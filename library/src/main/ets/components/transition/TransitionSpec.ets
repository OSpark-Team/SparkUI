/**
 * Pure transition helpers (no ArkUI runtime): preset → effect parameters, navigation direction resolution.
 * Unit-tested in `library/src/test/Transition.test.ets`; `SparkTransitionEffect.ets` turns a spec into a
 * `TransitionEffect`.
 */

/**
 * Named presets (Vue `<Transition name>` equivalents, plus Material motion patterns).
 * - 'fade': opacity only.
 * - 'slide-left' | 'slide-right' | 'slide-up' | 'slide-down': the content moves in the named direction by `distance`
 *   (new from the opposite side, old out towards the named side) while fading; reversed on back navigation.
 * - 'scale': fade + scale from 0.9 (symmetric). 'zoom': zoom-through (in from 0.85, out to 1.15; reversed on back).
 * - 'fade-through' (Material): old fades out in the first 35 %, new fades + scales in from 0.92 afterwards.
 * - 'shared-axis-x' | 'shared-axis-y' | 'shared-axis-z' (Material): 30 vp slide (or 0.8 / 1.1 scale) along the
 *   axis with a fade-through crossfade; direction-aware.
 * - 'none': no animation.
 */
export type SparkTransitionName = 'fade' | 'slide-left' | 'slide-right' | 'slide-up' | 'slide-down' | 'scale' |
  'zoom' | 'fade-through' | 'shared-axis-x' | 'shared-axis-y' | 'shared-axis-z' | 'none';

/** Vue `<Transition mode>`: 'default' runs leave and enter simultaneously. */
export type SparkTransitionMode = 'default' | 'out-in' | 'in-out';

/** Navigation direction; 'auto' resolves from `index`, then `order`, then the visit history. */
export type SparkNavDirection = 'forward' | 'back' | 'auto';

/** Material shared-axis offset. */
export const SPARK_SHARED_AXIS_OFFSET: string = '30vp';
/** Material fade-through / shared-axis split: the outgoing fade takes this fraction of the duration. */
export const SPARK_FADE_THROUGH_SPLIT: number = 0.35;
export const SPARK_SHARED_AXIS_SPLIT: number = 0.3;

/**
 * One side (enter or leave) of a transition. Values are the *off-screen* state: the start of an enter and the end
 * of a leave. Timings are fractions of the resolved duration.
 */
export class SparkEffectSpec {
  /** true → no effect at all (TransitionEffect.IDENTITY). */
  none: boolean = false;
  opacity: number = 1;
  /** Length string ('100%', '-30vp'); '' = no translation on that axis. */
  translateX: string = '';
  translateY: string = '';
  scale: number = 1;
  opacityDelay: number = 0;
  opacityDuration: number = 1;
  transformDelay: number = 0;
  transformDuration: number = 1;

  hasTransform(): boolean {
    return this.translateX.length > 0 || this.translateY.length > 0 || this.scale !== 1;
  }

  /** Longest segment end, as a fraction of the duration. */
  span(): number {
    if (this.none) {
      return 0;
    }
    const o = this.opacity !== 1 ? this.opacityDelay + this.opacityDuration : 0;
    const t = this.hasTransform() ? this.transformDelay + this.transformDuration : 0;
    return Math.max(o, t);
  }
}

export class SparkTransitionSpec {
  enter: SparkEffectSpec = new SparkEffectSpec();
  leave: SparkEffectSpec = new SparkEffectSpec();
}

/** '100%' → '-100%', '-30vp' → '30vp', '' → ''. */
export function sparkNegateLength(v: string): string {
  const s = v.trim();
  if (s.length === 0) {
    return '';
  }
  return s.startsWith('-') ? s.substring(1) : '-' + s;
}

function fade(e: SparkEffectSpec): SparkEffectSpec {
  e.opacity = 0;
  return e;
}

function timed(e: SparkEffectSpec, oDelay: number, oDur: number, tDelay: number, tDur: number): SparkEffectSpec {
  e.opacityDelay = oDelay;
  e.opacityDuration = oDur;
  e.transformDelay = tDelay;
  e.transformDuration = tDur;
  return e;
}

/**
 * Parameters for a preset. `forward` = false mirrors direction-aware presets (back navigation).
 * `distance` is the slide distance of the 'slide-*' presets (length string, default '100%' of the element).
 * Unknown names fall back to 'fade'.
 */
export function sparkTransitionSpec(name: string, forward: boolean, distance?: string): SparkTransitionSpec {
  const r = new SparkTransitionSpec();
  const d = distance !== undefined && distance.trim().length > 0 ? distance.trim() : '100%';
  const enter = r.enter;
  const leave = r.leave;
  switch (name) {
    case 'none':
      enter.none = true;
      leave.none = true;
      return r;
    case 'slide-left':
    case 'slide-right':
    case 'slide-up':
    case 'slide-down': {
      // content travels towards the named side: the new one comes from the opposite side
      const towardsStart = name === 'slide-left' || name === 'slide-up';
      const sign = towardsStart === forward;
      const inFrom = sign ? d : sparkNegateLength(d);
      const outTo = sparkNegateLength(inFrom);
      if (name === 'slide-left' || name === 'slide-right') {
        fade(enter).translateX = inFrom;
        fade(leave).translateX = outTo;
      } else {
        fade(enter).translateY = inFrom;
        fade(leave).translateY = outTo;
      }
      return r;
    }
    case 'scale':
      fade(enter).scale = 0.9;
      fade(leave).scale = 0.9;
      return r;
    case 'zoom':
      fade(enter).scale = forward ? 0.85 : 1.15;
      fade(leave).scale = forward ? 1.15 : 0.85;
      return r;
    case 'fade-through': {
      const s = SPARK_FADE_THROUGH_SPLIT;
      fade(leave);
      timed(leave, 0, s, 0, s);
      fade(enter).scale = 0.92;
      timed(enter, s, 1 - s, s, 1 - s);
      return r;
    }
    case 'shared-axis-x':
    case 'shared-axis-y':
    case 'shared-axis-z': {
      const s = SPARK_SHARED_AXIS_SPLIT;
      fade(enter);
      fade(leave);
      timed(leave, 0, s, 0, 1);
      timed(enter, s, 1 - s, 0, 1);
      if (name === 'shared-axis-z') {
        enter.scale = forward ? 0.8 : 1.1;
        leave.scale = forward ? 1.1 : 0.8;
      } else {
        const inFrom = forward ? SPARK_SHARED_AXIS_OFFSET : sparkNegateLength(SPARK_SHARED_AXIS_OFFSET);
        if (name === 'shared-axis-x') {
          enter.translateX = inFrom;
          leave.translateX = sparkNegateLength(inFrom);
        } else {
          enter.translateY = inFrom;
          leave.translateY = sparkNegateLength(inFrom);
        }
      }
      return r;
    }
    default:
      fade(enter);
      fade(leave);
      return r;
  }
}

/**
 * Navigation history for `navDirection: 'auto'` without an order / index: going to the page before the current
 * one counts as back (and pops it), anything else is forward (and pushes).
 */
export class SparkTransitionHistory {
  private stack: string[] = [];
  private limit: number;

  constructor(limit?: number) {
    this.limit = limit !== undefined && limit > 1 ? limit : 64;
  }

  /** Current key (or '' when empty). */
  top(): string {
    return this.stack.length > 0 ? this.stack[this.stack.length - 1] : '';
  }

  size(): number {
    return this.stack.length;
  }

  /** Record a visit; returns true for forward, false for back. */
  visit(key: string): boolean {
    const n = this.stack.length;
    if (n > 0 && this.stack[n - 1] === key) {
      return true;
    }
    if (n >= 2 && this.stack[n - 2] === key) {
      this.stack.pop();
      return false;
    }
    this.stack.push(key);
    if (this.stack.length > this.limit) {
      this.stack.shift();
    }
    return true;
  }

  reset(key?: string): void {
    this.stack = key !== undefined && key.length > 0 ? [key] : [];
  }
}

/**
 * Resolve the navigation direction of a key change (true = forward).
 * 'forward' / 'back' are explicit. 'auto' compares, in order:
 *   1. numeric indices (both ≥ 0 and different),
 *   2. positions in `order` (both present and different),
 *   3. the visit history (`history.visit(next)`, when given),
 * and defaults to forward. The history, when given, is always updated so it stays in sync.
 */
export function sparkResolveForward(direction: SparkNavDirection, prevKey: string, nextKey: string, order: string[],
  prevIndex: number, nextIndex: number, history?: SparkTransitionHistory): boolean {
  const byHistory = history !== undefined ? history.visit(nextKey) : true;
  if (direction === 'forward') {
    return true;
  }
  if (direction === 'back') {
    return false;
  }
  if (prevIndex >= 0 && nextIndex >= 0 && prevIndex !== nextIndex) {
    return nextIndex > prevIndex;
  }
  const a = order.indexOf(prevKey);
  const b = order.indexOf(nextKey);
  if (a >= 0 && b >= 0 && a !== b) {
    return b > a;
  }
  return byHistory;
}
