# 浮层

<p class="doc-lead">Dialog、Alert Dialog、Sheet、Drawer、Popover、Tooltip、Hover Card、各类菜单、Select、Combobox、Command 与 Toast 共用一套浮层基座，组合方式与 shadcn-vue 一致：根组件 + Trigger + Content。</p>

## 组合写法

```arkts preview
SDialog() {
  SDialogTrigger() { SButton({ text: 'Edit profile', variant: 'outline' }) }
  SDialogContent() {
    SDialogHeader() {
      SDialogTitle({ text: 'Edit profile' })
      SDialogDescription({ text: "Make changes to your profile here. Click save when you're done." })
    }
    SInput({ placeholder: 'Pedro Duarte' })
    SDialogFooter() {
      SDialogClose() { SButton({ text: 'Save changes' }) }
    }
  }
}
SPopover() {
  SPopoverTrigger() { SButton({ text: 'Open popover', variant: 'outline' }) }
  SPopoverContent() {
    Text('Popovers are anchored to their trigger.').fontSize(14)
  }
}
SDropdownMenu() {
  SDropdownMenuTrigger() { SButton({ text: 'Menu', variant: 'outline', iconRight: 'chevron-down' }) }
  SDropdownMenuContent() {
    SDropdownMenuLabel({ text: 'My Account' })
    SDropdownMenuSeparator()
    SDropdownMenuItem({ text: 'Profile', icon: 'user-round', shortcut: '⇧⌘P' })
    SDropdownMenuItem({ text: 'Settings', icon: 'settings' })
    SDropdownMenuItem({ text: 'Log out', icon: 'log-out', variant: 'destructive' })
  }
}
```

- 打开状态可以受控：`SDialog({ open: this.open!! })`，或监听 `onOpenChange`。
- 关闭：`SDialogClose`、`SPopoverClose`、`SSheetClose` 包裹任意内容；点击遮罩、返回键、Esc 也会关闭（可配置）。

## 语义转换

在**紧凑宽度 + 触屏**上，Alert Dialog、Dropdown Menu、Select 等会自动转换为底部抽屉（Drawer），无需开发者声明；通过各组件的 `adaptive` 参数（`'auto'` 默认）可以关闭或强制。

## Toast

```arkts preview
SButton({ text: 'Show toast', variant: 'outline' })
  .onClick(() => {
    SparkToast.show('Event has been created', { description: 'Sunday, December 03, 2023 at 9:00 AM' })
  })
SButton({ text: 'Success', variant: 'outline' })
  .onClick(() => { SparkToast.show('Saved', { variant: 'success', duration: 2000 }) })
```

宽窗口在右下角、紧凑窗口在底部居中；可左右滑动关闭；Toast 层按内容尺寸布局，Toast 之外的触摸直接穿透到页面。

## 实现约定

- 所有浮层通过 `openSparkOverlay(uiContext, scope)` / `closeSparkOverlay(scope)` 打开与关闭，scope 由 `SparkOverlayService.createScope()` 创建。
- 非模态层只拦截自身框架范围内的触摸，因此非模态层按内容尺寸布局，由 dialog 的 alignment 负责定位。
- 纯提示气泡（Tooltip）直接使用系统 `bindPopup`，触屏上长按触发。
