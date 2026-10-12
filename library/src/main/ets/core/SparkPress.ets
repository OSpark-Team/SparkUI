/**
 * Opacity feedback for tappable rows (checkbox, switch, radio item…), driven by the system pressed state
 * (`applyPressedAttribute`, the modifier form of `stateStyles({ pressed })`) — never by onTouch state.
 * Also owns the disabled look (`opacity-50`), so the two never fight over `opacity`.
 *
 * ```
 * Row() {...}.attributeModifier(new SparkPressModifier(this.disabled))
 * ```
 */
export class SparkPressModifier implements AttributeModifier<RowAttribute> {
  disabled: boolean;
  pressedOpacity: number;

  constructor(disabled: boolean, pressedOpacity?: number) {
    this.disabled = disabled;
    this.pressedOpacity = pressedOpacity ?? 0.8;
  }

  applyNormalAttribute(instance: RowAttribute): void {
    instance.opacity(this.disabled ? 0.5 : 1);
  }

  applyPressedAttribute(instance: RowAttribute): void {
    if (this.disabled) {
      return;
    }
    instance.opacity(this.pressedOpacity);
  }
}
