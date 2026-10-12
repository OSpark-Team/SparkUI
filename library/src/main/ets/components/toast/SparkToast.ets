import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { closeSparkOverlay, openSparkOverlay } from '../../primitives/overlay/SparkOverlayHost';
import { SparkOverlayScope, SparkOverlayService } from '../../primitives/overlay/SparkOverlay';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';
import { SSpinner } from '../spinner/SSpinner';
import { SparkAnim } from '../../core/SparkAnim';

export type SparkToastVariant = 'default' | 'success' | 'error' | 'warning' | 'info' | 'loading';

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
  /** ms; 0 = stay until dismissed */
  duration?: number;
  action?: SparkToastAction;
}

@ObservedV2
export class SparkToastItem {
  readonly id: number;
  @Trace title: string;
  @Trace description: string;
  @Trace variant: SparkToastVariant;
  @Trace action: SparkToastAction | undefined;
  @Trace dragX: number = 0;
  /** measured card height (vp), for stacking */
  @Trace height: number = 0;
  duration: number;
  timer: number = -1;

  constructor(id: number, title: string, options?: SparkToastOptions) {
    this.id = id;
    this.title = title;
    this.description = options?.description ?? '';
    this.variant = options?.variant ?? 'default';
    this.action = options?.action;
    this.duration = options?.duration ?? (this.variant === 'loading' ? 0 : 4000);
  }
}

/** Toast queue + overlay layer (singleton). */
@ObservedV2
export class SparkToaster {
  static readonly instance: SparkToaster = new SparkToaster();
  @Trace items: SparkToastItem[] = [];
  /** max toasts on screen; older ones are dropped */
  max: number = 3;
  private nextId: number = 1;
  private scope: SparkOverlayScope | undefined = undefined;

  show(title: string, options?: SparkToastOptions): number {
    const item = new SparkToastItem(this.nextId++, title, options);
    const ui = SparkUI.uiContext;
    const add = (): void => {
      this.items = this.items.concat([item]).slice(-this.max);
    };
    if (ui !== undefined) {
      SparkAnim.run(ui, SparkUI.theme, 'toast', 'normal', add);
    } else {
      add();
    }
    this.schedule(item);
    this.ensureLayer();
    return item.id;
  }

  /** Update an existing toast (e.g. loading → success). */
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
    item.duration = options?.duration ?? (item.variant === 'loading' ? 0 : 4000);
    this.schedule(item);
  }

  dismiss(id: number): void {
    const item = this.items.find((t: SparkToastItem) => t.id === id);
    if (item !== undefined) {
      clearTimeout(item.timer);
    }
    const ui = SparkUI.uiContext;
    const remove = (): void => {
      this.items = this.items.filter((t: SparkToastItem) => t.id !== id);
    };
    if (ui !== undefined) {
      SparkAnim.run(ui, SparkUI.theme, 'toast', 'fast', remove, () => this.maybeCloseLayer());
    } else {
      remove();
      this.maybeCloseLayer();
    }
  }

  dismissAll(): void {
    this.items.forEach((t: SparkToastItem) => clearTimeout(t.timer));
    this.items = [];
    this.maybeCloseLayer();
  }

  private schedule(item: SparkToastItem): void {
    clearTimeout(item.timer);
    if (item.duration > 0) {
      item.timer = setTimeout(() => this.dismiss(item.id), item.duration);
    }
  }

  private ensureLayer(): void {
    const ui = SparkUI.uiContext;
    if (ui === undefined || (this.scope !== undefined && SparkOverlayService.isOpen(this.scope))) {
      return;
    }
    const scope = SparkOverlayService.createScope();
    scope.presentation = 'toast';
          scope.motionKey = 'toast';
    scope.modal = false;
    scope.passThrough = true;
    scope.focusable = false;
    scope.dismissOnOutside = false;
    scope.theme = SparkUI.theme;
    scope.layout = SparkUI.layout.root;
    scope.content = sparkToastStackBuilder;
    this.scope = scope;
    openSparkOverlay(ui, scope);
  }

  private maybeCloseLayer(): void {
    if (this.items.length === 0 && this.scope !== undefined) {
      closeSparkOverlay(this.scope);
      this.scope = undefined;
    }
  }
}

/**
 * Sonner-style toasts.
 *
 * ```
 * SparkToast.show('Event has been created', { description: 'Sunday, December 03, 2023 at 9:00 AM',
 *   action: new SparkToastAction('Undo', () => this.undo()) })
 * SparkToast.success('Saved')
 * const id = SparkToast.loading('Uploading…'); …; SparkToast.update(id, 'Uploaded', { variant: 'success' })
 * ```
 * Requires a SparkProvider on screen. Bottom-right on wide windows, bottom-centre on compact ones;
 * swipe sideways to dismiss.
 */
export class SparkToast {
  static show(title: string, options?: SparkToastOptions): number {
    return SparkToaster.instance.show(title, options);
  }

  static success(title: string, description?: string): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'success' });
  }

  static error(title: string, description?: string): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'error' });
  }

  static warning(title: string, description?: string): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'warning' });
  }

  static info(title: string, description?: string): number {
    return SparkToaster.instance.show(title, { description: description, variant: 'info' });
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
}

/** Shorthand: `toast('Saved')`. */
export function toast(title: string, options?: SparkToastOptions): number {
  return SparkToaster.instance.show(title, options);
}

@ComponentV2
struct SparkToastCard {
  @Param item: SparkToastItem = new SparkToastItem(0, '');
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
    .translate({ x: this.item.dragX })
    .opacity(1 - Math.min(Math.abs(this.item.dragX) / 240, 0.8))
    .transition(SparkAnim.enter(this.theme, 'toast', 'normal', undefined, 24))
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
    .accessibilityText(this.item.title + ' ' + this.item.description)
  }
}

/** collapsed stack: vertical peek of each toast behind the front one */
const PEEK: number = 12;
const GAP: number = 8;

/**
 * The stack rendered inside the toast layer (Sonner style): the newest toast is in front, older ones are
 * pushed back (smaller, peeking out above). Tap the stack (touch) or hover it (pointer) to expand it into a
 * list. The stack reserves exactly the height it draws, so the non-modal layer never covers more of the page
 * than the toasts themselves.
 */
@ComponentV2
export struct SToastStack {
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local expanded: boolean = false;

  /** current position of a toast (keyed ForEach does not refresh the index parameter when older items drop) */
  private indexOf(t: SparkToastItem): number {
    return SparkToaster.instance.items.indexOf(t);
  }

  /** 0 = newest (front) */
  private depth(i: number): number {
    return SparkToaster.instance.items.length - 1 - i;
  }

  private offsetOf(i: number): number {
    const items = SparkToaster.instance.items;
    const d = this.depth(i);
    if (!this.expanded) {
      return -d * PEEK;
    }
    let y = 0;
    for (let k = i + 1; k < items.length; k++) {
      y += items[k].height + GAP;
    }
    return -y;
  }

  @Computed
  get frameHeight(): number {
    const items = SparkToaster.instance.items;
    if (items.length === 0) {
      return 0;
    }
    if (!this.expanded) {
      return items[items.length - 1].height + (items.length - 1) * PEEK;
    }
    let h = 0;
    items.forEach((t: SparkToastItem) => {
      h += t.height;
    });
    return h + (items.length - 1) * GAP;
  }

  @Monitor('frameHeight')
  collapseWhenSingle(): void {
    if (SparkToaster.instance.items.length <= 1 && this.expanded) {
      this.expanded = false;
    }
  }

  @Computed
  get bottomInset(): number {
    return Math.max(this.layout.env.safeArea.bottom, this.layout.env.keyboardHeight);
  }


  private setExpanded(v: boolean): void {
    if (v !== this.expanded) {
      SparkAnim.run(this.getUIContext(), this.theme, 'toast', 'normal', () => {
        this.expanded = v;
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      ForEach(SparkToaster.instance.items, (t: SparkToastItem) => {
        // stacking transform on a wrapper; the card's own drag translate stays un-animated
        Column() {
          SparkToastCard({ item: t })
        }
        .width('100%')
        .translate({ y: this.offsetOf(this.indexOf(t)) })
        .scale({
          x: this.expanded ? 1 : 1 - this.depth(this.indexOf(t)) * 0.05,
          y: this.expanded ? 1 : 1 - this.depth(this.indexOf(t)) * 0.05,
          centerY: '100%'
        })
        .opacity(this.expanded || this.depth(this.indexOf(t)) < 3 ? 1 : 0)
        .zIndex(this.indexOf(t))
        .animation(SparkAnim.attr(this.theme, 'toast', 'normal'))
        .onAreaChange((_: Area, n: Area) => {
          t.height = Number(n.height);
        })
      }, (t: SparkToastItem) => String(t.id))
    }
    .width(this.layout.env.windowWidthClass === 'compact' ? '100%' : 356 + 32)
    // height includes the padding (border-box)
    .height(this.frameHeight > 0 ? this.frameHeight + 16 + this.bottomInset : 'auto')
    .padding({ left: 16, right: 16, top: 0, bottom: 16 + this.bottomInset })
    .onHover((h: boolean) => this.setExpanded(h))
    .onClick(() => this.setExpanded(!this.expanded))
  }
}

@Builder
function sparkToastStackBuilder() {
  SToastStack()
}
