import { SparkColor } from '../../theme/color/SparkColor';
import { SparkShadow } from '../../theme/tokens/SparkShadow';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../../theme/tokens/SparkTokenReader';

/**
 * Per-instance token overrides of SColorPanel / SColorPicker (ADR D13): instance → theme `--color-picker-*` →
 * recipe. Colours / shadows use the theme file syntax; lengths are vp.
 * `SColorPanel({ tokens: { areaHeight: 200, radius: 0, swatchSize: 24 } })`
 */
export interface ColorPickerTokens {
  /** border of the area, swatches and preview (default `--border`) */
  borderColor?: string;
  /** light / dark cells of the transparency checkerboard */
  checkerLight?: string;
  checkerDark?: string;
  /** ring of the area / slider thumbs (default white, like most colour pickers) */
  thumbBorderColor?: string;
  /** panel width (default 240) */
  width?: number;
  /** saturation / value area height (default 160) */
  areaHeight?: number;
  /** area / preview radius (default `radius-md`) */
  radius?: number;
  /** hue / alpha track height (default 12) */
  trackHeight?: number;
  /** thumb diameter (default 16) */
  thumbSize?: number;
  /** preset / recent swatch size (default 20) */
  swatchSize?: number;
  swatchRadius?: number;
  swatchGap?: number;
  /** gap between the panel's rows (default 12) */
  gap?: number;
  thumbShadow?: string;
}

/** Resolved colour picker recipe (see {@link sparkColorPickerStyle}). */
export class ColorPickerStyle {
  borderColor: string = '#00000000';
  checkerLight: string = '#00000000';
  checkerDark: string = '#00000000';
  thumbBorderColor: string = '#FFFFFFFF';
  width: number = 240;
  areaHeight: number = 160;
  radius: number = 6;
  trackHeight: number = 12;
  thumbSize: number = 16;
  swatchSize: number = 20;
  swatchRadius: number = 4;
  swatchGap: number = 4;
  gap: number = 12;
  thumbShadow: SparkShadow | undefined = undefined;
}

/** Thumb ring recipe: `border-2 border-white` (Tailwind palette white), as in shadcn colour pickers. */
const THUMB_RING: string = '#FFFFFFFF';

/**
 * Colour picker recipe: `--color-picker-*` tokens over the built-in values, then the instance `tokens`.
 * The checkerboard is derived from `--background` / `--foreground` so it reads in light and dark themes.
 */
export function sparkColorPickerStyle(t: SparkTheme, tokens?: ColorPickerTokens): ColorPickerStyle {
  const r = new SparkTokenReader(t, 'color-picker');
  const s = new ColorPickerStyle();
  s.borderColor = r.color('border-color', tokens?.borderColor, t.colors.border);
  s.checkerLight = r.color('checker-light', tokens?.checkerLight, t.colors.background);
  s.checkerDark = r.color('checker-dark', tokens?.checkerDark,
    SparkColor.mix(t.colors.background, t.colors.foreground, 0.14));
  s.thumbBorderColor = r.color('thumb-border-color', tokens?.thumbBorderColor, THUMB_RING);
  s.width = r.len('width', tokens?.width, 240);
  s.areaHeight = r.len('area-height', tokens?.areaHeight, 160);
  s.radius = r.len('radius', tokens?.radius, t.radiusMd);
  s.trackHeight = r.len('track-height', tokens?.trackHeight, 12);
  s.thumbSize = r.len('thumb-size', tokens?.thumbSize, 16);
  s.swatchSize = r.len('swatch-size', tokens?.swatchSize, 20);
  s.swatchRadius = r.len('swatch-radius', tokens?.swatchRadius, t.radiusSm);
  s.swatchGap = r.len('swatch-gap', tokens?.swatchGap, 4);
  s.gap = r.len('gap', tokens?.gap, 12);
  s.thumbShadow = r.shadow('thumb-shadow', tokens?.thumbShadow, t.shadows.sm);
  return s;
}
