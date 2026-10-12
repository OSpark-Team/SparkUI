---
layout: home

hero:
  name: SparkUI
  text: The shadcn-vue experience on HarmonyOS
  tagline: A refined, token-driven ArkTS component library (API 22 · State Management V2) that adapts to phones, foldables, tablets and 2-in-1s.
  image:
    src: /logo.svg
    alt: SparkUI
  actions:
    - theme: brand
      text: Get started
      link: /en/guide/
    - theme: alt
      text: Components
      link: /en/components/

features:
  - icon: 🎨
    title: Tokens all the way down
    details: Paste a shadcn / tweakcn theme. oklch, hsl, rgb and hex are converted precisely; switch at runtime.
  - icon: 📐
    title: Breakpoint-free layout
    details: SGrid, SColumns, SFlow and every component lay themselves out in the space they actually get.
  - icon: ✨
    title: Beautiful by default
    details: Every part is styled out of the box and still overridable with AttributeModifier or component tokens.
  - icon: 🧩
    title: Familiar API
    details: Drop the S prefix and you have the shadcn-vue name. Controlled / uncontrolled, !! two-way binding, trailing-closure slots.
  - icon: 🪟
    title: Overlays that adapt
    details: Dialog, Popover, Menu, Select, Sheet, Toast… turn into bottom drawers on compact touch screens.
  - icon: 🖥️
    title: Web previews
    details: Every example in these docs renders (approximately) and responds in the browser.
---

## In 30 seconds

```bash
ohpm install @ospark/sparkui
```

```arkts preview
SCard() {
  SCardHeader() {
    SCardTitle({ text: 'Create project' })
    SCardDescription({ text: 'Deploy your new project in one click.' })
  }
  SCardContent() {
    Column({ space: 12 }) {
      SInput({ placeholder: 'Name of your project' })
      SSwitch({ label: 'Enable analytics', defaultChecked: true })
    }
    .alignItems(HorizontalAlign.Start)
  }
  SCardFooter() {
    SButton({ text: 'Cancel', variant: 'outline' })
    Blank()
    SButton({ text: 'Deploy' })
  }
}
.width(360)
```
