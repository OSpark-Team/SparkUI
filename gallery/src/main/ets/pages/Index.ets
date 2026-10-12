import {
  SButton, SIcon, SparkLayoutContext, SparkProvider, SparkTheme, SparkUI, SSheet, SSheetContent, SSheetDescription,
  SSheetHeader, SSheetTitle
} from '@sparkui/core';
import { ButtonDoc, CardDoc, CodeDoc, DialogDoc, IconsDoc, PopoverDoc, SheetDoc } from '../docs/ComponentDocs';
import { IntroDoc, LayoutDoc, ThemingDoc } from '../docs/StartDocs';
import { GalleryNav, navTitle } from '../shell/Nav';
import { ResponsiveDoc } from '../docs/ResponsiveDoc';
import {
  AccordionDoc, BreadcrumbDoc, ButtonGroupDoc, CollapsibleDoc, PaginationDoc, ScrollAreaDoc, TabsDoc, ToggleDoc
} from '../docs/NavDocs';
import { CheckboxDoc, FieldDoc, InputDoc, ProgressDoc, RadioGroupDoc, SliderDoc, SwitchDoc, TextareaDoc } from '../docs/FormDocs';
import {
  AlertDoc, AspectRatioDoc, AvatarDoc, BadgeDoc, EmptyDoc, ItemDoc, SeparatorDoc, SkeletonDoc, TypographyDoc
} from '../docs/DisplayDocs';
import { AlertDialogDoc, DropdownMenuDoc, SelectDoc, ToastDoc, TooltipDoc } from '../docs/OverlayDocs';

@Entry
@ComponentV2
struct Index {
  build() {
    Stack() {
      SparkProvider({ immersive: true }) {
        GalleryShell()
      }
    }
  }
}

@ComponentV2
struct Brand {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 8 }) {
      Row() {
        SIcon({ name: 'sparkles', sizing: 16, color: this.theme.colors.primaryForeground })
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .borderRadius(this.theme.radiusMd)
      .backgroundColor(this.theme.colors.primary)

      Text('SparkUI')
        .fontSize(this.theme.text.base)
        .fontWeight(this.theme.text.weightBold)
        .fontColor(this.theme.colors.foreground)
    }
  }
}

@ComponentV2
struct DocContent {
  @Param page: string = 'intro';

  build() {
    if (this.page === 'accordion') {
      AccordionDoc()
    } else     if (this.page === 'breadcrumb') {
      BreadcrumbDoc()
    } else     if (this.page === 'button-group') {
      ButtonGroupDoc()
    } else     if (this.page === 'collapsible') {
      CollapsibleDoc()
    } else     if (this.page === 'pagination') {
      PaginationDoc()
    } else     if (this.page === 'scroll-area') {
      ScrollAreaDoc()
    } else     if (this.page === 'tabs') {
      TabsDoc()
    } else     if (this.page === 'toggle') {
      ToggleDoc()
    } else if (this.page === 'checkbox') {
      CheckboxDoc()
    } else     if (this.page === 'field') {
      FieldDoc()
    } else     if (this.page === 'input') {
      InputDoc()
    } else     if (this.page === 'progress') {
      ProgressDoc()
    } else     if (this.page === 'radio-group') {
      RadioGroupDoc()
    } else     if (this.page === 'slider') {
      SliderDoc()
    } else     if (this.page === 'switch') {
      SwitchDoc()
    } else     if (this.page === 'textarea') {
      TextareaDoc()
    } else     if (this.page === 'alert') {
      AlertDoc()
    } else     if (this.page === 'aspect-ratio') {
      AspectRatioDoc()
    } else     if (this.page === 'avatar') {
      AvatarDoc()
    } else     if (this.page === 'badge') {
      BadgeDoc()
    } else     if (this.page === 'empty') {
      EmptyDoc()
    } else     if (this.page === 'item') {
      ItemDoc()
    } else     if (this.page === 'separator') {
      SeparatorDoc()
    } else     if (this.page === 'skeleton') {
      SkeletonDoc()
    } else     if (this.page === 'typography') {
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

@ComponentV2
struct GalleryShell {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local page: string = 'intro';
  @Local navOpen: boolean = false;
  private scroller: Scroller = new Scroller();

  private go(id: string): void {
    this.page = id;
    this.navOpen = false;
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  @Builder
  modeToggle() {
    SButton({ variant: 'ghost', sizing: 'icon', icon: this.theme.isDark ? 'sun' : 'moon', label: 'Toggle theme' })
      .onClick(() => SparkUI.themes.toggleDark())
  }

  @Builder
  pageBody() {
    Scroll(this.scroller) {
      Column() {
        Column() {
          DocContent({ page: this.page })
        }
        .width('100%')
        .constraintSize({ maxWidth: 880 })
        .padding({ left: 24, right: 24, top: 24, bottom: 48 + this.layout.env.safeArea.bottom })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    if (this.layout.atLeast('medium')) {
      Row() {
        // fixed sidebar (shadcn sidebar tokens)
        Column({ space: 16 }) {
          Brand()
          Scroll() {
            GalleryNav({ current: this.page, onSelect: (id: string) => this.go(id) })
          }
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        }
        .width(248)
        .height('100%')
        .padding({ left: 12, right: 12, top: 20 + this.layout.env.safeArea.top,
          bottom: this.layout.env.safeArea.bottom })
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.theme.colors.sidebar)
        .border({ width: { right: 1 }, color: this.theme.colors.sidebarBorder })

        Column() {
          Row() {
            Text(navTitle(this.page))
              .fontSize(this.theme.text.sm)
              .fontColor(this.theme.colors.mutedForeground)
            this.modeToggle()
          }
          .width('100%')
          .height(56 + this.layout.env.safeArea.top)
          .padding({ left: 24, right: 12, top: this.layout.env.safeArea.top })
          .justifyContent(FlexAlign.SpaceBetween)
          .border({ width: { bottom: 1 }, color: this.theme.colors.border })

          this.pageBody()
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
    } else {
      Column() {
        Row() {
          Row({ space: 4 }) {
            SButton({ variant: 'ghost', sizing: 'icon', icon: 'menu', label: 'Open navigation' })
              .onClick(() => {
                this.navOpen = true;
              })
            Brand()
          }

          this.modeToggle()
        }
        .width('100%')
        .height(56 + this.layout.env.safeArea.top)
        .padding({ left: 8, right: 8, top: this.layout.env.safeArea.top })
        .justifyContent(FlexAlign.SpaceBetween)
        .border({ width: { bottom: 1 }, color: this.theme.colors.border })

        this.pageBody()

        SSheet({ open: this.navOpen!! }) {
          SSheetContent({ side: 'left', panelWidth: 288 }) {
            SSheetHeader() {
              SSheetTitle({ text: 'SparkUI' })
              SSheetDescription({ text: 'Components & foundations' })
            }
            Scroll() {
              GalleryNav({ current: this.page, onSelect: (id: string) => this.go(id) })
            }
            .layoutWeight(1)
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
          }
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}
