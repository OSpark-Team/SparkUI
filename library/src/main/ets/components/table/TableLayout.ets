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
