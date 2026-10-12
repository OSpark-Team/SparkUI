---
layout: home

hero:
  name: SparkUI
  text: HarmonyOS 上的 shadcn-vue 体验
  tagline: 精致、以 Token 驱动的 ArkTS 组件库（API 22 · 状态管理 V2），为手机、折叠屏、平板与 2in1 自适应。
  image:
    src: /logo.svg
    alt: SparkUI
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/
    - theme: alt
      text: 浏览组件
      link: /components/

features:
  - icon: 🎨
    title: Token 贯穿始终
    details: 直接粘贴 shadcn / tweakcn 主题 CSS，oklch、hsl、rgb、hex 精确换算，运行时随时切换。
  - icon: 📐
    title: 无感断点的响应式
    details: SGrid、SColumns、SFlow 与所有组件都按自己实际得到的空间排版，像写 Web 一样堆组件即可。
  - icon: ✨
    title: 默认即美观
    details: 每个部件开箱即有样式，同时可用 AttributeModifier 或组件 Token 覆盖。
  - icon: 🧩
    title: 熟悉的 API
    details: 去掉 S 前缀就是 shadcn-vue 的组件名；受控 / 非受控、!! 双向绑定、尾随闭包插槽。
  - icon: 🪟
    title: 浮层与语义转换
    details: Dialog、Popover、Menu、Select、Sheet、Toast……在紧凑触屏上自动转换为底部抽屉。
  - icon: 🖥️
    title: 网页预览
    details: 文档中的每个示例都可在浏览器里近似渲染并交互。
---

## 30 秒上手

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
