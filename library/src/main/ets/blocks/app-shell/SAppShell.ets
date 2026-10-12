import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SAvatar } from '../../components/avatar/SAvatar';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { sparkGutter } from '../../layout/SparkLayouts';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SIDEBAR_WIDTH, SidebarCollapsible, SidebarPresentation, SidebarSide, SidebarVariant, sparkSidebarDefaultPolicy,
  SparkSidebarLayoutInput, SparkSidebarLayoutPolicy
} from '../BlocksLogic';
import {
  resolveSparkSidebar, SparkSidebarState, SSidebar, SSidebarContent, SSidebarFooter, SSidebarGroup,
  SSidebarGroupLabel, SSidebarHeader, SSidebarInset, SSidebarMenu, SSidebarMenuButton, SSidebarMenuItem,
  SSidebarProvider
} from '../sidebar/SSidebar';
import { SparkTopbarAction, STopbar, TopbarLeading } from '../topbar/STopbar';

/** One navigation entry of an SAppShell sidebar. */
export class SparkShellNavItem {
  id: string;
  title: string;
  /** lucide icon name */
  icon: string;
  badge: string | undefined;
  disabled: boolean;

  constructor(id: string, title: string, icon: string, badge?: string, disabled?: boolean) {
    this.id = id;
    this.title = title;
    this.icon = icon;
    this.badge = badge;
    this.disabled = disabled ?? false;
  }
}

/** A titled group of navigation entries (empty title = no label). */
export class SparkShellNavGroup {
  title: string;
  items: SparkShellNavItem[];

  constructor(title: string, items: SparkShellNavItem[]) {
    this.title = title;
    this.items = items;
  }
}

/** Signed-in user shown in the sidebar footer. */
export class SparkShellUser {
  name: string;
  detail: string;
  avatar: ResourceStr | undefined;

  constructor(name: string, detail: string, avatar?: ResourceStr) {
    this.name = name;
    this.detail = detail;
    this.avatar = avatar;
  }
}

/** Title of the nav item `id` ('' when not found). */
export function sparkShellNavTitle(nav: SparkShellNavGroup[], id: string): string {
  for (const g of nav) {
    for (const i of g.items) {
      if (i.id === id) {
        return i.title;
      }
    }
  }
  return '';
}

/** Title of the group containing the nav item `id` ('' when not found). */
export function sparkShellNavGroupTitle(nav: SparkShellNavGroup[], id: string): string {
  for (const g of nav) {
    for (const i of g.items) {
      if (i.id === id) {
        return g.title;
      }
    }
  }
  return '';
}

function initials(name: string): string {
  const parts = name.trim().split(' ').filter((p: string) => p.length > 0);
  if (parts.length === 0) {
    return '';
  }
  const a = parts[0].charAt(0);
  const b = parts.length > 1 ? parts[parts.length - 1].charAt(0) : '';
  return (a + b).toUpperCase();
}

/**
 * Default `navItemBuilder` of SAppShell: an SSidebarMenuButton bound to the item id. Write your own with the
 * same signature (a global `@Builder`, or an arrow that calls a `@LocalBuilder`) to render items differently;
 * SSidebarMenuButton's trailing slot, `isActive` and `sparkSidebarInSheet` cover most needs.
 */
@Builder
export function sparkShellNavItemBuilder(item: SparkShellNavItem) {
  SSidebarMenuButton({
    value: item.id,
    icon: item.icon,
    text: item.title,
    badge: item.badge,
    disabled: item.disabled
  })
}

/** Default `navGroupLabelBuilder` of SAppShell: an SSidebarGroupLabel (nothing for an empty title). */
@Builder
export function sparkShellNavGroupLabelBuilder(group: SparkShellNavGroup) {
  if (group.title.length > 0) {
    SSidebarGroupLabel({ text: group.title })
  }
}

@ComponentV2
struct ShellBrand {
  @Param brand: ResourceStr = '';
  @Param brandIcon: string = 'sparkles';
  @Param brandDetail: ResourceStr | undefined = undefined;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 8 }) {
      Row() {
        SIcon({ name: this.brandIcon, sizing: 16, color: this.theme.colors.sidebarPrimaryForeground })
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .borderRadius(this.theme.radiusMd)
      .backgroundColor(this.theme.colors.sidebarPrimary)

      Column({ space: 2 }) {
        Text(this.brand)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightSemibold)
          .fontColor(this.theme.colors.sidebarForeground)
          .maxLines(1)
        if (this.brandDetail !== undefined) {
          Text(this.brandDetail)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.sidebarForeground)
            .opacity(0.7)
            .maxLines(1)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(48)
    .clip(true)
  }
}

@ComponentV2
struct ShellUser {
  @Param user: SparkShellUser = new SparkShellUser('', '');
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 8 }) {
      SAvatar({ src: this.user.avatar, fallback: initials(this.user.name), sizing: 32, label: this.user.name })
      Column({ space: 2 }) {
        Text(this.user.name)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.sidebarForeground)
          .maxLines(1)
        Text(this.user.detail)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.sidebarForeground)
          .opacity(0.7)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(48)
    .clip(true)
    .accessibilityGroup(true)
  }
}

/** Main column of the shell: top bar + header slot + content (scrolling or fixed) + footer, safe-area aware. */
@ComponentV2
struct AppShellMain {
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr | undefined = undefined;
  @Param actions: SparkTopbarAction[] = [];
  @Event onAction: (id: string) => void = () => {
  };
  @Param search: boolean = false;
  @Param searchPlaceholder: string = 'Search…';
  @Event onSearch: (value: string) => void = () => {
  };
  @Event onSearchChange: (value: string) => void = () => {
  };
  @Param showTopbar: boolean = true;
  @Param topbarLeading: TopbarLeading = 'auto';
  @Param translucent: boolean = true;
  @Param safeArea: boolean = true;
  @Param scrollable: boolean = true;
  @Param footerText: ResourceStr | undefined = undefined;
  @Param maxContentWidth: number = 1200;
  /** scrolls back to the top when it changes (the active page) */
  @Param pageKey: string = '';
  @BuilderParam topbarLeadingBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam topbarTitleBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam topbarActionsBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam headerBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam footerBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkSidebarState | undefined = undefined;
  @Local barHeight: number = 56;
  @Local measuredWidth: number = 0;
  private scroller: Scroller = new Scroller();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
    }
  }

  @Monitor('pageKey')
  onPageChange(): void {
    if (this.scrollable) {
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    }
  }

  @Computed
  get bottomInset(): number {
    if (!this.safeArea || (this.ctx?.insetFramed ?? false)) {
      return 0;
    }
    return this.layout.env.safeArea.bottom;
  }

  /** The top bar floats over scrolling content (translucent) only in the scrolling layout. */
  @Computed
  get overlayBar(): boolean {
    return this.showTopbar && this.translucent && this.scrollable;
  }

  @Builder
  topbar() {
    if (this.showTopbar) {
      STopbar({
        title: this.title,
        subtitle: this.subtitle,
        leading: this.topbarLeading,
        actions: this.actions,
        onAction: (id: string) => this.onAction(id),
        search: this.search,
        searchPlaceholder: this.searchPlaceholder,
        onSearch: (v: string) => this.onSearch(v),
        onSearchChange: (v: string) => this.onSearchChange(v),
        translucent: this.translucent,
        safeArea: this.safeArea,
        leadingBuilder: (): void => {
          this.topbarLeadingBuilder()
        },
        titleBuilder: (): void => {
          this.topbarTitleBuilder()
        },
        // named, not a trailing closure: ArkTS rejects a trailing closure when other slots are passed
        content: (): void => {
          this.topbarActionsBuilder()
        }
      })
    }
    this.headerBuilder()
  }

  @Builder
  footer() {
    if (this.footerText !== undefined) {
      Text(this.footerText)
        .width('100%')
        .padding(16)
        .textAlign(TextAlign.Center)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
        .border({ width: { top: 1 }, color: this.theme.colors.border })
    }
    this.footerBuilder()
  }

  @Builder
  body() {
    Scroll(this.scroller) {
      Column() {
        Column() {
          this.content()
        }
        .width('100%')
        .constraintSize({ maxWidth: this.maxContentWidth > 0 ? this.maxContentWidth : undefined })
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: sparkGutter(this.measuredWidth),
          right: sparkGutter(this.measuredWidth),
          top: sparkGutter(this.measuredWidth),
          bottom: sparkGutter(this.measuredWidth) * 2
        })

        this.footer()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: this.overlayBar ? this.barHeight : 0, bottom: this.bottomInset })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
    })
  }

  build() {
    if (this.overlayBar) {
      // content scrolls underneath the translucent, blurred bar
      Stack({ alignContent: Alignment.Top }) {
        this.body()
        Column() {
          this.topbar()
        }
        .width('100%')
        .onAreaChange((_: Area, n: Area) => {
          this.barHeight = Number(n.height);
        })
      }
      .width('100%')
      .height('100%')
    } else {
      Column() {
        this.topbar()
        Column() {
          if (this.scrollable) {
            this.body()
          } else {
            // the page manages its own scrolling / panes (SListDetail, maps, editors…)
            this.content()
          }
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.scrollable) {
          this.footer()
          Column()
            .width('100%')
            .height(this.bottomInset)
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}

/**
 * Ready-made application shell, and a thin data-driven layer over SSidebarProvider / SSidebar /
 * SSidebarInset / STopbar: a sidebar (brand, grouped nav, user footer), a top bar (sidebar trigger, title of
 * the active page, search, actions) and the page content, with an optional footer.
 *
 * Breakpoint-free: `layoutPolicy` decides from the shell's own width whether the sidebar is docked, an icon
 * rail or a sheet (default: docked when it fits, else a sheet; `sparkSidebarRailPolicy()` adds a rail step).
 * Immersive-ready (`safeArea`, default on): the sidebar, top bar and content pad the window insets themselves
 * (ADR D10 — expandSafeArea cannot cross custom components).
 *
 * ```
 * SAppShell({ brand: 'Acme Inc', nav: NAV, value: this.page!!, user: ME,
 *   onNavigate: (id: string) => router.go(id) }) {      // every activation; no routing built in
 *   PageContent({ page: this.page })      // scrolls; padded and centred up to maxContentWidth
 * }
 * // with slots: ArkTS forbids a trailing closure next to other  args, so pass `content` by name
 * SAppShell({ nav: NAV, value: this.page!!, topbarActionsBuilder: this.themeToggle, content: this.page })
 * // (this.themeToggle / this.page being @LocalBuilder methods)
 * ```
 * Extension points (docs/design/blocks-extensibility.md): `controller` (own the SparkSidebarState),
 * `layoutPolicy`, every state change as an event, slots for each region (`titleBarBuilder`,
 * `sidebarHeaderBuilder`, `sidebarContentBuilder`, `sidebarFooterBuilder`, `navItemBuilder`,
 * `navGroupLabelBuilder`, `topbarLeadingBuilder`, `topbarTitleBuilder`, `topbarActionsBuilder`,
 * `headerBuilder`, `footerBuilder`), `showTopbar` / `scrollable` to opt out of the built-in bar and scroller.
 * Slots are additive to the data props (leave `brand` / `user` / `nav` empty to replace them). Pass slots as
 * global `@Builder`s, `@LocalBuilder`s or arrows, so `this` stays your component.
 * For anything further, compose SSidebarProvider / SSidebar / SSidebarInset / STopbar directly.
 */
@ComponentV2
export struct SAppShell {
  @Param brand: ResourceStr = '';
  @Param brandIcon: string = 'sparkles';
  @Param brandDetail: ResourceStr | undefined = undefined;
  @Param nav: SparkShellNavGroup[] = [];
  /** your own sidebar state object (headless control); one is created when omitted */
  @Param controller: SparkSidebarState | undefined = undefined;
  /** active nav item id */
  @Param value: string | undefined = undefined;
  @Event $value: (value: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (value: string) => void = () => {
  };
  /** every activation of a nav item, even the current one (router hook) */
  @Event onNavigate: (value: string) => void = () => {
  };
  /** top bar title (default: the active nav item's title) */
  @Param title: ResourceStr | undefined = undefined;
  @Param subtitle: ResourceStr | undefined = undefined;
  @Param actions: SparkTopbarAction[] = [];
  @Event onAction: (id: string) => void = () => {
  };
  @Param search: boolean = false;
  @Param searchPlaceholder: string = 'Search…';
  @Event onSearch: (value: string) => void = () => {
  };
  @Event onSearchChange: (value: string) => void = () => {
  };
  @Param user: SparkShellUser | undefined = undefined;
  @Param footerText: ResourceStr | undefined = undefined;
  @Param variant: SidebarVariant = 'sidebar';
  @Param collapsible: SidebarCollapsible = 'icon';
  @Param side: SidebarSide = 'left';
  @Param sidebarWidth: number = SIDEBAR_WIDTH;
  /** input of `layoutPolicy`: the content area should keep at least this width (vp) */
  @Param minInsetWidth: number = 360;
  @Param closeOnSelect: boolean = true;
  @Param motionKey: string = 'sidebar';
  @Event layoutPolicy: SparkSidebarLayoutPolicy = sparkSidebarDefaultPolicy;
  @Event onPresentationChange: (presentation: SidebarPresentation) => void = () => {
  };
  @Event onOpenMobileChange: (open: boolean) => void = () => {
  };
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  /** initial docked state; feed a persisted value here and save it in `onOpenChange` */
  @Param defaultOpen: boolean = true;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  /** show the built-in top bar (false: bring your own via `headerBuilder` or the content) */
  @Param showTopbar: boolean = true;
  /** top bar leading control: 'auto' (sidebar trigger), 'none' when e.g. a title bar already hosts it */
  @Param topbarLeading: TopbarLeading = 'auto';
  /** translucent top bar with content scrolling underneath */
  @Param topbarBlur: boolean = true;
  /** wrap the content in the padded, centred scroller (false: the content fills the area as is) */
  @Param scrollable: boolean = true;
  /** pad the window safe area (immersive pages) */
  @Param safeArea: boolean = true;
  /** max width of the page content (0 = unlimited) */
  @Param maxContentWidth: number = 1200;
  /** region above the whole shell, e.g. an STitleBar for free-form windows */
  @BuilderParam titleBarBuilder: () => void = sparkEmptyBuilder;
  /** under the brand in the sidebar header (team switcher, search…) */
  @BuilderParam sidebarHeaderBuilder: () => void = sparkEmptyBuilder;
  /** after the nav groups in the scrolling sidebar content */
  @BuilderParam sidebarContentBuilder: () => void = sparkEmptyBuilder;
  /** under the user in the sidebar footer */
  @BuilderParam sidebarFooterBuilder: () => void = sparkEmptyBuilder;
  /** renders one nav item (default: sparkShellNavItemBuilder) */
  @BuilderParam navItemBuilder: (item: SparkShellNavItem) => void = sparkShellNavItemBuilder;
  /** renders a group's label (default: sparkShellNavGroupLabelBuilder) */
  @BuilderParam navGroupLabelBuilder: (group: SparkShellNavGroup) => void = sparkShellNavGroupLabelBuilder;
  @BuilderParam topbarLeadingBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam topbarTitleBuilder: () => void = sparkEmptyBuilder;
  /** trailing top bar content (after `actions`) */
  @BuilderParam topbarActionsBuilder: () => void = sparkEmptyBuilder;
  /** under the top bar, above the content (tabs, filters…; also a custom bar with `showTopbar: false`) */
  @BuilderParam headerBuilder: () => void = sparkEmptyBuilder;
  /** after the content (after `footerText`) */
  @BuilderParam footerBuilder: () => void = sparkEmptyBuilder;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local own: SparkSidebarState = new SparkSidebarState();

  aboutToAppear(): void {
    if (this.controller === undefined) {
      this.own.open = this.open ?? this.defaultOpen;
      this.own.value = this.value ?? this.defaultValue;
    }
  }

  /** The sidebar controller in use (yours or the shell's own). */
  get sidebar(): SparkSidebarState {
    return this.controller ?? this.own;
  }

  @Computed
  get resolvedTitle(): ResourceStr {
    if (this.title !== undefined) {
      return this.title;
    }
    return sparkShellNavTitle(this.nav, this.sidebar.value);
  }

  @Computed
  get brandShown(): boolean {
    return typeof this.brand !== 'string' || this.brand.length > 0;
  }

  build() {
    Column() {
      this.titleBarBuilder()
      Column() {
        SSidebarProvider({
          controller: this.sidebar,
          variant: this.variant,
          collapsible: this.collapsible,
          side: this.side,
          sidebarWidth: this.sidebarWidth,
          minInsetWidth: this.minInsetWidth,
          closeOnSelect: this.closeOnSelect,
          motionKey: this.motionKey,
          layoutPolicy: (i: SparkSidebarLayoutInput): SidebarPresentation => this.layoutPolicy(i),
          onPresentationChange: (p: SidebarPresentation) => this.onPresentationChange(p),
          onOpenMobileChange: (o: boolean) => this.onOpenMobileChange(o),
          open: this.open,
          onOpenChange: (o: boolean) => {
            this.$open(o);
            this.onOpenChange(o);
          },
          value: this.value,
          onValueChange: (v: string) => {
            this.$value(v);
            this.onValueChange(v);
          },
          onNavigate: (v: string) => this.onNavigate(v),
          safeArea: this.safeArea
        }) {
          SSidebar() {
            SSidebarHeader() {
              if (this.brandShown) {
                ShellBrand({ brand: this.brand, brandIcon: this.brandIcon, brandDetail: this.brandDetail })
              }
              this.sidebarHeaderBuilder()
            }
            SSidebarContent() {
              ForEach(this.nav, (g: SparkShellNavGroup) => {
                SSidebarGroup() {
                  this.navGroupLabelBuilder(g)
                  SSidebarMenu() {
                    ForEach(g.items, (item: SparkShellNavItem) => {
                      SSidebarMenuItem() {
                        this.navItemBuilder(item)
                      }
                    }, (item: SparkShellNavItem) => item.id)
                  }
                }
              }, (g: SparkShellNavGroup, i: number) => `${i}:${g.title}`)
              this.sidebarContentBuilder()
            }
            SSidebarFooter() {
              if (this.user !== undefined) {
                ShellUser({ user: this.user })
              }
              this.sidebarFooterBuilder()
            }
          }
          SSidebarInset() {
            AppShellMain({
              title: this.resolvedTitle,
              subtitle: this.subtitle,
              actions: this.actions,
              onAction: (id: string) => this.onAction(id),
              search: this.search,
              searchPlaceholder: this.searchPlaceholder,
              onSearch: (v: string) => this.onSearch(v),
              onSearchChange: (v: string) => this.onSearchChange(v),
              showTopbar: this.showTopbar,
              topbarLeading: this.topbarLeading,
              translucent: this.topbarBlur,
              scrollable: this.scrollable,
              safeArea: this.safeArea,
              footerText: this.footerText,
              maxContentWidth: this.maxContentWidth,
              pageKey: this.sidebar.value,
              topbarLeadingBuilder: (): void => {
                this.topbarLeadingBuilder()
              },
              topbarTitleBuilder: (): void => {
                this.topbarTitleBuilder()
              },
              topbarActionsBuilder: (): void => {
                this.topbarActionsBuilder()
              },
              headerBuilder: (): void => {
                this.headerBuilder()
              },
              footerBuilder: (): void => {
                this.footerBuilder()
              },
              content: (): void => {
                this.content()
              }
            })
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
