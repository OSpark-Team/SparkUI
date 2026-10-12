import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SButton } from '../../components/button/SButton';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkListDetailWide, sparkListPaneWidth } from '../BlocksLogic';

const KEY: string = 'spark.list-detail';

/** Shared state of an SListDetail (master / detail). */
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
  controlled: boolean = false;
  emit: (show: boolean) => void = () => {
  };

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
    const wide = sparkListDetailWide(width, this.listWidth, this.minDetailWidth);
    if (wide !== this.wide) {
      this.wide = wide;
    }
  }

  /** Request showing / hiding the detail (push / pop when narrow). */
  setShowDetail(ctx: UIContext, theme: SparkTheme, show: boolean): void {
    if (show === this.showDetail) {
      return;
    }
    if (!this.controlled) {
      this.apply(ctx, theme, show);
    }
    this.emit(show);
  }

  apply(ctx: UIContext, theme: SparkTheme, show: boolean): void {
    if (show === this.showDetail) {
      return;
    }
    if (this.wide) {
      // nothing moves when side by side
      SparkAnim.commit(() => {
        this.showDetail = show;
      });
      return;
    }
    SparkAnim.run(ctx, theme, 'list-detail', 'normal', () => {
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
 * Narrow + detail shown: wire the page's `onBackPress` to `showDetail = false` for the system back gesture.
 */
@ComponentV2
export struct SListDetail {
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
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkListDetailState = new SparkListDetailState();

  aboutToAppear(): void {
    this.state.controlled = this.showDetail !== undefined;
    this.state.showDetail = this.showDetail ?? this.defaultShowDetail;
    this.state.listWidth = this.listWidth;
    this.state.minDetailWidth = this.minDetailWidth;
    this.state.emit = (v: boolean) => {
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
      this.state.apply(this.getUIContext(), this.theme, this.showDetail);
    }
  }

  @Monitor('listWidth', 'minDetailWidth')
  syncConfig(): void {
    this.state.listWidth = this.listWidth;
    this.state.minDetailWidth = this.minDetailWidth;
    this.state.measure(this.state.width);
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
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'arrow-left', label: 'Back' })
              .onClick(() => this.ctx?.setShowDetail(this.getUIContext(), this.theme, false))
          }
          if (this.title !== undefined) {
            Text(this.title)
              .layoutWeight(1)
              .fontSize(this.theme.text.sm)
              .fontWeight(this.theme.text.weightSemibold)
              .fontColor(this.theme.colors.foreground)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: this.s.wide ? 16 : 8, right: 16 })
        .border({ width: { bottom: 1 }, color: this.theme.colors.border })
      }
      Column() {
        this.content()
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
