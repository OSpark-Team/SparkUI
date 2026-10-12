import { SparkColor } from '../../theme/color/SparkColor';

/** Style of one token type. Colours are '#AARRGGBB' (or anything SparkColor.parse accepts via `fromVariables`). */
export interface SparkCodeStyle {
  color?: string;
  italic?: boolean;
  bold?: boolean;
}

/**
 * Token → style mapping for SCodeBlock, with separate light and dark entries (the block picks one from
 * `theme.isDark`). Lookups fall back along dotted names: 'keyword.control' → 'keyword' → foreground.
 *
 * ```
 * const codeTheme = SparkCodeTheme.github().copy('brand')
 *   .color('keyword', '#FF7C3AED', '#FFC4B5FD')
 *   .set('comment', { color: '#FF16A34A', italic: false });
 * SCodeBlock({ code, language: 'ts', codeTheme })
 * ```
 */
export class SparkCodeTheme {
  name: string;
  private light: Map<string, SparkCodeStyle> = new Map<string, SparkCodeStyle>();
  private dark: Map<string, SparkCodeStyle> = new Map<string, SparkCodeStyle>();
  private lightBg: string | undefined = undefined;
  private darkBg: string | undefined = undefined;

  constructor(name: string = 'custom') {
    this.name = name;
  }

  /** Set a token's style; `dark` defaults to `light`. Chainable. */
  set(token: string, light: SparkCodeStyle, dark?: SparkCodeStyle): SparkCodeTheme {
    this.light.set(token, light);
    this.dark.set(token, dark ?? light);
    return this;
  }

  /** Shortcut for colour-only entries; keeps any italic / bold already set. Chainable. */
  color(token: string, light: string, dark?: string): SparkCodeTheme {
    const l = this.light.get(token);
    const d = this.dark.get(token);
    const ls: SparkCodeStyle = { color: light, italic: l?.italic, bold: l?.bold };
    const ds: SparkCodeStyle = { color: dark ?? light, italic: d?.italic, bold: d?.bold };
    this.light.set(token, ls);
    this.dark.set(token, ds);
    return this;
  }

  /** Override the block background (default: derived from the SparkTheme muted colour). Chainable. */
  background(light: string, dark?: string): SparkCodeTheme {
    this.lightBg = light;
    this.darkBg = dark ?? light;
    return this;
  }

  copy(name?: string): SparkCodeTheme {
    const t = new SparkCodeTheme(name ?? this.name);
    this.light.forEach((s: SparkCodeStyle, k: string) => t.light.set(k, s));
    this.dark.forEach((s: SparkCodeStyle, k: string) => t.dark.set(k, s));
    t.lightBg = this.lightBg;
    t.darkBg = this.darkBg;
    return t;
  }

  /** Style for a token, falling back along dotted prefixes; undefined when nothing matches. */
  styleOf(token: string, isDark: boolean): SparkCodeStyle | undefined {
    const map = isDark ? this.dark : this.light;
    let key = token;
    while (true) {
      const s = map.get(key);
      if (s !== undefined) {
        return s;
      }
      const dot = key.lastIndexOf('.');
      if (dot < 0) {
        return undefined;
      }
      key = key.substring(0, dot);
    }
  }

  colorOf(token: string, isDark: boolean, fallback: string): string {
    return this.styleOf(token, isDark)?.color ?? fallback;
  }

  isItalic(token: string, isDark: boolean): boolean {
    return this.styleOf(token, isDark)?.italic === true;
  }

  isBold(token: string, isDark: boolean): boolean {
    return this.styleOf(token, isDark)?.bold === true;
  }

  backgroundOf(isDark: boolean): string | undefined {
    return isDark ? this.darkBg : this.lightBg;
  }

  /** Default palette (GitHub light / dark inspired). */
  static github(): SparkCodeTheme {
    return new SparkCodeTheme('github')
      .color('keyword', '#FFCF222E', '#FFFF7B72')
      .color('string', '#FF0A3069', '#FFA5D6FF')
      .set('comment', { color: '#FF6E7781', italic: true }, { color: '#FF8B949E', italic: true })
      .color('number', '#FF0550AE', '#FF79C0FF')
      .color('decorator', '#FF8250DF', '#FFD2A8FF')
      .color('type', '#FF953800', '#FFFFA657')
      .color('function', '#FF8250DF', '#FFD2A8FF')
      .color('property', '#FF0550AE', '#FF79C0FF')
      .color('variable', '#FF953800', '#FFFFA657')
      .color('tag', '#FF116329', '#FF7EE787')
      .color('attribute', '#FF0550AE', '#FF79C0FF')
      .color('regex', '#FF0A3069', '#FFA5D6FF')
      .color('meta', '#FF8250DF', '#FFD2A8FF')
      .color('inserted', '#FF116329', '#FF7EE787')
      .color('deleted', '#FF82071E', '#FFFFA198');
  }

  /**
   * Build a theme from CSS-style variables, on top of `base` (default github()). Recognised names:
   * `--code-<token>` (e.g. --code-keyword, --code-string, --code-comment, --code-function),
   * `--code-foreground` (plain text) and `--code-background`. `light` values apply to both modes and
   * `dark` (the `.dark { }` values) then overrides the dark side. Values that SparkColor cannot parse are ignored.
   */
  static fromVariables(light: Map<string, string>, dark?: Map<string, string>, base?: SparkCodeTheme): SparkCodeTheme {
    const t = (base ?? SparkCodeTheme.github()).copy('variables');
    const apply = (vars: Map<string, string>, toLight: boolean): void => {
      vars.forEach((value: string, name: string) => {
        if (!name.startsWith('--code-')) {
          return;
        }
        const parsed = SparkColor.parse(value.trim());
        if (!parsed.ok) {
          return;
        }
        const key = name.substring('--code-'.length);
        if (key === 'background') {
          t.darkBg = parsed.value;
          if (toLight) {
            t.lightBg = parsed.value;
          }
          return;
        }
        const token = key === 'foreground' ? 'plain' : key;
        const maps: Map<string, SparkCodeStyle>[] = toLight ? [t.light, t.dark] : [t.dark];
        maps.forEach((map: Map<string, SparkCodeStyle>) => {
          const prev = map.get(token);
          const s: SparkCodeStyle = { color: parsed.value, italic: prev?.italic, bold: prev?.bold };
          map.set(token, s);
        });
      });
    };
    // light values apply to both modes; `dark` then overrides the dark side
    apply(light, true);
    if (dark !== undefined) {
      apply(dark, false);
    }
    return t;
  }
}
