import { SparkColor } from '../theme/color/SparkColor';
import { SparkTheme } from '../theme/tokens/SparkTheme';

/**
 * Semantic status colour of a component (Progress, Badge, Alert, Avatar status …).
 * `default` is the theme's `primary`, `destructive` the theme's `destructive`.
 */
export type SparkTone = 'default' | 'success' | 'warning' | 'info' | 'destructive';

/** Resolved colours of a tone. */
export class SparkToneColors {
  /** filled surface / indicator colour (`bg-primary`) */
  solid: string = '#FF000000';
  /** text / icon on `solid` (`text-primary-foreground`) */
  onSolid: string = '#FFFFFFFF';
  /** tinted surface (`bg-primary/10`) */
  soft: string = '#00000000';
  /** text / icon on `soft` or on the page background */
  text: string = '#FF000000';
  /** tinted outline (`border-primary/30`) */
  border: string = '#00000000';
  /** progress track / buffer base (`bg-primary/20`) */
  track: string = '#00000000';
}

/**
 * @deprecated Status colours are theme tokens now (`--success`, `--warning`, `--info` and their
 * `-foreground`, ADR D13), defined by every preset in light and dark. Brand them in the theme file or with
 * `SparkUI.themes.setVariable('--success', 'oklch(0.6 0.17 150)')`. Kept for source compatibility; its values
 * are the preset defaults and are no longer read.
 */
export class SparkStatusPalette {
  successLight: string = '#FF059669';
  successDark: string = '#FF10B981';
  warningLight: string = '#FFD97706';
  warningDark: string = '#FFF59E0B';
  infoLight: string = '#FF0284C7';
  infoDark: string = '#FF38BDF8';
  /** foreground on a solid warning surface (amber is light: dark text reads better) */
  onWarning: string = '#FF1C1917';
}

/**
 * Tone recipe. Every tone reads semantic theme tokens: `default` → primary, `destructive` → destructive,
 * `success` / `warning` / `info` → the status tokens of the same name (with their `-foreground`).
 */
export class SparkTones {
  /** @deprecated see {@link SparkStatusPalette}; no longer read. */
  static palette: SparkStatusPalette = new SparkStatusPalette();

  /** Base colour of `tone` for the current theme. */
  static base(t: SparkTheme, tone: SparkTone): string {
    const c = t.colors;
    switch (tone) {
      case 'success':
        return c.success;
      case 'warning':
        return c.warning;
      case 'info':
        return c.info;
      case 'destructive':
        return c.destructive;
      default:
        return c.primary;
    }
  }

  /** Text / icon colour on a solid `tone` surface. */
  static foreground(t: SparkTheme, tone: SparkTone): string {
    const c = t.colors;
    switch (tone) {
      case 'success':
        return c.successForeground;
      case 'warning':
        return c.warningForeground;
      case 'info':
        return c.infoForeground;
      case 'destructive':
        return c.destructiveForeground;
      default:
        return c.primaryForeground;
    }
  }

  static resolve(t: SparkTheme, tone: SparkTone): SparkToneColors {
    const c = t.colors;
    const r = new SparkToneColors();
    const base = SparkTones.base(t, tone);
    r.solid = base;
    r.onSolid = SparkTones.foreground(t, tone);
    r.text = tone === 'default' ? c.foreground : base;
    r.soft = SparkColor.alpha(base, t.isDark ? 0.2 : 0.1);
    r.border = SparkColor.alpha(base, t.isDark ? 0.5 : 0.35);
    r.track = SparkColor.alpha(base, 0.2);
    return r;
  }
}
