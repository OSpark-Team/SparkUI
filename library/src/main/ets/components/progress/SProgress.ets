import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkTone, SparkToneColors, SparkTones } from '../../core/SparkTone';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkProgressArc, sparkRingArcPath, sparkProgressLabel, sparkProgressPercent, sparkSegmentFills } from './ProgressLogic';

/** Form of an SProgress: a bar, a ring, or a 240° gauge (meter). */
export type ProgressShape = 'linear' | 'circle' | 'gauge';
/** Preset size: bar thickness 4 / 8 / 12, ring / gauge diameter 40 / 64 / 96. */
export type ProgressSize = 'sm' | 'default' | 'lg';

/** gap between the parts of a segmented bar (vp) */
const SEGMENT_GAP: number = 4;
/** gauge opening: the arc runs from -120° to +120° */
const GAUGE_START: number = 240;
const GAUGE_SWEEP: number = 240;
/** visible arc of the indeterminate ring */
const SPIN_SWEEP: number = 90;

/** The value arc as an animatable property: the sweep follows `.animation(SparkAnim.attr(…))`. */
@AnimatableExtend(Path)
function sparkProgressArcCommands(arc: SparkProgressArc) {
  .commands(arc.commands())
}

/**
 * shadcn-vue `Progress`, extended with the forms a design system usually needs.
 *
 * - `linear` (default): `h-2 w-full rounded-full bg-primary/20` track, `bg-primary` indicator whose width
 *   animates to `value / max`. Extras: `sizing` / `thickness`, `buffer` (a lighter second bar, e.g. buffered
 *   video), `striped` (+ `animated`), `segments` (a stepped bar of N parts) and `indeterminate` (a sliding bar).
 * - `circle`: a ring (`diameter`, `thickness`) with the value (`showValue` / `valueText`), a `caption` or any slot
 *   content in its centre; `indeterminate` spins a quarter arc.
 * - `gauge`: a 240° meter with the same centre content.
 *
 * `tone` colours the indicator: default (primary) | success | warning | info | destructive.
 *
 * ```
 * SProgress({ value: 66 })
 * SProgress({ value: 40, buffer: 70, sizing: 'sm' })
 * SProgress({ value: 3, max: 5, segments: 5, tone: 'success' })
 * SProgress({ indeterminate: true, label: 'Loading' })
 * SProgress({ value: 72, shape: 'circle', showValue: true })
 * SProgress({ value: 48, shape: 'gauge', tone: 'warning', showValue: true, caption: 'CPU' })
 * SProgress({ value: 4, max: 10, shape: 'circle', diameter: 80 }) { Text('4/10') }
 * ```
 * Infinite motion (indeterminate, moving stripes) lives on its own child node and stops when that node is
 * removed; with motion disabled (`--motion-progress-enabled: false`) a static state is shown instead.
 */
@ComponentV2
export struct SProgress {
  /** 0…max */
  @Param value: number = 0;
  @Param max: number = 100;
  /** Accessible name. */
  @Param label: string | undefined = undefined;
  @Param shape: ProgressShape = 'linear';
  @Param sizing: ProgressSize = 'default';
  /** Bar height / ring stroke in vp; overrides the `sizing` preset. */
  @Param thickness: number | undefined = undefined;
  /** Ring / gauge diameter in vp; overrides the `sizing` preset. */
  @Param diameter: number | undefined = undefined;
  @Param tone: SparkTone = 'default';
  /** Unknown duration: sliding bar (linear) or spinning arc (circle). */
  @Param indeterminate: boolean = false;
  /** linear: secondary (buffered) value, 0…max, drawn lighter behind the indicator. */
  @Param buffer: number | undefined = undefined;
  /** linear: diagonal stripes on the indicator. */
  @Param striped: boolean = false;
  /** linear + striped: the stripes move. */
  @Param animated: boolean = false;
  /** linear: split the track into N equal parts (steps). 0 = continuous. */
  @Param segments: number = 0;
  /** Show the value: right of a bar, in the centre of a ring / gauge. */
  @Param showValue: boolean = false;
  /** Custom value text (default `"66%"`). Implies `showValue`. */
  @Param valueText: ResourceStr | undefined = undefined;
  /** ring / gauge: small muted text under the value. */
  @Param caption: ResourceStr | undefined = undefined;
  /** ring / gauge: custom centre content. */
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local trackWidth: number = 0;

  @Computed
  get percent(): number {
    return sparkProgressPercent(this.value, this.max);
  }

  @Computed
  get bufferPercent(): number {
    return this.buffer === undefined ? 0 : sparkProgressPercent(this.buffer, this.max);
  }

  @Computed
  get colors(): SparkToneColors {
    return SparkTones.resolve(this.theme, this.tone);
  }

  @Computed
  get barThickness(): number {
    if (this.thickness !== undefined) {
      return this.thickness;
    }
    if (this.shape !== 'linear') {
      return this.sizing === 'sm' ? 4 : (this.sizing === 'lg' ? 8 : 6);
    }
    return this.sizing === 'sm' ? 4 : (this.sizing === 'lg' ? 12 : 8);
  }

  @Computed
  get ringDiameter(): number {
    if (this.diameter !== undefined) {
      return this.diameter;
    }
    return this.sizing === 'sm' ? 40 : (this.sizing === 'lg' ? 96 : 64);
  }

  @Computed
  get segmentFills(): number[] {
    return sparkSegmentFills(this.percent, this.segments);
  }

  @Computed
  get segmentIndices(): number[] {
    const out: number[] = [];
    for (let i = 0; i < Math.floor(this.segments); i++) {
      out.push(i);
    }
    return out;
  }

  @Computed
  get displayText(): ResourceStr {
    return this.valueText ?? sparkProgressLabel(this.percent);
  }

  @Computed
  get valueVisible(): boolean {
    return (this.showValue || this.valueText !== undefined) && !this.indeterminate;
  }

  /** ring geometry in px (Path.commands() is in px), stroke centred on the circle */
  private arc(start: number, sweep: number): SparkProgressArc {
    const ctx = this.getUIContext();
    const d = this.ringDiameter;
    const r = Math.max(0, (d - this.barThickness) / 2);
    return new SparkProgressArc(ctx.vp2px(d / 2), ctx.vp2px(d / 2), ctx.vp2px(r), start, sweep);
  }

  @Computed
  get trackCommands(): string {
    const a = this.shape === 'gauge' ? this.arc(GAUGE_START, GAUGE_SWEEP) : this.arc(0, 360);
    return sparkRingArcPath(a.cx, a.cy, a.r, a.start, a.sweep);
  }

  @Computed
  get valueArc(): SparkProgressArc {
    if (this.shape === 'gauge') {
      return this.arc(GAUGE_START, GAUGE_SWEEP * this.percent / 100);
    }
    return this.arc(0, 360 * this.percent / 100);
  }

  /** a gauge is open at the bottom: only reserve the height its arc uses */
  @Computed
  get ringHeight(): number {
    const d = this.ringDiameter;
    if (this.shape !== 'gauge') {
      return d;
    }
    const r = (d - this.barThickness) / 2;
    return Math.ceil(d / 2 + r * 0.5 + this.barThickness / 2);
  }

  @Computed
  get valueFontSize(): number {
    const d = this.ringDiameter;
    const t = this.theme.text;
    if (d < 48) {
      return t.xs;
    }
    if (d < 80) {
      return t.sm;
    }
    return d < 120 ? t.xl : t.xxl;
  }

  @Computed
  get accessibleValue(): string {
    return this.indeterminate ? 'loading' : `${Math.round(this.percent)}%`;
  }

  build() {
    if (this.shape === 'linear') {
      this.linear()
    } else {
      this.ring()
    }
  }

  @Builder
  linear() {
    Row({ space: 8 }) {
      if (this.segments > 0 && !this.indeterminate) {
        Row({ space: SEGMENT_GAP }) {
          ForEach(this.segmentIndices, (i: number) => {
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width(`${(this.segmentFills[i] ?? 0) * 100}%`)
                .height('100%')
                .backgroundColor(this.colors.solid)
                .animation(SparkAnim.attr(this.theme, 'progress', 'slow'))
            }
            .layoutWeight(1)
            .height('100%')
            .backgroundColor(this.colors.track)
            .border({ width: 0, radius: this.barThickness / 2 })
            .clip(true)
          }, (i: number) => `${i}`)
        }
        .layoutWeight(1)
        .height(this.barThickness)
      } else {
        Stack({ alignContent: Alignment.Start }) {
          if (this.buffer !== undefined && !this.indeterminate) {
            Row()
              .width(`${this.bufferPercent}%`)
              .height('100%')
              .backgroundColor(SparkColor.alpha(this.colors.solid, 0.3))
              .animation(SparkAnim.attr(this.theme, 'progress', 'slow'))
          }
          if (this.indeterminate) {
            SProgressSweep({ color: this.colors.solid, trackWidth: this.trackWidth })
          } else {
            Stack({ alignContent: Alignment.Start }) {
              if (this.striped && this.animated) {
                SProgressStripes({
                  color: SparkColor.alpha(this.colors.onSolid, 0.25),
                  trackWidth: this.trackWidth,
                  thickness: this.barThickness,
                  moving: true
                })
              } else if (this.striped) {
                SProgressStripes({
                  color: SparkColor.alpha(this.colors.onSolid, 0.25),
                  trackWidth: this.trackWidth,
                  thickness: this.barThickness,
                  moving: false
                })
              }
            }
            .width(`${this.percent}%`)
            .height('100%')
            .backgroundColor(this.colors.solid)
            .clip(true)
            .animation(SparkAnim.attr(this.theme, 'progress', 'slow'))
          }
        }
        .layoutWeight(1)
        .height(this.barThickness)
        .backgroundColor(this.colors.track)
        .border({ width: 0, radius: this.barThickness / 2 })
        .clip(true)
        .onAreaChange((_: Area, n: Area) => {
          this.trackWidth = Number(n.width);
        })
      }
      if (this.valueVisible) {
        Text(this.displayText)
          .fontSize(this.theme.text.xs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.mutedForeground)
          .fontFeature('"tnum" on')
          .constraintSize({ minWidth: 32 })
          .textAlign(TextAlign.End)
          .maxLines(1)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(this.label ?? '')
    .accessibilityDescription(this.accessibleValue)
  }

  @Builder
  ring() {
    Stack({ alignContent: Alignment.Top }) {
      Shape() {
        Path()
          .commands(this.trackCommands)
          .fill(Color.Transparent)
          .stroke(this.colors.track)
          .strokeWidth(this.barThickness)
          .strokeLineCap(LineCapStyle.Round)
          .antiAlias(true)
        if (!this.indeterminate) {
          Path()
            .sparkProgressArcCommands(this.valueArc)
            .animation(SparkAnim.attr(this.theme, 'progress', 'slow'))
            .fill(Color.Transparent)
            .stroke(this.colors.solid)
            .strokeWidth(this.barThickness)
            .strokeLineCap(LineCapStyle.Round)
            .antiAlias(true)
        }
      }
      .width(this.ringDiameter)
      .height(this.ringDiameter)

      if (this.indeterminate) {
        SProgressSpin({ color: this.colors.solid, diameter: this.ringDiameter, thickness: this.barThickness })
      }

      Column({ space: 2 }) {
        if (this.valueVisible) {
          Text(this.displayText)
            .fontSize(this.valueFontSize)
            .fontWeight(this.theme.text.weightSemibold)
            .fontColor(this.theme.colors.foreground)
            .fontFeature('"tnum" on')
            .maxLines(1)
        }
        if (this.caption !== undefined) {
          Text(this.caption)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
            .maxLines(1)
        }
        this.content()
      }
      .width(this.ringDiameter)
      .height(this.ringDiameter)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding(this.barThickness + 2)
    }
    .width(this.ringDiameter)
    .height(this.ringHeight)
    .flexShrink(0)
    .accessibilityGroup(true)
    .accessibilityText(this.label ?? '')
    .accessibilityDescription(this.accessibleValue)
  }
}

/** Indeterminate bar: a 40% wide indicator sliding across the track forever (own node; removed to stop). */
@ComponentV2
struct SProgressSweep {
  @Param color: string = '#FF000000';
  @Param trackWidth: number = 0;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local x: number = 0;

  @Computed
  get segment(): number {
    return this.trackWidth * 0.4;
  }

  @Monitor('trackWidth')
  restart(): void {
    this.start();
  }

  private start(): void {
    const w = this.trackWidth;
    if (w <= 0) {
      return;
    }
    const seg = w * 0.4;
    const moving = SparkAnim.loop(this.getUIContext(), this.theme, 'progress', 'slow', 5, () => {
      this.x = -seg;
    }, () => {
      this.x = w;
    }, false, 'ease-in-out');
    if (!moving) {
      this.x = (w - seg) / 2;
    }
  }

  build() {
    Row()
      .width(this.segment)
      .height('100%')
      .backgroundColor(this.color)
      .translate({ x: this.x })
      .onAppear(() => this.start())
  }
}

/** Ring spinner: a quarter arc rotating forever (own node; removed to stop). */
@ComponentV2
struct SProgressSpin {
  @Param color: string = '#FF000000';
  @Param diameter: number = 64;
  @Param thickness: number = 6;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local angle: number = 0;

  @Computed
  get commands(): string {
    const ctx = this.getUIContext();
    const r = Math.max(0, (this.diameter - this.thickness) / 2);
    return sparkRingArcPath(ctx.vp2px(this.diameter / 2), ctx.vp2px(this.diameter / 2), ctx.vp2px(r), 0, SPIN_SWEEP);
  }

  build() {
    Shape() {
      Path()
        .commands(this.commands)
        .fill(Color.Transparent)
        .stroke(this.color)
        .strokeWidth(this.thickness)
        .strokeLineCap(LineCapStyle.Round)
        .antiAlias(true)
    }
    .width(this.diameter)
    .height(this.diameter)
    .rotate({ angle: this.angle })
    .onAppear(() => {
      SparkAnim.loop(this.getUIContext(), this.theme, 'progress', 'normal', 5, () => {
        this.angle = 0;
      }, () => {
        this.angle = 360;
      }, false, 'linear');
    })
  }
}

/**
 * Diagonal stripes covering the indicator: a repeating 45° gradient one stripe period wider than the track,
 * translated by one period per cycle when `moving` (the parent swaps the node to start / stop the motion).
 */
@ComponentV2
struct SProgressStripes {
  @Param color: string = '#40FFFFFF';
  @Param trackWidth: number = 0;
  @Param thickness: number = 8;
  @Param moving: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local shift: number = 0;

  /** horizontal stripe period (vp) */
  @Computed
  get period(): number {
    return Math.max(12, this.thickness * 2);
  }

  /** gradient stop of one period: along a 45° gradient the line is (w + h)/√2 long, a period P/√2 */
  @Computed
  get stops(): Array<[ResourceColor, number]> {
    const w = this.trackWidth + this.period;
    const f = Math.min(1, this.period / Math.max(1, w + this.thickness));
    return [[this.color, 0], [this.color, f / 2], ['#00000000', f / 2], ['#00000000', f]];
  }

  build() {
    Row()
      .width(this.trackWidth + this.period)
      .height('100%')
      .linearGradient({ angle: 45, colors: this.stops, repeating: true })
      .translate({ x: this.shift - this.period })
      .onAppear(() => {
        if (!this.moving) {
          return;
        }
        SparkAnim.loop(this.getUIContext(), this.theme, 'progress', 'slow', 3, () => {
          this.shift = 0;
        }, () => {
          this.shift = this.period;
        }, false, 'linear');
      })
  }
}
