# 第 3 轮迭代：文档站式 Gallery、代码高亮、强调色主题、Sheet、沉浸式

日期：2026-10-10 · 验证设备：平板（HarmonyOS 7.0）

## 完成内容

| 模块 | 内容 |
|---|---|
| 强调色主题 | `SparkUI.themes.useAccent('blue' \| 'green' \| 'orange' \| 'red' \| 'rose' \| 'violet' \| 'yellow' \| 'none')`。数值取 Tailwind v4 的 oklch 值：亮色用 600 档、暗色用 500 档（yellow 用 400/500）。作为覆盖层叠在灰阶底色之上，影响 primary / ring / sidebar-primary。主题源分三层：`灰阶 ⊕ 强调色 ⊕ 覆盖`（覆盖指加载的主题文件或编辑器写入的变量，切换底色或强调色时保留）；另提供 `resetOverrides()` |
| `SCodeBlock` | 自研分词器 `CodeHighlighter`，支持 ArkTS/TS、CSS、JSON、Bash。具备行号、复制按钮（写入剪贴板无需权限）、横向滚动、`maxHeight` 纵向滚动、GitHub 风格亮 / 暗配色，等宽字体使用系统 `monospace` |
| `SSheet` 系列 | top / right / bottom / left 四个方向。左右两侧宽度为 `w-3/4 sm:max-w-sm`。面板延伸到系统栏下方，内容按安全区留白。Footer 只在左右两侧自动推到底部（通过 `SparkDisclosure.placement` 获知所在方向） |
| Gallery 文档站 | 宽屏：固定侧边栏（sidebar Token）+ 顶栏（当前页 + 亮暗切换）；窄屏：顶栏 + 菜单按钮，点击后用受控 `SSheet`（左侧）打开导航，选中条目后自动关闭。页面包括 Introduction、Theming、Adaptive Layout、Icons（可搜索）、Code Block、Button、Dialog、Popover、Sheet；每个示例都有 Preview / Code 切换 |
| Theming 页 | 模式切换、8 个强调色色块、5 套底色、6 档圆角；预览卡片（含原生 TextInput / Toggle）；实时导出当前生效主题的 `theme.css` |
| 沉浸式 | `SparkProvider({ immersive: true })` → `window.setWindowLayoutFullScreen(true)`。内容按 `SparkUI.layout.env.safeArea` 留白；侧边栏和顶栏背景延伸到状态栏下方，页面内容可以滚动到导航条下方 |
| 布局模拟 | Adaptive Layout 页可模拟 Phone / Foldable (book) / Tablet (tabletop) / 真实窗口（调用 `SparkUI.layout.simulate`，作为布局检查器的雏形） |
| 容器查询修复 | `SparkContainer` 改用 `onAreaChange`（`onSizeChange` 首次布局时不触发）；同时通过 SparkContext 发布容器上下文，组件用 `resolveSparkLayout()` 获取 |
| 工具 | `tools/dev.sh`：自动重连无线 hdc，提供 shot / find / tap / back / swipe / restart 命令；`tools/ui-find.mjs` |

## 真机发现（已处理）

1. **`expandSafeArea` 不能让整页沉浸**：它只扩展「已扩展容器的直接子节点」，遇到自定义组件边界就停止（试过在页面根、Provider 容器、Shell 根节点上都加，依然无效）。改用窗口级的 `setWindowLayoutFullScreen`，`expandSafeArea` 仍用于背景层和浮层面板。
2. **插槽中的 `@Consumer` 拿不到容器上下文**：与第 1 轮中复合组件状态的问题是同一个原因。容器查询因此也通过 SparkContext 走渲染树解析。
3. **使用尾随闭包插槽的自定义组件后面不能链式写属性**：`SButton({...}) { 自定义内容 }.onClick(...)` 编译报错，只有不带插槽的写法才能直接 `.onClick()`。目前的绕法是在外面包一层 `Stack().onClick()`（`SparkTapBlocker` 仍能在禁用时拦截点击）。
4. `Circle().fill()` 需要 SDK 26，色块改用圆角 `Column`。
5. 底部 / 顶部 Sheet 被 Footer 的 `layoutWeight` 撑满屏幕 → Footer 只在左右两侧伸展。
6. `ui screenshot` 不会覆盖已存在的文件（会读到旧图）→ `tools/dev.sh shot` 先删除再截图。

## 验证

- 单元测试：39/39（新增：CodeHighlighter 7 个用例、强调色解析；blue 的 primary 精确等于 Tailwind blue-600 `#155DFC`）。
- `check arkts`：0 错误，剩余 1 条 `INTERNET` 权限提示（loadUrl 需要）。
- 真机截图 `docs/screenshots/r3-*.png`：
  - Introduction / Theming（blue、圆角 1；violet、暗色、圆角 0.3，原生 Toggle 跟随强调色）/ 实时 theme.css
  - 四向 Sheet、沉浸式外壳、沉浸式下 Popover 定位
  - 窄屏外壳与导航 Sheet（选中后跳转并关闭）
  - 容器查询（592 vp → compact，220 vp → compact）

## 待确认 / 下一步

- 是否给带插槽写法的组件增加 `@Event onPress`（不破坏现有 API，只是新增）。
- 继续 B 类组件（AlertDialog、Tooltip、DropdownMenu、Select、Toast…），以及 A 类组件（Card、Input、Tabs、Switch、Checkbox…），并逐个补上文档页。
