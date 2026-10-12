import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkSortedIndex, sparkTableBodyFixed, sparkTableBodyMax, sparkTableColumnWidths, sparkTableTotal,
  sparkTableUseCards, STableColumn, TableAdaptive, TableAlignment
} from './TableLayout';

const KEY_TABLE: string = 'spark.table';
const KEY_SECTION: string = 'spark.table.section';
const KEY_ROW: string = 'spark.table.row';

export type TableSectionKind = 'header' | 'body' | 'footer';

/** Table-wide state: columns, measured width and the resolved layout (widths / cards). */
@ObservedV2
export class SparkTableState {
  @Trace columns: STableColumn[] = [];
  @Trace available: number = 0;
  @Trace adaptive: TableAdaptive = 'auto';

  // @Computed: cached until columns / available / adaptive change, so N cells reading their width cost O(N)
  // instead of re-running the column solver per cell.
  @Computed
  get cards(): boolean {
    return sparkTableUseCards(this.adaptive, this.available, this.columns);
  }

  @Computed
  get widths(): number[] {
    return sparkTableColumnWidths(this.columns, this.available);
  }

  @Computed
  get total(): number {
    return sparkTableTotal(this.widths);
  }

  /** wider than the container: scroll horizontally */
  @Computed
  get scrolls(): boolean {
    return !this.cards && this.available > 0 && this.total > this.available + 0.5;
  }

  widthAt(i: number): number | undefined {
    if (this.available <= 0 || i < 0 || i >= this.columns.length) {
      return undefined;
    }
    return this.widths[i];
  }

  column(i: number): STableColumn | undefined {
    return i >= 0 && i < this.columns.length ? this.columns[i] : undefined;
  }
}

/** Per-member observable flag: only the members whose "last" state changes re-render. */
@ObservedV2
export class SparkTableMemberFlag {
  @Trace last: boolean = false;
}

/**
 * Ordered members (rows of a section, cells of a row). Members are ordered by component id, which grows in
 * build order, so a cell's index is its position in the row without the developer numbering it.
 *
 * Scales to large sections: ids live in a plain sorted array (binary-search insert, no copy + sort per add), and
 * "is last" is a per-member traced flag, so adding row N flips two flags instead of re-evaluating every row
 * (the old @Trace array made N row registrations cost O(N²)). Cells read their index through `version`.
 */
@ObservedV2
export class SparkTableMembers {
  @Trace kind: TableSectionKind = 'body';
  /** bumps on every membership change (cells' column index depends on it) */
  @Trace version: number = 0;
  private ids: number[] = [];
  private flags: Map<number, SparkTableMemberFlag> = new Map<number, SparkTableMemberFlag>();

  add(id: number): void {
    const at = sparkSortedIndex(this.ids, id);
    if (at < this.ids.length && this.ids[at] === id) {
      return;
    }
    const before = this.lastId();
    this.ids.splice(at, 0, id);
    this.version++;
    this.moveLast(before);
  }

  remove(id: number): void {
    const at = sparkSortedIndex(this.ids, id);
    if (at >= this.ids.length || this.ids[at] !== id) {
      return;
    }
    const before = this.lastId();
    this.ids.splice(at, 1);
    this.flags.delete(id);
    this.version++;
    this.moveLast(before);
  }

  indexOf(id: number): number {
    if (this.version < 0) {
      return -1; // never: reading `version` registers the dependency
    }
    const at = sparkSortedIndex(this.ids, id);
    return at < this.ids.length && this.ids[at] === id ? at : -1;
  }

  /** Observable "last member" flag of `id` (created on demand). */
  flag(id: number): SparkTableMemberFlag {
    let f = this.flags.get(id);
    if (f === undefined) {
      f = new SparkTableMemberFlag();
      this.flags.set(id, f);
    }
    return f;
  }

  isLast(id: number): boolean {
    return this.flag(id).last;
  }

  private lastId(): number {
    return this.ids.length > 0 ? this.ids[this.ids.length - 1] : -1;
  }

  private moveLast(before: number): void {
    const after = this.lastId();
    if (before === after) {
      return;
    }
    if (before >= 0) {
      const f = this.flags.get(before);
      if (f !== undefined) {
        f.last = false;
      }
    }
    if (after >= 0) {
      this.flag(after).last = true;
    }
  }
}

function alignOf(a: TableAlignment): FlexAlign {
  return a === 'end' ? FlexAlign.End : (a === 'center' ? FlexAlign.Center : FlexAlign.Start);
}

function textAlignOf(a: TableAlignment): TextAlign {
  return a === 'end' ? TextAlign.End : (a === 'center' ? TextAlign.Center : TextAlign.Start);
}

/**
 * shadcn-vue `Table` (`w-full caption-bottom text-sm`), with column sizing and a responsive card layout.
 *
 * Slot form:
 * ```
 * STable({ columns: this.cols, caption: 'A list of your recent invoices.' }) {
 *   STableHeader() {
 *     STableRow() { STableHead({ text: 'Invoice' }) STableHead({ text: 'Amount' }) }
 *   }
 *   STableBody() {
 *     ForEach(this.invoices, (r: Invoice) => {
 *       STableRow() { STableCell({ text: r.id }) STableCell({ text: r.amount }) }
 *     }, (r: Invoice) => r.id)
 *   }
 *   STableFooter() {
 *     STableRow() { STableCell({ text: 'Total' }) STableCell({ text: '$2,500.00' }) }
 *   }
 * }
 * ```
 * Data form (no slots): `STable({ columns: this.cols, rows: [['INV001', '$250.00'], ...], footer: [...] })`.
 * The data form is virtualized (`List` + `Repeat.virtualScroll()`, ADR D14): 10 000 rows render as fast as 10.
 * Its body scrolls inside the table once it is taller than `bodyHeight` (default 480vp above 50 rows), with the
 * header kept in view. Use the data form for long tables; the slot form builds every row.
 *
 * Columns (`STableColumn`): ArkUI cannot size arbitrary children, so the table owns the widths — fixed vp or a
 * weight of the remaining width with a min width — and each cell reads the width of its index (its position
 * in the row; pass `column` to override). When the columns do not fit, the table scrolls horizontally
 * (`adaptive: 'table'`) or — with `adaptive: 'auto'` (default) — turns every row into a card of
 * "Head: value" lines. `'cards'` always shows cards.
 */
@ComponentV2
export struct STable {
  @Param columns: STableColumn[] = [];
  @Param adaptive: TableAdaptive = 'auto';
  /** Data form: one string per column for each row. Leave undefined to use the slot. */
  @Param rows: string[][] | undefined = undefined;
  /** Data form: optional footer cells. */
  @Param footer: string[] | undefined = undefined;
  /**
   * Data form: body viewport height (vp). Rows beyond it scroll inside the table and are built lazily. Unset:
   * the body follows its rows up to 50 rows, above that it gets a 480vp viewport (ADR D14).
   */
  @Param bodyHeight: number | undefined = undefined;
  /** Data form: stable row key (default: the row index). Give one when rows are inserted / reordered. */
  @Param rowKey: ((row: string[], index: number) => string) | undefined = undefined;
  /** Caption below the table (`text-muted-foreground mt-4 text-sm`). */
  @Param caption: ResourceStr | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkTableState = new SparkTableState();

  aboutToAppear(): void {
    this.state.columns = this.columns;
    this.state.adaptive = this.adaptive;
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY_TABLE, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('columns', 'adaptive')
  syncColumns(): void {
    this.state.columns = this.columns;
    this.state.adaptive = this.adaptive;
  }

  @Computed
  get innerWidth(): Length {
    if (this.state.scrolls) {
      return this.state.total;
    }
    return this.state.available > 0 ? this.state.available : '100%';
  }

  @Computed
  get titles(): string[] {
    return this.columns.map((c: STableColumn) => c.title);
  }

  @Computed
  get rowCount(): number {
    return this.rows !== undefined ? this.rows.length : 0;
  }

  /** body viewport (Infinity: as tall as the rows) */
  @Computed
  get bodyMax(): number {
    return sparkTableBodyMax(this.rowCount, this.bodyHeight);
  }

  /** definite body height when the rows overflow it (0: follow the content) */
  @Computed
  get bodyFixed(): number {
    return sparkTableBodyFixed(this.rowCount, this.bodyMax);
  }

  private keyOf(r: string[], i: number): string {
    return this.rowKey !== undefined ? this.rowKey(r, i) : `${i}`;
  }

  /**
   * Data form (ADR D14): header and footer rows are plain components; the body is a `List` with
   * `Repeat.virtualScroll()`, so only the visible rows exist and scrolled-out rows are reused. Rows read the
   * table state directly (no SparkContext registration per row / cell), so N rows cost O(N) once, and nothing
   * per row is built until it scrolls into view.
   */
  @Builder
  dataTable() {
    if (!this.state.cards) {
      SparkTableDataRow({ table: this.state, cells: this.titles, kind: 'header', last: false })
    }
    List({ space: this.state.cards ? 8 : 0 }) {
      Repeat<string[]>(this.rows ?? [])
        .each((ri: RepeatItem<string[]>) => {
          ListItem() {
            SparkTableDataRow({
              table: this.state,
              cells: ri.item,
              kind: 'body',
              last: ri.index === this.rowCount - 1
            })
          }
        })
        .key((r: string[], i: number) => this.keyOf(r, i))
        .virtualScroll({ totalCount: this.rowCount })
    }
    .width('100%')
    .constraintSize({ minHeight: this.bodyFixed, maxHeight: this.bodyMax })
    .cachedCount(8)
    .scrollBar(isFinite(this.bodyMax) ? BarState.Auto : BarState.Off)
    .edgeEffect(EdgeEffect.None)
    // scroll the body first, then hand the rest of the gesture to the page
    .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    if (this.footer !== undefined) {
      SparkTableDataRow({ table: this.state, cells: this.footer, kind: 'footer', last: true })
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          if (this.rows !== undefined) {
            this.dataTable()
          } else {
            this.content()
          }
        }
        .width(this.innerWidth)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .enableScrollInteraction(this.state.scrolls)
      .edgeEffect(this.state.scrolls ? EdgeEffect.Spring : EdgeEffect.None)
      .scrollBar(this.state.scrolls ? BarState.Auto : BarState.Off)
      .align(Alignment.TopStart)

      if (this.caption !== undefined) {
        STableCaption({ text: this.caption })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_: Area, n: Area) => {
      const w = Number(n.width);
      if (Math.abs(w - this.state.available) > 0.5) {
        this.state.available = w;
      }
    })
  }
}

/** Table caption (`text-muted-foreground mt-4 text-sm`, centred). Write it after the body. */
@ComponentV2
export struct STableCaption {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .width('100%')
      .margin({ top: 16 })
      .textAlign(TextAlign.Center)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
  }
}

/** Shared section implementation: header / body / footer differ in kind only. */
@ComponentV2
struct SparkTableSection {
  @Param kind: TableSectionKind = 'body';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local members: SparkTableMembers = new SparkTableMembers();
  @Local table: SparkTableState | undefined = undefined;

  aboutToAppear(): void {
    this.members.kind = this.kind;
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY_SECTION, this.members);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.table === undefined) {
      this.table = SparkContext.resolve<SparkTableState>(this.getUIContext(), this.getUniqueId(), KEY_TABLE);
    }
  }

  @Computed
  get cards(): boolean {
    return this.table !== undefined && this.table.cards;
  }

  build() {
    Column({ space: this.cards ? 8 : 0 }) {
      // cards repeat the column titles in every card, so the header row is not shown
      if (!(this.cards && this.kind === 'header')) {
        this.content()
      }
    }
    .width('100%')
    .margin({ top: this.cards && this.kind === 'footer' ? 8 : 0 })
    .backgroundColor(this.kind === 'footer' && !this.cards ? SparkColor.alpha(this.theme.colors.muted, 0.5) :
      '#00000000')
    .border({
      width: { top: this.kind === 'footer' && !this.cards ? 1 : 0 },
      color: this.theme.colors.border
    })
  }
}

/** `<thead>`: its rows always draw a bottom border. Hidden in the card layout. */
@ComponentV2
export struct STableHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SparkTableSection({ kind: 'header', content: this.content })
  }
}

/** `<tbody>`: the last row has no bottom border. */
@ComponentV2
export struct STableBody {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SparkTableSection({ kind: 'body', content: this.content })
  }
}

/** `<tfoot>`: `bg-muted/50 border-t font-medium`. */
@ComponentV2
export struct STableFooter {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SparkTableSection({ kind: 'footer', content: this.content })
  }
}

/**
 * `<tr>`: `border-b transition-colors hover:bg-muted/50`, `bg-muted` when `selected`. In the card layout it is a
 * bordered card listing "Head: value" lines.
 */
@ComponentV2
export struct STableRow {
  @Param selected: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local cells: SparkTableMembers = new SparkTableMembers();
  @Local table: SparkTableState | undefined = undefined;
  @Local section: SparkTableMembers | undefined = undefined;
  @Local ix: SparkInteraction = new SparkInteraction();

  aboutToAppear(): void {
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY_ROW, this.cells);
  }

  aboutToDisappear(): void {
    this.section?.remove(this.getUniqueId());
    SparkContext.revoke(this.getUniqueId());
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    const ui = this.getUIContext();
    const id = this.getUniqueId();
    if (this.table === undefined) {
      this.table = SparkContext.resolve<SparkTableState>(ui, id, KEY_TABLE);
    }
    if (this.section === undefined) {
      this.section = SparkContext.resolve<SparkTableMembers>(ui, id, KEY_SECTION);
      if (this.section !== undefined) {
        this.section.add(id);
        this.cells.kind = this.section.kind;
      }
    }
  }

  @Computed
  get kind(): TableSectionKind {
    return this.section?.kind ?? 'body';
  }

  @Computed
  get cards(): boolean {
    return this.table !== undefined && this.table.cards;
  }

  @Computed
  get lastInSection(): boolean {
    return this.section !== undefined && this.section.isLast(this.getUniqueId());
  }

  @Computed
  get bottomBorder(): number {
    if (this.cards) {
      return 1;
    }
    if (this.kind === 'header') {
      return 1;
    }
    return this.lastInSection ? 0 : 1;
  }

  @Computed
  get rowBackground(): string {
    const c = this.theme.colors;
    if (this.selected) {
      return c.muted;
    }
    if (this.cards && this.kind === 'footer') {
      return SparkColor.alpha(c.muted, 0.5);
    }
    return this.ix.hovered && this.kind !== 'header' ? SparkColor.alpha(c.muted, 0.5) : '#00000000';
  }

  build() {
    Flex({
      direction: this.cards ? FlexDirection.Column : FlexDirection.Row,
      alignItems: this.cards ? ItemAlign.Start : ItemAlign.Center
    }) {
      this.content()
    }
    .width('100%')
    .padding(this.cards ? 12 : 0)
    .backgroundColor(this.rowBackground)
    .border(this.cards ? {
      width: 1,
      color: this.theme.colors.border,
      radius: this.theme.radiusLg
    } : {
      width: { bottom: this.bottomBorder },
      color: this.theme.colors.border,
      radius: 0
    })
    .accessibilityRole(AccessibilityRoleType.ROW)
    .accessibilitySelected(this.selected)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
  }
}

/** Shared cell implementation (head and data cells). */
@ComponentV2
struct SparkTableCellBase {
  @Param text: ResourceStr | undefined = undefined;
  @Param column: number | undefined = undefined;
  @Param head: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local table: SparkTableState | undefined = undefined;
  @Local row: SparkTableMembers | undefined = undefined;
  /** id this cell registered with in its row (the wrapping public component's id) */
  @Param memberId: number = -1;

  aboutToDisappear(): void {
    this.row?.remove(this.memberId);
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    const ui = this.getUIContext();
    const id = this.getUniqueId();
    if (this.table === undefined) {
      this.table = SparkContext.resolve<SparkTableState>(ui, id, KEY_TABLE);
    }
    if (this.row === undefined) {
      this.row = SparkContext.resolve<SparkTableMembers>(ui, id, KEY_ROW);
      this.row?.add(this.memberId);
    }
  }

  @Computed
  get index(): number {
    if (this.column !== undefined) {
      return this.column;
    }
    return this.row !== undefined ? this.row.indexOf(this.memberId) : -1;
  }

  @Computed
  get cards(): boolean {
    return this.table !== undefined && this.table.cards;
  }

  @Computed
  get col(): STableColumn | undefined {
    return this.table?.column(this.index);
  }

  @Computed
  get alignment(): TableAlignment {
    return this.col?.alignment ?? 'start';
  }

  @Computed
  get footer(): boolean {
    return this.row !== undefined && this.row.kind === 'footer';
  }

  @Computed
  get cellWidth(): Length {
    const w = this.table?.widthAt(this.index);
    return w !== undefined ? w : 'auto';
  }

  @Builder
  value(alignment: TableAlignment) {
    if (this.text !== undefined) {
      Text(this.text)
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontWeight(this.head || this.footer ? this.theme.text.weightMedium : this.theme.text.weightNormal)
        .fontColor(this.head ? this.theme.colors.mutedForeground : this.theme.colors.foreground)
        .textAlign(textAlignOf(alignment))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    this.content()
  }

  build() {
    if (this.cards) {
      // "Head: value" line of a card
      Row({ space: 12 }) {
        Text(this.col?.title ?? '')
          .fontSize(this.theme.text.sm)
          .lineHeight(this.theme.text.leadingSm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.mutedForeground)
          .maxLines(1)
          .flexShrink(0)
          .constraintSize({ maxWidth: '50%' })
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          this.value('end')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .padding({ top: 2, bottom: 2 })
      .alignItems(VerticalAlign.Center)
    } else {
      Row() {
        this.value(this.alignment)
      }
      .width(this.cellWidth)
      .flexShrink(0)
      .constraintSize({ minHeight: this.head ? 40 : 0 })
      .padding(this.head ? { left: 8, right: 8 } : 8)
      .justifyContent(alignOf(this.alignment))
      .alignItems(VerticalAlign.Center)
    }
  }
}

/**
 * `<th>`: `h-10 px-2 text-left font-medium text-muted-foreground whitespace-nowrap`. Width / alignment come from
 * its column (its position in the row, or `column`).
 */
@ComponentV2
export struct STableHead {
  @Param text: ResourceStr | undefined = undefined;
  /** Column index; defaults to the position in the row. */
  @Param column: number | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SparkTableCellBase({
      text: this.text,
      column: this.column,
      head: true,
      content: this.content,
      memberId: this.getUniqueId()
    })
  }
}

/**
 * `<td>`: `p-2 align-middle whitespace-nowrap`. Pass `text` or slot content (badges, buttons …). Width /
 * alignment come from its column (its position in the row, or `column`).
 */
@ComponentV2
export struct STableCell {
  @Param text: ResourceStr | undefined = undefined;
  /** Column index; defaults to the position in the row. */
  @Param column: number | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SparkTableCellBase({
      text: this.text,
      column: this.column,
      head: false,
      content: this.content,
      memberId: this.getUniqueId()
    })
  }
}

/**
 * One row of the data form (header / body / footer), with the same look as STableRow + cells but without
 * SparkContext registration: it reads the table state it is given, and its cells are plain Text nodes. Reused by
 * `Repeat` as rows scroll (only `cells` / `last` change).
 */
@ComponentV2
struct SparkTableDataRow {
  @Require @Param table: SparkTableState;
  @Param cells: string[] = [];
  @Param kind: TableSectionKind = 'body';
  @Param last: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get rowBackground(): string {
    const c = this.theme.colors;
    if (this.kind === 'footer') {
      return SparkColor.alpha(c.muted, 0.5);
    }
    return this.ix.hovered && this.kind === 'body' ? SparkColor.alpha(c.muted, 0.5) : '#00000000';
  }

  @Computed
  get head(): boolean {
    return this.kind === 'header';
  }

  @Computed
  get strong(): boolean {
    return this.kind !== 'body';
  }

  @Builder
  cell(i: number) {
    Row() {
      Text(i < this.cells.length ? this.cells[i] : '')
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontWeight(this.strong ? this.theme.text.weightMedium : this.theme.text.weightNormal)
        .fontColor(this.head ? this.theme.colors.mutedForeground : this.theme.colors.foreground)
        .textAlign(textAlignOf(this.table.column(i)?.alignment ?? 'start'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(this.table.widthAt(i) ?? 'auto')
    .flexShrink(0)
    .constraintSize({ minHeight: this.head ? 40 : 0 })
    .padding(this.head ? { left: 8, right: 8 } : 8)
    .justifyContent(alignOf(this.table.column(i)?.alignment ?? 'start'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  cardLine(i: number) {
    Row({ space: 12 }) {
      Text(this.table.column(i)?.title ?? '')
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.mutedForeground)
        .maxLines(1)
        .flexShrink(0)
        .constraintSize({ maxWidth: '50%' })
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(i < this.cells.length ? this.cells[i] : '')
        .layoutWeight(1)
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontWeight(this.strong ? this.theme.text.weightMedium : this.theme.text.weightNormal)
        .fontColor(this.theme.colors.foreground)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 2, bottom: 2 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    if (this.table.cards) {
      Column() {
        ForEach(this.table.columns, (c: STableColumn, i: number) => {
          this.cardLine(i)
        }, (c: STableColumn, i: number) => `${i}:${c.key}`)
      }
      .width('100%')
      .padding(12)
      .margin({ top: this.kind === 'footer' ? 8 : 0 })
      .backgroundColor(this.rowBackground)
      .border({ width: this.theme.borderWidth, color: this.theme.colors.border, radius: this.theme.radiusLg })
      .accessibilityRole(AccessibilityRoleType.ROW)
      .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    } else {
      Row() {
        ForEach(this.table.columns, (c: STableColumn, i: number) => {
          this.cell(i)
        }, (c: STableColumn, i: number) => `${i}:${c.key}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.rowBackground)
      .border({
        width: {
          top: this.kind === 'footer' ? this.theme.borderWidth : 0,
          bottom: this.kind === 'footer' || this.last ? 0 : this.theme.borderWidth
        },
        color: this.theme.colors.border,
        radius: 0
      })
      .accessibilityRole(AccessibilityRoleType.ROW)
      .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    }
  }
}
