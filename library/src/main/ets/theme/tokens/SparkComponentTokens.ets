import { SparkColor } from '../color/SparkColor';
import { ThemeValues } from '../css/ThemeValues';
import { SparkShadow } from './SparkShadow';

/**
 * Value kind of a component token (ADR D13).
 * - `color`: any theme colour syntax incl. alpha (`oklch(… / 50%)`), `transparent`, `none`, `color-mix()`
 * - `length`: `px` / `rem` / `vp` / unitless vp, `calc()`, `none` (= 0)
 * - `shadow`: CSS box-shadow (first layer) or `none`
 * - `number`: unitless number or percentage (`600`, `0.97`, `50%`)
 * - `bool`: `true|false|on|off|1|0|none`
 */
export type SparkTokenKind = 'color' | 'length' | 'shadow' | 'number' | 'bool';

/** One entry of the component token catalogue. */
export class SparkTokenSpec {
  component: string;
  property: string;
  kind: SparkTokenKind;

  constructor(component: string, property: string, kind: SparkTokenKind) {
    this.component = component;
    this.property = property;
    this.kind = kind;
  }

  /** CSS variable name, e.g. `--card-background`. */
  get variable(): string {
    return `--${this.component}-${this.property}`;
  }
}

/**
 * A parsed component token value. The raw text is parsed once (when the theme resolves) into every
 * interpretation it supports, so readers of any kind are O(1) and an unknown token can still be read.
 */
export class SparkTokenValue {
  raw: string = '';
  color: string | undefined = undefined;
  length: number | undefined = undefined;
  shadow: SparkShadow | undefined = undefined;
  num: number | undefined = undefined;
  bool: boolean | undefined = undefined;

  static parse(raw: string): SparkTokenValue {
    const v = new SparkTokenValue();
    v.raw = raw.trim();
    const c = ThemeValues.color(v.raw);
    if (c.ok) {
      v.color = c.value;
    }
    const len = ThemeValues.len(v.raw);
    if (!isNaN(len)) {
      v.length = len;
    }
    v.shadow = ThemeValues.shadow(v.raw);
    const n = ThemeValues.num(v.raw);
    if (!isNaN(n)) {
      v.num = n;
    }
    v.bool = ThemeValues.bool(v.raw);
    return v;
  }

  /** Whether the value can be read as `kind`. */
  supports(kind: SparkTokenKind): boolean {
    switch (kind) {
      case 'color':
        return this.color !== undefined;
      case 'length':
        return this.length !== undefined;
      case 'shadow':
        return this.shadow !== undefined;
      case 'number':
        return this.num !== undefined;
      default:
        return this.bool !== undefined;
    }
  }
}

/** Result of matching a CSS variable name against the catalogue. */
export class SparkTokenMatch {
  component: string = '';
  property: string = '';
  /** undefined: the component is known but the property is not (stored anyway, with a warning) */
  kind: SparkTokenKind | undefined = undefined;
}

/** Property prefix for a variant: the default variant uses bare names, others `<variant>-<property>`. */
export function sparkVariantProp(variant: string, property: string): string {
  return variant === 'default' ? property : `${variant}-${property}`;
}

/**
 * The component token catalogue: which `--<component>-<property>` variables SparkUI components read and
 * what kind of value each takes. Unknown properties of a known component are stored too (with a warning),
 * so custom components can define their own tokens and read them through `theme.comp`.
 */
export class SparkComponentTokenRegistry {
  private static table: Map<string, Map<string, SparkTokenKind>> | undefined = undefined;
  private static list: SparkTokenSpec[] = [];
  /** component names, longest first (so `toggle-group-…` wins over `toggle-…`) */
  private static names: string[] = [];

  /** Every catalogued token, in catalogue order. */
  static all(): SparkTokenSpec[] {
    SparkComponentTokenRegistry.ensure();
    return SparkComponentTokenRegistry.list;
  }

  /** Catalogued component names. */
  static components(): string[] {
    SparkComponentTokenRegistry.ensure();
    return SparkComponentTokenRegistry.list.map((s: SparkTokenSpec) => s.component)
      .filter((c: string, i: number, a: string[]) => a.indexOf(c) === i);
  }

  static kindOf(component: string, property: string): SparkTokenKind | undefined {
    const m = SparkComponentTokenRegistry.ensure().get(component);
    return m === undefined ? undefined : m.get(property);
  }

  /** Register extra tokens (custom components); they then validate like built-in ones. */
  static define(component: string, properties: string[], kind: SparkTokenKind): void {
    SparkComponentTokenRegistry.ensure();
    SparkComponentTokenRegistry.add(component, properties, kind);
  }

  /** `card-background` (no leading `--`) → component `card`, property `background`; undefined if no component matches. */
  static match(key: string): SparkTokenMatch | undefined {
    SparkComponentTokenRegistry.ensure();
    for (const name of SparkComponentTokenRegistry.names) {
      if (key.length > name.length + 1 && key.startsWith(name + '-')) {
        const r = new SparkTokenMatch();
        r.component = name;
        r.property = key.substring(name.length + 1);
        r.kind = SparkComponentTokenRegistry.kindOf(name, r.property);
        return r;
      }
    }
    return undefined;
  }

  private static add(component: string, properties: string[], kind: SparkTokenKind): void {
    const table = SparkComponentTokenRegistry.table as Map<string, Map<string, SparkTokenKind>>;
    let m = table.get(component);
    if (m === undefined) {
      m = new Map<string, SparkTokenKind>();
      table.set(component, m);
      SparkComponentTokenRegistry.names.push(component);
      SparkComponentTokenRegistry.names.sort((a: string, b: string) => b.length - a.length);
    }
    for (const p of properties) {
      if (!m.has(p)) {
        SparkComponentTokenRegistry.list.push(new SparkTokenSpec(component, p, kind));
      }
      m.set(p, kind);
    }
  }

  /** `properties` for every variant (`default` → bare name, others `<variant>-<property>`). */
  private static addVariants(component: string, variants: string[], properties: string[], kind: SparkTokenKind): void {
    const props: string[] = [];
    variants.forEach((v: string) => properties.forEach((p: string) => props.push(sparkVariantProp(v, p))));
    SparkComponentTokenRegistry.add(component, props, kind);
  }

  private static ensure(): Map<string, Map<string, SparkTokenKind>> {
    if (SparkComponentTokenRegistry.table !== undefined) {
      return SparkComponentTokenRegistry.table;
    }
    SparkComponentTokenRegistry.table = new Map<string, Map<string, SparkTokenKind>>();
    // shared modal backdrop; `--<overlay-key>-overlay` (dialog, sheet, drawer …) overrides it per component
    SparkComponentTokenRegistry.add('overlay', ['backdrop'], 'color');

    const buttonVariants = ['default', 'destructive', 'outline', 'secondary', 'ghost', 'link'];
    SparkComponentTokenRegistry.add('button', ['radius', 'height', 'height-sm', 'height-lg', 'padding-x', 'padding-x-sm', 'padding-x-lg', 'gap',
      'font-size', 'icon-size', 'border-width'], 'length');
    SparkComponentTokenRegistry.add('button', ['font-weight', 'pressed-scale'], 'number');
    SparkComponentTokenRegistry.add('button', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.addVariants('button', buttonVariants,
      ['background', 'foreground', 'border-color', 'hover-background', 'pressed-background'], 'color');
    SparkComponentTokenRegistry.addVariants('button', buttonVariants.slice(1), ['border-width'], 'length');
    SparkComponentTokenRegistry.addVariants('button', buttonVariants.slice(1), ['shadow'], 'shadow');

    const cardVariants = ['default', 'outline', 'elevated', 'ghost', 'filled'];
    SparkComponentTokenRegistry.add('card', ['radius', 'border-width', 'padding', 'padding-sm'], 'length');
    SparkComponentTokenRegistry.addVariants('card', cardVariants, ['background', 'border-color', 'hover-background', 'pressed-background'],
      'color');
    SparkComponentTokenRegistry.addVariants('card', cardVariants, ['shadow', 'hover-shadow'], 'shadow');

    SparkComponentTokenRegistry.add('input', ['background', 'foreground', 'placeholder-color', 'border-color', 'focus-border-color',
      'invalid-border-color', 'ring-color', 'invalid-ring-color'], 'color');
    SparkComponentTokenRegistry.add('input', ['radius', 'border-width', 'ring-width', 'height', 'height-sm', 'height-lg', 'padding-x'], 'length');

    SparkComponentTokenRegistry.add('badge', ['radius', 'border-width', 'padding-x'], 'length');
    SparkComponentTokenRegistry.add('badge', ['font-weight'], 'number');
    SparkComponentTokenRegistry.addVariants('badge', ['default', 'secondary', 'destructive', 'outline', 'success', 'warning', 'info'],
      ['background', 'foreground', 'border-color'], 'color');

    SparkComponentTokenRegistry.add('alert', ['radius', 'border-width', 'padding-x', 'padding-y'], 'length');
    SparkComponentTokenRegistry.addVariants('alert', ['default', 'destructive', 'success', 'warning', 'info'],
      ['background', 'foreground', 'border-color', 'description-color'], 'color');

    SparkComponentTokenRegistry.add('dialog', ['background', 'border-color', 'overlay'], 'color');
    SparkComponentTokenRegistry.add('dialog', ['radius', 'border-width', 'padding', 'max-width'], 'length');
    SparkComponentTokenRegistry.add('dialog', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('drawer', ['background', 'border-color', 'overlay', 'handle-background'], 'color');
    SparkComponentTokenRegistry.add('drawer', ['radius', 'border-width', 'padding', 'handle-width', 'handle-height'],
      'length');
    SparkComponentTokenRegistry.add('drawer', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('sheet', ['background', 'border-color', 'overlay'], 'color');
    SparkComponentTokenRegistry.add('sheet', ['border-width', 'padding'], 'length');
    SparkComponentTokenRegistry.add('sheet', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('popover', ['background', 'border-color'], 'color');
    SparkComponentTokenRegistry.add('popover', ['radius', 'border-width', 'padding'], 'length');
    SparkComponentTokenRegistry.add('popover', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('menu', ['background', 'border-color'], 'color');
    SparkComponentTokenRegistry.add('menu', ['radius', 'border-width', 'padding'], 'length');
    SparkComponentTokenRegistry.add('menu', ['shadow'], 'shadow');
    // option-list panels: --select-* falls back to --menu-*, --combobox-* to --popover-* (ADR D14 addendum)
    SparkComponentTokenRegistry.add('select', ['background', 'border-color', 'highlight-background',
      'highlight-foreground'], 'color');
    SparkComponentTokenRegistry.add('select', ['radius', 'border-width', 'padding', 'max-height'], 'length');
    SparkComponentTokenRegistry.add('select', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('combobox', ['background', 'border-color', 'highlight-background',
      'highlight-foreground'], 'color');
    SparkComponentTokenRegistry.add('combobox', ['radius', 'border-width', 'padding', 'max-height'], 'length');
    SparkComponentTokenRegistry.add('combobox', ['shadow'], 'shadow');

    SparkComponentTokenRegistry.add('tabs', ['list-background', 'indicator-background', 'indicator-border-color', 'trigger-foreground',
      'trigger-active-foreground'], 'color');
    SparkComponentTokenRegistry.add('tabs', ['height', 'list-radius', 'list-padding', 'indicator-radius', 'indicator-border-width'], 'length');
    SparkComponentTokenRegistry.add('tabs', ['indicator-shadow'], 'shadow');

    SparkComponentTokenRegistry.add('toggle', ['hover-background', 'hover-foreground', 'on-background', 'on-foreground', 'border-color'],
      'color');
    SparkComponentTokenRegistry.add('toggle', ['radius', 'border-width', 'height', 'height-sm', 'height-lg'], 'length');
    SparkComponentTokenRegistry.add('toggle', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('toggle-group', ['indicator-background'], 'color');

    SparkComponentTokenRegistry.add('switch', ['background', 'checked-background', 'thumb', 'checked-thumb'], 'color');
    SparkComponentTokenRegistry.add('switch', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('checkbox', ['background', 'border-color', 'checked-background', 'checked-border-color',
      'checked-foreground'], 'color');
    SparkComponentTokenRegistry.add('checkbox', ['radius', 'border-width'], 'length');
    SparkComponentTokenRegistry.add('progress', ['indicator-background', 'track-background'], 'color');
    SparkComponentTokenRegistry.add('progress', ['height', 'radius'], 'length');

    SparkComponentTokenRegistry.add('toast', ['background', 'foreground', 'description-color', 'border-color'], 'color');
    SparkComponentTokenRegistry.add('toast', ['radius', 'border-width', 'padding'], 'length');
    SparkComponentTokenRegistry.add('toast', ['shadow'], 'shadow');
    SparkComponentTokenRegistry.add('tooltip', ['background', 'foreground'], 'color');
    SparkComponentTokenRegistry.add('tooltip', ['radius'], 'length');
    // SCodeBlock syntax colours (SparkCodeTheme.fromVariables); unset = SparkCodeTheme.github()
    SparkComponentTokenRegistry.add('code', ['background', 'foreground', 'keyword', 'string', 'comment', 'number',
      'decorator', 'type', 'function', 'property', 'punctuation', 'variable', 'tag', 'attribute', 'regex', 'meta',
      'inserted', 'deleted'], 'color');

    // layout blocks. `--sidebar`, `--sidebar-foreground`, `--sidebar-accent`, `--sidebar-border` … stay semantic
    // (matched first) and are the base values of these tokens.
    SparkComponentTokenRegistry.add('sidebar', ['background', 'border-color', 'menu-foreground', 'menu-hover-background',
      'menu-active-background', 'menu-active-foreground', 'menu-outline-background', 'group-label-color',
      'inset-background'], 'color');
    SparkComponentTokenRegistry.add('sidebar', ['width', 'width-mobile', 'width-icon', 'frame-gap', 'border-width',
      'menu-radius', 'menu-height', 'menu-height-sm', 'menu-height-lg', 'floating-radius', 'inset-radius'], 'length');
    SparkComponentTokenRegistry.add('sidebar', ['menu-pressed-opacity'], 'number');
    SparkComponentTokenRegistry.add('sidebar', ['floating-shadow', 'inset-shadow', 'sheet-shadow'], 'shadow');
    SparkComponentTokenRegistry.add('topbar', ['background', 'translucent-background', 'border-color', 'title-color',
      'subtitle-color'], 'color');
    SparkComponentTokenRegistry.add('topbar', ['height', 'height-condensed', 'border-width', 'padding-x',
      'padding-x-condensed', 'translucent-blur'], 'length');
    SparkComponentTokenRegistry.add('titlebar', ['background', 'translucent-background', 'border-color', 'title-color',
      'caption-foreground', 'caption-hover-background', 'caption-pressed-background', 'close-hover-background',
      'close-hover-foreground', 'close-pressed-background'], 'color');
    SparkComponentTokenRegistry.add('titlebar', ['height', 'height-touch', 'border-width', 'caption-size',
      'caption-radius', 'translucent-blur'], 'length');
    SparkComponentTokenRegistry.add('app-shell', ['content-max-width', 'content-padding'], 'length');
    SparkComponentTokenRegistry.add('list-detail', ['divider-color', 'list-background', 'detail-background'], 'color');
    SparkComponentTokenRegistry.add('list-detail', ['list-width', 'header-height'], 'length');
    SparkComponentTokenRegistry.add('list-detail', ['detail-shadow'], 'shadow');
    SparkComponentTokenRegistry.add('supporting-pane', ['divider-color', 'background', 'sheet-background',
      'handle-background'], 'color');
    SparkComponentTokenRegistry.add('supporting-pane', ['width', 'divider-width', 'sheet-radius'], 'length');
    SparkComponentTokenRegistry.add('supporting-pane', ['sheet-shadow'], 'shadow');
    return SparkComponentTokenRegistry.table;
  }
}

/**
 * Store of resolved component tokens (`--<component>-<property>`), one per {@link SparkTheme} (`theme.comp`).
 *
 * Reading is typed and always takes the component's built-in value as fallback, so an unset (or wrongly typed)
 * token never changes anything:
 * ```
 * const bg = theme.comp.color('card', 'background', theme.colors.card);
 * const r = theme.comp.length('button', 'radius', theme.radiusMd);
 * const s = theme.comp.shadow('popover', 'shadow', theme.shadows.md);
 * ```
 * Every reader reads the traced `version`, so components (and their @Computed recipes) re-render when a theme
 * refresh changes any component token. Map contents themselves are not observed.
 */
@ObservedV2
export class SparkComponentTokens {
  /** bumps whenever the token set changes */
  @Trace version: number = 0;
  private values: Map<string, SparkTokenValue> = new Map<string, SparkTokenValue>();

  private static key(component: string, property: string): string {
    return `${component}-${property}`;
  }

  private get(component: string, property: string): SparkTokenValue | undefined {
    if (this.version < 0) {
      return undefined; // never: reading `version` registers the dependency
    }
    return this.values.get(SparkComponentTokens.key(component, property));
  }

  /** Store a raw value (parsed immediately). Used by the resolver; prefer SparkUI.themes.setVariable at runtime. */
  set(component: string, property: string, raw: string): SparkTokenValue {
    const v = SparkTokenValue.parse(raw);
    this.values.set(SparkComponentTokens.key(component, property), v);
    this.version++;
    return v;
  }

  has(component: string, property: string): boolean {
    return this.get(component, property) !== undefined;
  }

  /** Raw text of a token (after var() substitution), undefined when unset. */
  raw(component: string, property: string): string | undefined {
    const v = this.get(component, property);
    return v === undefined ? undefined : v.raw;
  }

  /** `#AARRGGBB` colour of a token, or `fallback`. */
  color(component: string, property: string, fallback: string): string {
    const v = this.get(component, property);
    return v !== undefined && v.color !== undefined ? v.color : fallback;
  }

  /** Length in vp, or `fallback`. */
  length(component: string, property: string, fallback: number): number {
    const v = this.get(component, property);
    return v !== undefined && v.length !== undefined ? v.length : fallback;
  }

  /** Shadow (`none` → a transparent SparkShadow), or `fallback`. */
  shadow(component: string, property: string, fallback: SparkShadow | undefined): SparkShadow | undefined {
    const v = this.get(component, property);
    return v !== undefined && v.shadow !== undefined ? v.shadow : fallback;
  }

  /** Unitless number / percentage (0.5 for `50%`), or `fallback`. */
  number(component: string, property: string, fallback: number): number {
    const v = this.get(component, property);
    return v !== undefined && v.num !== undefined ? v.num : fallback;
  }

  bool(component: string, property: string, fallback: boolean): boolean {
    const v = this.get(component, property);
    return v !== undefined && v.bool !== undefined ? v.bool : fallback;
  }

  /** Names (`card-background`, …) of every token that is set. */
  keys(): string[] {
    const out: string[] = [];
    if (this.version >= 0) {
      this.values.forEach((_: SparkTokenValue, k: string) => {
        out.push(k);
      });
    }
    return out;
  }

  get size(): number {
    return this.version >= 0 ? this.values.size : 0;
  }

  clear(): void {
    if (this.values.size > 0) {
      this.values = new Map<string, SparkTokenValue>();
      this.version++;
    }
  }

  /** Replace the token set with `other`'s; bumps `version` only when something changed. */
  copyFrom(other: SparkComponentTokens): void {
    let same = other.values.size === this.values.size;
    if (same) {
      other.values.forEach((v: SparkTokenValue, k: string) => {
        const mine = this.values.get(k);
        if (mine === undefined || mine.raw !== v.raw) {
          same = false;
        }
      });
    }
    if (same) {
      return;
    }
    const next = new Map<string, SparkTokenValue>();
    other.values.forEach((v: SparkTokenValue, k: string) => {
      next.set(k, v);
    });
    this.values = next;
    this.version++;
  }
}

/**
 * Per-instance token overrides (the `tokens` param of components): instance value → theme component token →
 * built-in recipe. Colours / shadows are CSS strings (same syntax as the theme file), lengths are vp numbers.
 */
export class SparkTokenOverride {
  /** Parsed colour of an instance value, or `fallback` when unset / invalid. */
  static color(value: string | undefined, fallback: string): string {
    if (value === undefined) {
      return fallback;
    }
    const c = ThemeValues.color(value);
    return c.ok ? c.value : fallback;
  }

  static shadow(value: string | undefined, fallback: SparkShadow | undefined): SparkShadow | undefined {
    if (value === undefined) {
      return fallback;
    }
    const s = ThemeValues.shadow(value);
    return s !== undefined ? s : fallback;
  }

  static len(value: number | undefined, fallback: number): number {
    return value === undefined || isNaN(value) ? fallback : value;
  }

  static number(value: number | undefined, fallback: number): number {
    return value === undefined || isNaN(value) ? fallback : value;
  }

  /** ShadowOptions for a resolved shadow (undefined / none → no shadow). */
  static shadowOptions(s: SparkShadow | undefined): ShadowOptions {
    return s !== undefined ? s.toOptions() : { radius: 0, color: Color.Transparent };
  }

  /** Whether a colour is fully transparent. */
  static isClear(argb: string): boolean {
    return SparkColor.fromArgbHex(argb).a <= 0;
  }
}
