# TODO

## Known issues

- **Menubar：切换菜单时旧触发按钮的背景会闪一下。** 菜单已打开时点按（或指针移到）另一个触发按钮，旧按钮的高亮背景会短暂闪烁。
  按压态已改为 `stateStyles`，悬停已改为瞬时切换（v1.0.0-rc），真机上仍可复现。待排查方向：
  - 菜单关闭时浮层把焦点还给旧触发按钮（`restoreFocusId`），引起的焦点或状态切换；
  - 命中层（proxy layer）与外部点击捕获层的事件时序；
  - `active` 状态与浮层退场动画之间的刷新时序。

## Planned

- 国际化后续：SparkShellNavItem / NavGroup 标题支持 ResourceStr；Calendar 的辅助文案跟随 `locale` 属性而非系统语言。
- RTL 支持。
- UI 自动化测试。
