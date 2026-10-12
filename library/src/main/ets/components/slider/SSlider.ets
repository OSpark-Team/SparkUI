import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { KeyCode } from '@kit.InputKit';
import { sparkFocusRing, SparkTapBlocker } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { resolveSparkField, SparkFieldState, sparkFieldGrows } from '../field/SField';

const THUMB: number = 16;
const TRACK_H: number = 6;
/** most step dots drawn by `ticks` (more would be visual noise) */
const MAX_TICKS: number = 41;

export type SliderOrientation = 'horizontal' | 'vertical';
/** When the value bubble above a thumb shows: never, while dragging / hovered / focused, or always. */
export type SliderTooltip = 'none' | 'active' | 'always';

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

function decimalsOf(n: number): number {
  const s = n.toString();
  const i = s.indexOf('.');
  return i < 0 ? 0 : Math.min(10, s.length - i - 1);
}

/** Snap `v` to `min + k·step` inside [min, max] (float-safe). Exported for unit tests. */
export function sparkSnapSlider(v: number, min: number, max: number, step: number): number {
  const st = step > 0 ? step : 1;
  const lo = Math.min(min, max);
  const hi = Math.max(min, max);
  const snapped = Math.round((v - lo) / st) * st + lo;
  const digits = Math.max(decimalsOf(st), decimalsOf(lo));
  return clamp(Number(snapped.toFixed(digits)), lo, hi);
}

/** Snap and order a two-thumb range: `[lo, hi]` with lo ≤ hi. */
export function sparkSnapRange(values: number[], min: number, max: number, step: number): number[] {
  const a = sparkSnapSlider(values.length > 0 ? values[0] : min, min, max, step);
  const b = sparkSnapSlider(values.length > 1 ? values[1] : max, min, max, step);
  return a <= b ? [a, b] : [b, a];
}

/** Move thumb `index` (0 = low, 1 = high) of `range` to `v` without crossing the other thumb. */
export function sparkMoveRangeThumb(range: number[], index: number, v: number): number[] {
  if (index === 0) {
    return [Math.min(v, range[1]), range[1]];
  }
  return [range[0], Math.max(v, range[0])];
}

/** Values of the step dots between min and max (empty when there would be more than `limit`). */
export function sparkSliderTicks(min: number, max: number, step: number, limit: number): number[] {
  const st = step > 0 ? step : 1;
  const count = Math.floor((max - min) / st + 1e-9) + 1;
  if (count < 2 || count > limit) {
    return [];
  }
  const out: number[] = [];
  for (let i = 0; i < count; i++) {
    out.push(sparkSnapSlider(min + i * st, min, max, st));
  }
  return out;
}

/**
 * shadcn-vue `Slider`, custom drawn: `h-1.5 rounded-full bg-muted` track, `bg-primary` range,
 * `size-4 rounded-full border border-primary bg-background shadow-sm` thumb with a `ring-4 ring-ring/50` on
 * hover / drag. Drag a thumb or tap the track; arrow keys step when focused.
 *
 * Variants:
 * - range: pass `values` / `defaultValues` with two numbers for two thumbs (`onValuesChange`); thumbs never cross.
 * - `ticks` (a dot per step) and `marks` (labelled values under / beside the track, via `formatValue`).
 * - `orientation: 'vertical'` (value grows upward; give it a `length`, default 160vp).
 * - keyboard: arrows step the value (in range mode, the thumb touched last).
 * - `tooltip`: 'active' shows the value above the thumb while dragging / hovering / focused, 'always' keeps it.
 *
 * ```
 * SSlider({ value: this.volume!!, max: 100, step: 1 })
 * SSlider({ defaultValue: 0.5, min: 0, max: 1, step: 0.05, onValueChange: (v: number) => ... })
 * SSlider({ values: this.price!!, min: 0, max: 1000, step: 10, tooltip: 'active' })   // range
 * SSlider({ defaultValue: 2, max: 4, step: 1, ticks: true, marks: [0, 1, 2, 3, 4] })
 * SSlider({ defaultValue: 40, orientation: 'vertical', length: 140 })
 * ```
 */
@ComponentV2
export struct SSlider {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: number | undefined = undefined;
  @Event $value: (v: number) => void = () => {
  };
  @Param defaultValue: number = 0;
  /** Controlled two-thumb range `[low, high]` (use with `!!`). */
  @Param values: number[] | undefined = undefined;
  @Event $values: (v: number[]) => void = () => {
  };
  /** Uncontrolled initial range; two numbers turn on range mode. */
  @Param defaultValues: number[] = [];
  @Param min: number = 0;
  @Param max: number = 100;
  @Param step: number = 1;
  @Param disabled: boolean = false;
  @Param orientation: SliderOrientation = 'horizontal';
  /** Length of a vertical slider (vp). */
  @Param length: number = 160;
  /** A dot at every step (up to 41 steps). */
  @Param ticks: boolean = false;
  /** Labelled values along the track. */
  @Param marks: number[] = [];
  @Param tooltip: SliderTooltip = 'none';
  /** Text of tooltips and marks. */
  @Param formatValue: (v: number) => string = (v: number): string => `${v}`;
  /** Accessible name. */
  @Param label: string | undefined = undefined;
  @Event onValueChange: (v: number) => void = () => {
  };
  /** Fired once when a drag / tap / key interaction ends. */
  @Event onValueCommit: (v: number) => void = () => {
  };
  @Event onValuesChange: (v: number[]) => void = () => {
  };
  /** Range mode: fired once when an interaction ends. */
  @Event onValuesCommit: (v: number[]) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: number = 0;
  @Local currentRange: number[] = [0, 0];
  @Local trackLength: number = 0;
  @Local dragging: boolean = false;
  @Local focused: boolean = false;
  /** thumb being dragged / stepped by the keyboard (range mode) */
  @Local active: number = 0;
  @Local ix: SparkInteraction = new SparkInteraction();
  @Local field: SparkFieldState | undefined = undefined;

  aboutToAppear(): void {
    this.current = sparkSnapSlider(this.value ?? this.defaultValue, this.min, this.max, this.step);
    this.currentRange = sparkSnapRange(this.values ?? this.defaultValues, this.min, this.max, this.step);
    this.ix.enabled = !this.disabled;
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.field === undefined) {
      this.field = resolveSparkField(this.getUIContext(), this.getUniqueId());
    }
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.current = sparkSnapSlider(this.value, this.min, this.max, this.step);
    }
  }

  @Monitor('values')
  syncValues(): void {
    if (this.values !== undefined) {
      this.currentRange = sparkSnapRange(this.values, this.min, this.max, this.step);
    }
  }

  @Monitor('disabled')
  syncDisabled(): void {
    this.ix.enabled = !this.disabled;
    if (this.disabled) {
      this.ix.reset();
      this.dragging = false;
    }
  }

  @Computed
  get isRange(): boolean {
    return (this.values ?? this.defaultValues).length >= 2;
  }

  @Computed
  get vertical(): boolean {
    return this.orientation === 'vertical';
  }

  private ratioOf(v: number): number {
    const span = this.max - this.min;
    if (span <= 0) {
      return 0;
    }
    return clamp((v - this.min) / span, 0, 1);
  }

  /** distance of a thumb's leading edge from the start of the axis (left, or bottom when vertical) */
  private posOf(v: number): number {
    return this.ratioOf(v) * Math.max(0, this.trackLength - THUMB);
  }

  /** thumb values: [value] or [low, high] */
  @Computed
  get thumbValues(): number[] {
    return this.isRange ? this.currentRange : [this.current];
  }

  @Computed
  get thumbIndices(): number[] {
    return this.isRange ? [0, 1] : [0];
  }

  /** filled part of the track along the axis: [start, end] in vp from the axis start */
  @Computed
  get fill(): number[] {
    const end = this.posOf(this.thumbValues[this.thumbValues.length - 1]) + THUMB / 2;
    const start = this.isRange ? this.posOf(this.thumbValues[0]) + THUMB / 2 : 0;
    return [start, end];
  }

  @Computed
  get tickValues(): number[] {
    return this.ticks ? sparkSliderTicks(this.min, this.max, this.step, MAX_TICKS) : [];
  }

  @Computed
  get tapBlocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  @Computed
  get motion(): AnimateParam {
    return this.dragging ? { duration: 0 } : SparkAnim.attr(this.theme, 'slider', 'fast');
  }

  @Computed
  get accessibleValue(): string {
    return this.isRange ? `${this.currentRange[0]} – ${this.currentRange[1]}` : `${this.current}`;
  }

  /** a value inside the filled range (ticks there use the contrasting colour) */
  private inFill(v: number): boolean {
    if (this.isRange) {
      return v >= this.currentRange[0] && v <= this.currentRange[1];
    }
    return v <= this.current;
  }

  /** axis offset → [x, y] of a node of `size` along the axis, keeping the cross axis at `cross` */
  private place(axisPos: number, cross: number, size: number): number[] {
    if (this.vertical) {
      return [cross, this.trackLength - axisPos - size];
    }
    return [axisPos, cross];
  }

  private valueAt(p: number): number {
    const usable = Math.max(1, this.trackLength - THUMB);
    let r = clamp((p - THUMB / 2) / usable, 0, 1);
    if (this.vertical) {
      r = 1 - r;
    }
    return sparkSnapSlider(this.min + r * (this.max - this.min), this.min, this.max, this.step);
  }

  /** nearest thumb to an axis position (range mode) */
  private nearest(v: number): number {
    const d0 = Math.abs(v - this.currentRange[0]);
    const d1 = Math.abs(v - this.currentRange[1]);
    if (d0 === d1) {
      return v > this.currentRange[1] ? 1 : (v < this.currentRange[0] ? 0 : this.active);
    }
    return d0 < d1 ? 0 : 1;
  }

  private set(v: number): void {
    if (v === this.current) {
      return;
    }
    // also when controlled: keeps the thumb under the finger even if the parent does not bind the value back
    this.current = v;
    this.$value(v);
    this.onValueChange(v);
  }

  private setRange(r: number[]): void {
    if (r[0] === this.currentRange[0] && r[1] === this.currentRange[1]) {
      return;
    }
    this.currentRange = r;
    this.$values([r[0], r[1]]);
    this.onValuesChange([r[0], r[1]]);
  }

  private moveTo(v: number): void {
    if (this.isRange) {
      this.setRange(sparkMoveRangeThumb(this.currentRange, this.active, v));
    } else {
      this.set(v);
    }
  }

  private commit(): void {
    if (this.isRange) {
      this.onValuesCommit([this.currentRange[0], this.currentRange[1]]);
    } else {
      this.onValueCommit(this.current);
    }
  }

  private fingerPos(e: GestureEvent): number | undefined {
    if (e.fingerList.length === 0) {
      return undefined;
    }
    return this.vertical ? e.fingerList[0].localY : e.fingerList[0].localX;
  }

  private dragTo(e: GestureEvent, pick: boolean): void {
    const p = this.fingerPos(e);
    if (p === undefined) {
      return;
    }
    const v = this.valueAt(p);
    if (pick && this.isRange) {
      this.active = this.nearest(v);
    }
    this.moveTo(v);
  }

  private nudge(dir: number): void {
    const st = this.step > 0 ? this.step : 1;
    const from = this.isRange ? this.currentRange[this.active] : this.current;
    this.moveTo(sparkSnapSlider(from + dir * st, this.min, this.max, this.step));
    this.commit();
  }

  private showTooltip(i: number): boolean {
    if (this.tooltip === 'always') {
      return true;
    }
    if (this.tooltip !== 'active') {
      return false;
    }
    const engaged = this.dragging || this.ix.hovered || this.focused;
    return engaged && (!this.isRange || this.active === i);
  }

  build() {
    if (this.vertical) {
      Row({ space: 8 }) {
        this.slider()
        if (this.marks.length > 0) {
          this.markLabels()
        }
      }
      .height(this.length)
      .alignItems(VerticalAlign.Top)
    } else {
      Column({ space: 6 }) {
        this.slider()
        if (this.marks.length > 0) {
          this.markLabels()
        }
      }
      .width('100%')
      .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    }
  }

  @Builder
  slider() {
    Stack({ alignContent: Alignment.TopStart }) {
      // track
      Stack({ alignContent: Alignment.TopStart }) {
        // range
        Row()
          .translate(this.vertical ? { x: 0, y: this.trackLength - this.fill[1] } : { x: this.fill[0], y: 0 })
          .width(this.vertical ? TRACK_H : Math.max(0, this.fill[1] - this.fill[0]))
          .height(this.vertical ? Math.max(0, this.fill[1] - this.fill[0]) : TRACK_H)
          .backgroundColor(this.theme.colors.primary)
          .animation(this.motion)
      }
      .width(this.vertical ? TRACK_H : '100%')
      .height(this.vertical ? '100%' : TRACK_H)
      .position(this.vertical ? { x: (THUMB - TRACK_H) / 2, y: 0 } : { x: 0, y: (THUMB - TRACK_H) / 2 })
      .backgroundColor(this.theme.colors.muted)
      .border({ width: 0, radius: TRACK_H / 2 })
      .clip(true)

      // step dots
      ForEach(this.tickValues, (v: number) => {
        Row()
          .width(4)
          .height(4)
          .position({
            x: this.place(this.posOf(v) + THUMB / 2 - 2, (THUMB - 4) / 2, 4)[0],
            y: this.place(this.posOf(v) + THUMB / 2 - 2, (THUMB - 4) / 2, 4)[1]
          })
          .backgroundColor(this.inFill(v) ? SparkColor.alpha(this.theme.colors.primaryForeground, 0.7) :
            SparkColor.alpha(this.theme.colors.mutedForeground, 0.5))
          .border({ width: 0, radius: 2 })
          .hitTestBehavior(HitTestMode.None)
      }, (v: number) => `${v}`)

      // thumbs (+ value bubbles)
      ForEach(this.thumbIndices, (i: number) => {
        Stack({ alignContent: Alignment.Bottom }) {
          if (this.showTooltip(i)) {
            Text(this.formatValue(this.thumbValues[i] ?? 0))
              .fontSize(this.theme.text.xs)
              .fontWeight(this.theme.text.weightMedium)
              .fontColor(this.theme.colors.primaryForeground)
              .fontFeature('"tnum" on')
              .maxLines(1)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor(this.theme.colors.primary)
              .border({ width: 0, radius: this.theme.radiusSm })
              .position({ x: '50%', y: -8 })
              .markAnchor({ x: '50%', y: '100%' })
              .hitTestBehavior(HitTestMode.None)
              .transition(SparkAnim.enter(this.theme, 'tooltip', 'fast', 0.9))
          }
          Row()
            .width(THUMB)
            .height(THUMB)
            .backgroundColor(this.theme.colors.background)
            .border({ width: 1, color: this.theme.colors.primary, radius: THUMB / 2 })
            .shadow(this.theme.shadows.sm.toOptions())
            .outline({
              width: (this.ix.hovered || this.dragging) && (!this.isRange || this.active === i) ? 4 : 0,
              color: SparkColor.alpha(this.theme.colors.ring, 0.5),
              radius: THUMB / 2 + 4,
              style: OutlineStyle.SOLID
            })
        }
        .width(THUMB)
        .height(THUMB)
        .translate({
          x: this.place(this.posOf(this.thumbValues[i] ?? 0), 0, THUMB)[0],
          y: this.place(this.posOf(this.thumbValues[i] ?? 0), 0, THUMB)[1]
        })
        .animation(this.motion)
      }, (i: number) => `${i}`)
    }
    .width(this.vertical ? THUMB : '100%')
    .height(this.vertical ? '100%' : THUMB)
    // a larger touch target than the 16vp thumb
    .responseRegion(this.vertical ? { x: -10, y: 0, width: THUMB + 20, height: '100%' } :
      { x: 0, y: -10, width: '100%', height: THUMB + 20 })
    .opacity(this.disabled ? 0.5 : 1)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .gestureModifier(this.tapBlocker)
    .accessibilityText(this.label ?? '')
    .accessibilityDescription(this.accessibleValue)
    .onAreaChange((_: Area, n: Area) => {
      this.trackLength = Number(this.vertical ? n.height : n.width);
    })
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onFocus(() => {
      this.focused = true;
    })
    .onBlur(() => {
      this.focused = false;
    })
    .onClick((e: ClickEvent) => {
      if (this.disabled) {
        return;
      }
      const v = this.valueAt(this.vertical ? e.y : e.x);
      if (this.isRange) {
        this.active = this.nearest(v);
      }
      this.moveTo(v);
      this.commit();
    })
    .gesture(
      PanGesture({ direction: this.vertical ? PanDirection.Vertical : PanDirection.Horizontal, distance: 2 })
        .onActionStart((e: GestureEvent) => {
          if (this.disabled) {
            return;
          }
          this.dragging = true;
          this.dragTo(e, true);
        })
        .onActionUpdate((e: GestureEvent) => {
          if (this.disabled) {
            return;
          }
          this.dragTo(e, false);
        })
        .onActionEnd(() => {
          if (this.dragging) {
            this.dragging = false;
            this.commit();
          }
        })
        .onActionCancel(() => {
          this.dragging = false;
        })
    )
    .onKeyEvent((e: KeyEvent) => {
      if (this.disabled || e.type !== KeyType.Down) {
        return;
      }
      if (e.keyCode === KeyCode.KEYCODE_DPAD_RIGHT || e.keyCode === KeyCode.KEYCODE_DPAD_UP) {
        this.nudge(1);
      } else if (e.keyCode === KeyCode.KEYCODE_DPAD_LEFT || e.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
        this.nudge(-1);
      }
    })
  }

  /** labelled marks: under a horizontal slider, beside a vertical one */
  @Builder
  markLabels() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.marks, (v: number) => {
        Text(this.formatValue(v))
          .fontSize(this.theme.text.xs)
          .fontColor(this.inFill(v) ? this.theme.colors.foreground : this.theme.colors.mutedForeground)
          .fontFeature('"tnum" on')
          .maxLines(1)
          .position(this.vertical ? { x: 0, y: this.trackLength - this.posOf(v) - THUMB / 2 } :
            { x: this.posOf(v) + THUMB / 2, y: 0 })
          .markAnchor(this.vertical ? { x: 0, y: '50%' } : { x: '50%', y: 0 })
      }, (v: number) => `${v}`)
    }
    .width(this.vertical ? 48 : '100%')
    .height(this.vertical ? '100%' : 16)
    .hitTestBehavior(HitTestMode.None)
  }
}
