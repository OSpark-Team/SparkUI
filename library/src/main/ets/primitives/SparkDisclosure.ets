import { PlacementRect } from './overlay/Placement';

/**
 * Open/closed state shared by a compound component's parts (Dialog, Sheet, Popover, Collapsible …),
 * distributed through {@link SparkContext}. Supports controlled (`open` + `$open` / `!!`) and uncontrolled
 * (`defaultOpen`) use: in controlled mode `setOpen` only emits, and the parent's value flows back.
 */
@ObservedV2
export class SparkDisclosure {
  @Trace open: boolean = false;
  controlled: boolean = false;
  /** notifies the owner component (→ `$open` / `onOpenChange`) */
  emit: (open: boolean) => void = () => {
  };
  /** `.id()` of the trigger, to restore focus on close */
  triggerKey: string = '';
  /** uniqueId of the trigger component, to measure the anchor rect */
  triggerUniqueId: number = -1;
  /** presentation detail published by the content part (e.g. Sheet side), for sibling parts to adapt */
  @Trace placement: string = '';

  private listeners: ((open: boolean) => void)[] = [];

  /** Request a change (from triggers, close buttons, dismissal). Controlled owners decide via `emit`. */
  setOpen(open: boolean): void {
    if (open === this.open) {
      return;
    }
    if (!this.controlled) {
      this.assign(open);
    }
    this.emit(open);
  }

  /** Set the actual state (owner / controlled value) and notify subscribers. */
  assign(open: boolean): void {
    if (open === this.open) {
      return;
    }
    this.open = open;
    this.listeners.forEach((l: (open: boolean) => void) => l(open));
  }

  /** Subscribe to state changes; returns an unsubscribe function. */
  subscribe(listener: (open: boolean) => void): () => void {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter((l: (open: boolean) => void) => l !== listener);
    };
  }

  toggle(): void {
    this.setOpen(!this.open);
  }

  /** Trigger rectangle in window vp, or undefined if it is not laid out. */
  anchorRect(uiContext: UIContext): PlacementRect | undefined {
    if (this.triggerUniqueId < 0) {
      return undefined;
    }
    try {
      const node = uiContext.getFrameNodeByUniqueId(this.triggerUniqueId);
      if (node === null) {
        return undefined;
      }
      const pos = node.getPositionToWindowWithTransform();
      const size = node.getMeasuredSize();
      return new PlacementRect(pos.x, pos.y, uiContext.px2vp(size.width), uiContext.px2vp(size.height));
    } catch (e) {
      return undefined;
    }
  }
}

/** Stable trigger id used for focus restoration. */
export function sparkTriggerKey(uniqueId: number): string {
  return `spark-trigger-${uniqueId}`;
}
