import { SparkColor, ColorParseResult } from '../color/SparkColor';
import { SPARK_COLOR_TOKENS } from '../tokens/SparkColors';
import { SparkComponentTokenRegistry, SparkTokenMatch, SparkTokenValue } from '../tokens/SparkComponentTokens';
import { SparkShadow, SparkTheme } from '../tokens/SparkTheme';
import { THEME_REM_VP, ThemeValues } from './ThemeValues';
import { ThemeDiagnostic, ThemeSource, ThemeVar } from './ThemeSource';

/** CSS `rem` → vp. */
export const REM_VP: number = THEME_REM_VP;

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

  /**
   * Resolve `var(--x, fallback)` references (fallbacks may contain nested functions, e.g.
   * `var(--x, oklch(1 0 0 / 50%))`). Returns undefined on cycles / missing vars without fallback.
   */
  static substitute(value: string, vars: Map<string, ThemeVar>, depth: number): string | undefined {
    const start = value.indexOf('var(');
    if (start < 0) {
      return value;
    }
    if (depth > 8) {
      return undefined;
    }
    let level = 0;
    let comma = -1;
    let end = -1;
    for (let i = start + 4; i < value.length; i++) {
      const ch = value[i];
      if (ch === '(') {
        level++;
      } else if (ch === ')') {
        if (level === 0) {
          end = i;
          break;
        }
        level--;
      } else if (ch === ',' && level === 0 && comma < 0) {
        comma = i;
      }
    }
    if (end < 0) {
      return undefined;
    }
    const name = value.substring(start + 4, comma < 0 ? end : comma).trim();
    if (!/^--[a-zA-Z0-9_-]+$/.test(name)) {
      return undefined;
    }
    const ref = vars.get(name);
    let replacement: string | undefined = undefined;
    if (ref !== undefined) {
      replacement = ThemeResolver.substitute(ref.value, vars, depth + 1);
    }
    if (replacement === undefined && comma >= 0) {
      replacement = ThemeResolver.substitute(value.substring(comma + 1, end).trim(), vars, depth + 1);
    }
    if (replacement === undefined) {
      return undefined;
    }
    const next = value.substring(0, start) + replacement + value.substring(end + 1);
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
    if (key === 'border-width') {
      const w = ThemeValues.len(value);
      if (isNaN(w) || w < 0) {
        return new ThemeDiagnostic('error', line, name, `invalid length "${value}"; keeping default`);
      }
      t.borderWidth = w;
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
    const ct: SparkTokenMatch | undefined = SparkComponentTokenRegistry.match(key);
    if (ct !== undefined) {
      return ThemeResolver.applyComponentToken(t, ct, name, value, line);
    }
    if (key.startsWith('font-') || key.startsWith('tracking') || key === 'letter-spacing') {
      return new ThemeDiagnostic('info', line, name, 'typography family/tracking not supported yet; skipped');
    }
    return new ThemeDiagnostic('warning', line, name, 'unknown variable; ignored');
  }

  /**
   * `--<component>-<property>` (ADR D13). A catalogued token must parse as its kind (otherwise error, the
   * component keeps its built-in value); an uncatalogued property of a known component is stored with a warning.
   */
  private static applyComponentToken(t: SparkTheme, ct: SparkTokenMatch, name: string, value: string,
    line: number): ThemeDiagnostic | undefined {
    if (ct.kind === undefined) {
      t.comp.set(ct.component, ct.property, value);
      return new ThemeDiagnostic('warning', line, name,
        `unknown ${ct.component} token "${ct.property}"; stored (readable via theme.comp) but unused by SparkUI`);
    }
    const parsed = SparkTokenValue.parse(value);
    if (!parsed.supports(ct.kind)) {
      return new ThemeDiagnostic('error', line, name, `expected a ${ct.kind}, got "${value}"; keeping default`);
    }
    t.comp.set(ct.component, ct.property, value);
    return undefined;
  }

  /** `0.625rem` → 10, `12px` / `12vp` / `12` → 12. CSS px are logical pixels, i.e. vp. NaN on failure. */
  static parseLength(value: string): number {
    return ThemeValues.plainLength(value);
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
    return ThemeValues.shadow(value);
  }
}
