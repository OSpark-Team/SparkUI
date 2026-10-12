/** Number of digits after the decimal point of `n` (`0.25` → 2, `1e-3` → 3). */
export function sparkDecimalsOf(n: number): number {
  if (!isFinite(n) || Math.floor(n) === n) {
    return 0;
  }
  const s = String(n);
  const e = s.indexOf('e-');
  if (e >= 0) {
    return parseInt(s.substring(e + 2), 10);
  }
  const dot = s.indexOf('.');
  return dot < 0 ? 0 : s.length - dot - 1;
}

/** Round `v` to `decimals` places without binary drift (`0.1 + 0.2` → `0.3`). */
export function sparkRoundTo(v: number, decimals: number): number {
  const d = Math.max(0, Math.min(10, Math.floor(decimals)));
  const k = Math.pow(10, d);
  return Math.round(v * k) / k;
}

/** Clamp to [min, max]; either bound may be undefined (open). NaN → min ?? 0. */
export function sparkNumberClamp(v: number, min: number | undefined, max: number | undefined): number {
  let r = isNaN(v) ? (min ?? 0) : v;
  if (min !== undefined && r < min) {
    r = min;
  }
  if (max !== undefined && r > max) {
    r = max;
  }
  return r;
}

/**
 * Value after one increment (`direction` 1) or decrement (-1): adds `step`, rounds to the precision of
 * `step` / `decimals` and clamps. A non-positive step counts as 1.
 */
export function sparkNumberStep(v: number, step: number, direction: number, min: number | undefined,
  max: number | undefined, decimals?: number): number {
  const s = step > 0 ? step : 1;
  const precision = Math.max(sparkDecimalsOf(s), decimals ?? 0);
  const next = sparkRoundTo(v + (direction < 0 ? -s : s), precision);
  return sparkNumberClamp(next, min, max);
}

/** Parse user text: accepts `-`, `.` or `,` as decimal separator, ignores spaces. Undefined when invalid. */
export function sparkNumberParse(text: string): number | undefined {
  const t = text.replace(/\s/g, '').replace(',', '.');
  if (t.length === 0 || !/^[-+]?(\d+\.?\d*|\.\d+)$/.test(t)) {
    return undefined;
  }
  const n = parseFloat(t);
  return isNaN(n) ? undefined : n;
}

/** Display text: fixed `decimals` when given, otherwise the shortest form. */
export function sparkNumberFormat(v: number, decimals?: number): string {
  if (decimals !== undefined && decimals >= 0) {
    return sparkRoundTo(v, decimals).toFixed(Math.min(10, Math.floor(decimals)));
  }
  return String(v);
}
