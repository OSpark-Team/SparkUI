/**
 * Fuzzy match score used by `SCommand` filtering (cmdk-like). Pure and unit-tested.
 *
 * Returns 0 when `query` does not match, otherwise a value in (0, 1]; higher is better:
 * - empty query → 1 (everything matches)
 * - exact match → 1, prefix → 0.9, word-start substring → 0.8, substring → 0.7
 * - case-insensitive subsequence ("gtl" ⊂ "Go to line") → (0, 0.6], favouring compact runs and
 *   letters that start words
 * Keywords are matched the same way at 0.95× the weight of the text.
 */
export function sparkCommandScore(query: string, text: string, keywords?: string[]): number {
  const q = query.trim().toLowerCase();
  if (q.length === 0) {
    return 1;
  }
  let best = scoreOne(q, text.toLowerCase());
  if (keywords !== undefined) {
    for (let i = 0; i < keywords.length; i++) {
      const k = scoreOne(q, keywords[i].toLowerCase()) * 0.95;
      if (k > best) {
        best = k;
      }
    }
  }
  return best;
}

function isBoundary(ch: string): boolean {
  return ch === ' ' || ch === '-' || ch === '_' || ch === '/' || ch === '.' || ch === ':';
}

function scoreOne(q: string, s: string): number {
  if (s.length === 0 || q.length > s.length) {
    return 0;
  }
  if (s === q) {
    return 1;
  }
  if (s.startsWith(q)) {
    return 0.9;
  }
  const idx = s.indexOf(q);
  if (idx > 0) {
    return isBoundary(s.charAt(idx - 1)) ? 0.8 : 0.7;
  }
  // subsequence
  let pos = 0;
  let last = -1;
  let gaps = 0;
  let starts = 0;
  for (let i = 0; i < q.length; i++) {
    const c = q.charAt(i);
    if (c === ' ') {
      continue;
    }
    const found = s.indexOf(c, pos);
    if (found < 0) {
      return 0;
    }
    if (last >= 0) {
      gaps += found - last - 1;
    }
    if (found === 0 || isBoundary(s.charAt(found - 1))) {
      starts++;
    }
    last = found;
    pos = found + 1;
  }
  const letters = q.replace(/ /g, '').length;
  if (letters === 0) {
    return 0;
  }
  const compact = letters / (letters + gaps);
  const wordStarts = starts / letters;
  return Math.min(0.6, 0.05 + 0.3 * compact + 0.25 * wordStarts);
}
