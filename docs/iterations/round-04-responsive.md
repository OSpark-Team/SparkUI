# 第 4 轮迭代：无感断点的响应式布局 + SCard

日期：2026-10-10 · 验证设备：平板

## 完成内容

- **布局原语**（`layout/SparkLayouts.ets`）：`SPage`、`SStack`、`SRow`、`SFlow`、`SGrid` + `SGridItem({ span, full })`、`SColumns` + `SColumn({ weight })`。全部基于容器自身宽度排版，见 ADR D11。
- **`SCard` 系列**：Header、Title、Description、Action、Content、Footer，对齐 shadcn v4。卡片根据自身宽度自动调整内边距；Footer 放不下时自动换行。
- **Gallery**：新增 Responsive Layout 页，用滑块调整容器宽度来模拟浏览器缩放，演示一个仪表盘：统计卡网格、2:1 双栏、表单字段双栏、标签流式换行；新增 Card 文档页；原 Adaptive Layout 页改名为 Adaptive Context。
- **单元测试**：`sparkGridColumns` 列数计算（40/40 通过）。

## 真机结果（截图 r4-*.png）

| 容器宽度 | 统计卡 | Overview / Recent Sales | 表单字段 |
|---|---|---|---|
| 100%（约 1100vp） | 4 列 | 并排 2:1 | 并排 |
| 67% | 2 列 | 堆叠（宽度低于 2×260+16） | 并排 |
| 28%（手机宽度） | 1 列 | 堆叠 | 堆叠；卡片内边距变为 16；标签换行 |

## 下一步

- 浮层组件的语义翻译：窄空间下 Popover / DropdownMenu / Select 转为底部 Sheet，Dialog 转为 Drawer（自动完成，无需配置）。
- A 类组件逐个实现，每个组件都具备自适应能力（例如 Field 在宽时标签在左、窄时标签在上；Tabs 放不下时可横向滚动；Table 在窄容器中转为卡片列表）。
