import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { resolveSparkField, SparkFieldState, sparkFieldGrows } from '../field/SField';
import { InputColors, InputTokens, sparkInputColors, sparkInputCounter, sparkNoFocusBox } from '../input/SInput';

/**
 * shadcn-vue `Textarea`: `min-h-16 w-full rounded-md border px-3 py-2 text-sm field-sizing-content`
 * on the native TextArea — it grows with its content (cap it with `maxHeight`).
 *
 * ```
 * STextarea({ placeholder: 'Type your message here.', value: this.message!! })
 * STextarea({ defaultValue: 'Hi', maxHeight: 200, onValueChange: (v: string) => ... })
 * STextarea({ placeholder: 'Bio', maxLength: 160, showCount: true })
 * ```
 * `modifier` styles the inner TextArea.
 */
@ComponentV2
export struct STextarea {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Param placeholder: ResourceStr = '';
  @Param invalid: boolean = false;
  @Param disabled: boolean = false;
  @Param maxLength: number | undefined = undefined;
  /** Upper bound of the auto-growing height (vp); scrolls beyond it. */
  @Param maxHeight: number | undefined = undefined;
  /** Character counter at the bottom-right (`length/maxLength`). */
  @Param showCount: boolean = false;
  /** Accessible name when there is no visible label. */
  @Param label: string | undefined = undefined;
  @Param modifier: AttributeModifier<TextAreaAttribute> = new SparkNoopModifier<TextAreaAttribute>();
  /** Per-instance token overrides (shares the `--input-*` theme tokens), see {@link InputTokens}. */
  @Param tokens: InputTokens = {};
  @Event onValueChange: (v: string) => void = () => {
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
    return sparkInputColors(this.theme, this.focused && !this.disabled, invalid, this.tokens);
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      TextArea({ text: this.current, placeholder: this.placeholder })
        .width('100%')
        .constraintSize({ minHeight: 64, maxHeight: this.maxHeight ?? Infinity })
        .padding({ left: this.colors.paddingX, right: this.colors.paddingX, top: 8, bottom: this.showCount ? 24 : 8 })
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontColor(this.colors.foreground)
        .placeholderColor(this.colors.placeholder)
        .placeholderFont({ size: this.theme.text.sm })
        .caretColor(this.colors.foreground)
        .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
        .backgroundColor(this.colors.background)
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
        .onFocus(() => {
          this.focused = true;
        })
        .onBlur(() => {
          this.focused = false;
        })
        .attributeModifier(this.modifier)

      if (this.showCount) {
        Text(sparkInputCounter(this.current.length, this.maxLength))
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.mutedForeground)
          .fontFeature('"tnum" on')
          .margin({ right: this.colors.paddingX, bottom: 6 })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    .opacity(this.disabled ? 0.5 : 1)
  }
}
