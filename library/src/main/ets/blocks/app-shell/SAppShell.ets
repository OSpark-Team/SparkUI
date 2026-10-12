import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SAvatar } from '../../components/avatar/SAvatar';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { sparkGutter } from '../../layout/SparkLayouts';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SidebarCollapsible, SidebarSide, SidebarVariant } from '../BlocksLogic';
import {
  resolveSparkSidebar, SparkSidebarState, SSidebar, SSidebarContent, SSidebarFooter, SSidebarGroup,
  SSidebarGroupLabel, SSidebarHeader, SSidebarInset, SSidebarMenu, SSidebarMenuButton, SSidebarMenuItem,
  SSidebarProvider
} from '../sidebar/SSidebar';
import { SparkTopbarAction, STopbar } from '../topbar/STopbar';

/** One navigation entry of an SAppShell sidebar. */
export class SparkShellNavItem {
  id: string;
  title: string;
  /** lucide icon name */
  icon: string;
  badge: string | undefined;

  constructor(id: string, title: string, icon: string, badge?: string) {
    this.id = id;
    this.title = title;
    this.icon = icon;
    this.badge = badge;
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

function initials(name: string): string {
  const parts = name.trim().split(' ').filter((p: string) => p.length > 0);
  if (parts.length === 0) {
    return '';
  }
  const a = parts[0].charAt(0);
  const b = parts.length > 1 ? parts[parts.length - 1].charAt(0) : '';
  return (a + b).toUpperCase();
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

/** Main column of the shell: top bar + scrolling content (+ footer), safe-area aware. */
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
  @Param translucent: boolean = true;
  @Param safeArea: boolean = true;
  @Param footerText: ResourceStr | undefined = undefined;
  @Param maxContentWidth: number = 1200;
  /** scrolls back to the top when it changes (the active page) */
  @Param pageKey: string = '';
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
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  @Computed
  get bottomInset(): number {
    if (!this.safeArea || (this.ctx?.insetFramed ?? false)) {
      return 0;
    }
    return this.layout.env.safeArea.bottom;
  }

  @Builder
  topbar() {
    STopbar({
      title: this.title,
      subtitle: this.subtitle,
      actions: this.actions,
      onAction: (id: string) => this.onAction(id),
      search: this.search,
      searchPlaceholder: this.searchPlaceholder,
      onSearch: (v: string) => this.onSearch(v),
      onSearchChange: (v: string) => this.onSearchChange(v),
      translucent: this.translucent,
      safeArea: this.safeArea
    })
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

        if (this.footerText !== undefined) {
          Text(this.footerText)
            .width('100%')
            .padding(16)
            .textAlign(TextAlign.Center)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
            .border({ width: { top: 1 }, color: this.theme.colors.border })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: this.translucent ? this.barHeight : 0, bottom: this.bottomInset })
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
    if (this.translucent) {
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
          this.body()
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
  }
}

/**
 * Ready-made application shell (the SparkUI gallery's own layout as a block): a data-driven sidebar
 * (brand, grouped nav with icons / badges, user footer), a top bar (sidebar trigger, title of the active
 * page, search, actions) and the scrolling page content, with an optional footer line.
 *
 * Breakpoint-free: the sidebar docks when there is room and becomes a sheet otherwise; with
 * `collapsible: 'icon'` the trigger folds it to an icon rail (animated width, motion key 'sidebar').
 * Immersive-ready (`safeArea`, default on): the sidebar, top bar and content pad the window insets themselves
 * (ADR D10 — expandSafeArea cannot cross custom components).
 *
 * ```
 * SAppShell({ brand: 'Acme Inc', nav: NAV, value: this.page!!, user: ME,
 *   actions: [new SparkTopbarAction('theme', 'moon', 'Toggle theme')], onAction: (id: string) => ... }) {
 *   PageContent({ page: this.page })      // scrolls; padded and centred up to maxContentWidth
 * }
 * ```
 * For anything custom, compose SSidebarProvider / SSidebar / SSidebarInset / STopbar directly.
 */
@ComponentV2
export struct SAppShell {
  @Param brand: ResourceStr = '';
  @Param brandIcon: string = 'sparkles';
  @Param brandDetail: ResourceStr | undefined = undefined;
  @Param nav: SparkShellNavGroup[] = [];
  /** active nav item id */
  @Param value: string | undefined = undefined;
  @Event $value: (value: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (value: string) => void = () => {
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
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = true;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  /** translucent top bar with content scrolling underneath */
  @Param topbarBlur: boolean = true;
  /** pad the window safe area (immersive pages) */
  @Param safeArea: boolean = true;
  /** max width of the page content (0 = unlimited) */
  @Param maxContentWidth: number = 1200;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local current: string = '';

  aboutToAppear(): void {
    this.current = this.value ?? this.defaultValue;
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.current = this.value;
    }
  }

  @Computed
  get resolvedTitle(): ResourceStr {
    if (this.title !== undefined) {
      return this.title;
    }
    return sparkShellNavTitle(this.nav, this.current);
  }

  private select(v: string): void {
    if (this.value === undefined) {
      this.current = v;
    }
    this.$value(v);
    this.onValueChange(v);
  }

  build() {
    SSidebarProvider({
      variant: this.variant,
      collapsible: this.collapsible,
      side: this.side,
      open: this.open,
      defaultOpen: this.defaultOpen,
      onOpenChange: (o: boolean) => {
        this.$open(o);
        this.onOpenChange(o);
      },
      value: this.current,
      onValueChange: (v: string) => this.select(v),
      safeArea: this.safeArea
    }) {
      SSidebar() {
        SSidebarHeader() {
          ShellBrand({ brand: this.brand, brandIcon: this.brandIcon, brandDetail: this.brandDetail })
        }
        SSidebarContent() {
          ForEach(this.nav, (g: SparkShellNavGroup) => {
            SSidebarGroup() {
              if (g.title.length > 0) {
                SSidebarGroupLabel({ text: g.title })
              }
              SSidebarMenu() {
                ForEach(g.items, (item: SparkShellNavItem) => {
                  SSidebarMenuItem() {
                    SSidebarMenuButton({ value: item.id, icon: item.icon, text: item.title, badge: item.badge })
                  }
                }, (item: SparkShellNavItem) => item.id)
              }
            }
          }, (g: SparkShellNavGroup, i: number) => `${i}:${g.title}`)
        }
        if (this.user !== undefined) {
          SSidebarFooter() {
            ShellUser({ user: this.user })
          }
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
          translucent: this.topbarBlur,
          safeArea: this.safeArea,
          footerText: this.footerText,
          maxContentWidth: this.maxContentWidth,
          pageKey: this.current
        }) {
          this.content()
        }
      }
    }
  }
}
