/**
 * Pure time-of-day helpers for STimePicker. Times are minutes since midnight (0..1439); -1 means "none".
 * Values travel as 24-hour `HH:mm` strings.
 */

/** Minutes in a day. */
export const SPARK_DAY_MINUTES: number = 24 * 60;

/** Parses `H:mm` / `HH:mm` (24-hour) to minutes since midnight; -1 when empty or invalid. */
export function sparkParseTime(value: string | undefined): number {
  if (value === undefined) {
    return -1;
  }
  const m = /^\s*(\d{1,2}):(\d{2})\s*$/.exec(value);
  if (m === null) {
    return -1;
  }
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h > 23 || min > 59) {
    return -1;
  }
  return h * 60 + min;
}

/** Minutes since midnight → `HH:mm` (wraps into one day). */
export function sparkFormatTime(minutes: number): string {
  const t = ((Math.round(minutes) % SPARK_DAY_MINUTES) + SPARK_DAY_MINUTES) % SPARK_DAY_MINUTES;
  const h = Math.floor(t / 60);
  const m = t % 60;
  return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m}`;
}

/** Display text: `HH:mm`, or `h:mm AM` / `h:mm PM` with `hour12` (`am` / `pm` are the localized markers). */
export function sparkTimeLabel(minutes: number, hour12: boolean, am: string, pm: string): string {
  if (!hour12) {
    return sparkFormatTime(minutes);
  }
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${sparkHour12(h)}:${m < 10 ? '0' : ''}${m} ${h < 12 ? am : pm}`;
}

/** 0..23 → 12, 1..11 (12-hour clock face). */
export function sparkHour12(hour: number): number {
  const h = hour % 12;
  return h === 0 ? 12 : h;
}

/** Sanitized minute step: an integer in 1..60 (other values fall back to 1). */
export function sparkMinuteStep(step: number): number {
  const s = Math.floor(step);
  return Number.isFinite(s) && s >= 1 && s <= 60 ? s : 1;
}

/** Minute options of one hour for a step: step 15 → [0, 15, 30, 45]. */
export function sparkMinuteOptions(step: number): number[] {
  const s = sparkMinuteStep(step);
  const out: number[] = [];
  for (let m = 0; m < 60; m += s) {
    out.push(m);
  }
  return out;
}

/** True when `minutes` lies within [min, max] (either bound -1 = open). */
export function sparkTimeInRange(minutes: number, min: number, max: number): boolean {
  return (min < 0 || minutes >= min) && (max < 0 || minutes <= max);
}

/** True when at least one step of `hour` lies within [min, max]. */
export function sparkHourEnabled(hour: number, step: number, min: number, max: number): boolean {
  const opts = sparkMinuteOptions(step);
  for (let i = 0; i < opts.length; i++) {
    if (sparkTimeInRange(hour * 60 + opts[i], min, max)) {
      return true;
    }
  }
  return false;
}

/**
 * The selectable time nearest to `minutes`: snapped to the minute step (within its hour) and kept within
 * [min, max]. Returns -1 when nothing is selectable (an empty range).
 */
export function sparkNearestTime(minutes: number, step: number, min: number, max: number): number {
  const opts = sparkMinuteOptions(step);
  const target = Math.max(0, Math.min(SPARK_DAY_MINUTES - 1, Math.round(minutes)));
  let best = -1;
  let bestDistance = Number.MAX_VALUE;
  for (let h = 0; h < 24; h++) {
    for (let i = 0; i < opts.length; i++) {
      const t = h * 60 + opts[i];
      if (!sparkTimeInRange(t, min, max)) {
        continue;
      }
      const d = Math.abs(t - target);
      if (d < bestDistance) {
        bestDistance = d;
        best = t;
      }
    }
  }
  return best;
}

/** The selectable time nearest to `minutes` whose hour is `hour` (-1 when that hour has none). */
export function sparkNearestInHour(hour: number, minute: number, step: number, min: number, max: number): number {
  const opts = sparkMinuteOptions(step);
  let best = -1;
  let bestDistance = Number.MAX_VALUE;
  for (let i = 0; i < opts.length; i++) {
    const t = hour * 60 + opts[i];
    if (!sparkTimeInRange(t, min, max)) {
      continue;
    }
    const d = Math.abs(opts[i] - minute);
    if (d < bestDistance) {
      bestDistance = d;
      best = t;
    }
  }
  return best;
}

/** Index of the enabled entry nearest to `index` (ties prefer the lower one); -1 when none is enabled. */
export function sparkNearestEnabled(disabled: boolean[], index: number): number {
  const n = disabled.length;
  if (n === 0) {
    return -1;
  }
  const start = Math.max(0, Math.min(n - 1, index));
  for (let d = 0; d < n; d++) {
    if (start - d >= 0 && !disabled[start - d]) {
      return start - d;
    }
    if (start + d < n && !disabled[start + d]) {
      return start + d;
    }
  }
  return -1;
}

/** Next enabled index from `index` in `dir` (+1 / -1), or `index` when there is none. */
export function sparkStepEnabled(disabled: boolean[], index: number, dir: number): number {
  for (let i = index + dir; i >= 0 && i < disabled.length; i += dir) {
    if (!disabled[i]) {
      return i;
    }
  }
  return index;
}
