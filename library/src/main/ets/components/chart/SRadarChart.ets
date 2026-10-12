import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkChartFormat, sparkNiceDomain, sparkNiceTicks, sparkPolar, sparkShapeDots, sparkShapePolygon,
  sparkShapeRings, sparkSpokeIndex, sparkTooltipPlace
} from './ChartMath';
import {
  SChartLegend, SChartPointer, SChartTooltipCard, sparkChartTextWidth, sparkResolveChartState, sparkVisibleKeys
} from './ChartParts';
import { SChartPath, SparkChartVec } from './ChartShape';
import {
  SparkChartConfig, SparkChartIndicator, SparkChartRow, SparkChartState, SparkChartTooltipItem
} from './ChartTypes';

/** Radar grid shape (Recharts `PolarGrid gridType`). */
export type SparkRadarGrid = 'polygon' | 'circle';

const EMPTY: SparkChartVec = new SparkChartVec([]);
const LABEL_H: number = 16;

function identityLabel(s: string): string {
  return s;
}

function defaultValue(v: number): string {
  return sparkChartFormat(v);
}

class RadarSeries {
  key: string = '';
  label: string = '';
  color: string = '#FF000000';
  xs: number[] = [];
  ys: number[] = [];
  shape: SparkChartVec = EMPTY;
  from: SparkChartVec = EMPTY;
  dots: SparkChartVec = EMPTY;
  dotsFrom: SparkChartVec = EMPTY;
}

class RadarLabel {
  text: string;
  x: number;
  y: number;
  w: number;

  constructor(text: string, x: number, y: number, w: number) {
    this.text = text;
    this.x = x;
    this.y = y;
    this.w = w;
  }
}

class RadarGeo {
  w: number = 0;
  h: number = 0;
  cx: number = 0;
  cy: number = 0;
  radius: number = 0;
  grid: SparkChartVec = EMPTY;
  labels: RadarLabel[] = [];
  series: RadarSeries[] = [];
  keys: string[] = [];
}

const NO_SERIES: RadarSeries = new RadarSeries();

/**
 * shadcn "Radar Chart": one spoke per data row (≥ 3), one filled polygon per series of `config`.
 * Polygons grow from the centre on appear and morph on data / legend changes. Tap or hover near a spoke for the
 * tooltip of that category. Spoke labels are hidden automatically when the chart is too small for them.
 *
 * ```
 * SRadarChart({ config: this.config, data: this.rows, dots: true })
 * ```
 */
@ComponentV2
export struct SRadarChart {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  @Param chartHeight: number = 250;
  @Param gridShape: SparkRadarGrid = 'polygon';
  @Param dots: boolean = false;
  /** polygon fill opacity (0 → outline only) */
  @Param fillAlpha: number = 0.6;
  /** outline width in vp (0 → none) */
  @Param lineWidth: number = 0;
  @Param labels: boolean = true;
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

  @Monitor('data', 'config')
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
    if (this.measuredWidth <= 0) {
      return this.chartHeight;
    }
    return Math.max(120, Math.min(this.chartHeight, this.measuredWidth));
  }

  @Computed
  get geo(): RadarGeo {
    const g = new RadarGeo();
    const W = this.measuredWidth;
    const H = this.boxHeight();
    g.w = W;
    g.h = H;
    const n = this.data.length;
    if (W <= 0 || n < 3) {
      return g;
    }
    const k = this.pxRatio;
    const fs = this.theme.text.xs;
    const texts = this.data.map((r: SparkChartRow) => this.labelFormatter(r.label));
    let maxW = 0;
    texts.forEach((t: string) => maxW = Math.max(maxW, sparkChartTextWidth(t, fs)));
    g.cx = W / 2;
    g.cy = H / 2;
    // labels need room on the sides; drop them when they would squeeze the radar below a third of the box
    const roomX = maxW + 8;
    const full = Math.min(W / 2, H / 2) - 4;
    const withLabels = Math.min(W / 2 - roomX, H / 2 - LABEL_H - 6);
    const showLabels = this.labels && withLabels >= full * 0.55;
    g.radius = Math.max(8, showLabels ? withLabels : full);

    const keys = sparkVisibleKeys(this.config, this.st());
    g.keys = keys;
    let max = 0;
    keys.forEach((key: string) => this.data.forEach((r: SparkChartRow) => max = Math.max(max, r.value(key))));
    const dom = sparkNiceDomain(0, max, 4);
    const ticks = sparkNiceTicks(0, dom[1], 4).filter((t: number) => t > 0);
    const radii = ticks.map((t: number) => g.radius * t / (dom[1] > 0 ? dom[1] : 1));
    if (radii.length === 0) {
      radii.push(g.radius);
    }
    g.grid = new SparkChartVec(sparkShapeRings(g.cx, g.cy, n, radii, this.gridShape === 'circle', k));

    if (showLabels) {
      texts.forEach((t: string, i: number) => {
        const p = sparkPolar(g.cx, g.cy, g.radius + 8, Math.PI * 2 * i / n);
        const w = sparkChartTextWidth(t, fs) + 4;
        // anchor by side: left half ends at the point, right half starts at it, top / bottom centred
        const s = Math.sin(Math.PI * 2 * i / n);
        const x = Math.abs(s) < 0.2 ? p[0] - w / 2 : (s > 0 ? p[0] : p[0] - w);
        const c = Math.cos(Math.PI * 2 * i / n);
        const y = Math.abs(c) < 0.2 ? p[1] - LABEL_H / 2 : (c > 0 ? p[1] - LABEL_H : p[1]);
        g.labels.push(new RadarLabel(t, Math.max(0, Math.min(W - w, x)), Math.max(0, Math.min(H - LABEL_H, y)), w));
      });
    }

    const cxs: number[] = [];
    const cys: number[] = [];
    for (let i = 0; i < n; i++) {
      cxs.push(g.cx);
      cys.push(g.cy);
    }
    keys.forEach((key: string, s: number) => {
      const rs = new RadarSeries();
      rs.key = key;
      rs.label = this.config.label(key);
      rs.color = this.config.color(this.theme, key, s);
      this.data.forEach((r: SparkChartRow, i: number) => {
        const rr = dom[1] > 0 ? g.radius * Math.max(0, r.value(key)) / dom[1] : 0;
        const p = sparkPolar(g.cx, g.cy, rr, Math.PI * 2 * i / n);
        rs.xs.push(p[0]);
        rs.ys.push(p[1]);
      });
      rs.shape = new SparkChartVec(sparkShapePolygon(rs.xs, rs.ys, k));
      rs.from = new SparkChartVec(sparkShapePolygon(cxs, cys, k));
      rs.dots = new SparkChartVec(sparkShapeDots(rs.xs, rs.ys, 4, k));
      rs.dotsFrom = new SparkChartVec(sparkShapeDots(cxs, cys, 4, k));
      g.series.push(rs);
    });
    return g;
  }

  private ser(key: string): RadarSeries {
    for (const s of this.geo.series) {
      if (s.key === key) {
        return s;
      }
    }
    return NO_SERIES;
  }

  private activeDot(key: string): SparkChartVec {
    const s = this.ser(key);
    const i = this.active;
    if (i < 0 || i >= s.xs.length) {
      return EMPTY;
    }
    return new SparkChartVec(sparkShapeDots([s.xs[i]], [s.ys[i]], 4, this.pxRatio));
  }

  @Computed
  get tipItems(): SparkChartTooltipItem[] {
    const i = this.active;
    if (i < 0 || i >= this.data.length) {
      return [];
    }
    const row = this.data[i];
    return this.geo.series.map((s: RadarSeries) =>
    new SparkChartTooltipItem(s.key, s.label, this.valueFormatter(row.value(s.key)), s.color));
  }

  private hit(x: number, y: number): number {
    const g = this.geo;
    const d = Math.sqrt((x - g.cx) * (x - g.cx) + (y - g.cy) * (y - g.cy));
    if (d > g.radius + 24 || g.radius <= 0) {
      return -1;
    }
    return sparkSpokeIndex(g.cx, g.cy, this.data.length, x, y);
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
    if (this.hit(x, y) === this.active) {
      this.point(-1000, -1000);
    } else {
      this.point(x, y);
    }
  }

  build() {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.data.length < 3) {
          Text(this.emptyText)
            .width('100%')
            .height('100%')
            .textAlign(TextAlign.Center)
            .fontSize(this.theme.text.sm)
            .fontColor(this.theme.colors.mutedForeground)
        } else if (this.geo.w > 0) {
          SChartPath({
            shape: this.geo.grid, boxWidth: this.geo.w, boxHeight: this.geo.h,
            strokeColor: this.theme.colors.border, strokeW: 1, animate: false
          })
          ForEach(this.geo.keys, (key: string) => {
            SChartPath({
              shape: this.ser(key).shape, from: this.ser(key).from, boxWidth: this.geo.w, boxHeight: this.geo.h,
              fillColor: this.ser(key).color, fillAlpha: this.fillAlpha,
              strokeColor: this.lineWidth > 0 ? this.ser(key).color : Color.Transparent, strokeW: this.lineWidth,
              animate: this.morph
            })
            if (this.dots) {
              SChartPath({
                shape: this.ser(key).dots, from: this.ser(key).dotsFrom, boxWidth: this.geo.w, boxHeight: this.geo.h,
                fillColor: this.ser(key).color, animate: this.morph
              })
            }
          }, (key: string) => key)
          if (this.tooltip && this.active >= 0) {
            ForEach(this.geo.keys, (key: string) => {
              SChartPath({
                shape: this.activeDot(key), boxWidth: this.geo.w, boxHeight: this.geo.h,
                fillColor: this.ser(key).color, strokeColor: this.theme.colors.background, strokeW: 2, animate: false
              })
            }, (key: string) => key)
          }
          ForEach(this.geo.labels, (l: RadarLabel) => {
            Text(l.text)
              .position({ x: l.x, y: l.y })
              .width(l.w)
              .height(LABEL_H)
              .textAlign(TextAlign.Center)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
              .maxLines(1)
              .hitTestBehavior(HitTestMode.Transparent)
          }, (l: RadarLabel) => `${l.text}|${l.x}|${l.y}`)
          SChartPointer({
            scrub: false, boxWidth: this.geo.w, boxHeight: this.geo.h,
            onPoint: (x: number, y: number) => this.point(x, y),
            onTap: (x: number, y: number) => this.tap(x, y),
            onLeave: () => this.point(-1000, -1000)
          })
          if (this.tooltip && this.active >= 0 && this.tipItems.length > 0) {
            Column() {
              SChartTooltipCard({
                title: this.data[Math.min(this.active, this.data.length - 1)].label,
                items: this.tipItems, indicator: this.indicator
              })
            }
            .position({
              x: sparkTooltipPlace(this.pointerX, this.pointerY, this.tipW, this.tipH, this.geo.w, this.geo.h, 16)[0],
              y: sparkTooltipPlace(this.pointerX, this.pointerY, this.tipW, this.tipH, this.geo.w, this.geo.h, 16)[1]
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
      .height(this.boxHeight())
      .accessibilityText(`radar chart: ${this.config.series.map((s) => s.label).join(', ')}`)
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
