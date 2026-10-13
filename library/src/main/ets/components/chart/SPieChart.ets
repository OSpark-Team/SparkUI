import { SparkEnvironment } from '../../layout/SparkLayoutContext';
import { sparkText } from '../../core/SparkText';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SparkArc, sparkArcIndex, sparkChartFormat, sparkPieArcs, sparkShapeArcs, sparkTooltipPlace
} from './ChartMath';
import { SChartLegend, SChartPointer, SChartTooltipCard, sparkResolveChartState } from './ChartParts';
import { SChartPath, SparkChartVec } from './ChartShape';
import {
  SparkChartConfig, SparkChartIndicator, SparkChartRow, SparkChartState, SparkChartTooltipItem
} from './ChartTypes';

const EMPTY: SparkChartVec = new SparkChartVec([]);
/** extra radius of the active slice (shadcn "Pie Chart - Donut Active") */
const GROW: number = 8;

function defaultValue(v: number): string {
  return sparkChartFormat(v);
}

class PieSlice {
  key: string = '';
  label: string = '';
  color: string = '#FF000000';
  value: number = 0;
  row: number = 0;
  a0: number = 0;
  a1: number = 0;
}

class PieGeo {
  w: number = 0;
  h: number = 0;
  cx: number = 0;
  cy: number = 0;
  r0: number = 0;
  r1: number = 0;
  slices: PieSlice[] = [];
  keys: string[] = [];
  arcs: SparkArc[] = [];
}

const NO_SLICE: PieSlice = new PieSlice();

/**
 * shadcn "Pie Chart" / "Donut": one slice per data row (row label = slice key in `config`, which gives its
 * label and colour), sized by `valueKey`. Slices sweep in on appear and morph when data or the legend change.
 * Tap / hover a slice for its tooltip; the active slice grows (`activeGrow`).
 *
 * ```
 * SPieChart({ config: this.browsers, data: this.rows, valueKey: 'visitors' })
 * ```
 */
@ComponentV2
export struct SPieChart {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  /** the row value drawn as slice size */
  @Param valueKey: string = 'value';
  /** inner radius as a fraction of the outer radius (0 = pie, ~0.6 = donut) */
  @Param innerRatio: number = 0;
  /** gap between slices in degrees */
  @Param padAngle: number = 0;
  /** maximum diameter in vp (the chart is square and never wider than its container) */
  @Param chartHeight: number = 250;
  /** big text in the middle of a donut (e.g. the total) */
  @Param centerValue: string = '';
  @Param centerLabel: string = '';
  @Param activeGrow: boolean = true;
  @Param tooltip: boolean = true;
  @Param legend: boolean = false;
  @Param indicator: SparkChartIndicator = 'dot';
  @Param valueFormatter: (value: number) => string = defaultValue;
  @Param emptyText: ResourceStr = $r('app.string.spark_no_data');
  @Event onActiveChange: (index: number) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local own: SparkChartState = new SparkChartState();
  @Local ctx: SparkChartState | undefined = undefined;
  @Local measuredWidth: number = 0;
  @Local pxRatio: number = 1;
  /** window density (px per vp) — chart paths are in px and must be rebuilt when it changes */
  @Local sparkEnv: SparkEnvironment = SparkUI.layout.env;

  @Monitor('sparkEnv.pxPerVp')
  syncDensity(): void {
    this.pxRatio = this.getUIContext().vp2px(1);
  }
  /** data row index of the active slice */
  @Local active: number = -1;
  @Local pointerX: number = 0;
  @Local pointerY: number = 0;
  @Local tipW: number = 0;
  @Local tipH: number = 0;
  @Local morph: boolean = true;

  aboutToAppear(): void {
    this.pxRatio = this.getUIContext().vp2px(1);
    this.own.subscribe(this.getUniqueId(), () => this.morph = true);
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  aboutToDisappear(): void {
    this.own.unsubscribe(this.getUniqueId());
    this.ctx?.unsubscribe(this.getUniqueId());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = sparkResolveChartState(this.getUIContext(), this.getUniqueId());
      this.ctx?.subscribe(this.getUniqueId(), () => this.morph = true);
    }
  }

  @Monitor('data', 'config', 'valueKey', 'innerRatio', 'padAngle')
  onData(): void {
    this.morph = true;
    if (this.active >= this.data.length) {
      this.active = -1;
    }
  }

  private st(): SparkChartState {
    return this.ctx ?? this.own;
  }

  private diameter(): number {
    if (this.measuredWidth <= 0) {
      return this.chartHeight;
    }
    return Math.max(80, Math.min(this.chartHeight, this.measuredWidth));
  }

  @Computed
  get geo(): PieGeo {
    const g = new PieGeo();
    const W = this.measuredWidth;
    const D = this.diameter();
    g.w = W;
    g.h = D;
    if (W <= 0) {
      return g;
    }
    g.cx = W / 2;
    g.cy = D / 2;
    g.r1 = Math.max(4, D / 2 - (this.activeGrow ? GROW : 2));
    g.r0 = g.r1 * Math.max(0, Math.min(0.95, this.innerRatio));
    const st = this.st();
    const rows: number[] = [];
    this.data.forEach((r: SparkChartRow, i: number) => {
      if (!st.isHidden(r.label)) {
        rows.push(i);
      }
    });
    const values = rows.map((i: number) => this.data[i].value(this.valueKey));
    g.arcs = sparkPieArcs(values, 0, Math.PI * 2, this.padAngle * Math.PI / 180);
    rows.forEach((ri: number, j: number) => {
      const r = this.data[ri];
      const s = new PieSlice();
      s.key = r.label;
      s.label = this.config.label(r.label);
      s.color = this.config.color(this.theme, r.label, ri);
      s.value = values[j];
      s.row = ri;
      s.a0 = g.arcs[j].a0;
      s.a1 = g.arcs[j].a1;
      g.slices.push(s);
      g.keys.push(r.label);
    });
    return g;
  }

  private slice(key: string): PieSlice {
    for (const s of this.geo.slices) {
      if (s.key === key) {
        return s;
      }
    }
    return NO_SLICE;
  }

  private shapeOf(key: string): SparkChartVec {
    const g = this.geo;
    const s = this.slice(key);
    const grow = this.activeGrow && s.row === this.active && s.key.length > 0 ? GROW : 0;
    return new SparkChartVec(sparkShapeArcs([g.cx, g.cy, g.r0, g.r1 + grow, s.a0, s.a1, 0], this.pxRatio));
  }

  private fromOf(): SparkChartVec {
    const g = this.geo;
    return new SparkChartVec(sparkShapeArcs([g.cx, g.cy, g.r0, g.r1, 0, 0, 0], this.pxRatio));
  }

  @Computed
  get tipItems(): SparkChartTooltipItem[] {
    for (const s of this.geo.slices) {
      if (s.row === this.active) {
        return [new SparkChartTooltipItem(s.key, s.label, this.valueFormatter(s.value), s.color)];
      }
    }
    return [];
  }

  private hit(x: number, y: number): number {
    const g = this.geo;
    const j = sparkArcIndex(g.arcs, g.cx, g.cy, g.r0, g.r1, x, y, GROW);
    return j >= 0 && j < g.slices.length ? g.slices[j].row : -1;
  }

  private point(x: number, y: number): void {
    const i = this.hit(x, y);
    this.pointerX = x;
    this.pointerY = y;
    if (i !== this.active) {
      this.active = i;
      this.onActiveChange(i);
    }
  }

  private tap(x: number, y: number): void {
    const i = this.hit(x, y);
    if (i === this.active) {
      this.point(-1000, -1000);
    } else {
      this.point(x, y);
    }
  }

  build() {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.data.length === 0) {
          Text(this.emptyText)
            .width('100%')
            .height('100%')
            .textAlign(TextAlign.Center)
            .fontSize(this.theme.text.sm)
            .fontColor(this.theme.colors.mutedForeground)
        } else if (this.geo.w > 0) {
          ForEach(this.geo.keys, (key: string) => {
            SChartPath({
              shape: this.shapeOf(key), from: this.fromOf(), boxWidth: this.geo.w, boxHeight: this.geo.h,
              fillColor: this.slice(key).color, animate: this.morph
            })
          }, (key: string) => key)
          if (this.centerValue.length > 0 || this.centerLabel.length > 0) {
            Column({ space: 2 }) {
              if (this.centerValue.length > 0) {
                Text(this.centerValue)
                  .fontSize(this.theme.text.xxxl)
                  .fontWeight(this.theme.text.weightBold)
                  .fontColor(this.theme.colors.foreground)
                  .maxLines(1)
              }
              if (this.centerLabel.length > 0) {
                Text(this.centerLabel)
                  .fontSize(this.theme.text.sm)
                  .fontColor(this.theme.colors.mutedForeground)
                  .maxLines(1)
              }
            }
            .width(this.geo.w)
            .height(this.geo.h)
            .justifyContent(FlexAlign.Center)
            .hitTestBehavior(HitTestMode.Transparent)
          }
          SChartPointer({
            scrub: false, boxWidth: this.geo.w, boxHeight: this.geo.h,
            onPoint: (x: number, y: number) => this.point(x, y),
            onTap: (x: number, y: number) => this.tap(x, y),
            onLeave: () => this.point(-1000, -1000)
          })
          if (this.tooltip && this.active >= 0 && this.tipItems.length > 0) {
            Column() {
              SChartTooltipCard({ title: '', items: this.tipItems, indicator: this.indicator })
            }
            .position({
              x: sparkTooltipPlace(this.pointerX, this.pointerY, this.tipW, this.tipH, this.geo.w, this.geo.h, 12)[0],
              y: sparkTooltipPlace(this.pointerX, this.pointerY, this.tipW, this.tipH, this.geo.w, this.geo.h, 12)[1]
            })
            .hitTestBehavior(HitTestMode.None)
            .onAreaChange((_: Area, a: Area) => {
              this.tipW = Number(a.width);
              this.tipH = Number(a.height);
            })
          }
        }
      }
      .width('100%')
      .height(this.diameter())
      .accessibilityText(this.centerLabel.length > 0 ? `${this.centerValue} ${this.centerLabel}` : sparkText(this.getUIContext(), $r('app.string.spark_pie_chart'), 'pie chart'))
      .onAreaChange((_: Area, a: Area) => {
        const w = Number(a.width);
        if (Math.abs(w - this.measuredWidth) > 0.5) {
          this.morph = false;
          this.measuredWidth = w;
        }
      })

      if (this.legend) {
        SChartLegend({
          config: this.config, state: this.st(), keys: this.data.map((r: SparkChartRow) => r.label),
          compact: this.measuredWidth < 360
        })
      }
    }
    .width('100%')
  }
}

/** SPieChart with a hole (`innerRatio` 0.6) and an optional centre label (shadcn "Pie Chart - Donut Text"). */
@ComponentV2
export struct SDonutChart {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  @Param valueKey: string = 'value';
  @Param innerRatio: number = 0.6;
  @Param padAngle: number = 0;
  @Param chartHeight: number = 250;
  @Param centerValue: string = '';
  @Param centerLabel: string = '';
  @Param activeGrow: boolean = true;
  @Param tooltip: boolean = true;
  @Param legend: boolean = false;
  @Param indicator: SparkChartIndicator = 'dot';
  @Param valueFormatter: (value: number) => string = defaultValue;
  @Param emptyText: ResourceStr = $r('app.string.spark_no_data');
  @Event onActiveChange: (index: number) => void = () => {
  };

  build() {
    Column() {
      SPieChart({
        config: this.config, data: this.data, valueKey: this.valueKey, innerRatio: this.innerRatio,
        padAngle: this.padAngle, chartHeight: this.chartHeight, centerValue: this.centerValue,
        centerLabel: this.centerLabel, activeGrow: this.activeGrow, tooltip: this.tooltip, legend: this.legend,
        indicator: this.indicator, valueFormatter: this.valueFormatter, emptyText: this.emptyText,
        onActiveChange: (i: number) => this.onActiveChange(i)
      })
    }
    .width('100%')
  }
}
