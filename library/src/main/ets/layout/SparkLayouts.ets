import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../core/Builders';
import { SparkContext } from '../core/SparkContext';
import { SparkUI } from '../core/SparkUI';
import { SparkTheme } from '../theme/tokens/SparkTheme';
import { SparkLayoutContext } from './SparkLayoutContext';

/**
 * Breakpoint-free layout primitives. Each container measures its own width and lays its children out —
 * developers just nest components, like CSS flex-wrap / grid auto-fill / container queries:
 *
 * ```
 * SPage({ title: 'Dashboard' }) {
 *   SGrid({ minItemWidth: 260 }) {            // 1 column on a phone, 2–4 on tablets, no breakpoints
 *     SGridItem() { SCard() { ... } }
 *     SGridItem({ span: 2 }) { SCard() { ... } }
 *   }
 *   SColumns() {                              // side by side when there is room, stacked otherwise
 *     SColumn({ weight: 2 }) { ... }
 *     SColumn() { ... }
 *   }
 * }
 * ```
 */

const GRID_KEY: string = 'spark.grid';
const COLUMNS_KEY: string = 'spark.columns';

/** Gutter that grows with the available width (no breakpoints exposed to the developer). */
export function sparkGutter(widthVp: number): number {
  if (widthVp >= 1024) {
    return 32;
  }
  if (widthVp >= 600) {
    return 24;
  }
  return 16;
}

// ------------------------------------------------------------------------------------------------ SPage

/**
 * Page body: scrolls, centres content up to `maxWidth`, applies an adaptive gutter and the safe-area insets
 * (so it works in immersive pages), and spaces children with a vertical rhythm.
 */
@ComponentV2
export struct SPage {
  @Param title: ResourceStr | undefined = undefined;
  @Param description: ResourceStr | undefined = undefined;
  /** Max content width in vp (0 = unlimited). */
  @Param maxWidth: number = 1200;
  /** Vertical gap between children in vp. */
  @Param gap: number = 24;
  /** Add the top / bottom safe-area insets (for immersive pages without their own top bar). */
  @Param safeArea: boolean = false;
  /** Wrap in a Scroll (disable when the page lives inside another scroller). */
  @Param scrollable: boolean = true;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local measuredWidth: number = 0;

  @Builder
  body() {
    Column() {
      Column({ space: this.gap }) {
        if (this.title !== undefined) {
          Column({ space: 8 }) {
            Text(this.title)
              .fontSize(this.measuredWidth >= 600 ? this.theme.text.xxxl : this.theme.text.xxl)
              .fontWeight(this.theme.text.weightBold)
              .fontColor(this.theme.colors.foreground)
            if (this.description !== undefined) {
              Text(this.description)
                .fontSize(this.theme.text.base)
                .lineHeight(this.theme.text.leadingBase)
                .fontColor(this.theme.colors.mutedForeground)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        this.content()
      }
      .width('100%')
      .constraintSize({ maxWidth: this.maxWidth > 0 ? this.maxWidth : undefined })
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: sparkGutter(this.measuredWidth),
        right: sparkGutter(this.measuredWidth),
        top: sparkGutter(this.measuredWidth) + (this.safeArea ? this.layout.env.safeArea.top : 0),
        bottom: sparkGutter(this.measuredWidth) * 2 + (this.safeArea ? this.layout.env.safeArea.bottom : 0)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
    })
  }

  build() {
    if (this.scrollable) {
      Scroll() {
        this.body()
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    } else {
      this.body()
    }
  }
}

// ------------------------------------------------------------------------------------------------ stacks

/** Vertical stack with a token gap (default 16 vp). */
@ComponentV2
export struct SStack {
  @Param gap: number = 16;
  @Param alignment: HorizontalAlign = HorizontalAlign.Start;
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: this.gap }) {
      this.content()
    }
    .width('100%')
    .alignItems(this.alignment)
  }
}

/** Horizontal row with a token gap (default 8 vp), vertically centred. */
@ComponentV2
export struct SRow {
  @Param gap: number = 8;
  @Param justify: FlexAlign = FlexAlign.Start;
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Row({ space: this.gap }) {
      this.content()
    }
    .justifyContent(this.justify)
    .alignItems(VerticalAlign.Center)
  }
}

/** Wrapping row (chips, button groups, tags): items flow onto new lines when space runs out. */
@ComponentV2
export struct SFlow {
  @Param gap: number = 8;
  @Param justify: FlexAlign = FlexAlign.Start;
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      justifyContent: this.justify,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(this.gap), cross: LengthMetrics.vp(this.gap) }
    }) {
      this.content()
    }
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ SGrid

/** Grid measurement shared with SGridItem through SparkContext. */
@ObservedV2
export class SparkGridState {
  @Trace columns: number = 1;
  @Trace itemWidth: number = 0;
  @Trace width: number = 0;
  gap: number = 16;

  /** Width for an item spanning `span` columns. */
  spanWidth(span: number): number {
    const s = Math.max(1, Math.min(span, this.columns));
    return this.itemWidth * s + this.gap * (s - 1);
  }
}

/** Column count for an auto-fill grid (pure; unit-tested). */
export function sparkGridColumns(width: number, minItemWidth: number, gap: number, maxColumns: number): number {
  if (width <= 0) {
    return 1;
  }
  let cols = Math.max(1, Math.floor((width + gap) / (Math.max(1, minItemWidth) + gap)));
  if (maxColumns > 0) {
    cols = Math.min(cols, maxColumns);
  }
  return cols;
}

/**
 * Auto-fill grid: as many columns of at least `minItemWidth` as fit, items stretched to fill the row —
 * `grid-template-columns: repeat(auto-fill, minmax(minItemWidth, 1fr))`, no breakpoints.
 */
@ComponentV2
export struct SGrid {
  @Param minItemWidth: number = 280;
  @Param gap: number = 16;
  /** Upper bound on columns (0 = unlimited). */
  @Param maxColumns: number = 0;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkGridState = new SparkGridState();

  aboutToAppear(): void {
    this.state.gap = this.gap;
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), GRID_KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  private measure(width: number): void {
    const cols = sparkGridColumns(width, this.minItemWidth, this.gap, this.maxColumns);
    // floor to a 0.5 vp grid so rounding never pushes the last item onto a new row
    const item = Math.floor(((width - this.gap * (cols - 1)) / cols) * 2) / 2;
    this.state.gap = this.gap;
    if (cols !== this.state.columns) {
      this.state.columns = cols;
    }
    if (item !== this.state.itemWidth) {
      this.state.itemWidth = item;
    }
    this.state.width = width;
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      alignItems: ItemAlign.Stretch,
      space: { main: LengthMetrics.vp(this.gap), cross: LengthMetrics.vp(this.gap) }
    }) {
      this.content()
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => this.measure(Number(n.width)))
  }
}

/** A grid cell. `span` columns wide (clamped to the current column count); `'full'` spans the whole row. */
@ComponentV2
export struct SGridItem {
  @Param span: number = 1;
  @Param full: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local grid: SparkGridState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.grid === undefined) {
      this.grid = SparkContext.resolve<SparkGridState>(this.getUIContext(), this.getUniqueId(), GRID_KEY);
    }
  }

  @Computed
  get cellWidth(): Length {
    const g = this.grid;
    if (g === undefined || g.itemWidth <= 0 || this.full) {
      return '100%';
    }
    return g.spanWidth(this.span);
  }

  build() {
    Column() {
      this.content()
    }
    .width(this.cellWidth)
    .alignItems(HorizontalAlign.Start)
  }
}

// ------------------------------------------------------------------------------------------------ SColumns

@ObservedV2
export class SparkColumnsState {
  /** true when columns sit side by side */
  @Trace horizontal: boolean = false;
  @Trace width: number = 0;
  gap: number = 24;
  minColumnWidth: number = 280;
  private weights: Map<number, number> = new Map<number, number>();
  @Trace version: number = 0;

  register(id: number, weight: number): void {
    this.weights.set(id, weight);
    this.version++;
  }

  unregister(id: number): void {
    this.weights.delete(id);
    this.version++;
  }

  get count(): number {
    return this.weights.size;
  }

  /** Width of column `id` when horizontal. */
  columnWidth(id: number): number {
    let total = 0;
    this.weights.forEach((w: number) => {
      total += w;
    });
    const w = this.weights.get(id) ?? 1;
    const n = Math.max(1, this.weights.size);
    const free = this.width - this.gap * (n - 1);
    return Math.floor((free * w / Math.max(total, 1)) * 2) / 2;
  }

  update(width: number): void {
    this.width = width;
    const n = Math.max(1, this.weights.size);
    const horizontal = width >= this.minColumnWidth * n + this.gap * (n - 1);
    if (horizontal !== this.horizontal) {
      this.horizontal = horizontal;
    }
  }
}

/**
 * Side-by-side columns that stack vertically when they no longer fit (each needs `minColumnWidth`).
 * Like `flex flex-wrap` with `flex: <weight> 1 <minColumnWidth>`.
 */
@ComponentV2
export struct SColumns {
  @Param minColumnWidth: number = 280;
  @Param gap: number = 24;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkColumnsState = new SparkColumnsState();

  aboutToAppear(): void {
    this.state.gap = this.gap;
    this.state.minColumnWidth = this.minColumnWidth;
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), COLUMNS_KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('state.version')
  onColumnsChanged(): void {
    this.state.update(this.state.width);
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      alignItems: ItemAlign.Start,
      space: { main: LengthMetrics.vp(this.gap), cross: LengthMetrics.vp(this.gap) }
    }) {
      this.content()
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => this.state.update(Number(n.width)))
  }
}

@ComponentV2
export struct SColumn {
  /** Relative width when side by side (like flex-grow). */
  @Param weight: number = 1;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local parent: SparkColumnsState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.parent === undefined) {
      const p = SparkContext.resolve<SparkColumnsState>(this.getUIContext(), this.getUniqueId(), COLUMNS_KEY);
      if (p !== undefined) {
        p.register(this.getUniqueId(), this.weight);
      }
      this.parent = p;
    }
  }

  aboutToDisappear(): void {
    this.parent?.unregister(this.getUniqueId());
  }

  @Computed
  get columnWidth(): Length {
    const p = this.parent;
    if (p === undefined || !p.horizontal || p.version < 0) {
      return '100%';
    }
    return p.columnWidth(this.getUniqueId());
  }

  build() {
    Column({ space: 16 }) {
      this.content()
    }
    .width(this.columnWidth)
    .alignItems(HorizontalAlign.Start)
  }
}
