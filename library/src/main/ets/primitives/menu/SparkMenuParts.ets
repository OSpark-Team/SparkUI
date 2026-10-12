import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkOverlayScope } from '../overlay/SparkOverlay';
import { SparkMenuMemory, sparkMenuCheckKey, sparkMenuListMaxHeight, sparkMenuRadioKey } from './MenuMemory';
import { MenuItemVariant, MenuRow } from './MenuRow';

/**
 * What a menu item needs from the menu surface it is rendered in (DropdownMenu, ContextMenu, Menubar …):
 * whether the surface is a touch bottom sheet (roomy rows), how to close it after activation, and the memory
 * of uncontrolled checkbox / radio values. Lives in the menu's long-lived state (outside the overlay) and is
 * provided inside the overlay through `SparkOverlayScope.contextKey/contextValue`.
 */
@ObservedV2
export class SparkMenuHandle {
  @Trace sheet: boolean = false;
  close: () => void = () => {
  };
  /** uncontrolled checkbox / radio values; survives the overlay content being rebuilt on every open */
  memory: SparkMenuMemory = new SparkMenuMemory();
}

/** Gap kept above a bottom-sheet menu (vp) so it never covers the whole window. */
const SHEET_TOP_GAP: number = 48;

/**
 * Max height (vp) of a menu panel's item list: the space left by the anchored placement on its side, or most
 * of the window for a bottom sheet, minus `chrome` (the panel's padding, border and sheet handle).
 * Reactive: reads `scope.placement`, which the overlay host updates whenever it places the panel.
 */
export function sparkMenuPanelMaxHeight(scope: SparkOverlayScope | undefined, sheet: boolean, chrome: number): number {
  if (scope === undefined) {
    return Infinity;
  }
  if (sheet) {
    const env = scope.layout.env;
    const h = SparkUI.layout.root.height;
    return h > 0 ? sparkMenuListMaxHeight(h - env.safeArea.top - SHEET_TOP_GAP, chrome) : Infinity;
  }
  const p = scope.placement;
  return sparkMenuListMaxHeight(p === undefined ? undefined : p.availableHeight, chrome);
}

/**
 * Scrolling item list of a menu panel (`max-h-(--available-height) overflow-y-auto`): content-sized until it
 * reaches `maxListHeight`, then it scrolls. Keyboard focus moving onto a row scrolls it into view (the Scroll
 * container's focus handling).
 */
@ComponentV2
export struct SparkMenuScroll {
  @Param maxListHeight: number = Infinity;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  private scroller: Scroller = new Scroller();

  build() {
    Scroll(this.scroller) {
      Column() {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxHeight: this.maxListHeight })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.None)
    .align(Alignment.Top)
  }
}

@ObservedV2
class MenuRadioState {
  @Trace value: string = '';
  emit: (v: string) => void = () => {
  };
}

function radioKey(menuKey: string): string {
  return `${menuKey}.radio`;
}

/** Plain action row; closes the surface found under `menuKey` after activation (unless keepOpen). */
@ComponentV2
export struct SparkMenuItemPart {
  @Param @Require menuKey: string;
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  @Param shortcut: string | undefined = undefined;
  @Param variant: MenuItemVariant = 'default';
  @Param disabled: boolean = false;
  @Param inset: boolean = false;
  @Param keepOpen: boolean = false;
  @Event onSelect: () => void = () => {
  };
  @Local handle: SparkMenuHandle | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.handle === undefined) {
      this.handle = SparkContext.resolve<SparkMenuHandle>(this.getUIContext(), this.getUniqueId(), this.menuKey);
    }
  }

  build() {
    MenuRow({
      text: this.text,
      icon: this.icon,
      shortcut: this.shortcut,
      variant: this.variant,
      disabled: this.disabled,
      inset: this.inset,
      roomy: this.handle?.sheet === true,
      onActivate: () => {
        this.onSelect();
        if (!this.keepOpen) {
          this.handle?.close();
        }
      }
    })
  }
}

/**
 * Row with a leading check mark; toggles (controlled `checked` + `$checked`, or uncontrolled). The uncontrolled
 * value is remembered in the menu's {@link SparkMenuHandle} under `value` (else the label), so it survives
 * closing and reopening the menu.
 */
@ComponentV2
export struct SparkMenuCheckboxPart {
  @Param @Require menuKey: string;
  /** identity of the item for the uncontrolled memory (default: the label) */
  @Param value: string = '';
  @Param text: ResourceStr = '';
  @Param shortcut: string | undefined = undefined;
  @Param checked: boolean | undefined = undefined;
  @Event $checked: (v: boolean) => void = () => {
  };
  @Param defaultChecked: boolean = false;
  @Event onCheckedChange: (v: boolean) => void = () => {
  };
  @Param disabled: boolean = false;
  @Local current: boolean = false;
  @Local handle: SparkMenuHandle | undefined = undefined;

  aboutToAppear(): void {
    this.current = this.checked ?? this.defaultChecked;
  }

  @Monitor('checked')
  sync(): void {
    if (this.checked !== undefined) {
      this.current = this.checked;
    }
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.handle === undefined) {
      const handle = SparkContext.resolve<SparkMenuHandle>(this.getUIContext(), this.getUniqueId(), this.menuKey);
      this.handle = handle;
      if (handle !== undefined && this.checked === undefined) {
        this.current = handle.memory.checked(this.memoryKey(), this.defaultChecked);
      }
    }
  }

  private memoryKey(): string {
    return sparkMenuCheckKey(this.value, this.text);
  }

  build() {
    MenuRow({
      text: this.text,
      shortcut: this.shortcut,
      indicator: 'check-left',
      selected: this.current,
      disabled: this.disabled,
      roomy: this.handle?.sheet === true,
      onActivate: () => {
        const v = !this.current;
        if (this.checked === undefined) {
          this.current = v;
          this.handle?.memory.setChecked(this.memoryKey(), v);
        }
        this.$checked(v);
        this.onCheckedChange(v);
      }
    })
  }
}

/**
 * Single-choice group for {@link SparkMenuRadioPart}s. The uncontrolled value is remembered in the menu's
 * {@link SparkMenuHandle} under `name` (else the defaultValue), so it survives closing and reopening the menu.
 */
@ComponentV2
export struct SparkMenuRadioGroupPart {
  @Param @Require menuKey: string;
  /** identity of the group for the uncontrolled memory (default: its defaultValue) */
  @Param name: string = '';
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: MenuRadioState = new MenuRadioState();
  private handle: SparkMenuHandle | undefined = undefined;

  aboutToAppear(): void {
    this.state.value = this.value ?? this.defaultValue;
    this.state.emit = (v: string) => {
      if (this.value === undefined) {
        this.state.value = v;
        this.handle?.memory.setRadio(sparkMenuRadioKey(this.name, this.defaultValue), v);
      }
      this.$value(v);
      this.onValueChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), radioKey(this.menuKey), this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.handle === undefined) {
      const handle = SparkContext.resolve<SparkMenuHandle>(this.getUIContext(), this.getUniqueId(), this.menuKey);
      this.handle = handle;
      if (handle !== undefined && this.value === undefined) {
        this.state.value = handle.memory.radio(sparkMenuRadioKey(this.name, this.defaultValue), this.defaultValue);
      }
    }
  }

  @Monitor('value')
  sync(): void {
    if (this.value !== undefined) {
      this.state.value = this.value;
    }
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
  }
}

/** Row with a leading dot when it is the group's value. */
@ComponentV2
export struct SparkMenuRadioPart {
  @Param @Require menuKey: string;
  @Param value: string = '';
  @Param text: ResourceStr = '';
  @Param disabled: boolean = false;
  @Local group: MenuRadioState | undefined = undefined;
  @Local handle: SparkMenuHandle | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.group === undefined) {
      this.group = SparkContext.resolve<MenuRadioState>(this.getUIContext(), this.getUniqueId(), radioKey(this.menuKey));
      this.handle = SparkContext.resolve<SparkMenuHandle>(this.getUIContext(), this.getUniqueId(), this.menuKey);
    }
  }

  build() {
    MenuRow({
      text: this.text,
      indicator: 'dot-left',
      selected: this.group?.value === this.value,
      disabled: this.disabled,
      roomy: this.handle?.sheet === true,
      onActivate: () => this.group?.emit(this.value)
    })
  }
}

/** Drag handle shown at the top of menu bottom sheets. */
@Builder
export function sparkSheetHandle(color: string) {
  Row() {
    Column().width(40).height(4).borderRadius(2).backgroundColor(color)
  }
  .width('100%')
  .justifyContent(FlexAlign.Center)
  .padding({ top: 4, bottom: 8 })
}

/** Height of {@link sparkSheetHandle} (vp): 4 + 4 + 8. */
export const SPARK_SHEET_HANDLE_HEIGHT: number = 16;
