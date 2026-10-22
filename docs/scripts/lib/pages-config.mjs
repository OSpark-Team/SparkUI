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
  'time-picker': ['STimePicker'],
  'time-range-picker': ['STimeRangePicker'],
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

/**
 * Demos shown as code only (no web preview), keyed by gallery doc struct. `demos` is 'all' or a list of demo
 * indices within the doc. Use this for demos the web cannot reproduce faithfully — animation-centric demos,
 * window chrome and other platform features — instead of growing imitations in the previewer.
 * `zh` / `en` is the note shown under the page lead.
 */
export const CODE_ONLY = {
  TransitionDoc: {
    demos: 'all',
    reason: 'transitions are animations; the web previewer does not animate, so a preview would only show/hide content',
    zh: '过渡完全是动画效果，网页预览无法还原，本页示例只展示代码。请在 HarmonyOS 设备或画廊应用中查看实际效果。',
    en: 'Transitions are pure animation, which the web preview cannot reproduce, so the examples on this page show code only. See them on a HarmonyOS device or in the gallery app.'
  },
  TitleBarDoc: {
    demos: 'all',
    reason: 'window chrome (caption buttons, dragging, maximize, decor APIs) only exists in a HarmonyOS free window',
    zh: '标题栏属于窗口装饰（窗口按钮、拖动、最大化、系统标题栏 API），只存在于 HarmonyOS 的自由窗口中，本页示例只展示代码。',
    en: 'The title bar is window chrome (caption buttons, dragging, maximize, decor APIs) that only exists in a HarmonyOS free window, so the examples on this page show code only.'
  }
};

/** True when demo `index` of gallery doc `docName` is code only. */
export function isCodeOnly(docName, index) {
  const c = CODE_ONLY[docName];
  return !!c && (c.demos === 'all' || c.demos.includes(index));
}

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
  note: '从组件库源码中的 <code>@Param</code> / <code>@Event</code> / <code>@BuilderParam</code> 声明自动提取。',
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
    usage: '基础用法',
    overview: { title: '组件总览', lead: '所有组件按画廊（gallery）的分组排列。示例附带可交互的网页近似预览与 ArkTS 源码；少数无法在网页上还原的示例（过渡动画、窗口标题栏）只展示代码。' }
  },
  {
    code: 'en',
    dir: 'en',
    prefix: '/en/',
    api: API_EN,
    usage: 'Usage',
    overview: {
      title: 'Components',
      lead: 'Every component, grouped like the gallery app. Examples come with an approximate interactive web preview and their ArkTS source; the few that the web cannot reproduce (transition animations, the window title bar) show code only.'
    }
  }
];
