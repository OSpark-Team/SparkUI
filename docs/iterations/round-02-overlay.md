# 第 2 轮迭代：交互反馈、lucide 图标集、Overlay 基座

日期：2026-10-10 · 验证设备：平板（HarmonyOS 7.0，172.15.125.54）

## 完成内容

| 模块 | 内容 | 位置 |
|---|---|---|
| 交互反馈 | `SparkInteraction`：hover / pressed 状态，变化放在 `animateTo` 中执行（时长和曲线取自 motion Token）。按钮按压时背景加深一档，并缩放到 0.97（图标按钮 0.94）；hover 时背景渐变；link 按压时降低不透明度 | `core/SparkInteraction.ets`、`ButtonVariants`（新增 `pressedBackground` / `pressedOpacity`） |
| lucide 图标 | 下载 `lucide-static@1.54.0`（ISC）。`tools/gen-icons.mjs` 把 path / circle / rect / line / ellipse / polyline / polygon 统一转换为**绝对坐标**路径（含相对命令、粘连的圆弧标志位）。按 `tools/icons.txt` 打包 199 个图标（组件自用 + 常用），约 30 KB | `tools/gen-icons.mjs`、`tools/icons.txt`、`icons/LucideIcons.ets` |
| 定位算法 | `Placement.compute`：side / alignment / sideOffset / alignOffset，flip（对侧空间更大时翻转）+ shift（交叉轴夹紧），RTL，箭头偏移，可用空间，动画原点 | `primitives/overlay/Placement.ets` |
| Overlay 服务 | `SparkOverlayService`：每个浮层对应一次 `openCustomDialog(ComponentContent)`，用 `LevelOrder` 维护层级栈（toast 固定在最高层）。系统 dialog 只提供图层、返回键 / ESC / 侧滑（经 `onWillDismiss` 交给拥有者决定）和焦点域。遮罩、动画、定位由 SparkUI 按 Token 自绘。关闭时先播退场动画，再 close、dispose、撤销 SparkContext，并把焦点还给触发器 | `primitives/overlay/SparkOverlay.ets` |
| Overlay 宿主 | `SparkOverlayHost`：全窗口宿主；背景层（`bg-black/50`，延伸到系统栏下方）；四种呈现方式（center / sheet-* / anchored / toast）及对应的进出场动画；锚点定位（测量内容后再显示，避免闪烁）；键盘避让；重新下发 theme / layout / 复合组件上下文 | `primitives/overlay/SparkOverlayHost.ets` |
| 开合状态 | `SparkDisclosure`：受控 / 非受控、订阅机制、触发器锚点测量 | `primitives/SparkDisclosure.ets` |
| 组件 | `SDialog` 系列（Trigger / Content / Header / Footer / Title / Description / Close；窄屏时 Footer 自动纵向排列）；`SPopover` 系列（Trigger / Content / Close） | `components/dialog`、`components/popover` |
| Gallery | 移除风险探针；新增点击日志、Dialog / 受控 Dialog / Popover 演示、199 图标网格 | `gallery/.../Index.ets` |
| 工具 | `tools/ui-find.mjs`：从 `ui layout` 的输出中按文本查找节点中心坐标，供真机自动化验证使用 | `tools/` |

## 设计要点

- **Overlay 内容的 `this` 绑定**：DialogContent 用 `@LocalBuilder panel()` 包裹用户插槽，再作为 `scope.content` 交给宿主。`@LocalBuilder` 保证 `this` 仍指向 DialogContent，所以 panel 中的 `this.theme`、`this.ctx` 正确。
- **为什么不用 `@Monitor('ctx.open')`**：对可选的 `@Local` 对象做路径监听会触发编译告警。因此 `SparkDisclosure` 改为显式 `subscribe()`；受控值通过 `assign()` 写入，并通知所有订阅者。
- **ComponentContent 关闭时不触发 `aboutToDisappear`**（官方 FAQ）：宿主的 SparkContext 由 Service 在 remove 时撤销。

## 真机验证结果

| 场景 | 结果 |
|---|---|
| 按钮按压视效（背景加深 + 缩放） | ✅ 长按截图可见 default 变为 primary/80 |
| 点击日志；Disabled / Loading 不触发 | ✅ |
| 199 个图标渲染 | ✅（截图 r2-gallery.png） |
| Popover 锚点定位：触发器下方、start 对齐、间距 4vp | ✅ 浮层坐标系与窗口一致（r2-popover.png / r2-popover-dark.png） |
| Popover 点击外部关闭 | ✅ |
| Dialog 外观：居中、max-w-lg、rounded-lg、border、shadow-lg、关闭 X、遮罩覆盖到状态栏 | ✅（r2-dialog.png / r2-dialog-dark.png） |
| Dialog 内容响应页面状态（计数器实时刷新），以及浮层内输入回写页面状态 | ✅ |
| 系统返回键关闭 Dialog（按一次只关闭 Dialog，不退出应用） | ✅ |
| 受控 Dialog（`open: this.dialogOpen!!`）：打开时为 `true`，点遮罩关闭后回写 `false` | ✅ |
| 亮 / 暗色 | ✅ |
| 软键盘避让 | ⏳ 平板接了物理键盘，只出现悬浮工具栏，需在手机或模拟器上复测 |
| 输入模式检测 | ✅ 拔掉指针设备后从 pointer 实时切换为 touch |

单元测试：31/31（新增 `Placement.test` 8 个用例）。构建：0 错误；剩余 1 条 `INTERNET` 权限提示（loadUrl，已在文档注明）。

## 遗留 / 下一步

1. 软键盘避让、ESC 键（外接键盘）、Tab 焦点陷阱与焦点归还：需要补测。
2. 基于同一基座实现：Sheet / Drawer（sheet-* 呈现方式 + 拖拽手势）、AlertDialog、Tooltip（passThrough）、HoverCard、DropdownMenu、Select、ContextMenu、Toast（Sonner）、Command、Combobox、DatePicker。
3. 语义翻译：在 Popover / Dialog 上实现 `adaptive`（窄屏时 Popover 转为底部 Sheet，Dialog 转为 Drawer）。
4. 第 2 批 A 类组件。
