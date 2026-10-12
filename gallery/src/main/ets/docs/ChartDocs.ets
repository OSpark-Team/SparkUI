import {
  SAreaChart, SBarChart, SButton, SCard, SCardContent, SCardDescription, SCardFooter, SCardHeader, SCardTitle,
  SChartContainer, SDonutChart, SIcon, SLineChart, SPieChart, SRadarChart, SRadialChart, SSparkline,
  SparkChartConfig, SparkChartRow, SparkChartSeries, sparkEmptyBuilder, SparkTheme, SparkUI, SToggleGroup,
  SToggleGroupItem
} from '@ospark/sparkui';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

// ------------------------------------------------------------------------------------------------ data

const MONTHS: SparkChartRow[] = [
  new SparkChartRow('January', { 'desktop': 186, 'mobile': 80 }),
  new SparkChartRow('February', { 'desktop': 305, 'mobile': 200 }),
  new SparkChartRow('March', { 'desktop': 237, 'mobile': 120 }),
  new SparkChartRow('April', { 'desktop': 73, 'mobile': 190 }),
  new SparkChartRow('May', { 'desktop': 209, 'mobile': 130 }),
  new SparkChartRow('June', { 'desktop': 214, 'mobile': 140 })
];

const DEVICES: SparkChartConfig = new SparkChartConfig([
  new SparkChartSeries('desktop', 'Desktop', 'chart-1'),
  new SparkChartSeries('mobile', 'Mobile', 'chart-2')
]);

const DESKTOP: SparkChartConfig = new SparkChartConfig([new SparkChartSeries('desktop', 'Desktop', 'chart-1')]);

const BROWSERS: SparkChartConfig = new SparkChartConfig([
  new SparkChartSeries('chrome', 'Chrome', 'chart-1'),
  new SparkChartSeries('safari', 'Safari', 'chart-2'),
  new SparkChartSeries('firefox', 'Firefox', 'chart-3'),
  new SparkChartSeries('edge', 'Edge', 'chart-4'),
  new SparkChartSeries('other', 'Other', 'chart-5')
]);

const BROWSER_ROWS: SparkChartRow[] = [
  new SparkChartRow('chrome', { 'visitors': 275 }),
  new SparkChartRow('safari', { 'visitors': 200 }),
  new SparkChartRow('firefox', { 'visitors': 187 }),
  new SparkChartRow('edge', { 'visitors': 173 }),
  new SparkChartRow('other', { 'visitors': 90 })
];

const SAFARI_ONLY: SparkChartRow[] = [new SparkChartRow('safari', { 'visitors': 200 })];

const PROFIT: SparkChartRow[] = [
  new SparkChartRow('January', { 'visitors': 186 }),
  new SparkChartRow('February', { 'visitors': 205 }),
  new SparkChartRow('March', { 'visitors': -207 }),
  new SparkChartRow('April', { 'visitors': 173 }),
  new SparkChartRow('May', { 'visitors': -209 }),
  new SparkChartRow('June', { 'visitors': 214 })
];

const VISITORS: SparkChartConfig = new SparkChartConfig([new SparkChartSeries('visitors', 'Visitors', 'chart-1')]);

function shortMonth(s: string): string {
  return s.substring(0, 3);
}

function randomMonths(): SparkChartRow[] {
  return MONTHS.map((r: SparkChartRow) => new SparkChartRow(r.label, {
    'desktop': Math.round(60 + Math.random() * 260),
    'mobile': Math.round(40 + Math.random() * 200)
  }));
}

/** A shadcn-gallery style chart card: title, description, chart, trend footer. */
@ComponentV2
struct ChartCard {
  @Param title: string = '';
  @Param description: string = 'January - June 2024';
  @Param trend: string = 'Trending up by 5.2% this month';
  @Param note: string = 'Showing total visitors for the last 6 months';
  @Param maxW: number = 520;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column() {
      SCard() {
        SCardHeader() {
          SCardTitle({ text: this.title })
          SCardDescription({ text: this.description })
        }
        SCardContent() {
          this.content()
        }
        SCardFooter() {
          Column({ space: 4 }) {
            Row({ space: 6 }) {
              Text(this.trend)
                .fontSize(this.theme.text.sm)
                .fontWeight(this.theme.text.weightMedium)
                .fontColor(this.theme.colors.foreground)
              SIcon({ name: 'trending-up', sizing: 16, color: this.theme.colors.foreground })
            }

            Text(this.note)
              .fontSize(this.theme.text.sm)
              .fontColor(this.theme.colors.mutedForeground)
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: this.maxW })
  }
}

// ------------------------------------------------------------------------------------------------ overview

const OVERVIEW_CODE = `// 1. describe the series (shadcn ChartConfig)
const config = new SparkChartConfig([
  new SparkChartSeries('desktop', 'Desktop', 'chart-1'),
  new SparkChartSeries('mobile', 'Mobile', 'chart-2')
]);
// 2. rows: a category label + a value per series key
const data: SparkChartRow[] = [
  new SparkChartRow('January', { 'desktop': 186, 'mobile': 80 }),
  new SparkChartRow('February', { 'desktop': 305, 'mobile': 200 }),
  // …
];

// 3. draw — the container shares legend toggles with the chart
SChartContainer({ config: config, legend: true }) {
  SBarChart({ config: config, data: this.data, labelFormatter: (s: string) => s.substring(0, 3) })
}`;

const SPARK_CODE = `SSparkline({ values: [12, 18, 15, 22, 19, 28, 26], color: 'chart-1' })
SSparkline({ values: [30, 26, 27, 21, 23, 18, 15], color: 'destructive', curve: 'linear' })`;

const EMPTY_CODE = `SChartContainer({ config: config, empty: rows.length === 0, emptyText: 'No data for this period' }) {
  SAreaChart({ config: config, data: rows })
}`;

@ComponentV2
export struct ChartsOverviewDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local data: SparkChartRow[] = MONTHS;

  @Builder
  stat(label: string, value: string, values: number[], color: string) {
    Column({ space: 6 }) {
      Text(label).fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)
      Text(value)
        .fontSize(this.theme.text.xl)
        .fontWeight(this.theme.text.weightSemibold)
        .fontColor(this.theme.colors.foreground)
      SSparkline({ values: values, color: color, chartHeight: 36 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(12)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Chart',
        lead: 'Beautiful charts drawn natively with ArkUI Path shapes, styled with the chart-1…5 tokens. ' +
          'Describe series once with SparkChartConfig; every chart measures its own width, thins its labels, ' +
          'animates in with motion key "chart", and shows a shadcn tooltip on hover, tap or horizontal pan.'
      })
      DemoBlock({ code: OVERVIEW_CODE }) {
        ChartCard({ title: 'Bar Chart - Legend', note: 'Tap a legend entry to hide a series; shuffle to morph' }) {
          Column({ space: 12 }) {
            SChartContainer({ config: DEVICES, legend: true }) {
              SBarChart({ config: DEVICES, data: this.data, labelFormatter: shortMonth })
            }
            SButton({ text: 'Shuffle data', variant: 'outline', sizing: 'sm', icon: 'refresh-cw' })
              .onClick(() => {
                this.data = randomMonths();
              })
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
      DocSection({
        title: 'Responsive',
        description: 'No breakpoints: cartesian charts default to a 16:9 box of their own width (160–320vp), ' +
          'skip category labels that would overlap and adapt the number of value ticks to the height.'
      })
      DocSection({ title: 'Sparkline', description: 'A tiny inline trend for stat cards and table cells.' })
      DemoBlock({ code: SPARK_CODE }) {
        Row({ space: 12 }) {
          this.stat('Revenue', '$45,231', [12, 18, 15, 22, 19, 28, 26], 'chart-1')
          this.stat('Churn', '2.4%', [30, 26, 27, 21, 23, 18, 15], 'destructive')
        }
        .width('100%')
        .constraintSize({ maxWidth: 520 })
      }
      DocSection({ title: 'Empty state', description: 'SChartContainer({ empty }) shows a muted placeholder.' })
      DemoBlock({ code: EMPTY_CODE }) {
        Column() {
          SChartContainer({ config: DEVICES, empty: true, emptyText: 'No data for this period', emptyHeight: 160 }) {
            SAreaChart({ config: DEVICES, data: [] })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 520 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ line

const LINE_CODE = `SLineChart({ config: config, data: rows, labelFormatter: (s: string) => s.substring(0, 3) })`;
const LINE_LINEAR_CODE = `SLineChart({ config: config, data: rows, curve: 'linear', dots: true })`;
const LINE_STEP_CODE = `SLineChart({ config: config, data: rows, curve: 'step' })`;
const LINE_MULTI_CODE = `SLineChart({ config: devices, data: rows, valueAxis: true, legend: true, dots: true })`;

@ComponentV2
export struct LineChartDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Line Chart', lead: 'Trends over categories; monotone ("natural"), linear or step curves.' })
      DemoBlock({ code: LINE_CODE }) {
        ChartCard({ title: 'Line Chart' }) {
          SLineChart({ config: DESKTOP, data: MONTHS, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Linear with dots' })
      DemoBlock({ code: LINE_LINEAR_CODE }) {
        ChartCard({ title: 'Line Chart - Linear' }) {
          SLineChart({ config: DESKTOP, data: MONTHS, curve: 'linear', dots: true, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Step' })
      DemoBlock({ code: LINE_STEP_CODE }) {
        ChartCard({ title: 'Line Chart - Step' }) {
          SLineChart({ config: DESKTOP, data: MONTHS, curve: 'step', labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Multiple', description: 'Several series, value axis, legend (tap to toggle).' })
      DemoBlock({ code: LINE_MULTI_CODE }) {
        ChartCard({ title: 'Line Chart - Multiple' }) {
          SLineChart({
            config: DEVICES, data: MONTHS, valueAxis: true, legend: true, dots: true, labelFormatter: shortMonth
          })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ area

const AREA_CODE = `SAreaChart({ config: config, data: rows, indicator: 'line' })`;
const AREA_STACKED_CODE = `SAreaChart({ config: devices, data: rows, stacked: true, legend: true })`;
const AREA_GRADIENT_CODE = `SAreaChart({ config: devices, data: rows, stacked: true, gradient: true })`;
const AREA_AXES_CODE = `SAreaChart({ config: devices, data: rows, curve: 'linear', valueAxis: true })`;

@ComponentV2
export struct AreaChartDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Area Chart', lead: 'Filled areas, optionally stacked or with a gradient fill.' })
      DemoBlock({ code: AREA_CODE }) {
        ChartCard({ title: 'Area Chart' }) {
          SAreaChart({ config: DESKTOP, data: MONTHS, indicator: 'line', labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Stacked' })
      DemoBlock({ code: AREA_STACKED_CODE }) {
        ChartCard({ title: 'Area Chart - Stacked' }) {
          SAreaChart({ config: DEVICES, data: MONTHS, stacked: true, legend: true, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Gradient' })
      DemoBlock({ code: AREA_GRADIENT_CODE }) {
        ChartCard({ title: 'Area Chart - Gradient' }) {
          SAreaChart({ config: DEVICES, data: MONTHS, stacked: true, gradient: true, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Axes' })
      DemoBlock({ code: AREA_AXES_CODE }) {
        ChartCard({ title: 'Area Chart - Axes' }) {
          SAreaChart({ config: DEVICES, data: MONTHS, curve: 'linear', valueAxis: true, labelFormatter: shortMonth })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ bar

const BAR_CODE = `SBarChart({ config: config, data: rows, labelFormatter: (s: string) => s.substring(0, 3) })`;
const BAR_MULTI_CODE = `SBarChart({ config: devices, data: rows, indicator: 'dashed' })`;
const BAR_STACKED_CODE = `SBarChart({ config: devices, data: rows, stacked: true, legend: true })`;
const BAR_HORIZONTAL_CODE = `SBarChart({ config: config, data: rows, horizontal: true, valueAxis: true })`;
const BAR_NEGATIVE_CODE = `SBarChart({ config: visitors, data: profit, valueAxis: true, barRadius: 4 })`;
const BAR_INTERACTIVE_CODE = `@Local series: string = 'desktop';

SToggleGroup({ type: 'single', value: [this.series], onValueChange: … }) {
  SToggleGroupItem({ value: 'desktop', text: 'Desktop' })
  SToggleGroupItem({ value: 'mobile', text: 'Mobile' })
}
SBarChart({ config: this.series === 'desktop' ? desktopConfig : mobileConfig, data: rows })`;

const MOBILE: SparkChartConfig = new SparkChartConfig([new SparkChartSeries('mobile', 'Mobile', 'chart-2')]);

@ComponentV2
export struct BarChartDoc {
  @Local series: string = 'desktop';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Bar Chart',
        lead: 'Grouped or stacked bars, vertical or horizontal, with rounded corners (--radius-md by default).'
      })
      DemoBlock({ code: BAR_CODE }) {
        ChartCard({ title: 'Bar Chart' }) {
          SBarChart({ config: DESKTOP, data: MONTHS, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Multiple' })
      DemoBlock({ code: BAR_MULTI_CODE }) {
        ChartCard({ title: 'Bar Chart - Multiple' }) {
          SBarChart({ config: DEVICES, data: MONTHS, indicator: 'dashed', labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Stacked + legend', description: 'Only the outer ends of a stack are rounded.' })
      DemoBlock({ code: BAR_STACKED_CODE }) {
        ChartCard({ title: 'Bar Chart - Stacked + Legend' }) {
          SBarChart({ config: DEVICES, data: MONTHS, stacked: true, legend: true, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Horizontal' })
      DemoBlock({ code: BAR_HORIZONTAL_CODE }) {
        ChartCard({ title: 'Bar Chart - Horizontal' }) {
          SBarChart({ config: DESKTOP, data: MONTHS, horizontal: true, valueAxis: true, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Negative', description: 'Bars grow from the zero line in both directions.' })
      DemoBlock({ code: BAR_NEGATIVE_CODE }) {
        ChartCard({ title: 'Bar Chart - Negative' }) {
          SBarChart({ config: VISITORS, data: PROFIT, valueAxis: true, barRadius: 4, labelFormatter: shortMonth })
        }
      }
      DocSection({ title: 'Interactive', description: 'Switching the series grows the new bars in.' })
      DemoBlock({ code: BAR_INTERACTIVE_CODE }) {
        ChartCard({ title: 'Bar Chart - Interactive' }) {
          Column({ space: 12 }) {
            SToggleGroup({
              type: 'single', variant: 'outline', sizing: 'sm', deselectable: false, value: [this.series],
              onValueChange: (v: string[]) => {
                if (v.length > 0) {
                  this.series = v[0];
                }
              }
            }) {
              SToggleGroupItem({ value: 'desktop', text: 'Desktop' })
              SToggleGroupItem({ value: 'mobile', text: 'Mobile' })
            }
            SBarChart({
              config: this.series === 'desktop' ? DESKTOP : MOBILE, data: MONTHS, labelFormatter: shortMonth
            })
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ pie

const PIE_CODE = `// row label = slice key in the config (label + colour)
SPieChart({ config: browsers, data: rows, valueKey: 'visitors' })`;
const DONUT_CODE = `SDonutChart({ config: browsers, data: rows, valueKey: 'visitors', centerValue: '1,125', centerLabel: 'Visitors' })`;
const PIE_LEGEND_CODE = `SPieChart({ config: browsers, data: rows, valueKey: 'visitors', padAngle: 2, legend: true })`;

@ComponentV2
export struct PieChartDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Pie Chart',
        lead: 'Pie and donut charts. Slices sweep in, the hovered / tapped slice grows, the legend toggles slices.'
      })
      DemoBlock({ code: PIE_CODE }) {
        ChartCard({ title: 'Pie Chart', maxW: 400 }) {
          SPieChart({ config: BROWSERS, data: BROWSER_ROWS, valueKey: 'visitors' })
        }
      }
      DocSection({ title: 'Donut with text' })
      DemoBlock({ code: DONUT_CODE }) {
        ChartCard({ title: 'Pie Chart - Donut with Text', maxW: 400 }) {
          SDonutChart({
            config: BROWSERS, data: BROWSER_ROWS, valueKey: 'visitors', centerValue: '1,125', centerLabel: 'Visitors'
          })
        }
      }
      DocSection({ title: 'Separated + legend' })
      DemoBlock({ code: PIE_LEGEND_CODE }) {
        ChartCard({ title: 'Pie Chart - Legend', maxW: 400 }) {
          SPieChart({ config: BROWSERS, data: BROWSER_ROWS, valueKey: 'visitors', padAngle: 2, legend: true })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ radial

const RADIAL_CODE = `SRadialChart({ config: browsers, data: rows, valueKey: 'visitors' })`;
const RADIAL_TEXT_CODE = `SRadialChart({
  config: browsers, data: [new SparkChartRow('safari', { 'visitors': 200 })], valueKey: 'visitors',
  maxValue: 280, endAngle: 250, innerRatio: 0.7, centerValue: '200', centerLabel: 'Visitors'
})`;
const RADIAL_SHAPE_CODE = `SRadialChart({ config: browsers, data: rows, valueKey: 'visitors', endAngle: 270, rounded: false, track: false })`;

@ComponentV2
export struct RadialChartDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Radial Chart', lead: 'Concentric radial bars with an optional track and centre label.' })
      DemoBlock({ code: RADIAL_CODE }) {
        ChartCard({ title: 'Radial Chart', maxW: 400 }) {
          SRadialChart({ config: BROWSERS, data: BROWSER_ROWS, valueKey: 'visitors' })
        }
      }
      DocSection({ title: 'Text' })
      DemoBlock({ code: RADIAL_TEXT_CODE }) {
        ChartCard({ title: 'Radial Chart - Text', maxW: 400 }) {
          SRadialChart({
            config: BROWSERS, data: SAFARI_ONLY, valueKey: 'visitors', maxValue: 280, endAngle: 250,
            innerRatio: 0.7, centerValue: '200', centerLabel: 'Visitors'
          })
        }
      }
      DocSection({ title: 'Shape', description: 'Partial sweep, square ends, no track.' })
      DemoBlock({ code: RADIAL_SHAPE_CODE }) {
        ChartCard({ title: 'Radial Chart - Shape', maxW: 400 }) {
          SRadialChart({
            config: BROWSERS, data: BROWSER_ROWS, valueKey: 'visitors', endAngle: 270, rounded: false, track: false
          })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ radar

const RADAR_CODE = `SRadarChart({ config: config, data: rows })`;
const RADAR_DOTS_CODE = `SRadarChart({ config: config, data: rows, dots: true, gridShape: 'circle' })`;
const RADAR_MULTI_CODE = `SRadarChart({ config: devices, data: rows, legend: true })`;
const RADAR_LINES_CODE = `SRadarChart({ config: devices, data: rows, fillAlpha: 0, lineWidth: 2 })`;

@ComponentV2
export struct RadarChartDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Radar Chart',
        lead: 'One spoke per category; polygons grow from the centre. Labels hide when the chart gets too small.'
      })
      DemoBlock({ code: RADAR_CODE }) {
        ChartCard({ title: 'Radar Chart', maxW: 400 }) {
          SRadarChart({ config: DESKTOP, data: MONTHS })
        }
      }
      DocSection({ title: 'Dots + circle grid' })
      DemoBlock({ code: RADAR_DOTS_CODE }) {
        ChartCard({ title: 'Radar Chart - Dots', maxW: 400 }) {
          SRadarChart({ config: DESKTOP, data: MONTHS, dots: true, gridShape: 'circle' })
        }
      }
      DocSection({ title: 'Multiple + legend' })
      DemoBlock({ code: RADAR_MULTI_CODE }) {
        ChartCard({ title: 'Radar Chart - Multiple', maxW: 400 }) {
          SRadarChart({ config: DEVICES, data: MONTHS, legend: true })
        }
      }
      DocSection({ title: 'Lines only' })
      DemoBlock({ code: RADAR_LINES_CODE }) {
        ChartCard({ title: 'Radar Chart - Lines Only', maxW: 400 }) {
          SRadarChart({ config: DEVICES, data: MONTHS, fillAlpha: 0, lineWidth: 2 })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
