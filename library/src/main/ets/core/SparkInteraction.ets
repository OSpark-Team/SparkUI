import { SparkTheme } from '../theme/tokens/SparkTheme';
import { SparkUI } from './SparkUI';

/**
 * Hover state for SparkUI components (pointer devices).
 *
 * Interaction-state visuals — pressed AND hover — switch instantly, never animated. A hover fade made the
 * previous control's background linger while the next one lit up (Menubar switching menus as the pointer moves
 * across the triggers looked like two highlighted triggers — the same artefact as an animated pressed state).
 * Only appearance / layout transitions (open, expand, slide) animate.
 *
 * Pressed visuals come from the system pressed state — `stateStyles({ pressed })` or
 * `AttributeModifier.applyPressedAttribute` — never from onTouch state.
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
    const next = isHover && this.enabled;
    if (this.hovered !== next) {
      this.hovered = next;
    }
  }

  reset(): void {
    this.hovered = false;
  }
}
