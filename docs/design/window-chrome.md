# 窗口标题栏（Window Chrome）调研与方案

> 状态：调研完成 + 首版实现（2026-10-12），**尚未真机验证**。所有结论来自本机 `devecocli docs`（HarmonyOS 官方离线文档）。工程 compatibleSdk 为 22，下文"NN+"表示起始 API 版本；本文用到的接口都 ≤ 22。
> 实现：`library/src/main/ets/blocks/titlebar/`（`SparkWindowChrome`、`STitleBar`、`TitleBarLogic`）；示例：`gallery/src/main/ets/docs/TitleBarDocs.ets`。

参考文档（`devecocli docs read <id>`）：
- `API参考/ArkUI_方舟UI框架/ArkTS_API/窗口管理/ohos_window_窗口_/Interface_Window/arkts-apis-window-window`
- `API参考/.../ohos_window_窗口_/Interfaces_其他/arkts-apis-window-i`（TitleButtonRect、DecorButtonStyle）
- `API参考/.../ohos_window_窗口_/Enums/arkts-apis-window-e`（WindowStatusType、MaximizePresentation）
- `开发指南/ArkUI_方舟UI框架/窗口管理/窗口模式/自由窗口/自由窗口简介/freeform-window-overview`
- `开发指南/ArkUI_方舟UI框架/窗口管理/窗口模式/自由窗口/应用适配自由窗口/application-adaptation-freeform-window`
- FAQ：`FAQ/电脑/常见问题/自由窗口下如何自定义窗口标题栏/faqs-computer-14`、`.../自由多窗模式下_应用页面与标题栏三键区域重叠/faqs-computer-5`、`.../PC应用如何隐藏导航栏右上角三键/faqs-computer-7`、`FAQ/UI框架/窗口管理/如何判断当前是否处于自由多窗及监听自由多窗切换/faqs-arkui-1596`

---

## 1. 背景：什么时候会有系统标题栏

"自由窗口"是可以自由移动、缩放、层叠的窗口状态。自由窗口的主窗口默认带系统标题栏：左侧是应用图标，右侧是"三键"（最大化/还原、最小化、关闭）。拖动标题栏可以移动窗口，拖动窗口边缘可以缩放。

| 设备 | 何时是自由窗口 |
|---|---|
| PC/2in1 | 默认就是自由窗口 |
| Tablet | 部分机型在控制中心开启"自由多窗"或"电脑模式"后 |
| Phone | 部分机型在控制中心开启"自由多窗"后 |
| 其余情况 | 不是自由窗口：没有标题栏，下文的 decor 类接口不生效或返回 801 |

**窗口尺寸包含标题栏**：标题栏可见时，内容区在标题栏下方，两者不重叠。用 `setWindowDecorVisible(false)` 隐藏标题栏后，内容区铺满整个窗口，**但三键仍然显示，会"下沉"到页面区域里，盖在内容上面**（FAQ faqs-computer-5）。所以隐藏标题栏后有两种选择：

- 用 `getTitleButtonRect()` 或 `on('windowTitleButtonRectChange')` 拿到三键的矩形，让开这块区域；
- 或者用 `setWindowTitleButtonVisible(false, false, false)` 把三键也隐藏，自己画。

## 2. API 矩阵

"自由窗口限定"指：只在支持且处于自由窗口状态的设备上生效。其余情况要么"不报错不生效"，要么返回 801，各接口不同，见"非自由窗口时"一列。

| 接口 | API | 作用 | 非自由窗口时 | 备注 |
|---|---|---|---|---|
| `setWindowDecorVisible(b)` | 11 | 显示或隐藏系统标题栏 | 不报错不生效，**切换到自由窗口后生效** | 必须在 `loadContent`/`setUIContent` 生效后调用。隐藏后三键会下沉到页面区域。全屏时鼠标悬停在顶部仍会出现悬浮标题栏 |
| `getWindowDecorVisible()` | 18 | 查询标题栏是否可见 | 801 | |
| `setWindowDecorHeight(h)` | 11 | 设置标题栏高度，整数，范围 [37,112] vp | 不报错不生效，切换后生效 | 隐藏标题栏后，这个值仍然决定三键所在区域的高度（FAQ 示例在隐藏后设为 56） |
| `getWindowDecorHeight()` | 11 | 查询标题栏高度（vp） | 不支持自由窗口的设备上不生效也不报错 | 与设置值可能相差 1vp |
| `getTitleButtonRect()` | 11 | 三键矩形 `{right, top, width, height}`，单位 vp，**相对窗口右上角** | 801 | |
| `on/off('windowTitleButtonRectChange')` | 11 | 三键矩形变化的回调 | 801 | 必须在 loadContent 之后注册 |
| `setWindowTitleButtonVisible(max, min, close?)` | 14 | 分别控制三键各自是否可见 | **801**（必须在自由窗口中调用，切换后要重新调用） | 只支持主窗和独立子窗。最大化按钮隐藏后，"还原"按钮也一起隐藏 |
| `setDecorButtonStyle(style)` | 14 | 设置三键样式 | 801（HarmonyOS 5.1.0 之前只有 PC 可用） | 字段见下 |
| `getDecorButtonStyle()` | 14 | 读取三键样式 | 801 | |
| `setWindowTitleMoveEnabled(b)` | 14 | 关闭系统标题栏默认的拖动移动和双击最大化 | 801 | 用于"保留系统标题栏，但移动和最大化交给应用"的场景 |
| `setWindowTitle(name)` | 15 | 设置系统标题栏上的标题文字 | — | 只在保留系统标题栏时有意义 |
| `setTitleAndDockHoverShown(title?, dock?)` | 14 | 全屏时鼠标悬停是否显示标题栏和 Dock | 801 | |
| `startMoving()` | 14 | 开始拖动窗口 | 主窗返回 801 或 1300004 | **只有在 `onTouch` 回调里调用才有效**：事件类型为 Down，或者在 Down 之后的 Move。之后窗口跟随指针移动 |
| `startMoving(offsetX, offsetY)` | 15 | 同上，并指定指针在窗口内的位置（px） | 801 | 用于窗口分合的场景 |
| `stopMoving()` | 15 | 中止拖动 | 801 | |
| `minimize()` | 11 | 主窗最小化 | — | PC 上通过 Dock 或 `restore()` 恢复 |
| `maximize(presentation?)` | 12（22 增加 `acrossDisplay`） | 最大化 | 不报错不生效 | **不传参数时默认是 `ENTER_IMMERSIVE`，即进入全屏**。想保留标题栏和 Dock，要传 `EXIT_IMMERSIVE` |
| `recover()` | 11 | 从全屏、最大化或分屏还原成悬浮窗（FLOATING） | 801 | 已经是悬浮窗时再调用会报 1300001 |
| `restore()` | 14 | 把**最小化**的主窗恢复到前台 | 只在 PC 和平板电脑模式下可用 | 不是"取消最大化"，那个要用 `recover` |
| `getWindowStatus()` | 12 | 查询窗口状态 | — | targetAPIVersion ≥ 14 时，最大化返回 MAXIMIZE；< 14 时返回 FULL_SCREEN |
| `on('windowStatusChange')` | 11 | 状态变化回调 | — | 回调时窗口 rect 可能还没更新，调用 maximize 或 recover 时会收到多次回调 |
| `on('windowStatusDidChange')` | 20 | 状态变化完成后回调（rect 已更新，已去重） | 801 | **推荐使用这个**，SparkLayoutMonitor 也用它 |
| `isInFreeWindowMode()` / `on('freeWindowModeChange')` | 22 | 查询或监听是否处于自由窗口 | — | 22 之前只能读 settings 中的 `window_pcmode_switch_status` |
| `setResizeByDragEnabled(b)` | 14 | 是否允许拖动边缘缩放 | 不生效 | |
| `setWindowLimits` / module.json5 `min/maxWindowWidth/Height` | 11 | 限制自由窗口尺寸 | — | 系统限制、配置和运行时设置三者取交集 |
| `setWindowShadowEnabled(b)` | 20 | 主窗阴影 | 6.1.0 之前只有 PC 可用 | **需要权限 `ohos.permission.SET_WINDOW_TRANSPARENT`** |
| `setWindowCornerRadius` / `setWindowShadowRadius` | 17 | 圆角 / 阴影半径 | — | **只支持子窗和全局悬浮窗，主窗返回 1300004**。主窗的圆角和阴影由系统决定 |
| `setSupportedWindowModes(modes)` | 26 | 运行时设置窗口支持的模式 | — | **超出 SDK 22，不能用**。改用 module.json5 中的 `supportWindowMode`（`fullscreen` / `split` / `floating`） |

`DecorButtonStyle`（14+）的字段：

| 字段 | 范围 | 默认值 |
|---|---|---|
| `colorMode` | — | 跟随系统；深色模式下按钮为浅色 |
| `buttonBackgroundSize` | [20,40] vp | 28 |
| `spacingBetweenButtons` | [8,24] vp | 12 |
| `closeButtonRightMargin` | [6,22] vp | 20 |
| `buttonIconSize`（20+） | [16,24] vp | 20 |
| `buttonBackgroundCornerRadius`（20+） | [4,8] vp | 4 |

**颜色只能选深色或浅色**，不能用主题色，也不能改 hover 颜色。

`WindowStatusType` 的取值：

| 值 | 含义 |
|---|---|
| FULL_SCREEN | 自由窗口下铺满屏幕，没有 Dock 和标题栏；悬停到热区时可以显示 |
| MAXIMIZE | 只出现在自由窗口中：铺满屏幕，Dock、状态栏、标题栏都可见 |
| MINIMIZE | 最小化 |
| FLOATING | 悬浮窗 |
| SPLIT_SCREEN | 分屏 |

关闭窗口：主窗没有"关闭窗口"接口。官方 FAQ 的做法是 `UIAbilityContext.terminateSelf()`。

## 3. 设备差异

- **PC/2in1**：始终是自由窗口，指针操作。点系统的最大化按钮时，窗口进入 MAXIMIZE，标题栏和 Dock 保持可见。
- **平板（自由多窗 / 电脑模式）**：窗口在运行时可能在"自由"和"非自由"之间切换。
  - `setWindowTitleButtonVisible` 和 `setDecorButtonStyle` 在非自由窗口时会抛 801，而且**切换到自由窗口后不会自动补上，必须在 `freeWindowModeChange` 里重新调用**。
  - `setWindowDecorVisible` 和 `setWindowDecorHeight` 的设置会被记住，切换后自动生效。
  - 平板上多是触屏操作：标题栏要更高，按钮热区要更大。
  - `restore()` 只在电脑模式下可用。
  - 切换自由多窗时，状态栏和导航条的避让区会变化，FAQ faqs-arkui-1596 有说明。SparkLayoutMonitor 已经在监听 `avoidAreaChange`。
- **手机**：大多数情况下不是自由窗口，此时所有接口都是空操作或返回 801，标题栏自动隐藏。
- **沉浸式**（D10，`setWindowLayoutFullScreen(true)`）在自由窗口里和标题栏是什么关系，文档没有写，需要真机确认。预期是：自由窗口中系统避让区为 0，标题栏仍然占据内容区的上方。

## 4. 方案比较

| 方案 | 做法 | 优点 | 缺点 |
|---|---|---|---|
| A. 保留系统标题栏，只改按钮样式 | `setDecorButtonStyle`（+ `setWindowTitle`） | 零风险，行为和系统完全一致 | 标题栏占一整行，放不下应用内容。颜色只能选深色或浅色，和主题不统一 |
| **B. 隐藏标题栏，保留系统三键（'keep'）** | `setWindowDecorVisible(false)`，用 `setWindowDecorHeight` 让三键和我们的标题栏等高，用 `setDecorButtonStyle` 调整尺寸、圆角和深浅色，按 `titleButtonRect` 在右侧留出位置 | 三键的行为（悬停布局菜单、还原、关闭确认等）由系统保证；标题栏的其余部分都是 SparkUI 风格 | 三键的颜色只能选深色或浅色 |
| **C. 隐藏标题栏和三键，完全自绘（'custom'）** | 再调用 `setWindowTitleButtonVisible(false,false,false)`，自绘最小化、最大化/还原、关闭按钮 | 风格完全统一，按钮尺寸能跟随触屏或指针调整 | 失去系统三键的附加能力（例如悬停最大化按钮时的分屏布局菜单）；关闭只能 `terminateSelf` |
| D. 完全不要三键（'hidden'） | 同 C，但不画按钮 | 适合 kiosk 或演示类应用 | 用户只能靠系统手势或 Dock 关闭窗口 |

**推荐**：库默认用 C（'custom'），满足"统一风格"的诉求；同时提供 B（'keep'），给需要系统三键附加能力的应用。两者都通过同一个 `STitleBar` 实现，只是 `systemButtons` 参数不同：

- 拖动：在标题栏空白处的 `onTouch` 中，在 Down 之后的第一次 Move 时调用 `startMoving()`，这是官方示例的写法。这样双击（`TapGesture({ count: 2 })`）不会被拖动吞掉。
- 双击：最大化或还原。MAXIMIZE 和 FULL_SCREEN 时调用 `recover()`，其余状态调用 `maximize(EXIT_IMMERSIVE)`。
- 插槽区域（leading / center / actions）和按钮都在自己的 `onTouch` 里 `stopPropagation()`，对应 Web 中 `-webkit-app-region: no-drag` 的效果。注意：这里的 `onTouch` 只负责阻止冒泡，**不驱动按压态**。按压态仍然走 `applyPressedAttribute`，见组件规范第 3 节。
- 状态为 FULL_SCREEN 或 MINIMIZE、不是自由窗口、或在手机上时，标题栏不渲染。全屏时由系统的悬浮标题栏接管。

## 5. 实现（首版）

### `SparkWindowChrome`（单例 `SparkWindowChrome.shared`，`@ObservedV2`）

- 状态（`@Trace`）：
  - `attached`、`freeWindow`、`status`（`'fullscreen'|'maximized'|'minimized'|'floating'|'split'|'unknown'`）
  - `decorVisible`、`decorHeight`、`titleButtonRect`（vp）
  - `systemButtons`（当前生效的模式；`'system'` 表示没有标题栏占用窗口）
  - `deviceType`
- getter：`isFloating`、`isMaximized`、`isFullScreen`、`owned`、`captionReserve`（'keep' 模式下右侧需要留出的宽度）。
- 绑定窗口：
  - `SparkWindowChrome.init(windowStage, context)`：**推荐**，在 EntryAbility 的 `loadContent` 回调里调用；
  - `attach(uiContext)`：懒绑定，通过 `findWindow(getWindowName())` 找到窗口；
  - 监听 `windowStatusDidChange`（20）、`freeWindowModeChange`（22）、`windowTitleButtonRectChange`（11）。
- 占用和归还：
  - `claim(owner, options)`：先保存原来的 decor 高度和按钮样式，再隐藏标题栏并应用 systemButtons。如果之后才进入自由窗口，会在 `freeWindowModeChange` 中重新应用。
  - `release(owner)`：恢复标题栏、三键、高度和按钮样式。只有当前占用者调用才生效，这样 if/else 切换两个标题栏时，旧标题栏后调用的 release 不会把新的覆盖掉。
- 动作：`minimize()`、`maximize(immersive?)`、`restore()`（内部调用 `recover`）、`toggleMaximize()`、`close()`（调用 `terminateSelf`）、`startMoving()`（必须在 onTouch 中调用）。所有调用都包在 try/catch 里，并处理 Promise 的 catch，非自由窗口时什么也不做。
- **没有修改** SparkProvider 和 SparkLayoutMonitor：Monitor 继续维护 `env.windowMode`，本服务单独监听，两者互不影响。

### `STitleBar`

- 参数：
  - `title`、`icon`（lucide 图标名）或 `appIcon`（图片）
  - `systemButtons: 'keep'|'custom'|'hidden'`（默认 'custom'）
  - `showWhen: 'auto'|'always'`
  - `detached`：预览模式，不碰真实窗口
  - `barHeight`：0 表示自动，指针设备 40、触屏 48
  - `bordered`、`translucent`、`previewStatus`
  - `onCaption(action)`
- 插槽：`leading`、`center`，以及尾随闭包 `content`（右侧 actions）。
- 挂载时调用 `claim`，卸载时调用 `release`。监听 `theme.isDark`，变化时调用 `restyle`，让保留的系统三键跟随深浅色；高度变化时同步 decor 高度。
- 自绘的三键是 ghost 风格：28vp 的按钮底板、`radiusMd` 圆角，hover 时显示 accent 色，关闭按钮 hover 时显示 destructive 色。按压态用 `SparkRowPressModifier`（即 `applyPressedAttribute`），**不加任何动画**。最大化状态下最大化按钮换成还原图标（`copy`）。

### 已知限制和待确认

1. 首帧问题：如果没有调用 `init`，`claim` 会在首帧 `aboutToAppear` 中执行。这时 `loadContent` 可能还没有"生效"，decor 的设置有可能被忽略。**因此请在 EntryAbility 中调用 `init`**；`init` 会重新应用当前的 claim。
2. `TitleButtonRect.right` 的语义：文档写的是"右边界，相对窗口右上角"。实现中按"到窗口右边缘的距离"处理，留出宽度 = `width + right`。**需要真机核对**。官方示例只减去了 `width`。
3. 自绘按钮不提供系统最大化按钮悬停时的"分屏布局菜单"。需要这个能力的应用请用 'keep'。
4. 主窗的圆角和阴影无法定制：`setWindowCornerRadius` 只支持子窗，`setWindowShadowEnabled` 需要权限。
5. `setSupportedWindowModes` 需要 API 26，不能用。请在 module.json5 中配置 `supportWindowMode` 和 `minWindowWidth` 等字段。

## 6. 真机验证计划

**平板（MatePad，172.15.125.54:5555）开启自由多窗：**

1. 关闭自由多窗时打开 Title Bar 页：free window 显示 no，开关不可用。开启自由多窗后，free window 变为 yes，开关可用（验证 `freeWindowModeChange`）。
2. 打开 'custom' 模式并应用：系统标题栏和三键都应消失，顶部出现 STitleBar。逐项检查：
   - 拖动空白处窗口能跟随移动；
   - 拖动按钮、插槽不会移动窗口；
   - 双击最大化后再双击还原；
   - 最小化后能从多任务中恢复；
   - 关闭后应用退出；
   - 快速连续点击两个按钮，不会同时出现两个按压态。
3. 切换到 'keep'：系统三键出现在我们留出的位置，与标题栏垂直居中（decor 高度 48）。切换深色主题后三键变浅色。核对 `titleButtonRect` 的数值和留白宽度（限制第 2 条）。
4. 'hidden'：没有任何按钮。
5. 关闭开关：系统标题栏、三键、原来的高度和样式全部恢复。
6. 应用开关打开时关闭自由多窗：标题栏隐藏；再开启自由多窗：标题栏重新出现，且三键状态被重新应用。
7. 最大化后的状态：如果显示 'maximized'，标题栏保持。用系统手势进入全屏后，标题栏隐藏。

**PC/2in1（MateBook 模拟器或真机）：**

1. 重复第 2 到 5 步，用鼠标操作。确认 hover 时的背景色动画，以及关闭按钮的红色 hover。
2. 在 EntryAbility 加上 `init` 后冷启动并直接挂载 STitleBar：首帧就不应出现系统标题栏（验证限制第 1 条）。
3. 双击最大化后，Dock 和状态栏应该可见（EXIT_IMMERSIVE 的效果）。
4. 与 `SparkProvider({ immersive: true })` 一起使用时，确认 safeArea.top 为 0，没有多出的顶部留白。

截图使用 `tools/dev.sh shot`；按压测试使用 `tools/dev.sh press x y out.jpeg`。
