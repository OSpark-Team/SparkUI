# 布局 Block 的扩展点（headless-first）

> 适用于 `library/src/main/ets/blocks/`：SSidebar 家族、STopbar、SAppShell、SListDetail、SSupportingPane、SDashboardGrid。
> 原则：**库不为特定场景写特例**。所有行为都可以由使用方替换或接管，库只提供默认值。

## 1. 原则

1. **状态即控制器**：每个有状态的 block 都有一个 `@ObservedV2` 状态类，可以由使用方自己创建，再通过 `controller` 传入。字段都带 `@Trace`，组件外也能响应式读取；方法用于驱动状态。
2. **受控 / 非受控 + 事件**：每个状态都同时提供 `xxx` / `defaultXxx` / `onXxxChange`（以及 `$xxx`，用于 `!!`）。只要状态有变化，就有对应的事件。
3. **策略是函数**："何时停靠、何时变成 rail 或 sheet、何时分栏"由可替换的纯函数决定（`@Event layoutPolicy`）。函数只接收容器自身测得的宽度，不读取窗口断点。默认策略和预置策略都在 `BlocksLogic.ets` 中，有单元测试覆盖。
4. **插槽是追加式的**：插槽（`xxxBuilder`）追加在内置内容之后。要替换内置内容，把对应的数据 prop 置空即可（例如 `brand: ''`、`leading: 'none'`、`title: ''`）。
5. **数据驱动只是薄层**：`SAppShell` 只是对 `SSidebarProvider / SSidebar / SSidebarInset / STopbar` 的一层组合。超出它能力范围的需求，直接用这些原语自己组合。
6. **不内置路由、存储和窗口 API**：只提供 `value` + `onNavigate` 两个钩子，用来接入任意路由；持久化通过 `defaultXxx` + `onXxxChange` 完成，由应用自己存（例如 PersistenceV2）；标题栏只预留一个区域插槽。

## 2. 扩展点一览

### SSidebarProvider / SparkSidebarState

| 类型 | 扩展点 |
|---|---|
| 控制器 | `controller: SparkSidebarState`。方法：`toggle()`、`setOpen(b)`、`setOpenMobile(b)`、`select(v)`（用户激活，会触发事件）、`setValue(v)`（程序设置，不触发事件）、`back(): boolean`（供 `onBackPress` 调用）、`relayout()`。只读字段：`presentation`、`open`、`openMobile`、`value`、`width`、`collapsed`、`iconOnly`、`mobile`、`rail`、`dockWidth`、`toggleable`、`insetFramed` |
| 受控 | `open` / `defaultOpen` / `onOpenChange` / `$open`；`value` / `defaultValue` / `onValueChange` / `$value` |
| 事件 | `onNavigate(v)`：每次激活都会触发，包括重复点击当前项（路由可借此实现"再点一次回到根"）；`onOpenMobileChange`；`onPresentationChange` |
| 策略 | `layoutPolicy(input) => 'docked' \| 'rail' \| 'sheet'`。默认是 `sparkSidebarDefaultPolicy`（与 shadcn 一致）；`sparkSidebarRailPolicy(minRailInsetWidth)` 是 Material 风格的三段式。输入为 `SparkSidebarLayoutInput`：容器宽、侧栏宽、rail 宽、`minInsetWidth`、`collapsible` |
| 阈值 | `sidebarWidth`、`sidebarWidthMobile`、`minInsetWidth`，没有固定断点 |
| 动效 | `motionKey`（默认 'sidebar'）同时用于折叠宽度动画和 sheet，可用 `--motion-<key>-*` 配置或关闭 |
| 返回 | sheet 自带返回手势处理；页面级的返回调用 `controller.back()` |
| 持久化 | `defaultOpen`（读取已存的值）+ `onOpenChange`（写入）。传入 controller 时，controller 保留自己的初始状态，由应用自己初始化（`ctrl.open = stored`） |

注意：传入 `controller` 时，`defaultOpen` / `defaultValue` 不会覆盖它，只有 provider 自建的状态才使用这两个默认值。

### 侧栏部件

- `SSidebarMenuButton`：`value` / `isActive` / `icon` / `badge` / `disabled`，尾部插槽 `content`。按下时只降低透明度（选择型控件规则）。
- 自定义菜单项：在 `onDidBuild` 里用 `SparkContext.whenAttached`，并调用 `resolveSparkSidebar()` 获取状态；用 `sparkSidebarInSheet()` 判断当前是否渲染在 sheet 里（rail 模式下 sheet 内仍需显示文字）。
- `SSidebarTrigger({ controller })`：可以放在 provider 之外，例如标题栏里。

### STopbar

| 类型 | 扩展点 |
|---|---|
| 插槽 | `leadingBuilder`（追加在内置 leading 之后，配合 `leading: 'none'` 可整体替换）、`titleBuilder`（追加在标题和副标题之后，`title: ''` 时替换标题）、`content`（尾部） |
| 阈值 | `condenseBelow`（默认 520）、`barHeight`（0 表示自动：56 / 48） |
| 钩子 | `onBack`、`onAction`、`onSearch` / `onSearchChange` |
| 控制器 | `sidebarController`：放在 provider 之外时，用它驱动 trigger |

### SAppShell（数据驱动层）

- 控制器与事件：`controller`、`value` / `defaultValue` / `onValueChange` / `onNavigate`、`open` / `defaultOpen` / `onOpenChange`、`onOpenMobileChange`、`onPresentationChange`；`layoutPolicy`、`minInsetWidth`、`sidebarWidth`、`motionKey` 原样透传。
- 区域插槽：`titleBarBuilder`（整个外壳上方，放 STitleBar 等窗口标题栏）、`sidebarHeaderBuilder`、`sidebarContentBuilder`、`sidebarFooterBuilder`、`navItemBuilder(item)`、`navGroupLabelBuilder(group)`、`topbarLeadingBuilder`、`topbarTitleBuilder`、`topbarActionsBuilder`、`headerBuilder`（顶栏下方）、`footerBuilder`。
- 默认渲染函数已导出，可以包装后复用：`sparkShellNavItemBuilder`、`sparkShellNavGroupLabelBuilder`。
- 退出内置结构：`showTopbar: false`（改用 `headerBuilder` 放自定义顶栏），`scrollable: false`（内容自己管理滚动和分栏，例如 SListDetail）。
- **ArkTS 限制**：只要传入了任何其他插槽参数，就**不能**再用尾随闭包，必须用 `content: this.xxx` 具名传入（编译错误 10905102）。不传插槽时，`SAppShell({...}) { ... }` 照常可用。
- 插槽建议用 `@LocalBuilder` 方法、全局 `@Builder`，或者箭头函数 `(): void => { this.x() }`，以保证 `this` 指向调用方。

### SListDetail / SSupportingPane

- `controller`（`SparkListDetailState` / `SparkSupportingPaneState`）：提供 `back(): boolean`、`setShowDetail()` / `setOpen()`、`relayout()`。
- `layoutPolicy(SparkSplitInput) => boolean`（默认分别是 `sparkListDetailDefaultPolicy` 和 `sparkSupportingDefaultPolicy`），配套事件 `onWideChange`，动效用 `motionKey`。
- `SListDetailPane`：`onBack(): boolean` 返回 true 时视为已处理，不再执行默认的 pop；另有 `headerBuilder`（标题栏尾部）、`empty` + `emptyBuilder`（未选中时的空状态）和 `backLabel`。

### SDashboardGrid

- `actionsBuilder`：标题行尾部插槽（筛选、日期范围、操作按钮）。列数由 `minTileWidth` / `maxColumns` 决定。

## 3. 示例

```ts
// 自己的控制器 + 路由 + 持久化
private sidebar: SparkSidebarState = new SparkSidebarState();
onBackPress(): boolean { return this.sidebar.back(); }

SAppShell({
  nav: NAV, controller: this.sidebar,
  value: this.route,                        // 由路由驱动
  onNavigate: (id: string) => this.router.push(id),
  onOpenChange: (o: boolean) => { this.prefs.sidebarOpen = o; },
  layoutPolicy: (i: SparkSidebarLayoutInput): SidebarPresentation => i.containerWidth > 900 ? 'docked' : 'rail',
  navItemBuilder: myNavItem,                // 全局 @Builder (item: SparkShellNavItem)
  titleBarBuilder: this.titleBar,           // STitleBar 区域
  content: this.page                        // 有其他插槽时 content 必须具名
})
```

gallery（`gallery/src/main/ets/pages/Index.ets`）就是 SAppShell 的完整示例：使用应用自有的 controller，系统返回会关闭 sheet；当前页面和侧栏折叠状态用 PersistenceV2 持久化；标题栏区域和顶栏操作都通过插槽接入；页面主体使用 SPageTransition。
