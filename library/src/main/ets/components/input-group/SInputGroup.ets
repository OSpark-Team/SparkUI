import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkFocusRing, SparkNoopModifier, SparkTapBlocker } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { ButtonStyle, ButtonStyleModifier, ButtonVariant, ButtonVariants } from '../button/ButtonVariants';
import { resolveSparkField, SparkFieldState, sparkFieldGrows } from '../field/SField';
import { InputColors, InputKind, sparkInputColors, sparkNoFocusBox } from '../input/SInput';

const KEY: string = 'spark.input-group';

export type InputGroupAddonAlignment = 'inline-start' | 'inline-end' | 'block-start' | 'block-end';
export type InputGroupButtonSize = 'xs' | 'sm' | 'icon-xs' | 'icon-sm';

/** State an input group shares with its parts (focus-within, invalid, disabled, the control's focus key). */
@ObservedV2
export class SparkInputGroupState {
  @Trace focused: boolean = false;
  @Trace invalid: boolean = false;
  @Trace disabled: boolean = false;
  /** `.id()` of the group's control, so addons can focus it when tapped */
  @Trace controlKey: string = '';

  focusControl(ui: UIContext): void {
    if (this.controlKey.length > 0 && !this.disabled) {
      try {
        ui.getFocusController().requestFocus(this.controlKey);
      } catch (e) {
        // the control is not focusable (e.g. hidden) — ignore
      }
    }
  }
}

function resolveGroup(ui: UIContext, id: number): SparkInputGroupState | undefined {
  return SparkContext.resolve<SparkInputGroupState>(ui, id, KEY);
}

/**
 * shadcn-vue `InputGroup` (v4): one bordered field holding an input plus addons (icons, text, buttons).
 * The group draws the border and the focus ring (`has-[:focus]:border-ring ring-ring/50 ring-[3px]`) while
 * its inner SInputGroupInput is focused.
 *
 * ```
 * SInputGroup() {
 *   SInputGroupAddon() { SIcon({ name: 'search' }) }
 *   SInputGroupInput({ placeholder: 'Search…', value: this.q!! })
 *   SInputGroupAddon({ alignment: 'inline-end' }) { SInputGroupText({ text: '12 results' }) }
 * }
 * SInputGroup() {
 *   SInputGroupInput({ placeholder: 'example.com' })
 *   SInputGroupAddon({ alignment: 'inline-end' }) { SInputGroupButton({ icon: 'copy', sizing: 'icon-xs' }) }
 * }
 * ```
 *
 * Write the parts in visual order: ArkUI cannot reorder slot children (`order-first` / `order-last`).
 * Block addons (`block-start` / `block-end`) span the full width and sit on their own line above / below the
 * input. Tapping an addon focuses the input.
 */
@ComponentV2
export struct SInputGroup {
  @Param invalid: boolean = false;
  @Param disabled: boolean = false;
  @Param modifier: AttributeModifier<FlexAttribute> = new SparkNoopModifier<FlexAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkInputGroupState = new SparkInputGroupState();
  @Local field: SparkFieldState | undefined = undefined;

  aboutToAppear(): void {
    this.syncFlags();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.field === undefined) {
      this.field = resolveSparkField(this.getUIContext(), this.getUniqueId());
      this.syncFlags();
    }
  }

  @Monitor('invalid', 'disabled')
  syncFlags(): void {
    const f = this.field;
    this.state.invalid = this.invalid || (f !== undefined && f.isInvalid);
    this.state.disabled = this.disabled;
  }

  @Computed
  get colors(): InputColors {
    const invalid = this.invalid || (this.field !== undefined && this.field.isInvalid);
    return sparkInputColors(this.theme, this.state.focused && !this.state.disabled, invalid);
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
      this.content()
    }
    .width('100%')
    .constraintSize({ minHeight: 36 })
    .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    .backgroundColor(this.colors.background)
    .border({ width: 1, color: this.colors.borderColor, radius: this.theme.radiusMd })
    .outline({
      width: this.colors.ringWidth,
      color: this.colors.ringColor,
      radius: this.theme.radiusMd + 3,
      style: OutlineStyle.SOLID
    })
    .shadow(this.theme.shadows.xs.toOptions())
    .clip(false)
    .opacity(this.disabled ? 0.5 : 1)
    .animation(SparkAnim.attr(this.theme, 'input', 'fast'))
    .attributeModifier(this.modifier)
  }
}

/**
 * Addon area: `text-muted-foreground flex items-center gap-2 py-1.5 text-sm font-medium`, with `pl-3`
 * (inline-start), `pr-3` (inline-end), or full width `px-3 pt-3` / `px-3 pb-3` (block-start / block-end).
 * Tapping it focuses the group's input.
 */
@ComponentV2
export struct SInputGroupAddon {
  @Param alignment: InputGroupAddonAlignment = 'inline-start';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkInputGroupState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveGroup(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get block(): boolean {
    return this.alignment === 'block-start' || this.alignment === 'block-end';
  }

  @Computed
  get pad(): Padding {
    switch (this.alignment) {
      case 'inline-end':
        return { left: 0, right: 12, top: 6, bottom: 6 };
      case 'block-start':
        return { left: 12, right: 12, top: 12, bottom: 6 };
      case 'block-end':
        return { left: 12, right: 12, top: 6, bottom: 12 };
      default:
        return { left: 12, right: 0, top: 6, bottom: 6 };
    }
  }

  build() {
    Row({ space: 8 }) {
      this.content()
    }
    .width(this.block ? '100%' : undefined)
    .flexShrink(0)
    .padding(this.pad)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.ctx?.focusControl(this.getUIContext()))
  }
}

/** Muted text / icon inside an addon: `text-muted-foreground flex items-center gap-2 text-sm`. */
@ComponentV2
export struct SInputGroupText {
  @Param text: ResourceStr | undefined = undefined;
  /** Leading lucide icon (16vp). */
  @Param icon: string | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 8 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 16, color: this.theme.colors.mutedForeground })
      }
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.sm)
          .fontColor(this.theme.colors.mutedForeground)
          .maxLines(1)
      }
      this.content()
    }
    .alignItems(VerticalAlign.Center)
  }
}

/**
 * Compact button for addons: shadcn `InputGroupButton` (`shadow-none`, sizes xs `h-6 px-2`, sm `h-8 px-2.5`,
 * icon-xs `size-6`, icon-sm `size-8`; default variant ghost). Clicks: native `.onClick()` on the component.
 *
 * ```
 * SInputGroupButton({ text: 'Search', variant: 'secondary' }).onClick(() => this.search())
 * SInputGroupButton({ icon: 'copy', sizing: 'icon-xs', label: 'Copy' }).onClick(() => this.copy())
 * ```
 */
@ComponentV2
export struct SInputGroupButton {
  @Param text: ResourceStr | undefined = undefined;
  /** Leading lucide icon name. */
  @Param icon: string | undefined = undefined;
  @Param variant: ButtonVariant = 'ghost';
  @Param sizing: InputGroupButtonSize = 'xs';
  @Param disabled: boolean = false;
  /** Accessible name; required for icon-only buttons. */
  @Param label: string | undefined = undefined;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get styles(): ButtonStyle {
    const s = ButtonVariants.resolve(this.theme, this.variant, 'sm');
    const small = this.sizing === 'xs' || this.sizing === 'icon-xs';
    s.height = small ? 24 : 32;
    s.square = this.sizing === 'icon-xs' || this.sizing === 'icon-sm';
    s.paddingX = s.square ? 0 : (small ? 8 : 10);
    s.gap = small ? 4 : 8;
    // xs: rounded-[calc(var(--radius)-5px)]
    s.radius = small ? Math.max(0, this.theme.radius - 5) : this.theme.radiusMd;
    s.shadow = undefined;
    s.iconSize = small ? 14 : 16;
    return s;
  }

  @Computed
  get recipe(): ButtonStyleModifier {
    return new ButtonStyleModifier(this.styles, this.ix.hovered, this.disabled, 1);
  }

  @Computed
  get tapBlocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  build() {
    Button() {
      Row({ space: this.styles.gap }) {
        if (this.icon !== undefined) {
          SIcon({ name: this.icon, sizing: this.styles.iconSize, color: this.styles.foreground })
        }
        if (this.text !== undefined) {
          Text(this.text)
            .fontSize(this.theme.text.sm)
            .fontWeight(this.theme.text.weightMedium)
            .fontColor(this.styles.foreground)
            .maxLines(1)
        }
      }
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(this.recipe)
    .focusable(!this.disabled)
    .gestureModifier(this.tapBlocker)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityText(this.label ?? (typeof this.text === 'string' ? this.text : ''))
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
  }
}

/**
 * The group's text control: an SInput-styled TextInput without its own border / ring
 * (`flex-1 rounded-none border-0 bg-transparent shadow-none`). Same value API as SInput.
 *
 * ```
 * SInputGroupInput({ placeholder: 'Search…', value: this.q!!, onSubmit: (v: string) => this.search(v) })
 * ```
 */
@ComponentV2
export struct SInputGroupInput {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Param placeholder: ResourceStr = '';
  @Param inputType: InputKind = 'text';
  @Param maxLength: number | undefined = undefined;
  /** Accessible name when there is no visible label. */
  @Param label: string | undefined = undefined;
  @Param modifier: AttributeModifier<TextInputAttribute> = new SparkNoopModifier<TextInputAttribute>();
  @Event onValueChange: (v: string) => void = () => {
  };
  @Event onSubmit: (v: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: string = '';
  @Local ctx: SparkInputGroupState | undefined = undefined;
  private controlId: string = '';

  aboutToAppear(): void {
    this.current = this.value ?? this.defaultValue;
    this.controlId = `spark-input-group-control-${this.getUniqueId()}`;
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveGroup(this.getUIContext(), this.getUniqueId());
      if (this.ctx !== undefined) {
        this.ctx.controlKey = this.controlId;
      }
    }
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.current = this.value;
    }
  }

  private set(v: string): void {
    if (v === this.current) {
      return;
    }
    this.current = v;
    this.$value(v);
    this.onValueChange(v);
  }

  @Computed
  get nativeType(): InputType {
    switch (this.inputType) {
      case 'password':
        return InputType.Password;
      case 'email':
        return InputType.Email;
      case 'number':
        return InputType.NUMBER_DECIMAL;
      default:
        return InputType.Normal;
    }
  }

  @Computed
  get disabled(): boolean {
    return this.ctx !== undefined && this.ctx.disabled;
  }

  build() {
    TextInput({ text: this.current, placeholder: this.placeholder })
      .id(this.controlId)
      .type(this.nativeType)
      .flexGrow(1)
      .flexShrink(1)
      .flexBasis(0)
      .constraintSize({ minWidth: 48 })
      .height(34)
      .padding({ left: 12, right: 12, top: 0, bottom: 0 })
      .fontSize(this.theme.text.sm)
      .fontColor(this.theme.colors.foreground)
      .placeholderColor(this.theme.colors.mutedForeground)
      .placeholderFont({ size: this.theme.text.sm })
      .caretColor(this.theme.colors.foreground)
      .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
      .backgroundColor('#00000000')
      .border({ width: 0, radius: 0 })
      .maxLength(this.maxLength ?? Infinity)
      .hoverEffect(HoverEffect.None)
      .enabled(!this.disabled)
      .focusable(!this.disabled)
      .focusBox(sparkNoFocusBox())
      .accessibilityText(this.label ?? '')
      .onChange((v: string) => this.set(v))
      .onSubmit(() => this.onSubmit(this.current))
      .onFocus(() => {
        if (this.ctx !== undefined) {
          this.ctx.focused = true;
        }
      })
      .onBlur(() => {
        if (this.ctx !== undefined) {
          this.ctx.focused = false;
        }
      })
      .attributeModifier(this.modifier)
  }
}
