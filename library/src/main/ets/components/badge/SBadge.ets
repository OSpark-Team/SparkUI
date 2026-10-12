import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type BadgeVariant = 'default' | 'secondary' | 'destructive' | 'outline';

/** Resolved colours of a badge (the output of the variant recipe). */
export class BadgeStyle {
  background: string = '#00000000';
  foreground: string = '#FF000000';
  borderColor: string = '#00000000';
}

/** shadcn-vue `badgeVariants`. */
export class BadgeVariants {
  static resolve(t: SparkTheme, variant: BadgeVariant): BadgeStyle {
    const c = t.colors;
    const s = new BadgeStyle();
    switch (variant) {
      case 'secondary':
        s.background = c.secondary;
        s.foreground = c.secondaryForeground;
        break;
      case 'destructive':
        // bg-destructive text-white dark:bg-destructive/60
        s.background = t.isDark ? SparkColor.alpha(c.destructive, 0.6) : c.destructive;
        s.foreground = c.destructiveForeground;
        break;
      case 'outline':
        s.foreground = c.foreground;
        s.borderColor = c.border;
        break;
      default:
        s.background = c.primary;
        s.foreground = c.primaryForeground;
    }
    return s;
  }
}

/**
 * shadcn-vue `Badge`: `inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs font-medium`.
 *
 * ```
 * SBadge({ text: 'New' })
 * SBadge({ text: 'Verified', variant: 'secondary', icon: 'circle-check' })
 * SBadge({ variant: 'outline' }) { Text('Custom') }
 * ```
 */
@ComponentV2
export struct SBadge {
  @Param text: ResourceStr | undefined = undefined;
  @Param variant: BadgeVariant = 'default';
  /** Leading lucide icon name (12vp). */
  @Param icon: string | undefined = undefined;
  /** Trailing lucide icon name (12vp). */
  @Param iconRight: string | undefined = undefined;
  @Param modifier: AttributeModifier<RowAttribute> = new SparkNoopModifier<RowAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get styles(): BadgeStyle {
    return BadgeVariants.resolve(this.theme, this.variant);
  }

  build() {
    Row({ space: 4 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 12, color: this.styles.foreground })
      }
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.xs)
          .lineHeight(this.theme.text.leadingXs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.styles.foreground)
          .maxLines(1)
      }
      this.content()
      if (this.iconRight !== undefined) {
        SIcon({ name: this.iconRight, sizing: 12, color: this.styles.foreground })
      }
    }
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .flexShrink(0)
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .backgroundColor(this.styles.background)
    .border({ width: 1, color: this.styles.borderColor, radius: this.theme.radiusMd })
    .attributeModifier(this.modifier)
  }
}
