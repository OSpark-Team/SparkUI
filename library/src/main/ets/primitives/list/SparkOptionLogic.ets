/**
 * Pure logic of the virtualized option list (ADR D14): flattening options into rows, filtering, keyboard
 * stepping and sizing. No UI imports, so it is unit-tested directly (test/List.test.ets → VirtualList).
 */

/** A data option shown by a virtualized option list (implemented by `SparkSelectOption`). */
export interface SparkOptionSource {
  value: string;
  label: string;
  disabled: boolean;
  /** group heading this option starts (undefined: continues the current group) */
  group: string | undefined;
}

export type SparkOptionEntryKind = 'option' | 'label';

/**
 * One row of a virtualized option list: an option or a group heading. `key` is stable across filtering
 * (`o:<value>` / `g:<index of the option that starts the group>`), so `Repeat` reuses rows instead of
 * rebuilding them when the query changes.
 */
export class SparkOptionEntry {
  readonly key: string;
  readonly kind: SparkOptionEntryKind;
  readonly value: string;
  readonly label: string;
  readonly disabled: boolean;

  constructor(key: string, kind: SparkOptionEntryKind, value: string, label: string, disabled: boolean) {
    this.key = key;
    this.kind = kind;
    this.value = value;
    this.label = label;
    this.disabled = disabled;
  }
}

/** Placeholder entry (default of row params). */
export const SPARK_EMPTY_OPTION_ENTRY: SparkOptionEntry = new SparkOptionEntry('', 'option', '', '', true);

/**
 * Flatten options into list rows: a heading row before the first *shown* option of each group, then the
 * options. `match` filters options (document order is kept); a group whose options are all filtered out
 * shows no heading. O(n).
 */
export function sparkOptionEntries(options: SparkOptionSource[],
  match?: (o: SparkOptionSource) => boolean): SparkOptionEntry[] {
  const out: SparkOptionEntry[] = [];
  let heading: string | undefined = undefined;
  let headingIndex = -1;
  let headingShown = true;
  for (let i = 0; i < options.length; i++) {
    const o = options[i];
    if (o.group !== undefined) {
      heading = o.group;
      headingIndex = i;
      headingShown = false;
    }
    if (match !== undefined && !match(o)) {
      continue;
    }
    if (!headingShown && heading !== undefined) {
      out.push(new SparkOptionEntry(`g:${headingIndex}`, 'label', '', heading, true));
      headingShown = true;
    }
    out.push(new SparkOptionEntry(`o:${o.value}`, 'option', o.value, o.label, o.disabled));
  }
  return out;
}

/** Row index of the option with `value` (-1 when absent). */
export function sparkOptionIndexOf(entries: SparkOptionEntry[], value: string): number {
  if (value.length === 0) {
    return -1;
  }
  for (let i = 0; i < entries.length; i++) {
    if (entries[i].kind === 'option' && entries[i].value === value) {
      return i;
    }
  }
  return -1;
}

/** Value of the first enabled option ('' when none). */
export function sparkOptionFirst(entries: SparkOptionEntry[]): string {
  return sparkOptionStep(entries, '', 1, 'first');
}

/**
 * Keyboard highlight step: the value of the enabled option `delta` rows away from `current` (wrapping, skipping
 * headings and disabled options), or the first / last enabled option. '' when nothing is selectable.
 */
export function sparkOptionStep(entries: SparkOptionEntry[], current: string, delta: number,
  edge?: 'first' | 'last'): string {
  const n = entries.length;
  const ok = (i: number): boolean => entries[i].kind === 'option' && !entries[i].disabled;
  if (edge === 'first') {
    for (let i = 0; i < n; i++) {
      if (ok(i)) {
        return entries[i].value;
      }
    }
    return '';
  }
  if (edge === 'last') {
    for (let i = n - 1; i >= 0; i--) {
      if (ok(i)) {
        return entries[i].value;
      }
    }
    return '';
  }
  const cur = sparkOptionIndexOf(entries, current);
  if (cur < 0) {
    return sparkOptionStep(entries, '', 0, delta >= 0 ? 'first' : 'last');
  }
  const dir = delta >= 0 ? 1 : -1;
  let steps = Math.max(1, Math.abs(delta));
  let i = cur;
  for (let guard = 0; guard < n; guard++) {
    i = (i + dir + n) % n;
    if (ok(i)) {
      steps--;
      if (steps === 0) {
        return entries[i].value;
      }
    }
  }
  return ok(cur) ? entries[cur].value : '';
}

/** Natural height of the rows (vp), capped at `max`. */
export function sparkOptionListHeight(entries: SparkOptionEntry[], rowHeight: number, labelHeight: number,
  max: number): number {
  let h = 0;
  for (let i = 0; i < entries.length; i++) {
    h += entries[i].kind === 'label' ? labelHeight : rowHeight;
    if (h >= max) {
      return max;
    }
  }
  return h;
}

/** Main-axis size of every row, for `List.childrenMainSize` (exact scrollbar / scrollToIndex). */
export function sparkOptionSizes(entries: SparkOptionEntry[], rowHeight: number, labelHeight: number): number[] {
  return entries.map((e: SparkOptionEntry) => e.kind === 'label' ? labelHeight : rowHeight);
}
