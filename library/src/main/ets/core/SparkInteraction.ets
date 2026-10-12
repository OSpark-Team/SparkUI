import { SparkTheme } from '../theme/tokens/SparkTheme';
import { SparkAnim } from './SparkAnim';
import { SparkUI } from './SparkUI';

/**
 * Hover state for SparkUI components (pointer devices). Hover changes are animated with the theme's fast
 * motion token.
 *
 * Pressed visuals must NOT be driven from onTouch state: when tapping several controls quickly the previous
 * control's release animation lingers and two controls look pressed at once. Use the system pressed state
 * instead — `stateStyles({ pressed })` or `AttributeModifier.applyPressedAttribute` (see SButton).
 *
 * ```
 * @Local ix: SparkInteraction = new SparkInteraction();
 * Row() {...}
 *   .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
 *   .stateStyles({ pressed: this.pressedStyle })
 * ```
 */
@ObservedV2
export class SparkInteraction {
  @Trace hovered: boolean = false;
  /** Set false to freeze feedback (disabled / loading). */
  enabled: boolean = true;

  hover(ctx: UIContext, theme: SparkTheme, isHover: boolean): void {
    SparkUI.layout.reportPointerEvent(true);
    if (this.hovered === isHover) {
      return;
    }
    SparkAnim.run(ctx, theme, 'hover', 'fast', () => {
      this.hovered = isHover && this.enabled;
    });
  }

  reset(): void {
    this.hovered = false;
  }
}
