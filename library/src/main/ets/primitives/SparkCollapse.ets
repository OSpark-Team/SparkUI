import { SparkAnim } from '../core/SparkAnim';
import { sparkEmptyBuilder } from '../core/Builders';
import { SparkUI } from '../core/SparkUI';
import { SparkTheme } from '../theme/tokens/SparkTheme';

/**
 * Height-animated disclosure region (Accordion / Collapsible content).
 *
 * The slot is laid out inside a non-interactive vertical Scroll, which measures its child with an unbounded
 * height. The natural height is therefore known even while collapsed, and the viewport height animates
 * between 0 and that height (clipped), together with opacity. Before the first measurement the state is
 * applied without animation, so an initially open region does not animate on appear.
 */
@ComponentV2
export struct SparkCollapse {
  @Param open: boolean = false;
  /** Animate height (true) or just snap (false). */
  @Param animated: boolean = true;
  /** motion key (`--motion-<key>-*`), e.g. 'accordion' / 'collapsible' */
  @Param motionKey: string = 'collapsible';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local expanded: boolean = false;
  @Local contentHeight: number = 0;
  @Local measured: boolean = false;

  aboutToAppear(): void {
    this.expanded = this.open;
  }

  @Monitor('open')
  syncOpen(): void {
    if (!this.measured || !this.animated) {
      this.expanded = this.open;
      return;
    }
    SparkAnim.run(this.getUIContext(), this.theme, this.motionKey, 'normal', () => {
      this.expanded = this.open;
    });
  }

  build() {
    Scroll() {
      Column() {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_: Area, n: Area) => {
        this.contentHeight = Number(n.height);
        this.measured = true;
      })
    }
    .width('100%')
    .height(this.expanded ? this.contentHeight : 0)
    .opacity(this.expanded ? 1 : 0)
    .scrollable(ScrollDirection.Vertical)
    .enableScrollInteraction(false)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .align(Alignment.Top)
    .clip(true)
    // collapsed content must not take focus / accessibility
    .focusable(this.expanded)
    .accessibilityLevel(this.expanded ? 'auto' : 'no-hide-descendants')
  }
}
