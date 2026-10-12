import { describe, it, expect } from '@ohos/hypium';
import { SparkColor } from '../main/ets/theme/color/SparkColor';

function hex(input: string): string {
  const r = SparkColor.parse(input);
  return r.ok ? r.value : `ERR:${r.error}`;
}

export default function sparkColorTest() {
  describe('SparkColor', () => {
    // Reference values: Tailwind v4 palette (oklch) ↔ published sRGB hex.
    it('oklch_neutral_scale', 0, () => {
      expect(hex('oklch(1 0 0)')).assertEqual('#FFFFFFFF');
      expect(hex('oklch(0.985 0 0)')).assertEqual('#FFFAFAFA');
      expect(hex('oklch(0.922 0 0)')).assertEqual('#FFE5E5E5');
      expect(hex('oklch(0.205 0 0)')).assertEqual('#FF171717');
      expect(hex('oklch(0.145 0 0)')).assertEqual('#FF0A0A0A');
    });
    it('oklch_chromatic', 0, () => {
      expect(hex('oklch(0.577 0.245 27.325)')).assertEqual('#FFE7000B'); // red-600
      expect(hex('oklch(0.646 0.222 41.116)')).assertEqual('#FFF54900'); // orange-600
    });
    it('oklch_alpha_and_units', 0, () => {
      expect(hex('oklch(1 0 0 / 10%)')).assertEqual('#1AFFFFFF');
      expect(hex('oklch(100% 0 0 / 0.5)')).assertEqual('#80FFFFFF');
      expect(hex('oklch(0.577 0.245 27.325deg)')).assertEqual('#FFE7000B');
    });
    it('oklch_gamut_mapping_stays_in_range', 0, () => {
      // Far outside sRGB: must still produce a valid opaque colour, never NaN.
      const r = SparkColor.parse('oklch(0.6 0.4 150)');
      expect(r.ok).assertTrue();
      expect(/^#FF[0-9A-F]{6}$/.test(r.value)).assertTrue();
      const lch = SparkColor.rgbToOklch(SparkColor.fromArgbHex(r.value));
      // hue preserved within a few degrees, lightness close
      expect(Math.abs(lch[2] - 150) < 6).assertTrue();
      expect(Math.abs(lch[0] - 0.6) < 0.05).assertTrue();
    });
    it('hsl_forms', 0, () => {
      expect(hex('hsl(0 0% 100%)')).assertEqual('#FFFFFFFF');
      expect(hex('hsl(0, 100%, 50%)')).assertEqual('#FFFF0000');
      expect(hex('hsla(120, 100%, 25%, 0.5)')).assertEqual('#80008000');
      // shadcn v1 bare triplet
      expect(hex('222.2 84% 4.9%')).assertEqual('#FF020817');
    });
    it('rgb_and_hex', 0, () => {
      expect(hex('rgb(255 0 0 / 0.5)')).assertEqual('#80FF0000');
      expect(hex('rgba(0,0,0,0.5)')).assertEqual('#80000000');
      expect(hex('#f00')).assertEqual('#FFFF0000');
      expect(hex('#F00A')).assertEqual('#AAFF0000');
      expect(hex('#112233')).assertEqual('#FF112233');
      expect(hex('#11223344')).assertEqual('#44112233');
      expect(hex('transparent')).assertEqual('#00000000');
    });
    it('rejects_invalid', 0, () => {
      expect(SparkColor.parse('').ok).assertFalse();
      expect(SparkColor.parse('foo').ok).assertFalse();
      expect(SparkColor.parse('oklch(x 0 0)').ok).assertFalse();
      expect(SparkColor.parse('#12').ok).assertFalse();
      expect(SparkColor.parse('#zzzzzz').ok).assertFalse();
      expect(SparkColor.parse('rgb(1 2)').ok).assertFalse();
      expect(SparkColor.parse('lab(50 0 0)').ok).assertFalse();
    });
    it('alpha_mix_helpers', 0, () => {
      expect(SparkColor.alpha('#FF171717', 0.9)).assertEqual('#E6171717');
      expect(SparkColor.mix('#FF000000', '#FFFFFFFF', 0.5)).assertEqual('#FF808080');
      expect(SparkColor.isDark('#FF0A0A0A')).assertTrue();
      expect(SparkColor.isDark('#FFFAFAFA')).assertFalse();
    });
  });
}
