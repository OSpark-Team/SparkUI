import { sparkText } from '../../core/SparkText';
import { SparkAnim } from '../../core/SparkAnim';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkPressModifier } from '../../core/SparkPress';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../../theme/tokens/SparkTokenReader';

/** Size of a choice control (Switch / Checkbox / Radio): sm · default · lg. */
export type ChoiceSize = 'sm' | 'default' | 'lg';

/** Switch geometry per size: [track width, track height, thumb] in vp. */
export function sparkSwitchMetrics(sizing: ChoiceSize): number[] {
  switch (sizing) {
    case 'sm':
      return [26, 14.4, 12];
    case 'lg':
      return [40, 24, 22];
    default:
      return [32, 18.4, 16];
  }
}

/** Surface of a "choice card" (label + description in a bordered, pressable box), selected or not. */
export class ChoiceCardStyle {
  background: string = '#00000000';
  borderColor: string = '#00000000';
}

/**
 * Per-instance token overrides of a switch (ADR D13): `SSwitch({ tokens: { checkedBackground: '#16a34a' } })`.
 * Instance → theme `--switch-*` → recipe.
 */
export interface SwitchTokens {
  background?: string;
  checkedBackground?: string;
  thumb?: string;
  checkedThumb?: string;
}

export function sparkChoiceCard(t: SparkTheme, selected: boolean, invalid: boolean): ChoiceCardStyle {
  const s = new ChoiceCardStyle();
  if (invalid) {
    s.borderColor = t.colors.destructive;
  } else {
    s.borderColor = selected ? t.colors.primary : t.colors.border;
  }
  s.background = selected ? SparkColor.alpha(t.colors.primary, t.isDark ? 0.1 : 0.05) : '#00000000';
  return s;
}

/**
 * shadcn-vue `Switch`: `h-[1.15rem] w-8 rounded-full border border-transparent shadow-xs`,
 * unchecked `bg-input dark:bg-input/80`, checked `bg-primary`; the `size-4` thumb slides `translate-x-[calc(100%-2px)]`.
 *
 * Variants: `sizing` sm | default | lg, `description` (muted text under the label) and `card` (label and
 * description in a bordered, pressable card with the switch on the right; highlighted while on).
 *
 * ```
 * SSwitch({ checked: this.airplane!!, label: 'Airplane Mode' })
 * SSwitch({ defaultChecked: true, onCheckedChange: (v: boolean) => ... })
 * SSwitch({ label: 'Marketing emails', description: 'Receive emails about new products.', card: true })
 * ```
 * React to changes with `onCheckedChange` / `!!` (the control's own tap consumes `.onClick()` on SSwitch).
 */
@ComponentV2
export struct SSwitch {
  /** Controlled state (use with `!!`). Leave undefined for uncontrolled. */
  @Param checked: boolean | undefined = undefined;
  @Event $checked: (v: boolean) => void = () => {
  };
  @Param defaultChecked: boolean = false;
  @Param disabled: boolean = false;
  /** Text shown to the right; also tappable. */
  @Param label: ResourceStr | undefined = undefined;
  /** Muted helper text under the label. */
  @Param description: ResourceStr | undefined = undefined;
  @Param sizing: ChoiceSize = 'default';
  /** Bordered choice card: texts on the left, switch on the right. */
  @Param card: boolean = false;
  @Event onCheckedChange: (v: boolean) => void = () => {
  };
  /** Per-instance token overrides (instance → theme `--switch-*` → recipe), see {@link SwitchTokens}. */
  @Param tokens: SwitchTokens = {};
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

  private toggle(): void {
    if (this.disabled) {
      return;
    }
    const v = !this.current;
    if (this.checked === undefined) {
      this.current = v;
    }
    this.$checked(v);
    this.onCheckedChange(v);
  }

  @Computed
  get press(): SparkPressModifier {
    return new SparkPressModifier(this.disabled, 0.85);
  }

  @Computed
  get metrics(): number[] {
    return sparkSwitchMetrics(this.sizing);
  }

  @Computed
  get trackColor(): string {
    const c = this.theme.colors;
    const r = new SparkTokenReader(this.theme, 'switch');
    if (this.current) {
      return r.color('checked-background', this.tokens.checkedBackground, c.primary);
    }
    return r.color('background', this.tokens.background, this.theme.isDark ? SparkColor.alpha(c.input, 0.8) : c.input);
  }

  @Computed
  get thumbColor(): string {
    const c = this.theme.colors;
    const r = new SparkTokenReader(this.theme, 'switch');
    const dark = this.theme.isDark;
    if (this.current) {
      return r.color('checked-thumb', this.tokens.checkedThumb, dark ? c.primaryForeground : c.background);
    }
    return r.color('thumb', this.tokens.thumb, dark ? c.foreground : c.background);
  }

  @Computed
  get trackShadow(): ShadowOptions {
    return SparkTokenOverride.shadowOptions(this.theme.comp.shadow('switch', 'shadow', this.theme.shadows.xs));
  }

  @Computed
  get cardStyle(): ChoiceCardStyle {
    return sparkChoiceCard(this.theme, this.current, false);
  }

  @Computed
  get accessibleName(): string {
    return typeof this.label === 'string' ? this.label : '';
  }

  @Computed
  get labelSize(): number {
    return this.sizing === 'lg' ? this.theme.text.base : this.theme.text.sm;
  }

  build() {
    Row({ space: this.card ? 16 : (this.sizing === 'lg' ? 12 : 8) }) {
      if (!this.card) {
        this.control()
      }
      if (this.label !== undefined || this.description !== undefined) {
        Column({ space: 4 }) {
          if (this.label !== undefined) {
            Text(this.label)
              .fontSize(this.labelSize)
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
      if (this.card) {
        this.control()
      }
    }
    .width(this.card ? '100%' : 'auto')
    .alignItems(this.description !== undefined && !this.card ? VerticalAlign.Top : VerticalAlign.Center)
    .padding(this.card ? 16 : 0)
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
    .accessibilityChecked(this.current)
    .accessibilityDescription(this.disabled ? sparkText(this.getUIContext(), $r('app.string.spark_state_disabled'), 'disabled') : '')
    .onClick(() => this.toggle())
  }

  @Builder
  control() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(this.metrics[2])
        .height(this.metrics[2])
        .backgroundColor(this.thumbColor)
        .border({ width: 0, radius: this.metrics[2] / 2 })
        .translate({ x: this.current ? this.metrics[0] - 2 - this.metrics[2] : 0 })
        .animation(SparkAnim.attr(this.theme, 'switch', 'normal'))
    }
    .width(this.metrics[0])
    .height(this.metrics[1])
    // border-transparent (1px) insets the thumb
    .padding(1)
    .flexShrink(0)
    .margin({ top: this.description !== undefined && !this.card ? 1 : 0 })
    .backgroundColor(this.trackColor)
    .border({ width: 0, radius: this.metrics[1] / 2 })
    .shadow(this.trackShadow)
    .animation(SparkAnim.attr(this.theme, 'switch', 'normal'))
  }
}
