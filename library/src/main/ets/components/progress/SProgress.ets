import { SparkAnim } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue `Progress`: `h-2 w-full rounded-full bg-primary/20` track with a `bg-primary` indicator whose
 * width animates to `value / max`.
 *
 * ```
 * SProgress({ value: 66 })
 * SProgress({ value: this.done, max: this.total })
 * ```
 */
@ComponentV2
export struct SProgress {
  /** 0…max */
  @Param value: number = 0;
  @Param max: number = 100;
  /** Accessible name. */
  @Param label: string | undefined = undefined;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get percent(): number {
    if (this.max <= 0) {
      return 0;
    }
    return Math.min(100, Math.max(0, this.value / this.max * 100));
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(`${this.percent}%`)
        .height('100%')
        .backgroundColor(this.theme.colors.primary)
        .animation(SparkAnim.attr(this.theme, 'progress', 'slow'))
    }
    .width('100%')
    .height(8)
    .backgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.2))
    .border({ width: 0, radius: 4 })
    .clip(true)
    .accessibilityText(this.label ?? '')
    .accessibilityDescription(`${Math.round(this.percent)}%`)
  }
}
