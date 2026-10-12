# 第 6 轮迭代：反馈修复 + 可配置动效系统

日期：2026-10-12 · 本轮未上真机（用户不在设备所在网络），只做了构建和单元测试

## 用户反馈修复

| 反馈 | 根因 | 修复 |
|---|---|---|
| Toast 从 loading 变为 done 后图标还在转 | 无限旋转的 `animateTo` 绑在同一个 SIcon 节点上；variant 切换后节点被复用，旋转一直保留 | loading 状态使用独立的 `SSpinner` 节点，状态切换时整个节点被移除；其他状态的图标用 `SparkAnim.enter` 缩放淡入 |
| Accordion 按压背景贴着文字和图标 | 触发行没有水平内边距 | 触发行和内容区统一 12vp 水平内边距，文字依然对齐 |
| Theming 页 Mode / Accent / Base Gray 按钮出现"两个按压背景" | 主题切换时先赋值 `@Trace accent`，再调用 `animateTo` 做 300ms 颜色过渡。ArkUI 的 `animateTo` 会把尚未刷新的状态变化一起动画，于是选中按钮的 variant 切换被卷进过渡，新旧两个按钮同时高亮 | 控制器内部用私有字段做解析；对外的 `@Trace` 选中值在动画调用之后再发布，选中态因此瞬时切换，只有 Token 颜色做过渡 |
| Tooltip 失效 | 触发器上的 `LongPressGesture`（parallelGesture）在手势竞争中输给内部按钮 | 改为 onTouch 计时器（按下 450ms 后显示，移动超过 10vp 取消，抬起即隐藏），不参与手势竞争；指针设备的悬停逻辑不变 |
| 分页点 3 后变成 `1 … 3 … 20` | 窄宽度下强制 siblings=0，而旧算法会用省略号替掉单独一页 | 改用 MUI usePagination 算法：省略号不会只替代一页（显示 `1 2 3 … 20`），槽位数保持 2s+5 不变；兄弟页数由组件实测宽度计算可容纳的槽位得出（`sparkPaginationSiblings`），不再依赖单一断点 |

## 可配置动效系统（ADR D12）

- `SparkAnim`（core/SparkAnim.ets）：`attr()` / `run()` / `enter()`，每个组件对应一个动效 key。
- 主题变量（语法扩展由用户提出）：`--motion-enabled`、`--motion-<key>-duration|ease|enabled`。ease 支持 CSS 关键字、`cubic-bezier()`、`spring(response, damping)`。
- 代码 API：`SparkUI.themes.setMotion('accordion', { duration: 320, ease: 'spring(0.45, 0.85)' })`、`setMotionEnabled(false)`，配置会随 theme.css 一起导出。
- 已接入的组件和 key：

  | 组件 | key |
  |---|---|
  | Accordion / Collapsible | accordion / collapsible |
  | Tabs（新增滑动指示器 + 内容入场） | tabs |
  | Checkbox（勾选缩放入场 + 底色过渡） | checkbox |
  | Radio | radio |
  | Switch | switch |
  | Slider | slider |
  | Progress | progress |
  | Select 箭头 | select |
  | Input / Textarea 焦点环 | input |
  | Avatar 图片淡入 | avatar |
  | Toast（入场 / 退场 / 回弹） | toast |
  | 浮层进出场 | dialog / drawer / sheet / popover / tooltip / menu / select |
  | 主题切换 | theme |

- Tabs 改为**单个滑动指示器**：选中项的背景是一个在 tab 之间移动的胶囊，所以永远不会出现两个高亮；首次布局不做动画。
- Gallery Theming 页新增 Motion 区：全局开关，以及 standard / spring / linear / slow 四种预设，可现场体验。

## 其他

- 工具修复：`tools/unit-test.sh` 先删除旧的结果文件，并检查结果是否是新生成的。之前测试代码编译失败时，脚本会读到上一次的旧结果，误报"全部通过"。
- 事故记录：本轮修复测试时，一个脚本匹配到了更靠前的同名片段，覆盖了 ThemeCss.test.ets 中的 6 个用例。已按原内容逐条恢复，测试重新全部通过。工程目前不在 git 版本控制下，建议启用（见本轮结论）。

## 验证

- `devecocli build` 成功；`check arkts`：90 个文件 0 错误。
- 单元测试 51/51 通过（新增 motion_variables、分页的"不替代单页"和"宽度推算兄弟页数"等用例）。
- 真机验证待下次连接设备时进行：Tooltip 长按、Tabs 指示器、Theming 页切换、Toast、Accordion、分页。

## 进行中（并行）

- D：InputGroup、NumberField、PinInput、TagsInput、Stepper、Table
- E：HoverCard、ContextMenu、Command、Combobox、Drawer、Menubar
- F：Calendar、RangeCalendar、DatePicker、DateRangePicker、日期工具（含单测）
