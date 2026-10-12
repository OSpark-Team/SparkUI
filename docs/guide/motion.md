# 动效

<p class="doc-lead">每个有动画的组件都有一个动效 key。像写 CSS transition 一样配置它——代码里调用，或写进主题文件；配置会随主题一起导出。</p>

## 在代码中配置

```arkts
SparkUI.themes.setMotion('accordion', { duration: 320, ease: 'spring(0.45, 0.85)' });
SparkUI.themes.setMotion('tooltip', { enabled: false });
SparkUI.themes.setMotion(['dialog', 'sheet'], { ease: 'spring(0.4, 0.8)' });  // 多个 key，一次刷新
SparkUI.themes.setMotionEnabled(false);                                         // 全局开关
```

`SparkMotionOptions`：`duration`（毫秒）、`ease`、`enabled`。

## 在主题文件中配置

```css [theme.css]
:root {
  --motion-enabled: true;
  --motion-accordion-duration: 320ms;
  --motion-accordion-ease: spring(0.45, 0.85);
  --motion-tooltip-enabled: false;
}
```

`ease` 可选：`linear`、`ease`、`ease-in`、`ease-out`、`ease-in-out`、`standard`、`friction`、`sharp`、`smooth`、`rhythm`、`cubic-bezier(a,b,c,d)`、`spring(response, damping)`。

## 动效 key

`accordion`、`collapsible`、`tabs`、`checkbox`、`radio`、`switch`、`slider`、`progress`、`select`、`input`、`avatar`、`toast`、`dialog`、`drawer`、`sheet`、`popover`、`tooltip`、`menu`、`button`、`theme`……（kebab-case 的组件名）。

```arkts preview
STabs({ defaultValue: 'one' }) {
  STabsList() {
    STabsTrigger({ value: 'one', text: 'Overview' })
    STabsTrigger({ value: 'two', text: 'Analytics' })
    STabsTrigger({ value: 'three', text: 'Reports' })
  }
}
SAccordion({ type: 'single', collapsible: true }) {
  SAccordionItem({ value: 'a' }) {
    SAccordionTrigger({ text: 'Try the motion presets' })
    SAccordionContent() {
      Text('The height, the chevron and the tab indicator use the configured duration and curve.')
    }
  }
}
.width(320)
```

## 规则

- **按压态永远不加动画**：按下和松开都瞬时切换，和原生一致。
- 选择型控件（Tabs、单选 ToggleGroup）用一个滑动指示器表示选中，不对两个兄弟节点同时做背景渐变。
- 组件内部所有动画都经过 `SparkAnim`（`attr()` / `run()` / `enter()`），因此都能被 `--motion-*` 配置或关闭。
