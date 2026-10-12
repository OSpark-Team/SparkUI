import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { MenuItemVariant, MenuLabel, MenuSeparator } from '../../primitives/menu/MenuRow';
import {
  SPARK_SHEET_HANDLE_HEIGHT, SparkMenuCheckboxPart, SparkMenuHandle, SparkMenuItemPart, sparkMenuPanelMaxHeight,
  SparkMenuRadioGroupPart, SparkMenuRadioPart, SparkMenuScroll, sparkSheetHandle
} from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkAlign, SparkSide } from '../../primitives/overlay/Placement';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkSurface, sparkSurfaceDefaults, SparkSurfaceStyle, SparkSurfaceTokens
} from '../../theme/tokens/SparkTokenReader';

const KEY: string = 'spark.dropdown';
/** key of the item handle inside the overlay */
const ITEM_KEY: string = 'spark.dropdown.items';

/** Whether a menu-like overlay should become a bottom sheet (semantic translation). */
export function sparkUseSheet(adaptive: SparkAdaptive): boolean {
  const env = SparkUI.layout.env;
  return adaptive === 'touch' ||
    (adaptive === 'auto' && env.modality === 'touch' && env.windowWidthClass === 'compact');
}

/**
 * shadcn-vue `DropdownMenu`. Anchored menu on pointer / wide screens; on compact touch screens it
 * automatically becomes a bottom sheet with touch-sized rows (`adaptive: 'auto'`). Long menus scroll within
 * the space available next to the trigger.
 *
 * ```
 * SDropdownMenu() {
 *   SDropdownMenuTrigger() { SButton({ text: 'Open', variant: 'outline' }) }
 *   SDropdownMenuContent() {
 *     SDropdownMenuLabel({ text: 'My Account' })
 *     SDropdownMenuSeparator()
 *     SDropdownMenuItem({ text: 'Profile', icon: 'user', shortcut: '⇧⌘P', onSelect: () => ... })
 *     SDropdownMenuItem({ text: 'Log out', icon: 'log-out', variant: 'destructive' })
 *   }
 * }
 * ```
 * Items report activation through `onSelect` (a `.onClick()` chained on an item does not fire: the row's own
 * click — which also serves keyboard and screen readers — takes it).
 */
@ComponentV2
export struct SDropdownMenu {
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = false;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkDisclosure = new SparkDisclosure();

  aboutToAppear(): void {
    this.state.controlled = this.open !== undefined;
    this.state.open = this.open ?? this.defaultOpen;
    this.state.emit = (v: boolean) => {
      this.$open(v);
      this.onOpenChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.state.assign(this.open);
    }
  }

  build() {
    Stack() {
      this.content()
    }
  }
}

@ComponentV2
export struct SDropdownMenuTrigger {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local ctx: SparkDisclosure | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
      if (this.ctx !== undefined) {
        this.ctx.triggerKey = sparkTriggerKey(this.getUniqueId());
        this.ctx.triggerUniqueId = this.getUniqueId();
      }
    }
  }

  build() {
    Stack() {
      this.content()
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .onClick(() => this.ctx?.toggle())
  }
}

/** `bg-popover min-w-[8rem] rounded-md border p-1 shadow-md`, or a bottom sheet on compact touch screens. */
@ComponentV2
export struct SDropdownMenuContent {
  @Param side: SparkSide = 'bottom';
  @Param alignment: SparkAlign = 'start';
  @Param sideOffset: number = 4;
  @Param adaptive: SparkAdaptive = 'auto';
  /** panel width in vp (shadcn examples use w-56 = 224); children size against it */
  @Param panelWidth: number = 224;
  /** Per-instance surface token overrides (instance → theme tokens → recipe), see {@link SparkSurfaceTokens}. */
  @Param tokens: SparkSurfaceTokens = {};
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkDisclosure | undefined = undefined;
  @Local sheet: boolean = false;
  /** the open layer (its placement bounds the panel height) */
  @Local scope: SparkOverlayScope | undefined = undefined;
  /** long-lived item handle: sheet flag, close, uncontrolled checkbox / radio memory */
  private handle: SparkMenuHandle = new SparkMenuHandle();
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
      this.ctx = ctx;
      if (ctx !== undefined) {
        this.handle.close = () => ctx.setOpen(false);
        this.binding.attach(this.getUIContext(), ctx, (scope: SparkOverlayScope) => {
          this.sheet = sparkUseSheet(this.adaptive);
          this.handle.sheet = this.sheet;
          this.scope = scope;
          ctx.placement = this.sheet ? 'sheet' : 'anchored';
          scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
          scope.motionKey = 'menu';
          scope.modal = this.sheet;
          scope.dismissOnOutside = true;
          scope.anchor = ctx.anchorRect(this.getUIContext());
          scope.side = this.side;
          scope.alignment = this.alignment;
          scope.sideOffset = this.sideOffset;
          scope.content = this.panel;
          scope.contextKey = ITEM_KEY;
          scope.contextValue = this.handle;
          scope.theme = this.theme;
          scope.layout = this.layout;
        });
      }
    }
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  /** `bg-popover rounded-md border p-1 shadow-md` → `--menu-*` tokens → instance tokens */
  @Computed
  get surface(): SparkSurfaceStyle {
    const t = this.theme;
    return sparkSurface(t, 'menu', sparkSurfaceDefaults(t.colors.popover, t.colors.border, t.borderWidth,
      this.sheet ? t.radiusXl : t.radiusMd, this.sheet ? 8 : 4, t.shadows.md), this.tokens);
  }

  /** padding + border (+ sheet handle and bottom safe area) around the item list */
  private chrome(): number {
    const s = this.surface;
    if (this.sheet) {
      return s.padding * 2 + s.borderWidth + SPARK_SHEET_HANDLE_HEIGHT + this.layout.env.safeArea.bottom;
    }
    return s.padding * 2 + s.borderWidth * 2;
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      SparkMenuScroll({ maxListHeight: sparkMenuPanelMaxHeight(this.scope, this.sheet, this.chrome()) }) {
        this.content()
      }
    }
    // a definite width: with an auto-width panel, '100%' rows resolve against the overlay layer
    .width(this.sheet ? '100%' : this.panelWidth)
    .padding(this.sheet ? {
      left: this.surface.padding,
      right: this.surface.padding,
      top: this.surface.padding,
      bottom: this.surface.padding + this.layout.env.safeArea.bottom
    } : this.surface.padding)
    .backgroundColor(this.surface.background)
    .border({
      width: this.sheet ? { top: this.surface.borderWidth } : this.surface.borderWidth,
      color: this.surface.borderColor,
      radius: this.sheet ? { topLeft: this.surface.radius, topRight: this.surface.radius } : this.surface.radius
    })
    .shadow(SparkTokenOverride.shadowOptions(this.surface.shadow))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}

/** Action row; closes the menu after activation (unless `keepOpen`). */
@ComponentV2
export struct SDropdownMenuItem {
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  @Param shortcut: string | undefined = undefined;
  @Param variant: MenuItemVariant = 'default';
  @Param disabled: boolean = false;
  @Param inset: boolean = false;
  /** keep the menu open after activation */
  @Param keepOpen: boolean = false;
  /** reka-style select event: tap, click, Space / Enter and screen-reader activation */
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

/**
 * Item with a check mark; toggles `checked`. Uncontrolled (`defaultChecked`) values are remembered across
 * openings, keyed by `value` (default: the label).
 */
@ComponentV2
export struct SDropdownMenuCheckboxItem {
  /** identity for the uncontrolled memory (default: the label) */
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

  build() {
    SparkMenuCheckboxPart({
      menuKey: ITEM_KEY,
      value: this.value,
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

/**
 * Single-choice group. Uncontrolled (`defaultValue`) values are remembered across openings, keyed by `name`
 * (default: the defaultValue — give groups sharing a defaultValue distinct names).
 */
@ComponentV2
export struct SDropdownMenuRadioGroup {
  /** identity for the uncontrolled memory (default: the defaultValue) */
  @Param name: string = '';
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
      name: this.name,
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
export struct SDropdownMenuRadioItem {
  @Param value: string = '';
  @Param text: ResourceStr = '';
  @Param disabled: boolean = false;

  build() {
    SparkMenuRadioPart({ menuKey: ITEM_KEY, value: this.value, text: this.text, disabled: this.disabled })
  }
}

@ComponentV2
export struct SDropdownMenuLabel {
  @Param text: ResourceStr = '';
  @Param inset: boolean = false;

  build() {
    MenuLabel({ text: this.text, inset: this.inset })
  }
}

@ComponentV2
export struct SDropdownMenuSeparator {
  build() {
    MenuSeparator()
  }
}

@ComponentV2
export struct SDropdownMenuGroup {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
  }
}
