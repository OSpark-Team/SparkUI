import { SparkAnim } from '../../core/SparkAnim';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { MenuLabel, MenuRow, MenuSeparator } from '../../primitives/menu/MenuRow';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';

const KEY: string = 'spark.select';

/** Data-driven option (use with `SSelect({ options })`). */
export class SparkSelectOption {
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
  readonly disclosure: SparkDisclosure = new SparkDisclosure();
  @Trace disabled: boolean = false;
  private labels: Map<string, string> = new Map<string, string>();
  emit: (v: string) => void = () => {
  };

  register(value: string, label: string): void {
    if (this.labels.get(value) !== label) {
      this.labels.set(value, label);
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
 * // data-driven (labels known up front)
 * SSelect({ value: this.fruit!!, placeholder: 'Select a fruit', options: FRUITS })
 *
 * // compound, like shadcn
 * SSelect({ value: this.theme!! }) {
 *   SSelectTrigger({ placeholder: 'Theme' })
 *   SSelectContent() {
 *     SSelectItem({ value: 'light', text: 'Light' })
 *     SSelectItem({ value: 'dark', text: 'Dark' })
 *   }
 * }
 * ```
 * Anchored list on pointer / wide screens, bottom sheet on compact touch screens.
 */
@ComponentV2
export struct SSelect {
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @Param placeholder: ResourceStr = 'Select…';
  /** data-driven mode: renders its own trigger + content */
  @Param options: SparkSelectOption[] = [];
  @Param disabled: boolean = false;
  @Param adaptive: SparkAdaptive = 'auto';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkSelectState = new SparkSelectState();

  aboutToAppear(): void {
    this.state.value = this.value ?? this.defaultValue;
    this.state.disabled = this.disabled;
    this.options.forEach((o: SparkSelectOption) => this.state.register(o.value, o.label));
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

  build() {
    Stack() {
      if (this.options.length > 0) {
        Column() {
          SSelectTrigger({ placeholder: this.placeholder })
          SSelectContent({ adaptive: this.adaptive }) {
            ForEach(this.options, (o: SparkSelectOption) => {
              if (o.group !== undefined) {
                SSelectLabel({ text: o.group })
              }
              SSelectItem({ value: o.value, text: o.label, disabled: o.disabled })
            }, (o: SparkSelectOption) => o.value)
          }
        }
      }
      this.content()
    }
  }
}

/** Input-styled trigger showing the selected label (or the placeholder) and a chevron. */
@ComponentV2
export struct SSelectTrigger {
  @Param placeholder: ResourceStr = 'Select…';
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
    .border({ width: 1, color: this.theme.colors.input, radius: this.theme.radiusMd })
    .shadow(this.theme.shadows.xs.toOptions())
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .opacity(this.state?.disabled === true ? 0.5 : 1)
    .focusable(true)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityText(this.label ?? '')
    .onClick(() => {
      if (this.state !== undefined && !this.state.disabled) {
        this.state.disclosure.toggle();
      }
    })
  }
}

/** The option list: as wide as the trigger (at least), anchored below it; bottom sheet on compact touch. */
@ComponentV2
export struct SSelectContent {
  @Param adaptive: SparkAdaptive = 'auto';
  /** max list height before scrolling (vp) */
  @Param maxListHeight: number = 320;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local state: SparkSelectState | undefined = undefined;
  @Local sheet: boolean = false;
  @Local anchorWidth: number = 128;
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      const state = SparkContext.resolve<SparkSelectState>(this.getUIContext(), this.getUniqueId(), KEY);
      this.state = state;
      if (state !== undefined) {
        this.binding.attach(this.getUIContext(), state.disclosure, (scope: SparkOverlayScope) => {
          this.sheet = sparkUseSheet(this.adaptive);
          state.disclosure.placement = this.sheet ? 'sheet' : 'anchored';
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

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        Row() {
          Column().width(40).height(4).borderRadius(2).backgroundColor(this.theme.colors.muted)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 8 })
      }
      Scroll() {
        Column() {
          this.content()
        }
        .width('100%')
      }
      .constraintSize({ maxHeight: this.sheet ? 420 : this.maxListHeight })
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
    }
    // definite width (the trigger's): '100%' rows would otherwise resolve against the overlay layer
    .width(this.sheet ? '100%' : Math.max(this.anchorWidth, 128))
    .padding(this.sheet ? { left: 8, right: 8, top: 8, bottom: 8 + this.layout.env.safeArea.bottom } : 4)
    .backgroundColor(this.theme.colors.popover)
    .border({
      width: this.sheet ? { top: 1 } : 1,
      color: this.theme.colors.border,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusMd
    })
    .shadow(this.theme.shadows.md.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    // Items are also built here, invisibly, so their labels register before the list is first opened
    // (the trigger can then show "China Standard Time" instead of "cst").
    Column() {
      this.content()
    }
    .width(0)
    .height(0)
    .clip(true)
    .visibility(Visibility.Hidden)
  }
}

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

  build() {
    MenuRow({
      text: this.text,
      indicator: 'check-right',
      selected: this.state?.value === this.value,
      disabled: this.disabled,
      roomy: this.state?.disclosure.placement === 'sheet',
      onActivate: () => {
        this.state?.select(this.value);
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
