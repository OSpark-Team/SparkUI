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
    return SparkTokenOverride.color(instance, base);
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
 */
export function sparkSurface(t: SparkTheme, component: string, defaults: SparkSurfaceStyle,
  tokens?: SparkSurfaceTokens): SparkSurfaceStyle {
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
