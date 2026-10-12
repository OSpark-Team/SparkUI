/**
 * Uncontrolled checkbox / radio values of one menu. Menu overlays rebuild their content on every open, so
 * per-item `@Local` state would reset to `defaultChecked` / `defaultValue` each time; the values live here
 * instead, in the long-lived menu state outside the overlay (SparkMenuHandle). Pure, unit-tested.
 */
export class SparkMenuMemory {
  private checks: Map<string, boolean> = new Map<string, boolean>();
  private radios: Map<string, string> = new Map<string, string>();

  /** Remembered checkbox value, or `fallback` (the item's defaultChecked) when never toggled. */
  checked(key: string, fallback: boolean): boolean {
    const v = this.checks.get(key);
    return v === undefined ? fallback : v;
  }

  setChecked(key: string, v: boolean): void {
    this.checks.set(key, v);
  }

  /** Remembered radio group value, or `fallback` (the group's defaultValue) when never changed. */
  radio(key: string, fallback: string): string {
    const v = this.radios.get(key);
    return v === undefined ? fallback : v;
  }

  setRadio(key: string, v: string): void {
    this.radios.set(key, v);
  }
}

/** Memory key of a checkbox item: its `value` when set, else its label (resource labels by resource id). */
export function sparkMenuCheckKey(value: string, text: ResourceStr): string {
  if (value.length > 0) {
    return `v:${value}`;
  }
  if (typeof text === 'string') {
    return `t:${text}`;
  }
  return `r:${(text as Resource).id}`;
}

/** Memory key of a radio group: its `name` when set, else its defaultValue. */
export function sparkMenuRadioKey(name: string, defaultValue: string): string {
  return name.length > 0 ? `n:${name}` : `d:${defaultValue}`;
}

/**
 * Max height (vp) of a menu panel's scrolling item list: the space the anchored placement leaves on the chosen
 * side (`available`, undefined before the first placement) minus the panel chrome (padding, border, handle).
 * Never below 48 (about one row and a half) so a cramped menu still shows something to scroll.
 */
export function sparkMenuListMaxHeight(available: number | undefined, chrome: number): number {
  if (available === undefined || isNaN(available)) {
    return Infinity;
  }
  return Math.max(48, available - chrome);
}
