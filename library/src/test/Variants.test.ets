import { describe, it, expect } from '@ohos/hypium';
import { SparkTones } from '../main/ets/core/SparkTone';
import { SparkTheme } from '../main/ets/theme/tokens/SparkTheme';
import { SparkColor } from '../main/ets/theme/color/SparkColor';
import { ButtonTokens, ButtonVariants } from '../main/ets/components/button/ButtonVariants';
import {
  SparkProgressArc, sparkRingArcPath, sparkProgressLabel, sparkProgressPercent, sparkSegmentFills
} from '../main/ets/components/progress/ProgressLogic';
import { sparkBadgeCount } from '../main/ets/components/badge/SBadge';
import { sparkAvatarRadius, sparkAvatarSize } from '../main/ets/components/avatar/SAvatar';
import { sparkSkeletonLineWidth } from '../main/ets/components/skeleton/SSkeleton';
import { sparkKbdIcon } from '../main/ets/components/kbd/SKbd';
import { sparkInputCounter, sparkInputHeight } from '../main/ets/components/input/SInput';
import {
  sparkMoveRangeThumb, sparkSliderTicks, sparkSnapRange, sparkSnapSlider
} from '../main/ets/components/slider/SSlider';

function list(a: number[]): string {
  return a.map((n: number) => String(n)).join(',');
}

export default function variantsTest() {
  describe('Variants', () => {
    it('progress_percent_clamps', 0, () => {
      expect(sparkProgressPercent(50, 200)).assertEqual(25);
      expect(sparkProgressPercent(-5, 100)).assertEqual(0);
      expect(sparkProgressPercent(150, 100)).assertEqual(100);
      expect(sparkProgressPercent(3, 0)).assertEqual(0);
      expect(sparkProgressLabel(66.4)).assertEqual('66%');
    });
    it('progress_percent_never_nan', 0, () => {
      expect(sparkProgressPercent(NaN, 100)).assertEqual(0);
      expect(sparkProgressPercent(50, NaN)).assertEqual(0);
      expect(sparkProgressPercent(50, Infinity)).assertEqual(0);
      expect(sparkProgressPercent(Infinity, 100)).assertEqual(100);
    });
    it('slider_snap_never_nan', 0, () => {
      expect(sparkSnapSlider(NaN, 0, 10, 1)).assertEqual(0);
      expect(sparkSnapSlider(5, NaN, 10, 1)).assertEqual(5);
      expect(sparkSnapSlider(5, 0, NaN, 1)).assertEqual(0);
      expect(sparkSnapSlider(3.4, 0, 10, NaN)).assertEqual(3);
      expect(sparkSnapSlider(Infinity, 0, 10, 1)).assertEqual(10);
      // exponent-form step keeps its precision (String(1e-7) has no '.')
      expect(sparkSnapSlider(0.00000034, 0, 1, 0.0000001)).assertEqual(0.0000003);
    });
    it('segment_fills', 0, () => {
      expect(list(sparkSegmentFills(60, 5))).assertEqual('1,1,1,0,0');
      expect(list(sparkSegmentFills(50, 4))).assertEqual('1,1,0,0');
      expect(Math.abs(sparkSegmentFills(70, 4)[2] - 0.8) < 1e-9).assertTrue();
      expect(sparkSegmentFills(30, 0).length).assertEqual(0);
    });
    it('arc_path', 0, () => {
      expect(sparkRingArcPath(50, 50, 40, 0, 0)).assertEqual('');
      // quarter arc from 12 o'clock to 3 o'clock, small arc, clockwise
      expect(sparkRingArcPath(50, 50, 40, 0, 90)).assertEqual('M50 10 A40 40 0 0 1 90 50');
      // more than half: large-arc flag set
      expect(sparkRingArcPath(50, 50, 40, 0, 270)).assertEqual('M50 10 A40 40 0 1 1 10 50');
      // full circle: two half arcs back to the start
      expect(sparkRingArcPath(50, 50, 40, 0, 360)).assertEqual('M50 10 A40 40 0 1 1 50 90 A40 40 0 1 1 50 10');
    });
    it('arc_is_animatable_arithmetic', 0, () => {
      const a = new SparkProgressArc(10, 10, 8, 0, 90);
      const b = new SparkProgressArc(10, 10, 8, 0, 270);
      const mid = a.plus(b.subtract(a).multiply(0.5));
      expect(mid.sweep).assertEqual(180);
      expect(mid.equals(new SparkProgressArc(10, 10, 8, 0, 180))).assertTrue();
      expect(a.equals(b)).assertFalse();
    });
    it('badge_count', 0, () => {
      expect(sparkBadgeCount(5, 99)).assertEqual('5');
      expect(sparkBadgeCount(100, 99)).assertEqual('99+');
      expect(sparkBadgeCount(1000, 0)).assertEqual('1000');
      expect(sparkBadgeCount(-3, 99)).assertEqual('0');
    });
    it('tones', 0, () => {
      const t = new SparkTheme();
      expect(SparkTones.resolve(t, 'default').solid).assertEqual(t.colors.primary);
      expect(SparkTones.resolve(t, 'destructive').solid).assertEqual(t.colors.destructive);
      expect(SparkTones.resolve(t, 'success').solid).assertEqual(SparkTones.palette.successLight);
      expect(SparkTones.resolve(t, 'warning').onSolid).assertEqual(SparkTones.palette.onWarning);
    });
    it('avatar_sizes_and_shapes', 0, () => {
      expect(sparkAvatarSize('lg')).assertEqual(48);
      expect(sparkAvatarSize(36)).assertEqual(36);
      expect(sparkAvatarSize('default')).assertEqual(32);
      expect(sparkAvatarRadius('circle', 40, 8)).assertEqual(20);
      expect(sparkAvatarRadius('rounded', 40, 8)).assertEqual(8);
      expect(sparkAvatarRadius('rounded', 20, 8)).assertEqual(5);
      expect(sparkAvatarRadius('square', 40, 8)).assertEqual(4);
    });
    it('skeleton_lines', 0, () => {
      expect(sparkSkeletonLineWidth(0, 3)).assertEqual('100%');
      expect(sparkSkeletonLineWidth(2, 3)).assertEqual('60%');
      expect(sparkSkeletonLineWidth(0, 1)).assertEqual('100%');
    });
    it('kbd_icons', 0, () => {
      expect(sparkKbdIcon('cmd')).assertEqual('command');
      expect(sparkKbdIcon('Enter')).assertEqual('corner-down-left');
      expect(sparkKbdIcon('K') === undefined).assertTrue();
    });
    it('input_size_and_counter', 0, () => {
      expect(sparkInputHeight('sm')).assertEqual(32);
      expect(sparkInputHeight('default')).assertEqual(36);
      expect(sparkInputHeight('lg')).assertEqual(40);
      expect(sparkInputCounter(12, 80)).assertEqual('12/80');
      expect(sparkInputCounter(12, undefined)).assertEqual('12');
    });
    it('slider_range', 0, () => {
      expect(list(sparkSnapRange([80, 20], 0, 100, 10))).assertEqual('20,80');
      expect(list(sparkSnapRange([], 0, 100, 1))).assertEqual('0,100');
      expect(list(sparkSnapRange([23, 77], 0, 100, 5))).assertEqual('25,75');
      // thumbs never cross
      expect(list(sparkMoveRangeThumb([20, 60], 0, 90))).assertEqual('60,60');
      expect(list(sparkMoveRangeThumb([20, 60], 1, 10))).assertEqual('20,20');
      expect(list(sparkMoveRangeThumb([20, 60], 1, 75))).assertEqual('20,75');
      expect(sparkSnapSlider(0.33, 0, 1, 0.05)).assertEqual(0.35);
    });
    it('slider_ticks', 0, () => {
      expect(list(sparkSliderTicks(0, 4, 1, 41))).assertEqual('0,1,2,3,4');
      expect(list(sparkSliderTicks(0, 1, 0.25, 41))).assertEqual('0,0.25,0.5,0.75,1');
      expect(sparkSliderTicks(0, 100, 1, 41).length).assertEqual(0);
    });
    it('button_foreground_token_channel_order', 0, () => {
      const t = new SparkTheme();
      t.colors.primary = '#FF4169E1';
      t.colors.destructive = '#FFE7000B';
      expect(SparkColor.toCss('#FF4169E1')).assertEqual('#4169E1FF');
      expect(SparkColor.toCss('#4169e1')).assertEqual('#4169e1');
      const blue: ButtonTokens = { foreground: '#4169E1FF' };
      const red: ButtonTokens = { foreground: '#e7000b' };
      const themeBlue: ButtonTokens = { foreground: t.colors.primary };
      const themeRed: ButtonTokens = { foreground: t.colors.destructive };
      const converted: ButtonTokens = { foreground: SparkColor.toCss('#80E7000B') };
      // CSS #RRGGBBAA
      expect(ButtonVariants.resolve(t, 'ghost', 'icon-sm', blue).foreground).assertEqual('#FF4169E1');
      expect(ButtonVariants.resolve(t, 'outline', 'icon-sm', red).foreground).assertEqual('#FFE7000B');
      // a theme colour (ArkUI #AARRGGBB) passed straight through keeps its colour
      expect(ButtonVariants.resolve(t, 'ghost', 'icon-sm', themeBlue).foreground).assertEqual('#FF4169E1');
      expect(ButtonVariants.resolve(t, 'outline', 'default', themeRed).foreground).assertEqual('#FFE7000B');
      expect(ButtonVariants.resolve(t, 'outline', 'default', converted).foreground).assertEqual('#80E7000B');
    });
  });
}
