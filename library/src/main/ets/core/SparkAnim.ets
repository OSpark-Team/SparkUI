import { curves } from '@kit.ArkUI';
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

  /** Explicit transition around a state change; runs the change directly when motion is off. */
  static run(ctx: UIContext, t: SparkTheme, key: string, speed: SparkSpeed, change: () => void,
    onFinish?: () => void): void {
    const d = SparkAnim.duration(t, key, speed);
    if (d <= 0) {
      change();
      if (onFinish !== undefined) {
        onFinish();
      }
      return;
    }
    ctx.animateTo({ duration: d, curve: SparkAnim.curve(t, key), onFinish: onFinish }, change);
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
