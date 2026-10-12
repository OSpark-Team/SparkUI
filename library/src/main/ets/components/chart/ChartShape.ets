import { PathShape } from '@kit.ArkUI';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkShapeCommands } from './ChartMath';

/**
 * Interpolatable chart shape (see `ChartMath` "shape vectors"). Implements `AnimatableArithmetic` so that
 * `@AnimatableExtend` can morph a Path from one shape to the next frame by frame (official pattern, docs
 * "@AnimatableExtend装饰器：定义可动画属性"). Vectors of different length cannot be blended: the result
 * then jumps to the target (`absolute`).
 */
export class SparkChartVec implements AnimatableArithmetic<SparkChartVec> {
  v: number[];
  /** set on a difference of incompatible vectors: plus() returns it unchanged, multiply() keeps it */
  absolute: boolean;

  constructor(v: number[], absolute?: boolean) {
    this.v = v;
    this.absolute = absolute ?? false;
  }

  plus(rhs: SparkChartVec): SparkChartVec {
    if (rhs.absolute) {
      return new SparkChartVec(rhs.v);
    }
    if (rhs.v.length !== this.v.length) {
      return new SparkChartVec(rhs.v);
    }
    const out: number[] = [];
    for (let i = 0; i < this.v.length; i++) {
      out.push(this.v[i] + rhs.v[i]);
    }
    return new SparkChartVec(out);
  }

  subtract(rhs: SparkChartVec): SparkChartVec {
    if (rhs.v.length !== this.v.length || this.absolute) {
      return new SparkChartVec(this.v, true);
    }
    const out: number[] = [];
    for (let i = 0; i < this.v.length; i++) {
      out.push(this.v[i] - rhs.v[i]);
    }
    return new SparkChartVec(out);
  }

  multiply(scale: number): SparkChartVec {
    if (this.absolute) {
      return this;
    }
    const out: number[] = [];
    for (let i = 0; i < this.v.length; i++) {
      out.push(this.v[i] * scale);
    }
    return new SparkChartVec(out);
  }

  equals(rhs: SparkChartVec): boolean {
    if (rhs.absolute !== this.absolute || rhs.v.length !== this.v.length) {
      return false;
    }
    for (let i = 0; i < this.v.length; i++) {
      if (this.v[i] !== rhs.v[i]) {
        return false;
      }
    }
    return true;
  }

  commands(): string {
    return sparkShapeCommands(this.v);
  }
}

const EMPTY_VEC: SparkChartVec = new SparkChartVec([]);
const NO_ANIMATION: AnimateParam = { duration: 0 };

@AnimatableExtend(Path)
function sparkChartShape(shape: SparkChartVec) {
  .commands(shape.commands())
}

@AnimatableExtend(Column)
function sparkChartClip(shape: SparkChartVec) {
  .clipShape(new PathShape({ commands: shape.commands() }))
}

/**
 * Internal: one animated chart shape. Appears morphing from `from` (the collapsed shape) to `shape`, then
 * morphs on every change of `shape` while `animate` is true (motion key 'chart', speed 'slow').
 * Paint attributes are set on the Path itself (Shape-level paint is not re-propagated to existing Paths).
 */
@ComponentV2
export struct SChartPath {
  @Param shape: SparkChartVec = EMPTY_VEC;
  /** start shape of the enter animation (undefined → appear in place) */
  @Param from: SparkChartVec | undefined = undefined;
  /** size of the drawing box in vp (shapes use absolute chart coordinates) */
  @Param boxWidth: number = 0;
  @Param boxHeight: number = 0;
  @Param fillColor: ResourceColor = Color.Transparent;
  @Param fillAlpha: number = 1;
  @Param strokeColor: ResourceColor = Color.Transparent;
  @Param strokeW: number = 0;
  @Param dash: number[] = [];
  /** morph changes of `shape` (false while the chart is being resized) */
  @Param animate: boolean = true;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local shown: SparkChartVec = EMPTY_VEC;
  @Local entering: boolean = false;

  aboutToAppear(): void {
    this.shown = this.from ?? this.shape;
  }

  @Monitor('shape')
  onShape(): void {
    this.shown = this.shape;
  }

  private anim(): AnimateParam {
    if (!this.entering && !this.animate) {
      return NO_ANIMATION;
    }
    const p = SparkAnim.attr(this.theme, 'chart', 'slow');
    p.onFinish = () => {
      this.entering = false;
    };
    return p;
  }

  build() {
    Path()
      .width(this.boxWidth)
      .height(this.boxHeight)
      .fill(this.fillColor)
      .fillOpacity(this.fillAlpha)
      .stroke(this.strokeColor)
      .strokeWidth(this.strokeW)
      .strokeDashArray(this.dash)
      .strokeLineJoin(LineJoinStyle.Round)
      .strokeLineCap(LineCapStyle.Round)
      .antiAlias(true)
      .sparkChartShape(this.shown)
      .animation(this.anim())
      .hitTestBehavior(HitTestMode.Transparent)
      .onAppear(() => {
        if (this.from !== undefined) {
          this.entering = true;
          this.shown = this.shape;
        }
      })
  }
}

/** Internal: an area filled with a vertical gradient (shadcn "Area Chart - Gradient"), clipped to the shape. */
@ComponentV2
export struct SChartGradient {
  @Param shape: SparkChartVec = EMPTY_VEC;
  @Param from: SparkChartVec | undefined = undefined;
  @Param boxWidth: number = 0;
  @Param boxHeight: number = 0;
  /** gradient colours, top → bottom */
  @Param topColor: ResourceColor = Color.Transparent;
  @Param bottomColor: ResourceColor = Color.Transparent;
  @Param animate: boolean = true;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local shown: SparkChartVec = EMPTY_VEC;
  @Local entering: boolean = false;

  aboutToAppear(): void {
    this.shown = this.from ?? this.shape;
  }

  @Monitor('shape')
  onShape(): void {
    this.shown = this.shape;
  }

  private anim(): AnimateParam {
    if (!this.entering && !this.animate) {
      return NO_ANIMATION;
    }
    const p = SparkAnim.attr(this.theme, 'chart', 'slow');
    p.onFinish = () => {
      this.entering = false;
    };
    return p;
  }

  build() {
    Column()
      .width(this.boxWidth)
      .height(this.boxHeight)
      .linearGradient({ direction: GradientDirection.Bottom, colors: [[this.topColor, 0], [this.bottomColor, 1]] })
      .sparkChartClip(this.shown)
      .animation(this.anim())
      .hitTestBehavior(HitTestMode.Transparent)
      .onAppear(() => {
        if (this.from !== undefined) {
          this.entering = true;
          this.shown = this.shape;
        }
      })
  }
}
