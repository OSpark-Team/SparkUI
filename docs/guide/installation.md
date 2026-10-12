# 安装与使用

## 安装

在 HarmonyOS 工程（API 22，状态管理 V2）的模块目录中执行：

```bash
ohpm install @sparkui/core
```

也可以在本仓库中以本地 HAR 依赖的方式引用 `library/`：

```json5
// entry/oh-package.json5
{
  "dependencies": {
    "@sparkui/core": "file:../library"
  }
}
```

## 用 SparkProvider 包裹页面

`SparkProvider` 为页面提供主题（`sparkTheme`）与布局（`sparkLayout`）上下文，把 Token 同步给原生组件，并绘制 `background` 背景。`@Entry` 的根节点必须是系统容器，所以写成 `Stack() { SparkProvider() { … } }`：

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

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `paintBackground` | `true` | 在内容后绘制 `background` Token。 |
| `immersive` | `false` | 沉浸式（全屏布局）：内容自行从 `SparkUI.layout.env.safeArea` 读取安全区留白。 |

## 读取主题

自定义组件通过 `@Consumer` 读取 Token，永远不要写死颜色：

```arkts
@ComponentV2
struct Price {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text('¥ 128')
      .fontSize(this.theme.text.lg)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.theme.colors.primary)
      .padding(this.theme.sp(2))
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
  }
}
```

- 颜色：`theme.colors.*`（`#AARRGGBB` 字符串）；透明度派生用 `SparkColor.alpha(hex, 0.5)`。
- 圆角：`theme.radiusSm / Md / Lg / Xl`；字号：`theme.text.xs … xxxxl`；阴影：`theme.shadows.sm.toOptions()`。
- 圆角要写在 `border({ width, color, radius })` 中——之后再调用 `border()` 会把单独设置的 `borderRadius` 重置为 0。

## 受控与非受控

值类组件同时支持两种写法：

```arkts preview {"airplane":false}
SSwitch({ label: 'Airplane mode', checked: this.airplane!! })   // 受控，!! 双向绑定
SCheckbox({ label: 'Remember me', defaultChecked: true,          // 非受控 + 事件
  onCheckedChange: (v: boolean) => { this.remember = v } })
Text(`airplane: ${this.airplane}`)
```

- 布尔类：Checkbox / Switch 用 `checked`，Toggle 用 `pressed`，Collapsible / Accordion 用 `open`。
- 其他：`value`（Input、Slider、RadioGroup、Tabs、ToggleGroup、Select……），对应 `onValueChange`。

## 点击与禁用

点击用原生通用事件 `.onClick()`，直接写在组件上（相当于 Vue 的 `@click`）；组件在 `disabled` / `loading` 时会吞掉点击：

```arkts preview {"saved":0}
SButton({ text: 'Save', icon: 'check' }).onClick(() => { this.saved++ })
SButton({ text: 'Disabled', disabled: true }).onClick(() => { this.saved += 100 })
Text(`saved: ${this.saved}`)
```
