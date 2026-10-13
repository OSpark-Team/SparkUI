import { Rgba, SparkColor } from '../../theme/color/SparkColor';

/**
 * Pure colour math of the colour picker (no UI, unit tested in `test/ColorPicker.test.ets`).
 *
 * Conventions: hue in degrees [0, 360], saturation / value / alpha in [0, 1]; `Rgba` channels in [0, 1].
 * Hex strings handed to and returned by the picker use the **CSS order** `#RRGGBB` / `#RRGGBBAA` (not ArkUI's
 * `#AARRGGBB`); turn a picker value into an ArkUI colour with `SparkColor.parse(value).value`.
 */

/** Value format of a colour picker: `#3b82f6`, `rgb(59 130 246)`, `hsl(217 91% 60%)`, `oklch(0.623 0.188 259.8)`. */
export type ColorPickerFormat = 'hex' | 'rgb' | 'hsl' | 'oklch';

/** Formats in the order the panel's format toggle cycles through them. */
export const SPARK_COLOR_FORMATS: ColorPickerFormat[] = ['hex', 'rgb', 'hsl', 'oklch'];

/** shadcn / Tailwind-like default swatches (neutral ends + the 500 shades). */
export const SPARK_DEFAULT_SWATCHES: string[] = [
  '#000000', '#737373', '#ffffff', '#ef4444', '#f97316', '#f59e0b', '#eab308', '#84cc16', '#22c55e', '#10b981',
  '#14b8a6', '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1', '#8b5cf6', '#a855f7', '#d946ef', '#ec4899', '#f43f5e'
];

/** HSV(A) colour: h in [0, 360], s / v / a in [0, 1]. */
export class SparkHsva {
  h: number = 0;
  s: number = 0;
  v: number = 0;
  a: number = 1;

  constructor(h: number, s: number, v: number, a: number) {
    this.h = h;
    this.s = s;
    this.v = v;
    this.a = a;
  }
}

/** Clamp `v` into [lo, hi]; NaN becomes `lo`. */
export function sparkColorClamp(v: number, lo: number, hi: number): number {
  if (isNaN(v)) {
    return lo;
  }
  return Math.min(hi, Math.max(lo, v));
}

/** Hue normalised into [0, 360] (360 stays 360 so the end of the hue slider keeps its position). */
export function sparkHue(h: number): number {
  if (!isFinite(h)) {
    return 0;
  }
  if (h >= 0 && h <= 360) {
    return h;
  }
  return ((h % 360) + 360) % 360;
}

/** HSV → sRGB (channels 0..1). */
export function sparkHsvToRgb(h: number, s: number, v: number, a: number): Rgba {
  const hh = sparkHue(h);
  const ss = sparkColorClamp(s, 0, 1);
  const vv = sparkColorClamp(v, 0, 1);
  const f = (n: number): number => {
    const k = (n + hh / 60) % 6;
    return vv - vv * ss * Math.max(0, Math.min(k, 4 - k, 1));
  };
  return new Rgba(f(5), f(3), f(1), sparkColorClamp(a, 0, 1));
}

/** Hue of an RGB colour, or `fallback` for greys (no hue). */
function hueOf(r: number, g: number, b: number, fallback: number): number {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const d = max - min;
  if (d < 1e-9) {
    return fallback;
  }
  let h = 0;
  if (max === r) {
    h = ((g - b) / d) % 6;
  } else if (max === g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h *= 60;
  return h < 0 ? h + 360 : h;
}

/**
 * sRGB → HSV. Greys keep `fallbackHue` and black keeps `fallbackSat` (the picker passes its current hue /
 * saturation, so dragging to a grey or to black never makes the hue slider or the area thumb jump).
 */
export function sparkRgbToHsv(c: Rgba, fallbackHue: number, fallbackSat: number): SparkHsva {
  const r = sparkColorClamp(c.r, 0, 1);
  const g = sparkColorClamp(c.g, 0, 1);
  const b = sparkColorClamp(c.b, 0, 1);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const s = max <= 1e-9 ? sparkColorClamp(fallbackSat, 0, 1) : (max - min) / max;
  return new SparkHsva(hueOf(r, g, b, sparkHue(fallbackHue)), s, max, sparkColorClamp(c.a, 0, 1));
}

/** sRGB → HSL: [h degrees, s 0..1, l 0..1]. */
export function sparkRgbToHsl(c: Rgba): number[] {
  const r = sparkColorClamp(c.r, 0, 1);
  const g = sparkColorClamp(c.g, 0, 1);
  const b = sparkColorClamp(c.b, 0, 1);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  const d = max - min;
  const s = d < 1e-9 ? 0 : d / (1 - Math.abs(2 * l - 1));
  return [hueOf(r, g, b, 0), sparkColorClamp(s, 0, 1), l];
}

function hex2(n: number): string {
  const s = Math.round(sparkColorClamp(n, 0, 1) * 255).toString(16);
  return s.length === 1 ? '0' + s : s;
}

/** True for `#RGB`, `#RRGGBB` and `#RRGGBBAA` (the leading `#` optional). */
export function sparkIsHexColor(text: string): boolean {
  return /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text.trim());
}

/** Parse `#RGB` / `#RRGGBB` / `#RRGGBBAA` (CSS order, `#` optional); undefined when invalid. */
export function sparkParseHex(text: string): Rgba | undefined {
  const t = text.trim();
  if (!sparkIsHexColor(t)) {
    return undefined;
  }
  let v = t.startsWith('#') ? t.substring(1) : t;
  if (v.length === 3) {
    v = v[0] + v[0] + v[1] + v[1] + v[2] + v[2];
  }
  const ch = (i: number): number => parseInt(v.substring(i, i + 2), 16) / 255;
  return new Rgba(ch(0), ch(2), ch(4), v.length === 8 ? ch(6) : 1);
}

/** `#rrggbb`, or `#rrggbbaa` when `alpha` is on and the colour is not opaque. */
export function sparkFormatHex(c: Rgba, alpha: boolean): string {
  const base = '#' + hex2(c.r) + hex2(c.g) + hex2(c.b);
  const a = Math.round(sparkColorClamp(c.a, 0, 1) * 255);
  return alpha && a < 255 ? base + hex2(c.a) : base;
}

/**
 * Parse a picker value: strict hex first (`#RGB` / `#RRGGBB` / `#RRGGBBAA`, `#` optional), then any colour
 * `SparkColor.parse` understands (`rgb()`, `hsl()`, `oklch()`, `oklab()`, keywords …). Undefined when invalid.
 */
export function sparkParseColor(text: string): Rgba | undefined {
  const hex = sparkParseHex(text);
  if (hex !== undefined) {
    return hex;
  }
  const t = text.trim();
  if (t.length === 0 || t.startsWith('#')) {
    return undefined;
  }
  const r = SparkColor.parse(t);
  return r.ok ? SparkColor.fromArgbHex(r.value) : undefined;
}

/** Number with at most `digits` decimals, trailing zeros dropped (`0.5`, `259.8`, `1`). */
export function sparkColorNum(n: number, digits: number): string {
  if (!isFinite(n)) {
    return '0';
  }
  const v = Number(n.toFixed(digits));
  return String(v === 0 ? 0 : v);
}

function alphaSuffix(c: Rgba, alpha: boolean): string {
  const a = sparkColorClamp(c.a, 0, 1);
  return alpha && Math.round(a * 255) < 255 ? ` / ${sparkColorNum(a, 2)}` : '';
}

/** Format a colour as a CSS string in `format` (alpha only when `alpha` is on and the colour is translucent). */
export function sparkFormatColor(c: Rgba, format: ColorPickerFormat, alpha: boolean): string {
  switch (format) {
    case 'rgb': {
      const ch = (v: number): number => Math.round(sparkColorClamp(v, 0, 1) * 255);
      return `rgb(${ch(c.r)} ${ch(c.g)} ${ch(c.b)}${alphaSuffix(c, alpha)})`;
    }
    case 'hsl': {
      const hsl = sparkRgbToHsl(c);
      return `hsl(${Math.round(hsl[0]) % 360} ${Math.round(hsl[1] * 100)}% ${Math.round(hsl[2] * 100)}%` +
        `${alphaSuffix(c, alpha)})`;
    }
    case 'oklch': {
      const lch = SparkColor.rgbToOklch(new Rgba(sparkColorClamp(c.r, 0, 1), sparkColorClamp(c.g, 0, 1),
        sparkColorClamp(c.b, 0, 1), 1));
      return `oklch(${sparkColorNum(lch[0], 3)} ${sparkColorNum(lch[1], 3)} ${sparkColorNum(lch[2], 1)}` +
        `${alphaSuffix(c, alpha)})`;
    }
    default:
      return sparkFormatHex(c, alpha);
  }
}

/** Format an HSVA colour (see {@link sparkFormatColor}). */
export function sparkFormatHsva(c: SparkHsva, format: ColorPickerFormat, alpha: boolean): string {
  return sparkFormatColor(sparkHsvToRgb(c.h, c.s, c.v, alpha ? c.a : 1), format, alpha);
}

/** ArkUI colour (`#AARRGGBB`) of an HSVA colour. */
export function sparkHsvaToArgb(c: SparkHsva, alpha: boolean): string {
  return SparkColor.toHex(sparkHsvToRgb(c.h, c.s, c.v, alpha ? c.a : 1));
}

/** ArkUI colour (`#AARRGGBB`) of a picker value, or `fallback` when it does not parse. */
export function sparkColorValueToArgb(value: string, fallback: string): string {
  const c = sparkParseColor(value);
  return c === undefined ? fallback : SparkColor.toHex(c);
}

/** The format after `f` in {@link SPARK_COLOR_FORMATS} (wraps). */
export function sparkNextColorFormat(f: ColorPickerFormat): ColorPickerFormat {
  const i = SPARK_COLOR_FORMATS.indexOf(f);
  return SPARK_COLOR_FORMATS[(i + 1) % SPARK_COLOR_FORMATS.length];
}

/** Short label of a format (`HEX`, `RGB`, `HSL`, `OKLCH`). */
export function sparkColorFormatLabel(f: ColorPickerFormat): string {
  return f.toUpperCase();
}

/**
 * Most-recent-first list with `value` added: case-insensitive duplicates of the same colour (compared as ARGB) are
 * removed, and the list is cut to `limit`. Unparseable values are ignored.
 */
export function sparkPushRecent(list: string[], value: string, limit: number): string[] {
  const key = sparkColorValueToArgb(value, '');
  if (key.length === 0 || limit <= 0) {
    return list.slice(0, Math.max(0, limit));
  }
  const rest = list.filter((v: string) => sparkColorValueToArgb(v, '') !== key);
  return [value].concat(rest).slice(0, limit);
}

/** Ratio [0, 1] of a position `p` along a track of `length` with a thumb of `thumb` (centre-based). */
export function sparkTrackRatio(p: number, length: number, thumb: number): number {
  const usable = length - thumb;
  if (!(usable > 0)) {
    return 0;
  }
  return sparkColorClamp((p - thumb / 2) / usable, 0, 1);
}

/** Saturation / value of a point (x, y) in an area of `w` × `h` (value grows upward). */
export function sparkAreaToSv(x: number, y: number, w: number, h: number): number[] {
  const s = w > 0 ? sparkColorClamp(x / w, 0, 1) : 0;
  const v = h > 0 ? 1 - sparkColorClamp(y / h, 0, 1) : 0;
  return [s, v];
}

/** Hue stops of the hue slider gradient (red → yellow → green → cyan → blue → magenta → red), ARGB. */
export function sparkHueStops(): string[] {
  const out: string[] = [];
  for (let i = 0; i <= 6; i++) {
    out.push(SparkColor.toHex(sparkHsvToRgb(i * 60, 1, 1, 1)));
  }
  return out;
}

/** Two colours equal once formatted the same way (used to ignore echoes of the picker's own value). */
export function sparkSameColor(a: string, b: string): boolean {
  if (a === b) {
    return true;
  }
  const x = sparkColorValueToArgb(a, '');
  return x.length > 0 && x === sparkColorValueToArgb(b, '');
}
