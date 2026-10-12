/** Marker for an ellipsis slot in {@link sparkPaginationRange}'s result. */
export const SPARK_PAGINATION_ELLIPSIS: number = -1;

function span(from: number, to: number): number[] {
  const out: number[] = [];
  for (let i = from; i <= to; i++) {
    out.push(i);
  }
  return out;
}

/**
 * Page items to render for a pagination control (1-based pages; `-1` = ellipsis). Same algorithm as
 * MUI's `usePagination` with one boundary page on each side:
 *
 * - always shows the first and last page, the current page and `siblings` pages on each side;
 * - an ellipsis never hides a single page — that page is shown instead (`1 2 3 … 20`, not `1 … 3 … 20`);
 * - the number of slots stays constant (`2 × siblings + 5`) while paging, so the control does not jump.
 *
 * ```
 * sparkPaginationRange(3, 20, 0)  // [1, 2, 3, -1, 20]
 * sparkPaginationRange(10, 20, 1) // [1, -1, 9, 10, 11, -1, 20]
 * ```
 */
export function sparkPaginationRange(page: number, total: number, siblings: number): number[] {
  const count = Math.floor(total);
  if (count <= 0) {
    return [];
  }
  const s = Math.max(0, Math.floor(siblings));
  const current = Math.min(Math.max(1, Math.floor(page)), count);
  if (count <= 2 * s + 5) {
    return span(1, count);
  }
  const boundary = 1;
  const siblingsStart = Math.max(Math.min(current - s, count - boundary - s * 2 - 1), boundary + 2);
  const siblingsEnd = Math.min(Math.max(current + s, boundary + s * 2 + 2), count - boundary - 1);
  const out: number[] = [1];
  // left gap: an ellipsis, or the single page it would hide
  out.push(siblingsStart > boundary + 2 ? SPARK_PAGINATION_ELLIPSIS : boundary + 1);
  for (let p = siblingsStart; p <= siblingsEnd; p++) {
    out.push(p);
  }
  out.push(siblingsEnd < count - boundary - 1 ? SPARK_PAGINATION_ELLIPSIS : count - boundary);
  out.push(count);
  return out;
}

/** How many sibling pages fit in `width` vp (slots of `slot` vp incl. gap, minus fixed chrome). */
export function sparkPaginationSiblings(width: number, chrome: number, slot: number, maxSiblings: number): number {
  if (width <= 0) {
    return maxSiblings;
  }
  const slots = Math.floor((width - chrome) / slot);
  return Math.max(0, Math.min(maxSiblings, Math.floor((slots - 5) / 2)));
}
