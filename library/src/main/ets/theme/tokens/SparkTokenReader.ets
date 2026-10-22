import { SparkColor } from '../color/SparkColor';
import { SPARK_COLOR_TOKENS } from './SparkColors';
import { SparkShadow } from './SparkShadow';
import { SparkTokenOverride } from './SparkComponentTokens';
import { SparkTheme } from './SparkTheme';

/**
 * Per-instance overrides of an overlay / floating surface (Dialog, Sheet, Popover, DropdownMenu content):
 * `SPopoverContent({ tokens: { background: 'transparent', borderWidth: 0, shadow: 'none' } })`.
 * Colours and shadows use the theme file syntax; lengths are vp.
 */
export interface SparkSurfaceTokens {
  background?: string;
  borderColor?: string;
  borderWidth?: number;
  radius?: number;
  padding?: number;
  shadow?: string;
}

/**
 * Reads the tokens of one component with the cascade every SparkUI component follows (ADR D13):
 * **instance `tokens` → theme component token(s) → built-in recipe value**.
 * `props` may list several token names, most specific first (e.g. `['outline-border-width', 'border-width']`).
 */
export class SparkTokenReader {
  private theme: SparkTheme;
  readonly component: string;

  constructor(theme: SparkTheme, component: string) {
    this.theme = theme;
    this.component = component;
  }

  private find(props: string | string[]): string | undefined {
    const list: string[] = typeof props === 'string' ? [props] : props;
    for (const p of list) {
      if (this.theme.comp.has(this.component, p)) {
        return p;
      }
    }
    return undefined;
  }

  color(props: string | string[], instance: string | undefined, fallback: string): string {
    const p = this.find(props);
    const base = p === undefined ? fallback : this.theme.comp.color(this.component, p, fallback);
    return SparkTokenOverride.color(this.themeColorAsCss(instance), base);
  }

  /**
   * Instance colour tokens use the theme-file (CSS) syntax, where 8 hex digits mean `#RRGGBBAA`; every
   * `theme.colors.*` value is ArkUI `#AARRGGBB`. Passing one straight through
   * (`tokens: { foreground: theme.colors.primary }`) read it with the channels rotated — '#FF4169E1' (royal
   * blue) became a pink, '#FFE7000B' (red) an almost transparent yellow. A value that is exactly one of the
   * current theme colours is therefore taken as `#AARRGGBB`. Other ARGB strings (e.g. `SparkColor.alpha()`
   * results) must be converted with `SparkColor.toCss()`.
   */
  private themeColorAsCss(instance: string | undefined): string | undefined {
    if (instance === undefined || !/^s*#[0-9a-fA-F]{8}s*$/.test(instance)) {
      return instance;
    }
    const v = instance.trim().toUpperCase();
    const colors = this.theme.colors;
    for (let i = 0; i < SPARK_COLOR_TOKENS.length; i++) {
      const c = colors.get(SPARK_COLOR_TOKENS[i]);
      if (c !== undefined && c.toUpperCase() === v) {
        return SparkColor.toCss(v);
      }
    }
    return instance;
  }

  len(props: string | string[], instance: number | undefined, fallback: number): number {
    const p = this.find(props);
    const base = p === undefined ? fallback : this.theme.comp.length(this.component, p, fallback);
    return SparkTokenOverride.len(instance, base);
  }

  num(props: string | string[], instance: number | undefined, fallback: number): number {
    const p = this.find(props);
    const base = p === undefined ? fallback : this.theme.comp.number(this.component, p, fallback);
    return SparkTokenOverride.number(instance, base);
  }

  shadow(props: string | string[], instance: string | undefined, fallback: SparkShadow | undefined):
    SparkShadow | undefined {
    const p = this.find(props);
    const base = p === undefined ? fallback : this.theme.comp.shadow(this.component, p, fallback);
    return SparkTokenOverride.shadow(instance, base);
  }

  /** Whether any of `props` is set in the theme. */
  has(props: string | string[]): boolean {
    return this.find(props) !== undefined;
  }
}

/** Resolved surface of an overlay panel (see {@link sparkSurface}). */
export class SparkSurfaceStyle {
  background: string = '#00000000';
  borderColor: string = '#00000000';
  borderWidth: number = 1;
  radius: number = 0;
  padding: number = 0;
  shadow: SparkShadow | undefined = undefined;
}

/**
 * Surface recipe of a floating panel: `component` tokens (`background`, `border-color`, `border-width`, `radius`,
 * `padding`, `shadow`) over the given defaults, then the instance overrides.
 *
 * `inherit` names a surface family the component belongs to (ADR D14 addendum): its tokens apply first, so
 * `--menu-background` restyles Select panels too, while `--select-background` restyles only Select
 * (`sparkSurface(t, 'select', defaults, tokens, 'menu')`).
 */
export function sparkSurface(t: SparkTheme, component: string, defaults: SparkSurfaceStyle,
  tokens?: SparkSurfaceTokens, inherit?: string): SparkSurfaceStyle {
  if (inherit !== undefined && inherit !== component) {
    return sparkSurface(t, component, sparkSurface(t, inherit, defaults), tokens);
  }
  const r = new SparkTokenReader(t, component);
  const s = new SparkSurfaceStyle();
  s.background = r.color('background', tokens?.background, defaults.background);
  s.borderColor = r.color('border-color', tokens?.borderColor, defaults.borderColor);
  s.borderWidth = r.len('border-width', tokens?.borderWidth, defaults.borderWidth);
  s.radius = r.len('radius', tokens?.radius, defaults.radius);
  s.padding = r.len('padding', tokens?.padding, defaults.padding);
  s.shadow = r.shadow('shadow', tokens?.shadow, defaults.shadow);
  return s;
}

/** Defaults helper for {@link sparkSurface}. */
export function sparkSurfaceDefaults(background: string, borderColor: string, borderWidth: number, radius: number,
  padding: number, shadow: SparkShadow | undefined): SparkSurfaceStyle {
  const s = new SparkSurfaceStyle();
  s.background = background;
  s.borderColor = borderColor;
  s.borderWidth = borderWidth;
  s.radius = radius;
  s.padding = padding;
  s.shadow = shadow;
  return s;
}

/**
 * Per-instance overrides of an option-list panel (SSelect / SCombobox): the surface plus the highlighted row
 * colours and the list's maximum height. `SSelect({ options, tokens: { highlightBackground: '#e0f2fe' } })`.
 */
export interface SparkOptionPanelTokens extends SparkSurfaceTokens {
  highlightBackground?: string;
  highlightForeground?: string;
  /** max list height before scrolling (vp) */
  maxHeight?: number;
}

/** Resolved option-list panel (see {@link sparkOptionPanel}). */
export class SparkOptionPanelStyle extends SparkSurfaceStyle {
  highlightBackground: string = '#00000000';
  highlightForeground: string = '#00000000';
  maxHeight: number = 300;
}

/**
 * Option-list panel recipe (ADR D14 addendum): surface = `inherit` family tokens → `component` tokens → instance;
 * `highlight-background` / `highlight-foreground` / `max-height` are read from `component` only
 * (defaults: `accent` / `accent-foreground` / `maxHeight`).
 */
export function sparkOptionPanel(t: SparkTheme, component: string, inherit: string, defaults: SparkSurfaceStyle,
  maxHeight: number, tokens?: SparkOptionPanelTokens): SparkOptionPanelStyle {
  const s = sparkSurface(t, component, defaults, tokens, inherit);
  const r = new SparkTokenReader(t, component);
  const p = new SparkOptionPanelStyle();
  p.background = s.background;
  p.borderColor = s.borderColor;
  p.borderWidth = s.borderWidth;
  p.radius = s.radius;
  p.padding = s.padding;
  p.shadow = s.shadow;
  p.highlightBackground = r.color('highlight-background', tokens?.highlightBackground, t.colors.accent);
  p.highlightForeground = r.color('highlight-foreground', tokens?.highlightForeground, t.colors.accentForeground);
  p.maxHeight = r.len('max-height', tokens?.maxHeight, maxHeight);
  return p;
}
