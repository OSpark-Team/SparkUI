# Changelog

## 1.0.0-rc

First public release candidate.

- **Components**: ~90 shadcn-vue aligned components, including Button, Card, Badge, Alert, Avatar (+ group),
  Input / Textarea / Input group / Number field / Pin input / Tags input, Checkbox, Switch, Radio group,
  Slider (range), Select, Combobox, Command, Calendar / Date picker, Tabs, Accordion, Collapsible,
  Toggle / Toggle group, Pagination, Breadcrumb, Stepper, Table, Progress (bar / ring / gauge), Skeleton,
  Spinner, Separator, Kbd, Empty, Item, Typography, Scroll area, Code block (custom grammars), Charts
  (line / area / bar / pie / donut / radial / radar / sparkline).
- **Overlays**: Dialog, Alert dialog, Sheet, Drawer, Popover, Tooltip, Hover card, Dropdown menu,
  Context menu, Menubar, Toast (multiple, configurable duration).
- **Blocks**: AppShell, Sidebar family (controller, pluggable layout policy, rail / sheet), Top bar,
  Title bar for free windows / PC, List-detail, Supporting pane, Dashboard grid.
- **Theming**: shadcn / tweakcn CSS parser (oklch with gamut mapping), presets, accents, light / dark /
  system, live hot reload, status tokens (`--success`, `--warning`, `--info`), component tokens
  (`--<component>-<property>`) and per-instance `tokens`.
- **Motion**: SparkAnim with `--motion-*` configuration per component; STransition / SSwitchTransition /
  SPageTransition / STransitionGroup.
- **Layout**: breakpoint-free SGrid / SColumns / SFlow / SStack, adaptive context, immersive safe areas.
- **i18n**: built-in texts are string resources (`spark_*`), Chinese by default, English under en_US;
  formatted strings use %d / %s placeholders. Follows the system language.

### Known issues

- Menubar: when switching menus, the previous trigger's background may briefly flash.
