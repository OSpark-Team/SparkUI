# 第 1 轮迭代：工程骨架与基座

日期：2026-10-10

## 已完成

| 模块 | 内容 | 位置 |
|---|---|---|
| 工程结构 | `entry` 迁移为 `gallery`（HAP）；新增 HAR 模块 `library`（`@sparkui/core`）；gallery 通过 `file:../library` 依赖 | `build-profile.json5`、`library/`、`gallery/` |
| 架构决策 | D1–D9（SDK 基线、Overlay、上下文、主题语法、断点、命名、Prop 规则），均已确认 | `docs/design/00-architecture-decisions.md` |
| 颜色引擎 | oklch / oklab / hsl / rgb / hex / shadcn v1 裸 HSL 解析；oklch → sRGB 采用 CSS Color 4 色域映射（OKLCh 色度二分 + ΔE-OK JND 0.02）；输出 `#AARRGGBB` | `library/.../theme/color/SparkColor.ets` |
| Token 模型 | `SparkColors`（32 个语义色，由 `tools/gen-tokens.mjs` 生成）、`SparkTheme`（radius 及 sm/md/lg/xl 派生、spacing、字号/行高/字重、阴影 xs–2xl、动效） | `theme/tokens/` |
| 主题文件 | CSS 子集解析器（`:root`、`.dark`、`@size()`、注释、行号诊断；对 shadcn/tweakcn 导出中的 `@theme`/`@layer`/`@import` 等跳过并给出 info 诊断）+ JSON 格式 + `var()` 解析 + 导出 CSS/JSON | `theme/css/` |
| 预设 | neutral / zinc / slate / stone / gray（亮暗两版），由 Tailwind v4 灰阶生成，与 shadcn v4 一致 | `theme/presets/Presets.ets` |
| 运行时控制器 | `SparkUI.themes`：模式 system/light/dark、监听系统深浅色、预设切换、从字符串/rawfile/沙箱文件/URL 加载、单变量覆盖（主题编辑器用）、颜色过渡动画、`@size()` 随断点切换 | `theme/SparkThemeController.ets` |
| 系统主题桥接 | Token → `CustomColors` 映射（见下表），通过 `WithTheme` + `ThemeControl.setDefaultTheme` 应用 | `theme/SystemThemeBridge.ets` |
| 布局上下文 | `SparkLayoutContext`（widthClass/heightClass）+ 共享 `SparkEnvironment`（posture、折痕、modality、windowMode、安全区、键盘高度）；`SparkLayoutMonitor` 采集窗口、折叠、输入设备、配置信号；`SparkContainer` 容器查询；布局检查器的模拟接口 | `layout/` |
| 根组件 | `SparkProvider`：下发 `sparkTheme` / `sparkLayout`，包裹 `WithTheme`，绘制 background | `core/SparkProvider.ets` |
| Variant 体系 | 配方函数（等价于 cva）+ 导出的 `AttributeModifier`；组件的 `modifier` 参数叠加在配方之后；focus ring 用 `focusBox` 实现（只在键盘走焦时显示，等同 :focus-visible） | `core/SparkModifier.ets`、`components/button/ButtonVariants.ets` |
| Icon | `SIcon`（lucide 矢量，通过 Shape+Path 渲染；可映射为 HM Symbol）、`SparkIcons` 注册表；目前为手写种子子集 | `icons/` |
| 首个组件 | `SButton`：6 个 variant × 6 个 sizing，含 icon / iconRight / loading / disabled，hover 与按压态，focus ring | `components/button/SButton.ets` |
| Gallery | 风险验证页：模式与预设切换、variant/尺寸矩阵、图标、原生组件跟随主题、`@Consumer` 插槽解析探针 | `gallery/src/main/ets/pages/Index.ets` |

## 系统主题桥接映射（节选）

`primary→brand`、`destructive→alert`、`foreground→fontPrimary/iconPrimary/compForegroundPrimary`、`muted-foreground→fontSecondary/iconSecondary`、`background→backgroundPrimary`、`muted→backgroundSecondary/compBackgroundGray`、`card→compBackgroundPrimary`、`secondary→compBackgroundSecondary`、`accent→compBackgroundTertiary/backgroundFourth`、`border→compDivider`、`ring→interactiveFocus`，交互态使用 foreground 的 5% / 10% 透明度。完整映射见 `SystemThemeBridge.ets`。

## 编译期发现的约束（已形成决策 D8 / D9）

- struct 名不能与内置组件同名 → 组件统一 `S` 前缀。
- prop 不能与通用属性/事件同名 → `sizing` / `alignment` / `inputId`，点击直接用原生 `.onClick()`。
- `@Entry` 的根节点必须是系统容器 → 页面写作 `Stack() { SparkProvider() { … } }`。

## 测试

- 本地单元测试（Hypium）：`tools/unit-test.sh` → **19/19 通过**。注入一个错误断言后确认会报 1 个失败，说明运行器有效。
  - `SparkColor.test`：Tailwind 参考值比对、alpha/单位、色域映射（hue 与亮度保持）、hsl/rgb/hex、非法输入。
  - `ThemeCss.test`：完整 shadcn 导出解析、行号诊断、乱码输入不抛异常、媒体查询中的暗色、JSON、CSS/JSON 往返、层叠顺序、非法值保留默认、`var()`（含循环检测）、长度/时间/曲线/阴影、5 套预设零诊断。
- `devecocli check arkts`：0 错误。剩余 1 条提示：`loadUrl` 需要宿主应用声明 `ohos.permission.INTERNET`（文档已注明）。
- `devecocli build`：成功。

## 真机验证（平板，HarmonyOS 7.0，172.15.125.54）

截图：`docs/screenshots/r1-tablet-light.png`、`docs/screenshots/r1-tablet-dark.png`。

| 项目 | 结果 | 处理 |
|---|---|---|
| 插槽内容中 `@Consumer` 的解析目标 | ❌ 解析到定义 Builder 的页面，不是宿主组件 | 新增 `SparkContext`，按渲染树（FrameNode 父链）解析；真机验证可以命中宿主（ADR D3 补充） |
| 主题切换时配方 Modifier 重新应用 | ✅ `@Computed` 生成新实例后能正确重新应用 | — |
| 按钮圆角 | ❌ Modifier 中 `border()` 不带 radius，把 `borderRadius` 重置成了 0 | radius 写入 `border({ radius })` |
| 图标尺寸 | ❌ `Path.commands` 以 px 为单位，viewPort 用 vp（数值或 px 字符串）都只渲染出 1/密度 大小 | 新增 `scalePathCommands`，按 vp2px 把坐标缩放到目标像素（保留圆弧的旋转角与标志位）；描边宽度随尺寸缩放 |
| 图标随主题变色 | ❌ `Shape` 上设置的 stroke 更新后不会传给已存在的 `Path` | 绘制属性改为设在每个 `Path` 上 |
| disabled 按钮上挂的原生 `.onClick()` | ❌ 内层 Button 设为 `enabled(false)` 时仍会触发 | `SparkTapBlocker`（gestureModifier）：禁用时安装一个空的 Tap 手势吞掉点击；真机复测 0 次触发 |
| 原生组件跟随主题（WithTheme 桥接） | ✅ Toggle / Checkbox / Slider / TextInput 在亮暗色下都跟随 | — |
| 状态栏和导航条区域的背景 | ❌ 暗色下露出纯黑 | `SparkProvider` 背景层加 `expandSafeArea`，内容仍在安全区内 |
| 布局上下文 | ✅ 平板横屏报告 width=expanded、height=medium、posture=flat、window=fullscreen；input=pointer（设备有指针设备或配置 hasPointerDevice 为真，待接鼠标/拔掉键盘复核） | — |

单元测试：23/23 通过（新增 `Icons.test`：绝对/相对命令、圆弧标志位、紧凑数字写法）。

## 下一步

真机验证上述风险 → Overlay 基座（`SparkOverlayService`，基于 openCustomDialog + 自研定位）→ 第 2 批 A 类组件。
