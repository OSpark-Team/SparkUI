import { SparkAnim, SparkSpeed } from '../../core/SparkAnim';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkEffectSpec, SparkTransitionSpec, sparkTransitionSpec } from './TransitionSpec';

/** Context handed to custom effect factories. */
export class SparkTransitionEnv {
  /** Navigation direction of this change (always true for STransition / STransitionGroup). */
  forward: boolean = true;
  /** Resolved duration in ms (never 0: factories are not called when motion is off). */
  duration: number = 0;
  curve: ICurve | undefined = undefined;
}

/**
 * Custom enter / leave effect. Effects without their own `.animation()` inherit the resolved duration and curve.
 * ```
 * enterEffect: (env: SparkTransitionEnv) => TransitionEffect.rotate({ z: 1, angle: env.forward ? 90 : -90 })
 *   .combine(TransitionEffect.OPACITY)
 * ```
 */
export type SparkTransitionEffectFactory = (env: SparkTransitionEnv) => TransitionEffect;

/** Resolved timing of a transition instance. duration 0 = motion off (instant, hooks fire synchronously). */
export class SparkTransitionTiming {
  duration: number = 0;
  curve: ICurve;

  constructor(duration: number, curve: ICurve) {
    this.duration = duration;
    this.curve = curve;
  }
}

/**
 * Timing from the motion key (`--motion-<key>-*`, speed token) with optional per-instance overrides.
 * `--motion-enabled: false` or `--motion-<key>-enabled: false` always wins (duration 0).
 */
export function sparkTransitionTiming(t: SparkTheme, key: string, speed: SparkSpeed, duration: number,
  ease: string): SparkTransitionTiming {
  const base = SparkAnim.duration(t, key, speed);
  const d = base <= 0 ? 0 : (duration >= 0 ? duration : base);
  const c = ease.trim().length > 0 ? SparkAnim.parseCurve(ease, t) : SparkAnim.curve(t, key);
  return new SparkTransitionTiming(d, c);
}

/** One side of a preset as a TransitionEffect (each segment carries its own animation parameters). */
export function sparkEffectFromSpec(s: SparkEffectSpec, timing: SparkTransitionTiming): TransitionEffect {
  if (s.none || timing.duration <= 0) {
    return TransitionEffect.IDENTITY;
  }
  const d = timing.duration;
  // opacity 1 equals the default and would not animate at all (docs): 0.99 keeps a finish callback
  let e: TransitionEffect = TransitionEffect.opacity(s.opacity >= 1 ? 0.99 : s.opacity).animation({
    duration: Math.round(d * s.opacityDuration), delay: Math.round(d * s.opacityDelay), curve: timing.curve
  });
  if (s.hasTransform()) {
    let tr: TransitionEffect | undefined = undefined;
    if (s.translateX.length > 0 || s.translateY.length > 0) {
      const o: TranslateOptions = {};
      if (s.translateX.length > 0) {
        o.x = s.translateX;
      }
      if (s.translateY.length > 0) {
        o.y = s.translateY;
      }
      tr = TransitionEffect.translate(o);
    }
    if (s.scale !== 1) {
      const sc = TransitionEffect.scale({ x: s.scale, y: s.scale });
      tr = tr === undefined ? sc : tr.combine(sc);
    }
    if (tr !== undefined) {
      e = e.combine(tr.animation({
        duration: Math.round(d * s.transformDuration), delay: Math.round(d * s.transformDelay), curve: timing.curve
      }));
    }
  }
  return e;
}

/** A custom effect with the resolved timing as its default animation parameters. */
export function sparkCustomEffect(f: SparkTransitionEffectFactory, forward: boolean,
  timing: SparkTransitionTiming): TransitionEffect {
  if (timing.duration <= 0) {
    return TransitionEffect.IDENTITY;
  }
  const env = new SparkTransitionEnv();
  env.forward = forward;
  env.duration = timing.duration;
  env.curve = timing.curve;
  // A preceding effect's animation parameters apply to the following combined effects (TransitionEffect docs).
  // The carrier must be a real effect: IDENTITY means "no transition" and drops the whole chain (the custom
  // effect then appeared / vanished instantly). opacity(0.99) is the near-invisible carrier the docs' own
  // example uses; it also guarantees a finish callback for out-in / in-out sequencing.
  return TransitionEffect.opacity(0.99).animation({ duration: timing.duration, curve: timing.curve }).combine(f(env));
}

/**
 * Full asymmetric enter / leave effect for a preset, with optional custom factories replacing either side.
 */
export function sparkTransitionEffect(name: string, forward: boolean, distance: string, timing: SparkTransitionTiming,
  enter?: SparkTransitionEffectFactory, leave?: SparkTransitionEffectFactory): TransitionEffect {
  if (timing.duration <= 0) {
    return TransitionEffect.IDENTITY;
  }
  const spec: SparkTransitionSpec = sparkTransitionSpec(name, forward, distance);
  const inE = enter !== undefined ? sparkCustomEffect(enter, forward, timing) : sparkEffectFromSpec(spec.enter, timing);
  const outE = leave !== undefined ? sparkCustomEffect(leave, forward, timing) :
    sparkEffectFromSpec(spec.leave, timing);
  return TransitionEffect.asymmetric(inE, outE);
}

/**
 * True when one side (enter or leave) animates; otherwise its after-hook fires synchronously and an 'out-in' /
 * 'in-out' sequence continues immediately (an IDENTITY transition has no finish callback to wait for).
 */
export function sparkTransitionSideAnimates(name: string, timing: SparkTransitionTiming,
  custom?: SparkTransitionEffectFactory): boolean {
  return timing.duration > 0 && (name !== 'none' || custom !== undefined);
}
