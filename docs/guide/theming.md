# 主题

<p class="doc-lead">每一种颜色、圆角、间距与阴影都来自 Token。选择一个基础灰阶、一个强调色和圆角，所有组件（包括原生 ArkUI 组件）都会实时更新。</p>

## 预设与强调色

内置预设与 shadcn v4 的基础色一致：`neutral`（默认）、`zinc`、`slate`、`stone`、`gray`；强调色叠加在预设之上，只改变 primary / ring / sidebar-primary：`blue`、`green`、`orange`、`red`、`rose`、`violet`、`yellow`。

```arkts
SparkUI.themes.usePreset('zinc');      // 基础灰阶（保留强调色与覆盖项，如圆角）
SparkUI.themes.useAccent('violet');    // 强调色；'none' = shadcn 默认的单色
SparkUI.themes.setMode('dark');        // 'light' | 'dark' | 'system'
SparkUI.themes.toggleDark();
SparkUI.themes.setVariable('--radius', '0.75rem');
```

在网页预览中试试（下面的选择器作用于本站所有预览，数值由 `Presets.ets` 自动生成）：

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

基础灰阶只会微调中性色（背景、边框、弱化文字）的色相——和 shadcn 一样克制；强调色改变 primary 与 ring。

## 加载 shadcn / tweakcn 主题

SparkUI 的主题文件就是 CSS 的一个子集：`:root {}`、`.dark {}`、`@size(compact|medium|expanded|large) {}`、`--var: value;` 与注释。shadcn / tweakcn 的导出可以原样粘贴：`@theme`、`@layer`、`@import`、`@custom-variant`、其他选择器与非自定义属性会被识别并以 `info` 诊断跳过。oklch、hsl、rgb、hex 会被精确换算。

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
const r1 = SparkUI.themes.loadString(cssText);                 // CSS 子集或 JSON（自动识别）
const r2 = SparkUI.themes.loadRawfile('themes/brand.css');      // resources/rawfile 下的文件
const r3 = SparkUI.themes.loadFile(sandboxPath);
const r4 = await SparkUI.themes.loadUrl('https://…/theme.css'); // 需要 ohos.permission.INTERNET
if (!r1.ok) {
  r1.diagnostics.forEach((d: ThemeDiagnostic) => console.warn(d.message));
}
SparkUI.themes.exportCss();   // 当前生效的主题（预设 + 覆盖项）
```

加载永不抛异常：缺失或非法的 Token 回退到所叠加的预设，问题以诊断（`error` / `warning` / `info`）返回。

## 状态色与组件 Token

- 状态色是真正的语义 Token：`--success`、`--warning`、`--info` 及其 `-foreground`。
- 全局旋钮 `--border-width` 控制所有带边框组件的边框粗细。
- 组件 Token 形如 `--<component>-<property>`：`--card-background`、`--button-radius`、`--button-outline-background`、`--button-height-sm`……未设置时组件使用自身的 shadcn 配方。
- 单个实例用 `tokens` 参数覆盖：

```arkts preview
SButton({ text: 'Pill', tokens: { radius: 999 } })
SButton({ text: 'Custom', tokens: { background: 'oklch(0.6 0.2 250)', foreground: '#ffffff' } })
```

- 全局设置时与其它变量一样（`setVariable`，或用 `loadString` 加载 `theme.css`）。状态徽章与提示读取语义状态色 Token：

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

## 原生组件

`SparkProvider` 会把 Token 同步到系统主题（`WithTheme` / `ThemeControl`），因此原生 `Toggle`、`TextInput` 等也会跟随强调色与明暗模式。
