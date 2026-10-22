/**
 * SparkColor — CSS color parsing and conversion.
 *
 * Supported inputs: oklch(), oklab(), hsl()/hsla(), rgb()/rgba(), #hex (3/4/6/8),
 * shadcn v1 bare HSL triplets ("222.2 84% 4.9%"), and a few keywords.
 * Output is always an ARGB hex string "#AARRGGBB", which ArkUI accepts as ResourceColor
 * (numbers are avoided because ArkUI treats 0x00RRGGBB as opaque).
 *
 * oklch → sRGB uses the CSS Color 4 gamut-mapping algorithm (chroma reduction in OKLCh
 * with deltaE-OK JND = 0.02), so out-of-gamut colours from tweakcn exports render faithfully.
 */

export class Rgba {
  /** 0..1, may be out of range before gamut mapping */
  r: number = 0;
  g: number = 0;
  b: number = 0;
  /** 0..1 */
  a: number = 1;

  constructor(r: number, g: number, b: number, a: number) {
    this.r = r;
    this.g = g;
    this.b = b;
    this.a = a;
  }
}

export class ColorParseResult {
  ok: boolean = false;
  /** "#AARRGGBB" when ok */
  value: string = '';
  error: string = '';

  static success(value: string): ColorParseResult {
    const r = new ColorParseResult();
    r.ok = true;
    r.value = value;
    return r;
  }

  static failure(error: string): ColorParseResult {
    const r = new ColorParseResult();
    r.error = error;
    return r;
  }
}

class Oklab {
  l: number;
  a: number;
  b: number;

  constructor(l: number, a: number, b: number) {
    this.l = l;
    this.a = a;
    this.b = b;
  }
}

const JND: number = 0.02;
const GAMUT_EPSILON: number = 0.0001;

function clamp01(v: number): number {
  return v < 0 ? 0 : (v > 1 ? 1 : v);
}

function srgbEncode(c: number): number {
  const sign = c < 0 ? -1 : 1;
  const abs = Math.abs(c);
  if (abs <= 0.0031308) {
    return c * 12.92;
  }
  return sign * (1.055 * Math.pow(abs, 1 / 2.4) - 0.055);
}

function srgbDecode(c: number): number {
  const sign = c < 0 ? -1 : 1;
  const abs = Math.abs(c);
  if (abs <= 0.04045) {
    return c / 12.92;
  }
  return sign * Math.pow((abs + 0.055) / 1.055, 2.4);
}

/** OKLab → gamma-encoded sRGB (unclamped). */
function oklabToSrgb(lab: Oklab): Rgba {
  const l_ = lab.l + 0.3963377774 * lab.a + 0.2158037573 * lab.b;
  const m_ = lab.l - 0.1055613458 * lab.a - 0.0638541728 * lab.b;
  const s_ = lab.l - 0.0894841775 * lab.a - 1.2914855480 * lab.b;
  const l = l_ * l_ * l_;
  const m = m_ * m_ * m_;
  const s = s_ * s_ * s_;
  const r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  const g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  const b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
  return new Rgba(srgbEncode(r), srgbEncode(g), srgbEncode(b), 1);
}

/** gamma-encoded sRGB → OKLab. */
function srgbToOklab(c: Rgba): Oklab {
  const r = srgbDecode(c.r);
  const g = srgbDecode(c.g);
  const b = srgbDecode(c.b);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return new Oklab(
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  );
}

function inGamut(c: Rgba): boolean {
  return c.r >= -GAMUT_EPSILON && c.r <= 1 + GAMUT_EPSILON &&
    c.g >= -GAMUT_EPSILON && c.g <= 1 + GAMUT_EPSILON &&
    c.b >= -GAMUT_EPSILON && c.b <= 1 + GAMUT_EPSILON;
}

function clipRgb(c: Rgba): Rgba {
  return new Rgba(clamp01(c.r), clamp01(c.g), clamp01(c.b), c.a);
}

function deltaEOK(x: Oklab, y: Oklab): number {
  const dl = x.l - y.l;
  const da = x.a - y.a;
  const db = x.b - y.b;
  return Math.sqrt(dl * dl + da * da + db * db);
}

function lchToLab(l: number, c: number, hDeg: number): Oklab {
  const h = hDeg * Math.PI / 180;
  return new Oklab(l, c * Math.cos(h), c * Math.sin(h));
}

export class SparkColor {
  /**
   * OKLCh → sRGB with CSS Color 4 gamut mapping.
   * @param l lightness 0..1
   * @param c chroma >= 0
   * @param h hue in degrees
   */
  static oklchToRgb(l: number, c: number, h: number, alpha: number): Rgba {
    if (l >= 1) {
      return new Rgba(1, 1, 1, alpha);
    }
    if (l <= 0) {
      return new Rgba(0, 0, 0, alpha);
    }
    const origin = oklabToSrgb(lchToLab(l, c, h));
    if (inGamut(origin)) {
      const ok = clipRgb(origin);
      ok.a = alpha;
      return ok;
    }
    // CSS Color 4 §13.2.2 binary search on chroma.
    let min = 0;
    let max = c;
    let minInGamut = true;
    let current = origin;
    let clipped = clipRgb(current);
    let e = deltaEOK(srgbToOklab(clipped), lchToLab(l, c, h));
    if (e < JND) {
      clipped.a = alpha;
      return clipped;
    }
    let guard = 0;
    while (max - min > GAMUT_EPSILON && guard < 64) {
      guard++;
      const chroma = (min + max) / 2;
      const candidateLab = lchToLab(l, chroma, h);
      current = oklabToSrgb(candidateLab);
      if (minInGamut && inGamut(current)) {
        min = chroma;
        continue;
      }
      clipped = clipRgb(current);
      e = deltaEOK(srgbToOklab(clipped), candidateLab);
      if (e < JND) {
        if (JND - e < GAMUT_EPSILON) {
          break;
        }
        minInGamut = false;
        min = chroma;
      } else {
        max = chroma;
      }
    }
    const result = clipRgb(current);
    result.a = alpha;
    return result;
  }

  static oklabToRgb(l: number, a: number, b: number, alpha: number): Rgba {
    const c = Math.sqrt(a * a + b * b);
    let h = Math.atan2(b, a) * 180 / Math.PI;
    if (h < 0) {
      h += 360;
    }
    return SparkColor.oklchToRgb(l, c, h, alpha);
  }

  /** h degrees, s/l 0..1 */
  static hslToRgb(h: number, s: number, l: number, alpha: number): Rgba {
    const hh = ((h % 360) + 360) % 360;
    const f = (n: number): number => {
      const k = (n + hh / 30) % 12;
      const a = s * Math.min(l, 1 - l);
      return l - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
    };
    return new Rgba(f(0), f(8), f(4), alpha);
  }

  static rgbToOklch(c: Rgba): number[] {
    const lab = srgbToOklab(c);
    const chroma = Math.sqrt(lab.a * lab.a + lab.b * lab.b);
    let h = Math.atan2(lab.b, lab.a) * 180 / Math.PI;
    if (h < 0) {
      h += 360;
    }
    return [lab.l, chroma, chroma < 0.0001 ? 0 : h];
  }

  static toHex(c: Rgba): string {
    return '#' + SparkColor.hex2(Math.round(clamp01(c.a) * 255)) +
      SparkColor.hex2(Math.round(clamp01(c.r) * 255)) +
      SparkColor.hex2(Math.round(clamp01(c.g) * 255)) +
      SparkColor.hex2(Math.round(clamp01(c.b) * 255));
  }

  /** "#AARRGGBB" → Rgba. Accepts #RGB/#RGBA/#RRGGBB/#RRGGBBAA (CSS order) only via parse(). */
  static fromArgbHex(hex: string): Rgba {
    const v = hex.startsWith('#') ? hex.substring(1) : hex;
    if (v.length === 8) {
      return new Rgba(
        parseInt(v.substring(2, 4), 16) / 255,
        parseInt(v.substring(4, 6), 16) / 255,
        parseInt(v.substring(6, 8), 16) / 255,
        parseInt(v.substring(0, 2), 16) / 255
      );
    }
    if (v.length === 6) {
      return new Rgba(
        parseInt(v.substring(0, 2), 16) / 255,
        parseInt(v.substring(2, 4), 16) / 255,
        parseInt(v.substring(4, 6), 16) / 255,
        1
      );
    }
    return new Rgba(0, 0, 0, 0);
  }

  /**
   * ArkUI `#AARRGGBB` (every `theme.colors.*` value, `SparkColor.alpha` / `mix` results) → CSS `#RRGGBBAA`, the
   * theme-file syntax that component `tokens` take: `tokens: { foreground: SparkColor.toCss(theme.colors.primary) }`.
   * `#RRGGBB` and anything else is returned unchanged.
   */
  static toCss(argbHex: string): string {
    const v = argbHex.trim();
    if (/^#[0-9a-fA-F]{8}$/.test(v)) {
      return `#${v.substring(3)}${v.substring(1, 3)}`;
    }
    return v;
  }

  /** Multiply the alpha channel, like Tailwind `bg-primary/90`. */
  static alpha(argbHex: string, opacity: number): string {
    const c = SparkColor.fromArgbHex(argbHex);
    c.a = clamp01(c.a * opacity);
    return SparkColor.toHex(c);
  }

  /** Linear blend in sRGB, t = 0 → a, t = 1 → b. Used for colour transitions. */
  static mix(a: string, b: string, t: number): string {
    const x = SparkColor.fromArgbHex(a);
    const y = SparkColor.fromArgbHex(b);
    const k = clamp01(t);
    return SparkColor.toHex(new Rgba(
      x.r + (y.r - x.r) * k,
      x.g + (y.g - x.g) * k,
      x.b + (y.b - x.b) * k,
      x.a + (y.a - x.a) * k
    ));
  }

  /** Relative luminance (WCAG). */
  static luminance(argbHex: string): number {
    const c = SparkColor.fromArgbHex(argbHex);
    return 0.2126 * srgbDecode(c.r) + 0.7152 * srgbDecode(c.g) + 0.0722 * srgbDecode(c.b);
  }

  static isDark(argbHex: string): boolean {
    return SparkColor.luminance(argbHex) < 0.18;
  }

  /** Parse any supported CSS colour into "#AARRGGBB". Never throws. */
  static parse(input: string): ColorParseResult {
    const raw = input.trim().toLowerCase();
    if (raw.length === 0) {
      return ColorParseResult.failure('empty color');
    }
    try {
      if (raw === 'transparent') {
        return ColorParseResult.success('#00000000');
      }
      if (raw === 'white') {
        return ColorParseResult.success('#FFFFFFFF');
      }
      if (raw === 'black') {
        return ColorParseResult.success('#FF000000');
      }
      if (raw.startsWith('#')) {
        return SparkColor.parseHex(raw.substring(1));
      }
      if (raw.startsWith('color-mix(') && raw.endsWith(')')) {
        return SparkColor.parseColorMix(raw.substring(10, raw.length - 1));
      }
      const open = raw.indexOf('(');
      if (open > 0 && raw.endsWith(')')) {
        const fn = raw.substring(0, open).trim();
        const body = raw.substring(open + 1, raw.length - 1);
        return SparkColor.parseFunction(fn, body);
      }
      // shadcn v1 bare HSL triplet: "222.2 84% 4.9%" (optionally "/ alpha")
      const bare = SparkColor.splitArgs(raw);
      if (bare !== undefined && bare.values.length === 3 && bare.values[1].endsWith('%') &&
        bare.values[2].endsWith('%')) {
        return SparkColor.parseFunction('hsl', raw);
      }
    } catch (e) {
      return ColorParseResult.failure(`invalid color "${input}"`);
    }
    return ColorParseResult.failure(`unsupported color "${input}"`);
  }

  private static hex2(v: number): string {
    const s = v.toString(16).toUpperCase();
    return s.length === 1 ? '0' + s : s;
  }

  private static parseHex(v: string): ColorParseResult {
    if (!/^[0-9a-f]+$/.test(v)) {
      return ColorParseResult.failure(`invalid hex "#${v}"`);
    }
    let r = 0;
    let g = 0;
    let b = 0;
    let a = 255;
    if (v.length === 3 || v.length === 4) {
      r = parseInt(v[0] + v[0], 16);
      g = parseInt(v[1] + v[1], 16);
      b = parseInt(v[2] + v[2], 16);
      if (v.length === 4) {
        a = parseInt(v[3] + v[3], 16);
      }
    } else if (v.length === 6 || v.length === 8) {
      r = parseInt(v.substring(0, 2), 16);
      g = parseInt(v.substring(2, 4), 16);
      b = parseInt(v.substring(4, 6), 16);
      if (v.length === 8) {
        a = parseInt(v.substring(6, 8), 16);
      }
    } else {
      return ColorParseResult.failure(`invalid hex length "#${v}"`);
    }
    return ColorParseResult.success(SparkColor.toHex(new Rgba(r / 255, g / 255, b / 255, a / 255)));
  }

  private static splitArgs(body: string): SplitArgs | undefined {
    let main = body;
    let alpha: string | undefined = undefined;
    const slash = body.indexOf('/');
    if (slash >= 0) {
      main = body.substring(0, slash);
      alpha = body.substring(slash + 1).trim();
    }
    const values = main.split(/[\s,]+/).filter((s: string) => s.length > 0);
    if (alpha === undefined && values.length === 4) {
      alpha = values.pop();
    }
    const result = new SplitArgs();
    result.values = values;
    result.alpha = alpha;
    return result;
  }

  /** number or percentage; `percentScale` is what 100% means. Returns NaN on failure. */
  private static num(token: string, percentScale: number): number {
    if (token === 'none') {
      return 0;
    }
    if (token.endsWith('%')) {
      return parseFloat(token.substring(0, token.length - 1)) / 100 * percentScale;
    }
    if (!/^[-+]?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?$/.test(token)) {
      return NaN;
    }
    return parseFloat(token);
  }

  private static hue(token: string): number {
    if (token.endsWith('deg')) {
      return parseFloat(token.substring(0, token.length - 3));
    }
    if (token.endsWith('turn')) {
      return parseFloat(token.substring(0, token.length - 4)) * 360;
    }
    if (token.endsWith('grad')) {
      return parseFloat(token.substring(0, token.length - 4)) * 0.9;
    }
    if (token.endsWith('rad')) {
      return parseFloat(token.substring(0, token.length - 3)) * 180 / Math.PI;
    }
    return SparkColor.num(token, 360);
  }

  /**
   * `color-mix(in <space>, <color> [p%], <color> [p%])`, interpolated with premultiplied alpha in sRGB whatever
   * the named space (the space only changes hue paths, which theme tints do not depend on). Percentages
   * summing below 100% scale the alpha, as in CSS: `color-mix(in oklab, var(--primary) 10%, transparent)`.
   */
  private static parseColorMix(body: string): ColorParseResult {
    const parts: string[] = [];
    let depth = 0;
    let start = 0;
    for (let i = 0; i < body.length; i++) {
      const ch = body[i];
      if (ch === '(') {
        depth++;
      } else if (ch === ')') {
        depth--;
      } else if (ch === ',' && depth === 0) {
        parts.push(body.substring(start, i).trim());
        start = i + 1;
      }
    }
    parts.push(body.substring(start).trim());
    if (parts.length !== 3 || !parts[0].startsWith('in ')) {
      return ColorParseResult.failure(`color-mix() expects "in <space>, <color> [p%], <color> [p%]"`);
    }
    const a = SparkColor.mixStop(parts[1]);
    const b = SparkColor.mixStop(parts[2]);
    if (a === undefined || b === undefined) {
      return ColorParseResult.failure(`invalid color in color-mix(${body})`);
    }
    let pa = a.percent;
    let pb = b.percent;
    if (isNaN(pa) && isNaN(pb)) {
      pa = 0.5;
      pb = 0.5;
    } else if (isNaN(pa)) {
      pa = 1 - pb;
    } else if (isNaN(pb)) {
      pb = 1 - pa;
    }
    const sum = pa + pb;
    if (sum <= 0) {
      return ColorParseResult.failure(`color-mix() percentages must not both be 0`);
    }
    const wa = pa / sum;
    const wb = pb / sum;
    const x = SparkColor.fromArgbHex(a.color);
    const y = SparkColor.fromArgbHex(b.color);
    const alpha = x.a * wa + y.a * wb;
    const out = alpha <= 0 ? new Rgba(0, 0, 0, 0) : new Rgba(
      (x.r * x.a * wa + y.r * y.a * wb) / alpha,
      (x.g * x.a * wa + y.g * y.a * wb) / alpha,
      (x.b * x.a * wa + y.b * y.a * wb) / alpha,
      alpha * Math.min(1, sum)
    );
    return ColorParseResult.success(SparkColor.toHex(out));
  }

  /** `<color> [p%]` of a color-mix() argument; percent is NaN when omitted. */
  private static mixStop(arg: string): MixStop | undefined {
    const m = /^(.*?)\s+(\d*\.?\d+)%$/.exec(arg);
    const stop = new MixStop();
    let colorText = arg;
    if (m !== null) {
      colorText = m[1];
      stop.percent = parseFloat(m[2]) / 100;
    }
    const c = SparkColor.parse(colorText);
    if (!c.ok) {
      return undefined;
    }
    stop.color = c.value;
    return stop;
  }

  private static parseFunction(fn: string, body: string): ColorParseResult {
    const args = SparkColor.splitArgs(body);
    if (args === undefined || args.values.length !== 3) {
      return ColorParseResult.failure(`${fn}() expects 3 components`);
    }
    const v = args.values;
    const alpha = args.alpha === undefined ? 1 : SparkColor.num(args.alpha, 1);
    let rgba: Rgba;
    if (fn === 'oklch') {
      rgba = SparkColor.oklchToRgb(SparkColor.num(v[0], 1), SparkColor.num(v[1], 0.4), SparkColor.hue(v[2]), alpha);
      if (isNaN(SparkColor.num(v[0], 1)) || isNaN(SparkColor.num(v[1], 0.4)) || isNaN(SparkColor.hue(v[2]))) {
        return ColorParseResult.failure(`invalid oklch(${body})`);
      }
    } else if (fn === 'oklab') {
      const l = SparkColor.num(v[0], 1);
      const a = SparkColor.num(v[1], 0.4);
      const b = SparkColor.num(v[2], 0.4);
      if (isNaN(l) || isNaN(a) || isNaN(b)) {
        return ColorParseResult.failure(`invalid oklab(${body})`);
      }
      rgba = SparkColor.oklabToRgb(l, a, b, alpha);
    } else if (fn === 'hsl' || fn === 'hsla') {
      const h = SparkColor.hue(v[0]);
      const s = SparkColor.num(v[1], 1);
      const l = SparkColor.num(v[2], 1);
      if (isNaN(h) || isNaN(s) || isNaN(l)) {
        return ColorParseResult.failure(`invalid hsl(${body})`);
      }
      // legacy unitless s/l in 0..100
      rgba = SparkColor.hslToRgb(h, v[1].endsWith('%') ? s : s / 100, v[2].endsWith('%') ? l : l / 100, alpha);
    } else if (fn === 'rgb' || fn === 'rgba') {
      const r = SparkColor.num(v[0], 255);
      const g = SparkColor.num(v[1], 255);
      const b = SparkColor.num(v[2], 255);
      if (isNaN(r) || isNaN(g) || isNaN(b)) {
        return ColorParseResult.failure(`invalid rgb(${body})`);
      }
      rgba = new Rgba(r / 255, g / 255, b / 255, alpha);
    } else {
      return ColorParseResult.failure(`unsupported color function ${fn}()`);
    }
    if (isNaN(alpha)) {
      return ColorParseResult.failure(`invalid alpha in ${fn}(${body})`);
    }
    return ColorParseResult.success(SparkColor.toHex(rgba));
  }
}

class MixStop {
  color: string = '#00000000';
  percent: number = NaN;
}

class SplitArgs {
  values: string[] = [];
  alpha: string | undefined = undefined;
}
