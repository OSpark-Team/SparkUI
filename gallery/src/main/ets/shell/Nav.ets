import { SparkShellNavGroup, SparkShellNavItem, sparkShellNavTitle } from '@sparkui/core';

/**
 * Gallery routes: every page id rendered by DocContent (pages/Index.ets), grouped for the SAppShell sidebar.
 * The gallery has no router: the active id is the SAppShell `value` (persisted), DocContent switches on it.
 */
export const NAV: SparkShellNavGroup[] = [
  new SparkShellNavGroup('Getting Started', [
    new SparkShellNavItem('intro', 'Introduction', 'book-open'),
    new SparkShellNavItem('theming', 'Theming', 'palette'),
    new SparkShellNavItem('responsive', 'Responsive Layout', 'layout-grid'),
    new SparkShellNavItem('layout', 'Adaptive Context', 'layout-dashboard')
  ]),
  new SparkShellNavGroup('Foundations', [
    new SparkShellNavItem('icons', 'Icons', 'sparkles'),
    new SparkShellNavItem('code', 'Code Block', 'code'),
    new SparkShellNavItem('transition', 'Transition', 'play')
  ]),
  new SparkShellNavGroup('Blocks', [
    new SparkShellNavItem('app-shell', 'App Shell', 'layout-dashboard'),
    new SparkShellNavItem('sidebar', 'Sidebar', 'panel-left'),
    new SparkShellNavItem('topbar', 'Top Bar', 'menu'),
    new SparkShellNavItem('list-detail', 'List Detail', 'mail'),
    new SparkShellNavItem('supporting-pane', 'Supporting Pane', 'panel-right'),
    new SparkShellNavItem('dashboard-grid', 'Dashboard Grid', 'chart-pie'),
    new SparkShellNavItem('title-bar', 'Title Bar', 'laptop')
  ]),
  new SparkShellNavGroup('Charts', [
    new SparkShellNavItem('charts', 'Chart', 'activity'),
    new SparkShellNavItem('area-chart', 'Area Chart', 'trending-up'),
    new SparkShellNavItem('bar-chart', 'Bar Chart', 'chart-bar'),
    new SparkShellNavItem('line-chart', 'Line Chart', 'chart-line'),
    new SparkShellNavItem('pie-chart', 'Pie Chart', 'chart-pie'),
    new SparkShellNavItem('radar-chart', 'Radar Chart', 'star'),
    new SparkShellNavItem('radial-chart', 'Radial Chart', 'circle')
  ]),
  new SparkShellNavGroup('Components', [
    new SparkShellNavItem('alert', 'Alert', 'circle-alert'),
    new SparkShellNavItem('aspect-ratio', 'Aspect Ratio', 'image'),
    new SparkShellNavItem('avatar', 'Avatar', 'user-round'),
    new SparkShellNavItem('badge', 'Badge', 'tag'),
    new SparkShellNavItem('button', 'Button', 'square'),
    new SparkShellNavItem('card', 'Card', 'layout-list'),
    new SparkShellNavItem('empty', 'Empty', 'inbox'),
    new SparkShellNavItem('item', 'Item', 'list'),
    new SparkShellNavItem('separator', 'Separator & Kbd', 'command'),
    new SparkShellNavItem('skeleton', 'Skeleton & Spinner', 'loader-circle'),
    new SparkShellNavItem('table', 'Table', 'table'),
    new SparkShellNavItem('typography', 'Typography', 'type')
  ]),
  new SparkShellNavGroup('Navigation', [
    new SparkShellNavItem('accordion', 'Accordion', 'chevrons-up-down'),
    new SparkShellNavItem('breadcrumb', 'Breadcrumb', 'chevron-right'),
    new SparkShellNavItem('button-group', 'Button Group', 'ellipsis'),
    new SparkShellNavItem('collapsible', 'Collapsible', 'chevron-down'),
    new SparkShellNavItem('pagination', 'Pagination', 'chevrons-right'),
    new SparkShellNavItem('scroll-area', 'Scroll Area', 'move'),
    new SparkShellNavItem('stepper', 'Stepper', 'list'),
    new SparkShellNavItem('tabs', 'Tabs', 'layout-grid'),
    new SparkShellNavItem('toggle', 'Toggle & Group', 'bold')
  ]),
  new SparkShellNavGroup('Forms', [
    new SparkShellNavItem('calendar', 'Calendar', 'calendar'),
    new SparkShellNavItem('checkbox', 'Checkbox', 'square-check'),
    new SparkShellNavItem('date-picker', 'Date Picker', 'calendar-days'),
    new SparkShellNavItem('field', 'Field', 'text-align-start'),
    new SparkShellNavItem('input', 'Input & Label', 'type'),
    new SparkShellNavItem('input-group', 'Input Group', 'search'),
    new SparkShellNavItem('number-field', 'Number Field', 'plus'),
    new SparkShellNavItem('pin-input', 'Pin Input', 'key'),
    new SparkShellNavItem('progress', 'Progress', 'loader'),
    new SparkShellNavItem('radio-group', 'Radio Group', 'circle'),
    new SparkShellNavItem('slider', 'Slider', 'sliders-horizontal'),
    new SparkShellNavItem('switch', 'Switch', 'toggle-right'),
    new SparkShellNavItem('tags-input', 'Tags Input', 'tag'),
    new SparkShellNavItem('textarea', 'Textarea', 'text-align-start')
  ]),
  new SparkShellNavGroup('Overlays', [
    new SparkShellNavItem('alert-dialog', 'Alert Dialog', 'triangle-alert'),
    new SparkShellNavItem('combobox', 'Combobox', 'chevrons-up-down'),
    new SparkShellNavItem('command', 'Command', 'command'),
    new SparkShellNavItem('context-menu', 'Context Menu', 'ellipsis-vertical'),
    new SparkShellNavItem('dialog', 'Dialog', 'square-check'),
    new SparkShellNavItem('drawer', 'Drawer', 'panel-left-open'),
    new SparkShellNavItem('dropdown-menu', 'Dropdown Menu', 'menu'),
    new SparkShellNavItem('hover-card', 'Hover Card', 'user-round'),
    new SparkShellNavItem('menubar', 'Menubar', 'menu'),
    new SparkShellNavItem('popover', 'Popover', 'message-square'),
    new SparkShellNavItem('select', 'Select', 'chevrons-up-down'),
    new SparkShellNavItem('sheet', 'Sheet', 'panel-left'),
    new SparkShellNavItem('toast', 'Toast', 'bell'),
    new SparkShellNavItem('tooltip', 'Tooltip', 'info')
  ])
];

/** Title of a page id ('' when unknown). */
export function navTitle(id: string): string {
  return sparkShellNavTitle(NAV, id);
}

/** Group title of a page id ('' when unknown). */
export function navGroupTitle(id: string): string {
  for (const g of NAV) {
    for (const i of g.items) {
      if (i.id === id) {
        return g.title;
      }
    }
  }
  return '';
}

/** Whether `id` is a known page (e.g. a persisted page id that may have been removed since). */
export function navHas(id: string): boolean {
  return navTitle(id).length > 0;
}

function flattenIds(nav: SparkShellNavGroup[]): string[] {
  const ids: string[] = [];
  nav.forEach((g: SparkShellNavGroup) => g.items.forEach((i: SparkShellNavItem) => ids.push(i.id)));
  return ids;
}

/** Page ids in sidebar order (SPageTransition `order`: moving down the list = forward, up = back). */
export const NAV_ORDER: string[] = flattenIds(NAV);
