import { sparkText, sparkTextOf } from '../../core/SparkText';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SButton } from '../../components/button/SButton';
import { SInput } from '../../components/input/SInput';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkTopbarStyle, sparkTopbarStyle, TopbarTokens } from '../BlockTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkTopbarCondensed, sparkTopbarHeight, TOPBAR_CONDENSED_BELOW } from '../BlocksLogic';
import { resolveSparkSidebar, SparkSidebarState, SSidebarTrigger } from '../sidebar/SSidebar';

/**
 * What the top bar shows before the title:
 * - 'auto': a sidebar trigger when inside an SSidebarProvider whose sidebar can collapse / is a sheet
 * - 'trigger': always the sidebar trigger
 * - 'back': a back arrow (fires `onBack`)
 * - 'none'
 */
export type TopbarLeading = 'auto' | 'trigger' | 'back' | 'none';

/** An icon action button on the trailing edge of the top bar. */
export class SparkTopbarAction {
  id: string;
  /** lucide icon name */
  icon: string;
  /** accessible name */
  label: string;

  constructor(id: string, icon: string, label: string) {
    this.id = id;
    this.icon = icon;
    this.label = label;
  }
}

/**
 * App header (shadcn "site header" block): leading control, title / subtitle, optional search, icon actions
 * and a trailing slot. Breakpoint-free: below ~520 vp of its own width it condenses (48 vp tall, subtitle
 * hidden, search behind an icon that expands over the title).
 *
 * ```
 * STopbar({ title: 'Inbox', search: true, actions: [new SparkTopbarAction('new', 'plus', 'New')],
 *   onAction: (id: string) => ... }) {
 *   SButton({ text: 'Share', sizing: 'sm', variant: 'outline' })    // optional trailing slot
 * }
 * ```
 * It stays at the top because it lives outside the scrolling content (SAppShell / SSidebarInset). With
 * `translucent` the background is translucent + backdrop-blurred, for content that scrolls underneath (SAppShell
 * does that). `safeArea` adds the status-bar inset for immersive pages (skipped automatically inside a framed
 * 'inset' sidebar layout, whose card already clears it).
 *
 * Extension points: the trailing closure (after `actions`); `leadingBuilder` / `titleBuilder` regions as
 * `WrappedBuilder`s (`titleBuilder: wrapBuilder(myGlobalBuilder)`; additive — set `leading: 'none'` or an empty
 * `title` to replace the built-ins), `condenseBelow` and `barHeight` instead of fixed metrics, `onBack`
 * for any back handling (no routing built in). Inside an SSidebarProvider, `leading: 'auto'` follows the
 * sidebar controller (`toggleable`).
 */
@ComponentV2
export struct STopbar {
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr | undefined = undefined;
  @Param leading: TopbarLeading = 'auto';
  @Event onBack: () => void = () => {
  };
  @Param actions: SparkTopbarAction[] = [];
  @Event onAction: (id: string) => void = () => {
  };
  /** show a search field (an icon that expands when condensed) */
  @Param search: boolean = false;
  @Param searchPlaceholder: ResourceStr = $r('app.string.spark_search_placeholder');
  @Event onSearchChange: (value: string) => void = () => {
  };
  @Event onSearch: (value: string) => void = () => {
  };
  /** translucent, backdrop-blurred background */
  @Param translucent: boolean = false;
  @Param bordered: boolean = true;
  /** add the top safe-area inset (immersive pages) */
  @Param safeArea: boolean = false;
  /** condense below this width of the bar itself (vp) */
  @Param condenseBelow: number = TOPBAR_CONDENSED_BELOW;
  /** bar height without the safe-area inset (vp, 0 = `--topbar-height[-condensed]`, else 56 / 48 condensed) */
  @Param barHeight: number = 0;
  /**
   * Extra leading content after the built-in `leading` control (use `leading: 'none'` to replace it), as
   * `wrapBuilder(myLeading)` of a global `@Builder` (no `this`: render a component or read shared state).
   */
  @Param leadingBuilder: WrappedBuilder<[]> | undefined = undefined;
  /**
   * Extra title content under / instead of `title` (breadcrumbs, a switcher…; leave `title` empty to replace),
   * as `wrapBuilder(myTitle)` of a global `@Builder`.
   */
  @Param titleBuilder: WrappedBuilder<[]> | undefined = undefined;
  /** trailing slot after `actions` — the trailing closure (the component's only @BuilderParam) */
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  /** per-instance look (ADR D13): instance → `--topbar-*` tokens → recipe */
  @Param tokens: TopbarTokens = {};
  /** drive the leading trigger from this controller (e.g. a bar outside the SSidebarProvider) */
  @Param sidebarController: SparkSidebarState | undefined = undefined;
  @Local ctx: SparkSidebarState | undefined = undefined;
  @Local measuredWidth: number = 0;
  @Local searchOpen: boolean = false;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
    }
  }

  get sidebar(): SparkSidebarState | undefined {
    return this.sidebarController ?? this.ctx;
  }

  @Computed
  get condensed(): boolean {
    return sparkTopbarCondensed(this.measuredWidth, this.condenseBelow);
  }

  @Computed
  get look(): SparkTopbarStyle {
    return sparkTopbarStyle(this.theme, this.tokens);
  }

  @Computed
  get paddingX(): number {
    return this.condensed ? this.look.paddingXCondensed : this.look.paddingX;
  }

  @Computed
  get showTrigger(): boolean {
    if (this.leading === 'trigger') {
      return true;
    }
    return this.leading === 'auto' && (this.sidebar?.toggleable ?? false);
  }

  @Computed
  get titleEmpty(): boolean {
    return typeof this.title === 'string' && this.title.length === 0;
  }

  @Computed
  get topInset(): number {
    if (!this.safeArea || (this.sidebar?.insetFramed ?? false)) {
      return 0;
    }
    return this.layout.env.safeArea.top;
  }

  @Monitor('condensed')
  onCondensedChange(): void {
    if (!this.condensed) {
      this.searchOpen = false;
    }
  }

  @Builder
  searchField() {
    Row() {
      SInput({
        placeholder: this.searchPlaceholder,
        label: sparkTextOf(this.getUIContext(), this.searchPlaceholder, 'Search…'),
        onValueChange: (v: string) => this.onSearchChange(v),
        onSubmit: (v: string) => this.onSearch(v)
      })
    }
    .width('100%')
  }

  build() {
    Row({ space: 8 }) {
      if (this.condensed && this.searchOpen) {
        Row() {
          this.searchField()
        }
        .layoutWeight(1)

        SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'x', label: sparkText(this.getUIContext(), $r('app.string.spark_close_search'), 'Close search') })
          .onClick(() => {
            this.searchOpen = false;
          })
      } else {
        if (this.showTrigger) {
          SSidebarTrigger({ controller: this.sidebarController })
        } else if (this.leading === 'back') {
          SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'arrow-left', label: sparkText(this.getUIContext(), $r('app.string.spark_back'), 'Back') })
            .onClick(() => this.onBack())
        }
        if (this.leadingBuilder !== undefined) {
          this.leadingBuilder.builder()
        }
        if ((this.showTrigger || this.leading === 'back') && !this.condensed) {
          Column()
            .width(1)
            .height(16)
            .margin({ left: 4, right: 4 })
            .backgroundColor(this.look.borderColor)
        }
        Column({ space: 2 }) {
          if (!this.titleEmpty) {
            Text(this.title)
              .fontSize(this.condensed ? this.theme.text.sm : this.theme.text.base)
              .fontWeight(this.theme.text.weightSemibold)
              .fontColor(this.look.titleColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.subtitle !== undefined && !this.condensed) {
            Text(this.subtitle)
              .fontSize(this.theme.text.xs)
              .fontColor(this.look.subtitleColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.titleBuilder !== undefined) {
            this.titleBuilder.builder()
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.search) {
          if (this.condensed) {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'search', label: sparkTextOf(this.getUIContext(), this.searchPlaceholder, 'Search…') })
              .onClick(() => {
                this.searchOpen = true;
              })
          } else {
            Row() {
              this.searchField()
            }
            .width(Math.min(260, Math.max(160, this.measuredWidth * 0.3)))
          }
        }
        ForEach(this.actions, (a: SparkTopbarAction) => {
          SButton({ variant: 'ghost', sizing: 'icon-sm', icon: a.icon, label: a.label })
            .onClick(() => this.onAction(a.id))
        }, (a: SparkTopbarAction) => a.id + a.icon)
        this.content()
      }
    }
    .width('100%')
    .height((this.barHeight > 0 ? this.barHeight :
      sparkTopbarHeight(this.condensed, this.look.height, this.look.heightCondensed)) + this.topInset)
    .padding({ left: this.paddingX, right: this.paddingX, top: this.topInset })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.translucent ? this.look.translucentBackground : this.look.background)
    .backdropBlur(this.translucent ? this.look.translucentBlur : 0)
    .border({ width: { bottom: this.bordered ? this.look.borderWidth : 0 }, color: this.look.borderColor })
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
    })
  }
}
