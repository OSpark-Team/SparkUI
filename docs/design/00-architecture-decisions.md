# SparkUI 架构决策记录（ADR-00）

> 状态：**已确认（2026-10-10）**：D1 保持 22；D2 统一 openCustomDialog；D3 Provider/Consumer + 全局兜底；D5 采纳阈值。D6 路由在第 4 批再确认。所有 API 结论均来自本机 `devecocli docs`（HarmonyOS 官方文档离线版），"NN+" 表示起始 API 版本。
> 工程现状：DevEco 模板工程，`targetSdkVersion 26.0.0`，`compatibleSdkVersion 6.0.2(22)`；模拟器有 Pura 90 Pro / Mate X7 / MatePad Pro 13 / MateBook Pro（均为 7.0.0(26)）。

---

## D1. SDK 基线（规范写 min 20，工程当前为 22）

| 方案 | 说明 |
|---|---|
| **A. 保持 compatible 22（推荐）** | 可直接使用 `UIObserver.on('windowSizeLayoutBreakpointChange')`（22+）、`getWindowAvoidAreaIgnoringVisibility`（22+）、`UIUtils.applySync/flushUpdates`（22+）、`ComponentContent.isDisposed/inheritFreezeOptions`（20+）、`CustomTheme.darkColors`（20+）、`supportSvg2`（21+）。代码分支最少。 |
| B. 降到 compatible 20 | 覆盖更多 HarmonyOS 6.0.0/6.0.1 设备；上面 22+ 能力需 `canIUse`/版本判断降级（断点改为自行按 windowSizeChange 计算等）。 |

均需对 23+/26 能力做版本守卫：`@Provider` 跨 BuilderNode（23）、`stateStyles.hovered`（26）、`Canvas(params)`（23）、`accessibilityStateDescription`（23）、`Colors.primary/onPrimary/container`（26）、`openOrderOverlay`（26）等。

---

## D2. Overlay 基座选型（关键）

### 调研要点
- `PromptAction.openCustomDialog(ComponentContent, BaseDialogOptions)`（12+）：完全自绘内容；`onWillDismiss`（12+）统一拦截遮罩点击 / 侧滑返回 / 三键返回 / ESC；`keyboardAvoidMode`；`levelOrder`（18+，层级栈）；`dialogTransition`/`maskTransition`（19+）；`focusable`（19+）；`isModal:false` 时无遮罩且事件穿透。打开后只能更新 alignment/offset/autoCancel/maskColor。
- `openPopup`/`openMenu`（18+）：系统做锚点定位与翻转，但**不回报最终方向**（自绘箭头会错位）；默认带模糊、阴影、20vp 圆角，需逐项覆盖；Menu 不能设宽度/阴影、点击内容自动关闭，不适合 Select。
- `OverlayManager`：层级低于所有 Dialog/Popup/Sheet/Toast，无遮罩无动画，返回键需 19+ 显式开启 —— 不适合作为浮层基座。
- `bindSheet`/`bindPopup`/`bindMenu`：声明式，不可在 AttributeModifier 中使用；样式与窗口宽度强绑定（<600vp 只能底部/全屏）。
- `promptAction.openToast`：仅纯文本、字体固定，不满足 Sonner。
- **上下文断裂**：文档明确 ComponentContent 不支持 `@Provide/@Consume`；V2 `@Provider/@Consumer` 跨越需 `enableProvideConsumeCrossing`，**API 23 起**，且内容挂在 Dialog 根下而非页面下。官方建议（FAQ）：把 `@ObservedV2` 对象作为 args 传入，`@Trace` 字段可响应式刷新。关闭不会触发 `aboutToDisappear`，必须手动 `dispose()`。

### 提案 A（推荐）：统一 `openCustomDialog` + 自研定位
- 每个 UIContext 一个 `SparkOverlayService`，内部维护层级栈 `{ id, ComponentContent, levelOrder, kind }`。
- 浮层内容统一由 `wrapBuilder` 构建，args 为一个 `OverlayScope`（`@ObservedV2`：theme、layout、locale、open 状态、`close()`），开发者在 `DialogContent { ... }` 里写的内容透明地被包进来——对开发者无感。
- 模态类（Dialog / AlertDialog / Sheet / Drawer）：`isModal:true` + Token 遮罩色 + 自定义 TransitionEffect；Drawer 自研拖拽手势。
- 锚点类（Popover / DropdownMenu / Select / Combobox / HoverCard / ContextMenu / Tooltip / DatePicker）：透明全窗口根 + 内容按锚点矩形（`FrameNode.getPositionToWindow` / `componentUtils.getRectangleById`）+ 窗口尺寸 + 避让区**自行计算定位与翻转**，箭头方向 100% 可控；点外部关闭用透明遮罩 + `autoCancel`，Tooltip 用 `isModal:false, focusable:false`。
- Toast / Sonner：单个非模态、不抢焦点、最高 levelOrder 的宿主浮层，内部堆叠多条通知。
- 优点：一套机制、视觉 100% 由 Token 控制、跨设备行为一致、语义翻译（Popover↔Sheet、Dialog↔Drawer）只是换"定位策略"。缺点：定位/翻转/键盘避让需自研与测试。

### 提案 B：混合
锚点类用系统 `openPopup`（剥离默认 chrome），模态类用 `openCustomDialog`。省掉定位代码，但箭头方向不可知、样式受系统默认值与版本差异影响（26 起模糊默认值变化）。

### 提案 C：声明式 bind*
最贴近原生，但无法统一管理层级栈/焦点归还，受 600vp 限制，且不可放入 Modifier。不推荐。

---

## D3. Token Store 与上下文传递

- `SparkTheme`：`@ObservedV2` class，显式字段 + `@Trace`（`colors: SparkColors`、`radius`、`spacing`、`typography`、`shadows`、`motion`……），颜色统一存为 ARGB `number`（可直接作 `ResourceColor`）。解析器通过脚本生成的显式映射表写入。
- 传递（推荐）：**`@Provider('sparkTheme')` / `@Consumer('sparkTheme')` + 全局默认实例兜底**。
  - `@Consumer('sparkTheme') theme: SparkTheme = SparkRuntime.theme;` —— 有 `SparkProvider` 时取最近祖先（支持子树局部主题，如预览不同主题），没有时回退全局实例，**组件在任何位置都能用，不会因忘包 Provider 而崩**。
  - 布局上下文同理：`@Consumer('sparkLayout')`，`SparkContainer` 可在子树重新 `@Provider` 局部上下文。
  - 浮层内容由 `SparkOverlayService` 把"打开时的 theme/layout 实例"显式放入 `OverlayScope`，浮层内部再 `@Provider` 下发，保证浮层内组件读到与触发处一致的上下文。
- 复合组件状态（Dialog open、Tabs value、Accordion 展开项……）同样用带作用域别名的 `@Provider/@Consumer`。
- 待真机验证（实现首批即做测试页）：`@BuilderParam` 尾随闭包内容中的 `@Consumer` 解析到哪个祖先（文档推断：普通 `@Builder` 以宿主子组件为父，即可取到宿主的 Provider）。
- 系统主题桥接：`ThemeControl.setDefaultTheme({ colors, darkColors })`（darkColors 20+）。文档未说明运行时再次调用是否刷新已存在组件 → 方案：每次 Token 更新都调用，同时在 `SparkProvider` 外包一层 `WithTheme({ theme })` 并替换 theme 对象以确保原生组件即时刷新；以真机结果为准。
- 亮暗：`applicationContext.setColorMode`（11+）强制模式；`applicationContext.on('environment')` 监听系统变化；模式选择用 PersistenceV2 持久化（setColorMode 不持久）。

---

## D4. 主题文件语法（不扩展，仅定义容错行为）

严格实现规范所列子集：`:root`、`.dark`、`@size(compact|medium|expanded|large)`、`--var: value;`、注释；颜色 `oklch/hsl/rgb/#hex`，长度 `rem/px/vp`。
为了能**直接粘贴 shadcn / tweakcn 导出**，对以下内容"识别但跳过 + 产出 info 级诊断"，不视为扩展：`@theme inline {}`、`@layer base {}`、`@import`、`@custom-variant`、`--font-*`、`--tracking-*`、`--shadow-*` 的原样值（阴影值本期解析为 Token，字体族跳过）。
组件 Token 覆盖（如 `--button-height-sm`）已在 D13 中确认并实现。

---

## D5. 布局等级与阈值

- `widthClass`（按**容器/窗口宽度 vp**）：`compact < 600 ≤ medium < 840 ≤ expanded < 1440 ≤ large`。与系统 `WidthBreakpoint`（SM 320–600 / MD 600–840 / LG 840–1440 / XL ≥1440）对齐，XS 并入 compact。
- `heightClass`（按**高度 vp**，不用系统基于宽高比的 HeightBreakpoint）：`compact < 480 ≤ medium < 900 ≤ expanded < 1200 ≤ large`（与 Material window size class 一致）。
- 阈值放在主题配置中可调；仅在跨等级时更新状态（窗口信号防抖 + `@Computed`）。
- `posture`：`foldStatusChange` + 折痕区域；HALF_FOLDED 且折痕横向（宽>高）→ `tabletop`，纵向 → `book`，否则 `flat`。
- `modality`：`inputDevice` 存在 mouse/touchpad 源 → `pointer`，再以事件 `sourceTool`（MOUSE/TOUCHPAD vs Finger/Pen）实时修正。
- `windowMode`：`windowStatusDidChange`（20+）；`avoidArea`：`avoidAreaChange`（SYSTEM / CUTOUT / NAVIGATION_INDICATOR / KEYBOARD）。

---

## D6. 路由适配（第 4 批实现，届时再次确认细节）

方向性提案：`interface SparkNavigator { push(name, param?); pop(); onBack(...) }`，内置 `NavPathStackNavigator`；ListDetail 自己做单/双栏（不依赖 Navigation 的 Split 模式），绑定 `NavPathStack` 后窄屏把详情作为 `NavDestination` 压栈。`HdsNavigation` 不进入 `@sparkui/core`（`@kit.*` 不支持动态 import，且仅限中国大陆），后续以独立可选 HAR `@sparkui/hds` 提供。

---

## D7. 工程结构（按规范执行，无需确认）

- 新增 HAR 模块 `library`（包名 `@sparkui/core`）。
- 现有 `entry` 模块迁移为 `gallery`（HAP，示例应用 + 集成测试）。
- `docs/` 存放设计文档、每轮迭代总结与测试说明。

---

## D8. 组件命名（已确认 2026-10-10）

编译实测：ArkTS 禁止自定义 struct 与内置组件同名（错误码 10905227 / 10905237）。shadcn 中有 12 个名字因此无法直接使用：Badge、Button、Calendar、Checkbox、DatePicker、Progress、Select、Sheet、Slider、Stepper、Tabs、Toggle。StepperItem、MenuItem 等子组件同理。

**决策：所有对外组件统一加 `S` 前缀**，去掉前缀即是 shadcn-vue 原名，例如 `SButton`、`SCard` / `SCardHeader`、`SDialog` / `SDialogContent`、`STabsList`。理由：
- 只有一条规则，无需记忆例外。
- 开发者可以在同一文件里同时使用原生 `Button` 和 `SButton`。
- ArkUI 未来新增同名内置组件时，不会引发破坏性变更。

非组件 API 保持描述性命名：`SparkUI`、`SparkProvider`、`SparkContainer`、`SparkTheme`，以及 `ButtonVariants` 等 variant 配方 / Modifier。

---

## D9. Prop 命名与事件（已确认 2026-10-10）

编译实测（错误码 10505001）：自定义组件的成员不能与 ArkUI 通用属性 / 通用事件同名。规则如下：

| shadcn prop | SparkUI | 说明 |
|---|---|---|
| `size` | `sizing` | Button / Toggle / ToggleGroup / InputGroup / Item / Icon 等 |
| `align` | `alignment` | Popover / DropdownMenu / Tooltip 等内容对齐 |
| `id` | `inputId` | 表单控件与 Label 关联 |
| `@click` / `@focus` / `@blur` | 原生通用事件 `.onClick()` / `.onFocus()` / `.onBlur()` | 直接挂在组件上，等同 Vue 的 `@click`；组件负责保证 disabled 时不触发 |

以后遇到其他冲突（`direction`、`offset`、`position` 等），统一采用"语义改名"：选一个不与通用属性冲突、且语义最接近的名字，并在组件文档中注明。

另：`@Entry` 页面的 build 根节点必须是系统容器组件，因此页面写法为 `Stack() { SparkProvider() { ... } }`（`SparkProvider` 不能直接作为页面根）。

---

## D3 补充：复合组件的上下文改用渲染树解析（真机验证，2026-10-10）

平板真机实测：写在尾随闭包插槽里的 `@Consumer`，解析到的是**定义该 Builder 的组件**（通常是页面），而不是承载插槽的宿主组件。因此 `STabs { STabsTrigger() }` 这种写法无法通过 `@Provider/@Consumer` 共享状态。

**对策（对开发者透明，不改变对外 API）：** 新增 `SparkContext`，沿真实渲染树解析上下文。
- 宿主在 `aboutToAppear` 中以自己的组件 id 注册 `provide(key, state)`，在 `aboutToDisappear` 中 `revoke`。
- 后代组件在 `onDidBuild` 中沿 FrameNode 父链向上查找。`getFrameNodeByUniqueId(宿主组件 id)` 返回宿主的根渲染节点，该节点就在后代的父链上，真机已验证可以命中。
- 浮层内容走同一套机制：浮层根组件注册为宿主。

主题与布局上下文不受影响：`SparkProvider` 是页面级组件，插槽内的 `@Consumer('sparkTheme'/'sparkLayout')` 都能取到（或回退到全局实例）。只有复合组件之间的共享状态改用 `SparkContext`。

---

## D10. 沉浸式与容器上下文（真机验证，2026-10-10）

- **沉浸式**：`SparkProvider({ immersive: true })` 调用 `window.setWindowLayoutFullScreen(true)`，内容按 `env.safeArea` 自行留白。原因：`expandSafeArea` 只扩展已扩展容器的直接子节点，遇到自定义组件边界就停止，无法让整页沉浸。`expandSafeArea` 仍用于背景层和浮层面板。
- **容器上下文**：`SparkContainer` 除了 `@Provider` 之外，同时通过 SparkContext 发布上下文。组件在 `onDidBuild` 中用 `resolveSparkLayout()` 获取最近的容器，取不到时回退到 `@Consumer('sparkLayout')`。
- **ArkTS 约束补充**：使用尾随闭包插槽的自定义组件，后面不能链式写通用属性或事件。

---

## D11. 无感断点的响应式模型（2026-10-10）

目标：开发者像写 Web 一样随意堆放组件，响应式由 SparkUI 负责，不需要学习断点。

1. **容器自测量**：所有布局原语都在 `onAreaChange` 中测量自身宽度并据此排版，不读取窗口断点。
   - `SGrid({ minItemWidth })`：auto-fill 列数 + span，等价于 `repeat(auto-fill, minmax(x, 1fr))`。
   - `SColumns` / `SColumn({ weight })`：放得下就并排（按权重分配宽度），放不下就纵向堆叠。
   - `SFlow`：自动换行。
   - `SStack` / `SRow`：纵向 / 横向排列，间距取自 Token。
   - `SPage`：自适应边距、最大宽度、可选安全区。
2. **组件自适应**：组件根据自己拿到的空间调整细节，例如 `SCard` 宽度小于 360vp 时内边距从 24 收紧到 16。后续浮层类组件在窄空间自动转为 Sheet / Drawer（语义翻译），同样无需开发者声明。
3. **为什么需要 `SGridItem` / `SColumn` 包裹**：ArkUI 父组件无法设置任意子组件（尤其是插槽内容）的尺寸。Grid / List / WaterFlow 都要求固定类型的子组件，Flex 子项的 flexBasis 也只能由子组件自己设置。因此网格单元和列需要一层轻量包裹，对应 Web 中的 `<div class="col">`。
4. 窗口级上下文（widthClass、posture、modality）仍然保留，用于导航形态等全局决策，以及语义翻译中依赖输入方式的部分。

---

## D12. 可配置动效系统（用户要求"类似 CSS"，2026-10-12）

- **统一入口**：所有组件动画都通过 `SparkAnim` 实现。
  - `attr()`：隐式属性动画，用于 `.animation()`。
  - `run()`：在状态变化外包一层 `animateTo`。
  - `enter()`：出现 / 消失时的 `TransitionEffect`。
  - 每个组件都有一个动效 key，例如 `accordion`、`collapsible`、`tabs`、`checkbox`、`radio`、`switch`、`slider`、`progress`、`select`、`input`、`avatar`、`toast`、`dialog`、`drawer`、`sheet`、`popover`、`tooltip`、`menu`、`theme`。
- **配置来源（主题文件语法扩展，由用户提出）**：
  - `--motion-enabled: true|false`：全局开关，关闭后所有动画瞬时完成。
  - `--motion-<key>-duration: 320ms`
  - `--motion-<key>-ease`：可选 `linear`、`ease`、`ease-in`、`ease-out`、`ease-in-out`、`standard`、`friction`、`sharp`、`smooth`、`rhythm`、`cubic-bezier(a,b,c,d)`、`spring(response, damping)`
  - `--motion-<key>-enabled: false`
  - 代码 API：`SparkUI.themes.setMotion(key, { duration, ease, enabled })` 和 `setMotionEnabled()`，内部写入同名变量，因此会随主题一起导出。
- **铁律**：按压态（pressed）不加任何动画；选中类控件不对两个兄弟节点同时做背景渐变（避免出现"两个高亮"），而是用单个滑动指示器（Tabs）或直接瞬切。
- **主题切换时序**：`useAccent` / `usePreset` / `setMode` 会先在 `animateTo` 中切换 Token，再发布 `@Trace` 的选中值，避免选中态被卷进主题过渡动画。原因：ArkUI 的 `animateTo` 会把调用时尚未刷新的状态变化一并动画。

---

## D13. 组件 Token 体系（用户决策，2026-10-12）

> 用户原话："success/warning/info 当然应该是真正的主题 token；还有更多：是否有边框、背景色、是否透明……我们需要一个完整、高度可定制的组件体系。"
> 本节取代 D4 中"组件 Token 覆盖列为后续语法扩展"的保留意见。语法仍是 D4 的 CSS 子集，只是新增了变量名，不新增语法结构。

### 1. 三层 Token

| 层 | 形式 | 例子 | 存放 |
|---|---|---|---|
| 语义 Token | `--<name>` | `--primary`、`--success`、`--warning-foreground` | `theme.colors`（由 `tools/gen-tokens.mjs` 生成） |
| 全局旋钮 | `--<knob>` | `--border-width`（默认 1px） | `theme.borderWidth` |
| 组件 Token | `--<component>-<property>` | `--card-background`、`--button-radius`、`--dialog-overlay` | `theme.comp`（`SparkComponentTokens`） |

**状态色成为语义 Token**：新增 `success`、`success-foreground`、`warning`、`warning-foreground`、`info`、`info-foreground`。所有预设的 `:root` 和 `.dark` 中都有定义，取值为 emerald 600/500、amber 600/500、sky 600/400，前景色与原 `SparkTones.palette` 一致，因此视觉不变。shadcn / tweakcn 导出里没有这些变量也不受影响：控制器总是先套用基础预设，再叠加用户文件，缺失的变量保留预设值。`SparkTones` 改为读取这些 Token；`SparkTones.palette` / `SparkStatusPalette` 为了源码兼容而保留，但已标为 deprecated，不再被读取。

**全局旋钮只保留 `--border-width`**。所有带边框的组件（Card、Input、outline Button、Badge、Alert、Checkbox、浮层面板、Toast、Tabs 暗色指示器）原来都用同一个 1px 字面量，一个旋钮就能实现"全站无边框"或"粗边框"风格。不加 `--surface-opacity`：同样的效果可以直接写在颜色 Token 的 alpha 里（`--card-background: oklch(1 0 0 / 60%)`）。不加 `--shadow-strength`：阴影强度已经由 `--shadow-*` 覆盖（tweakcn 导出会把 shadow-opacity 烘焙进这些值），单个组件还可以用 `-shadow: none` 关闭。再加一个乘性旋钮只会让叠加规则难以预测。

### 2. 命名、值与诊断

- **命名**：`--<component>-<property>`。有变体的组件，默认变体用不带前缀的属性名，其它变体在属性名前加变体名：`--button-background`（default）、`--button-outline-background`、`--card-ghost-background`。尺寸后缀同理：`--button-height`、`--button-height-sm`、`--button-height-lg`。
- **匹配顺序**：
  1. 先匹配语义 Token。所以 `--card-foreground`、`--popover-foreground`、`--input`、`--sidebar-*` 仍是语义 Token。
  2. 再按最长组件名前缀匹配。例如 `toggle-group-…` 优先于 `toggle-…`。
- **值类型**（`SparkTokenKind`）：
  - `color`：任何主题颜色语法，含 alpha（`oklch(… / 50%)`）、`transparent`、`none`，以及新增的 `color-mix(in <space>, c1 p%, c2 p%)`（按 sRGB 预乘混合）。
  - `length`：px / rem / vp / 无单位，`none`（= 0），以及 `calc()`（支持 + − × ÷ 和括号）。
  - `shadow`：CSS box-shadow 的第一层，或 `none`。
  - `number`：如 `600`、`0.97`；百分数会换算，`50%` → 0.5。
  - `bool`。
- **var() 引用**：`var()` 可引用任何变量。fallback 允许嵌套函数，例如 `var(--x, oklch(1 0 0 / 50%))`。
- **诊断**：
  - 已登记的 Token，值无法按其类型解析时，产生 `error`；组件保留内置值。
  - 已知组件的未登记属性产生 `warning`，但值仍会存储，可通过 `theme.comp` 读取，供自定义组件使用。用 `SparkComponentTokenRegistry.define()` 登记后，它会像内置 Token 一样参与校验。
  - 不匹配任何组件的变量，仍按原规则报 unknown variable。
- **默认值 = 未设置**：组件 Token 不写进预设。组件以自身的 shadcn 配方作为 fallback，因此不设置任何 Token 时视觉完全不变；导出的 theme.css 也只包含真正被覆盖的变量。

### 3. 读取 API

ArkTS 严格模式不允许索引签名，所以内部用 `Map` 存储：

```ts
theme.comp.color('card', 'background', theme.colors.card)   // '#AARRGGBB'
theme.comp.length('button', 'radius', theme.radiusMd)       // vp
theme.comp.shadow('popover', 'shadow', theme.shadows.md)    // SparkShadow | undefined；none → isNone
theme.comp.number('button', 'font-weight', 500)
theme.comp.bool(...)
theme.comp.has(...) / raw(...) / keys()
```

- **响应式**：`SparkComponentTokens` 是 `@ObservedV2`，每个读方法都会读取 `@Trace version`。主题刷新时，`copyFrom` 只在 Token 集合真正变化时执行 `version++`，读取过它的组件及其 `@Computed` 配方随之重算。
- **组件内部**：统一使用 `SparkTokenReader(theme, component)`，调用 `r.color(props, instanceValue, recipeValue)`。`props` 可以是数组，最具体的放在最前，例如 `['outline-border-width', 'border-width']`。

### 4. 单实例覆盖：`tokens` 参数（唯一约定）

- **写法**：组件提供 `@Param tokens: XxxTokens = {}`。`XxxTokens` 是字段全部可选的 interface，例如 `SCard({ tokens: { background: 'transparent', borderWidth: 0, shadow: 'none' } })`。
- **优先级**（从高到低）：
  1. 实例 `tokens`
  2. `--<component>-<variant>-<prop>`
  3. `--<component>-<prop>`
  4. 全局旋钮
  5. 内置配方
- **值约定**：颜色和阴影用字符串，语法与主题文件相同，非法值被忽略；长度和数值用 number（vp）。
- **与 `modifier` 的关系**：现有的 `modifier`（AttributeModifier）保留，作为最后一层任意属性覆盖。`tokens` 是语义化的设计参数，`modifier` 是兜底的逃生口，两者互不替代。
- **已提供**：
  - `ButtonTokens`、`CardTokens`
  - `InputTokens`（SInput / STextarea 共用）
  - `BadgeTokens`、`AlertTokens`、`ToggleTokens`、`SwitchTokens`、`CheckboxTokens`、`ProgressTokens`
  - `TabsTokens`（STabsList）
  - `SparkSurfaceTokens`（SDialogContent / SSheetContent / SPopoverContent / SDropdownMenuContent 共用）；`DrawerTokens`（SDrawerContent，在 surface 字段之外加拖拽把手）
  - 布局 block（`blocks/BlockTokens.ets`）：`SidebarTokens`（SSidebarProvider，解析结果存入 `SparkSidebarState.style` 供所有部件读取）、`TopbarTokens`、`TitleBarTokens`、`AppShellTokens`（含 `sidebar` / `topbar` 子对象）、`ListDetailTokens`、`SupportingPaneTokens`；`SDashboardTile` 复用 `CardTokens`
  - 布局尺寸 prop（`sidebarWidth`、`sidebarWidthMobile`、`sidebarWidthIcon`、`listWidth`、`paneWidth`）的默认值改为 0，表示"取组件 Token，再退回内置值"；`SAppShell.maxContentWidth` 默认改为 undefined（显式 0 仍表示不限宽）。显式传值的调用方行为不变

### 5. 运行时

- `SparkUI.themes.setVariable('--card-border-width', '0')` 写入 overrides，会随主题一起导出。
- 新增 `removeVariable(name, block?)`：删除覆盖值，恢复为配方值。
- 新增 `variable(name, block?)`：读取当前的覆盖值。

### 6. Token 目录（已接入的组件）

| 组件 | Token |
|---|---|
| 全局 | `--border-width`；`--overlay-backdrop`（模态遮罩，默认 black/50） |
| button | `radius` `height[-sm/-lg]` `padding-x[-sm/-lg]` `gap` `font-size` `icon-size` `border-width` `font-weight` `pressed-scale` `shadow`；各变体（default/destructive/outline/secondary/ghost/link）有 `background` `foreground` `border-color` `hover-background` `pressed-background`；非默认变体另有 `border-width` `shadow` |
| card | `radius` `border-width` `padding` `padding-sm`；各变体（default/outline/elevated/ghost/filled）有 `background` `border-color` `hover-background` `pressed-background` `shadow` `hover-shadow` |
| input（同时作用于 textarea、input-group、number-field、tags-input 的配色） | `background` `foreground` `placeholder-color` `border-color` `focus-border-color` `invalid-border-color` `ring-color` `invalid-ring-color` `radius` `border-width` `ring-width` `height[-sm/-lg]` `padding-x` |
| badge | `radius` `border-width` `padding-x` `font-weight`；各变体有 `background` `foreground` `border-color`（只作用于实心样式；soft 样式跟随状态 Token） |
| alert | `radius` `border-width` `padding-x` `padding-y`；各变体有 `background` `foreground` `border-color` `description-color` |
| dialog | `background` `border-color` `overlay` `radius` `border-width` `padding` `max-width` `shadow` |
| drawer | `background` `border-color` `overlay` `radius` `border-width` `padding` `shadow` `handle-background` `handle-width` `handle-height` |
| sheet | `background` `border-color` `overlay` `border-width` `padding` `shadow` |
| popover / menu | `background` `border-color` `radius` `border-width` `padding` `shadow` |
| select（→ menu）/ combobox（→ popover） | `background` `border-color` `radius` `border-width` `padding` `shadow` `highlight-background` `highlight-foreground` `max-height`（见 D14 §3） |
| tabs | `list-background` `list-radius` `list-padding` `height` `indicator-background` `indicator-border-color` `indicator-border-width` `indicator-radius` `indicator-shadow` `trigger-foreground` `trigger-active-foreground` |
| toggle / toggle-group | `hover-background` `hover-foreground` `on-background` `on-foreground` `border-color` `radius` `border-width` `height[-sm/-lg]` `shadow`；`--toggle-group-indicator-background` |
| switch | `background` `checked-background` `thumb` `checked-thumb` `shadow` |
| checkbox | `background` `border-color` `checked-background` `checked-border-color` `checked-foreground` `radius` `border-width` |
| progress | `indicator-background` `track-background`（仅 default tone）`height` `radius` |
| toast | `background` `foreground` `description-color` `border-color` `radius` `border-width` `padding` `shadow` |
| tooltip | `background` `foreground` `radius` |
| code（SCodeBlock） | `background` `foreground` `keyword` `string` `comment` `number` `decorator` `type` `function` `property` `punctuation` `variable` `tag` `attribute` `regex` `meta` `inserted` `deleted`（未设置时取 `SparkCodeTheme.github()` 的值；没传 `codeTheme` 的代码块会跟随这些 Token） |
| sidebar（SSidebar 家族） | `background`（默认语义 `--sidebar`）`border-color`（默认 `--sidebar-border`）`border-width` `width` `width-mobile` `width-icon`（rail 宽）`frame-gap` `menu-foreground` `menu-hover-background` `menu-active-background` `menu-active-foreground` `menu-outline-background` `menu-radius` `menu-height[-sm/-lg]` `menu-pressed-opacity` `group-label-color` `floating-radius` `floating-shadow` `inset-background` `inset-radius` `inset-shadow` `sheet-shadow`。`--sidebar`、`--sidebar-foreground`、`--sidebar-primary(-foreground)`、`--sidebar-accent(-foreground)`、`--sidebar-border`、`--sidebar-ring` 仍是语义 Token（先匹配），是上述 Token 的基础值 |
| topbar | `background` `translucent-background` `translucent-blur` `border-color` `border-width` `title-color` `subtitle-color` `height` `height-condensed` `padding-x` `padding-x-condensed` |
| titlebar（STitleBar） | `background` `translucent-background` `translucent-blur` `border-color` `border-width` `title-color` `height`（指针）`height-touch` `caption-size` `caption-radius` `caption-foreground` `caption-hover-background` `caption-pressed-background` `close-hover-background` `close-hover-foreground` `close-pressed-background` |
| app-shell | `content-max-width` `content-padding` |
| list-detail | `divider-color` `list-background` `detail-background` `list-width` `header-height` `detail-shadow` |
| supporting-pane | `divider-color` `divider-width` `background` `width` `sheet-background` `sheet-radius` `sheet-shadow` `handle-background` |
| dashboard tile | 复用 card（`SDashboardTile({ variant, tokens: CardTokens })`） |

遮罩颜色按以下顺序解析：
1. `--<浮层 motion key>-overlay`，如 `--dialog-overlay`、`--sheet-overlay`、`--drawer-overlay`
2. `--overlay-backdrop`
3. `#80000000`

### 7. 约束

- 按压态规则不变。Token 只改变配方的数值；pressed 仍只经 `applyPressedAttribute` / `stateStyles` 生效，不加动画。
- 背景被重新着色时（实例或 Token 改了 `background`），hover / pressed 层级从新颜色派生。显式设置了 `hover-background` / `pressed-background` 时，以设置值为准。

---

## D14. 长列表虚拟化（用户要求"长列表懒加载很重要"，2026-10-12）

### 1. 选型：`List` + `Repeat(...).virtualScroll()`

调研依据：`devecocli docs`《Repeat：可复用的循环渲染》、List API。

| 方案 | 结论 |
|---|---|
| `ForEach` | 一次性创建全部子组件，只是按需布局。长列表不可用，库中原有实现都是这种 |
| `LazyForEach` + `IDataSource` | 可行（V1/V2 都支持），但需要手写数据源和 `notifyDataAdd/Change…`，与 V2 的 `@Trace` / `@Computed` 数组模型重复 |
| **`Repeat` + `.virtualScroll()`** | **采用**。API 12 起可用（工程为 22），官方指南明确"懒加载模式需要和状态管理 V2 配合使用""推荐使用 V2 装饰器"。直接吃数组（含 `@Computed` 派生数组），数组变化自动 diff；自带节点复用池（API 18 起可关），复用优先于 `@ReusableV2`，所以不再另加 `@ReusableV2` |

官方约束（照搬到实现中）：

- 只能放在 `List` / `ListItemGroup` / `Grid` / `Swiper` / `WaterFlow` 中，且容器内只放这一个 `Repeat`。每项根节点是 `ListItem`。
- `.key()` 必须稳定且唯一，不要用 index（除非数据本身没有身份）。
- **嵌在同向滚动容器里、又没有主轴尺寸的 List 会全量加载**（List 文档）。所以每个虚拟列表都必须有确定的高度：选项列表按行高算出显式高度；表格在行数肯定溢出视口时用 `constraintSize({ minHeight = maxHeight })` 固定高度。
- 传给子组件时传 `ri.item`（对象引用）给 `@Param`，不要把 item 的字段拆成 `@Builder` 的原始参数（按值捕获，复用后不刷新）。
- 复用：被滚出的节点进缓存池，不触发 `aboutToAppear`/`onDidBuild`。因此**虚拟行不能依赖 `onDidBuild` + `SparkContext` 注册**（复用后注册的是旧值），行组件只接收 `@Param`。

### 2. 落地

- 原语 `primitives/list/`：
  - `SparkOptionLogic.ets`（纯逻辑，有单测）：`SparkOptionSource`（`SparkSelectOption` 实现它）、`SparkOptionEntry`（选项行或分组标题行，key 为 `o:<value>` / `g:<起始下标>`，过滤后 key 不变，Repeat 复用而非重建）、`sparkOptionEntries(options, match?)`（O(n) 展平 + 过滤，无匹配的分组不出标题）、`sparkOptionStep`（↑/↓ 跳过标题与禁用项、循环）、`sparkOptionListHeight` / `sparkOptionSizes`。
  - `SparkOptionList.ets`：`List` + `Repeat.virtualScroll()` + 两个模板（option / label）。显式高度 = 行高之和，封顶 `maxListHeight`；`childrenMainSize` 给出每行精确高度（滚动条和 `scrollToIndex` 准确）；`initialIndex` 打开即定位到已选项；`highlighted` 变化时 `scrollToIndex(i, false, ScrollAlign.AUTO)`。行 `SparkOptionRow` 是选择型行：按下只降不透明度（stateStyles，无动画），激活走原生 `onClick` + Enter（`sparkIsEnterUp`），无障碍角色 `OPTION`。
- **SSelect**：数据模式（`options`）改为虚拟列表，不再在隐藏副本里把选项再建一遍（标签直接由 `registerAll(options)` 一次登记）。复合模式（插槽）无法虚拟化，保持原样，文档建议长列表用 `options`。列表高度不超过浮层放置可用高度（`sparkMenuPanelMaxHeight`）。
- **SCombobox**：不再借用 SCommand（它把所有项建出来再 `Visibility.None`）。自带搜索框 + 虚拟列表：`@Computed entries = sparkComboboxEntries(options, query)`（cmdk 打分 `sparkCommandScore`，label 为主、value 为关键词），**不匹配的项根本不构建**，匹配项也只构建可见的；↑/↓（`onKeyPreIme`）移动高亮，Enter（`onSubmit`）选中。
- **STable 数据模式**（`rows`）：表头 / 表尾是普通行，表体是 `List` + `Repeat`。行组件 `SparkTableDataRow` 直接接收 table state，单元格是普通 Text，不做任何 SparkContext 注册。新增 `bodyHeight`（视口高度；未设时 ≤50 行跟随内容，>50 行默认 480vp）和 `rowKey`（默认行下标）。表体在视口内滚动（`nestedScroll SELF_FIRST`，滚到头再交给页面），表头固定。
- **STable 插槽模式的 O(N²)**：`SparkTableMembers` 原来每注册一行都要复制并排序 `@Trace ids`，并让所有行重算 `lastInSection`。现在 ids 是普通有序数组（二分插入），"是否最后一行"改为每成员一个 `@Trace` 标志，增删一行只翻转两个标志；`SparkTableState` 的 `widths/total/cards/scrolls` 改为 `@Computed` 缓存。
- **不改的**：`SScrollArea`（只是滚动容器，内容由使用者决定；长列表请在里面直接用 `List` + `Repeat`，不要用 SScrollArea 包 ForEach）；AppShell / Sidebar 导航（几十项、与插槽内容混排在同一个 Scroll 里，虚拟化收益小）。
- **SCommand 迁移方案**（由 a11y 负责人实施）：增加数据模式 `SCommand({ items: SparkCommandItemData[] })`，`@Computed` 过滤后展平为 `SparkOptionEntry`（或带 icon/shortcut 的扩展行），用 `SparkOptionList`（或同构的 List + Repeat）渲染；高亮 / ↑↓ / Enter 都按值操作数据数组（`sparkOptionStep`），不再依赖 `CommandEntry` 注册表和 frame-node 位置测量来滚动（改用 `scrollToIndex`）。插槽模式保留给短列表。

### 3. 选项浮层的组件 Token（D13 补充）

- `--select-*` 和 `--combobox-*`：`background` `border-color` `radius` `border-width` `padding` `shadow` `highlight-background` `highlight-foreground` `max-height`；实例覆盖 `tokens: SparkOptionPanelTokens`（`SSelect` / `SSelectContent` / `SCombobox`）。
- **家族回退**：Select 面板与 DropdownMenu 同属菜单表面，`--select-*` → `--menu-*` → 配方；Combobox 是 Popover + Command，`--combobox-*` → `--popover-*` → 配方。实现为 `sparkSurface(t, component, defaults, tokens, inherit)` 的新参数 `inherit`，以及 `sparkOptionPanel()`。这样一个主题写 `--menu-background` 就能统一所有菜单类浮层，写 `--select-*` 只改 Select。
- 高亮行和 `max-height` 只读组件自己的 Token（`menu` / `popover` 没有这些属性）。

### 4. 需要真机确认

- 1 000 项 Select / Combobox 打开无卡顿、打开即定位到已选项；快速滑动无白块（`cachedCount(4)`）。
- 10 000 行表格：首屏、滚动流畅；窄屏卡片模式下也只构建可见卡片；表体滚到底后继续拖动能带动页面滚动。
- Combobox 打开后搜索框获得焦点（现在只靠 `defaultFocus`，不再用 `setTimeout(0)` 请求焦点）。
