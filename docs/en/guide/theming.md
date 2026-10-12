# Theming

<p class="doc-lead">Every colour, radius, spacing and shadow comes from tokens. Pick a base gray, an accent colour and a radius — every component, native ArkUI ones included, updates live.</p>

## Presets and accents

Built-in presets match shadcn v4 base colours: `neutral` (default), `zinc`, `slate`, `stone`, `gray`. Accents are layered on top and only recolour primary / ring / sidebar-primary: `blue`, `green`, `orange`, `red`, `rose`, `violet`, `yellow`.

```arkts
SparkUI.themes.usePreset('zinc');      // base gray (keeps accent and overrides such as radius)
SparkUI.themes.useAccent('violet');    // accent; 'none' = monochrome shadcn default
SparkUI.themes.setMode('dark');        // 'light' | 'dark' | 'system'
SparkUI.themes.toggleDark();
SparkUI.themes.setVariable('--radius', '0.75rem');
```

Try it in the web preview (the picker applies to every preview on the site; values are generated from `Presets.ets`):

<ArkThemePicker />

```arkts preview
Column({ space: 12 }) {
  Text('Create an account').fontSize(18).fontWeight(600)
  Text('Enter your email below to create your account.')
    .fontSize(14).fontColor(this.theme.colors.mutedForeground)
  SInput({ placeholder: 'm@example.com', icon: 'mail' })
  SSwitch({ label: 'Native Toggle follows the accent', defaultChecked: true })
  Row({ space: 8 }) {
    SButton({ text: 'Create account' })
    SButton({ text: 'Cancel', variant: 'outline' })
    SButton({ variant: 'secondary', sizing: 'icon', icon: 'share-2', label: 'Share' })
  }
}
.width(340)
.alignItems(HorizontalAlign.Start)
```

Base grays only shift the hue of neutrals (backgrounds, borders, muted text) — subtle by design, exactly like shadcn. Accent colours change primary and ring.

## Loading shadcn / tweakcn themes

A SparkUI theme file is a CSS subset: `:root {}`, `.dark {}`, `@size(compact|medium|expanded|large) {}`, `--var: value;` and comments. shadcn / tweakcn exports paste as-is: `@theme`, `@layer`, `@import`, `@custom-variant`, other selectors and non-custom properties are recognised and skipped with an `info` diagnostic. oklch, hsl, rgb and hex are converted precisely.

```css [theme.css]
:root {
  --radius: 0.5rem;
  --primary: oklch(0.546 0.245 262.881);
  --primary-foreground: oklch(0.97 0.014 254.604);
}
.dark {
  --primary: oklch(0.623 0.214 259.815);
}
@size(compact) {
  :root { --radius: 0.375rem; }
}
```

```arkts
const r1 = SparkUI.themes.loadString(cssText);                 // CSS subset or JSON (auto-detected)
const r2 = SparkUI.themes.loadRawfile('themes/brand.css');      // resources/rawfile
const r3 = SparkUI.themes.loadFile(sandboxPath);
const r4 = await SparkUI.themes.loadUrl('https://…/theme.css'); // needs ohos.permission.INTERNET
if (!r1.ok) {
  r1.diagnostics.forEach((d: ThemeDiagnostic) => console.warn(d.message));
}
SparkUI.themes.exportCss();   // the effective theme (preset + overrides)
```

Loading never throws: missing or invalid tokens fall back to the underlying preset and problems come back as diagnostics (`error` / `warning` / `info`).

## Status colours and component tokens

- Status colours are real semantic tokens: `--success`, `--warning`, `--info` and their `-foreground`.
- The global knob `--border-width` controls the border of every bordered component.
- Component tokens are named `--<component>-<property>`: `--card-background`, `--button-radius`, `--button-outline-background`, `--button-height-sm`… Unset tokens fall back to the component's shadcn recipe.
- Override a single instance with the `tokens` param:

```arkts preview
SButton({ text: 'Pill', tokens: { radius: 999 } })
SButton({ text: 'Custom', tokens: { background: 'oklch(0.6 0.2 250)', foreground: '#ffffff' } })
```

- Theme-wide, set them like any other variable (`setVariable`, or a `theme.css` loaded with `loadString`). Status badges and alerts read the semantic status tokens:

```arkts preview
Column({ space: 12 }) {
  Row({ space: 8 }) {
    SButton({ text: 'Soft theme', variant: 'outline', sizing: 'sm' })
      .onClick(() => SparkUI.themes.loadString(`:root {
        --card-radius: 24px; --card-background: color-mix(in oklab, var(--primary) 4%, var(--background));
        --button-radius: 999px; --badge-radius: 999px; --border-width: 0px; --card-shadow: none;
      }`))
    SButton({ text: 'Reset', variant: 'ghost', sizing: 'sm' }).onClick(() => SparkUI.themes.resetOverrides())
  }
  SCard() {
    SCardHeader() {
      SCardTitle({ text: 'Deployment' })
      SCardDescription({ text: 'Reads --card-* and --button-* tokens' })
    }
    SCardContent() {
      Row({ space: 8 }) {
        SBadge({ text: 'Live', variant: 'success' })
        SBadge({ text: 'Degraded', variant: 'warning' })
        SBadge({ text: 'Info', variant: 'info' })
      }
    }
    SCardFooter() {
      SButton({ text: 'Redeploy' })
      SButton({ text: 'Logs', variant: 'outline' })
    }
  }
  .width(340)
}
```

## Native components

`SparkProvider` mirrors the tokens into the system theme (`WithTheme` / `ThemeControl`), so native `Toggle`, `TextInput` & co. follow the accent and the colour mode too.
