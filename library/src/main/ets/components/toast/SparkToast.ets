import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { closeSparkOverlay, openSparkOverlay } from '../../primitives/overlay/SparkOverlayHost';
import { SparkOverlayScope, SparkOverlayService } from '../../primitives/overlay/SparkOverlay';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';
import { SSpinner } from '../spinner/SSpinner';

export type SparkToastVariant = 'default' | 'success' | 'error' | 'warning' | 'info' | 'loading';

const ITEM_KEY: string = 'spark.toast.item';
/** gap between toasts / distance from the window edge (vp) */
const GAP: number = 8;
const EDGE: number = 16;

export class SparkToastAction {
  label: string;
  onClick: () => void;

  constructor(label: string, onClick: () => void) {
    this.label = label;
    this.onClick = onClick;
  }
}

export interface SparkToastOptions {
  description?: string;
  variant?: SparkToastVariant;
  /** Auto-dismiss after this many ms; 0 = stay until dismissed. Default: `SparkToast.configure({ duration })`. */
  duration?: number;
  action?: SparkToastAction;
}

/** Toaster-wide settings (`SparkToast.configure`). */
export interface SparkToasterOptions {
  /** default auto-dismiss time in ms (default 4000); loading toasts never auto-dismiss */
  duration?: number;
  /** most toasts on screen; the oldest is dismissed when exceeded (default 5) */
  max?: number;
}

@ObservedV2
export class SparkToastItem {
  readonly id: number;
  @Trace title: string;
  @Trace description: string;
  @Trace variant: SparkToastVariant;
  @Trace action: SparkToastAction | undefined;
  @Trace dragX: number = 0;
  /** FLIP offset while the toast's layer is re-positioned (vp, animated back to 0) */
  @Trace shift: number = 0;
  /** measured card height (vp) */
  height: number = 0;
  duration: number;
  timer: number = -1;
  scope: SparkOverlayScope | undefined = undefined;
  /** dialog offset currently applied (from the bottom alignment point, negative = up) */
  placedY: number = 0;

  constructor(id: number, title: string, duration: number, options?: SparkToastOptions) {
    this.id = id;
    this.title = title;
    this.description = options?.description ?? '';
    this.variant = options?.variant ?? 'default';
    this.action = options?.action;
    this.duration = options?.duration ?? (this.variant === 'loading' ? 0 : duration);
  }
}

/**
 * Toast manager (singleton). Every toast is its own small non-modal layer, so the page between and around
 * toasts stays interactive and nothing depends on a layer growing after it opened. The manager lists them
 * newest at the bottom and moves the older layers up (FLIP: the card is shifted back and animates into place).
 */
@ObservedV2
export class SparkToaster {
  static readonly instance: SparkToaster = new SparkToaster();
  @Trace items: SparkToastItem[] = [];
  /** default auto-dismiss time (ms) */
  duration: number = 4000;
  /** max toasts on screen; the oldest is dismissed when exceeded */
  max: number = 5;
  private nextId: number = 1;

  configure(options: SparkToasterOptions): void {
    if (options.duration !== undefined) {
      this.duration = Math.max(0, options.duration);
    }
    if (options.max !== undefined) {
      this.max = Math.max(1, Math.floor(options.max));
    }
  }

  show(title: string, options?: SparkToastOptions): number {
    const ui = SparkUI.uiContext;
    const item = new SparkToastItem(this.nextId++, title, this.duration, options);
    if (ui === undefined) {
      return item.id;
    }
    SparkAnim.commit(() => {
      this.items = this.items.concat([item]);
    });
    this.open(ui, item);
    this.schedule(item);
    while (this.items.length > this.max) {
      this.dismiss(this.items[0].id);
    }
    this.relayout();
    return item.id;
  }

  /** Update an existing toast (e.g. loading → success). Shows a new one when it is gone. */
  update(id: number, title: string, options?: SparkToastOptions): void {
    const item = this.items.find((t: SparkToastItem) => t.id === id);
    if (item === undefined) {
      this.show(title, options);
      return;
    }
    item.title = title;
    item.description = options?.description ?? item.description;
    item.variant = options?.variant ?? item.variant;
    item.action = options?.action ?? item.action;
    item.duration = options?.duration ?? (item.variant === 'loading' ? 0 : this.duration);
    this.schedule(item);
  }

  dismiss(id: number): void {
    const item = this.items.find((t: SparkToastItem) => t.id === id);
    if (item === undefined) {
      return;
    }
    clearTimeout(item.timer);
    SparkAnim.commit(() => {
      this.items = this.items.filter((t: SparkToastItem) => t.id !== id);
    });
    if (item.scope !== undefined) {
      closeSparkOverlay(item.scope);
      item.scope = undefined;
    }
    this.relayout();
  }

  dismissAll(): void {
    this.items.slice().forEach((t: SparkToastItem) => this.dismiss(t.id));
  }

  /** A card reports its measured height. */
  measured(item: SparkToastItem, height: number): void {
    if (Math.abs(item.height - height) > 0.5) {
      item.height = height;
      this.relayout();
    }
  }

  private bottomBase(): number {
    const env = SparkUI.layout.root.env;
    return EDGE + Math.max(env.safeArea.bottom, env.keyboardHeight);
  }

  /** Newest at the bottom; each older toast sits above the newer ones. */
  private targetY(index: number): number {
    let y = this.bottomBase();
    for (let k = this.items.length - 1; k > index; k--) {
      y += this.items[k].height + GAP;
    }
    return -y;
  }

  private relayout(): void {
    const ui = SparkUI.uiContext;
    this.items.forEach((t: SparkToastItem, i: number) => {
      const y = this.targetY(i);
      const scope = t.scope;
      if (scope === undefined || Math.abs(y - t.placedY) < 0.5) {
        return;
      }
      const delta = y - t.placedY;
      t.placedY = y;
      SparkOverlayService.moveTo(scope, 0, y).then(() => {
        if (ui === undefined) {
          return;
        }
        // the layer jumped by `delta`; draw the card where it was and let it glide into place
        SparkAnim.commit(() => {
          t.shift = -delta;
        });
        SparkAnim.run(ui, SparkUI.theme, 'toast', 'normal', () => {
          t.shift = 0;
        });
      });
    });
  }

  private open(ui: UIContext, item: SparkToastItem): void {
    const scope = SparkOverlayService.createScope();
    scope.presentation = 'toast';
    scope.motionKey = 'toast';
    scope.modal = false;
    scope.passThrough = true;
    scope.focusable = false;
    scope.dismissOnOutside = false;
    scope.restoreFocusId = '';
    scope.theme = SparkUI.theme;
    scope.layout = SparkUI.layout.root;
    scope.contextKey = ITEM_KEY;
    scope.contextValue = item;
    scope.content = sparkToastSlotBuilder;
    scope.offsetY = -this.bottomBase();
    item.placedY = scope.offsetY;
    item.scope = scope;
    openSparkOverlay(ui, scope);
  }

  private schedule(item: SparkToastItem): void {
    clearTimeout(item.timer);
    if (item.duration > 0) {
      item.timer = setTimeout(() => this.dismiss(item.id), item.duration);
    }
  }
}

/**
 * Sonner-style toasts. Several can be on screen; each auto-dismisses after its duration.
 *
 * ```
 * SparkToast.show('Event has been created', { description: 'Sunday, December 03, 2023 at 9:00 AM',
 *   action: new SparkToastAction('Undo', () => this.undo()), duration: 8000 })
 * SparkToast.success('Saved')
 * SparkToast.show('Pinned', { duration: 0 })            // stays until dismissed
 * SparkToast.configure({ duration: 6000, max: 4 })      // defaults for every toast
 * const id = SparkToast.loading('Uploading…'); …; SparkToast.update(id, 'Uploaded', { variant: 'success' })
 * ```
 * Requires a SparkProvider on screen. Bottom-right on wide windows, bottom-centre on compact ones;
 * swipe sideways to dismiss.
 */
export class SparkToast {
  static configure(options: SparkToasterOptions): void {
    SparkToaster.instance.configure(options);
  }

  static show(title: string, options?: SparkToastOptions): number {
    return SparkToaster.instance.show(title, options);
  }

  static success(title: string, description?: string, duration?: number): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'success', duration: duration });
  }

  static error(title: string, description?: string, duration?: number): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'error', duration: duration });
  }

  static warning(title: string, description?: string, duration?: number): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'warning', duration: duration });
  }

  static info(title: string, description?: string, duration?: number): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'info', duration: duration });
  }

  static loading(title: string, description?: string): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'loading' });
  }

  static update(id: number, title: string, options?: SparkToastOptions): void {
    SparkToaster.instance.update(id, title, options);
  }

  static dismiss(id: number): void {
    SparkToaster.instance.dismiss(id);
  }

  static dismissAll(): void {
    SparkToaster.instance.dismissAll();
  }
}

/** Shorthand: `toast('Saved')`. */
export function toast(title: string, options?: SparkToastOptions): number {
  return SparkToaster.instance.show(title, options);
}

@ComponentV2
struct SparkToastCard {
  @Param item: SparkToastItem = new SparkToastItem(0, '', 0);
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  private iconName(): string {
    switch (this.item.variant) {
      case 'success':
        return 'circle-check';
      case 'error':
        return 'octagon-alert';
      case 'warning':
        return 'triangle-alert';
      case 'info':
        return 'info';
      case 'loading':
        return 'loader-circle';
      default:
        return '';
    }
  }

  build() {
    Row({ space: 12 }) {
      // The spinner is its own node: when the toast turns loading → success it is removed together with
      // its infinite rotation (a rotating SIcon kept spinning after the variant changed).
      if (this.item.variant === 'loading') {
        SSpinner({ sizing: 18, color: this.theme.colors.foreground })
      } else if (this.iconName().length > 0) {
        SIcon({ name: this.iconName(), sizing: 18, color: this.theme.colors.foreground })
          .transition(SparkAnim.enter(this.theme, 'toast', 'fast', 0.6))
      }
      Column({ space: 2 }) {
        Text(this.item.title)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.popoverForeground)
        if (this.item.description.length > 0) {
          Text(this.item.description)
            .fontSize(this.theme.text.sm)
            .fontColor(this.theme.colors.mutedForeground)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.item.action !== undefined) {
        SButton({ text: this.item.action.label, sizing: 'sm' })
          .onClick(() => {
            this.item.action?.onClick();
            SparkToaster.instance.dismiss(this.item.id);
          })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.colors.popover)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
    .shadow(this.theme.shadows.lg.toOptions())
    .translate({ x: this.item.dragX, y: this.item.shift })
    .opacity(1 - Math.min(Math.abs(this.item.dragX) / 240, 0.8))
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionUpdate((e: GestureEvent) => {
          this.item.dragX = e.offsetX;
        })
        .onActionEnd(() => {
          if (Math.abs(this.item.dragX) > 80) {
            SparkToaster.instance.dismiss(this.item.id);
          } else {
            SparkAnim.run(this.getUIContext(), this.theme, 'toast', 'fast', () => {
              this.item.dragX = 0;
            });
          }
        })
    )
    .onAreaChange((_: Area, n: Area) => SparkToaster.instance.measured(this.item, Number(n.height)))
    .accessibilityText(this.item.title + ' ' + this.item.description)
  }
}

/**
 * Content of one toast layer: resolves its item from the layer's context and draws the card at the
 * toaster width (full width minus margins on compact windows, 356vp otherwise).
 */
@ComponentV2
export struct SToastSlot {
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local item: SparkToastItem | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => {
      if (this.item === undefined) {
        this.item = SparkContext.resolve<SparkToastItem>(this.getUIContext(), this.getUniqueId(), ITEM_KEY);
      }
    });
  }

  build() {
    Column() {
      if (this.item !== undefined) {
        SparkToastCard({ item: this.item })
      }
    }
    .width(this.layout.env.windowWidthClass === 'compact' ? '100%' : 356 + EDGE * 2)
    .padding({ left: EDGE, right: EDGE })
  }
}

@Builder
function sparkToastSlotBuilder() {
  SToastSlot()
}
