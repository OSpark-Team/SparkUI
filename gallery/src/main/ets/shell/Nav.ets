import { SIcon, SparkInteraction, SparkTheme, SparkUI } from '@sparkui/core';

export class NavItem {
  id: string;
  title: string;
  icon: string;

  constructor(id: string, title: string, icon: string) {
    this.id = id;
    this.title = title;
    this.icon = icon;
  }
}

export class NavGroup {
  title: string;
  items: NavItem[];

  constructor(title: string, items: NavItem[]) {
    this.title = title;
    this.items = items;
  }
}

export const NAV: NavGroup[] = [
  new NavGroup('Getting Started', [
    new NavItem('intro', 'Introduction', 'book-open'),
    new NavItem('theming', 'Theming', 'palette'),
    new NavItem('responsive', 'Responsive Layout', 'layout-grid'),
    new NavItem('layout', 'Adaptive Context', 'layout-dashboard')
  ]),
  new NavGroup('Foundations', [
    new NavItem('icons', 'Icons', 'sparkles'),
    new NavItem('code', 'Code Block', 'code')
  ]),
  new NavGroup('Components', [
    new NavItem('alert', 'Alert', 'circle-alert'),
    new NavItem('aspect-ratio', 'Aspect Ratio', 'image'),
    new NavItem('avatar', 'Avatar', 'user-round'),
    new NavItem('badge', 'Badge', 'tag'),
    new NavItem('button', 'Button', 'square'),
    new NavItem('card', 'Card', 'layout-list'),
    new NavItem('empty', 'Empty', 'inbox'),
    new NavItem('item', 'Item', 'list'),
    new NavItem('separator', 'Separator & Kbd', 'command'),
    new NavItem('skeleton', 'Skeleton & Spinner', 'loader-circle'),
    new NavItem('typography', 'Typography', 'type')
  ]),
  new NavGroup('Navigation', [
    new NavItem('accordion', 'Accordion', 'chevrons-up-down'),
    new NavItem('breadcrumb', 'Breadcrumb', 'chevron-right'),
    new NavItem('button-group', 'Button Group', 'ellipsis'),
    new NavItem('collapsible', 'Collapsible', 'chevron-down'),
    new NavItem('pagination', 'Pagination', 'chevrons-right'),
    new NavItem('scroll-area', 'Scroll Area', 'move'),
    new NavItem('tabs', 'Tabs', 'layout-grid'),
    new NavItem('toggle', 'Toggle & Group', 'bold')
  ]),
  new NavGroup('Forms', [
    new NavItem('checkbox', 'Checkbox', 'square-check'),
    new NavItem('field', 'Field', 'text-align-start'),
    new NavItem('input', 'Input & Label', 'type'),
    new NavItem('progress', 'Progress', 'loader'),
    new NavItem('radio-group', 'Radio Group', 'circle'),
    new NavItem('slider', 'Slider', 'sliders-horizontal'),
    new NavItem('switch', 'Switch', 'toggle-right'),
    new NavItem('textarea', 'Textarea', 'text-align-start')
  ]),
  new NavGroup('Overlays', [
    new NavItem('alert-dialog', 'Alert Dialog', 'triangle-alert'),
    new NavItem('dialog', 'Dialog', 'square-check'),
    new NavItem('dropdown-menu', 'Dropdown Menu', 'menu'),
    new NavItem('popover', 'Popover', 'message-square'),
    new NavItem('select', 'Select', 'chevrons-up-down'),
    new NavItem('sheet', 'Sheet', 'panel-left'),
    new NavItem('toast', 'Toast', 'bell'),
    new NavItem('tooltip', 'Tooltip', 'info')
  ])
];

export function navTitle(id: string): string {
  for (const g of NAV) {
    for (const i of g.items) {
      if (i.id === id) {
        return i.title;
      }
    }
  }
  return '';
}

@ComponentV2
struct NavLink {
  @Param item: NavItem = new NavItem('', '', '');
  @Param active: boolean = false;
  @Event onSelect: (id: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Styles
  normalStyle() {
    .backgroundColor(this.active || this.ix.hovered ? this.theme.colors.sidebarAccent : Color.Transparent)
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.theme.colors.sidebarAccent)
  }

  build() {
    Row({ space: 10 }) {
      SIcon({
        name: this.item.icon,
        sizing: 16,
        color: this.active ? this.theme.colors.sidebarAccentForeground : this.theme.colors.sidebarForeground
      })
      Text(this.item.title)
        .fontSize(this.theme.text.sm)
        .fontWeight(this.active ? this.theme.text.weightMedium : this.theme.text.weightNormal)
        .fontColor(this.active ? this.theme.colors.sidebarAccentForeground : this.theme.colors.sidebarForeground)
    }
    .width('100%')
    .height(34)
    .padding({ left: 10, right: 10 })
    .borderRadius(this.theme.radiusMd)
    // pressed comes from the system pressed state, never from onTouch (no lingering highlight)
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => this.onSelect(this.item.id))
    .accessibilityText(this.item.title)
    .accessibilitySelected(this.active)
  }
}

/** Docs navigation (rendered in the fixed sidebar on wide screens and inside a Sheet on compact ones). */
@ComponentV2
export struct GalleryNav {
  @Param current: string = 'intro';
  @Event onSelect: (id: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 20 }) {
      ForEach(NAV, (g: NavGroup) => {
        Column({ space: 2 }) {
          Text(g.title)
            .fontSize(this.theme.text.xs)
            .fontWeight(this.theme.text.weightMedium)
            .fontColor(this.theme.colors.mutedForeground)
            .padding({ left: 10, bottom: 6 })
          ForEach(g.items, (item: NavItem) => {
            NavLink({ item: item, active: item.id === this.current, onSelect: (id: string) => this.onSelect(id) })
          }, (item: NavItem) => item.id)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }, (g: NavGroup) => g.title)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
