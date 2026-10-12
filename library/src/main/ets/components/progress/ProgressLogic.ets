/**
 * Pure helpers of SProgress (unit-tested in Variants.test.ets).
 * Angles are in degrees, 0° = 12 o'clock, clockwise (like CSS `conic-gradient`).
 */

/** `value / max` as 0…100, clamped; 0 when `max <= 0`. */
export function sparkProgressPercent(value: number, max: number): number {
  if (max <= 0 || isNaN(value)) {
    return 0;
  }
  return Math.min(100, Math.max(0, value / max * 100));
}

/** Fill (0…1) of each of `segments` equal parts for `percent` (0…100). */
export function sparkSegmentFills(percent: number, segments: number): number[] {
  const n = Math.max(0, Math.floor(segments));
  const out: number[] = [];
  const filled = Math.min(100, Math.max(0, percent)) / 100 * n;
  for (let i = 0; i < n; i++) {
    out.push(Math.min(1, Math.max(0, filled - i)));
  }
  return out;
}

function round3(v: number): number {
  return Math.round(v * 1000) / 1000;
}

/** Point on a circle at `deg` (0° = top, clockwise). */
function arcPoint(cx: number, cy: number, r: number, deg: number): number[] {
  const a = deg * Math.PI / 180;
  return [round3(cx + r * Math.sin(a)), round3(cy - r * Math.cos(a))];
}

/**
 * SVG path data of a circular arc from `startDeg` sweeping `sweepDeg` clockwise. Units are whatever the caller
 * uses (SProgress passes px: `Path.commands()` is in px). Empty for a (near) zero sweep; a full circle for 360°.
 */
export function sparkRingArcPath(cx: number, cy: number, r: number, startDeg: number, sweepDeg: number): string {
  const sweep = Math.min(360, sweepDeg);
  if (sweep <= 0.05 || r <= 0) {
    return '';
  }
  const p0 = arcPoint(cx, cy, r, startDeg);
  const rr = round3(r);
  if (sweep >= 359.95) {
    const p1 = arcPoint(cx, cy, r, startDeg + 180);
    return `M${p0[0]} ${p0[1]} A${rr} ${rr} 0 1 1 ${p1[0]} ${p1[1]} A${rr} ${rr} 0 1 1 ${p0[0]} ${p0[1]}`;
  }
  const p1 = arcPoint(cx, cy, r, startDeg + sweep);
  const large = sweep > 180 ? 1 : 0;
  return `M${p0[0]} ${p0[1]} A${rr} ${rr} 0 ${large} 1 ${p1[0]} ${p1[1]}`;
}

/**
 * An arc as an animatable value (`AnimatableArithmetic`): SProgress interpolates it with `@AnimatableExtend`,
 * so the ring / gauge sweep animates through the regular `.animation(SparkAnim.attr(…))` path.
 */
export class SparkProgressArc implements AnimatableArithmetic<SparkProgressArc> {
  cx: number;
  cy: number;
  r: number;
  start: number;
  sweep: number;

  constructor(cx: number, cy: number, r: number, start: number, sweep: number) {
    this.cx = cx;
    this.cy = cy;
    this.r = r;
    this.start = start;
    this.sweep = sweep;
  }

  plus(rhs: SparkProgressArc): SparkProgressArc {
    return new SparkProgressArc(this.cx + rhs.cx, this.cy + rhs.cy, this.r + rhs.r, this.start + rhs.start,
      this.sweep + rhs.sweep);
  }

  subtract(rhs: SparkProgressArc): SparkProgressArc {
    return new SparkProgressArc(this.cx - rhs.cx, this.cy - rhs.cy, this.r - rhs.r, this.start - rhs.start,
      this.sweep - rhs.sweep);
  }

  multiply(scale: number): SparkProgressArc {
    return new SparkProgressArc(this.cx * scale, this.cy * scale, this.r * scale, this.start * scale, this.sweep * scale);
  }

  equals(rhs: SparkProgressArc): boolean {
    return this.cx === rhs.cx && this.cy === rhs.cy && this.r === rhs.r && this.start === rhs.start &&
      this.sweep === rhs.sweep;
  }

  commands(): string {
    return sparkRingArcPath(this.cx, this.cy, this.r, this.start, this.sweep);
  }
}

/** Default text of a value label: `"66%"`. */
export function sparkProgressLabel(percent: number): string {
  return `${Math.round(percent)}%`;
}
