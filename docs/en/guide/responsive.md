# Responsive Layout

<p class="doc-lead">No breakpoints to learn. Stack components the way you would on the web — SGrid, SColumns, SFlow and every SparkUI component measure the space they actually get and lay themselves out.</p>

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

## Primitives

| Primitive | Web equivalent | Notes |
| --- | --- | --- |
| `SGrid({ minItemWidth, gap, maxColumns })` | `repeat(auto-fill, minmax(x, 1fr))` | Automatic column count; `SGridItem({ span, full })` spans. |
| `SColumns({ minColumnWidth, gap })` + `SColumn({ weight })` | wrapping flex columns | Side by side (weighted) when they fit, stacked otherwise. |
| `SFlow({ gap, justify })` | `flex-wrap: wrap` | Wraps automatically. |
| `SStack({ gap, alignment })` / `SRow({ gap, justify })` | flex column / row | Gaps from tokens. |
| `SPage({ title, description, maxWidth, safeArea })` | page container | Adaptive margins, max width, optional safe area and scrolling. |

Resize the browser window to see the preview reflow:

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

## Why SGridItem / SColumn wrappers?

An ArkUI parent cannot size arbitrary children (slot content in particular): Grid / List / WaterFlow require specific child types and a Flex child's flexBasis can only be set by the child itself. Grid cells and columns therefore need a thin wrapper — the `<div class="col">` of the web.

## Components adapt too

Components tune details to the width they get:

- `SCard` tightens its padding from 24 to 16 below 360vp;
- `SField` puts the label beside the control when wide and above it when narrow (`orientation: 'responsive'`);
- `STabsList` scrolls horizontally when it doesn't fit, `SPagination` shows only previous / page / next when narrow;
- `SItem` moves its actions under the text below 360vp;
- overlays become bottom drawers on compact touch screens (see [Overlays](/en/guide/overlays)).

For window-level signals (input modality, fold posture) see [Adaptive Context](/en/guide/adaptive).
