# 自适应上下文

<p class="doc-lead">SparkUI 把窗口尺寸、折叠姿态、窗口模式、安全区与输入方式归纳为少量离散信号。组件读取最近的上下文——窗口级或容器级——并据此调整形态。</p>

## 窗口上下文

```arkts
@Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

build() {
  if (this.layout.atLeast('expanded')) {
    Row() { /* two panes */ }
  } else {
    Column() { /* single pane */ }
  }
}
```

| 信号 | 取值 |
| --- | --- |
| `widthClass` / `heightClass` | `compact` · `medium` · `expanded` · `large`（`SparkSizeClassName`） |
| `env.posture` | `flat` · `book` · `tabletop`（折叠姿态） |
| `env.modality` | `touch` · `pointer`（输入方式） |
| `env.windowMode` | `fullscreen` · 分屏 / 悬浮窗 …… |
| `env.safeArea` / `env.keyboardHeight` | 安全区与软键盘高度（vp） |

## 容器查询

`SparkContainer` 测量自身，为子树提供一个局部的 `widthClass`。组件在 `onDidBuild` 中用 `resolveSparkLayout()` 取最近的容器上下文，取不到时回退到窗口上下文：

```arkts
SparkContainer() {
  ContainerProbe()     // resolveSparkLayout(this.getUIContext(), this.getUniqueId())
}
```

## 模拟设备

开发时可以只覆盖上下文（窗口尺寸不变），用来检验自适应决策：

```arkts
SparkUI.layout.simulate(390, 844, 'flat', 'touch', 'fullscreen');      // phone
SparkUI.layout.simulate(840, 900, 'book', 'touch', 'fullscreen');      // foldable (book)
SparkUI.layout.simulate(1280, 800, 'tabletop', 'pointer', 'fullscreen');
SparkUI.layout.simulate(undefined, 0, 'flat', 'touch', 'fullscreen');  // back to the real window
```

::: tip 优先使用无感断点
大多数布局不需要读取上下文——用 [响应式布局](/guide/responsive) 中的原语即可。窗口上下文主要用于导航形态等全局决策，以及依赖输入方式的语义转换。
:::
