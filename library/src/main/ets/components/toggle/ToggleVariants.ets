import { SparkColor } from '../../theme/color/SparkColor';
import { SparkShadow, SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../../theme/tokens/SparkTokenReader';

export type ToggleVariant = 'default' | 'outline';
export type ToggleSize = 'default' | 'sm' | 'lg';

/** Which corners / edges of a toggle are joined to neighbours inside a toggle group. */
export type ToggleJoin = 'none' | 'first' | 'middle' | 'last' | 'only';

/**
 * Per-instance token overrides of a toggle (ADR D13): `SToggle({ icon: 'bold', tokens: { onBackground: '#0ea5e9' } })`.
 * Instance → theme `--toggle-*` → recipe.
 */
export interface ToggleTokens {
  onBackground?: string;
  onForeground?: string;
  hoverBackground?: string;
  hoverForeground?: string;
  borderColor?: string;
  borderWidth?: number;
  radius?: number;
  height?: number;
  shadow?: string;
}

const NO_TOGGLE_TOKENS: ToggleTokens = {};

/** Resolved style values of a toggle (output of the variant recipe). */
export class ToggleStyle {
  background: string = '#00000000';
  pressedBackground: string = '#00000000';
  foreground: string = '#FF000000';
  borderColor: string = '#00000000';
  borderWidth: number = 0;
  radius: number = 8;
  height: number = 36;
  minWidth: number = 36;
  paddingX: number = 8;
  gap: number = 8;
  fontSize: number = 14;
  fontWeight: number = 500;
  iconSize: number = 16;
  shadow: SparkShadow | undefined = undefined;
  /** selection item: pressed = fade only, no pressed background (see SparkPressFeedback) */
  pressFade: boolean = false;
}

/**
 * Toggle variant recipe, 1:1 with shadcn-vue's `toggleVariants`:
 * `inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium hover:bg-muted
 * hover:text-muted-foreground data-[state=on]:bg-accent data-[state=on]:text-accent-foreground`.
 */
export class ToggleVariants {
  static resolve(t: SparkTheme, variant: ToggleVariant, size: ToggleSize, on: boolean, hovered: boolean,
    tokens?: ToggleTokens): ToggleStyle {
    const c = t.colors;
    const k = tokens ?? NO_TOGGLE_TOKENS;
    const r = new SparkTokenReader(t, 'toggle');
    const s = new ToggleStyle();
    s.radius = r.len('radius', k.radius, t.radiusMd);
    s.fontSize = t.text.sm;
    s.fontWeight = t.text.weightMedium;
    s.foreground = c.foreground;
    if (variant === 'outline') {
      s.borderColor = r.color('border-color', k.borderColor, c.input);
      s.borderWidth = r.len('border-width', k.borderWidth, t.borderWidth);
      s.shadow = r.shadow('shadow', k.shadow, t.shadows.xs);
      if (hovered) {
        s.background = r.color('hover-background', k.hoverBackground, c.accent);
        s.foreground = r.color('hover-foreground', k.hoverForeground, c.accentForeground);
      }
    } else if (hovered) {
      s.background = r.color('hover-background', k.hoverBackground, c.muted);
      s.foreground = r.color('hover-foreground', k.hoverForeground, c.mutedForeground);
    }
    if (on) {
      s.background = r.color('on-background', k.onBackground, c.accent);
      s.foreground = r.color('on-foreground', k.onForeground, c.accentForeground);
    }
    s.pressedBackground = SparkColor.mix(on || hovered ? s.background : c.muted, c.foreground, 0.06);
    switch (size) {
      case 'sm':
        s.height = r.len('height-sm', k.height, 32);
        s.paddingX = 6;
        break;
      case 'lg':
        s.height = r.len('height-lg', k.height, 40);
        s.paddingX = 10;
        break;
      default:
        s.height = r.len('height', k.height, 36);
        s.paddingX = 8;
    }
    s.minWidth = s.height;
    return s;
  }

  /** Corner radii for a toggle joined into a group (`rounded-none first:rounded-l-md last:rounded-r-md`). */
  static radii(radius: number, join: ToggleJoin): BorderRadiuses {
    const left = join === 'none' || join === 'only' || join === 'first' ? radius : 0;
    const right = join === 'none' || join === 'only' || join === 'last' ? radius : 0;
    const r: BorderRadiuses = { topLeft: left, bottomLeft: left, topRight: right, bottomRight: right };
    return r;
  }

  /** Border widths: outline items share borders (`border-l-0 first:border-l`). */
  static edges(width: number, join: ToggleJoin): EdgeWidths {
    const left = join === 'middle' || join === 'last' ? 0 : width;
    const e: EdgeWidths = { top: width, bottom: width, left: left, right: width };
    return e;
  }
}

/** Applies a {@link ToggleStyle} to a Row; pressed look via the system pressed state. */
export class ToggleStyleModifier implements AttributeModifier<RowAttribute> {
  style: ToggleStyle;
  join: ToggleJoin;
  disabled: boolean;

  constructor(style: ToggleStyle, join: ToggleJoin, disabled: boolean) {
    this.style = style;
    this.join = join;
    this.disabled = disabled;
  }

  applyNormalAttribute(instance: RowAttribute): void {
    const s = this.style;
    const grouped = this.join !== 'none';
    instance
      .height(s.height)
      .constraintSize({ minWidth: s.minWidth })
      .padding({ left: s.paddingX, right: s.paddingX, top: 0, bottom: 0 })
      .backgroundColor(s.background)
      // radius inside border(): a later border() without radius would reset it
      .border({
        width: ToggleVariants.edges(s.borderWidth, this.join),
        color: s.borderColor,
        radius: ToggleVariants.radii(s.radius, this.join)
      })
      .shadow(s.shadow !== undefined && !grouped ? s.shadow.toOptions() : { radius: 0, color: Color.Transparent })
      .opacity(this.disabled ? 0.5 : 1)
  }

  applyPressedAttribute(instance: RowAttribute): void {
    if (this.disabled) {
      return;
    }
    if (this.style.pressFade) {
      instance.opacity(0.6)
      return;
    }
    instance.backgroundColor(this.style.pressedBackground)
  }
}
