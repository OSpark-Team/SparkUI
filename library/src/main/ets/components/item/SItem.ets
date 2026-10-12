import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkFocusRing, SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const ITEM_KEY: string = 'spark.item';
const GROUP_KEY: string = 'spark.itemGroup';
/** Below this own width the actions wrap under the content. */
const NARROW_WIDTH: number = 360;

export type ItemVariant = 'default' | 'outline' | 'muted';
export type ItemSize = 'default' | 'sm';
export type ItemMediaVariant = 'default' | 'icon' | 'image';

/** Per-item layout state shared with SItemMedia / SItemContent / SItemActions / SItemDescription. */
@ObservedV2
export class SparkItemState {
  /** own width < 360vp: actions wrap below the content */
  @Trace narrow: boolean = false;
  /** `sizing: 'sm'` */
  @Trace compact: boolean = false;
  /** content box width (own width minus padding and border) */
  @Trace innerWidth: number = 0;
  /** measured width of SItemMedia (0 = none) */
  @Trace mediaWidth: number = 0;
  /** number of SItemDescription parts (media aligns to the top when > 0) */
  @Trace descriptions: number = 0;

  /** gap between media / content / actions: gap-4, or gap-2.5 for sm */
  @Computed
  get gap(): number {
    return this.compact ? 10 : 16;
  }

  /** where the text column starts, relative to the content box */
  @Computed
  get contentStart(): number {
    return this.mediaWidth > 0 ? this.mediaWidth + this.gap : 0;
  }

  /** explicit content width used in the narrow (wrapping) layout */
  @Computed
  get narrowContentWidth(): number {
    return Math.max(0, this.innerWidth - this.contentStart);
  }

  update(width: number, horizontalChrome: number): void {
    const inner = Math.max(0, width - horizontalChrome);
    if (inner !== this.innerWidth) {
      this.innerWidth = inner;
    }
    const narrow = width > 0 && width < NARROW_WIDTH;
    if (narrow !== this.narrow) {
      this.narrow = narrow;
    }
  }
}

/** Group state: automatic separators between items (the top-most item gets none). */
@ObservedV2
export class SparkItemGroupState {
  @Trace bordered: boolean = false;
  @Trace separators: boolean = false;
  @Trace insetSeparators: boolean = true;
  /** component id of the top-most item, -1 until measured */
  @Trace firstId: number = -1;
  private positions: Map<number, number> = new Map<number, number>();

  report(id: number, y: number): void {
    this.positions.set(id, y);
    this.recompute();
  }

  remove(id: number): void {
    if (this.positions.delete(id)) {
      this.recompute();
    }
  }

  private recompute(): void {
    let first = -1;
    let minY = Number.MAX_VALUE;
    this.positions.forEach((y: number, id: number) => {
      if (y < minY - 0.5) {
        minY = y;
        first = id;
      }
    });
    if (first !== this.firstId) {
      this.firstId = first;
    }
  }
}

function resolveItem(uiContext: UIContext, id: number): SparkItemState | undefined {
  return SparkContext.resolve<SparkItemState>(uiContext, id, ITEM_KEY);
}

/**
 * shadcn-vue `ItemGroup`: a vertical list of SItem. `bordered` turns it into a settings-style card (`bg-card`
 * border, rounded-xl, items flush and clipped); `separators` draws a hairline between items automatically
 * (inset to the text column when `insetSeparators`).
 *
 * ```
 * SItemGroup({ bordered: true, separators: true }) {
 *   SItem({ interactive: true }) {
 *     SItemMedia({ icon: 'bell', variant: 'icon' })
 *     SItemContent() { SItemTitle({ text: 'Notifications' }) }
 *     SItemActions() { SIcon({ name: 'chevron-right' }) }
 *   }
 *   ...
 * }
 * ```
 */
@ComponentV2
export struct SItemGroup {
  @Param bordered: boolean = false;
  @Param separators: boolean = false;
  @Param insetSeparators: boolean = true;
  /** vertical gap between items in vp (shadcn ItemGroup has none; outline items often use 16) */
  @Param spacing: number = 0;
  @Param modifier: AttributeModifier<ColumnAttribute> = new SparkNoopModifier<ColumnAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkItemGroupState = new SparkItemGroupState();

  aboutToAppear(): void {
    this.sync();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), GROUP_KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('bordered', 'separators', 'insetSeparators')
  sync(): void {
    this.state.bordered = this.bordered;
    this.state.separators = this.separators;
    this.state.insetSeparators = this.insetSeparators;
  }

  build() {
    Column({ space: this.spacing }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.bordered ? this.theme.colors.card : Color.Transparent)
    .border({
      width: this.bordered ? 1 : 0,
      color: this.theme.colors.border,
      radius: this.bordered ? this.theme.radiusXl : 0
    })
    .clip(this.bordered)
    .attributeModifier(this.modifier)
  }
}

/**
 * shadcn-vue `Item`: `flex flex-wrap items-center gap-4 rounded-md border border-transparent p-4 text-sm`
 * (`sm`: `gap-2.5 px-4 py-3`). Variants: `default` (transparent), `outline` (`border-border`), `muted`
 * (`bg-muted/50`).
 *
 * `interactive` adds hover (`bg-accent/50`) and pressed (`bg-accent`) feedback and focusability; attach the
 * action with a wrapping `Stack() { SItem(...) { ... } }.onClick(...)` (slot components cannot chain events).
 *
 * Responsive: when the item itself is narrower than 360vp, SItemActions wraps onto its own line under the text.
 */
@ComponentV2
export struct SItem {
  @Param variant: ItemVariant = 'default';
  @Param sizing: ItemSize = 'default';
  /** hover / pressed feedback + focusable (use when the row is clickable) */
  @Param interactive: boolean = false;
  @Param modifier: AttributeModifier<FlexAttribute> = new SparkNoopModifier<FlexAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkItemState = new SparkItemState();
  @Local group: SparkItemGroupState | undefined = undefined;
  @Local ix: SparkInteraction = new SparkInteraction();
  private uid: number = -1;

  aboutToAppear(): void {
    this.uid = this.getUniqueId();
    this.state.compact = this.sizing === 'sm';
    SparkContext.provide(this.getUIContext(), this.uid, ITEM_KEY, this.state);
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.group === undefined) {
      this.group = SparkContext.resolve<SparkItemGroupState>(this.getUIContext(), this.uid, GROUP_KEY);
    }
  }

  aboutToDisappear(): void {
    this.group?.remove(this.uid);
    SparkContext.revoke(this.uid);
  }

  @Monitor('sizing')
  syncSizing(): void {
    this.state.compact = this.sizing === 'sm';
  }

  @Computed
  get paddingY(): number {
    return this.sizing === 'sm' ? 12 : 16;
  }

  /** flush rows inside a bordered group; rounded-md otherwise */
  @Computed
  get radius(): number {
    return this.group?.bordered === true ? 0 : this.theme.radiusMd;
  }

  @Computed
  get baseBackground(): string {
    return this.variant === 'muted' ? SparkColor.alpha(this.theme.colors.muted, 0.5) : '#00000000';
  }

  @Computed
  get hoverBackground(): string {
    return this.interactive ? SparkColor.alpha(this.theme.colors.accent, 0.5) : this.baseBackground;
  }

  @Computed
  get pressedBackground(): string {
    return this.interactive ? this.theme.colors.accent : this.baseBackground;
  }

  @Computed
  get showSeparator(): boolean {
    const g = this.group;
    return g !== undefined && g.separators && g.firstId !== -1 && g.firstId !== this.uid;
  }

  @Computed
  get separatorInset(): number {
    if (this.group?.insetSeparators !== true) {
      return 0;
    }
    return 16 + this.state.contentStart;
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.ix.hovered ? this.hoverBackground : this.baseBackground)
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.pressedBackground)
  }

  build() {
    Column() {
      if (this.showSeparator) {
        Row() {
          Row()
            .height(1)
            .layoutWeight(1)
            .backgroundColor(this.theme.colors.border)
        }
        .width('100%')
        .padding({ left: this.separatorInset })
        .accessibilityLevel('no')
      }
      Flex({
        direction: FlexDirection.Row,
        wrap: this.state.narrow ? FlexWrap.Wrap : FlexWrap.NoWrap,
        alignItems: ItemAlign.Center,
        space: { main: LengthMetrics.vp(this.state.gap), cross: LengthMetrics.vp(this.state.gap) }
      }) {
        this.content()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.paddingY, bottom: this.paddingY })
      .border({
        width: 1,
        color: this.variant === 'outline' ? this.theme.colors.border : Color.Transparent,
        radius: this.radius
      })
      .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
      .focusable(this.interactive)
      .focusBox(sparkFocusRing(this.theme))
      .onHover((h: boolean) => {
        if (this.interactive) {
          this.ix.hover(this.getUIContext(), this.theme, h);
        }
      })
      .onAreaChange((_: Area, n: Area) => {
        // 16 + 16 padding + 1 + 1 border
        this.state.update(Number(n.width), 34);
        this.group?.report(this.uid, Number(n.globalPosition.y ?? 0));
      })
      .attributeModifier(this.modifier)
    }
    .width('100%')
  }
}

/** Separator between items when not using `SItemGroup({ separators: true })`. */
@ComponentV2
export struct SItemSeparator {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column()
      .width('100%')
      .height(1)
      .backgroundColor(this.theme.colors.border)
      .accessibilityLevel('no')
  }
}

/**
 * `ItemMedia`: `default` (bare icon / avatar, 20vp icon), `icon` (`size-8 rounded-sm border bg-muted`, 16vp
 * icon) or `image` (`size-10 rounded-sm overflow-hidden`, object-cover `src`). Aligns to the top when the item
 * has a description.
 *
 * `tint` (an `#AARRGGBB` token such as `theme.colors.chart2`) gives the `icon` variant a soft coloured tile —
 * handy for settings lists.
 */
@ComponentV2
export struct SItemMedia {
  @Param icon: string | undefined = undefined;
  @Param variant: ItemMediaVariant = 'default';
  /** image for the `image` variant */
  @Param src: ResourceStr | undefined = undefined;
  @Param tint: string | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local item: SparkItemState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.item === undefined) {
      this.item = resolveItem(this.getUIContext(), this.getUniqueId());
    }
  }

  aboutToDisappear(): void {
    if (this.item !== undefined) {
      this.item.mediaWidth = 0;
    }
  }

  @Computed
  get boxSize(): number {
    if (this.variant === 'icon') {
      return 32;
    }
    return this.variant === 'image' ? 40 : 0;
  }

  @Computed
  get iconColor(): string {
    return this.tint ?? this.theme.colors.foreground;
  }

  @Computed
  get tileBackground(): string {
    if (this.variant !== 'icon') {
      return '#00000000';
    }
    return this.tint !== undefined ? SparkColor.alpha(this.tint, 0.14) : this.theme.colors.muted;
  }

  build() {
    Stack() {
      if (this.variant === 'image' && this.src !== undefined) {
        Image(this.src)
          .width(40)
          .height(40)
          .objectFit(ImageFit.Cover)
          .draggable(false)
      }
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: this.variant === 'default' ? 20 : 16, color: this.iconColor })
      }
      this.content()
    }
    .constraintSize({ minWidth: this.boxSize, minHeight: this.boxSize })
    .backgroundColor(this.tileBackground)
    .border({
      width: this.variant === 'icon' && this.tint === undefined ? 1 : 0,
      color: this.theme.colors.border,
      radius: this.theme.radiusSm
    })
    .clip(this.variant === 'image')
    .flexShrink(0)
    .alignSelf(this.item !== undefined && this.item.descriptions > 0 ? ItemAlign.Start : ItemAlign.Center)
    .translate({ y: this.variant === 'default' && this.item !== undefined && this.item.descriptions > 0 ? 2 : 0 })
    .onAreaChange((_: Area, n: Area) => {
      const w = Number(n.width);
      if (this.item !== undefined && this.item.mediaWidth !== w) {
        this.item.mediaWidth = w;
      }
    })
  }
}

/** Sizes SItemContent: grows in the single-line layout, explicit width in the wrapping (narrow) layout. */
class ItemContentModifier implements AttributeModifier<ColumnAttribute> {
  narrowWidth: number;

  /** @param narrowWidth explicit width, or -1 for the flexible (single-line) layout */
  constructor(narrowWidth: number) {
    this.narrowWidth = narrowWidth;
  }

  applyNormalAttribute(instance: ColumnAttribute): void {
    if (this.narrowWidth >= 0) {
      instance.layoutWeight(0).flexGrow(0).width(this.narrowWidth);
    } else {
      instance.width('auto').flexGrow(1).flexShrink(1).layoutWeight(1);
    }
  }
}

/** `flex flex-1 flex-col gap-1`: title + description. */
@ComponentV2
export struct SItemContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local item: SparkItemState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.item === undefined) {
      this.item = resolveItem(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get sizer(): ItemContentModifier {
    const it = this.item;
    return new ItemContentModifier(it !== undefined && it.narrow && it.innerWidth > 0 ? it.narrowContentWidth : -1);
  }

  build() {
    Column({ space: 4 }) {
      this.content()
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .attributeModifier(this.sizer)
  }
}

/** `flex w-fit items-center gap-2 text-sm leading-snug font-medium`; the slot holds trailing badges. */
@ComponentV2
export struct SItemTitle {
  @Param text: ResourceStr = '';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 8 }) {
      Text(this.text)
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.sm * 1.375)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
        .flexShrink(1)
      this.content()
    }
    .alignItems(VerticalAlign.Center)
  }
}

/** `text-muted-foreground line-clamp-2 text-sm leading-normal`. */
@ComponentV2
export struct SItemDescription {
  @Param text: ResourceStr = '';
  /** line clamp (shadcn: 2) */
  @Param maxLineCount: number = 2;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local item: SparkItemState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.item === undefined) {
      this.item = resolveItem(this.getUIContext(), this.getUniqueId());
      if (this.item !== undefined) {
        this.item.descriptions++;
      }
    }
  }

  aboutToDisappear(): void {
    if (this.item !== undefined) {
      this.item.descriptions = Math.max(0, this.item.descriptions - 1);
    }
  }

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.sm * 1.5)
      .fontColor(this.theme.colors.mutedForeground)
      .maxLines(this.maxLineCount)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}

/** Sizes SItemActions: intrinsic in the single-line layout, its own full-width line when narrow. */
class ItemActionsModifier implements AttributeModifier<RowAttribute> {
  narrow: boolean;
  indent: number;

  constructor(narrow: boolean, indent: number) {
    this.narrow = narrow;
    this.indent = indent;
  }

  applyNormalAttribute(instance: RowAttribute): void {
    if (this.narrow) {
      instance.width('100%').padding({ left: this.indent });
    } else {
      instance.width('auto').padding(0);
    }
  }
}

/** `flex items-center gap-2`, trailing; wraps under the text (aligned with it) when the item is narrow. */
@ComponentV2
export struct SItemActions {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local item: SparkItemState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.item === undefined) {
      this.item = resolveItem(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get sizer(): ItemActionsModifier {
    const it = this.item;
    return new ItemActionsModifier(it !== undefined && it.narrow, it !== undefined ? it.contentStart : 0);
  }

  build() {
    Row({ space: 8 }) {
      this.content()
    }
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .flexShrink(0)
    .attributeModifier(this.sizer)
  }
}
