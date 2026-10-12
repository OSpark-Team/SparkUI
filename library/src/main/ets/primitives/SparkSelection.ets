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
