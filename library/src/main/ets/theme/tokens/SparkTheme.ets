import { SparkColors } from './SparkColors';

/** A single drop shadow. ArkUI renders one shadow per component, so CSS multi-shadows keep the first layer. */
export class SparkShadow {
  offsetX: number = 0;
  offsetY: number = 0;
  /** blur radius in vp */
  radius: number = 0;
  color: string = '#00000000';

  constructor(offsetX: number, offsetY: number, radius: number, color: string) {
    this.offsetX = offsetX;
    this.offsetY = offsetY;
    this.radius = radius;
    this.color = color;
  }

  toOptions(): ShadowOptions {
    return {
      radius: this.radius,
      color: this.color,
      offsetX: this.offsetX,
      offsetY: this.offsetY
    };
  }
}

/** Shadow scale xs–2xl (Tailwind v4 defaults). */
@ObservedV2
export class SparkShadows {
  @Trace xs: SparkShadow = new SparkShadow(0, 1, 2, '#0D000000');
  @Trace sm: SparkShadow = new SparkShadow(0, 1, 3, '#1A000000');
  @Trace md: SparkShadow = new SparkShadow(0, 4, 6, '#1A000000');
  @Trace lg: SparkShadow = new SparkShadow(0, 10, 15, '#1A000000');
  @Trace xl: SparkShadow = new SparkShadow(0, 20, 25, '#1A000000');
  @Trace xxl: SparkShadow = new SparkShadow(0, 25, 50, '#40000000');

  copyFrom(o: SparkShadows): void {
    this.xs = o.xs;
    this.sm = o.sm;
    this.md = o.md;
    this.lg = o.lg;
    this.xl = o.xl;
    this.xxl = o.xxl;
  }

  set(name: string, value: SparkShadow): boolean {
    switch (name) {
      case 'xs':
        this.xs = value;
        return true;
      case 'sm':
        this.sm = value;
        return true;
      case 'md':
        this.md = value;
        return true;
      case 'lg':
        this.lg = value;
        return true;
      case 'xl':
        this.xl = value;
        return true;
      case '2xl':
        this.xxl = value;
        return true;
      default:
        return false;
    }
  }
}

/** Type scale (Tailwind v4 defaults, rem → 16vp). Sizes in fp so system font scaling applies. */
@ObservedV2
export class SparkTypography {
  @Trace xs: number = 12;
  @Trace sm: number = 14;
  @Trace base: number = 16;
  @Trace lg: number = 18;
  @Trace xl: number = 20;
  @Trace xxl: number = 24;
  @Trace xxxl: number = 30;
  @Trace xxxxl: number = 36;

  @Trace leadingXs: number = 16;
  @Trace leadingSm: number = 20;
  @Trace leadingBase: number = 24;
  @Trace leadingLg: number = 28;
  @Trace leadingXl: number = 28;
  @Trace leadingXxl: number = 32;
  @Trace leadingXxxl: number = 36;
  @Trace leadingXxxxl: number = 40;

  @Trace weightNormal: number = 400;
  @Trace weightMedium: number = 500;
  @Trace weightSemibold: number = 600;
  @Trace weightBold: number = 700;

  copyFrom(o: SparkTypography): void {
    this.xs = o.xs;
    this.sm = o.sm;
    this.base = o.base;
    this.lg = o.lg;
    this.xl = o.xl;
    this.xxl = o.xxl;
    this.xxxl = o.xxxl;
    this.xxxxl = o.xxxxl;
    this.leadingXs = o.leadingXs;
    this.leadingSm = o.leadingSm;
    this.leadingBase = o.leadingBase;
    this.leadingLg = o.leadingLg;
    this.leadingXl = o.leadingXl;
    this.leadingXxl = o.leadingXxl;
    this.leadingXxxl = o.leadingXxxl;
    this.leadingXxxxl = o.leadingXxxxl;
    this.weightNormal = o.weightNormal;
    this.weightMedium = o.weightMedium;
    this.weightSemibold = o.weightSemibold;
    this.weightBold = o.weightBold;
  }

  /** `--text-<size>` */
  setSize(size: string, v: number): boolean {
    switch (size) {
      case 'xs':
        this.xs = v;
        return true;
      case 'sm':
        this.sm = v;
        return true;
      case 'base':
        this.base = v;
        return true;
      case 'lg':
        this.lg = v;
        return true;
      case 'xl':
        this.xl = v;
        return true;
      case '2xl':
        this.xxl = v;
        return true;
      case '3xl':
        this.xxxl = v;
        return true;
      case '4xl':
        this.xxxxl = v;
        return true;
      default:
        return false;
    }
  }

  /** `--text-<size>--line-height` */
  setLeading(size: string, v: number): boolean {
    switch (size) {
      case 'xs':
        this.leadingXs = v;
        return true;
      case 'sm':
        this.leadingSm = v;
        return true;
      case 'base':
        this.leadingBase = v;
        return true;
      case 'lg':
        this.leadingLg = v;
        return true;
      case 'xl':
        this.leadingXl = v;
        return true;
      case '2xl':
        this.leadingXxl = v;
        return true;
      case '3xl':
        this.leadingXxxl = v;
        return true;
      case '4xl':
        this.leadingXxxxl = v;
        return true;
      default:
        return false;
    }
  }

  /** `--font-weight-<name>` */
  setWeight(name: string, v: number): boolean {
    switch (name) {
      case 'normal':
        this.weightNormal = v;
        return true;
      case 'medium':
        this.weightMedium = v;
        return true;
      case 'semibold':
        this.weightSemibold = v;
        return true;
      case 'bold':
        this.weightBold = v;
        return true;
      default:
        return false;
    }
  }
}

/** Per-component motion override (from `--motion-<component>-*` or SparkUI.themes.setMotion). */
export class SparkMotionOverride {
  /** ms; undefined = component default */
  duration: number | undefined = undefined;
  /** CSS-like easing: 'ease-out', 'cubic-bezier(…)', 'spring(response, damping)', 'linear' … */
  ease: string | undefined = undefined;
  enabled: boolean | undefined = undefined;

  clone(): SparkMotionOverride {
    const o = new SparkMotionOverride();
    o.duration = this.duration;
    o.ease = this.ease;
    o.enabled = this.enabled;
    return o;
  }
}

/** Motion tokens. Curves are cubic-bezier control points. */
@ObservedV2
export class SparkMotion {
  /** master switch (`--motion-enabled`): false → every SparkUI animation is instant */
  @Trace enabled: boolean = true;
  /** bumps whenever `overrides` change (Map contents are not traced) */
  @Trace version: number = 0;
  /** component name → override, e.g. 'accordion', 'tabs', 'dialog' */
  overrides: Map<string, SparkMotionOverride> = new Map<string, SparkMotionOverride>();
  @Trace durationFast: number = 150;
  @Trace durationNormal: number = 200;
  @Trace durationSlow: number = 300;
  /** Tailwind `ease-out`-like standard curve */
  @Trace easeStandard: number[] = [0.2, 0, 0, 1];
  @Trace easeIn: number[] = [0.4, 0, 1, 1];
  @Trace easeOut: number[] = [0, 0, 0.2, 1];

  copyFrom(o: SparkMotion): void {
    this.durationFast = o.durationFast;
    this.durationNormal = o.durationNormal;
    this.durationSlow = o.durationSlow;
    this.easeStandard = o.easeStandard;
    this.easeIn = o.easeIn;
    this.easeOut = o.easeOut;
    this.enabled = o.enabled;
    const next = new Map<string, SparkMotionOverride>();
    o.overrides.forEach((v: SparkMotionOverride, k: string) => {
      next.set(k, v.clone());
    });
    this.overrides = next;
    this.version++;
  }

  override(component: string): SparkMotionOverride {
    let o = this.overrides.get(component);
    if (o === undefined) {
      o = new SparkMotionOverride();
      this.overrides.set(component, o);
    }
    return o;
  }
}

export type SparkThemeMode = 'system' | 'light' | 'dark';

/**
 * The runtime token store. One global instance lives in `SparkUI.theme`; components read it through
 * `@Consumer('sparkTheme')` (falling back to the global instance), so every field change re-renders
 * exactly the components that read it.
 */
@ObservedV2
export class SparkTheme {
  /** preset or custom theme name */
  @Trace name: string = 'neutral';
  /** resolved appearance (after applying `system`) */
  @Trace isDark: boolean = false;
  @Trace colors: SparkColors = new SparkColors();
  /** `--radius` in vp (0.625rem = 10vp) */
  @Trace radius: number = 10;
  /** `--spacing` base unit in vp (0.25rem = 4vp) */
  @Trace spacing: number = 4;
  @Trace text: SparkTypography = new SparkTypography();
  @Trace shadows: SparkShadows = new SparkShadows();
  @Trace motion: SparkMotion = new SparkMotion();

  /** shadcn: calc(var(--radius) - 4px) */
  @Computed
  get radiusSm(): number {
    return Math.max(0, this.radius - 4);
  }

  /** shadcn: calc(var(--radius) - 2px) */
  @Computed
  get radiusMd(): number {
    return Math.max(0, this.radius - 2);
  }

  @Computed
  get radiusLg(): number {
    return this.radius;
  }

  /** shadcn: calc(var(--radius) + 4px) */
  @Computed
  get radiusXl(): number {
    return this.radius + 4;
  }

  /** Tailwind spacing scale: `sp(4)` = 4 × --spacing (16vp by default). */
  sp(n: number): number {
    return this.spacing * n;
  }

  copyFrom(o: SparkTheme): void {
    this.name = o.name;
    this.isDark = o.isDark;
    this.colors.copyFrom(o.colors);
    this.radius = o.radius;
    this.spacing = o.spacing;
    this.text.copyFrom(o.text);
    this.shadows.copyFrom(o.shadows);
    this.motion.copyFrom(o.motion);
  }
}
