import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkTableColumnWidths, sparkTableTotal, sparkTableUseCards, STableColumn, TableAdaptive, TableAlignment
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

  get cards(): boolean {
    return sparkTableUseCards(this.adaptive, this.available, this.columns);
  }

  get widths(): number[] {
    return sparkTableColumnWidths(this.columns, this.available);
  }

  get total(): number {
    return sparkTableTotal(this.widths);
  }

  /** wider than the container: scroll horizontally */
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

/**
 * Ordered members (rows of a section, cells of a row). Members are ordered by component id, which grows in
 * build order, so a cell's index is its position in the row without the developer numbering it.
 */
@ObservedV2
export class SparkTableMembers {
  @Trace ids: number[] = [];
  @Trace kind: TableSectionKind = 'body';

  add(id: number): void {
    if (this.ids.indexOf(id) < 0) {
      const next = this.ids.slice();
      next.push(id);
      next.sort((a: number, b: number) => a - b);
      this.ids = next;
    }
  }

  remove(id: number): void {
    if (this.ids.indexOf(id) >= 0) {
      this.ids = this.ids.filter((x: number) => x !== id);
    }
  }

  indexOf(id: number): number {
    return this.ids.indexOf(id);
  }

  isLast(id: number): boolean {
    return this.ids.length > 0 && this.ids[this.ids.length - 1] === id;
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

  @Builder
  dataTable() {
    STableHeader() {
      STableRow() {
        ForEach(this.columns, (c: STableColumn, i: number) => {
          STableHead({ text: c.title, column: i })
        }, (c: STableColumn, i: number) => `${i}:${c.key}`)
      }
    }
    STableBody() {
      ForEach(this.rows ?? [], (r: string[], ri: number) => {
        STableRow() {
          ForEach(r, (v: string, i: number) => {
            STableCell({ text: v, column: i })
          }, (v: string, i: number) => `${i}:${v}`)
        }
      }, (r: string[], ri: number) => `${ri}:${r.join('\u0001')}`)
    }
    if (this.footer !== undefined) {
      STableFooter() {
        STableRow() {
          ForEach(this.footer, (v: string, i: number) => {
            STableCell({ text: v, column: i })
          }, (v: string, i: number) => `${i}:${v}`)
        }
      }
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
