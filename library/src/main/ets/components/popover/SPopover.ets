import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkAlign, SparkSide } from '../../primitives/overlay/Placement';
import { closeSparkOverlay, openSparkOverlay } from '../../primitives/overlay/SparkOverlayHost';
import { SparkOverlayScope, SparkOverlayService } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkSurface, sparkSurfaceDefaults, SparkSurfaceStyle, SparkSurfaceTokens
} from '../../theme/tokens/SparkTokenReader';

const KEY: string = 'spark.popover';

/**
 * shadcn-vue `Popover`.
 *
 * ```
 * SPopover() {
 *   SPopoverTrigger() { SButton({ text: 'Open popover', variant: 'outline' }) }
 *   SPopoverContent({ side: 'bottom', alignment: 'start' }) { ... }
 * }
 * ```
 */
@ComponentV2
export struct SPopover {
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

/** Toggles the popover; its bounds are the anchor. */
@ComponentV2
export struct SPopoverTrigger {
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

/** Closes the popover when tapped. */
@ComponentV2
export struct SPopoverClose {
  @BuilderParam content: () => void = sparkEmptyBuilder;
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
    Stack() {
      this.content()
    }
    .onClick(() => this.ctx?.setOpen(false))
  }
}

/** Anchored panel: `bg-popover w-72 rounded-md border p-4 shadow-md`, flips / shifts to stay on screen. */
@ComponentV2
export struct SPopoverContent {
  @Param side: SparkSide = 'bottom';
  @Param alignment: SparkAlign = 'center';
  @Param sideOffset: number = 4;
  @Param alignOffset: number = 0;
  /** Panel width in vp (shadcn w-72 = 288). */
  @Param panelWidth: number = 288;
  /** Per-instance surface token overrides (instance → theme tokens → recipe), see {@link SparkSurfaceTokens}. */
  @Param tokens: SparkSurfaceTokens = {};
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkDisclosure | undefined = undefined;
  private scope: SparkOverlayScope | undefined = undefined;
  private unsubscribe: () => void = () => {
  };

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), KEY);
      this.ctx = ctx;
      if (ctx !== undefined) {
        this.unsubscribe = ctx.subscribe((open: boolean) => open ? this.show() : this.hide());
        if (ctx.open) {
          this.show();
        }
      }
    }
  }

  aboutToDisappear(): void {
    this.unsubscribe();
    this.hide();
  }

  private show(): void {
    if (this.scope !== undefined && SparkOverlayService.isOpen(this.scope)) {
      return;
    }
    const ctx = this.ctx;
    if (ctx === undefined) {
      return;
    }
    const scope = SparkOverlayService.createScope();
    scope.presentation = 'anchored';
          scope.motionKey = 'popover';
    scope.modal = false;
    scope.dismissOnOutside = true;
    scope.anchor = ctx.anchorRect(this.getUIContext());
    scope.side = this.side;
    scope.alignment = this.alignment;
    scope.sideOffset = this.sideOffset;
    scope.alignOffset = this.alignOffset;
    scope.content = this.panel;
    scope.contextKey = KEY;
    scope.contextValue = ctx;
    scope.restoreFocusId = ctx.triggerKey;
    scope.theme = this.theme;
    scope.layout = this.layout;
    scope.onDismiss = () => ctx.setOpen(false);
    this.scope = scope;
    openSparkOverlay(this.getUIContext(), scope);
  }

  private hide(): void {
    if (this.scope !== undefined) {
      closeSparkOverlay(this.scope);
    }
  }

  /** `bg-popover rounded-md border p-4 shadow-md` → `--popover-*` tokens → instance tokens */
  @Computed
  get surface(): SparkSurfaceStyle {
    const t = this.theme;
    return sparkSurface(t, 'popover', sparkSurfaceDefaults(t.colors.popover, t.colors.border, t.borderWidth,
      t.radiusMd, 16, t.shadows.md), this.tokens);
  }

  @LocalBuilder
  panel() {
    Column() {
      this.content()
    }
    .width(this.panelWidth)
    .alignItems(HorizontalAlign.Start)
    .padding(this.surface.padding)
    .backgroundColor(this.surface.background)
    .border({ width: this.surface.borderWidth, color: this.surface.borderColor, radius: this.surface.radius })
    .shadow(SparkTokenOverride.shadowOptions(this.surface.shadow))
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
