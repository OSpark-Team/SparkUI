import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type ScrollAreaOrientation = 'vertical' | 'horizontal' | 'both';

/**
 * shadcn-vue `ScrollArea`: native scrolling with a thin, theme-coloured scrollbar (`bg-border`, 6vp).
 *
 * ```
 * SScrollArea({ maxScrollHeight: 288, bordered: true }) {
 *   Column() { ForEach(tags, (t: string) => Text(t)) }
 * }
 * SScrollArea({ orientation: 'horizontal' }) { Row({ space: 16 }) { ... } }
 * ```
 *
 * The area fills the width it gets; its height follows the content up to `maxScrollHeight` (or the parent's
 * constraint). Wrap it in a sized container for a fixed height.
 */
@ComponentV2
export struct SScrollArea {
  @Param orientation: ScrollAreaOrientation = 'vertical';
  /** Maximum height in vp before the content scrolls (vertical / both). */
  @Param maxScrollHeight: number | undefined = undefined;
  /** Draw `rounded-md border` around the area (common in the shadcn examples). */
  @Param bordered: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private scroller: Scroller = new Scroller();

  @Computed
  get scrollAxis(): ScrollDirection {
    if (this.orientation === 'horizontal') {
      return ScrollDirection.Horizontal;
    }
    return this.orientation === 'both' ? ScrollDirection.FREE : ScrollDirection.Vertical;
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        this.content()
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minWidth: this.orientation === 'vertical' ? '100%' : 0 })
    }
    .width('100%')
    .constraintSize({ maxHeight: this.maxScrollHeight !== undefined ? this.maxScrollHeight : Infinity })
    .scrollable(this.scrollAxis)
    .scrollBar(BarState.Auto)
    .scrollBarColor(this.theme.colors.border)
    .scrollBarWidth(6)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    .align(Alignment.TopStart)
    .border({
      width: this.bordered ? 1 : 0,
      color: this.theme.colors.border,
      radius: this.theme.radiusMd
    })
    .clip(true)
    .accessibilityRole(AccessibilityRoleType.SCROLL)
  }
}
