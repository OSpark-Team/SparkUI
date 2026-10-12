# 第 5 轮迭代：组件批量实现（并行）+ 按压态修正

日期：2026-10-10 · 验证设备：平板

## 新增组件

| 分组 | 组件 | 实现 |
|---|---|---|
| 表单 | SLabel、SInput、STextarea、SCheckbox、SSwitch、SRadioGroup / Item、SSlider（自绘）、SProgress、SField 系列（responsive：宽时标签在左，窄时标签在上） | 子代理 A |
| 展示 | SBadge、SSeparator、SSkeleton、SSpinner、SKbd / Group、SAvatar、SAlert 系列、SEmpty 系列、SItem 系列（设置分组卡）、Typography（SH1–SH4、SP、SLead…）、SAspectRatio | 子代理 B |
| 导航 / 展开 | STabs 系列（放不下时横向滚动）、SAccordion 系列（高度动画）、SCollapsible、SToggle、SToggleGroup、SButtonGroup、SBreadcrumb 系列、SPagination（窄时只显示图标；`sparkPaginationRange` 有单测）、SScrollArea | 子代理 C |
| 浮层 | SAlertDialog 系列、STooltip（pointer 悬停 / touch 长按）、SDropdownMenu 系列（Checkbox / Radio 项；窄屏 touch 时自动变为底部 Sheet）、SSelect（数据驱动或复合写法，窄屏 touch 时变为 Sheet）、Sonner（`SparkToast` / `toast()`）；SDialog 在窄屏 touch 时自动变为 Drawer | 主线 |

公共基础设施：`OverlayBinding`（浮层内容组件与开关状态的绑定）、`MenuRow`（菜单行原语）、`SparkActivation`（不参与手势竞争的激活）、`SparkContext.whenAttached`。

## 真机发现与修复

1. **按压态（用户两次反馈）**：
   - 第一次：pressed 由 `onTouch` 状态驱动，快速切换点击时上一个按钮残留按下态。改为系统 pressed 态（`stateStyles` / `applyPressedAttribute`）。
   - 第二次：按压属性链上的隐式 `.animation()` 让松开时有淡出，仍会出现两个按钮同时呈按下态。现已移除所有涉及按压的 `.animation()`，按下和松开都瞬时切换。
   - 规则已写入 component-guide 和记忆。验证：连点两个按钮后立即在设备端截图，没有残留；长按截图仍能看到按下态。
2. **菜单项上的 `.onClick()` 被吞**：子组件的 TapGesture（即使是 parallelGesture）会在手势竞争中赢过祖先的 onClick。改用 `SparkActivation`：在 touch-up 后的下一个 tick 执行，不参与手势竞争；另外提供 reka 风格的 `onSelect`。
3. **ForEach 中的组件解析不到 SparkContext**：这类组件执行 onDidBuild 时还没挂到树上，`getFrameNodeByUniqueId` 返回 null。新增 `SparkContext.whenAttached`（下一帧重试），并用 codemod 改造了全部 50 处调用。
4. **auto 宽度的面板里，`width('100%')` 子项按浮层层宽度解析**：Dropdown / Select 面板改为确定宽度（224 / 触发器宽度）；文档页中设了 maxWidth 的包裹层统一补上 `width('100%')`。
5. **复合写法的 Select 打开前显示原始 value**：SSelectContent 在原位以 Hidden 方式预构建条目，提前注册标签。

## 验证

- `devecocli build` 成功；单元测试 51/51（新增 Pagination 11 个用例）。
- 真机已验证：Dropdown（外观、快捷键、onClick 与自动关闭）、Select（两种写法、回写、标签）、Tabs、Accordion、Scroll Area、按压态。
- 待逐页巡检：Form / Display 两组页面、Toggle、Pagination、Breadcrumb、Collapsible、Button Group、Tooltip（长按）、Toast、AlertDialog。
