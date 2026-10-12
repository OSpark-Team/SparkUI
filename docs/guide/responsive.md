# 响应式布局

<p class="doc-lead">不需要学习断点。像在 Web 上一样堆放组件——SGrid、SColumns、SFlow 以及每个 SparkUI 组件都会测量自己实际得到的空间并自行排版。</p>

```arkts
SGrid({ minItemWidth: 200 }) {          // no breakpoints: columns follow the width
  SGridItem() { StatCard(...) }
  SGridItem() { StatCard(...) }
  SGridItem({ span: 2 }) { ... }        // spans 2 columns when there are 2+
}

SColumns({ minColumnWidth: 280 }) {     // side by side, or stacked when narrow
  SColumn({ weight: 2 }) { SCard() { ... } }
  SColumn() { SCard() { ... } }
}
```

## 布局原语

| 原语 | 等价的 Web 写法 | 说明 |
| --- | --- | --- |
| `SGrid({ minItemWidth, gap, maxColumns })` | `repeat(auto-fill, minmax(x, 1fr))` | 自动列数；`SGridItem({ span, full })` 跨列。 |
| `SColumns({ minColumnWidth, gap })` + `SColumn({ weight })` | flex-wrap 列 | 放得下就并排（按权重分宽），放不下就纵向堆叠。 |
| `SFlow({ gap, justify })` | `flex-wrap: wrap` | 自动换行。 |
| `SStack({ gap, alignment })` / `SRow({ gap, justify })` | flex column / row | 间距取自 Token。 |
| `SPage({ title, description, maxWidth, safeArea })` | 页面容器 | 自适应边距、最大宽度、可选安全区与滚动。 |

在网页预览里拖动浏览器窗口宽度即可看到效果：

```arkts preview left
SGrid({ minItemWidth: 160, gap: 12 }) {
  SGridItem() {
    SCard({ sizing: 'sm' }) {
      SCardHeader() {
        SCardDescription({ text: 'Revenue' })
        SCardTitle({ text: '$45,231' })
      }
    }
  }
  SGridItem() {
    SCard({ sizing: 'sm' }) {
      SCardHeader() {
        SCardDescription({ text: 'Subscriptions' })
        SCardTitle({ text: '+2,350' })
      }
    }
  }
  SGridItem() {
    SCard({ sizing: 'sm' }) {
      SCardHeader() {
        SCardDescription({ text: 'Active now' })
        SCardTitle({ text: '+573' })
      }
    }
  }
  SGridItem({ full: true }) {
    SAlert({ heading: 'Full width', description: 'SGridItem({ full: true }) spans every column.', icon: 'info' })
  }
}
```

## 为什么需要 SGridItem / SColumn 包裹

ArkUI 父组件无法设置任意子组件（尤其是插槽内容）的尺寸：Grid / List / WaterFlow 要求固定类型的子组件，Flex 子项的 flexBasis 也只能由子组件自己设置。因此网格单元和列需要一层轻量包裹，对应 Web 中的 `<div class="col">`。

## 组件自适应

组件按自己拿到的宽度调整细节：

- `SCard` 宽度小于 360vp 时内边距从 24 收紧到 16；
- `SField` 宽时标签在左、窄时标签在上（`orientation: 'responsive'`）；
- `STabsList` 放不下时横向滚动，`SPagination` 窄时只显示上一页 / 页码 / 下一页；
- `SItem` 窄于 360vp 时操作区移到文字下方；
- 浮层在紧凑触屏上转换为底部抽屉（见[浮层](/guide/overlays)）。

需要窗口级信号（输入方式、折叠姿态）时，见[自适应上下文](/guide/adaptive)。
