export type SparkSizeClassName = 'compact' | 'medium' | 'expanded' | 'large';
export type SparkPosture = 'flat' | 'book' | 'tabletop';
export type SparkModality = 'touch' | 'pointer';
export type SparkWindowMode = 'fullscreen' | 'maximized' | 'split' | 'floating' | 'unknown';
/** Per-component override of interaction translation. */
export type SparkAdaptive = 'auto' | 'pointer' | 'touch';

const ORDER: SparkSizeClassName[] = ['compact', 'medium', 'expanded', 'large'];

export function sizeClassIndex(c: SparkSizeClassName): number {
  return ORDER.indexOf(c);
}

/** Thresholds (vp). `width = [medium, expanded, large]` lower bounds; same for height. */
export class SparkLayoutThresholds {
  width: number[] = [600, 840, 1440];
  height: number[] = [480, 900, 1200];

  classify(value: number, bounds: number[]): SparkSizeClassName {
    if (value >= bounds[2]) {
      return 'large';
    }
    if (value >= bounds[1]) {
      return 'expanded';
    }
    if (value >= bounds[0]) {
      return 'medium';
    }
    return 'compact';
  }

  widthClass(widthVp: number): SparkSizeClassName {
    return this.classify(widthVp, this.width);
  }

  heightClass(heightVp: number): SparkSizeClassName {
    return this.classify(heightVp, this.height);
  }
}

/** A rectangle in vp, window coordinates. */
export class SparkRect {
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;

  constructor(x: number, y: number, width: number, height: number) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

/** Safe-area insets in vp. */
export class SparkInsets {
  top: number = 0;
  bottom: number = 0;
  left: number = 0;
  right: number = 0;

  constructor(top: number, bottom: number, left: number, right: number) {
    this.top = top;
    this.bottom = bottom;
    this.left = left;
    this.right = right;
  }

  equals(o: SparkInsets): boolean {
    return this.top === o.top && this.bottom === o.bottom && this.left === o.left && this.right === o.right;
  }
}

/**
 * Window-level signals shared by every layout context in the window (containers reuse the same instance).
 * Fields only change when their discrete value changes, so readers re-render rarely.
 */
@ObservedV2
export class SparkEnvironment {
  @Trace posture: SparkPosture = 'flat';
  /** fold crease in window vp, when the device is half-folded */
  @Trace crease: SparkRect | undefined = undefined;
  @Trace modality: SparkModality = 'touch';
  @Trace windowMode: SparkWindowMode = 'fullscreen';
  /** status bar + cutout + navigation indicator */
  @Trace safeArea: SparkInsets = new SparkInsets(0, 0, 0, 0);
  /** docked soft keyboard height (vp), 0 when hidden */
  @Trace keyboardHeight: number = 0;
  /**
   * Physical pixels per vp of the window. It can change at runtime — e.g. a tablet window entering free-window mode
   * is scaled — so anything converted to px once (icon paths) must re-read it.
   */
  @Trace pxPerVp: number = 1;
  @Trace landscape: boolean = false;
  /** `deviceInfo.deviceType`: phone / tablet / 2in1 / … */
  @Trace deviceType: string = 'phone';
  /** Window size class, regardless of container. */
  @Trace windowWidthClass: SparkSizeClassName = 'compact';
  @Trace windowHeightClass: SparkSizeClassName = 'medium';
  /** Simulation flag set by the layout inspector. */
  @Trace simulated: boolean = false;
}

/**
 * Layout context consumed by SparkUI components through `@Consumer('sparkLayout')`.
 * The root context tracks the window; `SparkContainer` creates child contexts that track their own size
 * (container queries) and share the window {@link SparkEnvironment}.
 */
@ObservedV2
export class SparkLayoutContext {
  @Trace widthClass: SparkSizeClassName = 'compact';
  @Trace heightClass: SparkSizeClassName = 'medium';
  @Trace env: SparkEnvironment;
  /** true for SparkContainer contexts */
  readonly isContainer: boolean;
  /** latest measured size (vp). Not traced: read it imperatively; react to the classes instead. */
  width: number = 0;
  height: number = 0;

  constructor(env: SparkEnvironment, isContainer: boolean) {
    this.env = env;
    this.isContainer = isContainer;
  }

  atLeast(c: SparkSizeClassName): boolean {
    return sizeClassIndex(this.widthClass) >= sizeClassIndex(c);
  }

  heightAtLeast(c: SparkSizeClassName): boolean {
    return sizeClassIndex(this.heightClass) >= sizeClassIndex(c);
  }

  get compact(): boolean {
    return this.widthClass === 'compact';
  }

  get pointer(): boolean {
    return this.env.modality === 'pointer';
  }

  /** Resolve an `adaptive` prop: 'auto' follows the input modality. */
  interaction(adaptive: SparkAdaptive): SparkModality {
    if (adaptive === 'auto') {
      return this.env.modality;
    }
    return adaptive;
  }

  /** Update from a measured size; only crossing a threshold changes traced state. */
  updateSize(widthVp: number, heightVp: number, thresholds: SparkLayoutThresholds): void {
    this.width = widthVp;
    this.height = heightVp;
    const w = thresholds.widthClass(widthVp);
    const h = thresholds.heightClass(heightVp);
    if (w !== this.widthClass) {
      this.widthClass = w;
    }
    if (h !== this.heightClass) {
      this.heightClass = h;
    }
  }
}
