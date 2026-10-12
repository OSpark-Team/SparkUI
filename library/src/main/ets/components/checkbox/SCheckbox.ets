import { SparkAnim } from '../../core/SparkAnim';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkPressModifier } from '../../core/SparkPress';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../../theme/tokens/SparkTokenReader';
import { ChoiceCardStyle, ChoiceSize, sparkChoiceCard } from '../switch/SSwitch';

/** Checkbox box / mark size per `sizing`: [box, icon] in vp. */
export function sparkCheckboxMetrics(sizing: ChoiceSize): number[] {
  return sizing === 'sm' ? [14, 12] : (sizing === 'lg' ? [20, 16] : [16, 14]);
}

/**
 * Per-instance token overrides of a checkbox (ADR D13): `SCheckbox({ tokens: { radius: 999 } })`.
 * Instance → theme `--checkbox-*` → recipe.
 */
export interface CheckboxTokens {
  background?: string;
  borderColor?: string;
  checkedBackground?: string;
  checkedBorderColor?: string;
  checkedForeground?: string;
  radius?: number;
  borderWidth?: number;
}

/**
 * shadcn-vue `Checkbox`: `size-4 rounded-[4px] border border-input shadow-xs`, checked
 * `bg-primary border-primary text-primary-foreground` with a `check` icon (`size-3.5`).
 *
 * ```
 * SCheckbox({ checked: this.agree!!, label: 'Accept terms and conditions' })
 * SCheckbox({ defaultChecked: true, onCheckedChange: (v: boolean) => ... })
 * SCheckbox({ indeterminate: this.some && !this.all, checked: this.all!! })   // "select all"
 * SCheckbox({ label: 'Enable notifications', description: 'You can change this later.', card: true })
 * ```
 *
 * Variants: `sizing` sm | default | lg, `description` (muted text under the label) and `card` (a bordered,
 * pressable choice card, highlighted while checked).
 *
 * `indeterminate` shows a `minus` mark (shadcn-vue's `'indeterminate'` model value); tapping it emits `true`,
 * the parent is expected to clear `indeterminate`. The optional `label` is part of the tap target.
 * React to changes with `onCheckedChange` / `!!` (the control's own tap consumes `.onClick()` on SCheckbox).
 */
@ComponentV2
export struct SCheckbox {
  /** Controlled state (use with `!!`). Leave undefined for uncontrolled. */
  @Param checked: boolean | undefined = undefined;
  @Event $checked: (v: boolean) => void = () => {
  };
  @Param defaultChecked: boolean = false;
  @Param indeterminate: boolean = false;
  @Param disabled: boolean = false;
  /** Error look (`aria-invalid`: destructive border). */
  @Param invalid: boolean = false;
  /** Text shown to the right; also tappable. */
  @Param label: ResourceStr | undefined = undefined;
  /** Muted helper text under the label. */
  @Param description: ResourceStr | undefined = undefined;
  @Param sizing: ChoiceSize = 'default';
  /** Bordered choice card around box, label and description. */
  @Param card: boolean = false;
  @Event onCheckedChange: (v: boolean) => void = () => {
  };
  /** Per-instance token overrides (instance → theme `--checkbox-*` → recipe), see {@link CheckboxTokens}. */
  @Param tokens: CheckboxTokens = {};
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: boolean = false;

  aboutToAppear(): void {
    this.current = this.checked ?? this.defaultChecked;
  }

  @Monitor('checked')
  syncChecked(): void {
    if (this.checked !== undefined) {
      this.current = this.checked;
    }
  }

  private set(v: boolean): void {
    if (this.checked === undefined) {
      this.current = v;
    }
    this.$checked(v);
    this.onCheckedChange(v);
  }

  private toggle(): void {
    if (this.disabled) {
      return;
    }
    this.set(this.indeterminate ? true : !this.current);
  }

  @Computed
  get on(): boolean {
    return this.current || this.indeterminate;
  }

  @Computed
  get press(): SparkPressModifier {
    return new SparkPressModifier(this.disabled);
  }

  private get tok(): SparkTokenReader {
    return new SparkTokenReader(this.theme, 'checkbox');
  }

  @Computed
  get boxBackground(): string {
    if (this.on) {
      return this.tok.color('checked-background', this.tokens.checkedBackground, this.theme.colors.primary);
    }
    return this.tok.color('background', this.tokens.background,
      this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.3) : '#00000000');
  }

  @Computed
  get boxBorder(): string {
    if (this.invalid) {
      return this.theme.colors.destructive;
    }
    return this.on ? this.tok.color('checked-border-color', this.tokens.checkedBorderColor, this.boxBackground) :
      this.tok.color('border-color', this.tokens.borderColor, this.theme.colors.input);
  }

  @Computed
  get checkColor(): string {
    return this.tok.color('checked-foreground', this.tokens.checkedForeground, this.theme.colors.primaryForeground);
  }

  /** shadcn uses a literal rounded-[4px] here (not a radius token); `--checkbox-radius` overrides it */
  @Computed
  get boxRadius(): number {
    return this.tok.len('radius', this.tokens.radius, this.sizing === 'lg' ? 5 : 4);
  }

  @Computed
  get boxBorderWidth(): number {
    return this.tok.len('border-width', this.tokens.borderWidth, this.theme.borderWidth);
  }

  @Computed
  get metrics(): number[] {
    return sparkCheckboxMetrics(this.sizing);
  }

  @Computed
  get cardStyle(): ChoiceCardStyle {
    return sparkChoiceCard(this.theme, this.on, this.invalid);
  }

  @Computed
  get accessibleName(): string {
    return typeof this.label === 'string' ? this.label : '';
  }

  build() {
    Row({ space: 12 }) {
      Row() {
        if (this.indeterminate) {
          SIcon({ name: 'minus', sizing: this.metrics[1], color: this.checkColor, strokeWidth: 2.5 })
            .transition(SparkAnim.enter(this.theme, 'checkbox', 'fast', 0.5))
        } else if (this.current) {
          SIcon({ name: 'check', sizing: this.metrics[1], color: this.checkColor, strokeWidth: 2.5 })
            .transition(SparkAnim.enter(this.theme, 'checkbox', 'fast', 0.5))
        }
      }
      .width(this.metrics[0])
      .height(this.metrics[0])
      .flexShrink(0)
      .margin({ top: this.description !== undefined ? 2 : 0 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.boxBackground)
      .border({ width: this.boxBorderWidth, color: this.boxBorder, radius: this.boxRadius })
      // the box is not the pressed-style node (that is the outer Row), so it may animate its fill
      .animation(SparkAnim.attr(this.theme, 'checkbox', 'fast'))

      if (this.label !== undefined || this.description !== undefined) {
        Column({ space: 4 }) {
          if (this.label !== undefined) {
            Text(this.label)
              .fontSize(this.sizing === 'lg' ? this.theme.text.base : this.theme.text.sm)
              .fontWeight(this.theme.text.weightMedium)
              .lineHeight(this.theme.text.leadingSm)
              .fontColor(this.theme.colors.foreground)
          }
          if (this.description !== undefined) {
            Text(this.description)
              .fontSize(this.theme.text.sm)
              .lineHeight(this.theme.text.leadingSm)
              .fontColor(this.theme.colors.mutedForeground)
          }
        }
        .layoutWeight(this.card ? 1 : 0)
        .flexShrink(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width(this.card ? '100%' : 'auto')
    .alignItems(this.description !== undefined ? VerticalAlign.Top : VerticalAlign.Center)
    .padding(this.card ? 12 : 0)
    .backgroundColor(this.card ? this.cardStyle.background : '#00000000')
    .border({
      width: this.card ? this.theme.borderWidth : 0,
      color: this.cardStyle.borderColor,
      radius: this.card ? this.theme.radiusLg : 0
    })
    .attributeModifier(this.press)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityGroup(true)
    .accessibilityText(this.accessibleName)
    .accessibilityChecked(this.indeterminate ? undefined : this.current)
    .accessibilityDescription(this.indeterminate ? 'mixed' : (this.disabled ? 'disabled' : ''))
    .onClick(() => this.toggle())
  }
}
