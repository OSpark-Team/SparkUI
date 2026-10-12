import {
  SAppShell, SBadge, SButton, SDashboardGrid,
  SDashboardTile, SIcon, SListDetail, SListDetailPane, SListPane, SparkColor, SparkShellNavGroup,
  SparkShellNavItem, SparkShellUser, SparkTheme, SparkTopbarAction, SparkUI, SSidebar, SSidebarContent,
  SSidebarFooter, SSidebarGroup, SSidebarGroupLabel, SSidebarHeader, SSidebarInset, SSidebarMenu,
  SSidebarMenuButton, SSidebarMenuItem, SSidebarProvider, SSidebarSeparator, SSupportingPane,
  SSupportingPaneAside, SSupportingPaneMain, SSupportingPaneTrigger, SToggleGroup, SToggleGroupItem, STopbar,
  SidebarCollapsible, SidebarSide, SidebarVariant, SupportingCompactMode, toast
} from '@sparkui/core';
import { LengthMetrics } from '@kit.ArkUI';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

@Builder
function emptyFrame() {
}

/**
 * Bounded, resizable preview frame: the blocks are full-height layouts, so the demos render them inside a
 * fixed-height frame whose width can be dragged (like resizing a browser window). Nothing in the blocks
 * declares a breakpoint — they react to the frame's width.
 */
@ComponentV2
struct ResizableFrame {
  @Param frameHeight: number = 480;
  @Param initialPct: number = 100;
  @BuilderParam content: () => void = emptyFrame;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local pct: number = 100;

  aboutToAppear(): void {
    this.pct = this.initialPct;
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        SIcon({ name: 'smartphone', sizing: 16, color: this.theme.colors.mutedForeground })
        Slider({ value: this.pct, min: 40, max: 100, step: 1 })
          .layoutWeight(1)
          .onChange((v: number) => {
            this.pct = v;
          })
        SIcon({ name: 'monitor', sizing: 16, color: this.theme.colors.mutedForeground })
        Text(`${Math.round(this.pct)}%`)
          .width(44)
          .fontSize(this.theme.text.sm)
          .fontColor(this.theme.colors.mutedForeground)
      }
      .width('100%')

      Column() {
        this.content()
      }
      .width(`${this.pct}%`)
      .height(this.frameHeight)
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** Muted placeholder block for page content in the demos. */
@ComponentV2
struct Placeholder {
  @Param label: string = '';
  @Param tall: number = 120;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column() {
      Text(this.label)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .width('100%')
    .height(this.tall)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(SparkColor.alpha(this.theme.colors.muted, 0.6))
    .borderRadius(this.theme.radiusLg)
  }
}

// ================================================================================================ Sidebar

const SIDEBAR_CODE = `SSidebarProvider({ variant: 'sidebar', collapsible: 'icon', value: this.page!! }) {
  SSidebar() {
    SSidebarHeader() { Brand() }
    SSidebarContent() {
      SSidebarGroup() {
        SSidebarGroupLabel({ text: 'Platform' })
        SSidebarMenu() {
          SSidebarMenuItem() {
            SSidebarMenuButton({ value: 'inbox', icon: 'inbox', text: 'Inbox', badge: '24' })
          }
          SSidebarMenuItem() {
            SSidebarMenuButton({ value: 'calendar', icon: 'calendar', text: 'Calendar' })
          }
        }
      }
    }
    SSidebarFooter() { UserRow() }
  }
  SSidebarInset() {
    STopbar({ title: 'Inbox' })          // leading SSidebarTrigger appears automatically
    SPage() { ... }
  }
}
// Wide container: docked; the trigger folds it to an icon rail (animated width).
// Narrow container: the sidebar becomes a sheet opened by the trigger. No breakpoints to declare.`;

class DemoNav {
  id: string;
  title: string;
  icon: string;
  badge: string | undefined;

  constructor(id: string, title: string, icon: string, badge?: string) {
    this.id = id;
    this.title = title;
    this.icon = icon;
    this.badge = badge;
  }
}

const PLATFORM: DemoNav[] = [
  new DemoNav('home', 'Home', 'house'),
  new DemoNav('inbox', 'Inbox', 'inbox', '24'),
  new DemoNav('calendar', 'Calendar', 'calendar'),
  new DemoNav('search', 'Search', 'search')
];

const PROJECTS: DemoNav[] = [
  new DemoNav('design', 'Design Engineering', 'layout-dashboard'),
  new DemoNav('sales', 'Sales & Marketing', 'chart-line', '3'),
  new DemoNav('travel', 'Travel', 'map')
];

function navTitleOf(id: string): string {
  const all = PLATFORM.concat(PROJECTS);
  const hit = all.find((n: DemoNav) => n.id === id);
  return hit !== undefined ? hit.title : '';
}

@ComponentV2
struct DemoBrand {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 8 }) {
      Row() {
        SIcon({ name: 'sparkles', sizing: 16, color: this.theme.colors.sidebarPrimaryForeground })
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .borderRadius(this.theme.radiusMd)
      .backgroundColor(this.theme.colors.sidebarPrimary)

      Column({ space: 2 }) {
        Text('Acme Inc')
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightSemibold)
          .fontColor(this.theme.colors.sidebarForeground)
          .maxLines(1)
        Text('Enterprise')
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.sidebarForeground)
          .opacity(0.7)
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .clip(true)
  }
}

@ComponentV2
export struct SidebarDoc {
  @Local variant: SidebarVariant = 'sidebar';
  @Local collapsible: SidebarCollapsible = 'icon';
  @Local side: SidebarSide = 'left';
  @Local page: string = 'inbox';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Sidebar',
        lead: 'A composable, themeable app sidebar (shadcn-vue Sidebar). It docks beside the content when there is ' +
          'room and turns into a sheet when there is not — measured from its own container, no breakpoints. ' +
          'Collapse to an icon rail or off-canvas with an animated width.'
      })

      DocSection({ title: 'Playground', description: 'Drag the width slider; try the variants and collapse modes.' })
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center,
        space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.variant],
          onValueChange: (v: string[]) => {
            if (v.length > 0) {
              this.variant = v[0] as SidebarVariant;
            }
          } }) {
          SToggleGroupItem({ value: 'sidebar', text: 'Sidebar' })
          SToggleGroupItem({ value: 'floating', text: 'Floating' })
          SToggleGroupItem({ value: 'inset', text: 'Inset' })
        }

        SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.collapsible],
          onValueChange: (v: string[]) => {
            if (v.length > 0) {
              this.collapsible = v[0] as SidebarCollapsible;
            }
          } }) {
          SToggleGroupItem({ value: 'icon', text: 'Icon' })
          SToggleGroupItem({ value: 'offcanvas', text: 'Offcanvas' })
          SToggleGroupItem({ value: 'none', text: 'None' })
        }

        SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.side],
          onValueChange: (v: string[]) => {
            if (v.length > 0) {
              this.side = v[0] as SidebarSide;
            }
          } }) {
          SToggleGroupItem({ value: 'left', text: 'Left' })
          SToggleGroupItem({ value: 'right', text: 'Right' })
        }
      }
      .width('100%')

      DemoBlock({ code: SIDEBAR_CODE, centered: false }) {
        ResizableFrame({ frameHeight: 520 }) {
          SSidebarProvider({
            variant: this.variant,
            collapsible: this.collapsible,
            side: this.side,
            value: this.page,
            onValueChange: (v: string) => {
              this.page = v;
            }
          }) {
            SSidebar() {
              SSidebarHeader() {
                DemoBrand()
              }
              SSidebarContent() {
                SSidebarGroup() {
                  SSidebarGroupLabel({ text: 'Platform' })
                  SSidebarMenu() {
                    ForEach(PLATFORM, (n: DemoNav) => {
                      SSidebarMenuItem() {
                        SSidebarMenuButton({ value: n.id, icon: n.icon, text: n.title, badge: n.badge })
                      }
                    }, (n: DemoNav) => n.id)
                  }
                }
                SSidebarSeparator()
                SSidebarGroup() {
                  SSidebarGroupLabel({ text: 'Projects' })
                  SSidebarMenu() {
                    ForEach(PROJECTS, (n: DemoNav) => {
                      SSidebarMenuItem() {
                        SSidebarMenuButton({ value: n.id, icon: n.icon, text: n.title, badge: n.badge })
                      }
                    }, (n: DemoNav) => n.id)
                  }
                }
              }
              SSidebarFooter() {
                SSidebarMenu() {
                  SSidebarMenuItem() {
                    SSidebarMenuButton({ icon: 'settings', text: 'Settings', sizing: 'sm' })
                  }
                  SSidebarMenuItem() {
                    SSidebarMenuButton({ icon: 'log-out', text: 'Sign out', sizing: 'sm' })
                  }
                }
              }
            }
            SSidebarInset() {
              STopbar({ title: navTitleOf(this.page), subtitle: 'Acme Inc' })
              Column({ space: 12 }) {
                Placeholder({ label: `${navTitleOf(this.page)} content`, tall: 140 })
                Row({ space: 12 }) {
                  Column() {
                    Placeholder({ label: 'Card', tall: 96 })
                  }
                  .layoutWeight(1)

                  Column() {
                    Placeholder({ label: 'Card', tall: 96 })
                  }
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
            }
          }
        }
      }

      DocSection({
        title: 'Anatomy',
        description: 'SSidebarProvider owns the state (open, openMobile, value) and lays out SSidebar + ' +
          'SSidebarInset. Parts: SSidebarHeader, SSidebarContent (scrolls), SSidebarFooter, SSidebarGroup, ' +
          'SSidebarGroupLabel, SSidebarMenu, SSidebarMenuItem, SSidebarMenuButton (icon, text, badge, isActive or ' +
          'value), SSidebarSeparator, SSidebarTrigger.'
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// ================================================================================================ Topbar

const TOPBAR_CODE = `STopbar({
  title: 'Projects',
  subtitle: '12 active',
  search: true,                                  // expands from an icon when condensed
  actions: [new SparkTopbarAction('new', 'plus', 'New project'),
            new SparkTopbarAction('alerts', 'bell', 'Notifications')],
  onAction: (id: string) => ...,
  onSearch: (q: string) => ...
}) {
  SBadge({ text: 'Beta', variant: 'secondary' })  // optional trailing slot
}

STopbar({ title: 'Invoice #1024', leading: 'back', onBack: () => ... })
STopbar({ title: 'Gallery', translucent: true }) // backdrop blur for content scrolling underneath`;

@ComponentV2
export struct TopbarDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Top Bar',
        lead: 'The app header block: leading control, title, search and actions. It condenses on its own when ' +
          'narrow (shorter, subtitle hidden, search behind an icon) and adds the status-bar inset in immersive pages.'
      })

      DemoBlock({ code: TOPBAR_CODE, centered: false }) {
        ResizableFrame({ frameHeight: 300 }) {
          Column() {
            STopbar({
              title: 'Projects',
              subtitle: '12 active',
              search: true,
              actions: [new SparkTopbarAction('new', 'plus', 'New project'),
                new SparkTopbarAction('alerts', 'bell', 'Notifications')],
              onAction: (id: string) => {
                toast(`Action: ${id}`);
              },
              onSearch: (q: string) => {
                toast(`Search: ${q}`);
              }
            }) {
              SBadge({ text: 'Beta', variant: 'secondary' })
            }
            STopbar({ title: 'Invoice #1024', subtitle: 'Due in 3 days', leading: 'back', onBack: () => {
              toast('Back');
            } })
            Stack({ alignContent: Alignment.Top }) {
              Column({ space: 8 }) {
                ForEach([0, 1, 2, 3], (i: number) => {
                  Column()
                    .width('100%')
                    .height(36)
                    .borderRadius(this.theme.radiusMd)
                    .backgroundColor(i % 2 === 0 ? this.theme.colors.primary : this.theme.colors.destructive)
                    .opacity(0.5)
                }, (i: number) => `${i}`)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 20 })

              STopbar({ title: 'Translucent', translucent: true, leading: 'none' })
            }
            .width('100%')
            .layoutWeight(1)
            .clip(true)
          }
          .width('100%')
          .height('100%')
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// ================================================================================================ App shell

const SHELL_CODE = `const NAV: SparkShellNavGroup[] = [
  new SparkShellNavGroup('Workspace', [
    new SparkShellNavItem('dashboard', 'Dashboard', 'layout-dashboard'),
    new SparkShellNavItem('inbox', 'Inbox', 'inbox', '12'),
    new SparkShellNavItem('calendar', 'Calendar', 'calendar')
  ]),
  new SparkShellNavGroup('Settings', [ new SparkShellNavItem('team', 'Team', 'users') ])
];

// Entry page: Stack() { SparkProvider({ immersive: true }) { ... } }
SAppShell({
  brand: 'Acme Inc', brandDetail: 'Enterprise', nav: NAV, value: this.page!!,
  user: new SparkShellUser('Shad Cn', 'm@example.com'),
  search: true,
  actions: [new SparkTopbarAction('theme', 'moon', 'Toggle theme')],
  onAction: (id: string) => SparkUI.themes.toggleDark(),
  footerText: '© 2026 Acme Inc'
}) {
  PageFor({ page: this.page })     // scrolls under the translucent top bar
}`;

const SHELL_NAV: SparkShellNavGroup[] = [
  new SparkShellNavGroup('Workspace', [
    new SparkShellNavItem('dashboard', 'Dashboard', 'layout-dashboard'),
    new SparkShellNavItem('inbox', 'Inbox', 'inbox', '12'),
    new SparkShellNavItem('calendar', 'Calendar', 'calendar'),
    new SparkShellNavItem('docs', 'Documents', 'file-text')
  ]),
  new SparkShellNavGroup('Settings', [
    new SparkShellNavItem('team', 'Team', 'users'),
    new SparkShellNavItem('billing', 'Billing', 'credit-card')
  ])
];

@ComponentV2
export struct AppShellDoc {
  @Local page: string = 'dashboard';
  @Local variant: SidebarVariant = 'inset';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'App Shell',
        lead: 'Sidebar + top bar + scrolling content in one block — the layout of this gallery, driven by data. ' +
          'It pads immersive safe areas itself, scrolls content under a translucent top bar and scrolls back to ' +
          'the top when the page changes.'
      })

      SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.variant],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            this.variant = v[0] as SidebarVariant;
          }
        } }) {
        SToggleGroupItem({ value: 'sidebar', text: 'Sidebar' })
        SToggleGroupItem({ value: 'floating', text: 'Floating' })
        SToggleGroupItem({ value: 'inset', text: 'Inset' })
      }

      DemoBlock({ code: SHELL_CODE, centered: false }) {
        ResizableFrame({ frameHeight: 560 }) {
          SAppShell({
            brand: 'Acme Inc',
            brandDetail: 'Enterprise',
            nav: SHELL_NAV,
            value: this.page,
            onValueChange: (v: string) => {
              this.page = v;
            },
            user: new SparkShellUser('Shad Cn', 'm@example.com'),
            search: true,
            actions: [new SparkTopbarAction('theme', 'moon', 'Toggle theme')],
            onAction: () => SparkUI.themes.toggleDark(),
            variant: this.variant,
            footerText: '© 2026 Acme Inc',
            safeArea: false
          }) {
            Column({ space: 12 }) {
              Placeholder({ label: `${this.page} — hero`, tall: 160 })
              ForEach([0, 1, 2, 3, 4], (i: number) => {
                Placeholder({ label: `Section ${i + 1}`, tall: 88 })
              }, (i: number) => `${i}`)
            }
            .width('100%')
          }
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// ================================================================================================ List detail

const LIST_DETAIL_CODE = `SListDetail({ showDetail: this.open!!, listWidth: 300 }) {
  SListPane() {
    List() {
      ForEach(MAILS, (m: Mail) => {
        ListItem() { MailRow({ mail: m }) }
          .onClick(() => { this.selected = m.id; this.open = true; })
      })
    }
  }
  SListDetailPane({ title: this.mail.subject }) {     // back button when narrow
    MailView({ mail: this.mail })
  }
}`;

class Mail {
  id: string;
  from: string;
  subject: string;
  body: string;
  time: string;

  constructor(id: string, from: string, subject: string, body: string, time: string) {
    this.id = id;
    this.from = from;
    this.subject = subject;
    this.body = body;
    this.time = time;
  }
}

const MAILS: Mail[] = [
  new Mail('1', 'William Smith', 'Meeting Tomorrow', 'Hi, let\'s have a meeting tomorrow to discuss the project. ' +
    'I\'ve been reviewing the project details and have some ideas I\'d like to share.', '09:34'),
  new Mail('2', 'Alice Smith', 'Re: Project Update', 'Thank you for the project update. It looks great! I\'ve ' +
    'gone through the report, and the progress is impressive.', 'Yesterday'),
  new Mail('3', 'Bob Johnson', 'Weekend Plans', 'Any plans for the weekend? I was thinking of going hiking in the ' +
    'nearby mountains.', 'Mon'),
  new Mail('4', 'Emily Davis', 'Re: Question about Budget', 'I have a question about the budget for the upcoming ' +
    'project. It seems like there\'s a discrepancy in the allocation of resources.', 'Sun'),
  new Mail('5', 'Michael Wilson', 'Important Announcement', 'I have an important announcement to make during our ' +
    'team meeting.', 'Sat'),
  new Mail('6', 'Sarah Brown', 'Re: Feedback on Proposal', 'Thank you for your feedback on the proposal. It looks ' +
    'great!', 'Fri')
];

@ComponentV2
struct MailRow {
  @Param mail: Mail = MAILS[0];
  @Param selected: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Styles
  pressedStyle() {
    .backgroundColor(this.theme.colors.accent)
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.selected ? this.theme.colors.accent : Color.Transparent)
  }

  build() {
    Column({ space: 4 }) {
      Row() {
        Text(this.mail.from)
          .layoutWeight(1)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightSemibold)
          .fontColor(this.theme.colors.foreground)
        Text(this.mail.time)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.mutedForeground)
      }
      .width('100%')

      Text(this.mail.subject)
        .fontSize(this.theme.text.xs)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
      Text(this.mail.body)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
  }
}

@ComponentV2
export struct ListDetailDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local selected: string = '1';
  @Local open: boolean = false;

  get mail(): Mail {
    return MAILS.find((m: Mail) => m.id === this.selected) ?? MAILS[0];
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'List Detail',
        lead: 'Master / detail without routing. Side by side when the container fits both panes; one pane at a ' +
          'time when it does not — selecting pushes the detail over the list, and its back button pops it.'
      })

      DemoBlock({ code: LIST_DETAIL_CODE, centered: false }) {
        ResizableFrame({ frameHeight: 480 }) {
          SListDetail({ showDetail: this.open!!, listWidth: 300 }) {
            SListPane() {
              List({ space: 8 }) {
                ForEach(MAILS, (m: Mail) => {
                  ListItem() {
                    MailRow({ mail: m, selected: m.id === this.selected })
                  }
                  .onClick(() => {
                    this.selected = m.id;
                    this.open = true;
                  })
                }, (m: Mail) => m.id)
              }
              .width('100%')
              .height('100%')
              .padding(12)
              .scrollBar(BarState.Off)
            }
            SListDetailPane({ title: this.mail.subject }) {
              Column({ space: 12 }) {
                Row({ space: 12 }) {
                  Text(this.mail.from.split(' ').map((p: string) => p.charAt(0)).join(''))
                    .width(40)
                    .height(40)
                    .textAlign(TextAlign.Center)
                    .borderRadius(20)
                    .fontSize(this.theme.text.sm)
                    .backgroundColor(this.theme.colors.muted)
                    .fontColor(this.theme.colors.foreground)
                  Column({ space: 2 }) {
                    Text(this.mail.from)
                      .fontSize(this.theme.text.sm)
                      .fontWeight(this.theme.text.weightSemibold)
                      .fontColor(this.theme.colors.foreground)
                    Text(this.mail.time)
                      .fontSize(this.theme.text.xs)
                      .fontColor(this.theme.colors.mutedForeground)
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                Text(this.mail.body)
                  .fontSize(this.theme.text.sm)
                  .lineHeight(this.theme.text.leadingSm)
                  .fontColor(this.theme.colors.foreground)
              }
              .width('100%')
              .padding(16)
              .alignItems(HorizontalAlign.Start)
            }
          }
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// ================================================================================================ Supporting pane

const SUPPORTING_CODE = `SSupportingPane({ compactMode: 'sheet', paneWidth: 300 }) {
  SSupportingPaneMain() {
    SSupportingPaneTrigger({ text: 'Details' })  // only shown while the pane lives in a sheet
    Article()
  }
  SSupportingPaneAside({ title: 'Details' }) {
    Properties()
  }
}
// compactMode 'below': the pane stacks under the main content when narrow.`;

@ComponentV2
export struct SupportingPaneDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local mode: SupportingCompactMode = 'sheet';

  @Builder
  property(label: string, value: string) {
    Row() {
      Text(label)
        .layoutWeight(1)
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.mutedForeground)
      Text(value)
        .fontSize(this.theme.text.sm)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
    }
    .width('100%')
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Supporting Pane',
        lead: 'Main content with a supporting side pane (details, filters, related items). The pane sits beside ' +
          'the content when the main area keeps its minimum width, and otherwise moves below it or into a sheet.'
      })

      SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.mode],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            this.mode = v[0] as SupportingCompactMode;
          }
        } }) {
        SToggleGroupItem({ value: 'sheet', text: 'Sheet when narrow' })
        SToggleGroupItem({ value: 'below', text: 'Below when narrow' })
      }

      DemoBlock({ code: SUPPORTING_CODE, centered: false }) {
        ResizableFrame({ frameHeight: 520 }) {
          Scroll() {
            Column() {
              SSupportingPane({ compactMode: this.mode, paneWidth: 280, minMainWidth: 360 }) {
                SSupportingPaneMain() {
                  Row({ space: 8 }) {
                    Text('Quarterly report')
                      .layoutWeight(1)
                      .fontSize(this.theme.text.lg)
                      .fontWeight(this.theme.text.weightSemibold)
                      .fontColor(this.theme.colors.foreground)
                    SSupportingPaneTrigger({ text: 'Details', icon: 'info' })
                  }
                  .width('100%')

                  Placeholder({ label: 'Chart', tall: 160 })
                  Text('Revenue grew 20% quarter over quarter, driven by enterprise subscriptions. Churn stayed ' +
                    'flat while expansion revenue doubled.')
                    .fontSize(this.theme.text.sm)
                    .lineHeight(this.theme.text.leadingSm)
                    .fontColor(this.theme.colors.foreground)
                  Placeholder({ label: 'Table', tall: 120 })
                }
                SSupportingPaneAside({ title: 'Details' }) {
                  Column({ space: 10 }) {
                    this.property('Owner', 'Olivia Martin')
                    this.property('Status', 'In review')
                    this.property('Updated', 'Today, 09:41')
                    this.property('Visibility', 'Team')
                  }
                  .width('100%')

                  SButton({ text: 'Share report', icon: 'users', variant: 'outline', sizing: 'sm' })
                }
              }
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// ================================================================================================ Dashboard

const DASHBOARD_CODE = `SDashboardGrid({ title: 'Overview', minTileWidth: 200 }) {
  SDashboardTile({ title: 'Total Revenue', icon: 'dollar-sign', value: '$45,231.89',
    delta: '+20.1% from last month', trend: 'up' })
  ...
  SDashboardTile({ title: 'Sales', span: 2 }) { Chart() }   // 2 columns when there are 2+
  SDashboardTile({ full: true }) { RecentOrders() }          // always the whole row
}`;

const BARS: number[] = [42, 68, 51, 80, 63, 90, 74, 58, 85, 67, 95, 72];

@ComponentV2
export struct DashboardGridDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Dashboard Grid',
        lead: 'An auto-fill grid of dashboard tiles: as many columns as fit, tiles spanning columns or the full ' +
          'row. KPI tiles from props, anything else in the slot.'
      })

      DemoBlock({ code: DASHBOARD_CODE, centered: false }) {
        ResizableFrame({ frameHeight: 560 }) {
          Scroll() {
            Column() {
              SDashboardGrid({ title: 'Overview', description: 'Last 30 days', minTileWidth: 200 }) {
                SDashboardTile({ title: 'Total Revenue', icon: 'dollar-sign', value: '$45,231.89',
                  delta: '+20.1% from last month', trend: 'up' })
                SDashboardTile({ title: 'Subscriptions', icon: 'users', value: '+2,350',
                  delta: '+180.1% from last month', trend: 'up' })
                SDashboardTile({ title: 'Sales', icon: 'credit-card', value: '+12,234',
                  delta: '-4% from last month', trend: 'down' })
                SDashboardTile({ title: 'Active Now', icon: 'activity', value: '+573',
                  delta: '+201 since last hour', trend: 'none' })
                SDashboardTile({ title: 'Revenue by month', span: 2 }) {
                  Row({ space: 4 }) {
                    ForEach(BARS, (b: number, i: number) => {
                      Column()
                        .layoutWeight(1)
                        .height(b)
                        .borderRadius({ topLeft: 3, topRight: 3 })
                        .backgroundColor(i === 10 ? this.theme.colors.primary :
                          SparkColor.alpha(this.theme.colors.primary, 0.35))
                    }, (b: number, i: number) => `${i}`)
                  }
                  .width('100%')
                  .height(100)
                  .alignItems(VerticalAlign.Bottom)
                }
                SDashboardTile({ title: 'Goals', icon: 'star' }) {
                  Text('3 of 5 reached')
                    .fontSize(this.theme.text.sm)
                    .fontColor(this.theme.colors.mutedForeground)
                }
                SDashboardTile({ title: 'Recent orders', full: true }) {
                  Placeholder({ label: 'Full-row tiles take any content (tables, lists…)', tall: 80 })
                }
              }
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
