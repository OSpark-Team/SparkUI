import { SparkAnim } from '../../core/SparkAnim';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkPressModifier } from '../../core/SparkPress';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const TRACK_W: number = 32;
const TRACK_H: number = 18.4;
const THUMB: number = 16;

/**
 * shadcn-vue `Switch`: `h-[1.15rem] w-8 rounded-full border border-transparent shadow-xs`,
 * unchecked `bg-input dark:bg-input/80`, checked `bg-primary`; the `size-4` thumb slides `translate-x-[calc(100%-2px)]`.
 *
 * ```
 * SSwitch({ checked: this.airplane!!, label: 'Airplane Mode' })
 * SSwitch({ defaultChecked: true, onCheckedChange: (v: boolean) => ... })
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
  @Event onCheckedChange: (v: boolean) => void = () => {
  };
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
  get trackColor(): string {
    const c = this.theme.colors;
    if (this.current) {
      return c.primary;
    }
    return this.theme.isDark ? SparkColor.alpha(c.input, 0.8) : c.input;
  }

  @Computed
  get thumbColor(): string {
    const c = this.theme.colors;
    if (!this.theme.isDark) {
      return c.background;
    }
    return this.current ? c.primaryForeground : c.foreground;
  }

  @Computed
  get accessibleName(): string {
    return typeof this.label === 'string' ? this.label : '';
  }

  build() {
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width(THUMB)
          .height(THUMB)
          .backgroundColor(this.thumbColor)
          .border({ width: 0, radius: THUMB / 2 })
          .translate({ x: this.current ? TRACK_W - 2 - THUMB : 0 })
          .animation(SparkAnim.attr(this.theme, 'switch', 'normal'))
      }
      .width(TRACK_W)
      .height(TRACK_H)
      // border-transparent (1px) insets the thumb
      .padding(1)
      .backgroundColor(this.trackColor)
      .border({ width: 0, radius: TRACK_H / 2 })
      .shadow(this.theme.shadows.xs.toOptions())
      .animation(SparkAnim.attr(this.theme, 'switch', 'normal'))

      if (this.label !== undefined) {
        Text(this.label)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .lineHeight(this.theme.text.leadingSm)
          .fontColor(this.theme.colors.foreground)
      }
    }
    .alignItems(VerticalAlign.Center)
    .attributeModifier(this.press)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityGroup(true)
    .accessibilityText(this.accessibleName)
    .accessibilityChecked(this.current)
    .accessibilityDescription(this.disabled ? 'disabled' : '')
    .onClick(() => this.toggle())
  }
}
