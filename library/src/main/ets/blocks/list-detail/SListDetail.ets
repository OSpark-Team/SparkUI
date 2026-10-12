import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SButton } from '../../components/button/SButton';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkListDetailDefaultPolicy, sparkListPaneWidth, SparkSplitInput, SparkSplitPolicy } from '../BlocksLogic';

const KEY: string = 'spark.list-detail';

/**
 * Shared state and controller of an SListDetail (master / detail). Pass your own as `SListDetail({ controller })`
 * to drive it from outside (e.g. `onBackPress() { return this.ld.back(); }`) and to read `wide` / `showDetail`.
 */
@ObservedV2
export class SparkListDetailState {
  /** measured container width (vp) */
  @Trace width: number = 0;
  /** list and detail side by side */
  @Trace wide: boolean = false;
  /** the detail is the visible pane when narrow */
  @Trace showDetail: boolean = false;
  @Trace listWidth: number = 320;
  minDetailWidth: number = 360;
  /** motion key of the push / pop slide */
  motionKey: string = 'list-detail';
  policy: SparkSplitPolicy = sparkListDetailDefaultPolicy;
  controlled: boolean = false;
  emit: (show: boolean) => void = () => {
  };
  emitWide: (wide: boolean) => void = () => {
  };
  private uiContext: UIContext | undefined = undefined;
  private theme: SparkTheme = SparkUI.theme;

  /** Bind the UI context / theme used for animations (SListDetail does this). */
  attach(uiContext: UIContext, theme: SparkTheme): void {
    this.uiContext = uiContext;
    this.theme = theme;
  }

  get listPaneWidth(): number {
    return sparkListPaneWidth(this.width, this.listWidth, this.wide);
  }

  get detailPaneWidth(): number {
    return this.wide ? Math.max(0, this.width - this.listPaneWidth - 1) : this.width;
  }

  /** Narrow and the detail is pushed in. */
  get detailOnTop(): boolean {
    return !this.wide && this.showDetail;
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
      paneWidth: this.listWidth,
      minOtherWidth: this.minDetailWidth
    };
    const wide = this.policy(input);
    if (wide !== this.wide) {
      this.wide = wide;
      this.emitWide(wide);
    }
  }

  /** Request showing / hiding the detail (push / pop when narrow). */
  setShowDetail(show: boolean): void {
    if (show === this.showDetail) {
      return;
    }
    if (!this.controlled) {
      this.apply(show);
    }
    this.emit(show);
  }

  /**
   * Back handling for a page's `onBackPress`: pops the detail when it covers the list (narrow) and returns
   * true; false when there is nothing to pop.
   */
  back(): boolean {
    if (this.detailOnTop) {
      this.setShowDetail(false);
      return true;
    }
    return false;
  }

  /** Set the detail visibility (animated when narrow), without events. */
  apply(show: boolean): void {
    if (show === this.showDetail) {
      return;
    }
    const ctx = this.uiContext;
    if (this.wide || ctx === undefined) {
      // nothing moves when side by side
      SparkAnim.commit(() => {
        this.showDetail = show;
      });
      return;
    }
    SparkAnim.run(ctx, this.theme, this.motionKey, 'normal', () => {
      this.showDetail = show;
    });
  }
}

const FALLBACK: SparkListDetailState = new SparkListDetailState();

/**
 * Canonical list-detail layout (Material "list-detail", iPad split view) — no routing involved.
 * Side by side when the container fits `listWidth + minDetailWidth`; otherwise a single pane where the detail
 * is pushed over the list (slide, motion key 'list-detail') and SListDetailPane shows a back button.
 * Both panes stay mounted, so the list keeps its scroll position.
 *
 * ```
 * SListDetail({ showDetail: this.open!! }) {
 *   SListPane() { ForEach(mails, (m) => Row() {...}.onClick(() => { this.mail = m; this.open = true; })) }
 *   SListDetailPane({ title: this.mail.subject }) { MailView({ mail: this.mail }) }
 * }
 * ```
 * Narrow + detail shown: wire the page's `onBackPress` to `showDetail = false` (or `controller.back()`) for the
 * system back gesture.
 *
 * Extension points: `controller` (own the state), `layoutPolicy` (replace the side-by-side decision),
 * `onWideChange`, `motionKey`; SListDetailPane `onBack` (intercept), `headerBuilder`, `empty` + `emptyBuilder`.
 */
@ComponentV2
export struct SListDetail {
  /** your own state object (headless control); one is created when omitted */
  @Param controller: SparkListDetailState | undefined = undefined;
  @Param showDetail: boolean | undefined = undefined;
  @Event $showDetail: (show: boolean) => void = () => {
  };
  @Param defaultShowDetail: boolean = false;
  @Event onShowDetailChange: (show: boolean) => void = () => {
  };
  /** list pane width when side by side (vp) */
  @Param listWidth: number = 320;
  /** the detail needs at least this width to sit next to the list (vp) */
  @Param minDetailWidth: number = 360;
  @Param motionKey: string = 'list-detail';
  /** side by side (true) or one pane (false), from the measured width (replaceable) */
  @Event layoutPolicy: SparkSplitPolicy = sparkListDetailDefaultPolicy;
  /** the layout switched between side by side and one pane */
  @Event onWideChange: (wide: boolean) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkListDetailState = new SparkListDetailState();

  aboutToAppear(): void {
    if (this.controller !== undefined) {
      this.state = this.controller;
    }
    const s = this.state;
    s.attach(this.getUIContext(), this.theme);
    s.controlled = this.showDetail !== undefined;
    if (this.showDetail !== undefined) {
      s.showDetail = this.showDetail;
    } else if (this.controller === undefined) {
      s.showDetail = this.defaultShowDetail;
    }
    s.listWidth = this.listWidth;
    s.minDetailWidth = this.minDetailWidth;
    s.motionKey = this.motionKey;
    s.policy = (i: SparkSplitInput): boolean => this.layoutPolicy(i);
    s.emitWide = (w: boolean) => this.onWideChange(w);
    s.emit = (v: boolean) => {
      this.$showDetail(v);
      this.onShowDetailChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('showDetail')
  syncShow(): void {
    if (this.showDetail !== undefined) {
      this.state.apply(this.showDetail);
    }
  }

  @Monitor('listWidth', 'minDetailWidth', 'motionKey')
  syncConfig(): void {
    this.state.listWidth = this.listWidth;
    this.state.minDetailWidth = this.minDetailWidth;
    this.state.motionKey = this.motionKey;
    this.state.relayout();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.content()
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onAreaChange((_: Area, n: Area) => this.state.measure(Number(n.width)))
  }
}

/** The list (master) pane. */
@ComponentV2
export struct SListPane {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkListDetailState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkListDetailState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  get s(): SparkListDetailState {
    return this.ctx ?? FALLBACK;
  }

  build() {
    Column() {
      this.content()
    }
    .width(this.s.width > 0 ? this.s.listPaneWidth : '100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.colors.background)
    .border({ width: { right: this.s.wide ? 1 : 0 }, color: this.theme.colors.border })
    // parallax while the detail is pushed over it (narrow only)
    .translate({ x: this.s.detailOnTop ? -this.s.width * 0.25 : 0 })
    .opacity(this.s.detailOnTop ? 0.6 : 1)
    .focusable(!this.s.detailOnTop)
    .clip(true)
  }
}

/**
 * The detail pane. Side by side it fills the rest of the width (with an optional title bar); narrow it slides
 * over the list and its title bar gets a back button that pops back to the list.
 */
@ComponentV2
export struct SListDetailPane {
  @Param title: ResourceStr | undefined = undefined;
  /** show the back / title bar when narrow (default) */
  @Param showBack: boolean = true;
  @Param backLabel: string = 'Back';
  /** back button pressed; return true when handled (e.g. pop your own stack) to skip the default pop */
  @Event onBack: () => boolean = () => false;
  /** nothing selected: render `emptyBuilder` instead of the content */
  @Param empty: boolean = false;
  @BuilderParam emptyBuilder: () => void = sparkEmptyBuilder;
  /** trailing content of the title bar (actions) */
  @BuilderParam headerBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkListDetailState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkListDetailState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  get s(): SparkListDetailState {
    return this.ctx ?? FALLBACK;
  }

  private goBack(): void {
    if (!this.onBack()) {
      this.ctx?.setShowDetail(false);
    }
  }

  private offsetX(): number {
    const s = this.s;
    if (s.wide) {
      return s.listPaneWidth + 1;
    }
    return s.showDetail ? 0 : s.width;
  }

  build() {
    Column() {
      if ((!this.s.wide && this.showBack) || this.title !== undefined) {
        Row({ space: 8 }) {
          if (!this.s.wide && this.showBack) {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'arrow-left', label: this.backLabel })
              .onClick(() => this.goBack())
          }
          if (this.title !== undefined) {
            Text(this.title)
              .layoutWeight(1)
              .fontSize(this.theme.text.sm)
              .fontWeight(this.theme.text.weightSemibold)
              .fontColor(this.theme.colors.foreground)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Blank()
          }
          this.headerBuilder()
        }
        .width('100%')
        .height(48)
        .padding({ left: this.s.wide ? 16 : 8, right: 16 })
        .border({ width: { bottom: 1 }, color: this.theme.colors.border })
      }
      Column() {
        if (this.empty) {
          this.emptyBuilder()
        } else {
          this.content()
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width(this.s.width > 0 ? this.s.detailPaneWidth : '100%')
    .height('100%')
    .backgroundColor(this.theme.colors.background)
    .translate({ x: this.s.width > 0 ? this.offsetX() : 0 })
    .shadow(this.s.detailOnTop ? this.theme.shadows.lg.toOptions() : { radius: 0, color: '#00000000' })
    // hidden until measured, so it never covers the list on the first frame
    .visibility(this.s.width > 0 ? Visibility.Visible : Visibility.Hidden)
    .focusable(this.s.wide || this.s.showDetail)
    .clip(true)
  }
}
