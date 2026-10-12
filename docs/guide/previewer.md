# 网页预览器

<p class="doc-lead">文档里的每个 ArkTS 示例都会被一个小型解析器读取，再用模仿 SparkUI 的 Vue 组件渲染成网页。它不能 100% 还原 ArkUI，但尺寸、圆角、颜色 Token 与交互都尽量对齐。</p>

## 工作方式

1. **解析**：`docs/.vitepress/theme/previewer/parser.js` 把代码解析成语法树；无法识别的语句会变成错误节点，解析从下一行继续，不会让整个预览失败。
2. **求值**：`interp.js` 对表达式求值。`this.x` 解析到示例的演示状态（画廊页面中 `@Local` 字段的初始值会被自动提取），`this.theme.colors.*` 解析为 CSS 变量。
3. **渲染**：`runtime.js` 把每个组件调用转成描述对象，`components.js` 中的 Vue 组件负责模仿渲染；没有仿真的组件显示为带名字的占位框，子组件仍会渲染在框内。
4. **主题**：颜色 Token（包括状态色 `--success` / `--warning` / `--info`）由构建脚本从 `library/.../Presets.ets` 生成（`.ark-theme.ark-preset-*`、`.ark-accent-*`），图标路径来自 `LucideIcons.ets`，所以不会与组件库漂移。仿真组件以 `var(--<component>-<property>, <配方值>)` 读取 D13 组件 Token：示例中的 `SparkUI.themes.setVariable` / `loadString` / `toggleDark` 作用于该示例自己的预览，`tokens: { … }` 参数会变成内联 CSS 自定义属性。
5. **数据**：示例中构造的库类（`new SparkChartSeries(…)`、`new SparkShellNavItem(…)`、`new SparkTopbarAction(…)` 等）从库源码读取并以普通对象运行；画廊页面的常量（`MONTHS`、`MAILS` 等）与 getter（`get mail()`）也可在示例中使用。

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
- **SparkUI**：Button、Badge、Card 全家、Input、Textarea、Label、Switch、Checkbox、RadioGroup、Slider、Progress（线 / 环 / 仪表）、Tabs、Accordion、Collapsible、Toggle、ToggleGroup、ButtonGroup、Alert、Avatar / AvatarGroup、Separator、Skeleton、Spinner、Kbd、排版组件、Empty、Item、Breadcrumb、Pagination、Field、Table、AspectRatio、ScrollArea、NumberField、PinInput、TagsInput、InputGroup、Stepper、Calendar / DatePicker（简化）、SGrid / SColumns / SFlow / SStack / SRow / SPage；
- **图表**（布局移植自 `ChartMath.ets`：整齐刻度、band / point 比例尺、发散堆叠、monotone / step 曲线、圆角柱、标签抽稀）：SLineChart、SAreaChart（堆叠、渐变）、SBarChart（分组、堆叠、横向、负值）、SPieChart / SDonutChart（中心文字、激活扇区放大、间隔角）、SRadialChart（轨道、圆头、部分角度）、SRadarChart（多边形 / 圆形网格、圆点、描边）、SSparkline、SChartContainer（共享图例、空状态）。悬停显示十字线或条带光标与提示卡片，图例可切换系列，图形以 CSS 动画绘入；
- **区块**（无断点：每个区块用 `ResizeObserver` 测量所在预览容器，套用 `BlocksLogic.ets` 的策略与数值）：SSidebarProvider 与 SSidebar 全家（停靠 / 图标栏 / 滑出，sidebar / floating / inset 变体，激活项，展开的侧边栏放不下 `minInsetWidth` 时变为抽屉）、STopbar（侧边栏触发器或返回、标题 / 副标题、操作按钮、窄于 520 px 时收缩并把搜索收进图标）、SAppShell、SListDetail（并排或压栈 + 返回）、SSupportingPane（并排 / 下方 / 底部抽屉 + 触发按钮）、SDashboardGrid / SDashboardTile（跨列数受当前列数限制）；
- **浮层**：Dialog、AlertDialog、Sheet、Drawer、Popover、Tooltip、HoverCard、DropdownMenu、ContextMenu（右键）、Menubar、Select、Combobox、Command / CommandDialog、Toast（`SparkToast.show`）；
- **画廊辅助组件**（`Brand`、`UserRow`、`MailRow` 等）不做仿真：预览直接渲染画廊里真实的示例代码及其用到的辅助组件源码。

**只展示代码。** 网页无法如实还原的示例只展示代码、不提供预览：过渡页（纯动画，预览器不做动画）与标题栏页（窗口装饰，只存在于 HarmonyOS 的自由窗口中）。清单见 `docs/scripts/lib/pages-config.mjs` 中的 `CODE_ONLY`。

`npm run test:previewer` 会渲染所有带预览的画廊示例，列出仍显示为占位框的组件，并报告跳过的只展示代码的示例。`npm run docs:gen` 还会检查每个生成页面的结构。

## 已知差距

- `SCodeBlock` 的代码不做语法高亮。
- 示例调用的、没有源码也未被仿真的组件（例如你自己的 `StatCard(...)`，或 STitleBar、STransition 等只展示代码的组件）显示为占位框。
- 没有 ArkUI 的布局引擎：用 CSS flex / grid 近似；`layoutWeight`、`constraintSize`、对齐等常见属性已映射，复杂的 `RelativeContainer` 规则、`@Styles`、`AttributeModifier`、动画参数会被忽略。图表与区块用 CSS 动画（绘入、扫描、滑动），不做形状间的插值变形。
- `SparkContext`、`@Consumer` 等运行时机制只做了最常用的部分（`this.theme`；`SparkUI.layout` 返回固定的宽屏 + 指针环境，区块则按测得的宽度布局）。自定义 `layoutPolicy` 函数会执行，通过 `controller:` 传入的控制器不会生效。
- 示例中未声明的标识符（`config`、`rows`）会回退到画廊页面的常量或 shadcn 示例数据。
- 尺寸单位 vp / fp 以 1:1 映射为 CSS px。

