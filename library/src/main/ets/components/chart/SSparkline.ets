import { SparkEnvironment } from '../../layout/SparkLayoutContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SparkChartCurve, SparkLinearScale, sparkPointPositions, sparkShapeArea, sparkShapeDots, sparkShapeLine
} from './ChartMath';
import { SChartPath, SparkChartVec } from './ChartShape';
import { sparkChartColor } from './ChartTypes';

const EMPTY: SparkChartVec = new SparkChartVec([]);

class SparkGeo {
  w: number = 0;
  h: number = 0;
  line: SparkChartVec = EMPTY;
  lineFrom: SparkChartVec = EMPTY;
  area: SparkChartVec = EMPTY;
  areaFrom: SparkChartVec = EMPTY;
  end: SparkChartVec = EMPTY;
}

/**
 * Tiny inline trend line (no axes, no tooltip) — e.g. inside a stat card or a table cell. Fills the width it
 * gets; the value range is the data extent (not forced through 0). Draws in like the other charts.
 *
 * ```
 * SSparkline({ values: [3, 5, 4, 8, 6, 9], color: 'chart-2' })
 * ```
 */
@ComponentV2
export struct SSparkline {
  @Param values: number[] = [];
  /** token name ('chart-1', 'primary' …) or '#hex' */
  @Param color: string = 'chart-1';
  @Param filled: boolean = true;
  @Param curve: SparkChartCurve = 'monotone';
  @Param chartHeight: number = 32;
  @Param lineWidth: number = 1.5;
  /** dot on the last value */
  @Param endDot: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local measuredWidth: number = 0;
  @Local pxRatio: number = 1;
  /** window density (px per vp) — chart paths are in px and must be rebuilt when it changes */
  @Local sparkEnv: SparkEnvironment = SparkUI.layout.env;

  @Monitor('sparkEnv.pxPerVp')
  syncDensity(): void {
    this.pxRatio = this.getUIContext().vp2px(1);
  }
  @Local morph: boolean = true;

  aboutToAppear(): void {
    this.pxRatio = this.getUIContext().vp2px(1);
  }

  @Monitor('values')
  onValues(): void {
    this.morph = true;
  }

  private paint(): string {
    return sparkChartColor(this.theme, this.color, 0);
  }

  @Computed
  get geo(): SparkGeo {
    const g = new SparkGeo();
    const W = this.measuredWidth;
    const H = this.chartHeight;
    g.w = W;
    g.h = H;
    const n = this.values.length;
    if (W <= 0 || n === 0) {
      return g;
    }
    const k = this.pxRatio;
    const pad = Math.max(this.lineWidth, this.endDot ? 3 : 0) + 1;
    let lo = Number.POSITIVE_INFINITY;
    let hi = Number.NEGATIVE_INFINITY;
    this.values.forEach((v: number) => {
      if (isFinite(v)) {
        lo = Math.min(lo, v);
        hi = Math.max(hi, v);
      }
    });
    if (lo > hi) {
      lo = 0;
      hi = 1;
    }
    const scale = new SparkLinearScale(lo, hi, H - pad, pad);
    const xs = sparkPointPositions(n, pad, W - pad);
    const ys = this.values.map((v: number) => isFinite(v) ? scale.map(v) : H - pad);
    const base: number[] = xs.map((): number => H);
    const mid: number[] = xs.map((): number => H - pad);
    g.line = new SparkChartVec(sparkShapeLine(xs, ys, this.curve, k));
    g.lineFrom = new SparkChartVec(sparkShapeLine(xs, mid, this.curve, k));
    g.area = new SparkChartVec(sparkShapeArea(xs, ys, base, this.curve, k));
    g.areaFrom = new SparkChartVec(sparkShapeArea(xs, mid, base, this.curve, k));
    g.end = new SparkChartVec(sparkShapeDots([xs[n - 1]], [ys[n - 1]], 2.5, k));
    return g;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.geo.w > 0) {
        if (this.filled) {
          SChartPath({
            shape: this.geo.area, from: this.geo.areaFrom, boxWidth: this.geo.w, boxHeight: this.geo.h,
            fillColor: SparkColor.alpha(this.paint(), 0.15), animate: this.morph
          })
        }
        SChartPath({
          shape: this.geo.line, from: this.geo.lineFrom, boxWidth: this.geo.w, boxHeight: this.geo.h,
          strokeColor: this.paint(), strokeW: this.lineWidth, animate: this.morph
        })
        if (this.endDot) {
          SChartPath({
            shape: this.geo.end, boxWidth: this.geo.w, boxHeight: this.geo.h, fillColor: this.paint(),
            animate: this.morph
          })
        }
      }
    }
    .width('100%')
    .height(this.chartHeight)
    .hitTestBehavior(HitTestMode.Transparent)
    .onAreaChange((_: Area, a: Area) => {
      const w = Number(a.width);
      if (Math.abs(w - this.measuredWidth) > 0.5) {
        this.morph = false;
        this.measuredWidth = w;
      }
    })
  }
}
