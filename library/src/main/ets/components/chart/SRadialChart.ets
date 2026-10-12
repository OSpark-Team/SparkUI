import { sparkText } from '../../core/SparkText';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkChartFormat, sparkRingIndex, sparkShapeArcs, sparkTooltipPlace } from './ChartMath';
import { SChartLegend, SChartPointer, SChartTooltipCard, sparkResolveChartState } from './ChartParts';
import { SChartPath, SparkChartVec } from './ChartShape';
import {
  SparkChartConfig, SparkChartIndicator, SparkChartRow, SparkChartState, SparkChartTooltipItem
} from './ChartTypes';

const EMPTY: SparkChartVec = new SparkChartVec([]);

function defaultValue(v: number): string {
  return sparkChartFormat(v);
}

class RadialRing {
  key: string = '';
  label: string = '';
  color: string = '#FF000000';
  value: number = 0;
  row: number = 0;
  r0: number = 0;
  r1: number = 0;
  a1: number = 0;
}

class RadialGeo {
  w: number = 0;
  h: number = 0;
  cx: number = 0;
  cy: number = 0;
  inner: number = 0;
  outer: number = 0;
  a0: number = 0;
  aEnd: number = 0;
  rings: RadialRing[] = [];
  keys: string[] = [];
  track: SparkChartVec = EMPTY;
}

const NO_RING: RadialRing = new RadialRing();

/**
 * shadcn "Radial Chart": one concentric bar per data row (first row innermost; row label = key in `config`),
 * its sweep proportional to `valueKey` / `maxValue` between `startAngle` and `endAngle` (degrees, 0 = 12 o'clock,
 * clockwise). Optional muted track, rounded ends and a centre label. Bars sweep in on appear.
 *
 * ```
 * SRadialChart({ config: this.browsers, data: this.rows, valueKey: 'visitors', endAngle: 270 })
 * ```
 */
@ComponentV2
export struct SRadialChart {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param data: SparkChartRow[] = [];
  @Param valueKey: string = 'value';
  @Param startAngle: number = 0;
  @Param endAngle: number = 360;
  /** value that fills a whole ring; 0 → the largest value */
  @Param maxValue: number = 0;
  /** inner radius as a fraction of the outer radius */
  @Param innerRatio: number = 0.3;
  /** gap between rings in vp */
  @Param ringGap: number = 4;
  @Param track: boolean = true;
  @Param rounded: boolean = true;
  @Param chartHeight: number = 250;
  @Param centerValue: string = '';
  @Param centerLabel: string = '';
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

  @Monitor('data', 'config', 'valueKey', 'maxValue', 'startAngle', 'endAngle')
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
  get geo(): RadialGeo {
    const g = new RadialGeo();
    const W = this.measuredWidth;
    const D = this.diameter();
    g.w = W;
    g.h = D;
    if (W <= 0) {
      return g;
    }
    g.cx = W / 2;
    g.cy = D / 2;
    g.outer = Math.max(8, D / 2 - 4);
    g.inner = g.outer * Math.max(0, Math.min(0.9, this.innerRatio));
    g.a0 = this.startAngle * Math.PI / 180;
    g.aEnd = this.endAngle * Math.PI / 180;
    const st = this.st();
    const rows: number[] = [];
    this.data.forEach((r: SparkChartRow, i: number) => {
      if (!st.isHidden(r.label)) {
        rows.push(i);
      }
    });
    let max = this.maxValue;
    if (!(max > 0)) {
      rows.forEach((i: number) => max = Math.max(max, this.data[i].value(this.valueKey)));
    }
    const m = Math.max(1, rows.length);
    const t = (g.outer - g.inner) / m;
    const gap = Math.min(this.ringGap, t * 0.4);
    const round = this.rounded ? 1 : 0;
    const tracks: number[] = [];
    rows.forEach((ri: number, j: number) => {
      const r = this.data[ri];
      const ring = new RadialRing();
      ring.key = r.label;
      ring.label = this.config.label(r.label);
      ring.color = this.config.color(this.theme, r.label, ri);
      ring.value = r.value(this.valueKey);
      ring.row = ri;
      ring.r0 = g.inner + j * t + gap / 2;
      ring.r1 = ring.r0 + t - gap;
      const frac = max > 0 ? Math.max(0, Math.min(1, ring.value / max)) : 0;
      ring.a1 = g.a0 + (g.aEnd - g.a0) * frac;
      g.rings.push(ring);
      g.keys.push(r.label);
      tracks.push(g.cx, g.cy, ring.r0, ring.r1, g.a0, g.aEnd, round);
    });
    g.track = new SparkChartVec(sparkShapeArcs(tracks, this.pxRatio));
    return g;
  }

  private ring(key: string): RadialRing {
    for (const r of this.geo.rings) {
      if (r.key === key) {
        return r;
      }
    }
    return NO_RING;
  }

  private shapeOf(key: string): SparkChartVec {
    const g = this.geo;
    const r = this.ring(key);
    return new SparkChartVec(sparkShapeArcs([g.cx, g.cy, r.r0, r.r1, g.a0, r.a1, this.rounded ? 1 : 0],
      this.pxRatio));
  }

  private fromOf(key: string): SparkChartVec {
    const g = this.geo;
    const r = this.ring(key);
    return new SparkChartVec(sparkShapeArcs([g.cx, g.cy, r.r0, r.r1, g.a0, g.a0, this.rounded ? 1 : 0],
      this.pxRatio));
  }

  @Computed
  get tipItems(): SparkChartTooltipItem[] {
    for (const r of this.geo.rings) {
      if (r.row === this.active) {
        return [new SparkChartTooltipItem(r.key, r.label, this.valueFormatter(r.value), r.color)];
      }
    }
    return [];
  }

  private hit(x: number, y: number): number {
    const g = this.geo;
    const d = Math.sqrt((x - g.cx) * (x - g.cx) + (y - g.cy) * (y - g.cy));
    const j = sparkRingIndex(g.rings.length, g.inner, g.outer, d);
    return j >= 0 ? g.rings[j].row : -1;
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
        if (this.data.length === 0) {
          Text(this.emptyText)
            .width('100%')
            .height('100%')
            .textAlign(TextAlign.Center)
            .fontSize(this.theme.text.sm)
            .fontColor(this.theme.colors.mutedForeground)
        } else if (this.geo.w > 0) {
          if (this.track) {
            SChartPath({
              shape: this.geo.track, boxWidth: this.geo.w, boxHeight: this.geo.h,
              fillColor: this.theme.colors.muted, animate: false
            })
          }
          ForEach(this.geo.keys, (key: string) => {
            SChartPath({
              shape: this.shapeOf(key), from: this.fromOf(key), boxWidth: this.geo.w, boxHeight: this.geo.h,
              fillColor: this.ring(key).color, fillAlpha: this.active < 0 || this.ring(key).row === this.active ? 1 : 0.6,
              animate: this.morph
            })
          }, (key: string) => key)
          if (this.centerValue.length > 0 || this.centerLabel.length > 0) {
            Column({ space: 2 }) {
              if (this.centerValue.length > 0) {
                Text(this.centerValue)
                  .fontSize(this.theme.text.xxxxl)
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
      .accessibilityText(this.centerLabel.length > 0 ? `${this.centerValue} ${this.centerLabel}` : sparkText(this.getUIContext(), $r('app.string.spark_radial_chart'), 'radial chart'))
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
