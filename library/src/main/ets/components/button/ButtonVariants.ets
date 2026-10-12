import { SparkColor } from '../../theme/color/SparkColor';
import { SparkShadow, SparkTheme } from '../../theme/tokens/SparkTheme';

export type ButtonVariant = 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link';
export type ButtonSize = 'default' | 'sm' | 'lg' | 'icon' | 'icon-sm' | 'icon-lg';

/** Resolved, plain style values of a button (the output of the variant recipe). */
export class ButtonStyle {
  background: string = '#00000000';
  /** background while hovered (pointer) */
  hoverBackground: string = '#00000000';
  /** background while pressed (touch and pointer) — a step stronger than hover */
  pressedBackground: string = '#00000000';
  /** opacity while pressed (used by the link variant, which has no background) */
  pressedOpacity: number = 1;
  foreground: string = '#FF000000';
  borderColor: string = '#00000000';
  borderWidth: number = 0;
  radius: number = 8;
  height: number = 36;
  paddingX: number = 16;
  gap: number = 8;
  fontSize: number = 14;
  fontWeight: number = 500;
  iconSize: number = 16;
  shadow: SparkShadow | undefined = undefined;
  underlineOnHover: boolean = false;
  /** icon button: width = height */
  square: boolean = false;
}

/**
 * Button variant recipe (the cva equivalent), 1:1 with shadcn-vue's `buttonVariants`.
 * A pure function of theme + props, so it is unit-testable and reusable by other components
 * (Pagination links, AlertDialog actions …).
 */
export class ButtonVariants {
  static resolve(t: SparkTheme, variant: ButtonVariant, size: ButtonSize): ButtonStyle {
    const c = t.colors;
    const s = new ButtonStyle();
    s.radius = t.radiusMd;
    s.fontSize = t.text.sm;
    s.fontWeight = t.text.weightMedium;
    switch (variant) {
      case 'destructive':
        s.background = t.isDark ? SparkColor.alpha(c.destructive, 0.6) : c.destructive;
        s.hoverBackground = SparkColor.alpha(c.destructive, t.isDark ? 0.5 : 0.9);
        s.pressedBackground = SparkColor.alpha(c.destructive, t.isDark ? 0.4 : 0.8);
        s.foreground = c.destructiveForeground;
        s.shadow = t.shadows.xs;
        break;
      case 'outline':
        s.background = t.isDark ? SparkColor.alpha(c.input, 0.3) : c.background;
        s.hoverBackground = t.isDark ? SparkColor.alpha(c.input, 0.5) : c.accent;
        s.pressedBackground = t.isDark ? SparkColor.alpha(c.input, 0.7) : SparkColor.mix(c.accent, c.foreground, 0.06);
        s.foreground = c.foreground;
        s.borderColor = t.isDark ? c.input : c.border;
        s.borderWidth = 1;
        s.shadow = t.shadows.xs;
        break;
      case 'secondary':
        s.background = c.secondary;
        s.hoverBackground = SparkColor.alpha(c.secondary, 0.8);
        s.pressedBackground = SparkColor.mix(c.secondary, c.foreground, 0.08);
        s.foreground = c.secondaryForeground;
        s.shadow = t.shadows.xs;
        break;
      case 'ghost':
        s.hoverBackground = t.isDark ? SparkColor.alpha(c.accent, 0.5) : c.accent;
        s.pressedBackground = t.isDark ? c.accent : SparkColor.mix(c.accent, c.foreground, 0.06);
        s.foreground = c.foreground;
        break;
      case 'link':
        s.foreground = c.primary;
        s.underlineOnHover = true;
        s.pressedOpacity = 0.7;
        break;
      default:
        s.background = c.primary;
        s.hoverBackground = SparkColor.alpha(c.primary, 0.9);
        s.pressedBackground = SparkColor.alpha(c.primary, 0.8);
        s.foreground = c.primaryForeground;
        s.shadow = t.shadows.xs;
    }
    switch (size) {
      case 'sm':
        s.height = 32;
        s.paddingX = 12;
        s.gap = 6;
        break;
      case 'lg':
        s.height = 40;
        s.paddingX = 24;
        break;
      case 'icon':
        s.height = 36;
        s.square = true;
        break;
      case 'icon-sm':
        s.height = 32;
        s.square = true;
        break;
      case 'icon-lg':
        s.height = 40;
        s.square = true;
        break;
      default:
        s.height = 36;
        s.paddingX = 16;
    }
    if (s.square) {
      s.paddingX = 0;
    }
    return s;
  }
}

/**
 * Applies a {@link ButtonStyle} to an ArkUI `Button`. Exported so any Button can take the same look:
 * `Button('Go').attributeModifier(new ButtonStyleModifier(ButtonVariants.resolve(theme, 'outline', 'sm')))`.
 */
/**
 * Press feedback of a pressable control:
 * - `background`: pressed background + slight scale (actions: buttons)
 * - `opacity`: fade only, no extra background (selection items: pagination pages, segments, nav rows — a
 *   pressed background next to the selected item reads as two highlighted items)
 * - `none`
 */
export type SparkPressFeedback = 'background' | 'opacity' | 'none';

export class ButtonStyleModifier implements AttributeModifier<ButtonAttribute> {
  style: ButtonStyle;
  hovered: boolean;
  disabled: boolean;
  feedback: SparkPressFeedback = 'background';
  /** scale while pressed (1 = none) */
  pressScale: number;

  constructor(style: ButtonStyle, hovered?: boolean, disabled?: boolean, pressScale?: number) {
    this.style = style;
    this.hovered = hovered === true;
    this.disabled = disabled === true;
    this.pressScale = pressScale ?? 0.97;
  }

  private background(): string {
    const s = this.style;
    if (this.disabled) {
      return s.background;
    }
    return this.hovered ? s.hoverBackground : s.background;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    const s = this.style;
    instance
      .type(ButtonType.Normal)
      .stateEffect(false)
      .hoverEffect(HoverEffect.None)
      .height(s.height)
      // explicit vertical padding / min height: the native Button's defaults offset text in sm/lg sizes
      .padding({ left: s.paddingX, right: s.paddingX, top: 0, bottom: 0 })
      .constraintSize({ minHeight: s.height })
      .backgroundColor(this.background())
      // radius must live inside border(): a later border() without radius resets borderRadius to 0
      .border({ width: s.borderWidth, color: s.borderColor, radius: s.radius })
      .opacity(this.disabled ? 0.5 : 1)
      .scale({ x: 1, y: 1 })
      .shadow(s.shadow !== undefined ? s.shadow.toOptions() : { radius: 0, color: Color.Transparent })
    if (s.square) {
      instance.width(s.height);
    }
  }

  /**
   * Pressed look, driven by the system pressed state (equivalent of `stateStyles({ pressed })`): it can never
   * linger on a previous button when tapping several buttons quickly, unlike onTouch-driven state.
   */
  applyPressedAttribute(instance: ButtonAttribute): void {
    if (this.disabled || this.feedback === 'none') {
      return;
    }
    if (this.feedback === 'opacity') {
      instance.opacity(0.6)
      return;
    }
    const k = this.pressScale;
    instance
      .backgroundColor(this.style.pressedBackground)
      .opacity(this.style.pressedOpacity)
      .scale({ x: k, y: k })
  }
}
