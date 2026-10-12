/**
 * JavaScript port of library/src/main/ets/components/chart/ChartMath.ets (ticks, nice domains, scales,
 * diverging stacks, pie layout, polar helpers, curve / arc / rounded-rect path builders) so the web charts lay
 * out exactly like the ArkUI ones. Coordinates are CSS px (= vp), so the path builders take no `k` factor.
 */

const E10 = Math.sqrt(50);
const E5 = Math.sqrt(10);
const E2 = Math.sqrt(2);
export const TAU = Math.PI * 2;
const EPS = 1e-9;

// ------------------------------------------------------------------------------------------------ numbers

function decimalsOf(step) {
  if (!(step > 0) || !isFinite(step)) {
    return 0;
  }
  return Math.max(0, -Math.floor(Math.log(step) / Math.LN10 + EPS));
}

function roundTo(v, decimals) {
  return parseFloat(v.toFixed(Math.min(20, decimals)));
}

/** d3 `tickIncrement`-like step: 1, 2 or 5 × 10^k so that about `count` ticks span [start, stop]. */
export function tickStep(start, stop, count) {
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

/** Extend [min, max] to round tick boundaries (d3 `scale.nice()`); degenerate ranges are widened. */
export function niceDomain(min, max, count) {
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
    const step = tickStep(lo, hi, count);
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
export function niceTicks(min, max, count) {
  const lo = Math.min(min, max);
  const hi = Math.max(min, max);
  const step = tickStep(lo, hi, count);
  if (step <= 0) {
    return isFinite(lo) ? [lo] : [];
  }
  const d = decimalsOf(step);
  const i0 = Math.ceil(lo / step - EPS);
  const i1 = Math.floor(hi / step + EPS);
  const out = [];
  for (let i = i0; i <= i1; i++) {
    out.push(roundTo(i * step, d));
  }
  return out;
}

/** Value domain of a chart: data extent, optionally including 0, made nice. */
export function valueDomain(values, includeZero, count) {
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
  return niceDomain(lo, hi, count);
}

/** Axis tick count that fits the available length (≈ one tick per `spacing` px), clamped to [min, max]. */
export function tickCount(length, spacing, min, max) {
  if (!(length > 0) || !(spacing > 0)) {
    return min;
  }
  return Math.max(min, Math.min(max, Math.round(length / spacing)));
}

/** Show every n-th category label so labels of width `labelWidth` do not overlap over `span` px. */
export function labelStep(count, span, labelWidth) {
  if (count <= 1 || !(span > 0)) {
    return 1;
  }
  const per = span / count;
  return Math.max(1, Math.ceil(labelWidth / Math.max(per, 1)));
}

/** "1,234.5" — thousands separators, at most `decimals` fraction digits (trailing zeros trimmed). */
export function chartFormat(v, decimals) {
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
export function chartCompact(v) {
  const a = Math.abs(v);
  if (a >= 1e9) {
    return chartFormat(v / 1e9, 1) + 'B';
  }
  if (a >= 1e6) {
    return chartFormat(v / 1e6, 1) + 'M';
  }
  if (a >= 1e3) {
    return chartFormat(v / 1e3, 1) + 'k';
  }
  return chartFormat(v, 2);
}

/** ChartParts.sparkChartTextWidth: CJK = 1 em, everything else 0.6 em. */
export function textWidth(text, fontSize) {
  let w = 0;
  const s = String(text ?? '');
  for (let i = 0; i < s.length; i++) {
    w += s.charCodeAt(i) >= 0x2E80 ? fontSize : fontSize * 0.6;
  }
  return w;
}

// ------------------------------------------------------------------------------------------------ scales

export class LinearScale {
  constructor(d0, d1, r0, r1) {
    this.d0 = d0;
    this.d1 = d1;
    this.r0 = r0;
    this.r1 = r1;
  }

  map(v) {
    if (this.d1 === this.d0) {
      return (this.r0 + this.r1) / 2;
    }
    return this.r0 + (v - this.d0) / (this.d1 - this.d0) * (this.r1 - this.r0);
  }

  mapClamped(v) {
    const p = this.map(v);
    return Math.max(Math.min(this.r0, this.r1), Math.min(Math.max(this.r0, this.r1), p));
  }
}

/** Band scale (d3 `scaleBand`, align 0.5). */
export class BandScale {
  constructor(count, r0, r1, paddingInner, paddingOuter) {
    this.count = Math.max(0, count);
    const n = this.count;
    this.step = (r1 - r0) / Math.max(1, n - paddingInner + paddingOuter * 2);
    this.offset = r0 + (r1 - r0 - this.step * (n - paddingInner)) * 0.5;
    this.bandwidth = this.step * (1 - paddingInner);
  }

  start(i) {
    return this.offset + this.step * i;
  }

  center(i) {
    return this.start(i) + this.bandwidth / 2;
  }

  centers() {
    const out = [];
    for (let i = 0; i < this.count; i++) {
      out.push(this.center(i));
    }
    return out;
  }
}

/** Point scale: n points spread edge to edge over [r0, r1] (a single point sits in the middle). */
export function pointPositions(n, r0, r1) {
  const out = [];
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
export function nearestIndex(positions, p) {
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

/** Diverging stack (d3 `stackOffsetDiverging`) → { lower: number[][], upper: number[][] }. */
export function stack(values) {
  const res = { lower: [], upper: [] };
  let n = 0;
  for (const s of values) {
    n = Math.max(n, s.length);
  }
  const pos = new Array(n).fill(0);
  const neg = new Array(n).fill(0);
  for (const s of values) {
    const lo = [];
    const up = [];
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

/** Pie layout (d3 `pie`, data order kept) → [{ index, value, a0, a1 }]. */
export function pieArcs(values, start, end, pad) {
  const out = [];
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
      out.push({ index: i, value: 0, a0: a, a1: a });
      continue;
    }
    const a1 = a + v * k + pa;
    out.push({ index: i, value: v, a0: a + pa / 2, a1: a1 - pa / 2 });
    a = a1;
  }
  return out;
}

/** Point at radius r, angle a (0 = 12 o'clock, clockwise) around (cx, cy). */
export function polar(cx, cy, r, a) {
  return [cx + r * Math.sin(a), cy - r * Math.cos(a)];
}

export function angleOf(cx, cy, x, y) {
  let a = Math.atan2(x - cx, cy - y);
  if (a < 0) {
    a += TAU;
  }
  return a;
}

export function spokeIndex(cx, cy, n, x, y) {
  if (n <= 0) {
    return -1;
  }
  return Math.round(angleOf(cx, cy, x, y) / (TAU / n)) % n;
}

/** Slice under (x, y), or -1. */
export function arcIndex(arcs, cx, cy, r0, r1, x, y, slack) {
  const d = Math.hypot(x - cx, y - cy);
  if (d < r0 - slack || d > r1 + slack) {
    return -1;
  }
  const a = angleOf(cx, cy, x, y);
  for (const arc of arcs) {
    if (arc.a1 - arc.a0 <= EPS) {
      continue;
    }
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

export function ringIndex(count, r0, r1, d) {
  if (count <= 0 || d < r0 || d > r1 || r1 <= r0) {
    return -1;
  }
  return Math.min(count - 1, Math.floor((d - r0) / ((r1 - r0) / count)));
}

/** Tooltip box position next to an anchor, flipped / clamped to stay inside the chart box. */
export function tooltipPlace(ax, ay, tw, th, bw, bh, gap) {
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

function f(v) {
  const r = Math.round(v * 100) / 100;
  return (r === 0 ? 0 : r).toString();
}

function monotoneSlope3(x0, y0, x1, y1, x2, y2) {
  const h0 = x1 - x0;
  const h1 = x2 - x1;
  const s0 = h0 !== 0 ? (y1 - y0) / h0 : 0;
  const s1 = h1 !== 0 ? (y2 - y1) / h1 : 0;
  const p = h0 + h1 !== 0 ? (s0 * h1 + s1 * h0) / (h0 + h1) : 0;
  const r = (Math.sign(s0) + Math.sign(s1)) * Math.min(Math.abs(s0), Math.abs(s1), 0.5 * Math.abs(p));
  return isFinite(r) ? r : 0;
}

function monotoneSlope2(x0, y0, x1, y1, t) {
  const h = x1 - x0;
  return h !== 0 ? (3 * (y1 - y0) / h - t) / 2 : t;
}

/** Monotone-x tangents (Steffen, as d3 `curveMonotoneX`). */
export function monotoneTangents(xs, ys) {
  const n = Math.min(xs.length, ys.length);
  const t = [];
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

/** Curve through the points ('linear' | 'monotone' | 'step'). `move` starts with M (else L). */
export function curvePath(xs, ys, curve, move = true) {
  const n = Math.min(xs.length, ys.length);
  if (n === 0) {
    return '';
  }
  let s = `${move ? 'M' : 'L'}${f(xs[0])} ${f(ys[0])}`;
  if (curve === 'monotone' && n > 2) {
    const t = monotoneTangents(xs, ys);
    for (let i = 0; i < n - 1; i++) {
      const dx = (xs[i + 1] - xs[i]) / 3;
      s += ` C${f(xs[i] + dx)} ${f(ys[i] + dx * t[i])} ${f(xs[i + 1] - dx)} ${f(ys[i + 1] - dx * t[i + 1])} ` +
        `${f(xs[i + 1])} ${f(ys[i + 1])}`;
    }
    return s;
  }
  for (let i = 1; i < n; i++) {
    if (curve === 'step') {
      const mid = (xs[i - 1] + xs[i]) / 2;
      s += ` L${f(mid)} ${f(ys[i - 1])} L${f(mid)} ${f(ys[i])}`;
    }
    s += ` L${f(xs[i])} ${f(ys[i])}`;
  }
  return s;
}

/** Closed area between an upper curve (xs, ys) and a lower edge (xs, bs) following the same curve. */
export function areaPath(xs, ys, bs, curve) {
  const n = Math.min(xs.length, ys.length, bs.length);
  if (n === 0) {
    return '';
  }
  const rx = [];
  const rb = [];
  for (let i = n - 1; i >= 0; i--) {
    rx.push(xs[i]);
    rb.push(bs[i]);
  }
  return `${curvePath(xs, ys, curve, true)} ${curvePath(rx, rb, curve, false)} Z`;
}

/** Rectangle with per-corner radii (tl, tr, br, bl); negative w / h allowed. */
export function roundRectPath(x, y, w, h, tl, tr, br, bl) {
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
  const a = Math.max(0, Math.min(tl, m));
  const b = Math.max(0, Math.min(tr, m));
  const c = Math.max(0, Math.min(br, m));
  const d = Math.max(0, Math.min(bl, m));
  const L = x0;
  const T = y0;
  const R = x0 + ww;
  const B = y0 + hh;
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

/** Annular sector between radii r0 (may be 0) and r1 from angle a0 to a1; `round` caps both ends. */
export function arcPath(cx, cy, r0, r1, a0, a1, round) {
  const sweep = a1 - a0;
  if (!(sweep > 1e-6) || !(r1 > 0)) {
    return '';
  }
  const ri = Math.max(0, Math.min(r0, r1));
  if (sweep >= TAU - 1e-6) {
    let s = `M${f(cx)} ${f(cy - r1)} A${f(r1)} ${f(r1)} 0 1 1 ${f(cx)} ${f(cy + r1)} ` +
      `A${f(r1)} ${f(r1)} 0 1 1 ${f(cx)} ${f(cy - r1)} Z`;
    if (ri > 0) {
      s += ` M${f(cx)} ${f(cy - ri)} A${f(ri)} ${f(ri)} 0 1 0 ${f(cx)} ${f(cy + ri)} ` +
        `A${f(ri)} ${f(ri)} 0 1 0 ${f(cx)} ${f(cy - ri)} Z`;
    }
    return s;
  }
  const large = sweep > Math.PI ? 1 : 0;
  const o0 = polar(cx, cy, r1, a0);
  const o1 = polar(cx, cy, r1, a1);
  let s = `M${f(o0[0])} ${f(o0[1])} A${f(r1)} ${f(r1)} 0 ${large} 1 ${f(o1[0])} ${f(o1[1])}`;
  if (ri <= 0) {
    return `${s} L${f(cx)} ${f(cy)} Z`;
  }
  const i1 = polar(cx, cy, ri, a1);
  const i0 = polar(cx, cy, ri, a0);
  const cap = (r1 - ri) / 2;
  s += round ? ` A${f(cap)} ${f(cap)} 0 0 1 ${f(i1[0])} ${f(i1[1])}` : ` L${f(i1[0])} ${f(i1[1])}`;
  s += ` A${f(ri)} ${f(ri)} 0 ${large} 0 ${f(i0[0])} ${f(i0[1])}`;
  s += round ? ` A${f(cap)} ${f(cap)} 0 0 1 ${f(o0[0])} ${f(o0[1])}` : '';
  return s + ' Z';
}

export function polygonPath(xs, ys) {
  const n = Math.min(xs.length, ys.length);
  if (n === 0) {
    return '';
  }
  let s = `M${f(xs[0])} ${f(ys[0])}`;
  for (let i = 1; i < n; i++) {
    s += ` L${f(xs[i])} ${f(ys[i])}`;
  }
  return s + ' Z';
}

/** Polar grid: rings (polygons with `spokes` corners, or circles) + spokes to the outer ring. */
export function ringsPath(cx, cy, spokes, radii, circle) {
  const parts = [];
  let outer = 0;
  for (const r of radii) {
    outer = Math.max(outer, r);
    if (circle || spokes < 3) {
      parts.push(`M${f(cx - r)} ${f(cy)} A${f(r)} ${f(r)} 0 1 0 ${f(cx + r)} ${f(cy)} A${f(r)} ${f(r)} 0 1 0 ${f(cx - r)} ${f(cy)} Z`);
    } else {
      const xs = [];
      const ys = [];
      for (let i = 0; i < spokes; i++) {
        const p = polar(cx, cy, r, TAU * i / spokes);
        xs.push(p[0]);
        ys.push(p[1]);
      }
      parts.push(polygonPath(xs, ys));
    }
  }
  for (let i = 0; i < spokes && outer > 0; i++) {
    const p = polar(cx, cy, outer, TAU * i / spokes);
    parts.push(`M${f(cx)} ${f(cy)} L${f(p[0])} ${f(p[1])}`);
  }
  return parts.join(' ');
}
