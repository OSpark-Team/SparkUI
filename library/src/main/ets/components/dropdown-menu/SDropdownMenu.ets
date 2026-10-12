import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { MenuItemVariant, MenuLabel, MenuRow, MenuSeparator } from '../../primitives/menu/MenuRow';
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
const RADIO_KEY: string = 'spark.dropdown.radio';

/** Whether a menu-like overlay should become a bottom sheet (semantic translation). */
export function sparkUseSheet(adaptive: SparkAdaptive): boolean {
  const env = SparkUI.layout.env;
  return adaptive === 'touch' ||
    (adaptive === 'auto' && env.modality === 'touch' && env.windowWidthClass === 'compact');
}

/**
 * shadcn-vue `DropdownMenu`. Anchored menu on pointer / wide screens; on compact touch screens it
 * automatically becomes a bottom sheet with touch-sized rows (`adaptive: 'auto'`).
 *
 * ```
 * SDropdownMenu() {
 *   SDropdownMenuTrigger() { SButton({ text: 'Open', variant: 'outline' }) }
 *   SDropdownMenuContent() {
 *     SDropdownMenuLabel({ text: 'My Account' })
 *     SDropdownMenuSeparator()
 *     SDropdownMenuItem({ text: 'Profile', icon: 'user', shortcut: '⇧⌘P' }).onClick(() => ...)
 *     SDropdownMenuItem({ text: 'Log out', icon: 'log-out', variant: 'destructive' })
 *   }
 * }
 * ```
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
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
      this.ctx = ctx;
      if (ctx !== undefined) {
        this.binding.attach(this.getUIContext(), ctx, (scope: SparkOverlayScope) => {
          this.sheet = sparkUseSheet(this.adaptive);
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
          scope.contextKey = KEY;
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

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        Row() {
          Column().width(40).height(4).borderRadius(2).backgroundColor(this.theme.colors.muted)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 8 })
      }
      this.content()
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

/** Resolves the dropdown state (inside the overlay) and closes it after activation. */
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
  /** reka-style select event (alternative to `.onClick()`) */
  @Event onSelect: () => void = () => {
  };
  @Local ctx: SparkDisclosure | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
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
      roomy: this.ctx?.placement === 'sheet',
      onActivate: () => {
        this.onSelect();
        if (!this.keepOpen) {
          this.ctx?.setOpen(false);
        }
      }
    })
  }
}

/** Item with a check mark; toggles `checked`. */
@ComponentV2
export struct SDropdownMenuCheckboxItem {
  @Param text: ResourceStr = '';
  @Param checked: boolean | undefined = undefined;
  @Event $checked: (v: boolean) => void = () => {
  };
  @Param defaultChecked: boolean = false;
  @Event onCheckedChange: (v: boolean) => void = () => {
  };
  @Param disabled: boolean = false;
  @Local current: boolean = false;
  @Local ctx: SparkDisclosure | undefined = undefined;

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
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  build() {
    MenuRow({
      text: this.text,
      indicator: 'check-left',
      selected: this.current,
      disabled: this.disabled,
      roomy: this.ctx?.placement === 'sheet',
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

@ObservedV2
class DropdownRadioState {
  @Trace value: string = '';
  emit: (v: string) => void = () => {
  };
}

@ComponentV2
export struct SDropdownMenuRadioGroup {
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: DropdownRadioState = new DropdownRadioState();

  aboutToAppear(): void {
    this.state.value = this.value ?? this.defaultValue;
    this.state.emit = (v: string) => {
      if (this.value === undefined) {
        this.state.value = v;
      }
      this.$value(v);
      this.onValueChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), RADIO_KEY, this.state);
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

@ComponentV2
export struct SDropdownMenuRadioItem {
  @Param value: string = '';
  @Param text: ResourceStr = '';
  @Param disabled: boolean = false;
  @Local group: DropdownRadioState | undefined = undefined;
  @Local ctx: SparkDisclosure | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.group === undefined) {
      this.group = SparkContext.resolve<DropdownRadioState>(this.getUIContext(), this.getUniqueId(), RADIO_KEY);
      this.ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  build() {
    MenuRow({
      text: this.text,
      indicator: 'dot-left',
      selected: this.group?.value === this.value,
      disabled: this.disabled,
      roomy: this.ctx?.placement === 'sheet',
      onActivate: () => this.group?.emit(this.value)
    })
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
