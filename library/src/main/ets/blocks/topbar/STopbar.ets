import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SButton } from '../../components/button/SButton';
import { SInput } from '../../components/input/SInput';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkTopbarCondensed, sparkTopbarHeight } from '../BlocksLogic';
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
  @Param searchPlaceholder: string = 'Search…';
  @Event onSearchChange: (value: string) => void = () => {
  };
  @Event onSearch: (value: string) => void = () => {
  };
  /** translucent, backdrop-blurred background */
  @Param translucent: boolean = false;
  @Param bordered: boolean = true;
  /** add the top safe-area inset (immersive pages) */
  @Param safeArea: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
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

  @Computed
  get condensed(): boolean {
    return sparkTopbarCondensed(this.measuredWidth);
  }

  @Computed
  get showTrigger(): boolean {
    if (this.leading === 'trigger') {
      return true;
    }
    return this.leading === 'auto' && (this.ctx?.toggleable ?? false);
  }

  @Computed
  get topInset(): number {
    if (!this.safeArea || (this.ctx?.insetFramed ?? false)) {
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
        label: this.searchPlaceholder,
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

        SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'x', label: 'Close search' })
          .onClick(() => {
            this.searchOpen = false;
          })
      } else {
        if (this.showTrigger) {
          SSidebarTrigger()
        } else if (this.leading === 'back') {
          SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'arrow-left', label: 'Back' })
            .onClick(() => this.onBack())
        }
        if ((this.showTrigger || this.leading === 'back') && !this.condensed) {
          Column()
            .width(1)
            .height(16)
            .margin({ left: 4, right: 4 })
            .backgroundColor(this.theme.colors.border)
        }
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(this.condensed ? this.theme.text.sm : this.theme.text.base)
            .fontWeight(this.theme.text.weightSemibold)
            .fontColor(this.theme.colors.foreground)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.subtitle !== undefined && !this.condensed) {
            Text(this.subtitle)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.search) {
          if (this.condensed) {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'search', label: this.searchPlaceholder })
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
    .height(sparkTopbarHeight(this.condensed) + this.topInset)
    .padding({ left: this.condensed ? 8 : 16, right: this.condensed ? 8 : 16, top: this.topInset })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.translucent ? SparkColor.alpha(this.theme.colors.background, 0.8) :
      this.theme.colors.background)
    .backdropBlur(this.translucent ? 20 : 0)
    .border({ width: { bottom: this.bordered ? 1 : 0 }, color: this.theme.colors.border })
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
    })
  }
}
