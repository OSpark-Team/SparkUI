import { CustomColors, CustomTheme, ThemeControl } from '@kit.ArkUI';
import { SparkColor } from './color/SparkColor';
import { SparkColors } from './tokens/SparkColors';

/**
 * Maps SparkUI semantic tokens to the system `Colors` token set so native ArkUI components
 * (TextInput, Toggle, Slider, Select, Divider …) mixed into a SparkUI page roughly follow the theme.
 * The mapping table is documented in docs/design/01-theme-system.md.
 */
export class SystemThemeBridge {
  static toCustomColors(c: SparkColors): CustomColors {
    const a = (hex: string, o: number): string => SparkColor.alpha(hex, o);
    const colors: CustomColors = {
      brand: c.primary,
      alert: c.destructive,

      fontPrimary: c.foreground,
      fontSecondary: c.mutedForeground,
      fontTertiary: a(c.mutedForeground, 0.7),
      fontFourth: a(c.mutedForeground, 0.5),
      fontEmphasize: c.primary,
      fontOnPrimary: c.primaryForeground,
      fontOnSecondary: c.secondaryForeground,
      fontOnTertiary: a(c.primaryForeground, 0.7),
      fontOnFourth: a(c.primaryForeground, 0.5),

      iconPrimary: c.foreground,
      iconSecondary: c.mutedForeground,
      iconTertiary: a(c.mutedForeground, 0.7),
      iconFourth: a(c.mutedForeground, 0.5),
      iconEmphasize: c.primary,
      iconSubEmphasize: a(c.primary, 0.6),
      iconOnPrimary: c.primaryForeground,
      iconOnSecondary: c.secondaryForeground,
      iconOnTertiary: a(c.primaryForeground, 0.7),
      iconOnFourth: a(c.primaryForeground, 0.5),

      backgroundPrimary: c.background,
      backgroundSecondary: c.muted,
      backgroundTertiary: c.muted,
      backgroundFourth: c.accent,
      backgroundEmphasize: c.primary,

      compForegroundPrimary: c.foreground,
      compBackgroundPrimary: c.card,
      compBackgroundPrimaryTran: a(c.card, 0.8),
      compBackgroundPrimaryContrary: c.foreground,
      compBackgroundGray: c.muted,
      compBackgroundSecondary: c.secondary,
      compBackgroundTertiary: c.accent,
      compBackgroundEmphasize: c.primary,
      compBackgroundNeutral: c.foreground,
      compEmphasizeSecondary: a(c.primary, 0.2),
      compEmphasizeTertiary: a(c.primary, 0.1),
      compDivider: c.border,
      compCommonContrary: c.background,
      compBackgroundFocus: c.background,
      compFocusedPrimary: c.foreground,
      compFocusedSecondary: c.mutedForeground,
      compFocusedTertiary: c.muted,

      interactiveHover: a(c.foreground, 0.05),
      interactivePressed: a(c.foreground, 0.1),
      interactiveFocus: c.ring,
      interactiveActive: c.primary,
      interactiveSelect: a(c.primary, 0.2),
      interactiveClick: a(c.foreground, 0.1)
    };
    return colors;
  }

  static toCustomTheme(c: SparkColors): CustomTheme {
    const theme: CustomTheme = { colors: SystemThemeBridge.toCustomColors(c) };
    return theme;
  }

  /** Apply as the app default theme (affects native components created afterwards). Never throws. */
  static applyDefault(c: SparkColors): void {
    try {
      ThemeControl.setDefaultTheme(SystemThemeBridge.toCustomTheme(c));
    } catch (e) {
      // ThemeControl is best-effort; SparkUI components never depend on it.
    }
  }
}
