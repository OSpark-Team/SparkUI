// Page-level configuration for generated component pages.

/** Gallery nav ids covered by the hand-written guides (docs/guide, docs/en/guide). */
export const GUIDE_PAGE_IDS = ['intro', 'theming', 'responsive', 'layout'];

/**
 * Structs documented on a page when they don't simply live in components/<id> or blocks/<id>.
 * Only structs exported from library/Index.ets are shown.
 */
export const PAGE_EXTRA_STRUCTS = {
  icons: ['SIcon'],
  code: ['SCodeBlock'],
  separator: ['SSeparator', 'SKbd', 'SKbdGroup'],
  skeleton: ['SSkeleton', 'SSpinner'],
  input: ['SInput', 'SLabel'],
  toggle: ['SToggle', 'SToggleGroup', 'SToggleGroupItem'],
  calendar: ['SCalendar', 'SRangeCalendar'],
  'date-picker': ['SDatePicker', 'SDateRangePicker'],
  'dashboard-grid': ['SDashboardGrid', 'SDashboardTile'],
  charts: ['SChartContainer', 'SChartLegend', 'SChartTooltipCard', 'SChartEmpty', 'SSparkline'],
  'area-chart': ['SAreaChart'],
  'bar-chart': ['SBarChart'],
  'line-chart': ['SLineChart'],
  'pie-chart': ['SPieChart', 'SDonutChart'],
  'radar-chart': ['SRadarChart'],
  'radial-chart': ['SRadialChart'],
  toast: ['SToastSlot']
};

const API_EN = {
  title: 'API',
  note: 'Extracted from the <code>@Param</code> / <code>@Event</code> / <code>@BuilderParam</code> declarations in the library sources.',
  props: 'Prop',
  events: 'Event',
  type: 'Type',
  default: 'Default',
  description: 'Description',
  required: 'required',
  bindTitle: 'Supports two-way binding with the !! syntax',
  slots: 'Slots',
  childrenSlot: 'children (trailing closure)',
  none: 'No props.'
};

const API_ZH = {
  title: 'API',
  note: '从组件库源码中的 <code>@Param</code> / <code>@Event</code> / <code>@BuilderParam</code> 声明自动提取，说明文字保持英文原文。',
  props: '属性',
  events: '事件',
  type: '类型',
  default: '默认值',
  description: '说明',
  required: '必填',
  bindTitle: '支持 !! 双向绑定',
  slots: '插槽',
  childrenSlot: '子组件（尾随闭包）',
  none: '无属性。'
};

/** zh is the root locale, en lives under /en/. */
export const LOCALES = [
  {
    code: 'zh',
    dir: '.',
    prefix: '/',
    api: API_ZH,
    overview: { title: '组件总览', lead: '所有组件按画廊（gallery）的分组排列。每个示例都附带可交互的网页近似预览与 ArkTS 源码。' }
  },
  {
    code: 'en',
    dir: 'en',
    prefix: '/en/',
    api: API_EN,
    overview: {
      title: 'Components',
      lead: 'Every component, grouped like the gallery app. Each example comes with an approximate interactive web preview and its ArkTS source.'
    }
  }
];
