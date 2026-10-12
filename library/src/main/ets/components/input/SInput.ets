import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { sparkColorMetrics, SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { LengthMetrics } from '@kit.ArkUI';
import { resolveSparkField, SparkFieldState, sparkFieldGrows } from '../field/SField';

/** `type` of an SInput (named `inputType` because of the native `InputType` enum). */
export type InputKind = 'text' | 'password' | 'email' | 'number';

/** Resolved colours shared by SInput and STextarea (shadcn input recipe). */
export class InputColors {
  background: string = '#00000000';
  borderColor: string = '#00000000';
  /** focus ring (`ring-[3px]`) colour; width is 0 unless focused */
  ringColor: string = '#00000000';
  ringWidth: number = 0;
}

/**
 * shadcn input recipe: `border-input bg-transparent dark:bg-input/30`, focus `border-ring ring-ring/50 ring-[3px]`,
 * invalid `border-destructive ring-destructive/20 dark:ring-destructive/40`.
 */
export function sparkInputColors(t: SparkTheme, focused: boolean, invalid: boolean): InputColors {
  const c = t.colors;
  const r = new InputColors();
  r.background = t.isDark ? SparkColor.alpha(c.input, 0.3) : '#00000000';
  r.borderColor = invalid ? c.destructive : (focused ? c.ring : c.input);
  r.ringColor = invalid ? SparkColor.alpha(c.destructive, t.isDark ? 0.4 : 0.2) : SparkColor.alpha(c.ring, 0.5);
  r.ringWidth = focused ? 3 : 0;
  return r;
}

/**
 * The system keyboard focus box is hidden: text fields draw their own ring (shadcn shows it for any focus,
 * pointer or touch, on text inputs).
 */
export function sparkNoFocusBox(): FocusBoxStyle {
  return {
    strokeColor: sparkColorMetrics('#00000000'),
    strokeWidth: LengthMetrics.vp(0),
    margin: LengthMetrics.vp(0)
  };
}

/**
 * shadcn-vue `Input`: `h-9 w-full rounded-md border px-3 py-1 text-sm`, styled on the native TextInput.
 *
 * ```
 * SInput({ placeholder: 'Email', inputType: 'email', value: this.email!! })
 * SInput({ defaultValue: 'hello', onValueChange: (v: string) => ... })
 * SInput({ inputType: 'password', invalid: this.error.length > 0, onSubmit: (v: string) => this.login() })
 * ```
 *
 * `inputType` instead of `type` (native enum clash). Inside an invalid SField the invalid look is applied
 * automatically; inside a horizontal SField it takes the remaining row width.
 */
@ComponentV2
export struct SInput {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Param placeholder: ResourceStr = '';
  @Param inputType: InputKind = 'text';
  @Param invalid: boolean = false;
  @Param disabled: boolean = false;
  @Param maxLength: number | undefined = undefined;
  /** Accessible name when there is no visible label. */
  @Param label: string | undefined = undefined;
  /** Extra styles applied after the recipe (wins on conflicts). */
  @Param modifier: AttributeModifier<TextInputAttribute> = new SparkNoopModifier<TextInputAttribute>();
  @Event onValueChange: (v: string) => void = () => {
  };
  /** Enter / IME action pressed; receives the current value. */
  @Event onSubmit: (v: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: string = '';
  @Local focused: boolean = false;
  @Local field: SparkFieldState | undefined = undefined;

  aboutToAppear(): void {
    this.current = this.value ?? this.defaultValue;
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.field === undefined) {
      this.field = resolveSparkField(this.getUIContext(), this.getUniqueId());
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
  get colors(): InputColors {
    const invalid = this.invalid || (this.field !== undefined && this.field.isInvalid);
    return sparkInputColors(this.theme, this.focused && !this.disabled, invalid);
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

  build() {
    TextInput({ text: this.current, placeholder: this.placeholder })
      .type(this.nativeType)
      .width('100%')
      .height(36)
      .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
      .padding({ left: 12, right: 12, top: 0, bottom: 0 })
      .fontSize(this.theme.text.sm)
      .fontColor(this.theme.colors.foreground)
      .placeholderColor(this.theme.colors.mutedForeground)
      .placeholderFont({ size: this.theme.text.sm })
      .caretColor(this.theme.colors.foreground)
      .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
      .backgroundColor(this.colors.background)
      // radius must live inside border(): a later border() without radius resets it to 0
      .border({ width: 1, color: this.colors.borderColor, radius: this.theme.radiusMd })
      .outline({
        width: this.colors.ringWidth,
        color: this.colors.ringColor,
        radius: this.theme.radiusMd + 3,
        style: OutlineStyle.SOLID
      })
      .maxLength(this.maxLength ?? Infinity)
      .hoverEffect(HoverEffect.None)
      .enabled(!this.disabled)
      .focusable(!this.disabled)
      .opacity(this.disabled ? 0.5 : 1)
      .focusBox(sparkNoFocusBox())
      .accessibilityText(this.label ?? '')
      .animation(SparkAnim.attr(this.theme, 'input', 'fast'))
      .onChange((v: string) => this.set(v))
      .onSubmit(() => this.onSubmit(this.current))
      .onFocus(() => {
        this.focused = true;
      })
      .onBlur(() => {
        this.focused = false;
      })
      .attributeModifier(this.modifier)
  }
}
