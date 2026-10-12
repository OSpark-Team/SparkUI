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

/**
 * shadcn-vue `Slider` (single thumb), custom drawn: `h-1.5 rounded-full bg-muted` track, `bg-primary` range,
 * `size-4 rounded-full border border-primary bg-background shadow-sm` thumb with a `ring-4 ring-ring/50` on
 * hover / drag. Drag the thumb or tap the track; arrow keys step when focused.
 *
 * ```
 * SSlider({ value: this.volume!!, max: 100, step: 1 })
 * SSlider({ defaultValue: 0.5, min: 0, max: 1, step: 0.05, onValueChange: (v: number) => ... })
 * ```
 */
@ComponentV2
export struct SSlider {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: number | undefined = undefined;
  @Event $value: (v: number) => void = () => {
  };
  @Param defaultValue: number = 0;
  @Param min: number = 0;
  @Param max: number = 100;
  @Param step: number = 1;
  @Param disabled: boolean = false;
  /** Accessible name. */
  @Param label: string | undefined = undefined;
  @Event onValueChange: (v: number) => void = () => {
  };
  /** Fired once when a drag / tap / key interaction ends. */
  @Event onValueCommit: (v: number) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: number = 0;
  @Local trackWidth: number = 0;
  @Local dragging: boolean = false;
  @Local ix: SparkInteraction = new SparkInteraction();
  @Local field: SparkFieldState | undefined = undefined;

  aboutToAppear(): void {
    this.current = sparkSnapSlider(this.value ?? this.defaultValue, this.min, this.max, this.step);
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

  @Monitor('disabled')
  syncDisabled(): void {
    this.ix.enabled = !this.disabled;
    if (this.disabled) {
      this.ix.reset();
      this.dragging = false;
    }
  }

  @Computed
  get ratio(): number {
    const span = this.max - this.min;
    if (span <= 0) {
      return 0;
    }
    return clamp((this.current - this.min) / span, 0, 1);
  }

  @Computed
  get thumbX(): number {
    return this.ratio * Math.max(0, this.trackWidth - THUMB);
  }

  @Computed
  get tapBlocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  private valueAt(x: number): number {
    const usable = Math.max(1, this.trackWidth - THUMB);
    const r = clamp((x - THUMB / 2) / usable, 0, 1);
    return sparkSnapSlider(this.min + r * (this.max - this.min), this.min, this.max, this.step);
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

  private fingerX(e: GestureEvent): number | undefined {
    if (e.fingerList.length === 0) {
      return undefined;
    }
    return e.fingerList[0].localX;
  }

  private dragTo(e: GestureEvent): void {
    const x = this.fingerX(e);
    if (x !== undefined) {
      this.set(this.valueAt(x));
    }
  }

  private nudge(dir: number): void {
    const st = this.step > 0 ? this.step : 1;
    this.set(sparkSnapSlider(this.current + dir * st, this.min, this.max, this.step));
    this.onValueCommit(this.current);
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // track + range
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width(this.thumbX + THUMB / 2)
          .height(TRACK_H)
          .backgroundColor(this.theme.colors.primary)
          .animation(this.dragging ? { duration: 0 } : SparkAnim.attr(this.theme, 'slider', 'fast'))
      }
      .width('100%')
      .height(TRACK_H)
      .backgroundColor(this.theme.colors.muted)
      .border({ width: 0, radius: TRACK_H / 2 })
      .clip(true)

      // thumb
      Row()
        .width(THUMB)
        .height(THUMB)
        .backgroundColor(this.theme.colors.background)
        .border({ width: 1, color: this.theme.colors.primary, radius: THUMB / 2 })
        .shadow(this.theme.shadows.sm.toOptions())
        .outline({
          width: (this.ix.hovered || this.dragging) ? 4 : 0,
          color: SparkColor.alpha(this.theme.colors.ring, 0.5),
          radius: THUMB / 2 + 4,
          style: OutlineStyle.SOLID
        })
        .translate({ x: this.thumbX })
        .animation(this.dragging ? { duration: 0 } : SparkAnim.attr(this.theme, 'slider', 'fast'))
    }
    .width('100%')
    .height(THUMB)
    .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    // a taller touch target than the 16vp thumb
    .responseRegion({ x: 0, y: -10, width: '100%', height: THUMB + 20 })
    .opacity(this.disabled ? 0.5 : 1)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .gestureModifier(this.tapBlocker)
    .accessibilityText(this.label ?? '')
    .accessibilityDescription(`${this.current}`)
    .onAreaChange((_: Area, n: Area) => {
      this.trackWidth = Number(n.width);
    })
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick((e: ClickEvent) => {
      if (this.disabled) {
        return;
      }
      this.set(this.valueAt(e.x));
      this.onValueCommit(this.current);
    })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 2 })
        .onActionStart((e: GestureEvent) => {
          if (this.disabled) {
            return;
          }
          this.dragging = true;
          this.dragTo(e);
        })
        .onActionUpdate((e: GestureEvent) => {
          if (this.disabled) {
            return;
          }
          this.dragTo(e);
        })
        .onActionEnd(() => {
          if (this.dragging) {
            this.dragging = false;
            this.onValueCommit(this.current);
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
}
