# Changelog

## 1.1.1

### Added
- AppShell: `contentSafeArea` (default `true`). `false` lets non-scrolling content run edge to edge under the
  navigation indicator and pad itself (immersive canvases, maps, pages that use `SPage({ safeArea: true })`),
  instead of the shell appending a bottom-inset strip in the page background.

### Fixed
- Sidebar: in the icon rail, menu button labels and badges now leave the layout and the icon is centred; a rail
  wider than the shadcn 3rem (`--sidebar-width-icon`) no longer shows a truncated `…` next to each icon.
- Typography / Label / Dialog title: `leading-none` (line height = font size) clipped the top of CJK glyphs
  (e.g. 已, 毕); these now use 1.25× the font size.

## 1.1.0

### Added

- **Time picker**: `STimePicker` — time of day as 24-hour `HH:mm` (`value` / `!!` + `onValueChange`), optional
  12-hour display with an AM / PM column (`hour12`), `minuteStep` (1 / 5 / 15 …), `minTime` / `maxTime`,
  `disabled`, `placeholder`, `triggerWidth`. Outline trigger with a clock icon like `SDatePicker`; two snapping
  wheel columns (hours, minutes) with a selection highlight in a popover, or in a bottom sheet with touch-sized
  rows and a Done button on compact touch windows (`adaptive: 'auto'`). Updates live when a column comes to rest;
  arrow / Home / End keys and screen readers supported; `surfaceTokens` restyle the popover. Pure helpers
  (`sparkParseTime`, `sparkFormatTime`, `sparkTimeLabel`, `sparkNearestTime` …) are exported.
- Context menu: `SContextMenuTrigger({ onTap })` — a plain tap / click on the trigger area. Use it instead of an
  `.onClick()` on the trigger content (see Fixed).
- `SparkColor.toCss(argb)`: ArkUI `#AARRGGBB` → CSS `#RRGGBBAA`, for putting computed colours into component `tokens`.

### Fixed

- Item: on narrow widths (below 360vp, e.g. phones in portrait) trailing `SItemActions` such as a chevron,
  icon, switch or badge no longer drop to a new line — the text column shrinks instead. Only wide action groups
  (several buttons) still wrap under the text, and only when keeping them inline would leave the text less than
  120vp.
- Context menu: the click produced by the finger lift that ends a long-press (and the click after a right
  click) no longer counts as a tap — `onTap` is not fired for it, so long-pressing a card opens the menu without
  also activating the card. An `.onClick()` chained on the trigger content still fires in that case (ArkUI gives
  the inner handler the click first); move it to `onTap`.
- Component colour tokens (`SButton({ tokens: { foreground } })` and every other `tokens` colour): a
  `theme.colors.*` value passed as is was read as CSS `#RRGGBBAA` with its channels rotated (`#FF4169E1` royal
  blue rendered pink, `#FFE7000B` red an almost transparent yellow — icons and labels near invisible). Values
  equal to a current theme colour are now recognised as `#AARRGGBB`; convert other ARGB strings (e.g.
  `SparkColor.alpha()` results) with `SparkColor.toCss()`.

## 1.0.0

- **Color picker**: `SColorPanel` (inline: saturation / brightness area, hue and alpha sliders over a
  checkerboard, preview, validated input accepting #RGB / #RRGGBB / #RRGGBBAA and CSS colours, HEX / RGB / HSL /
  OKLCH format toggle, preset swatches, recent colours, keyboard and screen-reader support) and `SColorPicker`
  (trigger with chip + value or `iconOnly`, popover / bottom sheet on compact touch). Controlled / uncontrolled
  `value` in 'hex' | 'rgb' | 'hsl' | 'oklch', live `onValueChange` and `onValueCommit`, `--color-picker-*`
  component tokens and per-instance `tokens`. Pure colour helpers (`sparkHsvToRgb`, `sparkParseHex`,
  `sparkFormatColor` …) are exported.

### Fixed

- Icons, chart paths and progress arcs clipped after the window density changes (free window).
- Slider value bubble rendered empty.

### Known issues

- Menubar: when switching menus, the previous trigger's background may briefly flash (see TODO.md).

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
