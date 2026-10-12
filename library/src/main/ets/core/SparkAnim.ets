import { curves, UIUtils } from '@kit.ArkUI';
import { SparkMotionOverride, SparkTheme } from '../theme/tokens/SparkTheme';

/** Base speed of a component animation; maps to the duration tokens. */
export type SparkSpeed = 'fast' | 'normal' | 'slow';

/** Default easing per base speed when nothing is configured. */
const DEFAULT_EASE: string = 'standard';

/**
 * CSS-like motion for SparkUI components (the `transition` equivalent).
 *
 * Every animated component has a motion key ('accordion', 'tabs', 'checkbox', 'dialog', 'toast' …).
 * Its duration / easing / on-off come from, in order:
 *   1. `--motion-<key>-duration | -ease | -enabled` (theme file or `SparkUI.themes.setMotion()`)
 *   2. the component's base speed token (`--duration-fast|normal|slow`) and the standard curve
 * and `--motion-enabled: false` turns every SparkUI animation off (useful for reduced motion / tests).
 *
 * Two ways to use it:
 * ```
 * Column().height(h).animation(SparkAnim.attr(this.theme, 'accordion', 'normal'))   // implicit
 * SparkAnim.run(this.getUIContext(), this.theme, 'tabs', 'fast', () => { this.value = v; })  // explicit
 * ```
 * Rule (component-guide §3): never attach these to the attribute chain that carries pressed styles.
 */
export class SparkAnim {
  /** Resolved duration in ms (0 when disabled). */
  static duration(t: SparkTheme, key: string, speed: SparkSpeed): number {
    const m = t.motion;
    if (!m.enabled || m.version < 0) {
      return 0;
    }
    const o: SparkMotionOverride | undefined = m.overrides.get(key);
    if (o !== undefined && o.enabled === false) {
      return 0;
    }
    if (o !== undefined && o.duration !== undefined) {
      return o.duration;
    }
    return speed === 'fast' ? m.durationFast : (speed === 'slow' ? m.durationSlow : m.durationNormal);
  }

  /** Resolved curve for `key`. */
  static curve(t: SparkTheme, key: string): ICurve {
    const o: SparkMotionOverride | undefined = t.motion.overrides.get(key);
    return SparkAnim.parseCurve(o?.ease ?? DEFAULT_EASE, t);
  }

  /** For `.animation()`: implicit property animation. Duration 0 when motion is off. */
  static attr(t: SparkTheme, key: string, speed: SparkSpeed): AnimateParam {
    return { duration: SparkAnim.duration(t, key, speed), curve: SparkAnim.curve(t, key) };
  }

  /**
   * Explicit transition around a state change; runs the change directly when motion is off.
   *
   * State Management V2 marks components dirty in a micro-task, while `animateTo` captures dirty nodes
   * immediately: a plain V2 change inside the closure — and every change made from `@Monitor` — would skip
   * the animation. The change is therefore applied with `UIUtils.applySync` inside the closure, the
   * official V2 pattern (docs: "applySync/flushUpdates/flushUIUpdates接口：同步刷新").
   */
  static run(ctx: UIContext, t: SparkTheme, key: string, speed: SparkSpeed, change: () => void,
    onFinish?: () => void): void {
    const d = SparkAnim.duration(t, key, speed);
    if (d <= 0) {
      SparkAnim.commit(change);
      if (onFinish !== undefined) {
        onFinish();
      }
      return;
    }
    ctx.animateTo({ duration: d, curve: SparkAnim.curve(t, key), onFinish: onFinish }, () => {
      SparkAnim.commit(change);
    });
  }

  /**
   * `run` with an already-resolved duration / curve (e.g. a per-instance override that was resolved against the
   * theme first, see `sparkTransitionTiming`). Duration ≤ 0 commits the change directly.
   */
  static runWith(ctx: UIContext, duration: number, curve: ICurve, change: () => void, onFinish?: () => void): void {
    if (duration <= 0) {
      SparkAnim.commit(change);
      if (onFinish !== undefined) {
        onFinish();
      }
      return;
    }
    ctx.animateTo({ duration: duration, curve: curve, onFinish: onFinish }, () => {
      SparkAnim.commit(change);
    });
  }

  /**
   * Infinite animation (indeterminate progress, skeleton pulse / shimmer, spin): `reset` is committed first
   * (synchronously, so it is never folded into the animation), then `change` repeats forever.
   *
   * The cycle is `factor` × the key's duration (`--motion-<key>-duration` or the speed token), so it follows the
   * motion configuration; `ease` is used unless the key configures its own easing. Returns false (after applying
   * only `reset`) when motion is off for the key — callers then render a static state.
   *
   * Rule (component-guide §3.5): run it from `onAppear` of a node that exists only while the animation is
   * wanted, and remove that node to stop it.
   */
  static loop(ctx: UIContext, t: SparkTheme, key: string, speed: SparkSpeed, factor: number, reset: () => void,
    change: () => void, alternate?: boolean, ease?: string): boolean {
    SparkAnim.commit(reset);
    const d = SparkAnim.duration(t, key, speed) * factor;
    if (d <= 0) {
      return false;
    }
    const o: SparkMotionOverride | undefined = t.motion.overrides.get(key);
    const curve: ICurve = o?.ease !== undefined ? SparkAnim.parseCurve(o.ease, t) :
      SparkAnim.parseCurve(ease ?? DEFAULT_EASE, t);
    ctx.animateTo({
      duration: d,
      curve: curve,
      iterations: -1,
      playMode: alternate === true ? PlayMode.Alternate : PlayMode.Normal
    }, () => {
      SparkAnim.commit(change);
    });
    return true;
  }

  /**
   * Apply V2 state changes synchronously (`UIUtils.applySync`): computed values, monitors and UI update now.
   * Use it for changes that must NOT become part of a following animation (e.g. a selection published
   * before a theme colour transition). A nested applySync is skipped by the framework; the change then runs
   * directly and is flushed by the outer call.
   */
  static commit(change: () => void): void {
    let ran = false;
    try {
      UIUtils.applySync(() => {
        ran = true;
        change();
      });
    } catch (e) {
      // not allowed here (e.g. inside @Computed, error 140001): fall back to a normal update
    }
    if (!ran) {
      change();
    }
  }

  /** `TransitionEffect` for appear / disappear of an element (opacity + optional scale / slide). */
  static enter(t: SparkTheme, key: string, speed: SparkSpeed, scaleFrom?: number, slideY?: number): TransitionEffect {
    let e: TransitionEffect = TransitionEffect.OPACITY;
    if (scaleFrom !== undefined) {
      e = e.combine(TransitionEffect.scale({ x: scaleFrom, y: scaleFrom }));
    }
    if (slideY !== undefined) {
      e = e.combine(TransitionEffect.translate({ y: slideY }));
    }
    return e.animation(SparkAnim.attr(t, key, speed));
  }

  /** Parse a CSS-like easing string into an ArkUI curve. Unknown values fall back to the standard curve. */
  static parseCurve(ease: string, t: SparkTheme): ICurve {
    const v = ease.trim().toLowerCase();
    const std = t.motion.easeStandard;
    switch (v) {
      case 'linear':
        return curves.initCurve(Curve.Linear);
      case 'ease':
        return curves.cubicBezierCurve(0.25, 0.1, 0.25, 1);
      case 'ease-in':
        return curves.cubicBezierCurve(t.motion.easeIn[0], t.motion.easeIn[1], t.motion.easeIn[2], t.motion.easeIn[3]);
      case 'ease-out':
        return curves.cubicBezierCurve(t.motion.easeOut[0], t.motion.easeOut[1], t.motion.easeOut[2],
          t.motion.easeOut[3]);
      case 'ease-in-out':
        return curves.cubicBezierCurve(0.42, 0, 0.58, 1);
      case 'friction':
        return curves.initCurve(Curve.Friction);
      case 'sharp':
        return curves.initCurve(Curve.Sharp);
      case 'smooth':
        return curves.initCurve(Curve.Smooth);
      case 'rhythm':
        return curves.initCurve(Curve.Rhythm);
      case 'standard':
        return curves.cubicBezierCurve(std[0], std[1], std[2], std[3]);
      default:
        break;
    }
    const cb = /^cubic-bezier\(([^)]*)\)$/.exec(v);
    if (cb !== null) {
      const n = cb[1].split(',').map((x: string) => parseFloat(x.trim()));
      if (n.length === 4 && !n.some((x: number) => isNaN(x))) {
        return curves.cubicBezierCurve(n[0], n[1], n[2], n[3]);
      }
    }
    const sp = /^spring\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)$/.exec(v);
    if (sp !== null) {
      return curves.springMotion(parseFloat(sp[1]), parseFloat(sp[2]));
    }
    return curves.cubicBezierCurve(std[0], std[1], std[2], std[3]);
  }
}

/** Options for `SparkUI.themes.setMotion()`. */
export interface SparkMotionOptions {
  /** ms */
  duration?: number;
  /** 'ease-out', 'cubic-bezier(0.2, 0, 0, 1)', 'spring(0.4, 0.8)', 'linear' … */
  ease?: string;
  enabled?: boolean;
}
