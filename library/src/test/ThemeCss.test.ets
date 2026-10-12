import { describe, it, expect } from '@ohos/hypium';
import { ThemeCssParser } from '../main/ets/theme/css/ThemeCssParser';
import { ThemeResolver } from '../main/ets/theme/css/ThemeResolver';
import { ThemeDiagnostic, ThemeSource } from '../main/ets/theme/css/ThemeSource';
import { presetCss, SPARK_PRESETS } from '../main/ets/theme/presets/Presets';
import { SparkTheme } from '../main/ets/theme/tokens/SparkTheme';

const SHADCN_EXPORT = `
@import "tailwindcss";
@custom-variant dark (&:is(.dark *));

:root {
  --radius: 0.625rem;
  --background: oklch(1 0 0); /* page */
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --shadow-sm: 0 1px 3px 0px hsl(0 0% 0% / 0.10), 0 1px 2px -1px hsl(0 0% 0% / 0.10);
  --font-sans: Inter, sans-serif;
}

.dark {
  --background: oklch(0.145 0 0);
  --primary: oklch(0.922 0 0);
}

@theme inline {
  --color-background: var(--background);
}

@layer base {
  * { border-color: var(--border); }
  body { background: var(--background); }
}

@size(compact) { --spacing: 0.22rem; }
@size(large)   { --spacing: 0.28rem; }
`;

function count(diags: ThemeDiagnostic[], severity: string): number {
  return diags.filter((d: ThemeDiagnostic) => d.severity === severity).length;
}

export default function themeCssTest() {
  describe('ThemeCssParser', () => {
    it('parses_shadcn_export', 0, () => {
      const src = ThemeCssParser.parse(SHADCN_EXPORT);
      expect(count(src.diagnostics, 'error')).assertEqual(0);
      expect(src.root.get('--radius')?.value).assertEqual('0.625rem');
      expect(src.root.get('--background')?.value).assertEqual('oklch(1 0 0)');
      expect(src.root.get('--background')?.line).assertEqual(7);
      expect(src.dark.get('--primary')?.value).assertEqual('oklch(0.922 0 0)');
      expect(src.sizes.get('compact')?.get('--spacing')?.value).assertEqual('0.22rem');
      expect(src.sizes.get('large')?.get('--spacing')?.value).assertEqual('0.28rem');
      // @theme / @import / @custom-variant / selector rules are skipped with info diagnostics
      expect(count(src.diagnostics, 'info') >= 3).assertTrue();
      expect(src.root.has('--color-background')).assertFalse();
    });

    it('reports_structural_errors_with_lines', 0, () => {
      const src = ThemeCssParser.parse(':root {\n  --a: red;\n  --b:;\n  oops\n}\n@size(huge) { --spacing: 1px; }\n.dark {');
      const errors = src.diagnostics.filter((d: ThemeDiagnostic) => d.severity === 'error');
      expect(errors.some((d: ThemeDiagnostic) => d.variable === '--b' && d.line === 3)).assertTrue();
      expect(errors.some((d: ThemeDiagnostic) => d.message.indexOf('@size') >= 0 && d.line === 6)).assertTrue();
      expect(errors.some((d: ThemeDiagnostic) => d.message.indexOf('missing "}"') >= 0)).assertTrue();
      expect(src.root.get('--a')?.value).assertEqual('red');
    });

    it('never_throws_on_garbage', 0, () => {
      const inputs = ['', '}}}{{{', ':root { --x: oklch(; }', '/* unterminated', '@size(', '"', ';;;'];
      inputs.forEach((s: string) => {
        const src = ThemeCssParser.parse(s);
        expect(src instanceof ThemeSource).assertTrue();
      });
    });

    it('media_dark_maps_to_dark', 0, () => {
      const src = ThemeCssParser.parse('@media (prefers-color-scheme: dark) { :root { --background: #000; } }');
      expect(src.dark.get('--background')?.value).assertEqual('#000');
    });

    it('json_format', 0, () => {
      const src = ThemeCssParser.parseJson(
        '{"root":{"--primary":"#ff0000","radius":"0.5rem"},"dark":{"--primary":"#00ff00"},"sizes":{"compact":{"--spacing":"3px"}}}');
      expect(count(src.diagnostics, 'error')).assertEqual(0);
      expect(src.root.get('--radius')?.value).assertEqual('0.5rem');
      expect(src.sizes.get('compact')?.get('--spacing')?.value).assertEqual('3px');
      expect(ThemeCssParser.parseJson('{bad').diagnostics.length).assertEqual(1);
    });

    it('round_trip_css_and_json', 0, () => {
      const src = ThemeCssParser.parse(SHADCN_EXPORT);
      const again = ThemeCssParser.parse(src.toCss());
      expect(again.root.get('--primary')?.value).assertEqual('oklch(0.205 0 0)');
      expect(again.sizes.get('large')?.get('--spacing')?.value).assertEqual('0.28rem');
      const fromJson = ThemeCssParser.parseJson(src.toJson());
      expect(fromJson.dark.get('--background')?.value).assertEqual('oklch(0.145 0 0)');
    });
  });

  describe('ThemeResolver', () => {
    it('cascade_root_size_dark', 0, () => {
      const src = ThemeCssParser.parse(SHADCN_EXPORT);
      const light = new SparkTheme();
      ThemeResolver.apply(src, false, 'compact', light);
      expect(light.colors.background).assertEqual('#FFFFFFFF');
      expect(light.colors.primary).assertEqual('#FF171717');
      expect(light.radius).assertEqual(10);
      expect(Math.abs(light.spacing - 3.52) < 0.001).assertTrue();
      expect(light.shadows.sm.offsetY).assertEqual(1);
      expect(light.shadows.sm.radius).assertEqual(3);
      expect(light.shadows.sm.color).assertEqual('#1A000000');

      const dark = new SparkTheme();
      ThemeResolver.apply(src, true, 'medium', dark);
      expect(dark.isDark).assertTrue();
      expect(dark.colors.background).assertEqual('#FF0A0A0A');
      expect(dark.colors.primary).assertEqual('#FFE5E5E5');
      expect(dark.spacing).assertEqual(4); // no @size(medium) block → default
    });

    it('invalid_values_keep_defaults', 0, () => {
      const t = new SparkTheme();
      t.colors.primary = '#FF123456';
      const src = ThemeCssParser.parse(':root {\n --primary: notacolor;\n --radius: big;\n --unknown-x: 1;\n}');
      const diags = ThemeResolver.apply(src, false, 'compact', t);
      expect(t.colors.primary).assertEqual('#FF123456');
      expect(t.radius).assertEqual(10);
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--primary' && d.severity === 'error' && d.line === 2))
        .assertTrue();
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--radius' && d.severity === 'error')).assertTrue();
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--unknown-x' && d.severity === 'warning')).assertTrue();
    });

    it('var_references', 0, () => {
      const t = new SparkTheme();
      const src = ThemeCssParser.parse(':root { --brand: #ff0000; --primary: var(--brand); --ring: var(--nope, #00ff00); --accent: var(--loop); --loop: var(--accent); }');
      const diags = ThemeResolver.apply(src, false, 'compact', t);
      expect(t.colors.primary).assertEqual('#FFFF0000');
      expect(t.colors.ring).assertEqual('#FF00FF00');
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--accent' && d.severity === 'error')).assertTrue();
    });

    it('lengths_times_curves', 0, () => {
      expect(ThemeResolver.parseLength('0.625rem')).assertEqual(10);
      expect(ThemeResolver.parseLength('12px')).assertEqual(12);
      expect(ThemeResolver.parseLength('8vp')).assertEqual(8);
      expect(isNaN(ThemeResolver.parseLength('1fr'))).assertTrue();
      expect(ThemeResolver.parseTime('0.2s')).assertEqual(200);
      expect(ThemeResolver.parseTime('150ms')).assertEqual(150);
      const c = ThemeResolver.parseCubicBezier('cubic-bezier(0.4, 0, 0.2, 1)');
      expect(c !== undefined && c.length === 4 && c[2] === 0.2).assertTrue();
      expect(ThemeResolver.parseShadow('none')?.radius).assertEqual(0);
      expect(ThemeResolver.parseShadow('garbage')).assertUndefined();
    });

    it('motion_variables', 0, () => {
      const t = new SparkTheme();
      const css = [':root {', '--motion-enabled: true;', '--motion-accordion-duration: 320ms;',
        '--motion-accordion-ease: spring(0.45, 0.85);', '--motion-tooltip-enabled: false;',
        '--motion-tabs-ease: cubic-bezier(0.2, 0, 0, 1);', '--motion-bad-ease: wobbly;', '--motion-x: 1;', '}'];
      const src = ThemeCssParser.parse(css.join('\n'));
      const diags = ThemeResolver.apply(src, false, 'compact', t);
      expect(t.motion.enabled).assertTrue();
      expect(t.motion.overrides.get('accordion')?.duration).assertEqual(320);
      expect(t.motion.overrides.get('accordion')?.ease).assertEqual('spring(0.45, 0.85)');
      expect(t.motion.overrides.get('tooltip')?.enabled).assertFalse();
      expect(t.motion.overrides.get('tabs')?.ease).assertEqual('cubic-bezier(0.2, 0, 0, 1)');
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--motion-bad-ease' && d.severity === 'error'))
        .assertTrue();
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--motion-x' && d.severity === 'warning'))
        .assertTrue();
      const off = new SparkTheme();
      ThemeResolver.apply(ThemeCssParser.parse(':root { --motion-enabled: off; }'), false, 'compact', off);
      expect(off.motion.enabled).assertFalse();
      // copyFrom carries overrides (live theme refresh)
      const live = new SparkTheme();
      live.copyFrom(t);
      expect(live.motion.overrides.get('accordion')?.duration).assertEqual(320);
    });
    it('presets_resolve_without_errors', 0, () => {
      SPARK_PRESETS.forEach((name: string) => {
        const src = ThemeCssParser.parse(presetCss(name) as string);
        expect(src.diagnostics.length).assertEqual(0);
        const light = new SparkTheme();
        const dl = ThemeResolver.apply(src, false, 'compact', light);
        const dark = new SparkTheme();
        const dd = ThemeResolver.apply(src, true, 'compact', dark);
        expect(dl.length + dd.length).assertEqual(0);
        expect(light.colors.background).assertEqual('#FFFFFFFF');
        expect(dark.colors.border).assertEqual('#1AFFFFFF');
      });
    });
  });
}
