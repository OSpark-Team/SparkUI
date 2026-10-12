import { sparkTextOf } from '../../core/SparkText';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SButton } from '../../components/button/SButton';
import { SEmpty, SEmptyDescription, SEmptyHeader, SEmptyMedia, SEmptyTitle } from '../../components/empty/SEmpty';
import { SparkTopbarAction } from '../topbar/STopbar';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkListDetailDefaultPolicy, sparkListPaneWidth, SparkSplitInput, SparkSplitPolicy } from '../BlocksLogic';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { ListDetailTokens, SparkListDetailStyle, sparkListDetailStyle, sparkListWidth } from '../BlockTokens';

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
  /** resolved look (SListDetail `tokens` → `--list-detail-*` tokens → recipe), read by both panes */
  @Trace style: SparkListDetailStyle | undefined = undefined;
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
 * `onWideChange`, `motionKey`; SListDetailPane `onBack` (intercept), title-bar `actions` + `onAction` and a
 * `headerBuilder` region (`wrapBuilder(globalBuilder)`), `empty` + `emptyIcon` / `emptyTitle` /
 * `emptyDescription` (or branch inside the trailing closure for a custom empty state).
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
  /** list pane width when side by side (vp); 0 = the `--list-detail-list-width` token, else 320 */
  @Param listWidth: number = 0;
  /** per-instance look (ADR D13): instance → `--list-detail-*` tokens → recipe */
  @Param tokens: ListDetailTokens = {};
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
    s.listWidth = this.resolvedListWidth;
    s.style = this.look;
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

  @Computed
  get resolvedListWidth(): number {
    return sparkListWidth(this.theme, this.listWidth);
  }

  @Computed
  get look(): SparkListDetailStyle {
    return sparkListDetailStyle(this.theme, this.tokens);
  }

  @Monitor('resolvedListWidth', 'look', 'minDetailWidth', 'motionKey')
  syncConfig(): void {
    this.state.listWidth = this.resolvedListWidth;
    this.state.style = this.look;
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

  @Computed
  get look(): SparkListDetailStyle {
    return this.ctx?.style ?? sparkListDetailStyle(this.theme);
  }

  @Computed
  get paneBackground(): string {
    return this.look.listBackground;
  }

  build() {
    Column() {
      this.content()
    }
    .width(this.s.width > 0 ? this.s.listPaneWidth : '100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.paneBackground)
    .border({ width: { right: this.s.wide ? 1 : 0 }, color: this.look.dividerColor })
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
  @Param backLabel: ResourceStr = $r('app.string.spark_back');
  /** back button pressed; return true when handled (e.g. pop your own stack) to skip the default pop */
  @Event onBack: () => boolean = () => false;
  /**
   * Nothing selected: show the empty state (`emptyIcon` / `emptyTitle` / `emptyDescription`, an SEmpty) instead
   * of the content. For a custom empty state leave this false and branch inside the trailing closure.
   */
  @Param empty: boolean = false;
  /** lucide icon of the empty state */
  @Param emptyIcon: string = 'inbox';
  @Param emptyTitle: ResourceStr = $r('app.string.spark_nothing_selected');
  @Param emptyDescription: ResourceStr | undefined = undefined;
  /** icon buttons at the trailing end of the title bar (`onAction(id)`) */
  @Param actions: SparkTopbarAction[] = [];
  @Event onAction: (id: string) => void = () => {
  };
  /**
   * Custom trailing title-bar content after `actions`, as `wrapBuilder(myHeader)` of a global `@Builder`
   * (no `this`: render a component or read shared state).
   */
  @Param headerBuilder: WrappedBuilder<[]> | undefined = undefined;
  /** the detail — the trailing closure (the component's only @BuilderParam) */
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

  @Computed
  get look(): SparkListDetailStyle {
    return this.ctx?.style ?? sparkListDetailStyle(this.theme);
  }

  @Computed
  get paneBackground(): string {
    return this.look.detailBackground;
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
      if ((!this.s.wide && this.showBack) || this.title !== undefined || this.actions.length > 0 ||
        this.headerBuilder !== undefined) {
        Row({ space: 8 }) {
          if (!this.s.wide && this.showBack) {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'arrow-left', label: sparkTextOf(this.getUIContext(), this.backLabel, 'Back') })
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
          ForEach(this.actions, (a: SparkTopbarAction) => {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: a.icon, label: a.label })
              .onClick(() => this.onAction(a.id))
          }, (a: SparkTopbarAction) => a.id + a.icon)
          if (this.headerBuilder !== undefined) {
            this.headerBuilder.builder()
          }
        }
        .width('100%')
        .height(this.look.headerHeight)
        .padding({ left: this.s.wide ? 16 : 8, right: 16 })
        .border({ width: { bottom: 1 }, color: this.look.dividerColor })
      }
      Column() {
        if (this.empty) {
          Column() {
            SEmpty() {
              SEmptyHeader() {
                SEmptyMedia({ icon: this.emptyIcon, variant: 'icon' })
                SEmptyTitle({ text: this.emptyTitle })
                if (this.emptyDescription !== undefined) {
                  SEmptyDescription({ text: this.emptyDescription })
                }
              }
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
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
    .backgroundColor(this.paneBackground)
    .translate({ x: this.s.width > 0 ? this.offsetX() : 0 })
    .shadow(this.s.detailOnTop ? SparkTokenOverride.shadowOptions(this.look.detailShadow) :
      { radius: 0, color: '#00000000' })
    // hidden until measured, so it never covers the list on the first frame
    .visibility(this.s.width > 0 ? Visibility.Visible : Visibility.Hidden)
    .focusable(this.s.wide || this.s.showDetail)
    .clip(true)
  }
}
