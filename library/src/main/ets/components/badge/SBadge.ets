import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkTone, SparkToneColors, SparkTones } from '../../core/SparkTone';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type BadgeVariant = 'default' | 'secondary' | 'destructive' | 'outline' | 'success' | 'warning' | 'info';
export type BadgeSize = 'sm' | 'default' | 'lg';

/** Resolved colours of a badge (the output of the variant recipe). */
export class BadgeStyle {
  background: string = '#00000000';
  foreground: string = '#FF000000';
  borderColor: string = '#00000000';
  /** colour of the `dot` indicator */
  dot: string = '#FF000000';
}

/** Text shown for a numeric badge: `count`, or `max+` above `max` ("99+"). */
export function sparkBadgeCount(count: number, max: number): string {
  const n = Math.max(0, Math.floor(count));
  return max > 0 && n > max ? `${max}+` : `${n}`;
}

function toneOf(variant: BadgeVariant): SparkTone {
  switch (variant) {
    case 'destructive':
      return 'destructive';
    case 'success':
      return 'success';
    case 'warning':
      return 'warning';
    case 'info':
      return 'info';
    default:
      return 'default';
  }
}

/** shadcn-vue `badgeVariants`, plus status tones and a `soft` (tinted) look. */
export class BadgeVariants {
  static resolve(t: SparkTheme, variant: BadgeVariant, soft?: boolean): BadgeStyle {
    const c = t.colors;
    const s = new BadgeStyle();
    switch (variant) {
      case 'secondary':
        s.background = c.secondary;
        s.foreground = c.secondaryForeground;
        s.dot = c.secondaryForeground;
        return s;
      case 'outline':
        s.foreground = c.foreground;
        s.borderColor = c.border;
        s.dot = c.primary;
        return s;
      default:
        break;
    }
    const tone: SparkToneColors = SparkTones.resolve(t, toneOf(variant));
    if (soft === true) {
      s.background = tone.soft;
      s.foreground = variant === 'default' ? c.primary : tone.text;
      s.dot = s.foreground;
      return s;
    }
    if (variant === 'destructive') {
      // bg-destructive text-white dark:bg-destructive/60
      s.background = t.isDark ? SparkColor.alpha(c.destructive, 0.6) : c.destructive;
    } else {
      s.background = tone.solid;
    }
    s.foreground = tone.onSolid;
    s.dot = tone.onSolid;
    return s;
  }
}

/**
 * shadcn-vue `Badge`: `inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs font-medium`.
 *
 * Variants: default | secondary | destructive | outline | success | warning | info, each `soft` (tinted) if
 * wanted. `sizing` sm | default | lg, `pill` (rounded-full), `dot` (leading status dot — or a bare 8vp dot when
 * there is no text), `removable` (trailing ×, emits `onRemove`) and `count` / `max` for notification counts
 * ("99+"; hidden at 0 unless `showZero`).
 *
 * ```
 * SBadge({ text: 'New' })
 * SBadge({ text: 'Verified', variant: 'secondary', icon: 'circle-check' })
 * SBadge({ text: 'Active', variant: 'success', soft: true, dot: true })
 * SBadge({ count: 128, variant: 'destructive' })                  // "99+"
 * SBadge({ text: 'react', variant: 'outline', removable: true, onRemove: () => ... })
 * SBadge({ variant: 'outline' }) { Text('Custom') }
 * ```
 */
@ComponentV2
export struct SBadge {
  @Param text: ResourceStr | undefined = undefined;
  @Param variant: BadgeVariant = 'default';
  /** Tinted background with coloured text instead of a solid fill. */
  @Param soft: boolean = false;
  @Param sizing: BadgeSize = 'default';
  /** Fully rounded (`rounded-full`). Count badges are always pills. */
  @Param pill: boolean = false;
  /** Leading status dot; without text / count the badge is just the dot. */
  @Param dot: boolean = false;
  /** Overrides the dot colour. */
  @Param dotColor: ResourceColor | undefined = undefined;
  /** Leading lucide icon name. */
  @Param icon: string | undefined = undefined;
  /** Trailing lucide icon name. */
  @Param iconRight: string | undefined = undefined;
  /** Numeric badge (takes precedence over `text`). */
  @Param count: number | undefined = undefined;
  /** Above `max` the count reads "max+". 0 = no cap. */
  @Param max: number = 99;
  /** Keep a count badge visible at 0. */
  @Param showZero: boolean = false;
  /** Trailing × that emits `onRemove` (tags, filters). */
  @Param removable: boolean = false;
  @Event onRemove: () => void = () => {
  };
  @Param modifier: AttributeModifier<RowAttribute> = new SparkNoopModifier<RowAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get styles(): BadgeStyle {
    return BadgeVariants.resolve(this.theme, this.variant, this.soft);
  }

  @Computed
  get label(): ResourceStr | undefined {
    if (this.count !== undefined) {
      return sparkBadgeCount(this.count, this.max);
    }
    return this.text;
  }

  @Computed
  get hidden(): boolean {
    return this.count !== undefined && this.count <= 0 && !this.showZero;
  }

  /** a bare dot: no text, count, icon or slot content (slot content cannot be detected; pass text for it) */
  @Computed
  get dotOnly(): boolean {
    return this.dot && this.label === undefined && this.icon === undefined && this.iconRight === undefined &&
      !this.removable;
  }

  @Computed
  get fontSize(): number {
    return this.sizing === 'lg' ? this.theme.text.sm : (this.sizing === 'sm' ? 10 : this.theme.text.xs);
  }

  @Computed
  get iconSize(): number {
    return this.sizing === 'lg' ? 14 : (this.sizing === 'sm' ? 10 : 12);
  }

  @Computed
  get paddingX(): number {
    if (this.count !== undefined) {
      return this.sizing === 'lg' ? 6 : 4;
    }
    return this.sizing === 'lg' ? 10 : (this.sizing === 'sm' ? 6 : 8);
  }

  @Computed
  get paddingY(): number {
    return this.sizing === 'lg' ? 3 : (this.sizing === 'sm' ? 0 : 2);
  }

  /** text line + padding + 1px border on both sides */
  @Computed
  get minHeight(): number {
    const line = this.sizing === 'lg' ? this.theme.text.leadingSm : (this.sizing === 'sm' ? 14 : this.theme.text.leadingXs);
    return line + this.paddingY * 2 + 2;
  }

  @Computed
  get radius(): number {
    return this.pill || this.count !== undefined ? 9999 : this.theme.radiusMd;
  }

  @Computed
  get dotPaint(): ResourceColor {
    return this.dotColor ?? this.styles.dot;
  }

  build() {
    if (this.dotOnly) {
      Row()
        .width(this.sizing === 'lg' ? 10 : (this.sizing === 'sm' ? 6 : 8))
        .aspectRatio(1)
        .flexShrink(0)
        .backgroundColor(this.dotColor ?? (this.variant === 'outline' ? this.theme.colors.primary : this.styles.background))
        .border({ width: 0, radius: 9999 })
        .accessibilityLevel('no')
    } else {
      Row({ space: 4 }) {
        if (this.dot) {
          Row()
            .width(6)
            .height(6)
            .backgroundColor(this.dotPaint)
            .border({ width: 0, radius: 3 })
        }
        if (this.icon !== undefined) {
          SIcon({ name: this.icon, sizing: this.iconSize, color: this.styles.foreground })
        }
        if (this.label !== undefined) {
          Text(this.label)
            .fontSize(this.fontSize)
            .fontWeight(this.theme.text.weightMedium)
            .fontColor(this.styles.foreground)
            .fontFeature('"tnum" on')
            .maxLines(1)
        }
        this.content()
        if (this.iconRight !== undefined) {
          SIcon({ name: this.iconRight, sizing: this.iconSize, color: this.styles.foreground })
        }
        if (this.removable) {
          Row() {
            SIcon({ name: 'x', sizing: this.iconSize, color: this.styles.foreground })
          }
          .margin({ right: -2 })
          .border({ width: 0, radius: 9999 })
          .responseRegion({ x: -6, y: -6, width: this.iconSize + 12, height: this.iconSize + 12 })
          .stateStyles({ normal: this.removeNormal, pressed: this.removePressed })
          .accessibilityText('Remove')
          .onClick(() => this.onRemove())
        }
      }
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .flexShrink(0)
      .constraintSize({ minWidth: this.count !== undefined ? this.minHeight : 0, minHeight: this.minHeight })
      .padding({ left: this.paddingX, right: this.paddingX, top: this.paddingY, bottom: this.paddingY })
      .backgroundColor(this.styles.background)
      .border({ width: 1, color: this.styles.borderColor, radius: this.radius })
      .visibility(this.hidden ? Visibility.None : Visibility.Visible)
      .attributeModifier(this.modifier)
    }
  }

  @Styles
  removeNormal() {
    .opacity(0.7)
  }

  @Styles
  removePressed() {
    .opacity(1)
    .backgroundColor(SparkColor.alpha(this.styles.foreground, 0.15))
  }
}
