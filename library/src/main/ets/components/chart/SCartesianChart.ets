import { SparkUI } from '../../core/SparkUI';
import { SparkContext } from '../../core/SparkContext';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SparkBandScale, sparkChartCompact, SparkChartCurve, sparkChartFormat, sparkLabelStep, SparkLinearScale,
  sparkNearestIndex, sparkNiceTicks, sparkPointPositions, sparkShapeArea, sparkShapeDots, sparkShapeLine,
  sparkShapeLines, sparkShapeRects, SparkStack, sparkStack, sparkTickCount, sparkTooltipPlace, sparkValueDomain
} from './ChartMath';
import {
  SChartLegend, SChartPointer, SChartTooltipCard, sparkChartTextWidth, sparkResolveChartState, sparkVisibleKeys
} from './ChartParts';
import { SChartGradient, SChartPath, SparkChartVec } from './ChartShape';
import {
  SparkChartConfig, SparkChartIndicator, SparkChartRow, SparkChartState, SparkChartTooltipItem
} from './ChartTypes';

export type SparkCartesianKind = 'line' | 'area' | 'bar';

const EMPTY: SparkChartVec = new SparkChartVec([]);
const LABEL_H: number = 16;

function identityLabel(s: string): string {
  return s;
}

function defaultValue(v: number): string {
  return sparkChartFormat(v);
}

/** Geometry of one series. */
class CartesianSeries {
  key: string = '';
  label: string = '';
  color: string = '#FF000000';
  shape: SparkChartVec = EMPTY;
  from: SparkChartVec = EMPTY;
  /** upper edge line of an area */
  edge: SparkChartVec = EMPTY;
  edgeFrom: SparkChartVec = EMPTY;
  dots: SparkChartVec = EMPTY;
  dotsFrom: SparkChartVec = EMPTY;
  /** value-axis coordinate per category (y for vertical charts) */
  points: number[] = [];
}

class AxisLabel {
  text: string;
  x: number;
  y: number;
  w: number;
  end: boolean;

  constructor(text: string, x: number, y: number, w: number, end: boolean) {
    this.text = text;
    this.x = x;
    this.y = y;
    this.w = w;
    this.end = end;
  }
}

class CartesianGeo {
  w: number = 0;
  h: number = 0;
  plotL: number = 0;
  plotT: number = 0;
  plotW: number = 0;
  plotH: number = 0;
  /** category centres along the category axis (x, or y when horizontal) */
  positions: number[] = [];
  /** category step (band step or point spacing) */
  step: number = 0;
  grid: SparkChartVec = EMPTY;
  labels: AxisLabel[] = [];
  series: CartesianSeries[] = [];
  keys: string[] = [];
}

const NO_SERIES: CartesianSeries = new CartesianSeries();

/**
 * Internal engine of SLineChart / SAreaChart / SBarChart: measures its own width, lays out axes, grid and series
 * (Path shapes morphing with motion key 'chart'), and shows a crosshair / cursor + tooltip on hover, tap or
 * horizontal pan. Use the public wrappers.
 */
@ComponentV2
export struct SparkCartesian {
  @Param kind: SparkCartesianKind = 'line';
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  @Param chartHeight: number = 0;
  @Param curve: SparkChartCurve = 'monotone';
  @Param dots: boolean = false;
  @Param stacked: boolean = false;
  @Param gradient: boolean = false;
  @Param horizontal: boolean = false;
  @Param barRadius: number = -1;
  @Param lineWidth: number = 2;
  @Param areaOpacity: number = 0.4;
  @Param grid: boolean = true;
  @Param categoryAxis: boolean = true;
  @Param valueAxis: boolean = false;
  @Param tooltip: boolean = true;
  @Param legend: boolean = false;
  @Param indicator: SparkChartIndicator = 'dot';
  @Param labelFormatter: (label: string) => string = identityLabel;
  @Param valueFormatter: (value: number) => string = defaultValue;
  @Param emptyText: string = 'No data';
  @Event onActiveChange: (index: number) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local own: SparkChartState = new SparkChartState();
  @Local ctx: SparkChartState | undefined = undefined;
  @Local measuredWidth: number = 0;
  @Local pxRatio: number = 1;
  @Local active: number = -1;
  @Local pointerX: number = 0;
  @Local pointerY: number = 0;
  @Local tipW: number = 0;
  @Local tipH: number = 0;
  /** morph shape changes (false right after a resize) */
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

  @Monitor('data', 'config', 'stacked', 'horizontal', 'curve')
  onData(): void {
    this.morph = true;
    if (this.active >= this.data.length) {
      this.active = -1;
    }
  }

  private st(): SparkChartState {
    return this.ctx ?? this.own;
  }

  private boxHeight(): number {
    if (this.chartHeight > 0) {
      return this.chartHeight;
    }
    if (this.measuredWidth <= 0) {
      return 200;
    }
    return Math.max(160, Math.min(320, Math.round(this.measuredWidth * 0.5625)));
  }

  private isBar(): boolean {
    return this.kind === 'bar';
  }

  private isHorizontal(): boolean {
    return this.kind === 'bar' && this.horizontal;
  }

  @Computed
  get geo(): CartesianGeo {
    const g = new CartesianGeo();
    const W = this.measuredWidth;
    const H = this.boxHeight();
    g.w = W;
    g.h = H;
    const n = this.data.length;
    if (W <= 0 || n === 0) {
      return g;
    }
    const k = this.pxRatio;
    const fs = this.theme.text.xs;
    const keys = sparkVisibleKeys(this.config, this.st());
    g.keys = keys;
    const vals: number[][] = keys.map((key: string) => this.data.map((r: SparkChartRow) => r.value(key)));
    const stacked = this.stacked && this.kind !== 'line';
    const stack: SparkStack = sparkStack(stacked ? vals : []);
    const all: number[] = [];
    if (stacked) {
      stack.upper.forEach((s: number[]) => s.forEach((v: number) => all.push(v)));
      stack.lower.forEach((s: number[]) => s.forEach((v: number) => all.push(v)));
    } else {
      vals.forEach((s: number[]) => s.forEach((v: number) => all.push(v)));
    }
    const horizontal = this.isHorizontal();
    const bar = this.isBar();
    const catTexts = this.data.map((r: SparkChartRow) => this.labelFormatter(r.label));
    let catW = 0;
    catTexts.forEach((t: string) => catW = Math.max(catW, sparkChartTextWidth(t, fs)));

    // ---- layout
    let plotL = 0;
    let plotT = 0;
    let plotW = 0;
    let plotH = 0;
    let ticks: number[] = [];
    let scale = new SparkLinearScale(0, 1, 0, 1);
    if (!horizontal) {
      plotT = this.dots || !bar ? 8 : 4;
      const bottom = this.categoryAxis ? LABEL_H + 10 : 4;
      plotH = Math.max(1, H - plotT - bottom);
      const count = sparkTickCount(plotH, 48, 2, 6);
      const dom = sparkValueDomain(all, true, count);
      ticks = sparkNiceTicks(dom[0], dom[1], count);
      let valW = 0;
      ticks.forEach((t: number) => valW = Math.max(valW, sparkChartTextWidth(sparkChartCompact(t), fs)));
      plotL = this.valueAxis ? valW + 8 : (bar ? 0 : 12);
      const right = bar ? 0 : 12;
      plotW = Math.max(1, W - plotL - right);
      scale = new SparkLinearScale(dom[0], dom[1], plotT + plotH, plotT);
    } else {
      plotT = 0;
      const bottom = this.valueAxis ? LABEL_H + 10 : 0;
      plotH = Math.max(1, H - plotT - bottom);
      plotL = this.categoryAxis ? Math.min(catW, W * 0.35) + 8 : 0;
      plotW = Math.max(1, W - plotL - 8);
      const count = sparkTickCount(plotW, 80, 2, 6);
      const dom = sparkValueDomain(all, true, count);
      ticks = sparkNiceTicks(dom[0], dom[1], count);
      scale = new SparkLinearScale(dom[0], dom[1], plotL, plotL + plotW);
    }
    g.plotL = plotL;
    g.plotT = plotT;
    g.plotW = plotW;
    g.plotH = plotH;
    const base = scale.mapClamped(0);

    // ---- categories
    const band = new SparkBandScale(n, horizontal ? plotT : plotL, horizontal ? plotT + plotH : plotL + plotW,
      0.2, 0.1);
    if (bar) {
      g.positions = band.centers();
      g.step = band.step;
    } else {
      g.positions = sparkPointPositions(n, plotL, plotL + plotW);
      g.step = n > 1 ? plotW / (n - 1) : plotW;
    }

    // ---- grid + labels
    const segs: number[] = [];
    ticks.forEach((t: number) => {
      const p = scale.map(t);
      if (horizontal) {
        segs.push(p, plotT, p, plotT + plotH);
      } else {
        segs.push(plotL, p, plotL + plotW, p);
      }
    });
    g.grid = new SparkChartVec(sparkShapeLines(segs, k));
    const labels: AxisLabel[] = [];
    if (this.categoryAxis) {
      if (!horizontal) {
        const lw = catW + 8;
        const stepN = sparkLabelStep(n, bar ? plotW : plotW + g.step, lw);
        for (let i = 0; i < n; i += stepN) {
          const x = Math.max(0, Math.min(W - lw, g.positions[i] - lw / 2));
          labels.push(new AxisLabel(catTexts[i], x, plotT + plotH + 8, lw, false));
        }
      } else {
        const stepN = sparkLabelStep(n, plotH, LABEL_H + 4);
        for (let i = 0; i < n; i += stepN) {
          labels.push(new AxisLabel(catTexts[i], 0, g.positions[i] - LABEL_H / 2, Math.max(1, plotL - 8), true));
        }
      }
    }
    if (this.valueAxis) {
      if (!horizontal) {
        ticks.forEach((t: number) => {
          labels.push(new AxisLabel(sparkChartCompact(t), 0, scale.map(t) - LABEL_H / 2, Math.max(1, plotL - 8), true));
        });
      } else {
        let tw = 0;
        ticks.forEach((t: number) => tw = Math.max(tw, sparkChartTextWidth(sparkChartCompact(t), fs) + 8));
        const stepN = sparkLabelStep(ticks.length, plotW, tw);
        for (let i = 0; i < ticks.length; i += stepN) {
          const x = Math.max(0, Math.min(W - tw, scale.map(ticks[i]) - tw / 2));
          labels.push(new AxisLabel(sparkChartCompact(ticks[i]), x, plotT + plotH + 8, tw, false));
        }
      }
    }
    g.labels = labels;

    // ---- series
    const m = keys.length;
    const radius = this.barRadius >= 0 ? this.barRadius : this.theme.radiusMd;
    const flat: number[] = [];
    for (let i = 0; i < n; i++) {
      flat.push(base);
    }
    keys.forEach((key: string, s: number) => {
      const sg = new CartesianSeries();
      sg.key = key;
      sg.label = this.config.label(key);
      sg.color = this.config.color(this.theme, key, s);
      const upper = stacked ? stack.upper[s] : vals[s];
      const ys = upper.map((v: number) => scale.map(v));
      sg.points = ys;
      if (this.kind === 'line') {
        sg.shape = new SparkChartVec(sparkShapeLine(g.positions, ys, this.curve, k));
        sg.from = new SparkChartVec(sparkShapeLine(g.positions, flat, this.curve, k));
        if (this.dots) {
          sg.dots = new SparkChartVec(sparkShapeDots(g.positions, ys, 3, k));
          sg.dotsFrom = new SparkChartVec(sparkShapeDots(g.positions, flat, 3, k));
        }
      } else if (this.kind === 'area') {
        const bs = stacked ? stack.lower[s].map((v: number) => scale.map(v)) : flat;
        sg.shape = new SparkChartVec(sparkShapeArea(g.positions, ys, bs, this.curve, k));
        sg.from = new SparkChartVec(sparkShapeArea(g.positions, flat, flat, this.curve, k));
        sg.edge = new SparkChartVec(sparkShapeLine(g.positions, ys, this.curve, k));
        sg.edgeFrom = new SparkChartVec(sparkShapeLine(g.positions, flat, this.curve, k));
        if (this.dots) {
          sg.dots = new SparkChartVec(sparkShapeDots(g.positions, ys, 3, k));
          sg.dotsFrom = new SparkChartVec(sparkShapeDots(g.positions, flat, 3, k));
        }
      } else {
        const rects: number[] = [];
        const collapsed: number[] = [];
        const gap = stacked || m <= 1 ? 0 : Math.min(4, band.bandwidth * 0.1);
        const bw = stacked ? band.bandwidth : (band.bandwidth - gap * (m - 1)) / Math.max(1, m);
        const r = Math.max(0, Math.min(radius, bw / 2));
        // stacked: round the outer end of the last series and the base end of the first one
        const outer = !stacked || s === m - 1 ? r : 0;
        const inner = !stacked || s === 0 ? r : 0;
        for (let i = 0; i < n; i++) {
          const lower = stacked ? scale.map(stack.lower[s][i]) : base;
          const p = ys[i];
          const off = band.start(i) + (stacked ? 0 : s * (bw + gap));
          if (!horizontal) {
            rects.push(off, Math.min(p, lower), bw, Math.abs(lower - p), outer, outer, inner, inner);
            collapsed.push(off, base, bw, 0, outer, outer, inner, inner);
          } else {
            rects.push(Math.min(p, lower), off, Math.abs(p - lower), bw, inner, outer, outer, inner);
            collapsed.push(base, off, 0, bw, inner, outer, outer, inner);
          }
        }
        sg.shape = new SparkChartVec(sparkShapeRects(rects, k));
        sg.from = new SparkChartVec(sparkShapeRects(collapsed, k));
      }
      g.series.push(sg);
    });
    return g;
  }

  private ser(key: string): CartesianSeries {
    const list = this.geo.series;
    for (const s of list) {
      if (s.key === key) {
        return s;
      }
    }
    return NO_SERIES;
  }

  /** hover cursor: band rect for bars, vertical line for line / area */
  @Computed
  get cursor(): SparkChartVec {
    const g = this.geo;
    const i = this.active;
    if (i < 0 || i >= g.positions.length) {
      return EMPTY;
    }
    const c = g.positions[i];
    if (this.isBar()) {
      if (this.isHorizontal()) {
        return new SparkChartVec(sparkShapeRects([g.plotL, c - g.step / 2, g.plotW, g.step, 0, 0, 0, 0],
          this.pxRatio));
      }
      return new SparkChartVec(sparkShapeRects([c - g.step / 2, g.plotT, g.step, g.plotH, 0, 0, 0, 0], this.pxRatio));
    }
    return new SparkChartVec(sparkShapeLines([c, g.plotT, c, g.plotT + g.plotH], this.pxRatio));
  }

  private activeDot(key: string): SparkChartVec {
    const s = this.ser(key);
    const i = this.active;
    if (i < 0 || i >= s.points.length) {
      return EMPTY;
    }
    return new SparkChartVec(sparkShapeDots([this.geo.positions[i]], [s.points[i]], 4, this.pxRatio));
  }

  @Computed
  get tipItems(): SparkChartTooltipItem[] {
    const i = this.active;
    if (i < 0 || i >= this.data.length) {
      return [];
    }
    const row = this.data[i];
    const items = this.geo.series.map((s: CartesianSeries) =>
    new SparkChartTooltipItem(s.key, s.label, this.valueFormatter(row.value(s.key)), s.color));
    // stacked charts read top-down like the stack
    return this.stacked ? items.reverse() : items;
  }

  private tipPos(): number[] {
    const g = this.geo;
    const i = Math.max(0, Math.min(g.positions.length - 1, this.active));
    const c = g.positions.length > 0 ? g.positions[i] : 0;
    if (this.isHorizontal()) {
      return sparkTooltipPlace(this.pointerX, c, this.tipW, this.tipH, g.w, g.h, 12);
    }
    return sparkTooltipPlace(c, this.pointerY, this.tipW, this.tipH, g.w, g.h, 12);
  }

  private indexAt(x: number, y: number): number {
    return sparkNearestIndex(this.geo.positions, this.isHorizontal() ? y : x);
  }

  private point(x: number, y: number): void {
    const i = this.indexAt(x, y);
    this.pointerX = x;
    this.pointerY = y;
    if (i !== this.active) {
      this.active = i;
      this.onActiveChange(i);
    }
  }

  private tap(x: number, y: number): void {
    if (this.indexAt(x, y) === this.active) {
      this.leave();
    } else {
      this.point(x, y);
    }
  }

  private leave(): void {
    if (this.active !== -1) {
      this.active = -1;
      this.onActiveChange(-1);
    }
  }

  @Builder
  seriesShape(key: string) {
    if (this.kind === 'line') {
      SChartPath({
        shape: this.ser(key).shape, from: this.ser(key).from, boxWidth: this.geo.w, boxHeight: this.geo.h,
        strokeColor: this.ser(key).color, strokeW: this.lineWidth, animate: this.morph
      })
    } else if (this.kind === 'area') {
      if (this.gradient) {
        SChartGradient({
          shape: this.ser(key).shape, from: this.ser(key).from, boxWidth: this.geo.w, boxHeight: this.geo.h,
          topColor: SparkColor.alpha(this.ser(key).color, 0.8), bottomColor: SparkColor.alpha(this.ser(key).color, 0.1),
          animate: this.morph
        })
      } else {
        SChartPath({
          shape: this.ser(key).shape, from: this.ser(key).from, boxWidth: this.geo.w, boxHeight: this.geo.h,
          fillColor: this.ser(key).color, fillAlpha: this.areaOpacity, animate: this.morph
        })
      }
      SChartPath({
        shape: this.ser(key).edge, from: this.ser(key).edgeFrom, boxWidth: this.geo.w, boxHeight: this.geo.h,
        strokeColor: this.ser(key).color, strokeW: Math.max(1, this.lineWidth / 2), animate: this.morph
      })
    } else {
      SChartPath({
        shape: this.ser(key).shape, from: this.ser(key).from, boxWidth: this.geo.w, boxHeight: this.geo.h,
        fillColor: this.ser(key).color, animate: this.morph
      })
    }
    if (this.dots && this.kind !== 'bar') {
      SChartPath({
        shape: this.ser(key).dots, from: this.ser(key).dotsFrom, boxWidth: this.geo.w, boxHeight: this.geo.h,
        fillColor: this.ser(key).color, animate: this.morph
      })
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
          if (this.grid) {
            SChartPath({
              shape: this.geo.grid, boxWidth: this.geo.w, boxHeight: this.geo.h,
              strokeColor: SparkColor.alpha(this.theme.colors.border, 0.7), strokeW: 1, animate: false
            })
          }
          if (this.tooltip && this.active >= 0 && this.kind === 'bar') {
            SChartPath({
              shape: this.cursor, boxWidth: this.geo.w, boxHeight: this.geo.h,
              fillColor: SparkColor.alpha(this.theme.colors.muted, 0.8), animate: false
            })
          }
          ForEach(this.geo.keys, (key: string) => {
            this.seriesShape(key)
          }, (key: string) => key)
          if (this.tooltip && this.active >= 0 && this.kind !== 'bar') {
            SChartPath({
              shape: this.cursor, boxWidth: this.geo.w, boxHeight: this.geo.h,
              strokeColor: this.theme.colors.border, strokeW: 1, animate: false
            })
            ForEach(this.geo.keys, (key: string) => {
              SChartPath({
                shape: this.activeDot(key), boxWidth: this.geo.w, boxHeight: this.geo.h,
                fillColor: this.ser(key).color, strokeColor: this.theme.colors.background, strokeW: 2, animate: false
              })
            }, (key: string) => key)
          }
          ForEach(this.geo.labels, (l: AxisLabel) => {
            Text(l.text)
              .position({ x: l.x, y: l.y })
              .width(l.w)
              .height(LABEL_H)
              .textAlign(l.end ? TextAlign.End : TextAlign.Center)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .hitTestBehavior(HitTestMode.Transparent)
          }, (l: AxisLabel) => `${l.text}|${l.x}|${l.y}|${l.w}`)
          SChartPointer({
            scrub: true, boxWidth: this.geo.w, boxHeight: this.geo.h,
            onPoint: (x: number, y: number) => this.point(x, y),
            onTap: (x: number, y: number) => this.tap(x, y),
            onLeave: () => this.leave()
          })
          if (this.tooltip && this.active >= 0) {
            Column() {
              SChartTooltipCard({
                title: this.data[Math.min(this.active, this.data.length - 1)].label,
                items: this.tipItems, indicator: this.indicator
              })
            }
            .position({ x: this.tipPos()[0], y: this.tipPos()[1] })
            .hitTestBehavior(HitTestMode.None)
            .onAreaChange((_: Area, a: Area) => {
              this.tipW = Number(a.width);
              this.tipH = Number(a.height);
            })
          }
        }
      }
      .width('100%')
      .height(this.boxHeight())
      .clip(false)
      .accessibilityText(`${this.kind} chart: ${this.config.series.map((s) => s.label).join(', ')}`)
      .onAreaChange((_: Area, a: Area) => {
        const w = Number(a.width);
        if (Math.abs(w - this.measuredWidth) > 0.5) {
          this.morph = false;
          this.measuredWidth = w;
        }
      })

      if (this.legend) {
        SChartLegend({ config: this.config, state: this.st(), compact: this.measuredWidth < 360 })
      }
    }
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ public charts

/**
 * shadcn "Line Chart": one line per series of `config`, categories from `data` rows.
 *
 * ```
 * SLineChart({ config: this.config, data: this.rows, curve: 'monotone', dots: true })
 * ```
 * Hover (pointer), tap or pan horizontally to show the crosshair and tooltip.
 */
@ComponentV2
export struct SLineChart {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  /** height in vp; 0 → responsive 16:9 of the measured width (160–320) */
  @Param chartHeight: number = 0;
  /** 'monotone' (shadcn "natural"), 'linear' or 'step' */
  @Param curve: SparkChartCurve = 'monotone';
  @Param dots: boolean = false;
  @Param lineWidth: number = 2;
  @Param grid: boolean = true;
  /** category labels (x axis) */
  @Param categoryAxis: boolean = true;
  /** value ticks (y axis) */
  @Param valueAxis: boolean = false;
  @Param tooltip: boolean = true;
  @Param legend: boolean = false;
  @Param indicator: SparkChartIndicator = 'line';
  @Param labelFormatter: (label: string) => string = identityLabel;
  @Param valueFormatter: (value: number) => string = defaultValue;
  @Param emptyText: string = 'No data';
  @Event onActiveChange: (index: number) => void = () => {
  };

  build() {
    Column() {
      SparkCartesian({
        kind: 'line', config: this.config, data: this.data, chartHeight: this.chartHeight, curve: this.curve,
        dots: this.dots, lineWidth: this.lineWidth, grid: this.grid, categoryAxis: this.categoryAxis,
        valueAxis: this.valueAxis, tooltip: this.tooltip, legend: this.legend, indicator: this.indicator,
        labelFormatter: this.labelFormatter, valueFormatter: this.valueFormatter, emptyText: this.emptyText,
        onActiveChange: (i: number) => this.onActiveChange(i)
      })
    }
    .width('100%')
  }
}

/**
 * shadcn "Area Chart": filled areas (optionally `stacked`, `gradient` fill).
 *
 * ```
 * SAreaChart({ config: this.config, data: this.rows, stacked: true, gradient: true })
 * ```
 */
@ComponentV2
export struct SAreaChart {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  @Param chartHeight: number = 0;
  @Param curve: SparkChartCurve = 'monotone';
  @Param stacked: boolean = false;
  /** vertical gradient fill instead of a flat `areaOpacity` fill */
  @Param gradient: boolean = false;
  @Param areaOpacity: number = 0.4;
  @Param dots: boolean = false;
  @Param lineWidth: number = 2;
  @Param grid: boolean = true;
  @Param categoryAxis: boolean = true;
  @Param valueAxis: boolean = false;
  @Param tooltip: boolean = true;
  @Param legend: boolean = false;
  @Param indicator: SparkChartIndicator = 'dot';
  @Param labelFormatter: (label: string) => string = identityLabel;
  @Param valueFormatter: (value: number) => string = defaultValue;
  @Param emptyText: string = 'No data';
  @Event onActiveChange: (index: number) => void = () => {
  };

  build() {
    Column() {
      SparkCartesian({
        kind: 'area', config: this.config, data: this.data, chartHeight: this.chartHeight, curve: this.curve,
        stacked: this.stacked, gradient: this.gradient, areaOpacity: this.areaOpacity, dots: this.dots,
        lineWidth: this.lineWidth, grid: this.grid, categoryAxis: this.categoryAxis, valueAxis: this.valueAxis,
        tooltip: this.tooltip, legend: this.legend, indicator: this.indicator, labelFormatter: this.labelFormatter,
        valueFormatter: this.valueFormatter, emptyText: this.emptyText,
        onActiveChange: (i: number) => this.onActiveChange(i)
      })
    }
    .width('100%')
  }
}

/**
 * shadcn "Bar Chart": grouped or `stacked` bars, vertical or `horizontal`, rounded corners (`barRadius`,
 * default --radius-md; stacked bars round only the outer ends).
 *
 * ```
 * SBarChart({ config: this.config, data: this.rows, stacked: true, legend: true })
 * ```
 */
@ComponentV2
export struct SBarChart {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  @Param chartHeight: number = 0;
  @Param stacked: boolean = false;
  /** horizontal bars (categories on the vertical axis; Recharts `layout="vertical"`) */
  @Param horizontal: boolean = false;
  /** corner radius in vp; -1 → theme radius-md */
  @Param barRadius: number = -1;
  @Param grid: boolean = true;
  @Param categoryAxis: boolean = true;
  @Param valueAxis: boolean = false;
  @Param tooltip: boolean = true;
  @Param legend: boolean = false;
  @Param indicator: SparkChartIndicator = 'dot';
  @Param labelFormatter: (label: string) => string = identityLabel;
  @Param valueFormatter: (value: number) => string = defaultValue;
  @Param emptyText: string = 'No data';
  @Event onActiveChange: (index: number) => void = () => {
  };

  build() {
    Column() {
      SparkCartesian({
        kind: 'bar', config: this.config, data: this.data, chartHeight: this.chartHeight, stacked: this.stacked,
        horizontal: this.horizontal, barRadius: this.barRadius, grid: this.grid, categoryAxis: this.categoryAxis,
        valueAxis: this.valueAxis, tooltip: this.tooltip, legend: this.legend, indicator: this.indicator,
        labelFormatter: this.labelFormatter, valueFormatter: this.valueFormatter, emptyText: this.emptyText,
        onActiveChange: (i: number) => this.onActiveChange(i)
      })
    }
    .width('100%')
  }
}
