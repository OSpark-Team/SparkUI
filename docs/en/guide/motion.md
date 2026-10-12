# Motion

<p class="doc-lead">Every animated component has a motion key. Configure it like a CSS transition — in code or in the theme file; the settings are exported with the theme.</p>

## In code

```arkts
SparkUI.themes.setMotion('accordion', { duration: 320, ease: 'spring(0.45, 0.85)' });
SparkUI.themes.setMotion('tooltip', { enabled: false });
SparkUI.themes.setMotion(['dialog', 'sheet'], { ease: 'spring(0.4, 0.8)' });  // several keys, one refresh
SparkUI.themes.setMotionEnabled(false);                                         // master switch
```

`SparkMotionOptions`: `duration` (ms), `ease`, `enabled`.

## In the theme file

```css [theme.css]
:root {
  --motion-enabled: true;
  --motion-accordion-duration: 320ms;
  --motion-accordion-ease: spring(0.45, 0.85);
  --motion-tooltip-enabled: false;
}
```

`ease` accepts `linear`, `ease`, `ease-in`, `ease-out`, `ease-in-out`, `standard`, `friction`, `sharp`, `smooth`, `rhythm`, `cubic-bezier(a,b,c,d)` and `spring(response, damping)`.

## Motion keys

`accordion`, `collapsible`, `tabs`, `checkbox`, `radio`, `switch`, `slider`, `progress`, `select`, `input`, `avatar`, `toast`, `dialog`, `drawer`, `sheet`, `popover`, `tooltip`, `menu`, `button`, `theme`… (the kebab-case component name).

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

## Rules

- **Pressed states never animate**: press and release switch instantly, like native controls.
- Selection controls (Tabs, single ToggleGroup) show the selection with one sliding indicator instead of cross-fading two siblings.
- Every component animation goes through `SparkAnim` (`attr()` / `run()` / `enter()`), so all of them obey `--motion-*`.
