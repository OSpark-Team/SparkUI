import { SparkAnim } from '../../core/SparkAnim';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive } from '../../layout/SparkLayoutContext';
import { SparkAlign, SparkSide } from '../../primitives/overlay/Placement';
import { SparkDisclosure } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.tooltip';
/** touch: hold this long to show the tooltip */
const LONG_PRESS_MS: number = 450;

/** Tooltip state: open / closed plus what the content part publishes for the trigger's popup. */
@ObservedV2
export class SparkTooltipState extends SparkDisclosure {
  delay: number = 500;
  adaptive: SparkAdaptive = 'auto';
  @Trace panel: (() => void) | undefined = undefined;
  @Trace side: SparkSide = 'top';
  @Trace alignment: SparkAlign = 'center';
  @Trace sideOffset: number = 6;
}

function popupPlacement(side: SparkSide, alignment: SparkAlign): Placement {
  switch (side) {
    case 'bottom':
      return alignment === 'start' ? Placement.BottomLeft : (alignment === 'end' ? Placement.BottomRight :
        Placement.Bottom);
    case 'left':
      return alignment === 'start' ? Placement.LeftTop : (alignment === 'end' ? Placement.LeftBottom : Placement.Left);
    case 'right':
      return alignment === 'start' ? Placement.RightTop : (alignment === 'end' ? Placement.RightBottom :
        Placement.Right);
    default:
      return alignment === 'start' ? Placement.TopLeft : (alignment === 'end' ? Placement.TopRight : Placement.Top);
  }
}

/**
 * shadcn-vue `Tooltip`, built on the system popup (`bindPopup`: placement with flip, arrow, no mask), with
 * semantic translation:
 * - pointer: shows after hovering `delay` ms, hides on leave
 * - touch: long-press shows (the press is then not delivered as a tap to the trigger), releasing hides
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
  @Local state: SparkTooltipState = new SparkTooltipState();

  aboutToAppear(): void {
    this.syncOptions();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('delay', 'adaptive')
  syncOptions(): void {
    this.state.delay = this.delay;
    this.state.adaptive = this.adaptive;
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
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkTooltipState | undefined = undefined;
  private hoverTimer: number = -1;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkTooltipState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  aboutToDisappear(): void {
    clearTimeout(this.hoverTimer);
  }

  @Computed
  get shown(): boolean {
    return this.ctx !== undefined && this.ctx.open && this.ctx.panel !== undefined;
  }

  private hover(isHover: boolean): void {
    const ctx = this.ctx;
    if (ctx === undefined || ctx.adaptive === 'touch') {
      return;
    }
    SparkUI.layout.reportPointerEvent(true);
    clearTimeout(this.hoverTimer);
    if (isHover) {
      this.hoverTimer = setTimeout(() => ctx.setOpen(true), ctx.delay);
    } else {
      ctx.setOpen(false);
    }
  }

  private press(open: boolean): void {
    const ctx = this.ctx;
    if (ctx !== undefined && ctx.adaptive !== 'pointer') {
      ctx.setOpen(open);
    }
  }

  @Builder
  panelBuilder() {
    if (this.ctx?.panel !== undefined) {
      this.ctx.panel()
    }
  }

  build() {
    Stack() {
      this.content()
    }
    .onHover((isHover: boolean) => this.hover(isHover))
    // A priority gesture is recognised before the trigger's own tap: a completed long press shows the tooltip
    // and is not also delivered as a click; a short tap fails it and reaches the child as usual.
    .priorityGesture(
      LongPressGesture({ duration: LONG_PRESS_MS })
        .onAction(() => this.press(true))
        .onActionEnd(() => this.press(false))
        .onActionCancel(() => this.press(false))
    )
    .bindPopup(this.shown, {
      builder: () => this.panelBuilder(),
      placement: popupPlacement(this.ctx?.side ?? 'top', this.ctx?.alignment ?? 'center'),
      targetSpace: this.ctx?.sideOffset ?? 6,
      popupColor: this.theme.comp.color('tooltip', 'background', this.theme.colors.primary),
      backgroundBlurStyle: BlurStyle.NONE,
      shadow: { radius: 0, color: Color.Transparent },
      radius: this.theme.comp.length('tooltip', 'radius', this.theme.radiusMd),
      enableArrow: true,
      arrowWidth: 10,
      arrowHeight: 5,
      mask: false,
      autoCancel: true,
      focusable: false,
      outlineWidth: 0,
      borderWidth: 0,
      transition: SparkAnim.enter(this.theme, 'tooltip', 'fast', 0.95),
      onStateChange: (e: PopupStateChangeParam) => {
        if (!e.isVisible) {
          this.ctx?.setOpen(false);
        }
      }
    })
  }
}

/**
 * `bg-primary text-primary-foreground rounded-md px-3 py-1.5 text-xs` with an arrow; the system popup flips it
 * to stay on screen.
 */
@ComponentV2
export struct STooltipContent {
  @Param text: ResourceStr | undefined = undefined;
  @Param side: SparkSide = 'top';
  @Param alignment: SparkAlign = 'center';
  @Param sideOffset: number = 6;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkTooltipState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = SparkContext.resolve<SparkTooltipState>(this.getUIContext(), this.getUniqueId(), KEY);
      this.ctx = ctx;
      if (ctx !== undefined) {
        ctx.panel = this.panel;
        this.syncPlacement();
      }
    }
  }

  @Monitor('side', 'alignment', 'sideOffset')
  syncPlacement(): void {
    const ctx = this.ctx;
    if (ctx !== undefined) {
      ctx.side = this.side;
      ctx.alignment = this.alignment;
      ctx.sideOffset = this.sideOffset;
    }
  }

  aboutToDisappear(): void {
    if (this.ctx !== undefined) {
      this.ctx.setOpen(false);
      this.ctx.panel = undefined;
    }
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.comp.color('tooltip', 'foreground', this.theme.colors.primaryForeground))
      }
      this.content()
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .constraintSize({ maxWidth: 280 })
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
