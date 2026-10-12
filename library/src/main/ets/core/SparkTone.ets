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

/** Status palette (light, dark) for the tones shadcn has no token for. Tailwind emerald / amber / sky. */
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
 * Tone recipe. `default` / `destructive` follow the theme tokens; success / warning / info come from
 * {@link SparkTones.palette} (shadcn has no such tokens). Replace the palette at start-up to brand them:
 * `SparkTones.palette.successLight = '#FF16A34A'`.
 */
export class SparkTones {
  static palette: SparkStatusPalette = new SparkStatusPalette();

  /** Base colour of `tone` for the current theme. */
  static base(t: SparkTheme, tone: SparkTone): string {
    const p = SparkTones.palette;
    switch (tone) {
      case 'success':
        return t.isDark ? p.successDark : p.successLight;
      case 'warning':
        return t.isDark ? p.warningDark : p.warningLight;
      case 'info':
        return t.isDark ? p.infoDark : p.infoLight;
      case 'destructive':
        return t.colors.destructive;
      default:
        return t.colors.primary;
    }
  }

  static resolve(t: SparkTheme, tone: SparkTone): SparkToneColors {
    const c = t.colors;
    const r = new SparkToneColors();
    const base = SparkTones.base(t, tone);
    r.solid = base;
    switch (tone) {
      case 'default':
        r.onSolid = c.primaryForeground;
        break;
      case 'destructive':
        r.onSolid = c.destructiveForeground;
        break;
      case 'warning':
        r.onSolid = SparkTones.palette.onWarning;
        break;
      default:
        r.onSolid = '#FFFFFFFF';
    }
    r.text = tone === 'default' ? c.foreground : base;
    r.soft = SparkColor.alpha(base, t.isDark ? 0.2 : 0.1);
    r.border = SparkColor.alpha(base, t.isDark ? 0.5 : 0.35);
    r.track = SparkColor.alpha(base, 0.2);
    return r;
  }
}
