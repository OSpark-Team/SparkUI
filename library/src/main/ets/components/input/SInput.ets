import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { sparkColorMetrics, SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
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

export type InputSize = 'sm' | 'default' | 'lg';

/** Height in vp of an input size: sm 32 · default 36 · lg 40 (`h-8` / `h-9` / `h-10`). */
export function sparkInputHeight(sizing: InputSize): number {
  return sizing === 'sm' ? 32 : (sizing === 'lg' ? 40 : 36);
}

/** Character counter text: `"12/80"`, or just the length without a limit. */
export function sparkInputCounter(length: number, maxLength: number | undefined): string {
  return maxLength !== undefined && maxLength !== Infinity ? `${length}/${maxLength}` : `${length}`;
}

/**
 * shadcn-vue `Input`: `h-9 w-full rounded-md border px-3 py-1 text-sm`, styled on the native TextInput.
 *
 * Variants: `sizing` sm | default | lg, leading `icon` / trailing `iconRight` (lucide names), `clearable` (an ×
 * that empties the field while it has text), `showCount` (`12/80` counter, uses `maxLength`) and the `invalid`
 * error state.
 *
 * ```
 * SInput({ placeholder: 'Email', inputType: 'email', value: this.email!! })
 * SInput({ defaultValue: 'hello', onValueChange: (v: string) => ... })
 * SInput({ inputType: 'password', invalid: this.error.length > 0, onSubmit: (v: string) => this.login() })
 * SInput({ placeholder: 'Search', icon: 'search', clearable: true, sizing: 'lg' })
 * SInput({ placeholder: 'Bio', maxLength: 80, showCount: true })
 * ```
 *
 * `inputType` instead of `type` (native enum clash). Inside an invalid SField the invalid look is applied
 * automatically; inside a horizontal SField it takes the remaining row width. `modifier` styles the inner
 * TextInput.
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
  @Param sizing: InputSize = 'default';
  /** Leading lucide icon (muted). */
  @Param icon: string | undefined = undefined;
  /** Trailing lucide icon (muted). */
  @Param iconRight: string | undefined = undefined;
  /** Trailing × that clears the text (shown while there is text). */
  @Param clearable: boolean = false;
  /** Trailing character counter (`length/maxLength`). */
  @Param showCount: boolean = false;
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
  /** measured width of the trailing adornments (clear, counter, icon) */
  @Local trailingWidth: number = 0;

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

  @Computed
  get boxHeight(): number {
    return sparkInputHeight(this.sizing);
  }

  @Computed
  get fontSize(): number {
    return this.sizing === 'lg' ? this.theme.text.base : this.theme.text.sm;
  }

  @Computed
  get showClear(): boolean {
    return this.clearable && !this.disabled && this.current.length > 0;
  }

  @Computed
  get hasTrailing(): boolean {
    return this.clearable || this.showCount || this.iconRight !== undefined;
  }

  @Computed
  get paddingLeft(): number {
    return this.icon !== undefined ? 12 + 16 + 8 : 12;
  }

  @Computed
  get paddingRight(): number {
    return this.hasTrailing ? 12 + this.trailingWidth + 8 : 12;
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      TextInput({ text: this.current, placeholder: this.placeholder })
        .type(this.nativeType)
        .width('100%')
        .height(this.boxHeight)
        .padding({ left: this.paddingLeft, right: this.paddingRight, top: 0, bottom: 0 })
        .fontSize(this.fontSize)
        .fontColor(this.theme.colors.foreground)
        .placeholderColor(this.theme.colors.mutedForeground)
        .placeholderFont({ size: this.fontSize })
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

      if (this.icon !== undefined || this.hasTrailing) {
        // adornments float over the field; touches outside their buttons fall through to the TextInput
        Row() {
          if (this.icon !== undefined) {
            SIcon({ name: this.icon, sizing: 16, color: this.theme.colors.mutedForeground })
          }
          Blank()
          Row({ space: 8 }) {
            if (this.showCount) {
              Text(sparkInputCounter(this.current.length, this.maxLength))
                .fontSize(this.theme.text.xs)
                .fontColor(this.theme.colors.mutedForeground)
                .fontFeature('"tnum" on')
            }
            if (this.showClear) {
              Row() {
                SIcon({ name: 'x', sizing: 14, color: this.theme.colors.mutedForeground })
              }
              .width(20)
              .height(20)
              .justifyContent(FlexAlign.Center)
              .border({ width: 0, radius: 10 })
              .responseRegion({ x: -6, y: -8, width: 32, height: 36 })
              .stateStyles({ normal: this.clearNormal, pressed: this.clearPressed })
              .accessibilityText('Clear')
              .onClick(() => this.set(''))
            }
            if (this.iconRight !== undefined) {
              SIcon({ name: this.iconRight, sizing: 16, color: this.theme.colors.mutedForeground })
            }
          }
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent)
          .onAreaChange((_: Area, n: Area) => {
            this.trailingWidth = Number(n.width);
          })
        }
        .width('100%')
        .height(this.boxHeight)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    .opacity(this.disabled ? 0.5 : 1)
  }

  @Styles
  clearNormal() {
    .backgroundColor('#00000000')
  }

  @Styles
  clearPressed() {
    .backgroundColor(this.theme.colors.accent)
  }
}
