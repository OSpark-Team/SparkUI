import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { MenuItemVariant, MenuRow } from './MenuRow';

/**
 * What a menu item needs from the menu surface it is rendered in (ContextMenu, Menubar …): whether the
 * surface is a touch bottom sheet (roomy rows) and how to close it after activation. Provided inside the
 * overlay through `SparkOverlayScope.contextKey/contextValue`.
 */
@ObservedV2
export class SparkMenuHandle {
  @Trace sheet: boolean = false;
  close: () => void = () => {
  };
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

/** Row with a leading check mark; toggles (controlled `checked` + `$checked`, or uncontrolled). */
@ComponentV2
export struct SparkMenuCheckboxPart {
  @Param @Require menuKey: string;
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
      this.handle = SparkContext.resolve<SparkMenuHandle>(this.getUIContext(), this.getUniqueId(), this.menuKey);
    }
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
        }
        this.$checked(v);
        this.onCheckedChange(v);
      }
    })
  }
}

/** Single-choice group for {@link SparkMenuRadioPart}s. */
@ComponentV2
export struct SparkMenuRadioGroupPart {
  @Param @Require menuKey: string;
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: MenuRadioState = new MenuRadioState();

  aboutToAppear(): void {
    this.state.value = this.value ?? this.defaultValue;
    this.state.emit = (v: string) => {
      if (this.value === undefined) {
        this.state.value = v;
      }
      this.$value(v);
      this.onValueChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), radioKey(this.menuKey), this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
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
