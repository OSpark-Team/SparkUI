/** Result of splitting typed text at the delimiter. */
export class SparkTagsParse {
  /** complete tags (trimmed, non-empty) */
  tags: string[] = [];
  /** text after the last delimiter, still being typed */
  rest: string = '';
}

/**
 * Splits `text` at `delimiter`. Everything before the last delimiter becomes tags, the remainder stays in the
 * input. With `commit` (Enter / blur) the remainder becomes a tag too.
 *
 * ```
 * sparkTagsParse('vue, react,sv', ',', false) // tags ['vue', 'react'], rest 'sv'
 * ```
 */
export function sparkTagsParse(text: string, delimiter: string, commit: boolean): SparkTagsParse {
  const r = new SparkTagsParse();
  const parts = delimiter.length > 0 ? text.split(delimiter) : [text];
  const last = parts.length - 1;
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i].trim();
    if (i === last && !commit) {
      r.rest = parts[i].replace(/^\s+/, '');
    } else if (p.length > 0) {
      r.tags.push(p);
    }
  }
  return r;
}

/**
 * Appends `incoming` to `existing`, skipping duplicates (unless `allowDuplicates`) and stopping at `max`
 * (0 / undefined = no limit). Returns a new array.
 */
export function sparkTagsAdd(existing: string[], incoming: string[], max?: number,
  allowDuplicates?: boolean): string[] {
  const out = existing.slice();
  const limit = max !== undefined && max > 0 ? max : Number.MAX_SAFE_INTEGER;
  for (let i = 0; i < incoming.length; i++) {
    const t = incoming[i].trim();
    if (t.length === 0 || out.length >= limit) {
      continue;
    }
    if (allowDuplicates !== true && out.indexOf(t) >= 0) {
      continue;
    }
    out.push(t);
  }
  return out;
}

/** Copy of `tags` without the item at `index` (unchanged copy when out of range). */
export function sparkTagsRemoveAt(tags: string[], index: number): string[] {
  const out = tags.slice();
  if (index >= 0 && index < out.length) {
    out.splice(index, 1);
  }
  return out;
}
