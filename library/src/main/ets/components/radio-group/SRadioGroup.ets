import { SparkAnim } from '../../core/SparkAnim';
import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkPressModifier } from '../../core/SparkPress';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { ChoiceCardStyle, ChoiceSize, sparkChoiceCard } from '../switch/SSwitch';

/** Radio circle / dot size per `sizing`: [circle, dot] in vp. */
export function sparkRadioMetrics(sizing: ChoiceSize): number[] {
  return sizing === 'sm' ? [14, 6] : (sizing === 'lg' ? [20, 10] : [16, 8]);
}

const KEY: string = 'spark.radioGroup';

export type RadioGroupOrientation = 'vertical' | 'horizontal';

/** Selection shared by an SRadioGroup and its items. */
@ObservedV2
export class SparkRadioGroupState {
  @Trace value: string = '';
  @Trace disabled: boolean = false;
  controlled: boolean = false;
  emit: (v: string) => void = () => {
  };

  select(v: string): void {
    if (this.disabled || v === this.value) {
      return;
    }
    if (!this.controlled) {
      this.value = v;
    }
    this.emit(v);
  }
}

/**
 * shadcn-vue `RadioGroup` (`grid gap-3`).
 *
 * ```
 * SRadioGroup({ value: this.plan!! }) {
 *   SRadioGroupItem({ value: 'default', label: 'Default' })
 *   SRadioGroupItem({ value: 'comfortable', label: 'Comfortable' })
 *   SRadioGroupItem({ value: 'compact', label: 'Compact' })
 * }
 * SRadioGroup({ defaultValue: 'a', orientation: 'horizontal', onValueChange: (v: string) => ... }) { ... }
 * ```
 */
@ComponentV2
export struct SRadioGroup {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Param orientation: RadioGroupOrientation = 'vertical';
  @Param disabled: boolean = false;
  @Event onValueChange: (v: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkRadioGroupState = new SparkRadioGroupState();

  aboutToAppear(): void {
    this.state.controlled = this.value !== undefined;
    this.state.value = this.value ?? this.defaultValue;
    this.state.disabled = this.disabled;
    this.state.emit = (v: string) => {
      this.$value(v);
      this.onValueChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.controlled = true;
      this.state.value = this.value;
    }
  }

  @Monitor('disabled')
  syncDisabled(): void {
    this.state.disabled = this.disabled;
  }

  build() {
    Flex({
      direction: this.orientation === 'horizontal' ? FlexDirection.Row : FlexDirection.Column,
      wrap: this.orientation === 'horizontal' ? FlexWrap.Wrap : FlexWrap.NoWrap,
      alignItems: this.orientation === 'horizontal' ? ItemAlign.Center : ItemAlign.Start,
      space: { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(12) }
    }) {
      this.content()
    }
  }
}

/**
 * shadcn-vue `RadioGroupItem`: `size-4 rounded-full border border-input shadow-xs dark:bg-input/30`, the selected
 * item shows a `size-2` primary dot. The optional `label` is part of the tap target (`flex items-center gap-3`).
 *
 * Variants: `sizing` sm | default | lg, `description` (muted text under the label) and `card` (a bordered,
 * pressable choice card, highlighted while selected — e.g. plan pickers).
 *
 * ```
 * SRadioGroupItem({ value: 'pro', label: 'Pro', description: '$20 / month', card: true })
 * ```
 */
@ComponentV2
export struct SRadioGroupItem {
  @Param value: string = '';
  @Param label: ResourceStr | undefined = undefined;
  @Param disabled: boolean = false;
  @Param invalid: boolean = false;
  /** Muted helper text under the label. */
  @Param description: ResourceStr | undefined = undefined;
  @Param sizing: ChoiceSize = 'default';
  /** Bordered choice card around the radio, label and description. */
  @Param card: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkRadioGroupState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkRadioGroupState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  @Computed
  get selected(): boolean {
    return this.ctx !== undefined && this.ctx.value === this.value;
  }

  @Computed
  get isDisabled(): boolean {
    return this.disabled || (this.ctx !== undefined && this.ctx.disabled);
  }

  @Computed
  get press(): SparkPressModifier {
    return new SparkPressModifier(this.isDisabled);
  }

  @Computed
  get accessibleName(): string {
    return typeof this.label === 'string' ? this.label : this.value;
  }

  @Computed
  get metrics(): number[] {
    return sparkRadioMetrics(this.sizing);
  }

  @Computed
  get cardStyle(): ChoiceCardStyle {
    return sparkChoiceCard(this.theme, this.selected, this.invalid);
  }

  build() {
    Row({ space: 12 }) {
      Stack() {
        Row()
          .width(this.metrics[1])
          .height(this.metrics[1])
          .backgroundColor(this.theme.colors.primary)
          .border({ width: 0, radius: this.metrics[1] / 2 })
          .scale({ x: this.selected ? 1 : 0, y: this.selected ? 1 : 0 })
          .opacity(this.selected ? 1 : 0)
          .animation(SparkAnim.attr(this.theme, 'radio', 'fast'))
      }
      .width(this.metrics[0])
      .height(this.metrics[0])
      .flexShrink(0)
      .margin({ top: this.description !== undefined ? 2 : 0 })
      .backgroundColor(this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.3) : '#00000000')
      .border({
        width: 1,
        color: this.invalid ? this.theme.colors.destructive :
          (this.card && this.selected ? this.theme.colors.primary : this.theme.colors.input),
        radius: this.metrics[0] / 2
      })

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
      width: this.card ? 1 : 0,
      color: this.cardStyle.borderColor,
      radius: this.card ? this.theme.radiusLg : 0
    })
    .attributeModifier(this.press)
    .focusable(!this.isDisabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityGroup(true)
    .accessibilityText(this.accessibleName)
    .accessibilitySelected(this.selected)
    .accessibilityDescription(this.isDisabled ? 'disabled' : '')
    .onClick(() => {
      if (!this.isDisabled) {
        this.ctx?.select(this.value);
      }
    })
  }
}
