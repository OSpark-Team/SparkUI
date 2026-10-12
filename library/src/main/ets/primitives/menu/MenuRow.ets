import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type MenuIndicator = 'none' | 'check-left' | 'check-right' | 'dot-left';
export type MenuItemVariant = 'default' | 'destructive';

/** KEYCODE_ENTER / KEYCODE_NUMPAD_ENTER (ArkUI binds only Space to the native onClick of a focused node). */
const KEY_ENTER: number = 2054;
const KEY_NUMPAD_ENTER: number = 2119;

/** Whether a key event is the release of Enter / numpad Enter. */
export function sparkIsEnterUp(e: KeyEvent): boolean {
  return e.type === KeyType.Up && (e.keyCode === KEY_ENTER || e.keyCode === KEY_NUMPAD_ENTER);
}

/**
 * One row of a menu-like surface (DropdownMenu, Select, ContextMenu, Menubar …):
 * `relative flex items-center gap-2 rounded-sm px-2 py-1.5 text-sm`, accent on hover / press.
 *
 * Pressed comes from the system pressed state (stateStyles). Activation is the row's own native `.onClick()`,
 * so a tap, a mouse click, Space on the focused row and the screen reader's activation all take one path
 * (Enter is added through `onKeyEvent`). A row's click wins over an ancestor's, so a `.onClick()` chained on a
 * menu item component never fires: items report activation through `onSelect` / `onCheckedChange` /
 * `onValueChange` instead.
 */
@ComponentV2
export struct MenuRow {
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  @Param shortcut: string | undefined = undefined;
  @Param variant: MenuItemVariant = 'default';
  @Param disabled: boolean = false;
  /** leave room for a left indicator even when not shown (aligns items in mixed menus) */
  @Param inset: boolean = false;
  @Param indicator: MenuIndicator = 'none';
  @Param selected: boolean = false;
  /** touch-friendly rows (bottom-sheet presentation) */
  @Param roomy: boolean = false;
  /** accessibility role of the row (Select options pass OPTION) */
  @Param a11yRole: AccessibilityRoleType = AccessibilityRoleType.MENU_ITEM;
  @Event onActivate: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get fg(): string {
    return this.variant === 'destructive' ? this.theme.colors.destructive : this.theme.colors.popoverForeground;
  }

  @Computed
  get hoverBg(): string {
    return this.variant === 'destructive' ? SparkColor.alpha(this.theme.colors.destructive, 0.1) :
      this.theme.colors.accent;
  }

  /** check / radio rows report `checked`; plain rows and Select options report `selected` */
  private get checkable(): boolean {
    return this.indicator === 'check-left' || this.indicator === 'dot-left';
  }

  private activate(): void {
    if (!this.disabled) {
      this.onActivate();
    }
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.ix.hovered && !this.disabled ? this.hoverBg : Color.Transparent)
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.disabled ? Color.Transparent : this.hoverBg)
  }

  build() {
    Row({ space: 8 }) {
      if (this.indicator === 'check-left' || this.indicator === 'dot-left' || this.inset) {
        Stack() {
          if (this.selected && this.indicator === 'check-left') {
            SIcon({ name: 'check', sizing: 16, color: this.fg })
          } else if (this.selected && this.indicator === 'dot-left') {
            Column()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.fg)
          }
        }
        .width(16)
        .height(16)
      }
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 16, color: this.variant === 'destructive' ? this.fg :
          this.theme.colors.mutedForeground })
      }
      Text(this.text)
        .layoutWeight(1)
        .fontSize(this.roomy ? this.theme.text.base : this.theme.text.sm)
        .fontColor(this.fg)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.shortcut !== undefined) {
        Text(this.shortcut)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.mutedForeground)
          .letterSpacing(1.5)
      }
      if (this.indicator === 'check-right') {
        Stack() {
          if (this.selected) {
            SIcon({ name: 'check', sizing: 16, color: this.fg })
          }
        }
        .width(16)
        .height(16)
      }
    }
    .width('100%')
    .height(this.roomy ? 44 : 32)
    .padding({ left: 8, right: 8 })
    .borderRadius(this.theme.radiusSm)
    .opacity(this.disabled ? 0.5 : 1)
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => this.activate())
    .onKeyEvent((e: KeyEvent) => {
      if (sparkIsEnterUp(e)) {
        this.activate();
      }
    })
    .focusable(!this.disabled)
    .accessibilityGroup(true)
    .accessibilityRole(this.a11yRole)
    .accessibilityText(typeof this.text === 'string' ? this.text : '')
    .accessibilityDescription(this.disabled ? 'disabled' : '')
    .accessibilityChecked(this.checkable ? this.selected : undefined)
    .accessibilitySelected(this.checkable ? undefined : this.selected)
  }
}

/** `-mx-1 my-1 h-px bg-border` */
@ComponentV2
export struct MenuSeparator {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column()
      .width('100%')
      .height(1)
      .margin({ top: 4, bottom: 4 })
      .backgroundColor(this.theme.colors.border)
  }
}

/** `px-2 py-1.5 text-sm font-medium` (or muted xs for Select group labels). */
@ComponentV2
export struct MenuLabel {
  @Param text: ResourceStr = '';
  @Param muted: boolean = false;
  @Param inset: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .width('100%')
      .padding({ left: this.inset ? 32 : 8, right: 8, top: 6, bottom: 6 })
      .fontSize(this.muted ? this.theme.text.xs : this.theme.text.sm)
      .fontWeight(this.muted ? this.theme.text.weightNormal : this.theme.text.weightMedium)
      .fontColor(this.muted ? this.theme.colors.mutedForeground : this.theme.colors.popoverForeground)
  }
}
