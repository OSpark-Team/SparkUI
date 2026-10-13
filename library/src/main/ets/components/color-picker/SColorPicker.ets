import { sparkEmptyBuilder } from '../../core/Builders';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkText } from '../../core/SparkText';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { sparkSheetHandle } from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkSurface, sparkSurfaceDefaults, SparkSurfaceStyle, SparkSurfaceTokens
} from '../../theme/tokens/SparkTokenReader';
import { ButtonSize, ButtonStyle, ButtonStyleModifier, ButtonVariants } from '../button/ButtonVariants';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';
import { InputSize } from '../input/SInput';
import {
  ColorPickerFormat, sparkColorValueToArgb, sparkFormatColor, sparkParseColor, SPARK_DEFAULT_SWATCHES
} from './ColorPickerLogic';
import { SparkColorChip } from './ColorPickerParts';
import { ColorPickerStyle, ColorPickerTokens, sparkColorPickerStyle } from './ColorPickerStyle';
import { SColorPanel } from './SColorPanel';

/** Outline-button trigger: colour chip + value text (or the chip alone). */
@ComponentV2
struct SparkColorTrigger {
  @Param text: string = '';
  /** `#AARRGGBB` */
  @Param argb: string = '#00000000';
  @Param iconOnly: boolean = false;
  @Param sizing: InputSize = 'default';
  @Param disabled: boolean = false;
  @Param triggerWidth: Length | undefined = undefined;
  @Param triggerKey: string = '';
  @Param open: boolean = false;
  @Param label: string = '';
  @Param style: ColorPickerStyle = new ColorPickerStyle();
  @Event onActivate: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get buttonSize(): ButtonSize {
    if (this.iconOnly) {
      return this.sizing === 'sm' ? 'icon-sm' : (this.sizing === 'lg' ? 'icon-lg' : 'icon');
    }
    return this.sizing === 'sm' ? 'sm' : (this.sizing === 'lg' ? 'lg' : 'default');
  }

  @Computed
  get styles(): ButtonStyle {
    return ButtonVariants.resolve(this.theme, 'outline', this.buttonSize);
  }

  @Computed
  get recipe(): ButtonStyleModifier {
    return new ButtonStyleModifier(this.styles, this.ix.hovered, this.disabled, 1);
  }

  @Computed
  get chip(): number {
    return this.sizing === 'sm' ? 16 : (this.sizing === 'lg' ? 20 : 18);
  }

  build() {
    Button() {
      Row({ space: 8 }) {
        SparkColorChip({
          argb: this.argb,
          chipWidth: this.chip,
          chipHeight: this.chip,
          radius: this.theme.radiusSm,
          style: this.style
        })
        if (!this.iconOnly) {
          Text(this.text)
            .fontSize(this.sizing === 'lg' ? this.theme.text.base : this.theme.text.sm)
            .fontWeight(this.theme.text.weightNormal)
            .fontColor(this.theme.colors.foreground)
            .fontFeature('"tnum" on')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(this.triggerWidth !== undefined ? 1 : 0)
        }
      }
      .width(this.triggerWidth !== undefined && !this.iconOnly ? '100%' : 'auto')
      .justifyContent(this.iconOnly ? FlexAlign.Center : FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(this.recipe)
    .width(this.iconOnly ? this.styles.height : (this.triggerWidth ?? 'auto'))
    .padding(this.iconOnly ? { left: 0, right: 0, top: 0, bottom: 0 } :
      { left: this.styles.paddingX - 4, right: this.styles.paddingX, top: 0, bottom: 0 })
    .id(this.triggerKey)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.label)
    .accessibilityDescription(`${this.text}, ${this.open ?
      sparkText(this.getUIContext(), $r('app.string.spark_state_expanded'), 'expanded') :
      sparkText(this.getUIContext(), $r('app.string.spark_state_collapsed'), 'collapsed')}`)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => {
      if (!this.disabled) {
        this.onActivate();
      }
    })
  }
}

/**
 * Colour picker: an outline-button trigger showing the colour chip and value (or only the chip with
 * `iconOnly`) that opens an {@link SColorPanel} in a popover anchored below the trigger, or in a bottom sheet
 * on compact touch windows (`adaptive: 'auto'`).
 *
 * ```
 * SColorPicker({ value: this.brand!! })                                        // '#3b82f6'
 * SColorPicker({ value: this.tint!!, alpha: true, format: 'oklch', formatToggle: true })
 * SColorPicker({ defaultValue: '#f43f5e', iconOnly: true, sizing: 'sm', onValueCommit: (v: string) => ... })
 * SColorPicker({ value: this.c!!, swatches: ['#000', '#fff', '#3b82f6'], recent: true }) { Text('footer') }
 * ```
 * Values follow {@link SColorPanel}: a colour string in `format` ('hex' default), `onValueChange` live while
 * dragging, `onValueCommit` when an interaction ends and once more on close if the last value was not
 * committed yet. The trailing closure renders at the bottom of the panel. `tokens` restyle the panel
 * (`--color-picker-*`); `surfaceTokens` the popover surface (`--popover-*`).
 */
@ComponentV2
export struct SColorPicker {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '#000000';
  /** Format of emitted values and of the trigger text. */
  @Param format: ColorPickerFormat = 'hex';
  @Param alpha: boolean = false;
  @Param disabled: boolean = false;
  /** Trigger (and panel input) size. */
  @Param sizing: InputSize = 'default';
  /** Square trigger showing only the colour chip. */
  @Param iconOnly: boolean = false;
  /** Trigger width; undefined → fits its content. */
  @Param triggerWidth: Length | undefined = undefined;
  @Param formatToggle: boolean = false;
  @Param showInput: boolean = true;
  @Param swatches: string[] = SPARK_DEFAULT_SWATCHES;
  @Param recent: boolean = false;
  /** Accessible name of the trigger (default "Pick a color"). */
  @Param label: string | undefined = undefined;
  @Param adaptive: SparkAdaptive = 'auto';
  /** Panel tokens (instance → `--color-picker-*` → recipe). */
  @Param tokens: ColorPickerTokens = {};
  /** Popover surface tokens (instance → `--popover-*` → recipe). */
  @Param surfaceTokens: SparkSurfaceTokens = {};
  @Event onValueChange: (v: string) => void = () => {
  };
  @Event onValueCommit: (v: string) => void = () => {
  };
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local current: string = '#000000';
  @Local sheet: boolean = false;
  @Local disclosure: SparkDisclosure = new SparkDisclosure();
  private binding: OverlayBinding = new OverlayBinding();
  private lastCommitted: string = '';
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.current = this.value ?? this.defaultValue;
    this.lastCommitted = this.current;
    this.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
    this.disclosure.triggerUniqueId = this.getUniqueId();
    this.disclosure.emit = (open: boolean) => this.onOpenChange(open);
    this.unsubscribe = this.disclosure.subscribe((open: boolean) => {
      if (!open && this.current !== this.lastCommitted) {
        this.commit(this.current);
      }
    });
    this.binding.attach(this.getUIContext(), this.disclosure, (scope: SparkOverlayScope) => {
      this.sheet = sparkUseSheet(this.adaptive);
      scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
      scope.motionKey = this.sheet ? 'sheet' : 'popover';
      scope.modal = this.sheet;
      scope.dismissOnOutside = true;
      scope.anchor = this.disclosure.anchorRect(this.getUIContext());
      scope.side = 'bottom';
      scope.alignment = 'start';
      scope.sideOffset = 4;
      scope.content = this.panel;
      scope.theme = this.theme;
      scope.layout = this.layout;
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
    this.binding.dispose();
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.current = this.value;
    }
  }

  @Monitor('disabled')
  syncDisabled(): void {
    if (this.disabled) {
      this.disclosure.setOpen(false);
    }
  }

  private set(v: string): void {
    this.current = v;
    this.$value(v);
    this.onValueChange(v);
  }

  private commit(v: string): void {
    this.lastCommitted = v;
    this.onValueCommit(v);
  }

  @Computed
  get styles(): ColorPickerStyle {
    return sparkColorPickerStyle(this.theme, this.tokens);
  }

  @Computed
  get surface(): SparkSurfaceStyle {
    const t = this.theme;
    return sparkSurface(t, 'popover', sparkSurfaceDefaults(t.colors.popover, t.colors.border, t.borderWidth,
      t.radiusMd, 12, t.shadows.md), this.surfaceTokens);
  }

  @Computed
  get argb(): string {
    return sparkColorValueToArgb(this.current, '#00000000');
  }

  @Computed
  get text(): string {
    const c = sparkParseColor(this.current);
    return c === undefined ? this.current : sparkFormatColor(c, this.format, this.alpha);
  }

  @Computed
  get accessibleName(): string {
    return this.label ?? sparkText(this.getUIContext(), $r('app.string.spark_pick_color'), 'Pick a color');
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      SColorPanel({
        value: this.current,
        format: this.format,
        alpha: this.alpha,
        disabled: this.disabled,
        sizing: this.sizing,
        showInput: this.showInput,
        formatToggle: this.formatToggle,
        swatches: this.swatches,
        recent: this.recent,
        panelWidth: this.sheet ? '100%' : this.styles.width,
        label: this.label,
        tokens: this.tokens,
        onValueChange: (v: string) => this.set(v),
        onValueCommit: (v: string) => this.commit(v)
      }) {
        this.content()
      }
    }
    .width(this.sheet ? '100%' : this.styles.width + 2 * this.surface.padding + 2 * this.surface.borderWidth)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: this.surface.padding,
      right: this.surface.padding,
      top: this.sheet ? 8 : this.surface.padding,
      bottom: this.surface.padding + (this.sheet ? this.layout.env.safeArea.bottom : 0)
    })
    .backgroundColor(this.surface.background)
    .border({
      width: this.sheet ? { top: this.surface.borderWidth } : this.surface.borderWidth,
      color: this.surface.borderColor,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.surface.radius
    })
    .shadow(SparkTokenOverride.shadowOptions(this.surface.shadow))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    SparkColorTrigger({
      text: this.text,
      argb: this.argb,
      iconOnly: this.iconOnly,
      sizing: this.sizing,
      disabled: this.disabled,
      triggerWidth: this.triggerWidth,
      triggerKey: sparkTriggerKey(this.getUniqueId()),
      open: this.disclosure.open,
      label: this.accessibleName,
      style: this.styles,
      onActivate: () => this.disclosure.toggle()
    })
  }
}
