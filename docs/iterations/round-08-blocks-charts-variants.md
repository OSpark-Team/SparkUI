# 第 8 轮：反馈修复，接入布局块、图表和深度变体

日期：2026-10-12

## 用户反馈修复

| 反馈 | 根因 | 修复 |
|---|---|---|
| Preview / Code、分页按钮又出现"两个按下" | 第 7 轮给 SButton 加了变体颜色过渡。点 B 时 A 还在褪色，看上去两个按钮都处于按下状态 | 撤销该过渡，变体改为瞬切。按下态仍然走 `applyPressedAttribute`（即 stateStyles 的 Modifier 形式）。Preview / Code 改为滑动指示器分段控件 |
| 切换动画曲线很慢 | 一次预设调用了 10 次 `setMotion`，每次都要整体刷新主题、重渲染全应用 | `setMotion(keys[], …)` 合并后只刷新一次 |
| Toast 不推出新的 | 原来的列式布局 | 改为 Sonner 堆叠：最新一条在最前，旧的缩小后退；点按或悬停展开成列表；外框高度严格等于所画的内容 |
| Tooltip | 原本就正常（需要长按） | — |

## 新增

- **已接入的 18 个组件**：Calendar / DatePicker、InputGroup / NumberField / PinInput / TagsInput / Stepper / Table、HoverCard / ContextMenu / Command / Combobox / Drawer / Menubar。
- **布局块（Blocks）**：SSidebar 全家桶（宽时停靠、窄时变成 sheet，可折叠成图标栏；变体 sidebar / floating / inset）、STopbar（宽度不够时自动收紧）、SAppShell（数据驱动的整体外壳）、SListDetail、SSupportingPane、SDashboardGrid。按用户要求不做路由。
- **图表**：SLineChart / SAreaChart / SBarChart / SPieChart / SDonutChart / SRadialChart / SRadarChart / SSparkline，外加 SChartContainer、Legend、Tooltip。使用 `@AnimatableExtend` 驱动 Path 向量做动画（入场生长和数据形变）；支持触摸拖动和指针悬停。
- **深度变体**：
  - Progress：linear / circle / gauge 三种形态，支持 indeterminate、buffer、striped、segments 和语义色。
  - Badge：语义色、soft、dot、count/max、可移除。
  - Alert：语义色、带操作按钮、可关闭。
  - Avatar：多尺寸、多形状、状态点，新增 SAvatarGroup。
  - Card：多种变体、可按压卡片、图片头。
  - Skeleton：pulse / shimmer 动效、文本行、preset。
  - Separator：可带标签。
  - Kbd：新增 SKbdGroup 组合键。
  - Input / Textarea：多尺寸、图标、clearable、计数。
  - Switch / Checkbox / Radio：多尺寸、描述文字、卡片式选项。
  - Slider：范围选择、刻度和标记、数值提示、竖向。
  - Button：block、loadingText。
- **核心**：`SparkAnim.loop`（无限动画，跟随动效配置）；`SparkTone`（success / warning / info 语义色板）。

## 待定

- 是否把 success / warning / info 做成正式主题 token（`--success` 等）。目前 `SparkTones.palette` 用的是固定色板（Tailwind emerald / amber / sky），应用可以自行覆盖。

## 验证

- `devecocli build` 成功；单元测试 143/143 通过；`check arkts` 在 136 个文件中 0 错误。
- 真机验证待做，重点包括：图表入场动画、Progress 环形和条纹、Slider 范围模式、Sidebar 折叠与 sheet、Toast 堆叠、按压不残留。
