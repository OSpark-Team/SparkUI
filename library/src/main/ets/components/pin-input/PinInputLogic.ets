export type PinPattern = 'digits' | 'alphanumeric';

/** Keeps only characters allowed by `pattern` and cuts the result to `length`. */
export function sparkPinSanitize(text: string, pattern: PinPattern, length: number): string {
  const re: RegExp = pattern === 'digits' ? /[^0-9]/g : /[^0-9A-Za-z]/g;
  const clean = text.replace(re, '');
  return clean.substring(0, Math.max(0, Math.floor(length)));
}

/**
 * Slot counts per group. `groups` must add up to `length` (e.g. [3, 3] for 6); otherwise a single group of
 * `length` slots is used.
 */
export function sparkPinGroups(length: number, groups: number[] | undefined): number[] {
  const n = Math.max(0, Math.floor(length));
  if (groups === undefined || groups.length === 0) {
    return [n];
  }
  let sum = 0;
  for (let i = 0; i < groups.length; i++) {
    const g = Math.floor(groups[i]);
    if (g <= 0) {
      return [n];
    }
    sum += g;
  }
  return sum === n ? groups.map((g: number) => Math.floor(g)) : [n];
}

/** Index of the active slot: the next empty one, or the last slot when the value is complete. */
export function sparkPinActiveIndex(valueLength: number, length: number): number {
  if (length <= 0) {
    return -1;
  }
  return Math.min(valueLength, length - 1);
}

/** Slot size (vp) that fits `available`: 36 (shadcn w-9) shrinking to 28 at most. */
export function sparkPinSlotSize(available: number, length: number, groupCount: number): number {
  if (available <= 0 || length <= 0) {
    return 36;
  }
  // each separator: icon 16 + gap 8 on both sides
  const separators = Math.max(0, groupCount - 1) * 32;
  const fit = Math.floor((available - separators) / length);
  return Math.max(28, Math.min(36, fit));
}
