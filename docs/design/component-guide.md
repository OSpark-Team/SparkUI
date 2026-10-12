# SparkUI 组件开发规范（必读）

本文件是实现任何 SparkUI 组件前必须遵守的约定。规则均已经过编译或真机验证，背景见 `00-architecture-decisions.md`（D1–D11）。

## 1. 命名与 API（编译强制）

- 组件 struct 一律加 **`S` 前缀**，去掉前缀即为 shadcn-vue 名称：`SCheckbox`、`STabsList`、`SAccordionItem`。
- **prop 不得与通用属性/事件同名**（编译错误 10505001）：
  - `size` → `sizing`，`align` → `alignment`，`id` → `inputId`
  - 同样不可用的还有 `width`、`height`、`padding`、`margin`、`border`、`opacity`、`enabled`、`visibility`、`direction`、`offset`、`position`、`scale`、`onClick`、`onFocus`、`onBlur`、`onHover`、`onAppear`、`onTouch` 等。
  - 遇到冲突时语义改名，并写进组件的文档注释。
- **点击**用原生通用事件 `.onClick()`（写在组件上）；禁用时组件内部用 `SparkTapBlocker`（gestureModifier）吞掉点击。
- **使用尾随闭包插槽的组件后面不能链式写属性**。在示例中如需点击，外层包一个 `Stack().onClick()`。
- 每个容器 / 复合组件**只暴露一个** `@BuilderParam content: () => void = sparkEmptyBuilder`，保证 `SComp() { ... }` 写法可用。
- 简单场景提供快捷 prop：`text`、`label`、`icon`……
- 所有用到的 ArkUI API 必须在 compatibleSdk 22 上可用；有疑问时用 `devecocli docs search` 查证。不要用 SDK 23 及以上的 API，例如 `Circle.fill`、`stateStyles.hovered`、`Canvas(params)`。

## 2. 主题 / Token

- 读取：`@Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;`
- 所有颜色、圆角、间距、字号、阴影都必须来自 Token：
  - 颜色：`theme.colors.*`（`#AARRGGBB` 字符串）
  - 圆角：`theme.radiusSm/Md/Lg/Xl`
  - 字号 / 字重：`theme.text.xs…xxxxl`、`theme.text.weightMedium` 等
  - 阴影：`theme.shadows.xs…xxl.toOptions()`
  - 动效：`theme.motion.*`
- **禁止**写死颜色，也不要用 `$r('app.color…')`。
- 透明度派生用 `SparkColor.alpha(hex, 0.5)`（等价于 Tailwind 的 `bg-primary/50`），混色用 `SparkColor.mix(a, b, t)`。
- 圆角必须写在 `border({ width, color, radius })` 里：单独写 `.borderRadius()` 之后再调用 `border()` 会把圆角重置为 0。
- 焦点环：`.focusBox(sparkFocusRing(this.theme))`，只在键盘走焦时显示，等价于 `:focus-visible`。

## 3. 交互态

- **pressed 不能用 `onTouch` 状态驱动**（真机复现过：快速切换点击时，上一个按钮会残留按下态）。正确做法：
  - 内联 `stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })`，配合组件内的 `@Styles`；
  - 或样式在 `AttributeModifier` 中时，实现 `applyPressedAttribute`（参见 `ButtonVariants.ets`）；
  - **按压态不加任何过渡动画**：不要在 pressed / stateStyles 所在的属性链上写 `.animation()`。按下和松开都要瞬时切换（与原生一致）；否则松开时的淡出会残留，快速连续点击两个按钮时，会出现两个按钮同时呈按下态（用户真机反馈过）。只有与按压无关的视觉（Switch 滑块、Accordion 箭头、Progress）可以加动画，而且这些动画要写在不会影响按压属性的节点上。
- hover：`@Local ix: SparkInteraction = new SparkInteraction();` 再加 `.onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))`。
- disabled：视觉 `opacity(0.5)`，用 `SparkTapBlocker` 拦截点击，并设 `focusable(false)`。
- 无障碍：`accessibilityText`、`accessibilityRole`（18+）、`accessibilityChecked` / `accessibilitySelected`（13+）。

## 3.5 动效（D12）

- 一律使用 `SparkAnim`（core/SparkAnim.ets），每个组件取一个动效 key（kebab-case 组件名，例如 'checkbox'），速度档选 'fast' | 'normal' | 'slow'：
  - 隐式动画：`.animation(SparkAnim.attr(this.theme, 'accordion', 'normal'))`
  - 显式动画：`SparkAnim.run(this.getUIContext(), this.theme, 'tabs', 'fast', () => { ...状态变化 })`
  - 出现 / 消失：`.transition(SparkAnim.enter(this.theme, 'checkbox', 'fast', 0.5))`
- 禁止写死 `{ duration: 200 }` 或直接调用 `animateTo`：所有动画都必须能被 `--motion-*` 配置或关闭。
- 不要对按压态加动画；选中切换不要让两个兄弟节点同时渐变背景（改用单个移动的指示器，或者瞬切）。
- 无限动画（如 Spinner）放在独立节点里，条件变化时直接移除该节点；不要在同一节点上切换属性，否则旋转不会停。

## 4. 值组件：受控 / 非受控

```ts
@Param checked: boolean | undefined = undefined;      // 受控（配合 !!）
@Event $checked: (v: boolean) => void = () => {};     // !! 语法要求的名字：'$' + 参数名
@Param defaultChecked: boolean = false;               // 非受控初始值
@Event onCheckedChange: (v: boolean) => void = () => {};
@Local current: boolean = false;

aboutToAppear() { this.current = this.checked ?? this.defaultChecked; }
@Monitor('checked') sync() { if (this.checked !== undefined) { this.current = this.checked; } }
private set(v: boolean) {
  if (this.checked === undefined) { this.current = v; }
  this.$checked(v);
  this.onCheckedChange(v);
}
```

- 布尔类：Checkbox / Switch 用 `checked`，Toggle 用 `pressed`，Collapsible / Accordion 等用 `open`。
- 其他：`value`（Input、Slider、RadioGroup、Tabs、ToggleGroup、Select……），对应 `onValueChange`。
- 使用方：`SSwitch({ checked: this.on!! })` 或 `SSwitch({ defaultChecked: true, onCheckedChange: … })`。

## 5. 复合组件共享状态：SparkContext

- 插槽内容里的 `@Consumer` 解析到的是**定义插槽的组件**，不是宿主（真机已验证），所以复合组件之间的共享状态必须用 `SparkContext`。参考 `components/dialog/SDialog.ets`：
  - 根组件：`@Local state = new XxxState()`（`@ObservedV2` 类，字段用 `@Trace`）；在 `aboutToAppear` 中 `SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state)`，在 `aboutToDisappear` 中 `SparkContext.revoke(this.getUniqueId())`。
  - 子组件：`@Local ctx: XxxState | undefined = undefined;`，在 `onDidBuild()` 中 `if (this.ctx === undefined) this.ctx = SparkContext.resolve<XxxState>(this.getUIContext(), this.getUniqueId(), KEY);`。
  - 子组件初次 build 时 ctx 可能还是 undefined，必须给出合理的默认渲染。
  - **解析必须经过 `SparkContext.whenAttached`**：`onDidBuild() { SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve()); }`。由 ForEach / LazyForEach / if 创建的组件在执行 onDidBuild 时还没挂到树上，此时 `getFrameNodeByUniqueId` 返回 null（真机已验证），直接解析会失败。
- 不要用 `@Monitor('ctx.xxx')` 监听可选 `@Local` 对象的路径（编译告警）；需要副作用时，在状态类里提供 `subscribe()`。
- ArkTS 不支持 `??=`，请写成 `if` 判断。

## 6. 响应式（无感断点，D11）

- 组件根据**自己拿到的空间**自适应：用 `onAreaChange` 测量自身宽度（`onSizeChange` 首次布局不触发）。
- 窄时更紧凑，宽时更舒展：例如 Field 宽时标签在左、窄时标签在上；Tabs 放不下时横向滚动；Pagination 窄时只显示上一页 / 页码 / 下一页。
- 需要窗口级信号（输入方式等）时用 `@Consumer('sparkLayout')`；容器级上下文用 `resolveSparkLayout()`。

## 7. 浮层组件

- 统一用 `openSparkOverlay(uiContext, scope)` 和 `closeSparkOverlay(scope)`。scope 由 `SparkOverlayService.createScope()` 创建。
- 内容用 `@LocalBuilder panel()`（保证 `this` 绑定），参考 `SDialogContent`、`SPopoverContent`、`SSheetContent`。

## 8. ArkTS 严格模式常见坑

- 不允许 any / unknown、索引签名、对象字面量充当未声明的类型、解构、`for..in`、函数表达式（要用箭头函数）。
- 箭头函数需要写返回类型时显式写 `: void` 等；对象字面量需要有对应的 interface / class 类型。
- struct 内不能有与 `CustomComponent` 成员同名的字段（例如 `width`），改名为 `measuredWidth` 等。
- `@BuilderParam` 默认值用 `sparkEmptyBuilder`（从 `core/Builders` 导入）。
- `Flex` 的 `space` 用 `{ main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }`（从 `@kit.ArkUI` 导入 `LengthMetrics`）；类型名为 `FlexSpaceOptions`。

## 9. 文件组织与验证

- 每个组件一个目录：`library/src/main/ets/components/<name>/S<Name>.ets`（variant 配方可放在同目录）。
- 对外导出加在 `library/Index.ets`。
- 静态检查：`devecocli check arkts <文件...>`（需在沙箱外运行）。
- 构建：`devecocli build`。真机验证：`devecocli run --module gallery --device 172.15.125.54:5555`，再配合 `tools/dev.sh`。
