import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type SeparatorOrientation = 'horizontal' | 'vertical';

/**
 * shadcn-vue `Separator`: `bg-border shrink-0`, 1px tall (horizontal, full width) or 1px wide (vertical,
 * full height of the parent — give the parent a height, like shadcn's `h-5`).
 *
 * ```
 * SSeparator()
 * Row({ space: 16 }) { Text('Blog'); SSeparator({ orientation: 'vertical' }); Text('Docs') }.height(20)
 * ```
 */
@ComponentV2
export struct SSeparator {
  @Param orientation: SeparatorOrientation = 'horizontal';
  /** Purely visual (hidden from accessibility). Set false when it separates meaningful groups. */
  @Param decorative: boolean = true;
  /** Optional explicit length; defaults to 100% of the parent along the orientation. */
  @Param length: Length = '100%';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column()
      .width(this.orientation === 'vertical' ? 1 : this.length)
      .height(this.orientation === 'vertical' ? this.length : 1)
      .flexShrink(0)
      .backgroundColor(this.theme.colors.border)
      .accessibilityLevel(this.decorative ? 'no' : 'auto')
      .accessibilityText(this.decorative ? '' : 'separator')
  }
}
