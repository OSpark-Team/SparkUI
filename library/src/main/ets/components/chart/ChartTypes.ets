import { SparkTheme } from '../../theme/tokens/SparkTheme';

/** Tooltip colour indicator (shadcn `ChartTooltipContent indicator`). */
export type SparkChartIndicator = 'dot' | 'line' | 'dashed';

/** Where SChartContainer puts its legend. */
export type SparkChartLegendPlacement = 'top' | 'bottom';

const DEFAULT_TOKENS: string[] = ['chart-1', 'chart-2', 'chart-3', 'chart-4', 'chart-5'];

/**
 * Resolve a chart colour: '#RRGGBB' / '#AARRGGBB' are used as is, anything else is a theme token name
 * ('chart-1' … 'chart-5', 'primary', 'muted-foreground' …).
 */
export function sparkChartColor(theme: SparkTheme, color: string, index: number): string {
  if (color.startsWith('#')) {
    return color.length === 7 ? '#FF' + color.substring(1) : color;
  }
  const c = color.length > 0 ? theme.colors.get(color) : undefined;
  if (c !== undefined) {
    return c;
  }
  const n = DEFAULT_TOKENS.length;
  return theme.colors.get(DEFAULT_TOKENS[((index % n) + n) % n]) ?? theme.colors.chart1;
}

/**
 * One data series of a chart (an entry of shadcn's `ChartConfig`): the key it reads from every row,
 * a display label and a colour (token name or hex; empty → chart-1…5 by position).
 */
export class SparkChartSeries {
  key: string;
  label: string;
  color: string;

  constructor(key: string, label?: string, color?: string) {
    this.key = key;
    this.label = label ?? key;
    this.color = color ?? '';
  }
}

/** shadcn `ChartConfig`: series labels and colours, shared by the chart, its tooltip and its legend. */
export class SparkChartConfig {
  series: SparkChartSeries[];

  constructor(series: SparkChartSeries[]) {
    this.series = series;
  }

  indexOf(key: string): number {
    for (let i = 0; i < this.series.length; i++) {
      if (this.series[i].key === key) {
        return i;
      }
    }
    return -1;
  }

  label(key: string): string {
    const i = this.indexOf(key);
    return i >= 0 ? this.series[i].label : key;
  }

  /** Colour of `key`; unknown keys get chart-1…5 by `fallbackIndex`. */
  color(theme: SparkTheme, key: string, fallbackIndex?: number): string {
    const i = this.indexOf(key);
    if (i >= 0) {
      return sparkChartColor(theme, this.series[i].color, i);
    }
    return sparkChartColor(theme, '', fallbackIndex ?? 0);
  }

  keys(): string[] {
    return this.series.map((s: SparkChartSeries) => s.key);
  }
}

/**
 * One category of data: a label ('January', 'chrome' …) and a value per series key.
 * ArkTS needs quoted keys in the record literal: `new SparkChartRow('January', { 'desktop': 186, 'mobile': 80 })`.
 */
export class SparkChartRow {
  label: string;
  values: Record<string, number>;

  constructor(label: string, values: Record<string, number>) {
    this.label = label;
    this.values = values;
  }

  /** value of `key`, 0 when missing / not a number */
  value(key: string): number {
    const v: number | undefined = this.values[key];
    return v === undefined || !isFinite(v) ? 0 : v;
  }
}

/** One line of the tooltip card. */
export class SparkChartTooltipItem {
  key: string;
  label: string;
  value: string;
  color: string;

  constructor(key: string, label: string, value: string, color: string) {
    this.key = key;
    this.label = label;
    this.value = value;
    this.color = color;
  }
}

/**
 * Series visibility shared by a chart and its legend (SChartContainer publishes one to the charts inside
 * it through SparkContext). `subscribe` lets charts react to toggles (morph instead of jump).
 */
@ObservedV2
export class SparkChartState {
  @Trace hidden: string[] = [];
  private listeners: Map<number, () => void> = new Map<number, () => void>();

  isHidden(key: string): boolean {
    return this.hidden.indexOf(key) >= 0;
  }

  toggle(key: string): void {
    this.listeners.forEach((fn: () => void) => fn());
    if (this.isHidden(key)) {
      this.hidden = this.hidden.filter((k: string) => k !== key);
    } else {
      this.hidden = this.hidden.concat([key]);
    }
  }

  subscribe(id: number, fn: () => void): void {
    this.listeners.set(id, fn);
  }

  unsubscribe(id: number): void {
    this.listeners.delete(id);
  }
}

export const SPARK_CHART_KEY: string = 'spark.chart';
