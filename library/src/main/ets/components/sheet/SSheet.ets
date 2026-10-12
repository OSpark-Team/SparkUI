import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { closeSparkOverlay, openSparkOverlay } from '../../primitives/overlay/SparkOverlayHost';
import { SparkOverlayScope, SparkOverlayService, SparkPresentation } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';

const KEY: string = 'spark.sheet';

export type SheetSide = 'top' | 'right' | 'bottom' | 'left';

/**
 * shadcn-vue `Sheet`: a dialog that slides in from an edge.
 *
 * ```
 * SSheet() {
 *   SSheetTrigger() { SButton({ text: 'Open', variant: 'outline' }) }
 *   SSheetContent({ side: 'left' }) {
 *     SSheetHeader() { SSheetTitle({ text: 'Menu' }) SSheetDescription({ text: '…' }) }
 *     ...
 *   }
 * }
 * ```
 */
@ComponentV2
export struct SSheet {
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
export struct SSheetTrigger {
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
    .onClick(() => this.ctx?.setOpen(true))
  }
}

@ComponentV2
export struct SSheetClose {
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

/** Edge panel: `bg-background shadow-lg`, left/right `w-3/4 sm:max-w-sm`, slides in from `side`. */
@ComponentV2
export struct SSheetContent {
  @Param side: SheetSide = 'right';
  @Param showCloseButton: boolean = true;
  @Param dismissOnOutside: boolean = true;
  /** Width for left/right sheets in vp (default: 75% of the window, max 384). */
  @Param panelWidth: number = 0;
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

  private presentation(): SparkPresentation {
    switch (this.side) {
      case 'left':
        return 'sheet-left';
      case 'top':
        return 'sheet-top';
      case 'bottom':
        return 'sheet-bottom';
      default:
        return 'sheet-right';
    }
  }

  private show(): void {
    if (this.scope !== undefined && SparkOverlayService.isOpen(this.scope)) {
      return;
    }
    const ctx = this.ctx;
    if (ctx === undefined) {
      return;
    }
    ctx.placement = this.side;
    const scope = SparkOverlayService.createScope();
    scope.presentation = this.presentation();
          scope.motionKey = 'sheet';
    scope.modal = true;
    scope.dismissOnOutside = this.dismissOnOutside;
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

  private get vertical(): boolean {
    return this.side === 'left' || this.side === 'right';
  }

  private sideWidth(): number {
    if (this.panelWidth > 0) {
      return this.panelWidth;
    }
    return Math.min(384, Math.max(240, SparkUI.layout.root.width * 0.75));
  }

  private edgeBorder(): EdgeWidths {
    switch (this.side) {
      case 'left':
        return { right: 1 };
      case 'right':
        return { left: 1 };
      case 'top':
        return { bottom: 1 };
      default:
        return { top: 1 };
    }
  }

  @LocalBuilder
  panel() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 16 }) {
        this.content()
      }
      .width('100%')
      .height(this.vertical ? '100%' : undefined)
      .alignItems(HorizontalAlign.Start)
      .padding({
        top: (this.side === 'bottom' ? 0 : this.layout.env.safeArea.top) + 16,
        bottom: (this.side === 'top' ? 0 : this.layout.env.safeArea.bottom) + 16,
        left: 16,
        right: 16
      })

      if (this.showCloseButton) {
        SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'x', label: 'Close' })
          .margin({ top: (this.side === 'bottom' ? 0 : this.layout.env.safeArea.top) + 12, right: 12 })
          .opacity(0.7)
          .onClick(() => this.ctx?.setOpen(false))
      }
    }
    .width(this.vertical ? this.sideWidth() : '100%')
    .height(this.vertical ? '100%' : undefined)
    .backgroundColor(this.theme.colors.background)
    .border({ width: this.edgeBorder(), color: this.theme.colors.border })
    .shadow(this.theme.shadows.lg.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT])
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}

@ComponentV2
export struct SSheetHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 6 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ right: 32 })
  }
}

/** Actions area. In left / right sheets it is pushed to the bottom (shadcn `mt-auto`). */
@ComponentV2
export struct SSheetFooter {
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

  @Computed
  get grows(): boolean {
    const side = this.ctx?.placement ?? '';
    return side === 'left' || side === 'right';
  }

  build() {
    Column({ space: 8 }) {
      this.content()
    }
    .width('100%')
    .layoutWeight(this.grows ? 1 : 0)
    .justifyContent(FlexAlign.End)
  }
}

@ComponentV2
export struct SSheetTitle {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.base)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.theme.colors.foreground)
  }
}

@ComponentV2
export struct SSheetDescription {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
  }
}
