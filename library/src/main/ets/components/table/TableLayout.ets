export type TableAlignment = 'start' | 'center' | 'end';
export type TableAdaptive = 'auto' | 'table' | 'cards';

/** Options of an {@link STableColumn}. */
export interface STableColumnOptions {
  /** Share of the remaining width (default 1). Ignored when `fixedWidth` is set. */
  weight?: number;
  /** Fixed width in vp. */
  fixedWidth?: number;
  /** Smallest width (vp) a weighted column may shrink to (default 96). */
  minWidth?: number;
  alignment?: TableAlignment;
}

/**
 * A table column: key, header title and sizing. ArkUI cannot size arbitrary slot children, so the table owns
 * the column widths and every cell reads its width by index.
 *
 * ```
 * new STableColumn('invoice', 'Invoice', { fixedWidth: 100 })
 * new STableColumn('method', 'Method', { weight: 2 })
 * new STableColumn('amount', 'Amount', { alignment: 'end' })
 * ```
 */
export class STableColumn {
  key: string;
  title: string;
  weight: number = 1;
  fixedWidth: number | undefined = undefined;
  minWidth: number = 96;
  alignment: TableAlignment = 'start';

  constructor(key: string, title: string, options?: STableColumnOptions) {
    this.key = key;
    this.title = title;
    if (options !== undefined) {
      if (options.weight !== undefined && options.weight > 0) {
        this.weight = options.weight;
      }
      if (options.fixedWidth !== undefined && options.fixedWidth >= 0) {
        this.fixedWidth = options.fixedWidth;
      }
      if (options.minWidth !== undefined && options.minWidth >= 0) {
        this.minWidth = options.minWidth;
      }
      if (options.alignment !== undefined) {
        this.alignment = options.alignment;
      }
    }
  }
}

/** Width a column needs at least: its fixed width, else its min width. */
export function sparkTableColumnMin(c: STableColumn): number {
  return c.fixedWidth !== undefined ? c.fixedWidth : c.minWidth;
}

/** Sum of the columns' minimum widths (the table's natural minimum). */
export function sparkTableMinWidth(columns: STableColumn[]): number {
  let sum = 0;
  columns.forEach((c: STableColumn) => {
    sum += sparkTableColumnMin(c);
  });
  return sum;
}

/**
 * Column widths for a table `available` vp wide: fixed columns keep their width, the rest share what is left
 * by weight without going below their min width (iteratively, so a clamped column frees its share for the
 * others). When the minimums do not fit, the sum exceeds `available` and the table scrolls horizontally.
 */
export function sparkTableColumnWidths(columns: STableColumn[], available: number): number[] {
  const n = columns.length;
  const out: number[] = new Array<number>(n).fill(0);
  let remaining = Math.max(0, available);
  const flexible: number[] = [];
  for (let i = 0; i < n; i++) {
    const c = columns[i];
    if (c.fixedWidth !== undefined) {
      out[i] = c.fixedWidth;
      remaining -= c.fixedWidth;
    } else {
      flexible.push(i);
    }
  }
  remaining = Math.max(0, remaining);
  let open = flexible.slice();
  // clamp columns whose weighted share is below their minimum, then redistribute
  let changed = true;
  while (changed && open.length > 0) {
    changed = false;
    let weights = 0;
    open.forEach((i: number) => {
      weights += columns[i].weight;
    });
    const next: number[] = [];
    for (let k = 0; k < open.length; k++) {
      const i = open[k];
      const share = weights > 0 ? remaining * columns[i].weight / weights : 0;
      if (share < columns[i].minWidth) {
        out[i] = columns[i].minWidth;
        changed = true;
      } else {
        next.push(i);
      }
    }
    if (changed) {
      open.forEach((i: number) => {
        if (next.indexOf(i) < 0) {
          remaining = Math.max(0, remaining - out[i]);
        }
      });
      open = next;
    } else {
      open.forEach((i: number) => {
        out[i] = weights > 0 ? remaining * columns[i].weight / weights : 0;
      });
    }
  }
  return out;
}

/** Card layout? `auto` switches to cards when the table is narrower than its columns' minimum widths. */
export function sparkTableUseCards(adaptive: TableAdaptive, available: number, columns: STableColumn[]): boolean {
  if (adaptive === 'cards') {
    return true;
  }
  if (adaptive === 'table' || available <= 0 || columns.length === 0) {
    return false;
  }
  return available + 0.5 < sparkTableMinWidth(columns);
}

/** Sum of widths. */
export function sparkTableTotal(widths: number[]): number {
  let s = 0;
  widths.forEach((w: number) => {
    s += w;
  });
  return s;
}

/** Lower bound: first index in ascending `ids` whose value is >= `id` (binary search, O(log n)). */
export function sparkSortedIndex(ids: number[], id: number): number {
  let lo = 0;
  let hi = ids.length;
  while (lo < hi) {
    const mid = (lo + hi) >>> 1;
    if (ids[mid] < id) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/** Rows a data table renders before its body scrolls internally when no `bodyHeight` is given (ADR D14). */
export const SPARK_TABLE_VIRTUAL_THRESHOLD: number = 50;
/** Default body viewport (vp) of a data table above the threshold. */
export const SPARK_TABLE_BODY_HEIGHT: number = 480;
/** Smallest possible body row height (vp): `p-2` + one `text-sm` line. */
export const SPARK_TABLE_MIN_ROW_HEIGHT: number = 36;

/**
 * Body viewport of a data table: `bodyHeight` when given, else {@link SPARK_TABLE_BODY_HEIGHT} above
 * {@link SPARK_TABLE_VIRTUAL_THRESHOLD} rows, else unlimited (Infinity: the body is as tall as its rows).
 */
export function sparkTableBodyMax(rowCount: number, bodyHeight: number | undefined): number {
  if (bodyHeight !== undefined && bodyHeight > 0) {
    return bodyHeight;
  }
  return rowCount > SPARK_TABLE_VIRTUAL_THRESHOLD ? SPARK_TABLE_BODY_HEIGHT : Infinity;
}

/**
 * Fixed body height when the rows certainly overflow the viewport (so the virtualized List has a definite main
 * size and builds only visible rows); 0 when the body may be shorter and should follow its content.
 */
export function sparkTableBodyFixed(rowCount: number, bodyMax: number): number {
  if (!isFinite(bodyMax)) {
    return 0;
  }
  return rowCount * SPARK_TABLE_MIN_ROW_HEIGHT >= bodyMax ? bodyMax : 0;
}
