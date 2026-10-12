# Overlays

<p class="doc-lead">Dialog, Alert Dialog, Sheet, Drawer, Popover, Tooltip, Hover Card, the menus, Select, Combobox, Command and Toast share one overlay foundation and compose exactly like shadcn-vue: root + Trigger + Content.</p>

## Composition

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

- The open state can be controlled: `SDialog({ open: this.open!! })`, or observe `onOpenChange`.
- Closing: wrap anything in `SDialogClose`, `SPopoverClose`, `SSheetClose`; tapping the scrim, the back gesture and Esc close too (configurable).

## Semantic translation

On **compact width + touch**, Alert Dialog, Dropdown Menu, Select & co. automatically become bottom drawers — nothing to declare. Each component's `adaptive` param (`'auto'` by default) turns that off or forces it.

## Toast

```arkts preview
SButton({ text: 'Show toast', variant: 'outline' })
  .onClick(() => {
    SparkToast.show('Event has been created', { description: 'Sunday, December 03, 2023 at 9:00 AM' })
  })
SButton({ text: 'Success', variant: 'outline' })
  .onClick(() => { SparkToast.show('Saved', { variant: 'success', duration: 2000 }) })
```

Bottom-right on wide windows, bottom-centre on compact ones; swipe sideways to dismiss. Toast layers are content-sized, so touches outside the toasts go straight to the page.

## Implementation notes

- Every overlay opens and closes through `openSparkOverlay(uiContext, scope)` / `closeSparkOverlay(scope)`; scopes come from `SparkOverlayService.createScope()`.
- A non-modal layer only intercepts touches within its own frame, so non-modal layers are content-sized and positioned by the dialog alignment.
- Plain hint bubbles (Tooltip) use the system `bindPopup`, opened by long-press on touch screens.
