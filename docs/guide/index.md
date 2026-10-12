# 介绍

<p class="doc-lead">SparkUI 是一套精致、以 Token 驱动的 ArkTS 组件库：把 shadcn-vue 的体验原生带到 ArkUI，并配有一套为手机、折叠屏、平板与 2in1 设计的自适应布局系统。</p>

- **基线**：HarmonyOS API 22，ArkUI 状态管理 V2（`@ComponentV2` / `@Param` / `@Event` / `@Local`）。
- **命名**：所有组件带 `S` 前缀，去掉前缀即为 shadcn-vue 的名字：`SButton`、`SCard` / `SCardHeader`、`STabsList`……
- **主题**：颜色、圆角、间距、阴影、动效全部来自 Token，可以直接加载 shadcn / tweakcn 导出的主题 CSS。
- **响应式**：没有需要记忆的断点，组件按自己实际得到的空间排版。

## 设计取向

| 特性 | 说明 |
| --- | --- |
| Token 贯穿始终 | 粘贴 shadcn / tweakcn 主题，oklch、hsl、rgb、hex 精确换算，运行时切换。 |
| 一个上下文，覆盖所有设备 | 宽 / 高等级、折叠姿态与输入方式驱动组件的形态决策。 |
| 默认即美观 | 每个部件开箱即有样式，同时可以用 `AttributeModifier` 或组件 Token（`tokens` 参数）覆盖。 |

## 与 shadcn-vue 的差异

ArkTS 对自定义组件有几条编译期约束，SparkUI 统一做了"语义改名"：

| shadcn prop / 写法 | SparkUI | 原因 |
| --- | --- | --- |
| `size` | `sizing` | 不能与通用属性同名 |
| `align` | `alignment` | 同上 |
| `id` | `inputId` | 同上 |
| `@click` | 组件上的原生 `.onClick()` | 禁用时组件内部会吞掉点击 |
| `v-model` | `checked: this.on!!` / `value: this.v!!` | V2 的 `!!` 双向绑定 |
| `<Comp>…</Comp>` | `SComp() { … }` | 尾随闭包插槽 |

另外：使用尾随闭包插槽的组件后面不能再链式写属性；`@Entry` 页面的根节点必须是系统容器，因此页面写成 `Stack() { SparkProvider() { … } }`。

## 关于本文档

- 组件页面由脚本从画廊（`gallery/`）与组件库源码自动生成：示例代码就是画廊 `DemoBlock` 中的代码，API 表格来自 `@Param` / `@Event` / `@BuilderParam` 声明。
- 每个示例都带有一个**网页近似预览**，可以切换明暗、复制代码、在[演练场](/playground)中修改。预览不能 100% 还原 ArkUI 的渲染，详见[网页预览器](/guide/previewer)。

下一步：[安装与使用](/guide/installation)。
