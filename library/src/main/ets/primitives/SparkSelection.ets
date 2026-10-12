import { SparkAnim } from '../core/SparkAnim';

/** Laid-out rectangle of one item, relative to the items' container (vp). */
export class SparkItemRect {
  x: number;
  y: number;
  w: number;
  h: number;

  constructor(x: number, y: number, w: number, h: number) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }
}

/**
 * Selected-values state shared by the parts of a compound component (Tabs, Accordion, ToggleGroup),
 * distributed through {@link SparkContext}. Supports controlled (`value` + `$value` / `!!`) and uncontrolled
 * (`defaultValue`) use: in controlled mode a request only emits, and the parent's value flows back via `assign`.
 *
 * It also keeps the registration order of the item parts, so items can style themselves as first / last
 * (joined toggle groups, the last accordion item without a bottom border).
 */
@ObservedV2
export class SparkSelection {
  @Trace values: string[] = [];
  /** item component ids in registration (render) order */
  @Trace items: number[] = [];
  /** several values may be selected at once */
  multiple: boolean = false;
  /** single mode: tapping the selected value again clears the selection */
  collapsible: boolean = true;
  controlled: boolean = false;
  /** notifies the owner component (→ `$value` / `onValueChange`) */
  emit: (values: string[]) => void = () => {
  };
  /**
   * True once the user changed the selection. A sliding selection indicator only animates from then on,
   * so the initial layout (and geometry settling during first layout) never animates in from x = 0.
   */
  @Trace interacted: boolean = false;
  /** bumps when an item's laid-out rectangle changes */
  @Trace geoVersion: number = 0;
  private rects: Map<string, SparkItemRect> = new Map<string, SparkItemRect>();

  /** Items report their rectangle (from `.onAreaChange`, relative to the items' container). */
  report(value: string, x: number, y: number, w: number, h: number): void {
    const r = this.rects.get(value);
    if (r === undefined || r.x !== x || r.y !== y || r.w !== w || r.h !== h) {
      this.rects.set(value, new SparkItemRect(x, y, w, h));
      this.geoVersion++;
    }
  }

  /** Rectangle of an item (reactive through `geoVersion`). */
  rectOf(value: string): SparkItemRect | undefined {
    return this.geoVersion >= 0 ? this.rects.get(value) : undefined;
  }

  has(value: string): boolean {
    return this.values.indexOf(value) >= 0;
  }

  /** The single selected value ('' when none). */
  get first(): string {
    return this.values.length > 0 ? this.values[0] : '';
  }

  /** Toggle one value following the `multiple` / `collapsible` rules. */
  toggle(value: string): void {
    const on = this.has(value);
    if (this.multiple) {
      this.request(on ? this.values.filter((v: string) => v !== value) : this.values.concat([value]));
      return;
    }
    if (on) {
      if (this.collapsible) {
        this.request([]);
      }
      return;
    }
    this.request([value]);
  }

  /** Select exactly one value (Tabs). */
  select(value: string): void {
    if (this.values.length === 1 && this.values[0] === value) {
      return;
    }
    this.request([value]);
  }

  /** Request a change. Controlled owners decide via `emit`. */
  request(next: string[]): void {
    if (!this.interacted) {
      // flushed first, so the indicator's animation is already enabled when the selection moves
      SparkAnim.commit(() => {
        this.interacted = true;
      });
    }
    if (!this.controlled) {
      this.assign(next);
    }
    this.emit(next.slice());
  }

  /** Set the actual state (owner / controlled value). */
  assign(next: string[]): void {
    if (SparkSelection.same(next, this.values)) {
      return;
    }
    this.values = next.slice();
  }

  register(itemId: number): void {
    if (this.items.indexOf(itemId) < 0) {
      this.items = this.items.concat([itemId]);
    }
  }

  unregister(itemId: number): void {
    if (this.items.indexOf(itemId) >= 0) {
      this.items = this.items.filter((i: number) => i !== itemId);
    }
  }

  isFirst(itemId: number): boolean {
    return this.items.length > 0 && this.items[0] === itemId;
  }

  isLast(itemId: number): boolean {
    return this.items.length > 0 && this.items[this.items.length - 1] === itemId;
  }

  static same(a: string[], b: string[]): boolean {
    if (a.length !== b.length) {
      return false;
    }
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) {
        return false;
      }
    }
    return true;
  }
}
