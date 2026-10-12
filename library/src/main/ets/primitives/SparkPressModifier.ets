/**
 * Background / opacity feedback for pressable Rows (tab triggers, accordion triggers, breadcrumb links,
 * toggles), driven by the system pressed state (`applyPressedAttribute`), never by onTouch state.
 * Only background and opacity are set here, so borders, padding etc. can stay inline on the Row.
 */
export class SparkRowPressModifier implements AttributeModifier<RowAttribute> {
  background: string;
  pressedBackground: string;
  pressedOpacity: number;
  disabled: boolean;

  constructor(background: string, pressedBackground: string, pressedOpacity: number, disabled: boolean) {
    this.background = background;
    this.pressedBackground = pressedBackground;
    this.pressedOpacity = pressedOpacity;
    this.disabled = disabled;
  }

  applyNormalAttribute(instance: RowAttribute): void {
    instance
      .backgroundColor(this.background)
      .opacity(this.disabled ? 0.5 : 1)
  }

  applyPressedAttribute(instance: RowAttribute): void {
    if (this.disabled) {
      return;
    }
    instance
      .backgroundColor(this.pressedBackground)
      .opacity(this.pressedOpacity)
  }
}
