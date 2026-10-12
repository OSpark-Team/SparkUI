import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { sparkColorMetrics, SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../../theme/tokens/SparkTokenReader';
import { LengthMetrics } from '@kit.ArkUI';
import { resolveSparkField, SparkFieldState, sparkFieldGrows } from '../field/SField';

/** `type` of an SInput (named `inputType` because of the native `InputType` enum). */
export type InputKind = 'text' | 'password' | 'email' | 'number';

/**
 * Per-instance token overrides of a text field (SInput, STextarea; ADR D13), e.g. a filled, borderless field:
 * `SInput({ tokens: { background: 'oklch(0.97 0 0)', borderWidth: 0 } })`. Instance → theme `--input-*` → recipe.
 * Colours use the theme file syntax; lengths are vp.
 */
export interface InputTokens {
  background?: string;
  foreground?: string;
  placeholderColor?: string;
  borderColor?: string;
  focusBorderColor?: string;
  invalidBorderColor?: string;
  ringColor?: string;
  borderWidth?: number;
  radius?: number;
  ringWidth?: number;
  height?: number;
  paddingX?: number;
}

const NO_INPUT_TOKENS: InputTokens = {};

/** Resolved style shared by SInput, STextarea and the other text-field-like controls (shadcn input recipe). */
export class InputColors {
  background: string = '#00000000';
  borderColor: string = '#00000000';
  /** focus ring (`ring-[3px]`) colour; width is 0 unless focused */
  ringColor: string = '#00000000';
  ringWidth: number = 0;
  foreground: string = '#FF000000';
  placeholder: string = '#FF000000';
  borderWidth: number = 1;
  radius: number = 8;
  paddingX: number = 12;
}

/**
 * shadcn input recipe: `border-input bg-transparent dark:bg-input/30`, focus `border-ring ring-ring/50 ring-[3px]`,
 * invalid `border-destructive ring-destructive/20 dark:ring-destructive/40`; then the `--input-*` theme tokens and
 * the instance `tokens`.
 */
export function sparkInputColors(t: SparkTheme, focused: boolean, invalid: boolean, tokens?: InputTokens): InputColors {
  const c = t.colors;
  const k = tokens ?? NO_INPUT_TOKENS;
  const tok = new SparkTokenReader(t, 'input');
  const r = new InputColors();
  r.background = tok.color('background', k.background, t.isDark ? SparkColor.alpha(c.input, 0.3) : '#00000000');
  if (invalid) {
    r.borderColor = tok.color('invalid-border-color', k.invalidBorderColor, c.destructive);
    r.ringColor = tok.color('invalid-ring-color', undefined, SparkColor.alpha(c.destructive, t.isDark ? 0.4 : 0.2));
  } else {
    r.borderColor = focused ? tok.color('focus-border-color', k.focusBorderColor, c.ring) :
      tok.color('border-color', k.borderColor, c.input);
    r.ringColor = tok.color('ring-color', k.ringColor, SparkColor.alpha(c.ring, 0.5));
  }
  r.ringWidth = focused ? tok.len('ring-width', k.ringWidth, 3) : 0;
  r.foreground = tok.color('foreground', k.foreground, c.foreground);
  r.placeholder = tok.color('placeholder-color', k.placeholderColor, c.mutedForeground);
  r.borderWidth = tok.len('border-width', k.borderWidth, t.borderWidth);
  r.radius = tok.len('radius', k.radius, t.radiusMd);
  r.paddingX = tok.len('padding-x', k.paddingX, 12);
  return r;
}

/** Field height with `--input-height[-sm|-lg]` / `tokens.height` applied. */
export function sparkInputHeightOf(t: SparkTheme, sizing: InputSize, tokens?: InputTokens): number {
  const key = sizing === 'sm' ? 'height-sm' : (sizing === 'lg' ? 'height-lg' : 'height');
  return new SparkTokenReader(t, 'input').len(key, tokens?.height, sparkInputHeight(sizing));
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
  /** Per-instance token overrides (instance → theme `--input-*` → recipe), see {@link InputTokens}. */
  @Param tokens: InputTokens = {};
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
    return sparkInputColors(this.theme, this.focused && !this.disabled, invalid, this.tokens);
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
    return sparkInputHeightOf(this.theme, this.sizing, this.tokens);
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
    const px = this.colors.paddingX;
    return this.icon !== undefined ? px + 16 + 8 : px;
  }

  @Computed
  get paddingRight(): number {
    const px = this.colors.paddingX;
    return this.hasTrailing ? px + this.trailingWidth + 8 : px;
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      TextInput({ text: this.current, placeholder: this.placeholder })
        .type(this.nativeType)
        .width('100%')
        .height(this.boxHeight)
        .padding({ left: this.paddingLeft, right: this.paddingRight, top: 0, bottom: 0 })
        .fontSize(this.fontSize)
        .fontColor(this.colors.foreground)
        .placeholderColor(this.colors.placeholder)
        .placeholderFont({ size: this.fontSize })
        .caretColor(this.colors.foreground)
        .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
        .backgroundColor(this.colors.background)
        // radius must live inside border(): a later border() without radius resets it to 0
        .border({ width: this.colors.borderWidth, color: this.colors.borderColor, radius: this.colors.radius })
        .outline({
          width: this.colors.ringWidth,
          color: this.colors.ringColor,
          radius: this.colors.radius + this.colors.ringWidth,
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
        .padding({ left: this.colors.paddingX, right: this.colors.paddingX })
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
