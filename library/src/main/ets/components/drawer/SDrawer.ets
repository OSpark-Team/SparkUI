import { SparkAnim } from '../../core/SparkAnim';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.drawer';
/** release past this fraction of the panel height closes */
const CLOSE_FRACTION: number = 0.3;
/** downward fling speed (vp/s) that closes regardless of distance */
const FLING_VELOCITY: number = 800;

/**
 * shadcn-vue `Drawer` (vaul): a bottom panel with a drag handle that can be dragged down to dismiss.
 *
 * ```
 * SDrawer() {
 *   SDrawerTrigger() { SButton({ text: 'Open Drawer', variant: 'outline' }) }
 *   SDrawerContent() {
 *     SDrawerHeader() {
 *       SDrawerTitle({ text: 'Move Goal' })
 *       SDrawerDescription({ text: 'Set your daily activity goal.' })
 *     }
 *     ...
 *     SDrawerFooter() {
 *       SButton({ text: 'Submit' })
 *       SDrawerClose() { SButton({ text: 'Cancel', variant: 'outline' }) }
 *     }
 *   }
 * }
 * ```
 * Drag the panel down: it follows the finger; releasing past 30% of its height (or flinging down) closes it,
 * otherwise it springs back (motion key 'drawer').
 */
@ComponentV2
export struct SDrawer {
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
export struct SDrawerTrigger {
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
export struct SDrawerClose {
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

/**
 * The drawer panel (`bg-background rounded-t-lg border-t max-h-[80vh]` + handle `mt-4 h-2 w-[100px]
 * rounded-full bg-muted`), presented as a bottom sheet of the overlay host.
 */
@ComponentV2
export struct SDrawerContent {
  @Param dismissOnOutside: boolean = true;
  /** allow drag-to-dismiss */
  @Param dragToDismiss: boolean = true;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkDisclosure | undefined = undefined;
  /** current drag offset (vp, downward positive); follows the finger without animation */
  @Local dragY: number = 0;
  private panelHeight: number = 0;
  private closing: boolean = false;
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
          this.dragY = 0;
          this.closing = false;
          ctx.placement = 'bottom';
          scope.presentation = 'sheet-bottom';
          scope.motionKey = 'drawer';
          scope.modal = true;
          scope.dismissOnOutside = this.dismissOnOutside;
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

  private dragUpdate(offsetY: number): void {
    if (this.closing) {
      return;
    }
    // downward follows the finger 1:1; upward resists (rubber band, at most 24 vp)
    this.dragY = offsetY >= 0 ? offsetY : -Math.min(24, Math.sqrt(-offsetY) * 2);
  }

  private dragEnd(velocityY: number): void {
    if (this.closing) {
      return;
    }
    const h = this.panelHeight > 0 ? this.panelHeight : 300;
    if (this.dragY > h * CLOSE_FRACTION || (velocityY > FLING_VELOCITY && this.dragY > 0)) {
      // the host slides the panel out from where the finger left it
      this.closing = true;
      this.ctx?.setOpen(false);
    } else {
      SparkAnim.run(this.getUIContext(), this.theme, 'drawer', 'normal', () => {
        this.dragY = 0;
      });
    }
  }

  @LocalBuilder
  panel() {
    Column() {
      // drag handle
      Row() {
        Column()
          .width(100)
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.theme.colors.muted)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 16 })

      Column() {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxHeight: SparkUI.layout.root.height * 0.8 })
    .padding({ bottom: this.layout.env.safeArea.bottom })
    .backgroundColor(this.theme.colors.background)
    .border({
      width: { top: 1 },
      color: this.theme.colors.border,
      radius: { topLeft: this.theme.radiusLg, topRight: this.theme.radiusLg }
    })
    .shadow(this.theme.shadows.lg.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .translate({ y: this.dragY })
    .onSizeChange((_: SizeOptions, n: SizeOptions) => {
      this.panelHeight = Number(n.height);
    })
    .gesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 5 })
        .onActionUpdate((e: GestureEvent) => {
          if (this.dragToDismiss) {
            this.dragUpdate(e.offsetY);
          }
        })
        .onActionEnd((e: GestureEvent) => {
          if (this.dragToDismiss) {
            this.dragEnd(e.velocityY);
          }
        })
        .onActionCancel(() => {
          if (this.dragToDismiss) {
            this.dragEnd(0);
          }
        })
    )
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}

/** `flex flex-col gap-1.5 p-4`, centred text on compact windows (shadcn: text-center md:text-left). */
@ComponentV2
export struct SDrawerHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

  build() {
    Column({ space: 6 }) {
      this.content()
    }
    .width('100%')
    .padding(16)
    .alignItems(this.layout.compact ? HorizontalAlign.Center : HorizontalAlign.Start)
  }
}

/** `mt-auto flex flex-col gap-2 p-4`. */
@ComponentV2
export struct SDrawerFooter {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 8 }) {
      this.content()
    }
    .width('100%')
    .padding(16)
  }
}

@ComponentV2
export struct SDrawerTitle {
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
export struct SDrawerDescription {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
      .textAlign(this.layout.compact ? TextAlign.Center : TextAlign.Start)
  }
}
