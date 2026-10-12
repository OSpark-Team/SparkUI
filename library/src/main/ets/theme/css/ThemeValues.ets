import { ColorParseResult, SparkColor } from '../color/SparkColor';
import { SparkShadow } from '../tokens/SparkShadow';

/** CSS `rem` → vp. */
export const THEME_REM_VP: number = 16;

/**
 * Value parsers of the theme CSS subset, shared by the resolver (semantic / global tokens), the component
 * token store and per-instance `tokens` overrides. Every parser is total: it returns NaN / undefined instead
 * of throwing.
 */
export class ThemeValues {
  /** `0.625rem` → 10, `12px` / `12vp` / `12` → 12. CSS px are logical pixels, i.e. vp. NaN on failure. */
  static plainLength(value: string): number {
    const m = /^(-?\d*\.?\d+)(rem|px|vp|em)?$/.exec(value.trim().toLowerCase());
    if (m === null) {
      return NaN;
    }
    const n = parseFloat(m[1]);
    const unit = m[2];
    if (unit === 'rem' || unit === 'em') {
      return n * THEME_REM_VP;
    }
    return n;
  }

  /**
   * A length: plain (`8px`, `0.5rem`, `12`), `0` / `none` (→ 0) or `calc()` with + - * / and parentheses,
   * e.g. `calc(0.625rem - 2px)` (what `calc(var(--radius) - 2px)` becomes after var() substitution).
   */
  static len(value: string): number {
    const v = value.trim().toLowerCase();
    if (v === 'none') {
      return 0;
    }
    const plain = ThemeValues.plainLength(v);
    if (!isNaN(plain)) {
      return plain;
    }
    if (v.startsWith('calc(') && v.endsWith(')')) {
      return new CalcParser(v.substring(5, v.length - 1)).run();
    }
    return NaN;
  }

  /** `true|1|on|yes` / `false|0|off|no|none`; undefined otherwise. */
  static bool(value: string): boolean | undefined {
    const v = value.trim().toLowerCase();
    if (v === 'true' || v === '1' || v === 'on' || v === 'yes') {
      return true;
    }
    if (v === 'false' || v === '0' || v === 'off' || v === 'no' || v === 'none') {
      return false;
    }
    return undefined;
  }

  /** Unitless number (`600`, `0.97`) or percentage (`50%` → 0.5). NaN otherwise. */
  static num(value: string): number {
    const m = /^(-?\d*\.?\d+)(%)?$/.exec(value.trim());
    if (m === null) {
      return NaN;
    }
    const n = parseFloat(m[1]);
    return m[2] === '%' ? n / 100 : n;
  }

  /** Any SparkColor syntax plus `none` (→ transparent) and `color-mix()` (see SparkColor.parse). */
  static color(value: string): ColorParseResult {
    if (value.trim().toLowerCase() === 'none') {
      return ColorParseResult.success('#00000000');
    }
    return SparkColor.parse(value);
  }

  /** First layer of a CSS box-shadow → SparkShadow. `none` → transparent shadow. undefined when invalid. */
  static shadow(value: string): SparkShadow | undefined {
    const v = value.trim();
    if (v.toLowerCase() === 'none') {
      return SparkShadow.none();
    }
    // split top-level by comma, take first layer
    let depth = 0;
    let first = v;
    for (let i = 0; i < v.length; i++) {
      const ch = v[i];
      if (ch === '(') {
        depth++;
      } else if (ch === ')') {
        depth--;
      } else if (ch === ',' && depth === 0) {
        first = v.substring(0, i);
        break;
      }
    }
    // tokenise by whitespace outside parentheses
    const tokens: string[] = [];
    let cur = '';
    depth = 0;
    for (let i = 0; i < first.length; i++) {
      const ch = first[i];
      if (ch === '(') {
        depth++;
      } else if (ch === ')') {
        depth--;
      }
      if (/\s/.test(ch) && depth === 0) {
        if (cur.length > 0) {
          tokens.push(cur);
        }
        cur = '';
      } else {
        cur += ch;
      }
    }
    if (cur.length > 0) {
      tokens.push(cur);
    }
    const lengths: number[] = [];
    let color = '#1A000000';
    for (const tok of tokens) {
      if (tok === 'inset') {
        continue;
      }
      const len = ThemeValues.plainLength(tok);
      if (!isNaN(len)) {
        lengths.push(len);
        continue;
      }
      const c = SparkColor.parse(tok);
      if (!c.ok) {
        return undefined;
      }
      color = c.value;
    }
    if (lengths.length < 2) {
      return undefined;
    }
    return new SparkShadow(lengths[0], lengths[1], lengths.length > 2 ? lengths[2] : 0, color);
  }
}

/** Tiny recursive-descent evaluator for `calc()` bodies (lengths in vp, unitless factors). NaN on error. */
class CalcParser {
  private s: string;
  private i: number = 0;

  constructor(s: string) {
    this.s = s;
  }

  run(): number {
    const v = this.expr();
    this.ws();
    return this.i === this.s.length ? v : NaN;
  }

  private ws(): void {
    while (this.i < this.s.length && /\s/.test(this.s[this.i])) {
      this.i++;
    }
  }

  private expr(): number {
    let v = this.term();
    for (; ; ) {
      this.ws();
      const ch = this.s[this.i];
      if (ch === '+' || ch === '-') {
        this.i++;
        const r = this.term();
        v = ch === '+' ? v + r : v - r;
      } else {
        return v;
      }
    }
  }

  private term(): number {
    let v = this.factor();
    for (; ; ) {
      this.ws();
      const ch = this.s[this.i];
      if (ch === '*' || ch === '/') {
        this.i++;
        const r = this.factor();
        v = ch === '*' ? v * r : v / r;
      } else {
        return v;
      }
    }
  }

  private factor(): number {
    this.ws();
    if (this.s[this.i] === '(') {
      this.i++;
      const v = this.expr();
      this.ws();
      if (this.s[this.i] !== ')') {
        return NaN;
      }
      this.i++;
      return v;
    }
    if (this.s.startsWith('calc(', this.i)) {
      this.i += 4;
      return this.factor();
    }
    const m = /^-?\d*\.?\d+(rem|px|vp|em)?/.exec(this.s.substring(this.i));
    if (m === null) {
      this.i = this.s.length + 1;
      return NaN;
    }
    this.i += m[0].length;
    return ThemeValues.plainLength(m[0]);
  }
}
