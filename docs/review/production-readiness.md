# SparkUI 生产就绪度审查

日期：2026-10-12 · 审查对象：`main`（daee251）加上工作区里其他 agent 正在改动的内容 · 方式：只读审查（通读 core/theme/layout/overlay，抽查约 60 个组件，规则 grep，运行构建和测试）

> 行号以审查时的文件为准。审查期间有其他 agent 在并行修改（例如 `SAlertDialog.ets` 已从 400 多行缩到 139 行），所以个别行号可能偏移，请以符号名为准。
> 路径省略前缀 `library/src/main/ets/`。

## 0. 结论

**现在不能作为 1.0 对外发布；可以作为 0.x 预览版，在内部或试点项目里使用。**

- 工程基础扎实：
  - 136 个文件静态检查 0 错误，debug 和 release 构建都成功，单元测试 143/143 通过。
  - 历史问题已有统一的规则落地（SparkAnim、applySync、按压态、非模态层按内容尺寸、SparkContext 的 provide/revoke），grep 没有发现回归。
  - 图表数学对空数据、NaN、零跨度都做了保护。
- 阻碍上线的主要有四类：
  1. 菜单类控件无法被读屏激活（无障碍硬伤）。
  2. 第 6 到 8 轮的大量行为还没有在真机上验证。
  3. 发布物料缺失：没有 LICENSE、README、CHANGELOG；签名配置被提交进仓库。
  4. 没有 UI 自动化测试，也没有 CI。
- 此外还有一批 P1 正确性问题（状态丢失、竞态、长列表性能、i18n），建议在 1.0 前修掉。

## 1. 检查结果

| 检查 | 结果 |
|---|---|
| `devecocli check arkts --project .` | 136 个文件，0 错误，1 个告警：`SparkThemeController.ets:241` 用到 `http`，需要 `ohos.permission.INTERNET` |
| `devecocli build`（debug，gallery HAP） | 成功 |
| `devecocli build --modules library --build-mode release` | 成功，产出 `library.har`（约 780KB）。有 ArkTS 告警：`STable.ets:297,307,317,560,582` 和 `SMenubar.ets:404` 的 `@BuilderParam` 没有用 @Builder 或 @LocalBuilder 初始化；`SPinInput.ets:89` 的 `TextInputController` 不是所有设备都支持（syscap）；另外提示没有开启混淆 |
| `bash tools/unit-test.sh` | 143/143 通过。只覆盖纯逻辑（颜色、主题 CSS、日期、分页、图表数学、Command 过滤、Blocks 逻辑、变体配方） |
| UI 测试 | 没有。`gallery/src/ohosTest` 只有模板用例（`assertContain`） |
| CI | 没有（不存在 `.github/` 或其他流水线配置） |

## 2. P0：上线前必须解决

### P0-1 菜单、Command、AlertDialog 和 NumberField 只能靠触摸激活，读屏和部分键盘场景完全不可用

- 现象：`SparkActivation` 用 `onTouch` 抬起来模拟点击，而读屏的"双击激活"发出的是 click 或无障碍动作，不是 touch。
- 受影响位置：
  - `primitives/menu/MenuRow.ets:115`：Dropdown、ContextMenu、Menubar、Select 的所有菜单项。
  - `components/command/SCommand.ets:674`：同时还设了 `focusable(false)`，Combobox 的选项也就选不了。
  - `components/alert-dialog/SAlertDialog.ets:114`：Cancel 只能用 onTouch 关闭，没有键盘路径。
  - `components/number-field/SNumberField.ets:189`：−/+ 声明了 `accessibilityRole(BUTTON)`，却没有 `onClick`。
- 修复：
  - 在同一节点上补 `.onClick`（或 `onAccessibilityActionIntercept`）作为激活入口，和 touch 路径去重：TouchDown 置标志，onClick 发现标志后跳过。
  - 补上 `accessibilityRole`（菜单项、选项）。
  - 第 7 轮文档已把 `SparkActivation` 列为"待替换的非官方写法"，建议这次一起改成官方方案：`parallelGesture(TapGesture)`，或者把 onClick 放到同一节点上。

### P0-2 第 6 到 8 轮的改动没有经过真机验证

- `docs/iterations/round-06/07/08` 都写着"真机验证待做"。待验证的内容包括：
  - Accordion 动画、Tabs 和 ToggleGroup 指示器、Tooltip 长按
  - Toast 堆叠和期间页面可操作
  - 图表入场和形变、Progress 环形和条纹、Slider 范围模式
  - Sidebar 的折叠和 sheet、"按压不残留"
- 这几轮修的恰恰都是"只有真机才能复现"的问题（按压残留、V2 动画时序、非模态层拦截触摸）。没验证就发布，回归风险很高。
- 修复：按 `tools/dev.sh` 逐项走一遍清单，并把截图结果写回 iteration 文档。

### P0-3 发布物料和仓库卫生

| 问题 | 位置 | 修复 |
|---|---|---|
| 没有 LICENSE，但 `oh-package.json5` 写着 `"license": "MIT"` | 仓库根目录、`library/` | 加 `LICENSE`。ohpm 发布要求 HAR 根目录同时有 README.md、CHANGELOG.md 和 LICENSE |
| 没有 README、CHANGELOG，`author` 为空 | `library/oh-package.json5` | 补齐；README 写清楚安装、`SparkProvider` 用法、最低 API 22、权限说明 |
| **签名配置提交进了 git** | `build-profile.json5:3-14`：`signingConfigs` 里有 `storePassword`、`keyPassword`（DevEco 加密串）以及指向 `C:\Users\Okysu\.ohos\config\*.p12/.cer` 的绝对路径 | 把 signingConfigs 移出版本库：用模板文件，或者让各开发者自己生成；把 `build-profile.json5` 中的签名部分改为本地覆盖。虽然是 debug 证书，但其他人或 CI 拿到仓库无法构建；一旦把仓库公开，就等于泄露了签名材料。同时建议在 AGC 轮换这份调试证书 |
| 编译缓存进了 git | `.cache/.tsbuildinfo`、`.cache/.tsbuildinfo.linter`（每次构建都会变脏） | 加到 `.gitignore`，再 `git rm --cached` |
| `docs/screenshots` 有 11MB 的 PNG | — | 移到 git LFS 或 release 附件 |

## 3. P1：1.0 前应修

### 3.1 正确性

1. **Spinner 和按钮的 loading 绕过了 SparkAnim，还可能不转**
   - 位置：`components/spinner/SSpinner.ets:32-37`、`components/button/SButton.ets:120-127`。
   - 两处都直接调用 `animateTo({ duration: 1000, iterations: -1 })`：既写死了时长，也不受 `--motion-*` 和全局关闭开关控制。
   - 重置语句 `angle = 0` 没有先提交。按 V2 的标脏时序，第二次进入 loading 时 0→360 会被合并成"没有变化"，图标就不转了。
   - 修复：像 `SProgress.ets:423` 那样改用 `SparkAnim.loop(..., reset, change, false, 'linear')`。
2. **非受控的菜单勾选项和单选组，每次打开菜单都会被重置**
   - 位置：`SDropdownMenu.ets:244-249, 303-306`、`primitives/menu/SparkMenuParts.ets:238-243, 293-296`。
   - 原因：浮层内容每次 open 都重新构建 ComponentContent，`@Local current` 随之丢失，所以 `defaultChecked` 和 `defaultValue` 只在第一次打开时有效。
   - 修复：把非受控值放到菜单根状态里（根状态在浮层之外），或者像 Radix 那样只提供受控 API。
3. **Calendar 翻月有竞态**
   - 位置：`components/calendar/SCalendar.ets:530-560`。
   - 动画进行中再点一次"下一月"，`navigate` 会立即 `applyView(M+2)`；第一段动画的 onFinish 随后又 `applyView(M+1)`。结果是第二次点击丢失，`onMonthChange` 也会重复触发。
   - `:512` 和 `:551` 还用了 `setTimeout(0)`（组件规范 §3.5 禁止），而且没有在卸载时清理。
   - 修复：记录 pending delta，在 onFinish 里统一计算目标月；用 `SparkAnim.commit` 代替 `setTimeout(0)`。
4. **disabled 不生效**
   - `SSelect.ets:39`：`SparkSelectState.disabled` 没有加 `@Trace`，触发器的透明度不会更新，而且始终 `focusable(true)`。
   - `SInputGroup.ets:226,249-255`：group 设为 disabled 时，`SInputGroupButton` 依然可以点击、可以获得焦点。
5. **受控 AlertDialog 无法拒绝关闭**
   - 位置：`SAlertDialog.ets:56-58`。在 `$open` 回调里先执行了 `this.opened = v`，父组件单向传入 `open` 时无法阻止关闭。
   - 关闭后父组件的 `open` 仍是 true，`@Monitor('open')` 不再触发，导致无法再次打开。
6. **浮层生命周期**
   - `primitives/overlay/SparkOverlay.ets:222`：`closeCustomDialog` reject 时，`closing.finally()` 返回的 promise 没人 catch，会产生未处理的 rejection。修复：改成 `.then(cleanup, cleanup)`。
   - `core/SparkContext.ets:99-111`：`whenAttached` 重试 20 次以后，即使节点一直没挂上也会执行 `fn`；组件已经卸载时也照样执行。后果是 `SCommandItem` 在注销之后又注册回去，留下一个按 Enter 仍能选中的"幽灵项"，浮层 binding 也会在 dispose 之后再 attach。修复：在 `aboutToDisappear` 里置 `alive=false`，执行 fn 前先检查。
   - `SMenubar.ets:545-548`：菜单在打开状态下被卸载时，`unregister` 没有重置 `openId`，代理层一直挡在菜单栏上，菜单栏随之失效。
   - `SDrawer.ets:191-195`：拖拽关闭被受控方拒绝后，`closing` 一直是 true，之后所有拖拽都被忽略。
7. **列表顺序依赖组件 uid 的创建顺序**
   - `STable.ets:44-60, 335-366`：中途插入或前插的行、通过 `if` 后出现的单元格，`isLast` 或列序号会算错。
   - `SCommand.ets:87`：同样的问题导致 ↑/↓ 的顺序错乱。`:92-98` 的 `unregister` 也没有调用 `ensureHighlight()`。
8. **数据驱动的块不会刷新**
   - `SAppShell.ets:404-409` 的 ForEach 只用 `item.id` 作 key，而 `SparkShellNavItem` 是普通类。id 不变时，badge 和 title 的更新不会显示。
   - `STopbar.ets:191` 的 key 没有包含 label。
   - 这和最近 Gallery 提交里修的是同一类问题。修复：把相关字段拼进 key，或者把这些类改成 `@ObservedV2`/`@Trace`。

### 3.2 性能

9. **库里没有任何 LazyForEach 或虚拟化**（grep 结果为 0），长列表会全部同步构建：
   - Select：`SSelect.ets:131,304-310`，选项会构建两遍（一份隐藏副本，一份面板）。
   - Command 和 Combobox：`SCombobox.ets:164-176`，所有项都构建出来再用 `Visibility.None` 隐藏，过滤复杂度是 O(项数×分组数)。
   - Table 数据模式（`STable.ets:169-177`）：每添加一行都要复制并排序 `@Trace ids`，触发所有行的 `lastInSection` 重算，总体是 O(N²)。`widths` 没有缓存；key 里带了下标，前插一行就会重建整张表。
   - 修复：Table 和 Command 提供基于 `List` 加 `LazyForEach` 或 `Repeat` 的数据模式；`widths` 改成 `@Computed`；key 用数据本身。
10. **长菜单超出屏幕**
    - `Placement.compute` 已经算出了 `availableHeight`（`Placement.ets:169`），但没有地方使用。
    - Dropdown、ContextMenu、Menubar 的面板都没有 Scroll，也没有最大高度。
11. **主题刷新的开销**
    - `SparkThemeController.refresh` 每次都会对全量 token 执行 `copyFrom`；V2 对没变化的基本类型值不会通知，所以这一点问题不大。
    - 但每次刷新都会全局调用 `ThemeControl.setDefaultTheme`，而 `SparkAnim.attr()` 每次 build 都会重新解析曲线。
    - 建议在真机上用 Profiler 对比：100 个组件的页面切换主题和动效预设时的帧耗时。

### 3.3 国际化（面向中文用户，属于 P1）

12. **没有字符串表**
    - 几十处硬编码英文，读屏会对中文用户念英文。主要有：
      - 通用和浮层：`'Close'`、`'Cancel'`/`'Continue'`、`'Select…'`、`'No results'`
      - 分页和控件：`'Previous'`/`'Next'`/`'More pages'`、`'Loading'`、`'No data'`、`'Clear'`、`'Remove'`、`'Copy code'`、`'Back'`
      - 状态描述：`'expanded'`/`'collapsed'`、`'disabled'`/`'mixed'`、`` `Page ${p}, current` ``、`` `Step ${n}` ``
    - `SparkDate` 只支持 `'en' | 'zh'`；`sparkChartFormat` 把千分位、k/M/B 写死了，|v|≥1e21 时会输出指数形式。
    - 修复：新增 `SparkUI.locale` 或 `SparkStrings`，提供可覆盖的文案表，默认跟随系统语言；数字格式化改用 `Intl.NumberFormat`。

### 3.4 API 稳定性和测试

13. **对外 API 面过大**
    - `Index.ets` 导出了 121 个符号，其中包括被认定为 hack 的内部实现：`SparkActivation`、`OverlayBinding`、`OverlayConfigurator`、`SparkContext`、`MenuRow`、`SparkSelection`。
    - 一旦发布，这些都要受 semver 约束。
    - 修复：1.0 前划分 public 和 internal（例如单独的 `@sparkui/core/internal` 入口，或者不导出），并写一份版本策略：0.x 期间允许破坏性变更，从 1.0 起严格遵循 semver，配合 CHANGELOG。
14. **测试覆盖**
    - 目前只有纯逻辑单测。最容易回归的部分都没有自动化测试：受控/非受控同步、浮层开关和卸载、按压态、V2 动画时序。
    - 修复：
      - 在 `library/src/ohosTest` 里用 Hypium 加 `@ohos.UiTest`（Driver/ON），针对 gallery 页面写冒烟用例：每个组件打开、点击、关闭，并断言没有残留浮层。
      - 关键交互的回归项可以截图比对。
      - 搭 CI：先跑 `check arkts`、构建、单测，有条件再接模拟器跑 UI 测试。

## 4. P2：建议改进

### 正确性和健壮性

- **主题从网络加载**（`theme/SparkThemeController.ets:238-251`）：
  - 不限制协议，允许 `http`（明文传输，可被篡改）；
  - 没设 `connectTimeout`/`readTimeout`，默认要等 60 秒；
  - 不限制响应大小；
  - 并发调用时后返回的结果覆盖先返回的。
  - 主题本身不能执行代码，风险有限，但数值 token 没有上限（例如 `--radius: 1e9`、duration `1e9ms`），恶意或错误的主题可能把 UI 搞坏。
  - 建议：默认只允许 https；设置超时和大小上限；给长度、时长、字号设合理范围；用请求序号丢弃过期的结果。
- **全局副作用**：
  - `syncAppColorMode` 默认为 true，会调用 `appContext.setColorMode` 改变整个 App 的深浅色模式；
  - `SystemThemeBridge.applyDefault` 会改写全局 `ThemeControl` 默认主题。
  - 作为库，这两项建议默认关闭或在文档里明确说明。
  - 另外 `SystemThemeBridge.ets:8` 引用的 `docs/design/01-theme-system.md` 不存在。
- `loadString`（`SparkThemeController.ets:205`）修改 `this.preset` 时没有经过 `SparkAnim.commit`，可能被卷进主题过渡（第 6 轮那类问题）。
- **单例绑定**：`SparkLayoutMonitor` 和 `SparkUI` 只绑定第一个 UIContext 所在的窗口。
  - 有子窗口或多 Ability 时尺寸和监听会错；`SparkUI.ui` 卸载后不会清空。
  - `SparkProvider` 的 `immersive` 在卸载时不会恢复。
  - `onSizeClassChange` 没有取消订阅的方法。
- `SparkContext.resolve` 每次调用都要遍历全部 host（`indexPendingHosts`），host 多时开销是 O(n)。`ThemeResolver.substitute` 把嵌套深度和"同一值里引用 var 的次数"共用一个 depth 上限 8，引用超过 8 个 var 的值会被拒绝。
- **小键盘 Enter 的键码写错了**：`SCommand.ets:21` 和 `SCalendar.ets:43` 写的是 `2124`，SDK 中的值是 `KEYCODE_NUMPAD_ENTER = 2119`。另外这些地方都没用 `KeyCode` 枚举，而是写死数字。
- **边界值**：
  - `SSlider`：`decimalsOf` 遇到 1e-7 这样的 step 会出错；NaN 会一路传下去；修改 min/max/step 后不会重新吸附到刻度。
  - `SNumberField.ets:76-81`：受控值不做 clamp，可能显示 "NaN"。
  - `sparkProgressPercent`：max 为 NaN 或 Infinity 时返回 NaN。
  - `SPieChart`、`SRadialChart` 用 label 作 key，重复的 label 会冲突；全部为 0 时也不显示 `emptyText`。
- **其他交互细节**：
  - `SPinInput.ets:231`：`maxLength` 先于 sanitize 截断，粘贴带分隔符的验证码会少一位；`:38, :109` 的 `setTimeout(0)` 没有清理。
  - `SPagination.ets:52-55`：total 变小时会悄悄 clamp 当前页，不触发 `onPageChange`。
  - `STagsInput.ets:165`：key 里带了下标，删掉一个 tag 后，它后面的 chip 全部重建并重放入场动画。
  - `SCalendar` 的"今天"只在挂载时取一次，跨过零点后不会更新；`required` 模式下重复点同一天会再次触发 change。
  - Toast（`SparkToast.ets:347-361`）的滑动手势没有处理 `onActionCancel`；键盘高度变化时不会重新布局。
  - `SCodeBlock.ets:107` 的 2 秒计时器没有清理。
- **待真机确认的行为**：
  - `SSkeleton.ets:229` 和 `SProgress.ets:363` 在宽度变化时会再启动一个无限动画，需要确认会不会叠加。
  - focusable=false 的层（Toast、Menubar 代理层）显示时，返回键和 Esc 会不会被吞掉。

### 无障碍（除 P0-1 以外）

- **角色和状态缺失**：
  - SCheckbox、SSwitch、SSlider 没有 `accessibilityRole`；SSlider 的可访问名称默认为空。
  - Radio 没有 `accessibilityChecked`；Tabs 用的是 BUTTON 角色。
  - Progress 的可访问文本默认为空。
- **键盘导航**：
  - RadioGroup 和 Tabs 不支持方向键切换。
  - Slider 不支持 Home/End/PageUp/PageDown。
  - Tooltip、HoverCard 获得焦点时不会打开；ContextMenu 没有键盘打开方式。
  - Toast 不会被读屏播报，其中的操作按钮键盘也够不到。
- **图表**：没有数据摘要，只念 "pie chart" 这类英文类型名；`SSparkline` 完全没有可访问文本。
- **SListDetail**：窄屏下隐藏的详情面板只是平移出屏，读屏仍然能读到。
- **系统"减弱动效"**：组件没有跟随这个系统设置，只能由 App 自己调用 `setMotionEnabled(false)`。

### RTL 和大字体

- **RTL 完全不支持**：
  - 代码里有 88 处物理 `{left/right}`，`LengthMetrics` 的 start/end 一处都没有用到；
  - `PlacementRequest.rtl` 从来没有被赋值（`SparkOverlayHost.ets:322-333`）；
  - Sheet 的滑入方向、`SListDetail` 的 translate、Slider 和 Calendar 的方向键，以及 `chevron-right`/`arrow-left` 图标都不会镜像。
  - 如果不面向 RTL 市场，可以先在文档里注明"暂不支持 RTL"。
- **大字体**：
  - 字号用 fp（这是对的），但有 58 处 `.height(<数字>)` 是固定高度，其中不少同时设了 `clip(true)`，大字号下文字会被截断。例如：
    - `SAppShell.ets:115,145` 是 48，要放两行文字；
    - `SCodeBlock.ets:180`；
    - `STypography.ets:97,218` 把 lineHeight 写死为 28；
    - `SNumberField` 的按钮高 34。
  - 建议改成 `constraintSize({ minHeight })`，并用 `leading*` token；在系统字体 2 倍和 3.2 倍下逐页过一遍。

### Token 和规范

- 硬编码颜色：
  - 遮罩 `BACKDROP = '#80000000'`（`SparkOverlayHost.ets:254`），应该做成 `--overlay` token；
  - `SCodeBlock.ets:21-28` 的语法高亮色板；
  - `SparkTone` 的 success、warning、info 是固定色板，第 8 轮待定的 `--success` 等 token 建议在 1.0 前定下来。
- 释放 HAR 时混淆是关闭的，`consumer-rules.txt` 和 `obfuscation-rules.txt` 都是空文件。如果使用方开了混淆，`ThemeCssParser.parseJson` 依赖的 `ThemeJsonDoc` 字段名可能被改掉。建议在 consumer-rules 里加 `-keep-property-name`，并用一个开启混淆的示例工程验证。
- 构建告警：`STable` 和 `SMenubar` 用 `@BuilderParam` 传递非 @Builder 的值。目前只是告警，但以后的编译器可能把它升级为错误。
- `SPinInput` 用到的 `TextInputController` 有 syscap 告警，需要确认目标设备（phone、tablet、2in1）上可用，或者加 `canIUse` 判断。

## 5. 已确认没有问题的地方

- 所有 `SparkContext.provide` 都在 `aboutToDisappear` 里有对应的 `revoke`；浮层的 ComponentContent host 在 `SparkOverlayService.remove` 中 revoke。
- `SparkLayoutMonitor` 的窗口、折叠、输入设备、环境监听都在 `detach` 中注销；`SparkThemeController` 的环境监听按引用计数注销。
- 没有 onTouch 驱动的按压视觉；按压链上没有 `.animation()`；选择型控件按压时只改透明度。
- 除 SSpinner 和 SButton 外，没有直接调用 `animateTo`；浮层都通过 `SparkAnim.run`。
- 需要穿透的层（Toast、HoverCard 悬停模式、Menubar 代理层）都按内容尺寸布局。
- 以下计时器都会在卸载或关闭时清理：HoverCard、Tooltip、ContextMenu、NumberField 的计时器，以及每条 Toast 自己的计时器。
- `SparkDate` 的闰年、月末 clamp 计算正确，没有时区漂移；`ChartMath` 对空数据、单点、NaN、总和为 0 都有保护。
- 主题 CSS 解析器：`var()` 的递归有深度上限，JSON 解析有 try 保护，加载失败不会抛异常，会返回诊断信息。

## 6. 生产就绪清单

| 项 | 状态 |
|---|---|
| 静态检查和构建（debug、release HAR） | ✅ |
| 纯逻辑单测 | ✅ 143 个 |
| UI 和交互自动化测试 | ❌ |
| CI 流水线 | ❌ |
| 真机回归（第 6 到 8 轮） | ❌ 待做 |
| LICENSE、README、CHANGELOG、author | ❌ |
| 签名材料不在仓库中 | ❌ |
| `.gitignore` 完整（`.cache`） | ⚠️ |
| 版本和 semver 策略、public/internal 划分 | ❌ 目前是 0.1.0，没有策略 |
| 无障碍：读屏可以激活所有交互 | ❌（P0-1） |
| 无障碍：角色、状态、键盘导航 | ⚠️ 部分完成 |
| i18n 文案表、本地化数字和日期 | ❌ |
| RTL | ❌（未声明不支持） |
| 大字体 | ⚠️ 有固定高度截断风险 |
| 深色模式 | ✅ 全部走 token；遮罩和代码色板例外 |
| 动效可配置和可关闭 | ✅ 例外：Spinner、Button loading；没有跟随系统"减弱动效" |
| 长列表性能（虚拟化） | ❌ |
| 内存和监听泄漏 | ✅ 基本干净（P1-6 的 whenAttached 除外） |
| 网络主题加载的安全性 | ⚠️ 需要限制 https、超时、大小、数值范围 |
| 混淆兼容（consumer-rules） | ⚠️ 未验证 |
| 文档（组件 API 参考） | ⚠️ 只有 Gallery 和设计文档，缺少面向使用者的 API 文档 |

## 7. 建议的修复顺序

1. P0-1：把激活方式改成 onClick 或官方手势，并补无障碍角色。改动集中在 `SparkActivation`、`MenuRow`、`SCommandItem`、`SAlertDialog`、`SNumberField`。
2. P0-3：处理仓库卫生，补齐发布物料（这些都是纯配置，半天内可以完成）。
3. P1：依次修 1 到 8（Spinner、菜单状态、Calendar 竞态、disabled、受控 AlertDialog、浮层生命周期、uid 排序、key）。每条都补一个回归用例。
4. P0-2：真机回归，同时验证上一步的修复。
5. P1 中的 9 到 14：虚拟化、菜单滚动、文案表、API 划分和版本策略、UI 测试和 CI。达到这一步后可以发布 1.0.0-rc。
6. P2 中的项目按目标市场排期：RTL 和大字体在面向海外或适老化场景时提级。
