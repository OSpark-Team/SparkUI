# 第 7 轮：暂停新组件，修复动效根因并改用官方写法

日期：2026-10-12

## 用户反馈

1. Theming 页的选中切换很生硬。
2. Accordion 等组件展开、收起没有动画，内容直接出现或消失。
3. 怀疑很多状态处理用了 hack，而不是官方写法。
4. Tooltip 仍然不显示。
5. Toast 显示期间，页面其他组件无法操作。

## 根因与修复

| 问题 | 根因（均已查官方文档） | 修复 |
|---|---|---|
| 展开 / 收起无动画（Accordion、Collapsible，以及所有由 `@Monitor` 触发的动画） | 状态管理 V2 在微任务中标脏，`animateTo` 却在调用时立即刷新脏节点。闭包中的 V2 修改会直接跳到终态（文档《applySync/flushUpdates/flushUIUpdates接口：同步刷新》，以及 FAQ《@Monitor使用限制》场景一） | `SparkAnim.run` 在动画闭包内调用 `UIUtils.applySync`（这是官方给出的方案）；新增 `SparkAnim.commit()` 用于同步提交、不参与动画的修改。hover 动画也改为走 `SparkAnim.run` |
| Theming 选中态生硬 | 上一轮为了避免选中态交叉渐变，让选中瞬时切换；当时用的手段是"先启动动画、再发布 @Trace" | 删除这个时序技巧，控制器改用 `SparkAnim.commit` 同步提交选中值，颜色过渡用 `SparkAnim.run`。Theming 页的 Mode / Accent / Base gray / Radius / Motion 改用新版 `SToggleGroup`：同一时刻只有一个滑动的选中指示器 |
| Tooltip 不显示 | 之前的实现靠 onTouch 计时，再打开一个全窗口 dialog。打开 dialog 会给原触摸流发送 Cancel，Tooltip 刚出现就被关掉 | 改用系统 `bindPopup`（无遮罩，自带箭头和自动翻转）。触屏长按用 `priorityGesture(LongPressGesture)`，长按成功后不会再触发按钮的点击；指针悬停延迟保留 |
| Toast 显示时页面不可操作 | 非模态 dialog 只拦截自身框架内的触摸，但 Toast 宿主铺满了整个窗口 | Toast 层改为按内容尺寸布局，用 dialog 的 alignment 定位（窄屏底部居中，宽屏右下） |

## 组件改进

- `SToggleGroup`：新增 `spacing`、`wrap`、`deselectable`。`type: 'single'` 时，选中背景由一个滑动指示器绘制（motion key `toggle-group`），选中项文字颜色同步过渡。
- `SparkSelection`：新增几何上报 `report/rectOf` 和 `interacted`，由 Tabs 和 ToggleGroup 共用。Tabs 去掉了 `setTimeout(0)` 的"首次放置"技巧，改为用户交互后才做动画。
- `SButton`：变体切换时做一次短的颜色过渡（motion key `button`，类似 CSS `transition: background-color`）。按压态依旧瞬时切换，不受影响。
- `STooltip` 新增导出 `SparkTooltipState`；配置不再塞进 `placement` 字符串。

## 仍然存在、计划后续替换的非官方写法

- `SparkActivation`（用于 MenuRow、AlertDialog）：用 onTouch 抬起来模拟激活，原因是子组件的 TapGesture 会吞掉祖先组件的 onClick。下一步评估用 `parallelGesture`，或者把 onClick 放到同一节点上。
- `SparkContext.whenAttached`：用 16ms 重试等待节点挂载。ForEach 子节点在 onDidBuild 时还没挂上树，这一点已在真机验证；替代方案待调研。
- 浮层的 anchored 非模态层（HoverCard 悬停模式、Menubar 命中层，均为未接入的新组件）同样是全窗口宿主，接入前需要按 Toast 的方式改造。

## 验证

- `devecocli build` 成功；单元测试 51/51 通过；`check arkts` 在本轮修改的文件中没有错误（剩余报错全部来自三份尚未接入的新组件文档页）。
- 尚未上真机：需要验证 Accordion 动画、Theming 页指示器、Tooltip 长按和悬停、Toast 期间页面可操作。

## 新组件（已完成，暂缓接入）

按用户要求，先修问题再加组件。三路新组件的代码已经写完但尚未接入：Calendar / DatePicker、InputGroup / NumberField / PinInput / TagsInput / Stepper / Table、HoverCard / ContextMenu / Command / Combobox / Drawer / Menubar。等本轮修复在真机上确认后再接入。
