import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';

/** SparkContext key shared by Dialog and AlertDialog parts. */
export const SPARK_DIALOG_KEY: string = 'spark.dialog';
const KEY: string = SPARK_DIALOG_KEY;

/**
 * shadcn-vue `Dialog`.
 *
 * ```
 * SDialog() {
 *   SDialogTrigger() { SButton({ text: 'Edit profile', variant: 'outline' }) }
 *   SDialogContent() {
 *     SDialogHeader() {
 *       SDialogTitle({ text: 'Edit profile' })
 *       SDialogDescription({ text: 'Make changes to your profile here.' })
 *     }
 *     ...
 *     SDialogFooter() {
 *       SDialogClose() { SButton({ text: 'Cancel', variant: 'outline' }) }
 *       SButton({ text: 'Save' })
 *     }
 *   }
 * }
 * // controlled: SDialog({ open: this.show!! }) { ... }
 * ```
 */
@ComponentV2
export struct SDialog {
  /** Controlled open state (use with `!!`). Leave undefined for uncontrolled. */
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

/** Opens the dialog when its content is tapped. */
@ComponentV2
export struct SDialogTrigger {
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

/** Closes the dialog when its content is tapped (works inside the dialog content). */
@ComponentV2
export struct SDialogClose {
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
 * The dialog panel. Renders nothing in place; while open it is shown in an overlay layer.
 * - pointer / wide screens: centred `bg-background rounded-lg border p-6 shadow-lg sm:max-w-lg`
 * - touch + compact window (`adaptive: 'auto'`): bottom Drawer with a drag handle (semantic translation)
 */
@ComponentV2
export struct SDialogContent {
  @Param showCloseButton: boolean = true;
  /** Close when tapping the backdrop. */
  @Param dismissOnOutside: boolean = true;
  /** 'auto': Drawer on compact touch screens, centred dialog otherwise. */
  @Param adaptive: SparkAdaptive = 'auto';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkDisclosure | undefined = undefined;
  /** current presentation is the bottom drawer */
  @Local drawer: boolean = false;
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
          const env = SparkUI.layout.env;
          this.drawer = this.adaptive === 'touch' ||
            (this.adaptive === 'auto' && env.modality === 'touch' && env.windowWidthClass === 'compact');
          scope.presentation = this.drawer ? 'sheet-bottom' : 'center';
          scope.motionKey = this.drawer ? 'drawer' : 'dialog';
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

  @LocalBuilder
  panel() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: 16 }) {
          if (this.drawer) {
            // drag handle (shadcn Drawer: mx-auto h-2 w-[100px] rounded-full bg-muted)
            Row() {
              Column()
                .width(100)
                .height(6)
                .borderRadius(3)
                .backgroundColor(this.theme.colors.muted)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          this.content()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: 24,
          right: 24,
          top: this.drawer ? 12 : 24,
          bottom: 24 + (this.drawer ? this.layout.env.safeArea.bottom : 0)
        })

        if (this.showCloseButton && !this.drawer) {
          SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'x', label: 'Close' })
            .margin({ top: 12, right: 12 })
            .opacity(0.7)
            .onClick(() => this.ctx?.setOpen(false))
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.drawer ? undefined : 512 })
      .backgroundColor(this.theme.colors.background)
      .border({
        width: this.drawer ? { top: 1 } : 1,
        color: this.theme.colors.border,
        radius: this.drawer ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusLg
      })
      .shadow(this.theme.shadows.lg.toOptions())
      // only takes effect when the panel touches the bottom edge (drawer mode)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .padding({ left: this.drawer ? 0 : 16, right: this.drawer ? 0 : 16 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}

@ComponentV2
export struct SDialogHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 8 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ right: 24 })
  }
}

/** Actions row; stacks vertically (primary on top) on compact width, like shadcn's `flex-col-reverse sm:flex-row`. */
@ComponentV2
export struct SDialogFooter {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

  build() {
    if (this.layout.compact) {
      Column({ space: 8 }) {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.End)
      .reverse(true)
    } else {
      Row({ space: 8 }) {
        this.content()
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
  }
}

@ComponentV2
export struct SDialogTitle {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.lg)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.theme.colors.foreground)
      .lineHeight(this.theme.text.lg)
  }
}

@ComponentV2
export struct SDialogDescription {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
  }
}
