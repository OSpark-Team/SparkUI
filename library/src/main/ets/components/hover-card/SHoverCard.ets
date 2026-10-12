import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkAlign, SparkSide } from '../../primitives/overlay/Placement';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.hovercard';

/** Open state plus hover-intent timers. */
@ObservedV2
export class SparkHoverCardState {
  readonly disclosure: SparkDisclosure = new SparkDisclosure();
  openDelay: number = 700;
  closeDelay: number = 300;
  /** how the card was opened: 'hover' (pointer, pass-through layer) or 'tap' (touch, tap outside closes) */
  via: 'hover' | 'tap' = 'hover';
  private openTimer: number = -1;
  private closeTimer: number = -1;

  /** pointer entered the trigger */
  enterTrigger(): void {
    clearTimeout(this.closeTimer);
    if (this.disclosure.open) {
      return;
    }
    clearTimeout(this.openTimer);
    this.openTimer = setTimeout(() => {
      this.via = 'hover';
      this.disclosure.setOpen(true);
    }, this.openDelay);
  }

  /** pointer entered the card: keep it open */
  enterContent(): void {
    clearTimeout(this.closeTimer);
  }

  /** pointer left the trigger or the card */
  leave(): void {
    clearTimeout(this.openTimer);
    if (!this.disclosure.open || this.via !== 'hover') {
      return;
    }
    clearTimeout(this.closeTimer);
    this.closeTimer = setTimeout(() => this.disclosure.setOpen(false), this.closeDelay);
  }

  /** touch: tap toggles, like a Popover */
  tap(): void {
    clearTimeout(this.openTimer);
    clearTimeout(this.closeTimer);
    this.via = 'tap';
    this.disclosure.toggle();
  }

  dispose(): void {
    clearTimeout(this.openTimer);
    clearTimeout(this.closeTimer);
  }
}

/**
 * shadcn-vue `HoverCard`: preview content behind a link.
 * - pointer: opens after hovering the trigger for `openDelay` ms, closes `closeDelay` ms after the pointer
 *   leaves both the trigger and the card (moving onto the card keeps it open)
 * - touch: tapping the trigger toggles it (tap outside closes), like a Popover
 *
 * ```
 * SHoverCard() {
 *   SHoverCardTrigger() { SButton({ text: '@nextjs', variant: 'link' }) }
 *   SHoverCardContent() {
 *     Row({ space: 16 }) { SAvatar(...) Column() { Text('@nextjs') ... } }
 *   }
 * }
 * ```
 */
@ComponentV2
export struct SHoverCard {
  @Param openDelay: number = 700;
  @Param closeDelay: number = 300;
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = false;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkHoverCardState = new SparkHoverCardState();

  aboutToAppear(): void {
    this.state.openDelay = this.openDelay;
    this.state.closeDelay = this.closeDelay;
    this.state.disclosure.controlled = this.open !== undefined;
    this.state.disclosure.open = this.open ?? this.defaultOpen;
    this.state.disclosure.emit = (v: boolean) => {
      this.$open(v);
      this.onOpenChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    this.state.dispose();
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.state.disclosure.assign(this.open);
    }
  }

  @Monitor('openDelay', 'closeDelay')
  syncDelays(): void {
    this.state.openDelay = this.openDelay;
    this.state.closeDelay = this.closeDelay;
  }

  build() {
    Stack() {
      this.content()
    }
  }
}

/** Hover (pointer) or tap (touch) target; its bounds are the anchor. */
@ComponentV2
export struct SHoverCardTrigger {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkHoverCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkHoverCardState>(this.getUIContext(), this.getUniqueId(), KEY);
      if (this.state !== undefined) {
        this.state.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
        this.state.disclosure.triggerUniqueId = this.getUniqueId();
      }
    }
  }

  build() {
    Stack() {
      this.content()
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .onHover((isHover: boolean) => {
      SparkUI.layout.reportPointerEvent(true);
      if (isHover) {
        this.state?.enterTrigger();
      } else {
        this.state?.leave();
      }
    })
    .onClick((e: ClickEvent) => {
      // mouse clicks follow the link / button underneath; hover already shows the card
      if (e.source !== SourceType.Mouse) {
        this.state?.tap();
      }
    })
  }
}

/** Anchored card: `bg-popover w-64 rounded-md border p-4 shadow-md`. */
@ComponentV2
export struct SHoverCardContent {
  @Param side: SparkSide = 'bottom';
  @Param alignment: SparkAlign = 'center';
  @Param sideOffset: number = 4;
  /** card width in vp (shadcn w-64 = 256) */
  @Param panelWidth: number = 256;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local state: SparkHoverCardState | undefined = undefined;
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      const state = SparkContext.resolve<SparkHoverCardState>(this.getUIContext(), this.getUniqueId(), KEY);
      this.state = state;
      if (state !== undefined) {
        this.binding.attach(this.getUIContext(), state.disclosure, (scope: SparkOverlayScope) => {
          const hover = state.via === 'hover';
          scope.presentation = 'anchored';
          scope.motionKey = 'popover';
          scope.modal = false;
          // hover: the page keeps receiving the pointer (leaving the trigger is what closes the card)
          scope.passThrough = hover;
          scope.focusable = !hover;
          scope.dismissOnOutside = !hover;
          scope.restoreFocusId = hover ? '' : state.disclosure.triggerKey;
          scope.anchor = state.disclosure.anchorRect(this.getUIContext());
          scope.side = this.side;
          scope.alignment = this.alignment;
          scope.sideOffset = this.sideOffset;
          scope.content = this.panel;
          scope.contextKey = KEY;
          scope.contextValue = state;
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
      this.content()
    }
    .width(this.panelWidth)
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(this.theme.colors.popover)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
    .shadow(this.theme.shadows.md.toOptions())
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.state?.enterContent();
      } else {
        this.state?.leave();
      }
    })
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
