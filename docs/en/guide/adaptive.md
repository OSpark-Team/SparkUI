# Adaptive Context

<p class="doc-lead">SparkUI folds window size, fold posture, window mode, safe areas and input modality into a few discrete signals. Components read the nearest context — window or container — and adapt.</p>

## Window context

```arkts
@Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

build() {
  if (this.layout.atLeast('expanded')) {
    Row() { /* two panes */ }
  } else {
    Column() { /* single pane */ }
  }
}
```

| Signal | Values |
| --- | --- |
| `widthClass` / `heightClass` | `compact` · `medium` · `expanded` · `large` (`SparkSizeClassName`) |
| `env.posture` | `flat` · `book` · `tabletop` (fold posture) |
| `env.modality` | `touch` · `pointer` (input modality) |
| `env.windowMode` | `fullscreen` · split / floating … |
| `env.safeArea` / `env.keyboardHeight` | insets and soft keyboard height (vp) |

## Container queries

`SparkContainer` measures itself and provides a local `widthClass` to its subtree. Components call `resolveSparkLayout()` in `onDidBuild` to get the nearest container, falling back to the window context:

```arkts
SparkContainer() {
  ContainerProbe()     // resolveSparkLayout(this.getUIContext(), this.getUniqueId())
}
```

## Simulating devices

During development you can override the context only (the window keeps its size) to exercise adaptive decisions:

```arkts
SparkUI.layout.simulate(390, 844, 'flat', 'touch', 'fullscreen');      // phone
SparkUI.layout.simulate(840, 900, 'book', 'touch', 'fullscreen');      // foldable (book)
SparkUI.layout.simulate(1280, 800, 'tabletop', 'pointer', 'fullscreen');
SparkUI.layout.simulate(undefined, 0, 'flat', 'touch', 'fullscreen');  // back to the real window
```

::: tip Prefer breakpoint-free layout
Most layouts never need to read the context — use the primitives from [Responsive Layout](/en/guide/responsive). The window context is for global decisions such as the navigation style, and for modality-dependent semantic translation.
:::
