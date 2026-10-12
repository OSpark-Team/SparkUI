/**
 * Pure logic of the data mode of `SCommand` (ADR D14): the item data class, filtering into list rows with group
 * headings, and lookups. No UI imports, so it is unit-tested directly (test/Command.test.ets).
 */
import { SparkOptionEntry, sparkOptionIndexOf } from '../../primitives/list/SparkOptionLogic';
import { sparkCommandScore } from './CommandScore';

/** Fields of a `SparkCommandEntryData` (everything but `value` is optional). */
export interface SparkCommandEntryInit {
  /** identity (unique in the array): highlight, selection and the row key */
  value: string;
  /** shown text, matched against the query (default: `value`) */
  label?: string;
  /** group heading; consecutive items with the same group share one heading */
  group?: string;
  /** leading icon name (SIcon) */
  icon?: string;
  /** trailing shortcut hint, e.g. '⌘P' */
  shortcut?: string;
  /** extra search terms */
  keywords?: string[];
  disabled?: boolean;
  /** per-item activation callback (in addition to `SCommand.onItemSelect`) */
  onSelect?: (value: string) => void;
}

/** One item of `SCommand({ items })`. */
export class SparkCommandEntryData {
  readonly value: string;
  readonly label: string;
  readonly group: string | undefined;
  readonly icon: string | undefined;
  readonly shortcut: string | undefined;
  readonly keywords: string[];
  readonly disabled: boolean;
  readonly onSelect: ((value: string) => void) | undefined;

  constructor(init: SparkCommandEntryInit) {
    this.value = init.value;
    this.label = init.label ?? init.value;
    this.group = init.group;
    this.icon = init.icon;
    this.shortcut = init.shortcut;
    this.keywords = init.keywords ?? [];
    this.disabled = init.disabled === true;
    this.onSelect = init.onSelect;
  }
}

/**
 * A row of the virtualized command list: an item (`kind` 'option') or a group heading ('label'). It is a
 * `SparkOptionEntry`, so `sparkOptionStep` / `sparkOptionIndexOf` / sizing work on it unchanged. Keys are stable
 * across filtering: `o:<value>` for items, `g:<index of the first item of the group run>` for headings.
 */
export class SparkCommandRow extends SparkOptionEntry {
  readonly icon: string | undefined;
  readonly shortcut: string | undefined;
  /** the item (undefined for headings) */
  readonly item: SparkCommandEntryData | undefined;

  constructor(key: string, item: SparkCommandEntryData | undefined, heading?: string) {
    super(key, item === undefined ? 'label' : 'option', item === undefined ? '' : item.value,
      item === undefined ? (heading ?? '') : item.label, item === undefined ? true : item.disabled);
    this.icon = item === undefined ? undefined : item.icon;
    this.shortcut = item === undefined ? undefined : item.shortcut;
    this.item = item;
  }
}

/** Placeholder row (default of row params). */
export const SPARK_EMPTY_COMMAND_ROW: SparkCommandRow = new SparkCommandRow('', undefined, '');

/** Whether `item` passes `query` (cmdk scoring on the label and the keywords). */
export function sparkCommandMatches(item: SparkCommandEntryData, query: string): boolean {
  return sparkCommandScore(query, item.label, item.keywords) > 0;
}

/**
 * Flatten `items` into list rows: a heading before the first *shown* item of each run of items sharing a group,
 * then the items. With `filter` (default) only items matching `query` are kept, in document order (filtered, not
 * re-sorted); a group with no match shows no heading. O(n).
 */
export function sparkCommandEntries(items: SparkCommandEntryData[], query: string,
  filter?: boolean): SparkCommandRow[] {
  const q = query.trim();
  const filtering = filter !== false && q.length > 0;
  const out: SparkCommandRow[] = [];
  let group: string | undefined = undefined;
  let groupStart = -1;
  let headingShown = true;
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    if (i === 0 || it.group !== group) {
      group = it.group;
      groupStart = i;
      headingShown = group === undefined;
    }
    if (filtering && !sparkCommandMatches(it, q)) {
      continue;
    }
    if (!headingShown) {
      out.push(new SparkCommandRow(`g:${groupStart}`, undefined, group));
      headingShown = true;
    }
    out.push(new SparkCommandRow(`o:${it.value}`, it));
  }
  return out;
}

/** The enabled item with `value` among the rows (undefined when absent or disabled). */
export function sparkCommandItemOf(rows: SparkCommandRow[], value: string): SparkCommandEntryData | undefined {
  const i = sparkOptionIndexOf(rows, value);
  if (i < 0) {
    return undefined;
  }
  const item = rows[i].item;
  return item === undefined || item.disabled ? undefined : item;
}
