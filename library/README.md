# SparkUI

Refined, token-driven ArkTS component library for HarmonyOS, aligned with [shadcn/ui](https://ui.shadcn.com) / shadcn-vue.

- 90+ components: buttons, forms, overlays, menus, data table, calendar & date picker, charts, toasts …
- Layout blocks: AppShell, Sidebar, Top bar, window Title bar (free window / PC), List-detail, Supporting pane
- Theme system: paste a shadcn / tweakcn CSS theme, light & dark, live switching, status colours
  (`--success` / `--warning` / `--info`) and per-component tokens (`--card-background`, `--button-radius` …)
- Breakpoint-free responsive layout: components adapt to the space they actually get
- Configurable motion (like CSS transitions) per component, page / content transitions
- State Management V2, API 22+

## Install

```bash
ohpm install @ospark/sparkui
```

## Usage

```ts
import { SparkProvider, SButton, SCard, SCardHeader, SCardTitle, SCardContent } from '@ospark/sparkui';

@Entry
@ComponentV2
struct Index {
  build() {
    SparkProvider() {
      SCard() {
        SCardHeader() { SCardTitle({ text: 'Hello SparkUI' }) }
        SCardContent() {
          SButton({ text: 'Get started' }).onClick(() => console.info('clicked'))
        }
      }
    }
  }
}
```

### Theming

```ts
import { SparkUI } from '@ospark/sparkui';

SparkUI.themes.usePreset('zinc');            // base gray
SparkUI.themes.useAccent('blue');            // accent colour
SparkUI.themes.setMode('dark');              // 'light' | 'dark' | 'system'
SparkUI.themes.loadString(cssFromTweakcn);   // any shadcn / tweakcn export
SparkUI.themes.setVariable('--card-border-width', '0');   // component token
```

## Requirements

- HarmonyOS API 22 (6.0.2) or later, Stage model, ArkTS State Management V2

## Links

- Documentation & live previews: https://ospark-team.github.io/SparkUI/
- Source: https://github.com/OSpark-Team/SparkUI
- Changelog: [CHANGELOG.md](CHANGELOG.md)

## License

[MIT](LICENSE) © OSpark Team
