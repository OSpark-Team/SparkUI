/**
 * Pure chart maths for SparkUI charts: ticks, scales, stacking, pie angles, SVG path builders and hit testing.
 * No ArkUI imports — everything here is unit tested (library/src/test/Chart.test.ets).
 *
 * Conventions:
 * - coordinates are in vp; path builders multiply by `k` (vp → px ratio) because `Path.commands` is in px.
 * - polar angles are radians, 0 at 12 o'clock, growing clockwise (like Recharts with startAngle 90 → -270).
 */

/** Curve interpolation of line / area series (shadcn: `type="natural" | "linear" | "step"`). */
export type SparkChartCurve = 'linear' | 'monotone' | 'step';

const E10: number = Math.sqrt(50);
const E5: number = Math.sqrt(10);
const E2: number = Math.sqrt(2);
const TAU: number = Math.PI * 2;
const EPS: number = 1e-9;

// ------------------------------------------------------------------------------------------------ numbers

function decimalsOf(step: number): number {
  if (!(step > 0) || !isFinite(step)) {
    return 0;
  }
  return Math.max(0, -Math.floor(Math.log(step) / Math.LN10 + EPS));
}

function roundTo(v: number, decimals: number): number {
  return parseFloat(v.toFixed(Math.min(20, decimals)));
}

/** d3 `tickIncrement`-like step: 1, 2 or 5 × 10^k so that about `count` ticks span [start, stop]. */
export function sparkTickStep(start: number, stop: number, count: number): number {
  const span = Math.abs(stop - start);
  if (!(span > 0) || !(count > 0) || !isFinite(span)) {
    return 0;
  }
  const step0 = span / count;
  let step1 = Math.pow(10, Math.floor(Math.log(step0) / Math.LN10));
  const error = step0 / step1;
  if (error >= E10) {
    step1 *= 10;
  } else if (error >= E5) {
    step1 *= 5;
  } else if (error >= E2) {
    step1 *= 2;
  }
  return roundTo(step1, decimalsOf(step1) + 2);
}

/**
 * Extend [min, max] to round tick boundaries (d3 `scale.nice()`); degenerate ranges are widened:
 * [0, 0] → [0, 1], [v, v] → [0, v] (v > 0) or [v, 0] (v < 0).
 */
export function sparkNiceDomain(min: number, max: number, count: number): number[] {
  let lo = Math.min(min, max);
  let hi = Math.max(min, max);
  if (!isFinite(lo) || !isFinite(hi)) {
    return [0, 1];
  }
  if (lo === hi) {
    if (lo === 0) {
      return [0, 1];
    }
    if (lo > 0) {
      lo = 0;
    } else {
      hi = 0;
    }
  }
  let prev = 0;
  for (let i = 0; i < 10; i++) {
    const step = sparkTickStep(lo, hi, count);
    if (step <= 0 || step === prev) {
      break;
    }
    const d = decimalsOf(step);
    lo = roundTo(Math.floor(lo / step + EPS) * step, d);
    hi = roundTo(Math.ceil(hi / step - EPS) * step, d);
    prev = step;
  }
  return [lo, hi];
}

/** Round tick values inside [min, max] (d3 `ticks`). */
export function sparkNiceTicks(min: number, max: number, count: number): number[] {
  const lo = Math.min(min, max);
  const hi = Math.max(min, max);
  const step = sparkTickStep(lo, hi, count);
  if (step <= 0) {
    return isFinite(lo) ? [lo] : [];
  }
  const d = decimalsOf(step);
  const i0 = Math.ceil(lo / step - EPS);
  const i1 = Math.floor(hi / step + EPS);
  const out: number[] = [];
  for (let i = i0; i <= i1; i++) {
    out.push(roundTo(i * step, d));
  }
  return out;
}

/** Value domain of a chart: data extent, optionally including 0, made nice. */
export function sparkValueDomain(values: number[], includeZero: boolean, count: number): number[] {
  let lo = Number.POSITIVE_INFINITY;
  let hi = Number.NEGATIVE_INFINITY;
  for (const v of values) {
    if (isFinite(v)) {
      lo = Math.min(lo, v);
      hi = Math.max(hi, v);
    }
  }
  if (lo > hi) {
    return [0, 1];
  }
  if (includeZero) {
    lo = Math.min(lo, 0);
    hi = Math.max(hi, 0);
  }
  return sparkNiceDomain(lo, hi, count);
}

/** Axis tick count that fits the available length (≈ one tick per `spacing` vp), clamped to [min, max]. */
export function sparkTickCount(length: number, spacing: number, min: number, max: number): number {
  if (!(length > 0) || !(spacing > 0)) {
    return min;
  }
  return Math.max(min, Math.min(max, Math.round(length / spacing)));
}

/** Show every n-th category label so labels of width `labelWidth` do not overlap over `span` vp. */
export function sparkLabelStep(count: number, span: number, labelWidth: number): number {
  if (count <= 1 || !(span > 0)) {
    return 1;
  }
  const per = span / count;
  return Math.max(1, Math.ceil(labelWidth / Math.max(per, 1)));
}

/** "1,234.5" — thousands separators, at most `decimals` fraction digits (trailing zeros trimmed). */
export function sparkChartFormat(v: number, decimals?: number): string {
  if (!isFinite(v)) {
    return '';
  }
  const d = decimals ?? 2;
  const neg = v < 0;
  let s = Math.abs(v).toFixed(d);
  if (s.indexOf('.') >= 0) {
    s = s.replace(/0+$/, '').replace(/\.$/, '');
  }
  const dot = s.indexOf('.');
  const intPart = dot >= 0 ? s.substring(0, dot) : s;
  const frac = dot >= 0 ? s.substring(dot) : '';
  let grouped = '';
  for (let i = 0; i < intPart.length; i++) {
    const fromEnd = intPart.length - i;
    grouped += intPart.charAt(i);
    if (fromEnd > 1 && (fromEnd - 1) % 3 === 0) {
      grouped += ',';
    }
  }
  return (neg && (grouped + frac) !== '0' ? '-' : '') + grouped + frac;
}

/** Compact axis label: 950, 1.2k, 3.4M, 1.1B. */
export function sparkChartCompact(v: number): string {
  const a = Math.abs(v);
  if (a >= 1e9) {
    return sparkChartFormat(v / 1e9, 1) + 'B';
  }
  if (a >= 1e6) {
    return sparkChartFormat(v / 1e6, 1) + 'M';
  }
  if (a >= 1e3) {
    return sparkChartFormat(v / 1e3, 1) + 'k';
  }
  return sparkChartFormat(v, 2);
}

// ------------------------------------------------------------------------------------------------ scales

/** Linear scale: domain [d0, d1] → range [r0, r1]. */
export class SparkLinearScale {
  d0: number;
  d1: number;
  r0: number;
  r1: number;

  constructor(d0: number, d1: number, r0: number, r1: number) {
    this.d0 = d0;
    this.d1 = d1;
    this.r0 = r0;
    this.r1 = r1;
  }

  map(v: number): number {
    if (this.d1 === this.d0) {
      return (this.r0 + this.r1) / 2;
    }
    return this.r0 + (v - this.d0) / (this.d1 - this.d0) * (this.r1 - this.r0);
  }

  invert(p: number): number {
    if (this.r1 === this.r0) {
      return (this.d0 + this.d1) / 2;
    }
    return this.d0 + (p - this.r0) / (this.r1 - this.r0) * (this.d1 - this.d0);
  }

  /** map() clamped to the range (e.g. the baseline of a chart whose domain does not include 0). */
  mapClamped(v: number): number {
    const p = this.map(v);
    return Math.max(Math.min(this.r0, this.r1), Math.min(Math.max(this.r0, this.r1), p));
  }
}

/** Band scale (d3 `scaleBand`, align 0.5): `count` equal bands over [r0, r1]. */
export class SparkBandScale {
  count: number;
  step: number;
  bandwidth: number;
  offset: number;

  constructor(count: number, r0: number, r1: number, paddingInner: number, paddingOuter: number) {
    this.count = Math.max(0, count);
    const n = this.count;
    this.step = (r1 - r0) / Math.max(1, n - paddingInner + paddingOuter * 2);
    this.offset = r0 + (r1 - r0 - this.step * (n - paddingInner)) * 0.5;
    this.bandwidth = this.step * (1 - paddingInner);
  }

  /** start of band i */
  start(i: number): number {
    return this.offset + this.step * i;
  }

  center(i: number): number {
    return this.start(i) + this.bandwidth / 2;
  }

  centers(): number[] {
    const out: number[] = [];
    for (let i = 0; i < this.count; i++) {
      out.push(this.center(i));
    }
    return out;
  }
}

/** Point scale: n points spread edge to edge over [r0, r1] (a single point sits in the middle). */
export function sparkPointPositions(n: number, r0: number, r1: number): number[] {
  const out: number[] = [];
  if (n <= 0) {
    return out;
  }
  if (n === 1) {
    out.push((r0 + r1) / 2);
    return out;
  }
  const step = (r1 - r0) / (n - 1);
  for (let i = 0; i < n; i++) {
    out.push(r0 + step * i);
  }
  return out;
}

/** Index of the position closest to p (positions sorted ascending); -1 when empty. */
export function sparkNearestIndex(positions: number[], p: number): number {
  const n = positions.length;
  if (n === 0) {
    return -1;
  }
  let lo = 0;
  let hi = n - 1;
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    if (positions[mid] <= p) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return Math.abs(positions[lo] - p) <= Math.abs(positions[hi] - p) ? lo : hi;
}

// ------------------------------------------------------------------------------------------------ stacking

/** Lower / upper edges per series and index (`values[series][index]`). */
export class SparkStack {
  lower: number[][] = [];
  upper: number[][] = [];
}

/**
 * Diverging stack (d3 `stackOffsetDiverging`): positives grow up from 0, negatives grow down from 0,
 * series stacked in order. Non-finite values count as 0.
 */
export function sparkStack(values: number[][]): SparkStack {
  const res = new SparkStack();
  let n = 0;
  for (const s of values) {
    n = Math.max(n, s.length);
  }
  const pos: number[] = [];
  const neg: number[] = [];
  for (let i = 0; i < n; i++) {
    pos.push(0);
    neg.push(0);
  }
  for (const s of values) {
    const lo: number[] = [];
    const up: number[] = [];
    for (let i = 0; i < n; i++) {
      const raw = i < s.length ? s[i] : 0;
      const v = isFinite(raw) ? raw : 0;
      if (v >= 0) {
        lo.push(pos[i]);
        pos[i] += v;
        up.push(pos[i]);
      } else {
        up.push(neg[i]);
        neg[i] += v;
        lo.push(neg[i]);
      }
    }
    res.lower.push(lo);
    res.upper.push(up);
  }
  return res;
}

// ------------------------------------------------------------------------------------------------ polar

/** One pie / donut slice: angles in radians (0 = 12 o'clock, clockwise). */
export class SparkArc {
  index: number;
  value: number;
  a0: number;
  a1: number;

  constructor(index: number, value: number, a0: number, a1: number) {
    this.index = index;
    this.value = value;
    this.a0 = a0;
    this.a1 = a1;
  }
}

/**
 * Pie layout (d3 `pie`, data order kept): slices proportional to the values over [start, end],
 * `pad` radians of gap per slice (split on both sides). Negative / non-finite values count as 0.
 */
export function sparkPieArcs(values: number[], start: number, end: number, pad: number): SparkArc[] {
  const out: SparkArc[] = [];
  const span = end - start;
  let sum = 0;
  let nonZero = 0;
  for (const v of values) {
    if (isFinite(v) && v > 0) {
      sum += v;
      nonZero++;
    }
  }
  const pa = nonZero > 0 ? Math.min(Math.abs(span) / nonZero, Math.max(0, pad)) : 0;
  const k = sum > 0 ? (span - nonZero * pa) / sum : 0;
  let a = start;
  for (let i = 0; i < values.length; i++) {
    const raw = values[i];
    const v = isFinite(raw) && raw > 0 ? raw : 0;
    if (v === 0) {
      out.push(new SparkArc(i, 0, a, a));
      continue;
    }
    const a1 = a + v * k + pa;
    out.push(new SparkArc(i, v, a + pa / 2, a1 - pa / 2));
    a = a1;
  }
  return out;
}

/** Point at radius r, angle a (0 = 12 o'clock, clockwise) around (cx, cy). */
export function sparkPolar(cx: number, cy: number, r: number, a: number): number[] {
  return [cx + r * Math.sin(a), cy - r * Math.cos(a)];
}

/** Angle of (x, y) around (cx, cy) in [0, 2π), 0 = 12 o'clock, clockwise. */
export function sparkAngleOf(cx: number, cy: number, x: number, y: number): number {
  let a = Math.atan2(x - cx, cy - y);
  if (a < 0) {
    a += TAU;
  }
  return a;
}

/** Spoke index of a radar with n spokes nearest to (x, y). */
export function sparkSpokeIndex(cx: number, cy: number, n: number, x: number, y: number): number {
  if (n <= 0) {
    return -1;
  }
  const a = sparkAngleOf(cx, cy, x, y);
  return Math.round(a / (TAU / n)) % n;
}

/** Slice under (x, y), or -1. `r0`/`r1` are the inner / outer radius; `slack` widens the ring. */
export function sparkArcIndex(arcs: SparkArc[], cx: number, cy: number, r0: number, r1: number, x: number,
  y: number, slack: number): number {
  const d = Math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
  if (d < r0 - slack || d > r1 + slack) {
    return -1;
  }
  const a = sparkAngleOf(cx, cy, x, y);
  for (const arc of arcs) {
    if (arc.a1 - arc.a0 <= EPS) {
      continue;
    }
    // compare in the arc's own turn so arcs that start after 0 or wrap past 2π still match
    let t = a;
    while (t < arc.a0) {
      t += TAU;
    }
    while (t - TAU >= arc.a0) {
      t -= TAU;
    }
    if (t <= arc.a1) {
      return arc.index;
    }
  }
  return -1;
}

/** Concentric ring under distance d from the centre (rings of equal width between r0 and r1), or -1. */
export function sparkRingIndex(count: number, r0: number, r1: number, d: number): number {
  if (count <= 0 || d < r0 || d > r1 || r1 <= r0) {
    return -1;
  }
  return Math.min(count - 1, Math.floor((d - r0) / ((r1 - r0) / count)));
}

/** Tooltip box position next to an anchor, flipped / clamped to stay inside the chart box. Returns [x, y]. */
export function sparkTooltipPlace(ax: number, ay: number, tw: number, th: number, bw: number, bh: number,
  gap: number): number[] {
  let x = ax + gap;
  if (x + tw > bw) {
    x = ax - gap - tw;
  }
  if (x < 0) {
    x = Math.max(0, Math.min(bw - tw, ax - tw / 2));
  }
  let y = ay - th / 2;
  y = Math.max(0, Math.min(Math.max(0, bh - th), y));
  return [x, y];
}

// ------------------------------------------------------------------------------------------------ paths

/** Number for a path command: px, at most 2 decimals. */
function f(v: number): string {
  const r = Math.round(v * 100) / 100;
  return (r === 0 ? 0 : r).toString();
}

function monotoneSlope3(x0: number, y0: number, x1: number, y1: number, x2: number, y2: number): number {
  const h0 = x1 - x0;
  const h1 = x2 - x1;
  const s0 = h0 !== 0 ? (y1 - y0) / h0 : 0;
  const s1 = h1 !== 0 ? (y2 - y1) / h1 : 0;
  const p = h0 + h1 !== 0 ? (s0 * h1 + s1 * h0) / (h0 + h1) : 0;
  const r = (Math.sign(s0) + Math.sign(s1)) * Math.min(Math.abs(s0), Math.abs(s1), 0.5 * Math.abs(p));
  return isFinite(r) ? r : 0;
}

function monotoneSlope2(x0: number, y0: number, x1: number, y1: number, t: number): number {
  const h = x1 - x0;
  return h !== 0 ? (3 * (y1 - y0) / h - t) / 2 : t;
}

/** Monotone-x tangents (Steffen, as d3 `curveMonotoneX`). */
export function sparkMonotoneTangents(xs: number[], ys: number[]): number[] {
  const n = Math.min(xs.length, ys.length);
  const t: number[] = [];
  if (n < 3) {
    const s = n === 2 && xs[1] !== xs[0] ? (ys[1] - ys[0]) / (xs[1] - xs[0]) : 0;
    for (let i = 0; i < n; i++) {
      t.push(s);
    }
    return t;
  }
  for (let i = 0; i < n; i++) {
    t.push(0);
  }
  for (let i = 1; i < n - 1; i++) {
    t[i] = monotoneSlope3(xs[i - 1], ys[i - 1], xs[i], ys[i], xs[i + 1], ys[i + 1]);
  }
  t[0] = monotoneSlope2(xs[0], ys[0], xs[1], ys[1], t[1]);
  t[n - 1] = monotoneSlope2(xs[n - 1], ys[n - 1], xs[n - 2], ys[n - 2], t[n - 2]);
  return t;
}

/**
 * Commands for a curve through the points. `move` starts with M (else L, to continue a path).
 * Works for decreasing x too (used for the lower edge of areas), producing the same curve reversed.
 */
export function sparkCurvePath(xs: number[], ys: number[], curve: SparkChartCurve, k: number, move: boolean): string {
  const n = Math.min(xs.length, ys.length);
  if (n === 0) {
    return '';
  }
  let s = `${move ? 'M' : 'L'}${f(xs[0] * k)} ${f(ys[0] * k)}`;
  if (curve === 'monotone' && n > 2) {
    const t = sparkMonotoneTangents(xs, ys);
    for (let i = 0; i < n - 1; i++) {
      const dx = (xs[i + 1] - xs[i]) / 3;
      s += ` C${f((xs[i] + dx) * k)} ${f((ys[i] + dx * t[i]) * k)} ${f((xs[i + 1] - dx) * k)} ` +
        `${f((ys[i + 1] - dx * t[i + 1]) * k)} ${f(xs[i + 1] * k)} ${f(ys[i + 1] * k)}`;
    }
    return s;
  }
  for (let i = 1; i < n; i++) {
    if (curve === 'step') {
      const mid = (xs[i - 1] + xs[i]) / 2;
      s += ` L${f(mid * k)} ${f(ys[i - 1] * k)} L${f(mid * k)} ${f(ys[i] * k)}`;
    }
    s += ` L${f(xs[i] * k)} ${f(ys[i] * k)}`;
  }
  return s;
}

/** Closed area between an upper curve (xs, ys) and a lower edge (xs, bs) following the same curve. */
export function sparkAreaPath(xs: number[], ys: number[], bs: number[], curve: SparkChartCurve, k: number): string {
  const n = Math.min(xs.length, ys.length, bs.length);
  if (n === 0) {
    return '';
  }
  const rx: number[] = [];
  const rb: number[] = [];
  for (let i = n - 1; i >= 0; i--) {
    rx.push(xs[i]);
    rb.push(bs[i]);
  }
  return `${sparkCurvePath(xs, ys, curve, k, true)} ${sparkCurvePath(rx, rb, curve, k, false)} Z`;
}

/** Rectangle with per-corner radii (top-left, top-right, bottom-right, bottom-left); negative h/w allowed. */
export function sparkRoundRectPath(x: number, y: number, w: number, h: number, tl: number, tr: number, br: number,
  bl: number, k: number): string {
  let x0 = x;
  let y0 = y;
  let ww = w;
  let hh = h;
  if (ww < 0) {
    x0 += ww;
    ww = -ww;
  }
  if (hh < 0) {
    y0 += hh;
    hh = -hh;
  }
  if (ww < 0.01 || hh < 0.01) {
    return '';
  }
  const m = Math.min(ww, hh) / 2;
  const a = Math.max(0, Math.min(tl, m)) * k;
  const b = Math.max(0, Math.min(tr, m)) * k;
  const c = Math.max(0, Math.min(br, m)) * k;
  const d = Math.max(0, Math.min(bl, m)) * k;
  const L = x0 * k;
  const T = y0 * k;
  const R = (x0 + ww) * k;
  const B = (y0 + hh) * k;
  let s = `M${f(L + a)} ${f(T)} L${f(R - b)} ${f(T)}`;
  if (b > 0) {
    s += ` A${f(b)} ${f(b)} 0 0 1 ${f(R)} ${f(T + b)}`;
  }
  s += ` L${f(R)} ${f(B - c)}`;
  if (c > 0) {
    s += ` A${f(c)} ${f(c)} 0 0 1 ${f(R - c)} ${f(B)}`;
  }
  s += ` L${f(L + d)} ${f(B)}`;
  if (d > 0) {
    s += ` A${f(d)} ${f(d)} 0 0 1 ${f(L)} ${f(B - d)}`;
  }
  s += ` L${f(L)} ${f(T + a)}`;
  if (a > 0) {
    s += ` A${f(a)} ${f(a)} 0 0 1 ${f(L + a)} ${f(T)}`;
  }
  return s + ' Z';
}

/** Circle as two arcs. */
export function sparkCirclePath(cx: number, cy: number, r: number, k: number): string {
  if (!(r > 0)) {
    return '';
  }
  const R = r * k;
  return `M${f((cx - r) * k)} ${f(cy * k)} A${f(R)} ${f(R)} 0 1 0 ${f((cx + r) * k)} ${f(cy * k)} ` +
    `A${f(R)} ${f(R)} 0 1 0 ${f((cx - r) * k)} ${f(cy * k)} Z`;
}

/**
 * Annular sector between radii r0 (inner, may be 0) and r1 from angle a0 to a1.
 * `round` caps both ends with half circles (Recharts `cornerRadius` on radial bars).
 */
export function sparkArcPath(cx: number, cy: number, r0: number, r1: number, a0: number, a1: number, round: boolean,
  k: number): string {
  const sweep = a1 - a0;
  if (!(sweep > 1e-6) || !(r1 > 0)) {
    return '';
  }
  const ri = Math.max(0, Math.min(r0, r1));
  if (sweep >= TAU - 1e-6) {
    let s = `M${f(cx * k)} ${f((cy - r1) * k)} A${f(r1 * k)} ${f(r1 * k)} 0 1 1 ${f(cx * k)} ${f((cy + r1) * k)} ` +
      `A${f(r1 * k)} ${f(r1 * k)} 0 1 1 ${f(cx * k)} ${f((cy - r1) * k)} Z`;
    if (ri > 0) {
      s += ` M${f(cx * k)} ${f((cy - ri) * k)} A${f(ri * k)} ${f(ri * k)} 0 1 0 ${f(cx * k)} ${f((cy + ri) * k)} ` +
        `A${f(ri * k)} ${f(ri * k)} 0 1 0 ${f(cx * k)} ${f((cy - ri) * k)} Z`;
    }
    return s;
  }
  const large = sweep > Math.PI ? 1 : 0;
  const o0 = sparkPolar(cx, cy, r1, a0);
  const o1 = sparkPolar(cx, cy, r1, a1);
  let s = `M${f(o0[0] * k)} ${f(o0[1] * k)} A${f(r1 * k)} ${f(r1 * k)} 0 ${large} 1 ${f(o1[0] * k)} ${f(o1[1] * k)}`;
  if (ri <= 0) {
    return `${s} L${f(cx * k)} ${f(cy * k)} Z`;
  }
  const i1 = sparkPolar(cx, cy, ri, a1);
  const i0 = sparkPolar(cx, cy, ri, a0);
  const cap = (r1 - ri) / 2 * k;
  s += round ? ` A${f(cap)} ${f(cap)} 0 0 1 ${f(i1[0] * k)} ${f(i1[1] * k)}` : ` L${f(i1[0] * k)} ${f(i1[1] * k)}`;
  s += ` A${f(ri * k)} ${f(ri * k)} 0 ${large} 0 ${f(i0[0] * k)} ${f(i0[1] * k)}`;
  s += round ? ` A${f(cap)} ${f(cap)} 0 0 1 ${f(o0[0] * k)} ${f(o0[1] * k)}` : '';
  return s + ' Z';
}

/** Closed polygon. */
export function sparkPolygonPath(xs: number[], ys: number[], k: number): string {
  const n = Math.min(xs.length, ys.length);
  if (n === 0) {
    return '';
  }
  let s = `M${f(xs[0] * k)} ${f(ys[0] * k)}`;
  for (let i = 1; i < n; i++) {
    s += ` L${f(xs[i] * k)} ${f(ys[i] * k)}`;
  }
  return s + ' Z';
}

// ------------------------------------------------------------------------------------------------ shape vectors

/**
 * A chart shape as a flat number vector, so it can be interpolated element-wise by an animation
 * (`AnimatableArithmetic`): enter animations and data changes morph from one vector to the next.
 *
 * Layout: [kind, k (vp→px), ...payload]. Header values are equal in both endpoints, so interpolation keeps them.
 * - LINE    [1, k, curve, n, x*n, y*n]
 * - AREA    [2, k, curve, n, x*n, y*n, base*n]
 * - RECTS   [3, k, count, (x, y, w, h, tl, tr, br, bl)*count]
 * - ARCS    [4, k, count, (cx, cy, r0, r1, a0, a1, round)*count]
 * - DOTS    [5, k, count, r, (x, y)*count]
 * - POLYGON [6, k, n, x*n, y*n]
 * - LINES   [7, k, count, (x1, y1, x2, y2)*count]  (grid / crosshair segments)
 * - RINGS   [8, k, cx, cy, n, levels, circle, r*levels]  (polar grid: rings + n spokes to the outer ring)
 */
export const SPARK_SHAPE_LINE: number = 1;
export const SPARK_SHAPE_AREA: number = 2;
export const SPARK_SHAPE_RECTS: number = 3;
export const SPARK_SHAPE_ARCS: number = 4;
export const SPARK_SHAPE_DOTS: number = 5;
export const SPARK_SHAPE_POLYGON: number = 6;
export const SPARK_SHAPE_LINES: number = 7;
export const SPARK_SHAPE_RINGS: number = 8;

export function sparkCurveCode(c: SparkChartCurve): number {
  return c === 'linear' ? 0 : (c === 'step' ? 2 : 1);
}

function curveOf(code: number): SparkChartCurve {
  const c = Math.round(code);
  return c === 0 ? 'linear' : (c === 2 ? 'step' : 'monotone');
}

export function sparkShapeLine(xs: number[], ys: number[], curve: SparkChartCurve, k: number): number[] {
  const n = Math.min(xs.length, ys.length);
  const v: number[] = [SPARK_SHAPE_LINE, k, sparkCurveCode(curve), n];
  for (let i = 0; i < n; i++) {
    v.push(xs[i]);
  }
  for (let i = 0; i < n; i++) {
    v.push(ys[i]);
  }
  return v;
}

export function sparkShapeArea(xs: number[], ys: number[], bs: number[], curve: SparkChartCurve, k: number): number[] {
  const n = Math.min(xs.length, ys.length, bs.length);
  const v: number[] = [SPARK_SHAPE_AREA, k, sparkCurveCode(curve), n];
  for (let i = 0; i < n; i++) {
    v.push(xs[i]);
  }
  for (let i = 0; i < n; i++) {
    v.push(ys[i]);
  }
  for (let i = 0; i < n; i++) {
    v.push(bs[i]);
  }
  return v;
}

/** `rects` is a flat list of (x, y, w, h, tl, tr, br, bl). */
export function sparkShapeRects(rects: number[], k: number): number[] {
  const v: number[] = [SPARK_SHAPE_RECTS, k, Math.floor(rects.length / 8)];
  for (const r of rects) {
    v.push(r);
  }
  return v;
}

/** `arcs` is a flat list of (cx, cy, r0, r1, a0, a1, round 0/1). */
export function sparkShapeArcs(arcs: number[], k: number): number[] {
  const v: number[] = [SPARK_SHAPE_ARCS, k, Math.floor(arcs.length / 7)];
  for (const a of arcs) {
    v.push(a);
  }
  return v;
}

export function sparkShapeDots(xs: number[], ys: number[], r: number, k: number): number[] {
  const n = Math.min(xs.length, ys.length);
  const v: number[] = [SPARK_SHAPE_DOTS, k, n, r];
  for (let i = 0; i < n; i++) {
    v.push(xs[i]);
    v.push(ys[i]);
  }
  return v;
}

export function sparkShapePolygon(xs: number[], ys: number[], k: number): number[] {
  const n = Math.min(xs.length, ys.length);
  const v: number[] = [SPARK_SHAPE_POLYGON, k, n];
  for (let i = 0; i < n; i++) {
    v.push(xs[i]);
  }
  for (let i = 0; i < n; i++) {
    v.push(ys[i]);
  }
  return v;
}

/** `segs` is a flat list of (x1, y1, x2, y2). */
export function sparkShapeLines(segs: number[], k: number): number[] {
  const v: number[] = [SPARK_SHAPE_LINES, k, Math.floor(segs.length / 4)];
  for (const s of segs) {
    v.push(s);
  }
  return v;
}

export function sparkShapeRings(cx: number, cy: number, spokes: number, radii: number[], circle: boolean,
  k: number): number[] {
  const v: number[] = [SPARK_SHAPE_RINGS, k, cx, cy, spokes, radii.length, circle ? 1 : 0];
  for (const r of radii) {
    v.push(r);
  }
  return v;
}

/** Path commands (px) for a shape vector; '' for unknown / malformed vectors. */
export function sparkShapeCommands(v: number[]): string {
  if (v.length < 3) {
    return '';
  }
  const kind = Math.round(v[0]);
  const k = v[1];
  if (kind === SPARK_SHAPE_LINE || kind === SPARK_SHAPE_AREA) {
    const n = Math.round(v[3]);
    const need = 4 + n * (kind === SPARK_SHAPE_AREA ? 3 : 2);
    if (v.length < need) {
      return '';
    }
    const xs = v.slice(4, 4 + n);
    const ys = v.slice(4 + n, 4 + 2 * n);
    if (kind === SPARK_SHAPE_LINE) {
      return sparkCurvePath(xs, ys, curveOf(v[2]), k, true);
    }
    return sparkAreaPath(xs, ys, v.slice(4 + 2 * n, 4 + 3 * n), curveOf(v[2]), k);
  }
  if (kind === SPARK_SHAPE_RECTS) {
    const n = Math.round(v[2]);
    const parts: string[] = [];
    for (let i = 0; i < n && 3 + i * 8 + 7 < v.length; i++) {
      const o = 3 + i * 8;
      const p = sparkRoundRectPath(v[o], v[o + 1], v[o + 2], v[o + 3], v[o + 4], v[o + 5], v[o + 6], v[o + 7], k);
      if (p.length > 0) {
        parts.push(p);
      }
    }
    return parts.join(' ');
  }
  if (kind === SPARK_SHAPE_ARCS) {
    const n = Math.round(v[2]);
    const parts: string[] = [];
    for (let i = 0; i < n && 3 + i * 7 + 6 < v.length; i++) {
      const o = 3 + i * 7;
      const p = sparkArcPath(v[o], v[o + 1], v[o + 2], v[o + 3], v[o + 4], v[o + 5], v[o + 6] >= 0.5, k);
      if (p.length > 0) {
        parts.push(p);
      }
    }
    return parts.join(' ');
  }
  if (kind === SPARK_SHAPE_DOTS) {
    const n = Math.round(v[2]);
    const parts: string[] = [];
    for (let i = 0; i < n && 4 + i * 2 + 1 < v.length; i++) {
      const p = sparkCirclePath(v[4 + i * 2], v[5 + i * 2], v[3], k);
      if (p.length > 0) {
        parts.push(p);
      }
    }
    return parts.join(' ');
  }
  if (kind === SPARK_SHAPE_POLYGON) {
    const n = Math.round(v[2]);
    if (v.length < 3 + 2 * n) {
      return '';
    }
    return sparkPolygonPath(v.slice(3, 3 + n), v.slice(3 + n, 3 + 2 * n), k);
  }
  if (kind === SPARK_SHAPE_LINES) {
    const n = Math.round(v[2]);
    let s = '';
    for (let i = 0; i < n && 3 + i * 4 + 3 < v.length; i++) {
      const o = 3 + i * 4;
      s += `${s.length > 0 ? ' ' : ''}M${f(v[o] * k)} ${f(v[o + 1] * k)} L${f(v[o + 2] * k)} ${f(v[o + 3] * k)}`;
    }
    return s;
  }
  if (kind === SPARK_SHAPE_RINGS && v.length >= 7) {
    const cx = v[2];
    const cy = v[3];
    const spokes = Math.round(v[4]);
    const levels = Math.round(v[5]);
    const circle = v[6] >= 0.5;
    const parts: string[] = [];
    let outer = 0;
    for (let l = 0; l < levels && 7 + l < v.length; l++) {
      const r = v[7 + l];
      outer = Math.max(outer, r);
      if (circle || spokes < 3) {
        const c = sparkCirclePath(cx, cy, r, k);
        if (c.length > 0) {
          parts.push(c);
        }
      } else {
        const xs: number[] = [];
        const ys: number[] = [];
        for (let i = 0; i < spokes; i++) {
          const p = sparkPolar(cx, cy, r, TAU * i / spokes);
          xs.push(p[0]);
          ys.push(p[1]);
        }
        parts.push(sparkPolygonPath(xs, ys, k));
      }
    }
    for (let i = 0; i < spokes && outer > 0; i++) {
      const p = sparkPolar(cx, cy, outer, TAU * i / spokes);
      parts.push(`M${f(cx * k)} ${f(cy * k)} L${f(p[0] * k)} ${f(p[1] * k)}`);
    }
    return parts.join(' ');
  }
  return '';
}
