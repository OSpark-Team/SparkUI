import { SparkColor, ColorParseResult } from '../color/SparkColor';
import { SPARK_COLOR_TOKENS } from '../tokens/SparkColors';
import { SparkShadow, SparkTheme } from '../tokens/SparkTheme';
import { ThemeDiagnostic, ThemeSource, ThemeVar } from './ThemeSource';

/** CSS `rem` → vp. */
export const REM_VP: number = 16;

/**
 * Turns a raw {@link ThemeSource} into concrete token values on a {@link SparkTheme}.
 *
 * Cascade: `:root` → `@size(<current>)` → `.dark` (when dark). Every variable is validated on its own;
 * an invalid value keeps the value already present on the target (the preset default) and produces a
 * typed diagnostic, so a broken theme file can never crash the app or blank the UI.
 */
export class ThemeResolver {
  /**
   * @param target theme pre-filled with defaults; values are written in place.
   * @returns diagnostics produced while applying (parse diagnostics stay on the source).
   */
  static apply(source: ThemeSource, isDark: boolean, size: string, target: SparkTheme): ThemeDiagnostic[] {
    const diags: ThemeDiagnostic[] = [];
    const vars = new Map<string, ThemeVar>();
    source.root.forEach((v: ThemeVar, k: string) => {
      vars.set(k, v);
    });
    const sizeVars = source.sizes.get(size);
    if (sizeVars !== undefined) {
      sizeVars.forEach((v: ThemeVar, k: string) => {
        vars.set(k, v);
      });
    }
    if (isDark) {
      source.dark.forEach((v: ThemeVar, k: string) => {
        vars.set(k, v);
      });
    }
    target.isDark = isDark;
    vars.forEach((v: ThemeVar, name: string) => {
      const value = ThemeResolver.substitute(v.value, vars, 0);
      if (value === undefined) {
        diags.push(new ThemeDiagnostic('error', v.line, name, `unresolvable var() in "${v.value}"`));
        return;
      }
      const d = ThemeResolver.applyVar(target, name, value, v.line);
      if (d !== undefined) {
        diags.push(d);
      }
    });
    return diags;
  }

  /** Resolve `var(--x, fallback)` references. Returns undefined on cycles / missing vars without fallback. */
  static substitute(value: string, vars: Map<string, ThemeVar>, depth: number): string | undefined {
    if (value.indexOf('var(') < 0) {
      return value;
    }
    if (depth > 8) {
      return undefined;
    }
    const m = /var\(\s*(--[a-zA-Z0-9_-]+)\s*(?:,\s*([^)]*))?\)/.exec(value);
    if (m === null) {
      return undefined;
    }
    const ref = vars.get(m[1]);
    let replacement: string | undefined = undefined;
    if (ref !== undefined) {
      replacement = ThemeResolver.substitute(ref.value, vars, depth + 1);
    } else if (m[2] !== undefined) {
      replacement = m[2].trim();
    }
    if (replacement === undefined) {
      return undefined;
    }
    const next = value.substring(0, m.index) + replacement + value.substring(m.index + m[0].length);
    return ThemeResolver.substitute(next, vars, depth + 1);
  }

  /** Apply one resolved variable. Returns a diagnostic when the value is rejected or the name unknown. */
  static applyVar(t: SparkTheme, name: string, value: string, line: number): ThemeDiagnostic | undefined {
    const key = name.substring(2);
    if (SPARK_COLOR_TOKENS.includes(key)) {
      const c: ColorParseResult = SparkColor.parse(value);
      if (!c.ok) {
        return new ThemeDiagnostic('error', line, name, `${c.error}; keeping default`);
      }
      t.colors.set(key, c.value);
      return undefined;
    }
    if (key === 'radius' || key === 'spacing') {
      const len = ThemeResolver.parseLength(value);
      if (isNaN(len) || len < 0) {
        return new ThemeDiagnostic('error', line, name, `invalid length "${value}"; keeping default`);
      }
      if (key === 'radius') {
        t.radius = len;
      } else {
        t.spacing = len;
      }
      return undefined;
    }
    if (key.startsWith('shadow-')) {
      const which = key.substring(7);
      if (!['xs', 'sm', 'md', 'lg', 'xl', '2xl'].includes(which)) {
        return new ThemeDiagnostic('info', line, name, 'shadow parameter not used by SparkUI; skipped');
      }
      const s = ThemeResolver.parseShadow(value);
      if (s === undefined) {
        return new ThemeDiagnostic('error', line, name, `invalid shadow "${value}"; keeping default`);
      }
      t.shadows.set(which, s);
      return undefined;
    }
    if (key.startsWith('text-')) {
      const rest = key.substring(5);
      const isLeading = rest.endsWith('--line-height');
      const size = isLeading ? rest.substring(0, rest.length - 13) : rest;
      const len = ThemeResolver.parseLength(value);
      if (isNaN(len) || len <= 0) {
        return new ThemeDiagnostic('error', line, name, `invalid length "${value}"; keeping default`);
      }
      const ok = isLeading ? t.text.setLeading(size, len) : t.text.setSize(size, len);
      return ok ? undefined : new ThemeDiagnostic('warning', line, name, 'unknown text size; ignored');
    }
    if (key.startsWith('font-weight-')) {
      const w = parseFloat(value);
      if (isNaN(w) || w < 100 || w > 900) {
        return new ThemeDiagnostic('error', line, name, `invalid font weight "${value}"; keeping default`);
      }
      return t.text.setWeight(key.substring(12), w) ? undefined :
        new ThemeDiagnostic('warning', line, name, 'unknown font weight; ignored');
    }
    if (key === 'motion-enabled') {
      const b = ThemeResolver.parseBool(value);
      if (b === undefined) {
        return new ThemeDiagnostic('error', line, name, `expected true/false/1/0, got "${value}"`);
      }
      t.motion.enabled = b;
      return undefined;
    }
    if (key.startsWith('motion-')) {
      // --motion-<component>-duration | -ease | -enabled
      const rest = key.substring(7);
      const dash = rest.lastIndexOf('-');
      if (dash <= 0) {
        return new ThemeDiagnostic('warning', line, name, 'expected --motion-<component>-duration|ease|enabled');
      }
      const component = rest.substring(0, dash);
      const prop = rest.substring(dash + 1);
      const o = t.motion.override(component);
      if (prop === 'duration') {
        const ms = ThemeResolver.parseTime(value);
        if (isNaN(ms) || ms < 0) {
          return new ThemeDiagnostic('error', line, name, `invalid duration "${value}"`);
        }
        o.duration = ms;
      } else if (prop === 'ease') {
        if (!ThemeResolver.isEase(value)) {
          return new ThemeDiagnostic('error', line, name, `invalid easing "${value}"`);
        }
        o.ease = value.trim().toLowerCase();
      } else if (prop === 'enabled') {
        const b = ThemeResolver.parseBool(value);
        if (b === undefined) {
          return new ThemeDiagnostic('error', line, name, `expected true/false/1/0, got "${value}"`);
        }
        o.enabled = b;
      } else {
        return new ThemeDiagnostic('warning', line, name, 'expected --motion-<component>-duration|ease|enabled');
      }
      t.motion.version++;
      return undefined;
    }
    if (key.startsWith('duration-')) {
      const ms = ThemeResolver.parseTime(value);
      if (isNaN(ms) || ms < 0) {
        return new ThemeDiagnostic('error', line, name, `invalid duration "${value}"; keeping default`);
      }
      const which = key.substring(9);
      if (which === 'fast') {
        t.motion.durationFast = ms;
      } else if (which === 'normal') {
        t.motion.durationNormal = ms;
      } else if (which === 'slow') {
        t.motion.durationSlow = ms;
      } else {
        return new ThemeDiagnostic('warning', line, name, 'unknown duration; ignored');
      }
      return undefined;
    }
    if (key.startsWith('ease-')) {
      const curve = ThemeResolver.parseCubicBezier(value);
      if (curve === undefined) {
        return new ThemeDiagnostic('error', line, name, `invalid cubic-bezier "${value}"; keeping default`);
      }
      const which = key.substring(5);
      if (which === 'standard') {
        t.motion.easeStandard = curve;
      } else if (which === 'in') {
        t.motion.easeIn = curve;
      } else if (which === 'out') {
        t.motion.easeOut = curve;
      } else {
        return new ThemeDiagnostic('warning', line, name, 'unknown easing; ignored');
      }
      return undefined;
    }
    if (key.startsWith('font-') || key.startsWith('tracking') || key === 'letter-spacing') {
      return new ThemeDiagnostic('info', line, name, 'typography family/tracking not supported yet; skipped');
    }
    return new ThemeDiagnostic('warning', line, name, 'unknown variable; ignored');
  }

  /** `0.625rem` → 10, `12px` / `12vp` / `12` → 12. CSS px are logical pixels, i.e. vp. NaN on failure. */
  static parseLength(value: string): number {
    const m = /^(-?\d*\.?\d+)(rem|px|vp|em)?$/.exec(value.trim().toLowerCase());
    if (m === null) {
      return NaN;
    }
    const n = parseFloat(m[1]);
    const unit = m[2];
    if (unit === 'rem' || unit === 'em') {
      return n * REM_VP;
    }
    return n;
  }

  /** `150ms` / `0.15s` → milliseconds. */
  static parseTime(value: string): number {
    const m = /^(\d*\.?\d+)(ms|s)?$/.exec(value.trim().toLowerCase());
    if (m === null) {
      return NaN;
    }
    const n = parseFloat(m[1]);
    return m[2] === 's' ? n * 1000 : n;
  }

  static parseBool(value: string): boolean | undefined {
    const v = value.trim().toLowerCase();
    if (v === 'true' || v === '1' || v === 'on') {
      return true;
    }
    if (v === 'false' || v === '0' || v === 'off' || v === 'none') {
      return false;
    }
    return undefined;
  }

  /** CSS-like easing accepted by SparkAnim: keywords, cubic-bezier(a,b,c,d), spring(response, damping). */
  static isEase(value: string): boolean {
    const v = value.trim().toLowerCase();
    if (['linear', 'ease', 'ease-in', 'ease-out', 'ease-in-out', 'standard', 'friction', 'sharp', 'smooth',
      'rhythm'].includes(v)) {
      return true;
    }
    if (ThemeResolver.parseCubicBezier(v) !== undefined) {
      return true;
    }
    const m = /^spring\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)$/.exec(v);
    return m !== null;
  }

  static parseCubicBezier(value: string): number[] | undefined {
    const m = /^cubic-bezier\(([^)]*)\)$/.exec(value.trim().toLowerCase());
    if (m === null) {
      return undefined;
    }
    const parts = m[1].split(',').map((s: string) => parseFloat(s.trim()));
    if (parts.length !== 4 || parts.some((n: number) => isNaN(n))) {
      return undefined;
    }
    return parts;
  }

  /** First layer of a CSS box-shadow → SparkShadow. `none` → transparent shadow. */
  static parseShadow(value: string): SparkShadow | undefined {
    const v = value.trim();
    if (v.toLowerCase() === 'none') {
      return new SparkShadow(0, 0, 0, '#00000000');
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
      const len = ThemeResolver.parseLength(tok);
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
