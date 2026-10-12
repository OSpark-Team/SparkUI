import { SparkAnim } from '../../core/SparkAnim';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkOptionList, SparkOptionRow } from '../../primitives/list/SparkOptionList';
import {
  SparkOptionEntry, sparkOptionEntries, SparkOptionSource
} from '../../primitives/list/SparkOptionLogic';
import { MenuLabel, MenuSeparator } from '../../primitives/menu/MenuRow';
import {
  SPARK_SHEET_HANDLE_HEIGHT, sparkMenuPanelMaxHeight, SparkMenuScroll, sparkSheetHandle
} from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkOptionPanel, SparkOptionPanelStyle, SparkOptionPanelTokens, sparkSurfaceDefaults
} from '../../theme/tokens/SparkTokenReader';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';

const KEY: string = 'spark.select';

/** Data-driven option (use with `SSelect({ options })` / `SCombobox({ options })`). */
export class SparkSelectOption implements SparkOptionSource {
  value: string;
  label: string;
  disabled: boolean;
  /** optional group heading this option starts */
  group: string | undefined;

  constructor(value: string, label: string, disabled?: boolean, group?: string) {
    this.value = value;
    this.label = label;
    this.disabled = disabled === true;
    this.group = group;
  }
}

@ObservedV2
export class SparkSelectState {
  @Trace value: string = '';
  @Trace version: number = 0;
  /** row under the pointer (compound items; data mode keeps its own) */
  @Trace highlighted: string = '';
  readonly disclosure: SparkDisclosure = new SparkDisclosure();
  @Trace disabled: boolean = false;
  /** panel colours resolved by SSelectContent (compound items read the highlight colours) */
  @Trace panel: SparkOptionPanelStyle | undefined = undefined;
  private labels: Map<string, string> = new Map<string, string>();
  emit: (v: string) => void = () => {
  };

  register(value: string, label: string): void {
    if (this.labels.get(value) !== label) {
      this.labels.set(value, label);
      this.version++;
    }
  }

  /** Register many labels with a single notification (data mode: O(n), one re-render of the trigger). */
  registerAll(options: SparkSelectOption[]): void {
    let changed = false;
    for (let i = 0; i < options.length; i++) {
      const o = options[i];
      if (this.labels.get(o.value) !== o.label) {
        this.labels.set(o.value, o.label);
        changed = true;
      }
    }
    if (changed) {
      this.version++;
    }
  }

  labelOf(value: string): string | undefined {
    return this.version >= 0 ? this.labels.get(value) : undefined;
  }

  select(v: string): void {
    this.emit(v);
    this.disclosure.setOpen(false);
  }
}

/**
 * shadcn-vue `Select`. Two styles of use:
 *
 * ```
 * // data-driven (labels known up front) — virtualized: 10 000 options open instantly
 * SSelect({ value: this.fruit!!, placeholder: 'Select a fruit', options: FRUITS })
 *
 * // compound, like shadcn (short, hand-written lists)
 * SSelect({ value: this.theme!! }) {
 *   SSelectTrigger({ placeholder: 'Theme' })
 *   SSelectContent() {
 *     SSelectItem({ value: 'light', text: 'Light' })
 *     SSelectItem({ value: 'dark', text: 'Dark' })
 *   }
 * }
 * ```
 * Anchored list on pointer / wide screens, bottom sheet on compact touch screens.
 *
 * The data form renders its options with `List` + `Repeat.virtualScroll()` (ADR D14): only the visible rows
 * exist, and the list opens scrolled to the selected option. The compound form builds every item (slot content
 * cannot be virtualized) — use `options` for anything longer than a screenful.
 *
 * Panel tokens (ADR D13/D14): `--select-*` (`background` `border-color` `radius` `border-width` `padding` `shadow`
 * `highlight-background` `highlight-foreground` `max-height`), falling back to the shared `--menu-*` surface;
 * per instance via `tokens`.
 */
@ComponentV2
export struct SSelect {
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @Param placeholder: ResourceStr = $r('app.string.spark_select_placeholder');
  /** data-driven mode: renders its own trigger + (virtualized) content */
  @Param options: SparkSelectOption[] = [];
  @Param disabled: boolean = false;
  @Param adaptive: SparkAdaptive = 'auto';
  /** data mode: panel overrides (see SSelectContent) */
  @Param tokens: SparkOptionPanelTokens = {};
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkSelectState = new SparkSelectState();

  aboutToAppear(): void {
    this.state.value = this.value ?? this.defaultValue;
    this.state.disabled = this.disabled;
    this.state.registerAll(this.options);
    this.state.emit = (v: string) => {
      if (this.value === undefined) {
        this.state.value = v;
      }
      this.$value(v);
      this.onValueChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('value')
  sync(): void {
    if (this.value !== undefined) {
      this.state.value = this.value;
    }
  }

  @Monitor('disabled')
  syncDisabled(): void {
    this.state.disabled = this.disabled;
  }

  @Monitor('options')
  syncOptions(): void {
    this.state.registerAll(this.options);
  }

  build() {
    Stack() {
      if (this.options.length > 0) {
        Column() {
          SSelectTrigger({ placeholder: this.placeholder })
          SSelectContent({ adaptive: this.adaptive, options: this.options, tokens: this.tokens })
        }
      }
      this.content()
    }
  }
}

/** Input-styled trigger showing the selected label (or the placeholder) and a chevron. */
@ComponentV2
export struct SSelectTrigger {
  @Param placeholder: ResourceStr = $r('app.string.spark_select_placeholder');
  /** 'default' h-9, 'sm' h-8 */
  @Param sizing: 'default' | 'sm' = 'default';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkSelectState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkSelectState>(this.getUIContext(), this.getUniqueId(), KEY);
      if (this.state !== undefined) {
        this.state.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
        this.state.disclosure.triggerUniqueId = this.getUniqueId();
      }
    }
  }

  @Computed
  get label(): string | undefined {
    const s = this.state;
    if (s === undefined || s.value.length === 0) {
      return undefined;
    }
    return s.labelOf(s.value) ?? s.value;
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.5) : this.theme.colors.accent)
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.3) : Color.Transparent)
  }

  build() {
    Row({ space: 8 }) {
      Text(this.label ?? this.placeholder)
        .layoutWeight(1)
        .fontSize(this.theme.text.sm)
        .fontColor(this.label !== undefined ? this.theme.colors.foreground : this.theme.colors.mutedForeground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SIcon({ name: 'chevron-down', sizing: 16, color: SparkColor.alpha(this.theme.colors.mutedForeground, 0.8) })
        .rotate({ angle: this.state?.disclosure.open === true ? 180 : 0 })
        .animation(SparkAnim.attr(this.theme, 'select', 'normal'))
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .height(this.sizing === 'sm' ? 32 : 36)
    .constraintSize({ minWidth: 128 })
    .padding({ left: 12, right: 12 })
    .border({ width: this.theme.borderWidth, color: this.theme.colors.input, radius: this.theme.radiusMd })
    .shadow(this.theme.shadows.xs.toOptions())
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .opacity(this.state?.disabled === true ? 0.5 : 1)
    .focusable(true)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.SELECT)
    .accessibilityText(this.label ?? '')
    .onClick(() => {
      if (this.state !== undefined && !this.state.disabled) {
        this.state.disclosure.toggle();
      }
    })
  }
}

/**
 * The option list: as wide as the trigger (at least), anchored below it; bottom sheet on compact touch.
 * With `options` (what `SSelect({ options })` passes) the rows are virtualized; otherwise the slot is rendered.
 *
 * `tokens` / `--select-*` → `--menu-*` → `bg-popover rounded-md border p-1 shadow-md`.
 */
@ComponentV2
export struct SSelectContent {
  @Param adaptive: SparkAdaptive = 'auto';
  /** max list height before scrolling (vp); `--select-max-height` / `tokens.maxHeight` override it */
  @Param maxListHeight: number = 320;
  /** data mode: virtualized rows instead of the slot */
  @Param options: SparkSelectOption[] = [];
  @Param tokens: SparkOptionPanelTokens = {};
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local state: SparkSelectState | undefined = undefined;
  @Local sheet: boolean = false;
  @Local anchorWidth: number = 128;
  /** data mode: keyboard / pointer highlighted row */
  @Local highlighted: string = '';
  /** the open overlay scope: its placement gives the height available to the list */
  @Local scope: SparkOverlayScope | undefined = undefined;
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      const state = SparkContext.resolve<SparkSelectState>(this.getUIContext(), this.getUniqueId(), KEY);
      this.state = state;
      if (state !== undefined) {
        state.panel = this.surface;
        this.binding.attach(this.getUIContext(), state.disclosure, (scope: SparkOverlayScope) => {
          this.scope = scope;
          this.sheet = sparkUseSheet(this.adaptive);
          state.disclosure.placement = this.sheet ? 'sheet' : 'anchored';
          state.panel = this.surface;
          this.highlighted = state.value;
          state.highlighted = '';
          const anchor = state.disclosure.anchorRect(this.getUIContext());
          this.anchorWidth = anchor !== undefined ? anchor.width : 128;
          scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
          scope.motionKey = 'select';
          scope.modal = this.sheet;
          scope.anchor = anchor;
          scope.side = 'bottom';
          scope.alignment = 'start';
          scope.sideOffset = 4;
          scope.content = this.panel;
          scope.contextKey = KEY;
          scope.contextValue = state;
          scope.theme = this.theme;
          scope.layout = this.layout;
        });
      }
    }
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @Computed
  get surface(): SparkOptionPanelStyle {
    const t = this.theme;
    return sparkOptionPanel(t, 'select', 'menu', sparkSurfaceDefaults(t.colors.popover, t.colors.border,
      t.borderWidth, this.sheet ? t.radiusXl : t.radiusMd, this.sheet ? 8 : 4, t.shadows.md),
      this.sheet ? 420 : this.maxListHeight, this.tokens);
  }

  @Monitor('surface')
  publishSurface(): void {
    if (this.state !== undefined) {
      this.state.panel = this.surface;
    }
  }

  @Computed
  get entries(): SparkOptionEntry[] {
    return sparkOptionEntries(this.options);
  }

  /** panel padding, border and sheet handle around the list (vp) */
  private chrome(): number {
    const s = this.surface;
    if (this.sheet) {
      return s.padding * 2 + s.borderWidth + SPARK_SHEET_HANDLE_HEIGHT + this.layout.env.safeArea.bottom;
    }
    return s.padding * 2 + s.borderWidth * 2;
  }

  /** `max-height` token / instance value, never taller than the space the placement leaves */
  private listMax(): number {
    return Math.min(this.surface.maxHeight, sparkMenuPanelMaxHeight(this.scope, this.sheet, this.chrome()));
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      if (this.options.length > 0) {
        SparkOptionList({
          entries: this.entries,
          selected: this.state?.value ?? '',
          highlighted: this.highlighted,
          roomy: this.sheet,
          maxListHeight: this.listMax(),
          highlightBackground: this.surface.highlightBackground,
          highlightForeground: this.surface.highlightForeground,
          onPick: (v: string) => this.state?.select(v),
          onHighlight: (v: string) => {
            this.highlighted = v;
          }
        })
      } else {
        SparkMenuScroll({ maxListHeight: this.listMax() }) {
          this.content()
        }
      }
    }
    // definite width (the trigger's): '100%' rows would otherwise resolve against the overlay layer
    .width(this.sheet ? '100%' : Math.max(this.anchorWidth, 128))
    .padding(this.sheet ? {
      left: this.surface.padding,
      right: this.surface.padding,
      top: this.surface.padding,
      bottom: this.surface.padding + this.layout.env.safeArea.bottom
    } : this.surface.padding)
    .backgroundColor(this.surface.background)
    .border({
      width: this.sheet ? { top: this.surface.borderWidth } : this.surface.borderWidth,
      color: this.surface.borderColor,
      radius: this.sheet ? { topLeft: this.surface.radius, topRight: this.surface.radius } : this.surface.radius
    })
    .shadow(SparkTokenOverride.shadowOptions(this.surface.shadow))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    // Compound mode: items are also built here, invisibly, so their labels register before the list is first
    // opened (the trigger can then show "China Standard Time" instead of "cst"). Data mode registers the labels
    // from `options` and builds nothing here.
    Column() {
      if (this.options.length === 0) {
        this.content()
      }
    }
    .width(0)
    .height(0)
    .clip(true)
    .visibility(Visibility.Hidden)
  }
}

/** One option of the compound form (same row as the data form: check on the right, opacity fade on press). */
@ComponentV2
export struct SSelectItem {
  @Param value: string = '';
  @Param text: string = '';
  @Param disabled: boolean = false;
  @Local state: SparkSelectState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkSelectState>(this.getUIContext(), this.getUniqueId(), KEY);
      this.state?.register(this.value, this.text);
    }
  }

  @Monitor('value', 'text')
  reRegister(): void {
    this.state?.register(this.value, this.text);
  }

  @Computed
  get entry(): SparkOptionEntry {
    return new SparkOptionEntry(`o:${this.value}`, 'option', this.value, this.text, this.disabled);
  }

  build() {
    SparkOptionRow({
      entry: this.entry,
      selected: this.state?.value ?? '',
      highlighted: this.state?.highlighted ?? '',
      roomy: this.state?.disclosure.placement === 'sheet',
      highlightBackground: this.state?.panel?.highlightBackground ?? '',
      highlightForeground: this.state?.panel?.highlightForeground ?? '',
      onPick: (v: string) => this.state?.select(v),
      onHighlight: (v: string) => {
        if (this.state !== undefined) {
          this.state.highlighted = v;
        }
      }
    })
  }
}

@ComponentV2
export struct SSelectLabel {
  @Param text: ResourceStr = '';

  build() {
    MenuLabel({ text: this.text, muted: true })
  }
}

@ComponentV2
export struct SSelectSeparator {
  build() {
    MenuSeparator()
  }
}

@ComponentV2
export struct SSelectGroup {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
  }
}
