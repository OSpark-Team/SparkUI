import { describe, it, expect } from '@ohos/hypium';
import { ThemeCssParser } from '../main/ets/theme/css/ThemeCssParser';
import { ThemeResolver } from '../main/ets/theme/css/ThemeResolver';
import { ThemeDiagnostic, ThemeSource } from '../main/ets/theme/css/ThemeSource';
import { presetCss, SPARK_PRESETS } from '../main/ets/theme/presets/Presets';
import { SparkTheme } from '../main/ets/theme/tokens/SparkTheme';
import { SparkComponentTokenRegistry } from '../main/ets/theme/tokens/SparkComponentTokens';
import {
  sparkOptionPanel, sparkSurface, sparkSurfaceDefaults, SparkTokenReader
} from '../main/ets/theme/tokens/SparkTokenReader';
import { SparkColor } from '../main/ets/theme/color/SparkColor';
import { ThemeValues } from '../main/ets/theme/css/ThemeValues';
import { ButtonVariants } from '../main/ets/components/button/ButtonVariants';
import { CardVariants } from '../main/ets/components/card/SCard';
import { SparkTones } from '../main/ets/core/SparkTone';
import {
  sparkCaptionPlate, sparkListDetailStyle, sparkListWidth, sparkShellMaxWidth, sparkShellPadding, sparkSidebarRailWidth,
  sparkSidebarStyle, sparkSidebarWidth, sparkSupportingPaneStyle, sparkTitleBarStyle, sparkTopbarStyle
} from '../main/ets/blocks/BlockTokens';
import { sparkSidebarRowWidth } from '../main/ets/blocks/BlocksLogic';
import { sparkColorPickerStyle } from '../main/ets/components/color-picker/ColorPickerStyle';

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

  describe('ThemeTokens', () => {
    it('status_tokens_in_presets', 0, () => {
      SPARK_PRESETS.forEach((name: string) => {
        const src = ThemeCssParser.parse(presetCss(name) as string);
        const light = new SparkTheme();
        ThemeResolver.apply(src, false, 'compact', light);
        const dark = new SparkTheme();
        ThemeResolver.apply(src, true, 'compact', dark);
        expect(SparkColor.fromArgbHex(light.colors.success).g > 0.5).assertTrue();
        expect(light.colors.warningForeground).assertEqual(dark.colors.warningForeground);
        expect(light.colors.info !== dark.colors.info).assertTrue();
        expect(SparkTones.resolve(dark, 'success').solid).assertEqual(dark.colors.success);
        expect(SparkTones.resolve(light, 'warning').onSolid).assertEqual(light.colors.warningForeground);
      });
    });

    it('status_tokens_fallback_for_shadcn_exports', 0, () => {
      // the controller layers a tweakcn export over the preset: tokens it omits keep the preset value
      const preset = ThemeCssParser.parse(presetCss('neutral') as string);
      const base = new SparkTheme();
      ThemeResolver.apply(preset, false, 'compact', base);
      const t = new SparkTheme();
      ThemeResolver.apply(preset.merge(ThemeCssParser.parse(SHADCN_EXPORT)), false, 'compact', t);
      expect(t.colors.primary).assertEqual('#FF171717');
      expect(t.colors.success).assertEqual(base.colors.success);
      const custom = new SparkTheme();
      ThemeResolver.apply(preset.merge(ThemeCssParser.parse(':root { --success: #16a34a; }')), false, 'compact',
        custom);
      expect(custom.colors.success).assertEqual('#FF16A34A');
    });

    it('component_tokens_resolve', 0, () => {
      const css = [':root {', '--radius: 0.625rem;', '--muted: #f5f5f5;', '--card-background: transparent;',
        '--card-border-width: 0;', '--button-radius: calc(var(--radius) - 2px);', '--popover-shadow: none;',
        '--dialog-overlay: oklch(0 0 0 / 30%);', '--input-background: var(--muted);',
        '--button-outline-border-color: color-mix(in oklab, #ff0000 50%, transparent);',
        '--tabs-indicator-shadow: 0 2px 4px rgb(0 0 0 / 0.2);', '--badge-font-weight: 600;',
        '--border-width: 2px;', '}', '.dark {', '--card-background: #111;', '}'];
      const src = ThemeCssParser.parse(css.join('\n'));
      const t = new SparkTheme();
      const diags = ThemeResolver.apply(src, false, 'compact', t);
      expect(diags.length).assertEqual(0);
      expect(t.comp.color('card', 'background', '#FFFFFFFF')).assertEqual('#00000000');
      expect(t.comp.length('card', 'border-width', 1)).assertEqual(0);
      expect(t.comp.length('button', 'radius', 0)).assertEqual(8);
      expect(t.comp.shadow('popover', 'shadow', undefined)?.isNone).assertTrue();
      expect(t.comp.color('dialog', 'overlay', '')).assertEqual('#4D000000');
      expect(t.comp.color('input', 'background', '')).assertEqual('#FFF5F5F5');
      expect(t.comp.color('button', 'outline-border-color', '')).assertEqual('#80FF0000');
      expect(t.comp.shadow('tabs', 'indicator-shadow', undefined)?.offsetY).assertEqual(2);
      expect(t.comp.number('badge', 'font-weight', 500)).assertEqual(600);
      expect(t.borderWidth).assertEqual(2);
      // unset tokens fall back
      expect(t.comp.color('card', 'border-color', '#FF123456')).assertEqual('#FF123456');
      expect(t.comp.has('menu', 'radius')).assertFalse();
      const dark = new SparkTheme();
      ThemeResolver.apply(src, true, 'compact', dark);
      expect(dark.comp.color('card', 'background', '')).assertEqual('#FF111111');
    });

    it('component_token_diagnostics', 0, () => {
      const t = new SparkTheme();
      const src = ThemeCssParser.parse(':root {\n --card-radius: red;\n --card-glow: 4px;\n --button-shadow: wobbly;\n' +
        ' --card-background: notacolor;\n --tabs-height: var(--missing);\n}');
      const diags = ThemeResolver.apply(src, false, 'compact', t);
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--card-radius' && d.severity === 'error' && d.line === 2))
        .assertTrue();
      expect(t.comp.has('card', 'radius')).assertFalse();
      // unknown property of a known component: warning, but stored and readable
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--card-glow' && d.severity === 'warning')).assertTrue();
      expect(t.comp.length('card', 'glow', 0)).assertEqual(4);
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--button-shadow' && d.severity === 'error')).assertTrue();
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--card-background' && d.severity === 'error'))
        .assertTrue();
      expect(diags.some((d: ThemeDiagnostic) => d.variable === '--tabs-height' && d.severity === 'error')).assertTrue();
      expect(SparkComponentTokenRegistry.match('toggle-group-indicator-background')?.component)
        .assertEqual('toggle-group');
      expect(SparkComponentTokenRegistry.match('code-keyword')?.kind).assertEqual('color');
      // `sidebar` is a component now, but `--sidebar-accent` is not one of its tokens (it stays semantic)
      expect(SparkComponentTokenRegistry.match('sidebar-accent')?.kind).assertUndefined();
      expect(SparkComponentTokenRegistry.match('sidebar-menu-radius')?.kind).assertEqual('length');
      // semantic tokens keep precedence over component prefixes
      const s = new SparkTheme();
      const d2 = ThemeResolver.apply(ThemeCssParser.parse(':root { --card-foreground: #123456; }'), false, 'compact', s);
      expect(d2.length).assertEqual(0);
      expect(s.colors.cardForeground).assertEqual('#FF123456');
    });

    it('values_and_var_fallbacks', 0, () => {
      expect(ThemeValues.len('calc(0.625rem + 4px)')).assertEqual(14);
      expect(ThemeValues.len('calc((10px - 2px) * 2)')).assertEqual(16);
      expect(isNaN(ThemeValues.len('calc(1fr)'))).assertTrue();
      expect(ThemeValues.len('none')).assertEqual(0);
      expect(ThemeValues.num('50%')).assertEqual(0.5);
      expect(SparkColor.parse('color-mix(in srgb, #000 25%, #fff)').value).assertEqual('#FFBFBFBF');
      expect(SparkColor.parse('color-mix(in oklab, #ff0000 10%, transparent)').value).assertEqual('#1AFF0000');
      expect(SparkColor.parse('color-mix(in srgb, red)').ok).assertFalse();
      const t = new SparkTheme();
      ThemeResolver.apply(ThemeCssParser.parse(':root { --card-background: var(--nope, oklch(1 0 0 / 50%)); }'), false,
        'compact', t);
      expect(t.comp.color('card', 'background', '')).assertEqual('#80FFFFFF');
    });

    it('version_bumps_only_on_change', 0, () => {
      const a = new SparkTheme();
      ThemeResolver.apply(ThemeCssParser.parse(':root { --card-radius: 4px; }'), false, 'compact', a);
      const live = new SparkTheme();
      live.copyFrom(a);
      const v = live.comp.version;
      expect(live.comp.length('card', 'radius', 0)).assertEqual(4);
      live.copyFrom(a);
      expect(live.comp.version).assertEqual(v);
      live.copyFrom(new SparkTheme());
      expect(live.comp.version > v).assertTrue();
      expect(live.comp.has('card', 'radius')).assertFalse();
    });

    it('cascade_instance_theme_recipe', 0, () => {
      const t = new SparkTheme();
      const plain = ButtonVariants.resolve(t, 'default', 'default');
      expect(plain.radius).assertEqual(t.radiusMd);
      expect(plain.background).assertEqual(t.colors.primary);
      ThemeResolver.apply(ThemeCssParser.parse(':root { --button-radius: 999px; --button-height-sm: 28px; ' +
        '--button-background: #0ea5e9; --card-ghost-background: #eee; }'), false, 'compact', t);
      const themed = ButtonVariants.resolve(t, 'default', 'sm');
      expect(themed.radius).assertEqual(999);
      expect(themed.height).assertEqual(28);
      expect(themed.background).assertEqual('#FF0EA5E9');
      expect(themed.hoverBackground).assertEqual(SparkColor.alpha('#FF0EA5E9', 0.9));
      const inst = ButtonVariants.resolve(t, 'default', 'sm', { radius: 0, background: 'transparent' });
      expect(inst.radius).assertEqual(0);
      expect(inst.background).assertEqual('#00000000');
      // only the default variant reads --button-background
      expect(ButtonVariants.resolve(t, 'outline', 'default').background).assertEqual(t.colors.background);
      expect(ButtonVariants.resolve(t, 'outline', 'default').borderWidth).assertEqual(1);
      expect(CardVariants.resolve(t, 'ghost').background).assertEqual('#FFEEEEEE');
      expect(CardVariants.resolve(t, 'default', { borderWidth: 0 }).borderWidth).assertEqual(0);
      const r = new SparkTokenReader(t, 'button');
      expect(r.len(['height-lg', 'height-sm'], undefined, 1)).assertEqual(28);
      expect(r.color('nope', 'not a colour', '#FF000000')).assertEqual('#FF000000');
    });

    it('option_panel_tokens_select_combobox', 0, () => {
      expect(SparkComponentTokenRegistry.kindOf('select', 'highlight-background')).assertEqual('color');
      expect(SparkComponentTokenRegistry.kindOf('select', 'max-height')).assertEqual('length');
      expect(SparkComponentTokenRegistry.kindOf('combobox', 'shadow')).assertEqual('shadow');
      expect(SparkComponentTokenRegistry.match('combobox-border-width')?.component).assertEqual('combobox');
      const t = new SparkTheme();
      const defaults = sparkSurfaceDefaults(t.colors.popover, t.colors.border, t.borderWidth, t.radiusMd, 4,
        t.shadows.md);
      // unset: the recipe
      const plain = sparkOptionPanel(t, 'select', 'menu', defaults, 320);
      expect(plain.background).assertEqual(t.colors.popover);
      expect(plain.highlightBackground).assertEqual(t.colors.accent);
      expect(plain.highlightForeground).assertEqual(t.colors.accentForeground);
      expect(plain.maxHeight).assertEqual(320);
      expect(plain.padding).assertEqual(4);
      const diags = ThemeResolver.apply(ThemeCssParser.parse(':root { --menu-background: #111111; ' +
        '--menu-radius: 2px; --select-radius: 12px; --select-highlight-background: #e0f2fe; ' +
        '--select-max-height: 200px; --popover-border-color: #ff0000; --combobox-shadow: none; }'), false,
        'compact', t);
      expect(diags.length).assertEqual(0);
      const sel = sparkOptionPanel(t, 'select', 'menu', defaults, 320);
      expect(sel.background).assertEqual('#FF111111'); // inherited from --menu-*
      expect(sel.radius).assertEqual(12); // --select-* beats --menu-*
      expect(sel.highlightBackground).assertEqual('#FFE0F2FE');
      expect(sel.maxHeight).assertEqual(200);
      const combo = sparkOptionPanel(t, 'combobox', 'popover', defaults, 300);
      expect(combo.borderColor).assertEqual('#FFFF0000'); // inherited from --popover-*
      expect(combo.background).assertEqual(t.colors.popover); // --menu-* does not leak into combobox
      expect(combo.shadow?.isNone).assertTrue();
      expect(combo.highlightBackground).assertEqual(t.colors.accent);
      // instance tokens win over both
      const inst = sparkOptionPanel(t, 'select', 'menu', defaults, 320,
        { background: 'transparent', radius: 0, highlightBackground: '#000', maxHeight: 99 });
      expect(inst.background).assertEqual('#00000000');
      expect(inst.radius).assertEqual(0);
      expect(inst.highlightBackground).assertEqual('#FF000000');
      expect(inst.maxHeight).assertEqual(99);
      // the shared surface helper honours the family too
      expect(sparkSurface(t, 'select', defaults, undefined, 'menu').background).assertEqual('#FF111111');
      expect(sparkSurface(t, 'select', defaults).background).assertEqual(t.colors.popover);
    });

    it('color_picker_tokens', 0, () => {
      expect(SparkComponentTokenRegistry.kindOf('color-picker', 'checker-dark')).assertEqual('color');
      expect(SparkComponentTokenRegistry.kindOf('color-picker', 'area-height')).assertEqual('length');
      expect(SparkComponentTokenRegistry.kindOf('color-picker', 'thumb-shadow')).assertEqual('shadow');
      // longest prefix: color-picker-…, not a semantic token
      expect(SparkComponentTokenRegistry.match('color-picker-swatch-size')?.component).assertEqual('color-picker');
      expect(SparkComponentTokenRegistry.match('color-picker-swatch-size')?.property).assertEqual('swatch-size');
      const t = new SparkTheme();
      const plain = sparkColorPickerStyle(t);
      expect(plain.borderColor).assertEqual(t.colors.border);
      expect(plain.checkerLight).assertEqual(t.colors.background);
      expect(plain.width).assertEqual(240);
      expect(plain.areaHeight).assertEqual(160);
      expect(plain.radius).assertEqual(t.radiusMd);
      expect(plain.swatchRadius).assertEqual(t.radiusSm);
      expect(plain.thumbBorderColor).assertEqual('#FFFFFFFF');
      const diags = ThemeResolver.apply(ThemeCssParser.parse(':root { --color-picker-area-height: 200px; ' +
        '--color-picker-radius: 0; --color-picker-checker-dark: #cccccc; --color-picker-thumb-shadow: none; ' +
        '--color-picker-swatch-size: 1.5rem; }'), false, 'compact', t);
      expect(diags.length).assertEqual(0);
      const s = sparkColorPickerStyle(t);
      expect(s.areaHeight).assertEqual(200);
      expect(s.radius).assertEqual(0);
      expect(s.checkerDark).assertEqual('#FFCCCCCC');
      expect(s.thumbShadow?.isNone).assertTrue();
      expect(s.swatchSize).assertEqual(24);
      // instance tokens win
      const inst = sparkColorPickerStyle(t, { areaHeight: 120, checkerDark: 'transparent', width: 300 });
      expect(inst.areaHeight).assertEqual(120);
      expect(inst.checkerDark).assertEqual('#00000000');
      expect(inst.width).assertEqual(300);
      // a wrongly typed value is an error and keeps the recipe
      const bad = ThemeResolver.apply(ThemeCssParser.parse(':root { --color-picker-border-color: 12px; }'), false,
        'compact', new SparkTheme());
      expect(bad.length > 0).assertTrue();
    });

    it('block_tokens', 0, () => {
      const t = new SparkTheme();
      ThemeResolver.apply(ThemeCssParser.parse(presetCss('neutral') as string), false, 'compact', t);
      // no tokens: the shadcn recipe (semantic --sidebar-* values)
      const plain = sparkSidebarStyle(t);
      expect(plain.background).assertEqual(t.colors.sidebar);
      expect(plain.menuActiveBackground).assertEqual(t.colors.sidebarAccent);
      expect(plain.menuRadius).assertEqual(t.radiusMd);
      expect(plain.menuHeight).assertEqual(32);
      expect(plain.groupLabelColor).assertEqual(SparkColor.alpha(t.colors.sidebarForeground, 0.7));
      expect(sparkSidebarWidth(t, 0)).assertEqual(256);
      expect(sparkTopbarStyle(t).height).assertEqual(56);
      expect(sparkTitleBarStyle(t).closeHoverBackground).assertEqual(t.colors.destructive);
      expect(sparkCaptionPlate(sparkTitleBarStyle(t), 40)).assertEqual(28);
      expect(sparkShellMaxWidth(t, undefined)).assertEqual(1200);
      expect(sparkShellPadding(t, 24)).assertEqual(24);

      const sidebarBefore = t.colors.sidebar;
      const diags = ThemeResolver.apply(ThemeCssParser.parse(':root { --sidebar-background: transparent; ' +
        '--sidebar-width: 18rem; --sidebar-width-icon: 56px; --sidebar-menu-radius: 999px; ' +
        '--sidebar-menu-pressed-opacity: 50%; --sidebar-inset-shadow: none; --topbar-height: 64px; ' +
        '--titlebar-close-hover-background: #ff0000; --titlebar-caption-size: 30px; ' +
        '--app-shell-content-max-width: 960px; --list-detail-list-width: 280px; --supporting-pane-divider-color: ' +
        'transparent; --drawer-handle-background: #00ff00; --sidebar-accent: #123456; }'), false, 'compact', t);
      expect(diags.length).assertEqual(0);
      // semantic --sidebar-* tokens keep working next to the component ones
      expect(t.colors.sidebarAccent).assertEqual('#FF123456');
      const s = sparkSidebarStyle(t);
      expect(s.background).assertEqual('#00000000');
      expect(t.colors.sidebar).assertEqual(sidebarBefore);
      expect(s.menuRadius).assertEqual(999);
      expect(s.menuPressedOpacity).assertEqual(0.5);
      expect(s.menuActiveBackground).assertEqual('#FF123456');
      expect(s.insetShadow?.isNone).assertTrue();
      expect(sparkSidebarWidth(t, 0)).assertEqual(288);
      expect(sparkSidebarWidth(t, 200)).assertEqual(200);
      expect(sparkSidebarRailWidth(t, 0)).assertEqual(56);
      expect(sparkSidebarRowWidth('rail', true, 'icon', 'inset', 288, 56, s.frameGap)).assertEqual(72);
      // instance tokens beat theme tokens
      expect(sparkSidebarStyle(t, { background: '#ffffff', menuHeight: 40 }).background).assertEqual('#FFFFFFFF');
      expect(sparkSidebarStyle(t, { menuHeight: 40 }).menuHeight).assertEqual(40);
      expect(sparkTopbarStyle(t).height).assertEqual(64);
      expect(sparkTopbarStyle(t, { height: 52 }).height).assertEqual(52);
      const tb = sparkTitleBarStyle(t);
      expect(tb.closeHoverBackground).assertEqual('#FFFF0000');
      expect(tb.closePressedBackground).assertEqual(SparkColor.alpha('#FFFF0000', 0.85));
      expect(sparkCaptionPlate(tb, 40)).assertEqual(30);
      expect(sparkShellMaxWidth(t, undefined)).assertEqual(960);
      expect(sparkShellMaxWidth(t, 0)).assertEqual(0);
      expect(sparkListWidth(t, 0)).assertEqual(280);
      expect(sparkListDetailStyle(t).dividerColor).assertEqual(t.colors.border);
      expect(sparkSupportingPaneStyle(t).dividerColor).assertEqual('#00000000');
      expect(t.comp.color('drawer', 'handle-background', '')).assertEqual('#FF00FF00');
    });
  });
}
