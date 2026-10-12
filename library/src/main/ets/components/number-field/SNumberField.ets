import { KeyCode } from '@kit.InputKit';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { resolveSparkField, SparkFieldState, sparkFieldGrows } from '../field/SField';
import { InputColors, sparkInputColors, sparkNoFocusBox } from '../input/SInput';
import { sparkNumberClamp, sparkNumberFormat, sparkNumberParse, sparkNumberStep } from './NumberFieldLogic';

/** Delay before a held − / + starts repeating, and the repeat interval (ms). */
const REPEAT_DELAY: number = 400;
const REPEAT_INTERVAL: number = 60;

/**
 * shadcn-vue `NumberField` (NumberFieldContent + Decrement + Input + Increment in one component): an input
 * with centred text and − / + buttons inside it.
 *
 * ```
 * SNumberField({ value: this.qty!!, min: 0, max: 99 })
 * SNumberField({ defaultValue: 1.5, step: 0.25, decimals: 2, onValueChange: (v: number) => ... })
 * ```
 *
 * - Holding − / + repeats; the value is clamped to `[min, max]` and rounded to the step's precision.
 * - Typing is free; the text is parsed and clamped on Enter or blur (invalid text reverts).
 * - Keyboard: arrow up / down step while the input is focused.
 * - `decimals` formats the shown value with a fixed number of decimals (formatOptions-lite).
 */
@ComponentV2
export struct SNumberField {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: number | undefined = undefined;
  @Event $value: (v: number) => void = () => {
  };
  @Param defaultValue: number = 0;
  @Param min: number | undefined = undefined;
  @Param max: number | undefined = undefined;
  @Param step: number = 1;
  /** Fixed number of decimals shown (undefined = as needed). */
  @Param decimals: number | undefined = undefined;
  @Param disabled: boolean = false;
  @Param invalid: boolean = false;
  /** Accessible name when there is no visible label. */
  @Param label: string | undefined = undefined;
  @Event onValueChange: (v: number) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: number = 0;
  @Local text: string = '';
  @Local focused: boolean = false;
  @Local field: SparkFieldState | undefined = undefined;
  private repeatTimer: number = -1;

  aboutToAppear(): void {
    this.current = sparkNumberClamp(this.value ?? this.defaultValue, this.min, this.max);
    this.text = sparkNumberFormat(this.current, this.decimals);
  }

  aboutToDisappear(): void {
    this.stopRepeat();
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
      this.text = sparkNumberFormat(this.value, this.decimals);
    }
  }

  @Monitor('min', 'max', 'decimals')
  syncBounds(): void {
    this.commit(sparkNumberClamp(this.current, this.min, this.max));
  }

  private commit(v: number): void {
    const next = sparkNumberClamp(v, this.min, this.max);
    this.text = sparkNumberFormat(next, this.decimals);
    if (next === this.current) {
      return;
    }
    this.current = next;
    this.$value(next);
    this.onValueChange(next);
  }

  private nudge(direction: number): boolean {
    if (this.disabled) {
      return false;
    }
    const base = sparkNumberParse(this.text) ?? this.current;
    const next = sparkNumberStep(base, this.step, direction, this.min, this.max, this.decimals);
    const moved = next !== this.current;
    this.commit(next);
    return moved;
  }

  private commitText(): void {
    const parsed = sparkNumberParse(this.text);
    this.commit(parsed ?? this.current);
  }

  /** Press-and-hold on − / +: step on touch down, then repeat until release or a bound is hit. */
  private onStepTouch(e: TouchEvent, direction: number): void {
    if (e.type === TouchType.Down) {
      this.stopRepeat();
      if (!this.nudge(direction)) {
        return;
      }
      this.repeatTimer = setTimeout(() => this.repeat(direction), REPEAT_DELAY);
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.stopRepeat();
    }
  }

  private repeat(direction: number): void {
    if (!this.nudge(direction)) {
      this.repeatTimer = -1;
      return;
    }
    this.repeatTimer = setTimeout(() => this.repeat(direction), REPEAT_INTERVAL);
  }

  private stopRepeat(): void {
    if (this.repeatTimer >= 0) {
      clearTimeout(this.repeatTimer);
      this.repeatTimer = -1;
    }
  }

  @Computed
  get colors(): InputColors {
    const invalid = this.invalid || (this.field !== undefined && this.field.isInvalid);
    return sparkInputColors(this.theme, this.focused && !this.disabled, invalid);
  }

  @Computed
  get atMin(): boolean {
    return this.min !== undefined && this.current <= this.min;
  }

  @Computed
  get atMax(): boolean {
    return this.max !== undefined && this.current >= this.max;
  }

  @Computed
  get decPress(): SparkRowPressModifier {
    return new SparkRowPressModifier('#00000000', SparkColor.alpha(this.theme.colors.accent, 0.8), 1,
      this.disabled || this.atMin);
  }

  @Computed
  get incPress(): SparkRowPressModifier {
    return new SparkRowPressModifier('#00000000', SparkColor.alpha(this.theme.colors.accent, 0.8), 1,
      this.disabled || this.atMax);
  }

  @Builder
  stepButton(icon: string, direction: number, label: string, atBound: boolean, press: SparkRowPressModifier) {
    Row() {
      // at a bound: disabled:opacity-20 (row 0.5 from the press modifier × icon 0.4)
      SIcon({ name: icon, sizing: 16, color: this.theme.colors.foreground })
        .opacity(atBound && !this.disabled ? 0.4 : 1)
    }
    .width(36)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .attributeModifier(press)
    .border({ width: 0, radius: this.theme.radiusMd })
    .focusable(!atBound && !this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(label)
    .onTouch((e: TouchEvent) => this.onStepTouch(e, direction))
    .onKeyEvent((e: KeyEvent) => {
      if (e.type === KeyType.Up && (e.keyCode === KeyCode.KEYCODE_ENTER || e.keyCode === KeyCode.KEYCODE_SPACE)) {
        this.nudge(direction);
      }
    })
  }

  build() {
    Stack() {
      TextInput({ text: this.text })
        .type(InputType.NUMBER_DECIMAL)
        .width('100%')
        .height(36)
        .textAlign(TextAlign.Center)
        .padding({ left: 40, right: 40, top: 0, bottom: 0 })
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.foreground)
        .caretColor(this.theme.colors.foreground)
        .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
        .backgroundColor(this.colors.background)
        .border({ width: 1, color: this.colors.borderColor, radius: this.theme.radiusMd })
        .outline({
          width: this.colors.ringWidth,
          color: this.colors.ringColor,
          radius: this.theme.radiusMd + 3,
          style: OutlineStyle.SOLID
        })
        .hoverEffect(HoverEffect.None)
        .enabled(!this.disabled)
        .focusable(!this.disabled)
        .focusBox(sparkNoFocusBox())
        .accessibilityText(this.label ?? '')
        .animation(SparkAnim.attr(this.theme, 'input', 'fast'))
        .onChange((v: string) => {
          this.text = v;
        })
        .onSubmit(() => this.commitText())
        .onFocus(() => {
          this.focused = true;
        })
        .onBlur(() => {
          this.focused = false;
          this.commitText();
        })
        .onKeyEvent((e: KeyEvent) => {
          if (e.type !== KeyType.Down) {
            return;
          }
          if (e.keyCode === KeyCode.KEYCODE_DPAD_UP) {
            this.nudge(1);
          } else if (e.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
            this.nudge(-1);
          }
        })

      // absolute like shadcn's `absolute left-0` / `right-0`: they do not take part in the layout
      Row() {
        this.stepButton('minus', -1, 'Decrease', this.atMin, this.decPress)
      }
      .position({ left: 1, top: 1 })

      Row() {
        this.stepButton('plus', 1, 'Increase', this.atMax, this.incPress)
      }
      .position({ right: 1, top: 1 })
    }
    .width('100%')
    .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    .opacity(this.disabled ? 0.5 : 1)
  }
}
