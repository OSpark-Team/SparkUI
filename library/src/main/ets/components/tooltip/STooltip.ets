import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkAlign, SparkSide } from '../../primitives/overlay/Placement';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.tooltip';

/**
 * shadcn-vue `Tooltip`, with semantic translation:
 * - pointer: shows after hovering `delay` ms, hides on leave
 * - touch: long-press shows, releasing hides
 *
 * ```
 * STooltip() {
 *   STooltipTrigger() { SButton({ variant: 'outline', sizing: 'icon', icon: 'plus', label: 'Add' }) }
 *   STooltipContent({ text: 'Add to library' })
 * }
 * ```
 */
@ComponentV2
export struct STooltip {
  /** hover delay in ms (pointer) */
  @Param delay: number = 500;
  /** 'auto' follows the input modality; 'touch' disables hover, 'pointer' disables long-press */
  @Param adaptive: SparkAdaptive = 'auto';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkDisclosure = new SparkDisclosure();

  aboutToAppear(): void {
    this.state.placement = `${this.delay}|${this.adaptive}`;
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  build() {
    Stack() {
      this.content()
    }
  }
}

@ComponentV2
export struct STooltipTrigger {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local ctx: SparkDisclosure | undefined = undefined;
  private timer: number = -1;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
      if (this.ctx !== undefined) {
        this.ctx.triggerUniqueId = this.getUniqueId();
        this.ctx.triggerKey = sparkTriggerKey(this.getUniqueId());
      }
    }
  }

  aboutToDisappear(): void {
    clearTimeout(this.timer);
    clearTimeout(this.pressTimer);
  }

  private config(): string[] {
    return (this.ctx?.placement ?? '500|auto').split('|');
  }

  private hover(isHover: boolean): void {
    const ctx = this.ctx;
    if (ctx === undefined || this.config()[1] === 'touch') {
      return;
    }
    SparkUI.layout.reportPointerEvent(true);
    clearTimeout(this.timer);
    if (isHover) {
      this.timer = setTimeout(() => ctx.setOpen(true), Number(this.config()[0]));
    } else {
      ctx.setOpen(false);
    }
  }

  private pressTimer: number = -1;
  private downX: number = 0;
  private downY: number = 0;

  /**
   * Touch long-press without a gesture recognizer: a LongPressGesture on the trigger competes with the
   * trigger's own button (and lost — the tooltip never showed). Touch events don't enter the gesture arena.
   */
  private touch(e: TouchEvent): void {
    const ctx = this.ctx;
    if (ctx === undefined || this.config()[1] === 'pointer') {
      return;
    }
    const t = e.touches.length > 0 ? e.touches[0] : (e.changedTouches.length > 0 ? e.changedTouches[0] : undefined);
    if (e.type === TouchType.Down && t !== undefined) {
      this.downX = t.windowX;
      this.downY = t.windowY;
      clearTimeout(this.pressTimer);
      this.pressTimer = setTimeout(() => ctx.setOpen(true), 450);
    } else if (e.type === TouchType.Move && t !== undefined) {
      if (Math.abs(t.windowX - this.downX) > 10 || Math.abs(t.windowY - this.downY) > 10) {
        clearTimeout(this.pressTimer);
      }
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      clearTimeout(this.pressTimer);
      ctx.setOpen(false);
    }
  }

  build() {
    Stack() {
      this.content()
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .onHover((isHover: boolean) => this.hover(isHover))
    .onTouch((e: TouchEvent) => this.touch(e))
  }
}

/** `bg-primary text-primary-foreground rounded-md px-3 py-1.5 text-xs` with an arrow; flips to stay on screen. */
@ComponentV2
export struct STooltipContent {
  @Param text: ResourceStr | undefined = undefined;
  @Param side: SparkSide = 'top';
  @Param alignment: SparkAlign = 'center';
  @Param sideOffset: number = 6;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkDisclosure | undefined = undefined;
  @Local scope: SparkOverlayScope | undefined = undefined;
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
      this.ctx = ctx;
      if (ctx !== undefined) {
        this.binding.attach(this.getUIContext(), ctx, (scope: SparkOverlayScope) => {
          scope.presentation = 'anchored';
          scope.motionKey = 'tooltip';
          scope.modal = false;
          scope.passThrough = true;
          scope.focusable = false;
          scope.dismissOnOutside = false;
          scope.restoreFocusId = '';
          scope.anchor = ctx.anchorRect(this.getUIContext());
          scope.side = this.side;
          scope.alignment = this.alignment;
          scope.sideOffset = this.sideOffset;
          scope.content = this.panel;
          scope.theme = this.theme;
          scope.layout = this.layout;
          this.scope = scope;
        });
      }
    }
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @Computed
  get arrowX(): number {
    const p = this.scope?.placement;
    if (p === undefined || p.side === 'left' || p.side === 'right') {
      return -100;
    }
    return p.arrowOffset - 4;
  }

  @Computed
  get arrowY(): number {
    const s = this.scope;
    const p = s?.placement;
    if (s === undefined || p === undefined) {
      return -100;
    }
    if (p.side === 'top') {
      return s.measuredHeight - 4;
    }
    if (p.side === 'bottom') {
      return -4;
    }
    return p.arrowOffset - 4;
  }

  @Computed
  get arrowLeft(): number {
    const s = this.scope;
    const p = s?.placement;
    if (s === undefined || p === undefined) {
      return -100;
    }
    if (p.side === 'left') {
      return s.measuredWidth - 4;
    }
    if (p.side === 'right') {
      return -4;
    }
    return this.arrowX;
  }

  @LocalBuilder
  panel() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(8)
        .height(8)
        .rotate({ angle: 45 })
        .backgroundColor(this.theme.colors.primary)
        .position({ x: this.arrowLeft, y: this.arrowY })
      Column() {
        if (this.text !== undefined) {
          Text(this.text)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.primaryForeground)
        }
        this.content()
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .constraintSize({ maxWidth: 280 })
      .backgroundColor(this.theme.colors.primary)
      .borderRadius(this.theme.radiusMd)
    }
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
