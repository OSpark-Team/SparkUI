import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkFocusRing, SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkShadow, SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.card';

/** Card measurement shared with its parts: padding adapts to the card's own width. */
@ObservedV2
export class SparkCardState {
  /** horizontal / vertical padding in vp (shadcn px-6 / py-6, 16 when the card is narrow) */
  @Trace padding: number = 24;
  @Trace width: number = 0;
  /** `sizing: 'sm'`: always the compact 16vp padding */
  compact: boolean = false;

  update(width: number): void {
    this.width = width;
    const p = this.compact || (width > 0 && width < 360) ? 16 : 24;
    if (p !== this.padding) {
      this.padding = p;
    }
  }
}

function resolveCard(uiContext: UIContext, id: number): SparkCardState | undefined {
  return SparkContext.resolve<SparkCardState>(uiContext, id, KEY);
}

export type CardVariant = 'default' | 'outline' | 'elevated' | 'ghost' | 'filled';
export type CardSize = 'default' | 'sm';

/** Resolved surface of a card variant (normal / hover / pressed backgrounds, border, shadow). */
export class CardStyle {
  background: string = '#00000000';
  hoverBackground: string = '#00000000';
  pressedBackground: string = '#00000000';
  borderColor: string = '#00000000';
  shadow: SparkShadow | undefined = undefined;
  hoverShadow: SparkShadow | undefined = undefined;
}

/** Card variant recipe: default (shadcn) | outline | elevated | ghost | filled. */
export class CardVariants {
  static resolve(t: SparkTheme, variant: CardVariant): CardStyle {
    const c = t.colors;
    const s = new CardStyle();
    switch (variant) {
      case 'outline':
        s.borderColor = c.border;
        break;
      case 'elevated':
        s.background = c.card;
        s.shadow = t.shadows.md;
        s.hoverShadow = t.shadows.lg;
        break;
      case 'ghost':
        break;
      case 'filled':
        s.background = SparkColor.alpha(c.muted, t.isDark ? 0.6 : 0.8);
        break;
      default:
        s.background = c.card;
        s.borderColor = c.border;
        s.shadow = t.shadows.sm;
        s.hoverShadow = t.shadows.md;
    }
    if (s.hoverShadow === undefined) {
      s.hoverShadow = s.shadow;
    }
    // interactive feedback: an accent wash on hover, one step stronger while pressed
    const transparent = s.background === '#00000000';
    s.hoverBackground = transparent ? SparkColor.alpha(c.accent, 0.5) : SparkColor.mix(s.background, c.accent, 0.5);
    s.pressedBackground = transparent ? c.accent : SparkColor.mix(s.background, c.foreground, t.isDark ? 0.08 : 0.04);
    return s;
  }
}

/**
 * Applies a {@link CardStyle}; with `interactive` the pressed look comes from the system pressed state
 * (`applyPressedAttribute`), never from onTouch state, and is not animated.
 */
class CardStyleModifier implements AttributeModifier<ColumnAttribute> {
  style: CardStyle;
  radius: number;
  interactive: boolean;
  hovered: boolean;

  constructor(style: CardStyle, radius: number, interactive: boolean, hovered: boolean) {
    this.style = style;
    this.radius = radius;
    this.interactive = interactive;
    this.hovered = hovered;
  }

  applyNormalAttribute(instance: ColumnAttribute): void {
    const s = this.style;
    const hover = this.interactive && this.hovered;
    const shadow = hover ? s.hoverShadow : s.shadow;
    instance
      .backgroundColor(hover ? s.hoverBackground : s.background)
      .border({ width: 1, color: s.borderColor, radius: this.radius })
      .shadow(shadow !== undefined ? shadow.toOptions() : { radius: 0, color: Color.Transparent })
      .scale({ x: 1, y: 1 })
  }

  applyPressedAttribute(instance: ColumnAttribute): void {
    if (!this.interactive) {
      return;
    }
    instance
      .backgroundColor(this.style.pressedBackground)
      .scale({ x: 0.99, y: 0.99 })
  }
}

/**
 * shadcn-vue `Card`: `bg-card text-card-foreground flex flex-col gap-6 rounded-xl border py-6 shadow-sm`.
 * Responsive without breakpoints: padding tightens automatically when the card itself is narrow.
 *
 * Variants: default | outline (border only) | elevated (shadow-md, no border) | ghost (no surface) | filled
 * (`bg-muted`). `sizing: 'sm'` keeps the compact 16vp padding. `interactive` adds hover / pressed feedback and
 * focusability — attach the action on a wrapping `Stack() { SCard(...) { ... } }.onClick(...)` (slot components
 * cannot chain events). `image` puts a full-bleed media header on top (`imageHeight`, default 16:9).
 *
 * ```
 * SCard() {
 *   SCardHeader() {
 *     SCardTitle({ text: 'Account' })
 *     SCardDescription({ text: 'Manage your profile.' })
 *   }
 *   SCardContent() { TextInput({ placeholder: 'Name' }) }
 *   SCardFooter() { SButton({ text: 'Save' }) }
 * }
 * Stack() {
 *   SCard({ variant: 'elevated', interactive: true, image: 'https://example.com/cover.jpg' }) { SCardHeader() { ... } }
 * }.onClick(() => this.open())
 * ```
 */
@ComponentV2
export struct SCard {
  @Param variant: CardVariant = 'default';
  @Param sizing: CardSize = 'default';
  /** Hover / pressed feedback + focusable (use when the whole card is clickable). */
  @Param interactive: boolean = false;
  /** Full-bleed media header. */
  @Param image: ResourceStr | undefined = undefined;
  /** Height of the media header in vp; defaults to a 16:9 box. */
  @Param imageHeight: number | undefined = undefined;
  @Param modifier: AttributeModifier<ColumnAttribute> = new SparkNoopModifier<ColumnAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCardState = new SparkCardState();
  @Local ix: SparkInteraction = new SparkInteraction();

  aboutToAppear(): void {
    this.state.compact = this.sizing === 'sm';
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('sizing')
  syncSizing(): void {
    this.state.compact = this.sizing === 'sm';
    this.state.update(this.state.width);
  }

  @Computed
  get recipe(): CardStyleModifier {
    return new CardStyleModifier(CardVariants.resolve(this.theme, this.variant), this.theme.radiusXl,
      this.interactive, this.ix.hovered);
  }

  build() {
    Column({ space: this.state.padding }) {
      if (this.image !== undefined) {
        Image(this.image)
          .width('100%')
          .height(this.imageHeight ?? Math.round(this.state.width * 9 / 16))
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .backgroundColor(this.theme.colors.muted)
      }
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: this.image !== undefined ? 0 : this.state.padding, bottom: this.state.padding })
    .clip(this.image !== undefined)
    .attributeModifier(this.recipe)
    .focusable(this.interactive)
    .focusBox(sparkFocusRing(this.theme))
    .onHover((h: boolean) => {
      if (this.interactive) {
        this.ix.hover(this.getUIContext(), this.theme, h);
      }
    })
    .onAreaChange((_: Area, n: Area) => this.state.update(Number(n.width)))
    .attributeModifier(this.modifier)
  }
}

/** Title + description (+ optional SCardAction on the right). */
@ComponentV2
export struct SCardHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Column({ space: 6 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: this.card?.padding ?? 24, right: this.card?.padding ?? 24 })
  }
}

@ComponentV2
export struct SCardTitle {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.base)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.theme.colors.cardForeground)
  }
}

@ComponentV2
export struct SCardDescription {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
  }
}

/** Header action placed at the top-right corner of the card. */
@ComponentV2
export struct SCardAction {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Row() {
      this.content()
    }
    .position({ right: this.card?.padding ?? 24, top: 0 })
  }
}

@ComponentV2
export struct SCardContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Column({ space: 12 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: this.card?.padding ?? 24, right: this.card?.padding ?? 24 })
  }
}

/** Actions row; wraps onto several lines when the card is narrow. */
@ComponentV2
export struct SCardFooter {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }
    }) {
      this.content()
    }
    .width('100%')
    .padding({ left: this.card?.padding ?? 24, right: this.card?.padding ?? 24 })
  }
}
