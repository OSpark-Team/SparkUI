import { SparkAnim } from '../../core/SparkAnim';
import { ComponentContent, LevelOrder, promptAction } from '@kit.ArkUI';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { PlacementRect, PlacementResult, SparkAlign, SparkSide } from './Placement';

/**
 * How an overlay is presented.
 * - `center`: modal dialog centred in the viewport (Dialog, AlertDialog)
 * - `sheet-*`: modal panel attached to an edge (Sheet, Drawer)
 * - `anchored`: positioned next to a trigger (Popover, DropdownMenu, Select, Tooltip, HoverCard …)
 * - `toast`: non-modal, non-focusable layer above everything (Sonner)
 */
export type SparkPresentation = 'center' | 'sheet-bottom' | 'sheet-top' | 'sheet-left' | 'sheet-right' | 'anchored' |
  'toast';

export type SparkDismissReason = 'outside' | 'back' | 'escape' | 'programmatic' | 'gesture';

/** Callback asking the owner to close (the owner decides; controlled components may refuse). */
export type SparkDismissHandler = (reason: SparkDismissReason) => void;

/**
 * State of one open overlay. Passed as the ComponentContent argument — ComponentContent trees do not
 * inherit @Provider context (documented, and verified), so everything the content needs travels here.
 */
@ObservedV2
export class SparkOverlayScope {
  readonly id: number;
  presentation: SparkPresentation = 'center';
  /** dim the page and block interaction behind the overlay */
  modal: boolean = true;
  /** take focus (and trap it while open); false for tooltips / toasts */
  focusable: boolean = true;
  /** close when the user taps outside the content */
  dismissOnOutside: boolean = true;
  /** pass touches outside the content through to the page (tooltips, toasts) */
  passThrough: boolean = false;

  /**
   * Content-sized layer: the dialog frame is exactly the content (a non-modal dialog only intercepts touches
   * inside its frame — docs "弹出框蒙层控制"). True for toasts and pass-through anchored layers; such a
   * layer is positioned by the dialog's alignment / offset instead of inside a full-window host.
   */
  /** initial dialog offset of a content-sized toast layer (vp, from its alignment point) */
  offsetX: number = 0;
  offsetY: number = 0;

  get contentSized(): boolean {
    return this.presentation === 'toast' || (this.passThrough && this.presentation === 'anchored');
  }

  // anchored placement
  anchor: PlacementRect | undefined = undefined;
  side: SparkSide = 'bottom';
  alignment: SparkAlign = 'center';
  sideOffset: number = 4;
  alignOffset: number = 0;

  /** user content, rendered inside the overlay host */
  content: () => void = () => {
  };
  /** compound-component state re-provided inside the overlay through SparkContext */
  contextKey: string = '';
  contextValue: Object | undefined = undefined;
  /** focus target to restore on close (component `.id()`) */
  restoreFocusId: string = '';
  /** motion key for enter / exit (`--motion-<key>-*`): 'dialog', 'sheet', 'popover', 'tooltip', 'menu', 'toast' … */
  motionKey: string = 'overlay';
  /** uniqueId of the SparkOverlayHost (for SparkContext cleanup: ComponentContent skips aboutToDisappear) */
  hostComponentId: number = -1;

  theme: SparkTheme = SparkUI.theme;
  layout: SparkLayoutContext = SparkUI.layout.root;
  onDismiss: SparkDismissHandler = () => {
  };
  /** called after the exit animation, when the overlay is gone */
  onClosed: () => void = () => {
  };

  /** drives enter / exit animations */
  @Trace visible: boolean = false;
  @Trace placement: PlacementResult | undefined = undefined;
  /** measured content size (vp) */
  @Trace measuredWidth: number = 0;
  @Trace measuredHeight: number = 0;

  constructor(id: number) {
    this.id = id;
  }
}

class OpenEntry {
  scope: SparkOverlayScope;
  content: ComponentContent<SparkOverlayScope>;
  uiContext: UIContext;
  closing: boolean = false;

  constructor(scope: SparkOverlayScope, content: ComponentContent<SparkOverlayScope>, uiContext: UIContext) {
    this.scope = scope;
    this.content = content;
    this.uiContext = uiContext;
  }
}

/**
 * The overlay base (ADR D2): every SparkUI overlay is a `promptAction.openCustomDialog(ComponentContent)`
 * whose content is a full-window {@link SparkOverlayHost}. The system dialog only supplies the layer,
 * back-key / ESC / side-swipe interception and focus scope; mask, animation and positioning are drawn by
 * SparkUI from tokens so every overlay looks and behaves the same on every device.
 */
export class SparkOverlayService {
  private static nextId: number = 1;
  private static nextOrder: number = 1;
  private static entries: Map<number, OpenEntry> = new Map<number, OpenEntry>();

  static createScope(): SparkOverlayScope {
    return new SparkOverlayScope(SparkOverlayService.nextId++);
  }

  static isOpen(scope: SparkOverlayScope): boolean {
    const e = SparkOverlayService.entries.get(scope.id);
    return e !== undefined && !e.closing;
  }

  /** Move a content-sized layer: dialog offset from its alignment point (vp). Resolves once applied. */
  static moveTo(scope: SparkOverlayScope, dx: number, dy: number): Promise<void> {
    const e = SparkOverlayService.entries.get(scope.id);
    if (e === undefined) {
      return Promise.resolve();
    }
    try {
      return e.uiContext.getPromptAction().updateCustomDialog(e.content, { offset: { dx: dx, dy: dy } })
        .catch(() => {
        });
    } catch (err) {
      // layer already gone
      return Promise.resolve();
    }
  }

  /** Number of overlays currently on screen (layout inspector / tests). */
  static get openCount(): number {
    return SparkOverlayService.entries.size;
  }

  /** Use `openSparkOverlay()` (SparkOverlayHost.ets), which supplies the host builder. */
  static open(uiContext: UIContext, scope: SparkOverlayScope, host: WrappedBuilder<[SparkOverlayScope]>): void {
    if (SparkOverlayService.entries.has(scope.id)) {
      return;
    }
    const content = new ComponentContent<SparkOverlayScope>(uiContext, host, scope);
    const entry = new OpenEntry(scope, content, uiContext);
    SparkOverlayService.entries.set(scope.id, entry);
    const order = scope.presentation === 'toast' ? 100000 : Math.min(99999, SparkOverlayService.nextOrder++);
    const options: promptAction.BaseDialogOptions = {
      isModal: !scope.passThrough,
      autoCancel: false,
      maskColor: Color.Transparent,
      // Content-sized layers (see SparkOverlayScope.contentSized) are aligned / offset by the dialog; every
      // other layer is a full-window host. Anchored ones start off-screen until placed (moveTo).
      alignment: scope.presentation === 'toast' ?
        (scope.layout.env.windowWidthClass === 'compact' ? DialogAlignment.Bottom : DialogAlignment.BottomEnd) :
        DialogAlignment.TopStart,
      offset: scope.contentSized && scope.presentation === 'anchored' ? { dx: 0, dy: -10000 } :
        { dx: scope.offsetX, dy: scope.offsetY },
      transition: TransitionEffect.IDENTITY,
      keyboardAvoidMode: KeyboardAvoidMode.NONE,
      levelOrder: LevelOrder.clamp(order),
      focusable: scope.focusable,
      onWillDismiss: (action: DismissDialogAction) => {
        let reason: SparkDismissReason = 'back';
        if (action.reason === DismissReason.TOUCH_OUTSIDE) {
          reason = 'outside';
        } else if (action.reason === DismissReason.SLIDE_DOWN) {
          reason = 'gesture';
        }
        scope.onDismiss(reason);
      }
    };
    const fail = (): void => {
      SparkOverlayService.entries.delete(scope.id);
      content.dispose();
    };
    try {
      uiContext.getPromptAction().openCustomDialog(content, options).catch(fail);
    } catch (e) {
      fail();
    }
  }

  /** Run the exit animation (driven by the host), then remove the layer. */
  static close(scope: SparkOverlayScope): void {
    const entry = SparkOverlayService.entries.get(scope.id);
    if (entry === undefined || entry.closing) {
      return;
    }
    entry.closing = true;
    const theme = scope.theme;
    SparkAnim.run(entry.uiContext, theme, scope.motionKey, 'fast', () => {
      scope.visible = false;
    }, () => SparkOverlayService.remove(entry));
  }

  private static remove(entry: OpenEntry): void {
    const scope = entry.scope;
    let closing: Promise<void>;
    try {
      closing = entry.uiContext.getPromptAction().closeCustomDialog(entry.content);
    } catch (e) {
      closing = Promise.resolve();
    }
    closing.finally(() => {
      entry.content.dispose();
      SparkOverlayService.entries.delete(scope.id);
      if (scope.hostComponentId >= 0) {
        SparkContext.revoke(scope.hostComponentId);
      }
      if (scope.restoreFocusId.length > 0) {
        try {
          entry.uiContext.getFocusController().requestFocus(scope.restoreFocusId);
        } catch (e) {
          // the trigger may be gone
        }
      }
      scope.onClosed();
    });
  }

  /** Close everything (e.g. on page change). */
  static closeAll(): void {
    SparkOverlayService.entries.forEach((e: OpenEntry) => SparkOverlayService.close(e.scope));
  }
}
