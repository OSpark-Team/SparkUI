import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { MenuItemVariant, MenuLabel, MenuSeparator } from '../../primitives/menu/MenuRow';
import {
  SparkMenuCheckboxPart, SparkMenuHandle, SparkMenuItemPart, SparkMenuRadioGroupPart, SparkMenuRadioPart,
  sparkSheetHandle
} from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { PlacementRect } from '../../primitives/overlay/Placement';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';

const KEY: string = 'spark.contextmenu';
/** key of the item handle inside the overlay */
const ITEM_KEY: string = 'spark.contextmenu.items';
const LONG_PRESS_MS: number = 500;

/** Open state + the point the menu opens at (window vp). */
@ObservedV2
export class SparkContextMenuState {
  readonly disclosure: SparkDisclosure = new SparkDisclosure();
  readonly handle: SparkMenuHandle = new SparkMenuHandle();
  x: number = 0;
  y: number = 0;
  /** opened with the mouse (right click): never a bottom sheet */
  viaPointer: boolean = false;
  disabled: boolean = false;

  constructor() {
    this.handle.close = () => this.disclosure.setOpen(false);
  }

  openAt(x: number, y: number, viaPointer: boolean): void {
    if (this.disabled) {
      return;
    }
    this.x = x;
    this.y = y;
    this.viaPointer = viaPointer;
    this.disclosure.setOpen(true);
  }
}

/**
 * shadcn-vue `ContextMenu`: a menu opened on the trigger area with a right click (pointer, at the pointer
 * position) or a long press (touch, at the finger). On compact touch screens it becomes a bottom sheet.
 *
 * ```
 * SContextMenu() {
 *   SContextMenuTrigger() { Text('Right click here') ... }
 *   SContextMenuContent() {
 *     SContextMenuItem({ text: 'Back', shortcut: '⌘[' }).onClick(() => ...)
 *     SContextMenuItem({ text: 'Reload', shortcut: '⌘R', onSelect: () => ... })
 *     SContextMenuSeparator()
 *     SContextMenuCheckboxItem({ text: 'Show Bookmarks', checked: this.bookmarks!! })
 *     SContextMenuSeparator()
 *     SContextMenuLabel({ text: 'People', inset: true })
 *     SContextMenuRadioGroup({ value: this.person!! }) {
 *       SContextMenuRadioItem({ value: 'pedro', text: 'Pedro Duarte' })
 *       SContextMenuRadioItem({ value: 'colm', text: 'Colm Tuite' })
 *     }
 *   }
 * }
 * ```
 */
@ComponentV2
export struct SContextMenu {
  @Param disabled: boolean = false;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkContextMenuState = new SparkContextMenuState();

  aboutToAppear(): void {
    this.state.disabled = this.disabled;
    this.state.disclosure.emit = (v: boolean) => this.onOpenChange(v);
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('disabled')
  syncDisabled(): void {
    this.state.disabled = this.disabled;
  }

  build() {
    Stack() {
      this.content()
    }
  }
}

/**
 * The area that opens the menu: right mouse button → at the pointer; touch long-press (500 ms without moving
 * more than 10 vp) → at the finger. Long-press uses a touch timer (a LongPressGesture loses to inner buttons).
 */
@ComponentV2
export struct SContextMenuTrigger {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkContextMenuState | undefined = undefined;
  private timer: number = -1;
  private downX: number = 0;
  private downY: number = 0;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkContextMenuState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  aboutToDisappear(): void {
    clearTimeout(this.timer);
  }

  private mouse(e: MouseEvent): void {
    if (e.button === MouseButton.Right && e.action === MouseAction.Press && this.state !== undefined) {
      SparkUI.layout.reportPointerEvent(true);
      this.state.openAt(e.windowX, e.windowY, true);
      e.stopPropagation();
    }
  }

  private touch(e: TouchEvent): void {
    const state = this.state;
    if (state === undefined || e.source === SourceType.Mouse) {
      return;
    }
    const t = e.touches.length > 0 ? e.touches[0] : (e.changedTouches.length > 0 ? e.changedTouches[0] : undefined);
    if (e.type === TouchType.Down && t !== undefined) {
      this.downX = t.windowX;
      this.downY = t.windowY;
      clearTimeout(this.timer);
      const x = t.windowX;
      const y = t.windowY;
      this.timer = setTimeout(() => state.openAt(x, y, false), LONG_PRESS_MS);
    } else if (e.type === TouchType.Move && t !== undefined) {
      if (Math.abs(t.windowX - this.downX) > 10 || Math.abs(t.windowY - this.downY) > 10) {
        clearTimeout(this.timer);
      }
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      clearTimeout(this.timer);
    }
  }

  build() {
    Stack() {
      this.content()
    }
    .onMouse((e: MouseEvent) => this.mouse(e))
    .onTouch((e: TouchEvent) => this.touch(e))
  }
}

/** `bg-popover min-w-[8rem] rounded-md border p-1 shadow-md` at the pointer; bottom sheet on compact touch. */
@ComponentV2
export struct SContextMenuContent {
  /** panel width in vp (shadcn demo: w-52 = 208); rows size against it */
  @Param panelWidth: number = 208;
  @Param adaptive: SparkAdaptive = 'auto';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local state: SparkContextMenuState | undefined = undefined;
  @Local sheet: boolean = false;
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      const state = SparkContext.resolve<SparkContextMenuState>(this.getUIContext(), this.getUniqueId(), KEY);
      this.state = state;
      if (state !== undefined) {
        this.binding.attach(this.getUIContext(), state.disclosure, (scope: SparkOverlayScope) => {
          this.sheet = !state.viaPointer && sparkUseSheet(this.adaptive);
          state.handle.sheet = this.sheet;
          scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
          scope.motionKey = 'menu';
          scope.modal = this.sheet;
          scope.dismissOnOutside = true;
          scope.restoreFocusId = '';
          // zero-size anchor at the pointer / finger: the menu's top-left corner sits there (flips / shifts)
          scope.anchor = new PlacementRect(state.x, state.y, 0, 0);
          scope.side = 'bottom';
          scope.alignment = 'start';
          scope.sideOffset = 2;
          scope.content = this.panel;
          scope.contextKey = ITEM_KEY;
          scope.contextValue = state.handle;
          scope.theme = this.theme;
          scope.layout = this.layout;
        });
      }
    }
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      this.content()
    }
    // a definite width: with an auto-width panel, '100%' rows resolve against the overlay layer
    .width(this.sheet ? '100%' : this.panelWidth)
    .padding(this.sheet ? { left: 8, right: 8, top: 8, bottom: 8 + this.layout.env.safeArea.bottom } : 4)
    .backgroundColor(this.theme.colors.popover)
    .border({
      width: this.sheet ? { top: 1 } : 1,
      color: this.theme.colors.border,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusMd
    })
    .shadow(this.theme.shadows.md.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}

/** Action row; closes the menu after activation (`onSelect` and the native `.onClick()` both fire). */
@ComponentV2
export struct SContextMenuItem {
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  @Param shortcut: string | undefined = undefined;
  @Param variant: MenuItemVariant = 'default';
  @Param disabled: boolean = false;
  @Param inset: boolean = false;
  @Param keepOpen: boolean = false;
  @Event onSelect: () => void = () => {
  };

  build() {
    SparkMenuItemPart({
      menuKey: ITEM_KEY,
      text: this.text,
      icon: this.icon,
      shortcut: this.shortcut,
      variant: this.variant,
      disabled: this.disabled,
      inset: this.inset,
      keepOpen: this.keepOpen,
      onSelect: () => this.onSelect()
    })
  }
}

@ComponentV2
export struct SContextMenuCheckboxItem {
  @Param text: ResourceStr = '';
  @Param shortcut: string | undefined = undefined;
  @Param checked: boolean | undefined = undefined;
  @Event $checked: (v: boolean) => void = () => {
  };
  @Param defaultChecked: boolean = false;
  @Event onCheckedChange: (v: boolean) => void = () => {
  };
  @Param disabled: boolean = false;

  build() {
    SparkMenuCheckboxPart({
      menuKey: ITEM_KEY,
      text: this.text,
      shortcut: this.shortcut,
      checked: this.checked,
      $checked: (v: boolean) => this.$checked(v),
      defaultChecked: this.defaultChecked,
      onCheckedChange: (v: boolean) => this.onCheckedChange(v),
      disabled: this.disabled
    })
  }
}

@ComponentV2
export struct SContextMenuRadioGroup {
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SparkMenuRadioGroupPart({
      menuKey: ITEM_KEY,
      value: this.value,
      $value: (v: string) => this.$value(v),
      defaultValue: this.defaultValue,
      onValueChange: (v: string) => this.onValueChange(v)
    }) {
      this.content()
    }
  }
}

@ComponentV2
export struct SContextMenuRadioItem {
  @Param value: string = '';
  @Param text: ResourceStr = '';
  @Param disabled: boolean = false;

  build() {
    SparkMenuRadioPart({ menuKey: ITEM_KEY, value: this.value, text: this.text, disabled: this.disabled })
  }
}

@ComponentV2
export struct SContextMenuLabel {
  @Param text: ResourceStr = '';
  @Param inset: boolean = false;

  build() {
    MenuLabel({ text: this.text, inset: this.inset })
  }
}

@ComponentV2
export struct SContextMenuSeparator {
  build() {
    MenuSeparator()
  }
}

@ComponentV2
export struct SContextMenuGroup {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
  }
}
