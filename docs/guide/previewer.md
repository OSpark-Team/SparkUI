# 网页预览器

<p class="doc-lead">文档里的每个 ArkTS 示例都会被一个小型解析器读取，再用模仿 SparkUI 的 Vue 组件渲染成网页。它不能 100% 还原 ArkUI，但尺寸、圆角、颜色 Token 与交互都尽量对齐。</p>

## 工作方式

1. **解析**：`docs/.vitepress/theme/previewer/parser.js` 把代码解析成语法树；无法识别的语句会变成错误节点，解析从下一行继续，不会让整个预览失败。
2. **求值**：`interp.js` 对表达式求值。`this.x` 解析到示例的演示状态（画廊页面中 `@Local` 字段的初始值会被自动提取），`this.theme.colors.*` 解析为 CSS 变量。
3. **渲染**：`runtime.js` 把每个组件调用转成描述对象，`components.js` 中的 Vue 组件负责模仿渲染；没有仿真的组件显示为带名字的占位框，子组件仍会渲染在框内。
4. **主题**：颜色 Token 由构建脚本从 `library/.../Presets.ets` 生成（`.ark-theme.ark-preset-*`、`.ark-accent-*`），图标路径来自 `LucideIcons.ets`，所以不会与组件库漂移。

## 支持的语法子集

| 语法 | 示例 |
| --- | --- |
| 组件调用、对象字面量参数 | `SButton({ text: 'Save', variant: 'outline' })` |
| 尾随闭包子组件 | `Column({ space: 8 }) { Text('a') }` |
| 链式属性 | `.width('100%').padding({ left: 12 }).fontColor(...)` |
| 字面量 | 字符串、模板字符串、数字、布尔、`null` / `undefined`、数组、对象、正则 |
| 表达式 | 成员访问、调用、`new`、一元 / 二元 / 三元、赋值、`++` / `--`、`as` 类型断言、`!` 非空断言 |
| 双向绑定 | `checked: this.on!!` —— 交互会写回演示状态 |
| 控制流 | `if / else`、`ForEach(arr, (item, i) => { ... })`、`const` / `let` |
| 结构体 | `@Entry @ComponentV2 struct X { @Local v = 1; build() { ... } }`，`@Builder` 方法可被 `this.xxx()` 调用 |
| 事件 | `.onClick(() => { this.count++ })`、`onCheckedChange: (v) => { this.x = v }` |
| 枚举 | `FlexAlign.Center`、`HorizontalAlign.Start`、`Color.Red`、`FontWeight.Medium` …… |

## 已仿真的组件

- **ArkUI 基础**：Column、Row、Flex、Stack、Text、Span、Button、Image、Divider、Blank、Scroll、List / ListItem、Grid / GridItem、Toggle、TextInput、TextArea、Progress、LoadingProgress、Circle、Rect……
- **SparkUI**：Button、Badge、Card 全家、Input、Textarea、Label、Switch、Checkbox、RadioGroup、Slider、Progress（线 / 环 / 仪表）、Tabs、Accordion、Collapsible、Toggle、ToggleGroup、ButtonGroup、Alert、Avatar / AvatarGroup、Separator、Skeleton、Spinner、Kbd、排版组件、Empty、Item、Breadcrumb、Pagination、Field、Table、AspectRatio、ScrollArea、NumberField、PinInput、TagsInput、InputGroup、Stepper、Calendar（简化）、Sparkline、SGrid / SColumns / SFlow / SStack / SRow / SPage；
- **浮层**：Dialog、AlertDialog、Sheet、Drawer、Popover、Tooltip、HoverCard、DropdownMenu、ContextMenu（右键）、Menubar、Select、Combobox、Command / CommandDialog、Toast（`SparkToast.show`）。

## 已知差距

- 图表（Line / Area / Bar / Pie / Radar / Radial）、区块（App Shell、Sidebar、List Detail……）、日期选择器与代码高亮块显示为占位框。
- 自定义的辅助组件（例如示例里调用的 `StatCard(...)`）没有源码，显示为占位框。
- 没有 ArkUI 的布局引擎：用 CSS flex / grid 近似；`layoutWeight`、`constraintSize`、对齐等常见属性已映射，复杂的 `RelativeContainer` 规则、`@Styles`、`AttributeModifier`、动画参数会被忽略。
- `SparkContext`、`@Consumer` 等运行时机制只做了最常用的部分（`this.theme`、`SparkUI.layout` 返回固定的宽屏 + 指针环境）。
- 尺寸单位 vp / fp 以 1:1 映射为 CSS px。

想试试？打开[演练场](/playground)。
