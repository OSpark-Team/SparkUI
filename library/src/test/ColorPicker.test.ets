import { describe, it, expect } from '@ohos/hypium';
import { Rgba, SparkColor } from '../main/ets/theme/color/SparkColor';
import {
  sparkAreaToSv, sparkColorClamp, sparkColorFormatLabel, sparkColorNum, sparkColorValueToArgb, sparkFormatColor,
  sparkFormatHex, sparkFormatHsva, SparkHsva, sparkHsvaToArgb, sparkHsvToRgb, sparkHue, sparkHueStops,
  sparkIsHexColor, sparkNextColorFormat, sparkParseColor, sparkParseHex, sparkPushRecent, sparkRgbToHsl,
  sparkRgbToHsv, sparkSameColor, sparkTrackRatio, SPARK_DEFAULT_SWATCHES
} from '../main/ets/components/color-picker/ColorPickerLogic';

function hex(c: Rgba | undefined): string {
  return c === undefined ? 'undefined' : sparkFormatHex(c, true);
}

function near(a: number, b: number): boolean {
  return Math.abs(a - b) < 1e-6;
}

export default function colorPickerTest() {
  describe('ColorPicker', () => {
    it('clamp_and_hue', 0, () => {
      expect(sparkColorClamp(2, 0, 1)).assertEqual(1);
      expect(sparkColorClamp(-1, 0, 1)).assertEqual(0);
      expect(sparkColorClamp(NaN, 0, 1)).assertEqual(0);
      expect(sparkHue(360)).assertEqual(360);
      expect(sparkHue(-30)).assertEqual(330);
      expect(sparkHue(725)).assertEqual(5);
      expect(sparkHue(NaN)).assertEqual(0);
    });

    it('hsv_to_rgb_primaries', 0, () => {
      expect(hex(sparkHsvToRgb(0, 1, 1, 1))).assertEqual('#ff0000');
      expect(hex(sparkHsvToRgb(120, 1, 1, 1))).assertEqual('#00ff00');
      expect(hex(sparkHsvToRgb(240, 1, 1, 1))).assertEqual('#0000ff');
      expect(hex(sparkHsvToRgb(60, 1, 1, 1))).assertEqual('#ffff00');
      expect(hex(sparkHsvToRgb(360, 1, 1, 1))).assertEqual('#ff0000');
      expect(hex(sparkHsvToRgb(200, 0, 1, 1))).assertEqual('#ffffff');
      expect(hex(sparkHsvToRgb(200, 1, 0, 1))).assertEqual('#000000');
      expect(hex(sparkHsvToRgb(0, 0, 0.5, 0.5))).assertEqual('#80808080');
    });

    it('rgb_to_hsv_round_trip', 0, () => {
      const c = sparkParseHex('#3b82f6') as Rgba;
      const hsv = sparkRgbToHsv(c, 0, 0);
      expect(Math.round(hsv.h)).assertEqual(217);
      expect(Math.round(hsv.s * 100)).assertEqual(76);
      expect(Math.round(hsv.v * 100)).assertEqual(96);
      expect(hex(sparkHsvToRgb(hsv.h, hsv.s, hsv.v, hsv.a))).assertEqual('#3b82f6');
      // every default swatch survives hex → hsv → hex
      SPARK_DEFAULT_SWATCHES.forEach((s: string) => {
        const x = sparkParseHex(s) as Rgba;
        const h = sparkRgbToHsv(x, 0, 0);
        expect(sparkFormatHex(sparkHsvToRgb(h.h, h.s, h.v, 1), false)).assertEqual(s);
      });
    });

    it('greys_keep_hue_and_black_keeps_saturation', 0, () => {
      const grey = sparkRgbToHsv(new Rgba(0.5, 0.5, 0.5, 1), 123, 0.4);
      expect(grey.h).assertEqual(123);
      expect(grey.s).assertEqual(0);
      const black = sparkRgbToHsv(new Rgba(0, 0, 0, 1), 200, 0.7);
      expect(black.h).assertEqual(200);
      expect(black.s).assertEqual(0.7);
      expect(black.v).assertEqual(0);
    });

    it('hex_parse_strict', 0, () => {
      expect(sparkIsHexColor('#fff')).assertTrue();
      expect(sparkIsHexColor('FFAA00')).assertTrue();
      expect(sparkIsHexColor('#3b82f680')).assertTrue();
      expect(sparkIsHexColor('#ffff')).assertFalse();
      expect(sparkIsHexColor('#12345')).assertFalse();
      expect(sparkIsHexColor('#ggg')).assertFalse();
      expect(sparkIsHexColor('')).assertFalse();
      expect(hex(sparkParseHex('#f80'))).assertEqual('#ff8800');
      expect(hex(sparkParseHex(' 3B82F6 '))).assertEqual('#3b82f6');
      // CSS order: alpha last
      const a = sparkParseHex('#3b82f680') as Rgba;
      expect(Math.round(a.a * 255)).assertEqual(128);
      expect(hex(a)).assertEqual('#3b82f680');
      expect(sparkParseHex('#ffff') === undefined).assertTrue();
    });

    it('hex_format_alpha', 0, () => {
      const c = new Rgba(1, 0, 0, 0.5);
      expect(sparkFormatHex(c, true)).assertEqual('#ff000080');
      expect(sparkFormatHex(c, false)).assertEqual('#ff0000');
      expect(sparkFormatHex(new Rgba(1, 0, 0, 1), true)).assertEqual('#ff0000');
      expect(sparkFormatHex(new Rgba(2, -1, 0.5, 1), false)).assertEqual('#ff0080');
    });

    it('parse_any_css_colour', 0, () => {
      expect(hex(sparkParseColor('rgb(59 130 246)'))).assertEqual('#3b82f6');
      expect(hex(sparkParseColor('rgb(255 0 0 / 0.5)'))).assertEqual('#ff000080');
      expect(hex(sparkParseColor('hsl(0 100% 50%)'))).assertEqual('#ff0000');
      expect(hex(sparkParseColor('oklch(1 0 0)'))).assertEqual('#ffffff');
      expect(hex(sparkParseColor('white'))).assertEqual('#ffffff');
      expect(sparkParseColor('nope') === undefined).assertTrue();
      expect(sparkParseColor('#12') === undefined).assertTrue();
      expect(sparkParseColor('') === undefined).assertTrue();
    });

    it('format_functions', 0, () => {
      const blue = sparkParseHex('#3b82f6') as Rgba;
      expect(sparkFormatColor(blue, 'hex', false)).assertEqual('#3b82f6');
      expect(sparkFormatColor(blue, 'rgb', false)).assertEqual('rgb(59 130 246)');
      expect(sparkFormatColor(blue, 'hsl', false)).assertEqual('hsl(217 91% 60%)');
      expect(sparkFormatColor(blue, 'oklch', false).startsWith('oklch(0.623 0.188 259.8')).assertTrue();
      const half = new Rgba(1, 0, 0, 0.5);
      expect(sparkFormatColor(half, 'rgb', true)).assertEqual('rgb(255 0 0 / 0.5)');
      expect(sparkFormatColor(half, 'rgb', false)).assertEqual('rgb(255 0 0)');
      expect(sparkFormatColor(half, 'hsl', true)).assertEqual('hsl(0 100% 50% / 0.5)');
      // every format parses back to the same colour
      const formats: string[] = [sparkFormatColor(blue, 'rgb', false), sparkFormatColor(blue, 'hsl', false),
        sparkFormatColor(blue, 'oklch', false)];
      formats.forEach((f: string) => {
        const back = sparkParseColor(f) as Rgba;
        expect(Math.abs(back.r * 255 - 59) < 2.5 && Math.abs(back.g * 255 - 130) < 2.5 &&
          Math.abs(back.b * 255 - 246) < 2.5).assertTrue();
      });
    });

    it('hsl_conversion', 0, () => {
      const hsl = sparkRgbToHsl(new Rgba(0, 0.5, 0.5, 1));
      expect(Math.round(hsl[0])).assertEqual(180);
      expect(near(hsl[1], 1)).assertTrue();
      expect(near(hsl[2], 0.25)).assertTrue();
      expect(sparkRgbToHsl(new Rgba(0.5, 0.5, 0.5, 1))[1]).assertEqual(0);
    });

    it('hsva_helpers', 0, () => {
      const c = new SparkHsva(0, 1, 1, 0.5);
      expect(sparkFormatHsva(c, 'hex', true)).assertEqual('#ff000080');
      expect(sparkFormatHsva(c, 'hex', false)).assertEqual('#ff0000');
      expect(sparkHsvaToArgb(c, true)).assertEqual('#80FF0000');
      expect(sparkHsvaToArgb(c, false)).assertEqual('#FFFF0000');
      expect(sparkColorValueToArgb('#3b82f680', '')).assertEqual('#803B82F6');
      expect(sparkColorValueToArgb('nope', '#00000000')).assertEqual('#00000000');
      expect(SparkColor.parse('#3b82f680').value).assertEqual(sparkColorValueToArgb('#3b82f680', ''));
    });

    it('same_colour_and_numbers', 0, () => {
      expect(sparkSameColor('#ff0000', 'rgb(255 0 0)')).assertTrue();
      expect(sparkSameColor('#FF0000', '#ff0000')).assertTrue();
      expect(sparkSameColor('#ff0000', '#fe0000')).assertFalse();
      expect(sparkSameColor('nope', 'nope2')).assertFalse();
      expect(sparkColorNum(0.5, 2)).assertEqual('0.5');
      expect(sparkColorNum(259.81, 1)).assertEqual('259.8');
      expect(sparkColorNum(-0.0001, 2)).assertEqual('0');
      expect(sparkColorNum(Infinity, 2)).assertEqual('0');
    });

    it('formats_cycle', 0, () => {
      expect(sparkNextColorFormat('hex')).assertEqual('rgb');
      expect(sparkNextColorFormat('rgb')).assertEqual('hsl');
      expect(sparkNextColorFormat('hsl')).assertEqual('oklch');
      expect(sparkNextColorFormat('oklch')).assertEqual('hex');
      expect(sparkColorFormatLabel('oklch')).assertEqual('OKLCH');
    });

    it('recent_list', 0, () => {
      let r: string[] = [];
      r = sparkPushRecent(r, '#ff0000', 3);
      r = sparkPushRecent(r, '#00ff00', 3);
      r = sparkPushRecent(r, 'rgb(255 0 0)', 3); // same colour as #ff0000: moves to the front
      expect(r.join(',')).assertEqual('rgb(255 0 0),#00ff00');
      r = sparkPushRecent(r, '#0000ff', 3);
      r = sparkPushRecent(r, '#ffffff', 3);
      expect(r.join(',')).assertEqual('#ffffff,#0000ff,rgb(255 0 0)');
      expect(sparkPushRecent(r, 'nope', 3).length).assertEqual(3);
      expect(sparkPushRecent(r, '#000', 0).length).assertEqual(0);
    });

    it('geometry', 0, () => {
      expect(sparkTrackRatio(8, 216, 16)).assertEqual(0);
      expect(sparkTrackRatio(208, 216, 16)).assertEqual(1);
      expect(sparkTrackRatio(108, 216, 16)).assertEqual(0.5);
      expect(sparkTrackRatio(-50, 216, 16)).assertEqual(0);
      expect(sparkTrackRatio(10, 10, 16)).assertEqual(0);
      const sv = sparkAreaToSv(60, 40, 240, 160);
      expect(sv[0]).assertEqual(0.25);
      expect(sv[1]).assertEqual(0.75);
      expect(sparkAreaToSv(-5, 500, 240, 160).join(',')).assertEqual('0,0');
      expect(sparkAreaToSv(5, 5, 0, 0).join(',')).assertEqual('0,0');
      const stops = sparkHueStops();
      expect(stops.length).assertEqual(7);
      expect(stops[0]).assertEqual('#FFFF0000');
      expect(stops[2]).assertEqual('#FF00FF00');
      expect(stops[6]).assertEqual('#FFFF0000');
    });
  });
}
