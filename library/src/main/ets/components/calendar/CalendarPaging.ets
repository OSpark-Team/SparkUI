import { SparkDate, SparkDates } from './SparkDate';

/**
 * Month paging of SCalendar while its slide animation runs (pure, unit-tested).
 *
 * A page request during a slide is never lost and never applied twice: requests accumulate into one pending
 * target month (counted from the pending target, not from the month still on screen). The slide applies the
 * latest target once, at its hidden midpoint; when more requests arrive during the slide-in, another slide
 * follows. A request that comes back to the shown month applies nothing (no month change is reported).
 */
export class SparkMonthPager {
  /** a slide is running (requests only update the pending target) */
  animating: boolean = false;
  private pending: SparkDate | undefined = undefined;
  private pendingFocus: SparkDate | undefined = undefined;

  /** Month that the next request counts from: the pending target, else the shown month. */
  base(view: SparkDate): SparkDate {
    return this.pending ?? view;
  }

  /** Whether a target is waiting to be applied. */
  get hasPending(): boolean {
    return this.pending !== undefined;
  }

  /**
   * Record a request of `delta` months (with an optional day to focus). Returns true when a new slide must
   * start (none is running); false when the running slide will pick the request up.
   */
  request(view: SparkDate, delta: number, focus?: SparkDate): boolean {
    this.pending = SparkDates.startOfMonth(SparkDates.addMonths(this.base(view), delta));
    this.pendingFocus = focus;
    if (this.animating) {
      return false;
    }
    this.animating = true;
    return true;
  }

  /** Direction (1 forward, -1 back, 0 none) of the pending target relative to the shown month. */
  direction(view: SparkDate): number {
    const p = this.pending;
    if (p === undefined) {
      return 0;
    }
    const c = SparkDates.compare(SparkDates.startOfMonth(p), SparkDates.startOfMonth(view));
    return c > 0 ? 1 : (c < 0 ? -1 : 0);
  }

  /** The focus day that came with the pending target (read it before `take`, which clears it). */
  get focus(): SparkDate | undefined {
    return this.pendingFocus;
  }

  /**
   * At the hidden midpoint of a slide: the month to apply (undefined when the pending target is the shown month)
   * — clears the pending target and its focus day.
   */
  take(view: SparkDate): SparkDate | undefined {
    const p = this.pending;
    this.pending = undefined;
    this.pendingFocus = undefined;
    if (p === undefined || SparkDates.isSameMonth(p, view)) {
      return undefined;
    }
    return p;
  }

  /** The slide finished: true when requests arrived meanwhile and another slide must run. */
  finish(view: SparkDate): boolean {
    if (this.pending !== undefined && !SparkDates.isSameMonth(this.pending, view)) {
      return true;
    }
    this.pending = undefined;
    this.pendingFocus = undefined;
    this.animating = false;
    return false;
  }

  /** Forget everything (unmount, motion turned off). */
  reset(): void {
    this.pending = undefined;
    this.pendingFocus = undefined;
    this.animating = false;
  }
}

/** Whether paging `delta` months from `base` keeps the shown months inside [min, max]. */
export function sparkCalendarCanPage(base: SparkDate, delta: number, monthCount: number, min?: SparkDate,
  max?: SparkDate): boolean {
  if (delta < 0) {
    return min === undefined || SparkDates.compare(SparkDates.addDays(SparkDates.startOfMonth(base), -1), min) >= 0;
  }
  return max === undefined ||
    SparkDates.compare(SparkDates.addMonths(SparkDates.startOfMonth(base), Math.max(1, monthCount)), max) <= 0;
}
