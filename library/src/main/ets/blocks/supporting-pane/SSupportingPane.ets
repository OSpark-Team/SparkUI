import { sparkText } from '../../core/SparkText';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SButton } from '../../components/button/SButton';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { closeSparkOverlay, openSparkOverlay } from '../../primitives/overlay/SparkOverlayHost';
import { SparkOverlayScope, SparkOverlayService } from '../../primitives/overlay/SparkOverlay';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkSupportingDefaultPolicy, SparkSplitInput, SparkSplitPolicy } from '../BlocksLogic';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import {
  SparkSupportingPaneStyle, sparkSupportingPaneStyle, sparkSupportingPaneWidth, SupportingPaneTokens
} from '../BlockTokens';

const KEY: string = 'spark.supporting-pane';

/**
 * Where the supporting pane goes when the container is too narrow:
 * - 'below': stacked under the main content
 * - 'sheet': hidden; SSupportingPaneTrigger opens it as a bottom sheet
 */
export type SupportingCompactMode = 'below' | 'sheet';

/**
 * Shared state and controller of an SSupportingPane. Pass your own as `SSupportingPane({ controller })` to open the
 * sheet from anywhere, read `wide` / `inSheet`, or handle back (`controller.back()`).
 */
@ObservedV2
export class SparkSupportingPaneState {
  @Trace width: number = 0;
  @Trace wide: boolean = true;
  /** bottom sheet shown (narrow + 'sheet') */
  @Trace open: boolean = false;
  @Trace compactMode: SupportingCompactMode = 'below';
  @Trace paneWidth: number = 320;
  /** resolved look (SSupportingPane `tokens` → `--supporting-pane-*` tokens → recipe) */
  @Trace style: SparkSupportingPaneStyle | undefined = undefined;
  @Trace gap: number = 24;
  minMainWidth: number = 480;
  /** motion key of the sheet */
  motionKey: string = 'supporting-pane';
  policy: SparkSplitPolicy = sparkSupportingDefaultPolicy;
  controlled: boolean = false;
  emit: (open: boolean) => void = () => {
  };
  emitWide: (wide: boolean) => void = () => {
  };
  private listeners: ((open: boolean) => void)[] = [];

  get inSheet(): boolean {
    return !this.wide && this.compactMode === 'sheet';
  }

  get mainWidth(): number {
    return this.wide ? Math.max(0, this.width - this.paneWidth) : this.width;
  }

  measure(width: number): void {
    if (width !== this.width) {
      this.width = width;
    }
    this.relayout();
  }

  /** Re-run the split policy. */
  relayout(): void {
    const input: SparkSplitInput = {
      containerWidth: this.width,
      paneWidth: this.paneWidth,
      minOtherWidth: this.minMainWidth
    };
    const wide = this.policy(input);
    if (wide !== this.wide) {
      this.wide = wide;
      if (wide) {
        this.apply(false);
      }
      this.emitWide(wide);
    }
  }

  /** Back handling for a page's `onBackPress`: closes the sheet and returns true when it was open. */
  back(): boolean {
    if (this.open && this.inSheet) {
      this.setOpen(false);
      return true;
    }
    return false;
  }

  setOpen(open: boolean): void {
    if (open === this.open) {
      return;
    }
    if (!this.controlled) {
      this.apply(open);
    }
    this.emit(open);
  }

  apply(open: boolean): void {
    if (open === this.open) {
      return;
    }
    this.open = open;
    this.listeners.forEach((l: (o: boolean) => void) => l(open));
  }

  subscribe(fn: (open: boolean) => void): () => void {
    this.listeners.push(fn);
    return () => {
      this.listeners = this.listeners.filter((l: (o: boolean) => void) => l !== fn);
    };
  }
}

const FALLBACK: SparkSupportingPaneState = new SparkSupportingPaneState();

function resolveState(uiContext: UIContext, id: number): SparkSupportingPaneState | undefined {
  return SparkContext.resolve<SparkSupportingPaneState>(uiContext, id, KEY);
}

/**
 * Canonical "supporting pane" layout: main content plus a fixed-width side pane (details, filters,
 * related items). Side by side when the main area keeps `minMainWidth`; otherwise the pane moves below the
 * main content (`compactMode: 'below'`) or into a bottom sheet opened by SSupportingPaneTrigger ('sheet').
 *
 * ```
 * SSupportingPane({ compactMode: 'sheet' }) {
 *   SSupportingPaneMain() {
 *     SSupportingPaneTrigger({ text: 'Details' })      // only visible when the pane is in a sheet
 *     ...
 *   }
 *   SSupportingPaneAside({ title: 'Details' }) { ... }
 * }
 * ```
 * Panes take their natural height; put the block inside a scroller (SPage) for long content.
 * Extension points: `controller`, `layoutPolicy`, `onWideChange`, `motionKey`, `compactMode`.
 */
@ComponentV2
export struct SSupportingPane {
  /** your own state object (headless control); one is created when omitted */
  @Param controller: SparkSupportingPaneState | undefined = undefined;
  @Param compactMode: SupportingCompactMode = 'below';
  /** supporting pane width when side by side (vp, includes the gap); 0 = `--supporting-pane-width`, else 320 */
  @Param paneWidth: number = 0;
  /** per-instance look (ADR D13): instance → `--supporting-pane-*` tokens → recipe */
  @Param tokens: SupportingPaneTokens = {};
  /** the pane sits beside the main area only while the main area keeps this width (vp) */
  @Param minMainWidth: number = 480;
  /** sheet open state (narrow + 'sheet') */
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = false;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @Param motionKey: string = 'supporting-pane';
  /** side by side (true) or compact (false), from the measured width (replaceable) */
  @Event layoutPolicy: SparkSplitPolicy = sparkSupportingDefaultPolicy;
  @Event onWideChange: (wide: boolean) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkSupportingPaneState = new SparkSupportingPaneState();

  aboutToAppear(): void {
    if (this.controller !== undefined) {
      this.state = this.controller;
    }
    const s = this.state;
    s.controlled = this.open !== undefined;
    if (this.open !== undefined) {
      s.open = this.open;
    } else if (this.controller === undefined) {
      s.open = this.defaultOpen;
    }
    s.policy = (i: SparkSplitInput): boolean => this.layoutPolicy(i);
    s.emitWide = (w: boolean) => this.onWideChange(w);
    s.emit = (v: boolean) => {
      this.$open(v);
      this.onOpenChange(v);
    };
    this.syncConfig();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, s);
  }

  aboutToDisappear(): void {
    this.state.apply(false);
    SparkContext.revoke(this.getUniqueId());
  }

  @Computed
  get resolvedPaneWidth(): number {
    return sparkSupportingPaneWidth(this.theme, this.paneWidth);
  }

  @Computed
  get look(): SparkSupportingPaneStyle {
    return sparkSupportingPaneStyle(this.theme, this.tokens);
  }

  @Monitor('compactMode', 'resolvedPaneWidth', 'look', 'minMainWidth', 'motionKey')
  syncConfig(): void {
    this.state.motionKey = this.motionKey;
    this.state.compactMode = this.compactMode;
    this.state.paneWidth = this.resolvedPaneWidth;
    this.state.style = this.look;
    this.state.minMainWidth = this.minMainWidth;
    if (this.state.width > 0) {
      this.state.measure(this.state.width);
    }
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.state.apply(this.open);
    }
  }

  build() {
    Flex({
      direction: this.state.wide ? FlexDirection.Row : FlexDirection.Column,
      alignItems: ItemAlign.Start
    }) {
      this.content()
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => this.state.measure(Number(n.width)))
  }
}

@ComponentV2
export struct SSupportingPaneMain {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local ctx: SparkSupportingPaneState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveState(this.getUIContext(), this.getUniqueId());
    }
  }

  get s(): SparkSupportingPaneState {
    return this.ctx ?? FALLBACK;
  }

  build() {
    Column({ space: 16 }) {
      this.content()
    }
    .width(this.s.width > 0 && this.s.wide ? this.s.mainWidth : '100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** The supporting pane. Its `title` heads the pane (and the sheet when it is one). */
@ComponentV2
export struct SSupportingPaneAside {
  @Param title: ResourceStr | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkSupportingPaneState | undefined = undefined;
  private scope: SparkOverlayScope | undefined = undefined;
  private unsubscribe: () => void = () => {
  };

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = resolveState(this.getUIContext(), this.getUniqueId());
      this.ctx = ctx;
      if (ctx !== undefined) {
        this.unsubscribe = ctx.subscribe((open: boolean) => open ? this.show() : this.hide());
        if (ctx.open && ctx.inSheet) {
          this.show();
        }
      }
    }
  }

  aboutToDisappear(): void {
    this.unsubscribe();
    this.hide();
  }

  get s(): SparkSupportingPaneState {
    return this.ctx ?? FALLBACK;
  }

  @Computed
  get look(): SparkSupportingPaneStyle {
    return this.ctx?.style ?? sparkSupportingPaneStyle(this.theme);
  }

  private show(): void {
    if (this.scope !== undefined && SparkOverlayService.isOpen(this.scope)) {
      return;
    }
    const ctx = this.ctx;
    if (ctx === undefined || !ctx.inSheet) {
      return;
    }
    const scope = SparkOverlayService.createScope();
    scope.presentation = 'sheet-bottom';
    scope.motionKey = ctx.motionKey;
    scope.modal = true;
    scope.dismissOnOutside = true;
    scope.content = this.panel;
    scope.contextKey = KEY;
    scope.contextValue = ctx;
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

  @Builder
  heading() {
    if (this.title !== undefined) {
      Text(this.title)
        .fontSize(this.theme.text.base)
        .fontWeight(this.theme.text.weightSemibold)
        .fontColor(this.theme.colors.foreground)
    }
  }

  /** Bottom-sheet presentation (narrow + 'sheet'). */
  @LocalBuilder
  panel() {
    Column({ space: 12 }) {
      Row() {
        Column()
          .width(40)
          .height(4)
          .borderRadius(2)
          .backgroundColor(this.look.handleBackground)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Row() {
        Column() {
          this.heading()
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'x', label: sparkText(this.getUIContext(), $r('app.string.spark_close'), 'Close') })
          .onClick(() => this.ctx?.setOpen(false))
      }
      .width('100%')

      Scroll() {
        Column({ space: 16 }) {
          this.content()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .constraintSize({ maxHeight: SparkUI.layout.root.height * 0.7 })
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 16 + this.layout.env.safeArea.bottom })
    .backgroundColor(this.look.sheetBackground)
    .border({
      width: { top: this.theme.borderWidth },
      color: this.theme.colors.border,
      radius: { topLeft: this.look.sheetRadius, topRight: this.look.sheetRadius }
    })
    .shadow(SparkTokenOverride.shadowOptions(this.look.sheetShadow))
    .expandSafeArea([SafeAreaType.SYSTEM])
  }

  build() {
    if (this.s.inSheet) {
      Column()
        .width(0)
        .height(0)
    } else {
      Column({ space: 16 }) {
        this.heading()
        this.content()
      }
      .width(this.s.wide && this.s.width > 0 ? this.s.paneWidth : '100%')
      .alignItems(HorizontalAlign.Start)
      .padding(this.s.wide ? { left: this.s.gap } : { top: this.s.gap })
      .margin(this.s.wide ? { top: 0 } : { top: this.s.gap })
      .backgroundColor(this.look.background)
      .border({
        width: this.s.wide ? { left: this.look.dividerWidth } : { top: this.look.dividerWidth },
        color: this.look.dividerColor
      })
    }
  }
}

/** Opens the supporting pane's sheet; renders nothing unless the pane currently lives in a sheet. */
@ComponentV2
export struct SSupportingPaneTrigger {
  @Param text: ResourceStr = $r('app.string.spark_details');
  @Param icon: string = 'panel-right';
  @Local ctx: SparkSupportingPaneState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveState(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Stack() {
      if (this.ctx?.inSheet ?? false) {
        SButton({ text: this.text, icon: this.icon, variant: 'outline', sizing: 'sm' })
          .onClick(() => this.ctx?.setOpen(true))
      }
    }
  }
}
