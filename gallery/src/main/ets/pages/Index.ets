import {
  SAppShell, SButton, SPageTransition, SparkProvider, SparkSidebarState, SparkTheme, SparkUI, SSidebarMenu, SSidebarMenuButton,
  SSidebarMenuItem
} from '@sparkui/core';
import { PersistenceV2 } from '@kit.ArkUI';
import { ButtonDoc, CardDoc, CodeDoc, DialogDoc, IconsDoc, PopoverDoc, SheetDoc } from '../docs/ComponentDocs';
import { IntroDoc, LayoutDoc, ThemingDoc } from '../docs/StartDocs';
import { NAV, NAV_ORDER, navGroupTitle, navHas } from '../shell/Nav';
import { ResponsiveDoc } from '../docs/ResponsiveDoc';
import {
  AccordionDoc, BreadcrumbDoc, ButtonGroupDoc, CollapsibleDoc, PaginationDoc, ScrollAreaDoc, TabsDoc, ToggleDoc
} from '../docs/NavDocs';
import { CheckboxDoc, FieldDoc, InputDoc, ProgressDoc, RadioGroupDoc, SliderDoc, SwitchDoc, TextareaDoc } from '../docs/FormDocs';
import {
  AlertDoc, AspectRatioDoc, AvatarDoc, BadgeDoc, EmptyDoc, ItemDoc, SeparatorDoc, SkeletonDoc, TypographyDoc
} from '../docs/DisplayDocs';
import { AlertDialogDoc, DropdownMenuDoc, SelectDoc, ToastDoc, TooltipDoc } from '../docs/OverlayDocs';
import { CalendarDoc, DatePickerDoc } from '../docs/DateDocs';
import { AreaChartDoc, BarChartDoc, ChartsOverviewDoc, LineChartDoc, PieChartDoc, RadarChartDoc, RadialChartDoc } from '../docs/ChartDocs';
import { AppShellDoc, DashboardGridDoc, ListDetailDoc, SidebarDoc, SupportingPaneDoc, TopbarDoc } from '../docs/BlocksDocs';
import { InputGroupDoc, NumberFieldDoc, PinInputDoc, StepperDoc, TableDoc, TagsInputDoc } from '../docs/DataDocs';
import { ComboboxDoc, CommandDoc, ContextMenuDoc, DrawerDoc, HoverCardDoc, MenubarDoc } from '../docs/OverlayDocs2';
import { TransitionDoc } from '../docs/TransitionDocs';
import { GalleryTitleBar, TitleBarDoc } from '../docs/TitleBarDocs';

/** Gallery preferences persisted across launches (PersistenceV2), fed to SAppShell through its hooks. */
@ObservedV2
class GalleryPrefs {
  @Trace page: string = 'intro';
  @Trace sidebarOpen: boolean = true;
}

@Entry
@ComponentV2
struct Index {
  /** the gallery owns the sidebar controller, so the page can route the system back to it */
  private sidebar: SparkSidebarState = new SparkSidebarState();

  onBackPress(): boolean {
    return this.sidebar.back();
  }

  build() {
    Stack() {
      SparkProvider({ immersive: true }) {
        GalleryShell({ sidebar: this.sidebar })
      }
    }
  }
}

/** Light / dark switch in the top bar (a component, so its icon follows the live theme). */
@ComponentV2
struct ThemeToggle {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Stack() {
      SButton({ variant: 'ghost', sizing: 'icon-sm', icon: this.theme.isDark ? 'sun' : 'moon', label: 'Toggle theme' })
        .onClick(() => SparkUI.themes.toggleDark())
    }
  }
}

@ComponentV2
struct DocContent {
  @Param page: string = 'intro';

  build() {
    if (this.page === 'transition') {
      TransitionDoc()
    } else if (this.page === 'title-bar') {
      TitleBarDoc()
    } else if (this.page === 'charts') {
      ChartsOverviewDoc()
    } else if (this.page === 'area-chart') {
      AreaChartDoc()
    } else if (this.page === 'bar-chart') {
      BarChartDoc()
    } else if (this.page === 'line-chart') {
      LineChartDoc()
    } else if (this.page === 'pie-chart') {
      PieChartDoc()
    } else if (this.page === 'radar-chart') {
      RadarChartDoc()
    } else if (this.page === 'radial-chart') {
      RadialChartDoc()
    } else if (this.page === 'sidebar') {
      SidebarDoc()
    } else if (this.page === 'topbar') {
      TopbarDoc()
    } else if (this.page === 'app-shell') {
      AppShellDoc()
    } else if (this.page === 'list-detail') {
      ListDetailDoc()
    } else if (this.page === 'supporting-pane') {
      SupportingPaneDoc()
    } else if (this.page === 'dashboard-grid') {
      DashboardGridDoc()
    } else if (this.page === 'calendar') {
      CalendarDoc()
    } else if (this.page === 'date-picker') {
      DatePickerDoc()
    } else if (this.page === 'input-group') {
      InputGroupDoc()
    } else if (this.page === 'number-field') {
      NumberFieldDoc()
    } else if (this.page === 'pin-input') {
      PinInputDoc()
    } else if (this.page === 'tags-input') {
      TagsInputDoc()
    } else if (this.page === 'stepper') {
      StepperDoc()
    } else if (this.page === 'table') {
      TableDoc()
    } else if (this.page === 'hover-card') {
      HoverCardDoc()
    } else if (this.page === 'context-menu') {
      ContextMenuDoc()
    } else if (this.page === 'command') {
      CommandDoc()
    } else if (this.page === 'combobox') {
      ComboboxDoc()
    } else if (this.page === 'drawer') {
      DrawerDoc()
    } else if (this.page === 'menubar') {
      MenubarDoc()
    } else if (this.page === 'accordion') {
      AccordionDoc()
    } else if (this.page === 'breadcrumb') {
      BreadcrumbDoc()
    } else if (this.page === 'button-group') {
      ButtonGroupDoc()
    } else if (this.page === 'collapsible') {
      CollapsibleDoc()
    } else if (this.page === 'pagination') {
      PaginationDoc()
    } else if (this.page === 'scroll-area') {
      ScrollAreaDoc()
    } else if (this.page === 'tabs') {
      TabsDoc()
    } else if (this.page === 'toggle') {
      ToggleDoc()
    } else if (this.page === 'checkbox') {
      CheckboxDoc()
    } else if (this.page === 'field') {
      FieldDoc()
    } else if (this.page === 'input') {
      InputDoc()
    } else if (this.page === 'progress') {
      ProgressDoc()
    } else if (this.page === 'radio-group') {
      RadioGroupDoc()
    } else if (this.page === 'slider') {
      SliderDoc()
    } else if (this.page === 'switch') {
      SwitchDoc()
    } else if (this.page === 'textarea') {
      TextareaDoc()
    } else if (this.page === 'alert') {
      AlertDoc()
    } else if (this.page === 'aspect-ratio') {
      AspectRatioDoc()
    } else if (this.page === 'avatar') {
      AvatarDoc()
    } else if (this.page === 'badge') {
      BadgeDoc()
    } else if (this.page === 'empty') {
      EmptyDoc()
    } else if (this.page === 'item') {
      ItemDoc()
    } else if (this.page === 'separator') {
      SeparatorDoc()
    } else if (this.page === 'skeleton') {
      SkeletonDoc()
    } else if (this.page === 'typography') {
      TypographyDoc()
    } else if (this.page === 'alert-dialog') {
      AlertDialogDoc()
    } else if (this.page === 'dropdown-menu') {
      DropdownMenuDoc()
    } else if (this.page === 'select') {
      SelectDoc()
    } else if (this.page === 'toast') {
      ToastDoc()
    } else if (this.page === 'tooltip') {
      TooltipDoc()
    } else if (this.page === 'responsive') {
      ResponsiveDoc()
    } else if (this.page === 'card') {
      CardDoc()
    } else if (this.page === 'theming') {
      ThemingDoc()
    } else if (this.page === 'layout') {
      LayoutDoc()
    } else if (this.page === 'icons') {
      IconsDoc()
    } else if (this.page === 'code') {
      CodeDoc()
    } else if (this.page === 'button') {
      ButtonDoc()
    } else if (this.page === 'dialog') {
      DialogDoc()
    } else if (this.page === 'popover') {
      PopoverDoc()
    } else if (this.page === 'sheet') {
      SheetDoc()
    } else {
      IntroDoc()
    }
  }
}

/**
 * The gallery layout is the library's SAppShell (the showcase of the block): grouped sidebar from NAV (docked
 * when it fits, an icon rail when collapsed, a sheet on narrow windows), top bar with the page title, its group
 * and the theme toggle, immersive safe areas, content scrolling under the translucent bar.
 *
 * Extension points used here: an app-owned `controller` (system back closes the sheet), persistence through
 * the `onValueChange` / `onOpenChange` hooks (PersistenceV2, no storage inside the block), slots for the top
 * bar actions, the sidebar footer and the title-bar region (GalleryTitleBar for free-form windows); the page
 * body is an SPageTransition keyed by the page id.
 */
@ComponentV2
struct GalleryShell {
  @Param @Require sidebar: SparkSidebarState;
  @Local prefs: GalleryPrefs = PersistenceV2.connect(GalleryPrefs, 'sparkui.gallery', () => new GalleryPrefs())!;

  aboutToAppear(): void {
    if (!navHas(this.prefs.page)) {
      this.prefs.page = 'intro';
    }
    // a controller keeps its own initial state: seed it with the persisted collapse state
    this.sidebar.open = this.prefs.sidebarOpen;
  }

  /** One page of the transition (SPageTransition keeps the leaving page mounted while it animates out). */
  @LocalBuilder
  renderPage(key: string) {
    DocContent({ page: key })
  }

  /** Page body: a direction-aware transition (down the sidebar = forward, up = back). */
  @LocalBuilder
  body() {
    SPageTransition({
      current: this.prefs.page,
      pageBuilder: this.renderPage,
      order: NAV_ORDER,
      name: 'fade-through'
    })
  }

  @LocalBuilder
  titleBar() {
    // free-window / PC chrome (renders nothing unless the window is a free-form window)
    GalleryTitleBar()
  }

  @LocalBuilder
  topbarActions() {
    ThemeToggle()
  }

  @LocalBuilder
  sidebarFooter() {
    SSidebarMenu() {
      SSidebarMenuItem() {
        SSidebarMenuButton({ icon: 'info', text: 'SparkUI · API 22 · V2', sizing: 'sm' })
      }
    }
  }

  build() {
    SAppShell({
      brand: 'SparkUI',
      brandDetail: 'Components & foundations',
      nav: NAV,
      controller: this.sidebar,
      value: this.prefs.page,
      onValueChange: (id: string) => {
        this.prefs.page = id;
      },
      onOpenChange: (open: boolean) => {
        this.prefs.sidebarOpen = open;
      },
      subtitle: navGroupTitle(this.prefs.page),
      collapsible: 'icon',
      maxContentWidth: 880,
      titleBarBuilder: (): void => {
        this.titleBar()
      },
      topbarActionsBuilder: (): void => {
        this.topbarActions()
      },
      sidebarFooterBuilder: (): void => {
        this.sidebarFooter()
      },
      // with other slots passed, the content goes by name too (ArkTS: no trailing closure alongside slot args)
      content: this.body
    })
  }
}
