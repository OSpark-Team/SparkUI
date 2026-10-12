# Installation

## Install

In a HarmonyOS module (API 22, State Management V2):

```bash
ohpm install @sparkui/core
```

Inside this repository you can also depend on `library/` as a local HAR:

```json5
// entry/oh-package.json5
{
  "dependencies": {
    "@sparkui/core": "file:../library"
  }
}
```

## Wrap pages in SparkProvider

`SparkProvider` provides the theme (`sparkTheme`) and layout (`sparkLayout`) contexts, bridges tokens to native components and paints the `background` token. The root of an `@Entry` page must be a system container, so write `Stack() { SparkProvider() { … } }`:

```arkts [Index.ets]
import { SparkProvider, SButton } from '@sparkui/core';

@Entry
@ComponentV2
struct Index {
  build() {
    Stack() {                       // @Entry root must be a system container
      SparkProvider() {             // theme + layout context for the page
        Column({ space: 12 }) {
          SButton({ text: 'Get started' })
            .onClick(() => console.info('clicked'))
        }
      }
    }
  }
}
```

| Param | Default | Description |
| --- | --- | --- |
| `paintBackground` | `true` | Paint the `background` token behind the content. |
| `immersive` | `false` | Edge-to-edge layout; content reads its insets from `SparkUI.layout.env.safeArea`. |

## Reading the theme

Custom components read tokens through `@Consumer` — never hard-code colours:

```arkts
@ComponentV2
struct Price {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text('$ 128')
      .fontSize(this.theme.text.lg)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.theme.colors.primary)
      .padding(this.theme.sp(2))
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
  }
}
```

- Colours: `theme.colors.*` (`#AARRGGBB` strings); derive alpha with `SparkColor.alpha(hex, 0.5)`.
- Radii: `theme.radiusSm / Md / Lg / Xl`; type: `theme.text.xs … xxxxl`; shadows: `theme.shadows.sm.toOptions()`.
- Put the radius inside `border({ width, color, radius })` — a later `border()` resets a separate `borderRadius` to 0.

## Controlled and uncontrolled

Value components support both styles:

```arkts preview {"airplane":false}
SSwitch({ label: 'Airplane mode', checked: this.airplane!! })   // controlled, !! two-way binding
SCheckbox({ label: 'Remember me', defaultChecked: true,          // uncontrolled + event
  onCheckedChange: (v: boolean) => { this.remember = v } })
Text(`airplane: ${this.airplane}`)
```

- Booleans: Checkbox / Switch use `checked`, Toggle uses `pressed`, Collapsible / Accordion use `open`.
- Everything else: `value` (Input, Slider, RadioGroup, Tabs, ToggleGroup, Select…) with `onValueChange`.

## Clicks and disabled state

Use the native universal `.onClick()` on the component itself (like Vue's `@click`); disabled / loading components swallow the tap:

```arkts preview {"saved":0}
SButton({ text: 'Save', icon: 'check' }).onClick(() => { this.saved++ })
SButton({ text: 'Disabled', disabled: true }).onClick(() => { this.saved += 100 })
Text(`saved: ${this.saved}`)
```
