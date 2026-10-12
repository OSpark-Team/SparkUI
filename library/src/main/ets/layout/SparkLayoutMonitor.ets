import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { inputDevice } from '@kit.InputKit';
import {
  SparkEnvironment,
  SparkInsets,
  SparkLayoutContext,
  SparkLayoutThresholds,
  SparkPosture,
  SparkRect,
  SparkSizeClassName,
  SparkWindowMode
} from './SparkLayoutContext';

/** Listener for root size-class changes (e.g. the theme controller's `@size()` blocks). */
export type SparkSizeClassListener = (widthClass: SparkSizeClassName) => void;

/**
 * Collects window / display / input signals and folds them into discrete layout state
 * (singleton: `SparkUI.layout`). All system calls are best-effort and guarded, so SparkUI keeps working
 * in the previewer and in unit tests with sensible defaults.
 */
export class SparkLayoutMonitor {
  readonly env: SparkEnvironment = new SparkEnvironment();
  /** Root (window) layout context. */
  readonly root: SparkLayoutContext = new SparkLayoutContext(this.env, false);
  readonly thresholds: SparkLayoutThresholds = new SparkLayoutThresholds();

  private uiContext: UIContext | undefined = undefined;
  private win: window.Window | undefined = undefined;
  private attachCount: number = 0;
  private listeners: SparkSizeClassListener[] = [];
  private pointerDevices: Set<number> = new Set<number>();
  private configPointer: boolean = false;
  private appContext: common.ApplicationContext | undefined = undefined;
  private envCallbackId: number = -1;
  private sizeCb: (size: window.Size) => void = () => {
  };
  private avoidCb: (o: window.AvoidAreaOptions) => void = () => {
  };
  private statusCb: (s: window.WindowStatusType) => void = () => {
  };
  private foldCb: (s: display.FoldStatus) => void = () => {
  };
  private inputCb: (e: inputDevice.DeviceListener) => void = () => {
  };

  onSizeClassChange(l: SparkSizeClassListener): void {
    this.listeners.push(l);
  }

  /** Change thresholds at runtime (vp). Re-classifies immediately. */
  setThresholds(width: number[], height: number[]): void {
    if (width.length === 3) {
      this.thresholds.width = width;
    }
    if (height.length === 3) {
      this.thresholds.height = height;
    }
    this.updateRootSize(this.root.width, this.root.height);
  }

  /** Edge-to-edge window layout (content under the system bars); insets stay available in env.safeArea. */
  setImmersive(immersive: boolean): void {
    if (this.win === undefined) {
      return;
    }
    try {
      this.win.setWindowLayoutFullScreen(immersive).then(() => this.readAvoidAreas()).catch(() => {
      });
    } catch (e) {
    }
  }

  attach(uiContext: UIContext): void {
    this.attachCount++;
    if (this.uiContext !== undefined) {
      return;
    }
    this.uiContext = uiContext;
    try {
      this.env.deviceType = deviceInfo.deviceType;
    } catch (e) {
    }
    this.attachWindow(uiContext);
    this.attachFold();
    this.attachInput();
    this.attachConfig(uiContext);
  }

  detach(): void {
    this.attachCount = Math.max(0, this.attachCount - 1);
    if (this.attachCount > 0 || this.uiContext === undefined) {
      return;
    }
    try {
      this.win?.off('windowSizeChange', this.sizeCb);
      this.win?.off('avoidAreaChange', this.avoidCb);
      this.win?.off('windowStatusDidChange', this.statusCb);
    } catch (e) {
    }
    try {
      display.off('foldStatusChange', this.foldCb);
    } catch (e) {
    }
    try {
      inputDevice.off('change', this.inputCb);
    } catch (e) {
    }
    try {
      this.appContext?.off('environment', this.envCallbackId);
    } catch (e) {
    }
    this.win = undefined;
    this.uiContext = undefined;
    this.appContext = undefined;
  }

  /**
   * Fallback measurement from SparkProvider's root size (vp). Used when window APIs are unavailable
   * (previewer) — and harmless otherwise, since it reports the same size.
   */
  reportRootSize(widthVp: number, heightVp: number): void {
    if (this.win === undefined && !this.env.simulated) {
      this.updateRootSize(widthVp, heightVp);
    }
  }

  /** Called by components on hover/mouse events so modality reacts to the actually used device. */
  reportPointerEvent(isPointer: boolean): void {
    if (this.env.simulated) {
      return;
    }
    const m = isPointer ? 'pointer' : (this.hasPointerDevice() ? 'pointer' : 'touch');
    if (this.env.modality !== m) {
      this.env.modality = m;
    }
  }

  /**
   * Layout inspector simulation: override window-level signals. Pass `undefined` to stop simulating.
   */
  simulate(widthVp: number | undefined, heightVp: number, posture: SparkPosture, modality: 'touch' | 'pointer',
    windowMode: SparkWindowMode): void {
    if (widthVp === undefined) {
      this.env.simulated = false;
      this.refreshAll();
      return;
    }
    this.env.simulated = true;
    this.env.posture = posture;
    this.env.modality = modality;
    this.env.windowMode = windowMode;
    this.env.crease = posture === 'flat' ? undefined :
      (posture === 'book' ? new SparkRect(widthVp / 2 - 8, 0, 16, heightVp) :
        new SparkRect(0, heightVp / 2 - 8, widthVp, 16));
    this.updateRootSize(widthVp, heightVp);
  }

  // ---------------------------------------------------------------------------------------------

  private updateRootSize(widthVp: number, heightVp: number): void {
    const before = this.root.widthClass;
    this.root.updateSize(widthVp, heightVp, this.thresholds);
    if (this.env.windowWidthClass !== this.root.widthClass) {
      this.env.windowWidthClass = this.root.widthClass;
    }
    if (this.env.windowHeightClass !== this.root.heightClass) {
      this.env.windowHeightClass = this.root.heightClass;
    }
    const landscape = widthVp > heightVp;
    if (this.env.landscape !== landscape) {
      this.env.landscape = landscape;
    }
    if (before !== this.root.widthClass) {
      this.listeners.forEach((l: SparkSizeClassListener) => l(this.root.widthClass));
    }
  }

  private px2vp(px: number): number {
    return this.uiContext !== undefined ? this.uiContext.px2vp(px) : px;
  }

  private refreshAll(): void {
    if (this.win !== undefined) {
      try {
        const rect = this.win.getWindowProperties().windowRect;
        this.updateRootSize(this.px2vp(rect.width), this.px2vp(rect.height));
        this.readAvoidAreas();
        this.readWindowStatus();
      } catch (e) {
      }
    }
    this.readFold();
    this.updateModality();
  }

  private attachWindow(uiContext: UIContext): void {
    try {
      const name = uiContext.getWindowName();
      this.win = name !== undefined ? window.findWindow(name) : undefined;
    } catch (e) {
      this.win = undefined;
    }
    if (this.win === undefined) {
      return;
    }
    try {
      const rect = this.win.getWindowProperties().windowRect;
      this.updateRootSize(this.px2vp(rect.width), this.px2vp(rect.height));
      this.sizeCb = (size: window.Size) => {
        if (!this.env.simulated) {
          this.updateRootSize(this.px2vp(size.width), this.px2vp(size.height));
          this.readFold();
        }
      };
      this.win.on('windowSizeChange', this.sizeCb);
    } catch (e) {
    }
    try {
      this.readAvoidAreas();
      this.avoidCb = () => this.readAvoidAreas();
      this.win.on('avoidAreaChange', this.avoidCb);
    } catch (e) {
    }
    try {
      this.readWindowStatus();
      this.statusCb = () => this.readWindowStatus();
      this.win.on('windowStatusDidChange', this.statusCb);
    } catch (e) {
    }
  }

  private readAvoidAreas(): void {
    if (this.win === undefined) {
      return;
    }
    let sys: window.AvoidArea;
    let cutout: window.AvoidArea;
    let nav: window.AvoidArea;
    let kb: window.AvoidArea;
    try {
      sys = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      cutout = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      nav = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      kb = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
    } catch (e) {
      return;
    }
    const top = Math.max(sys.topRect.height, cutout.topRect.height);
    const bottom = Math.max(sys.bottomRect.height, nav.bottomRect.height);
    const left = Math.max(sys.leftRect.width, cutout.leftRect.width);
    const right = Math.max(sys.rightRect.width, cutout.rightRect.width);
    const insets = new SparkInsets(this.px2vp(top), this.px2vp(bottom), this.px2vp(left), this.px2vp(right));
    if (!insets.equals(this.env.safeArea)) {
      this.env.safeArea = insets;
    }
    const kbh = this.px2vp(kb.bottomRect.height);
    if (kbh !== this.env.keyboardHeight) {
      this.env.keyboardHeight = kbh;
    }
  }

  private readWindowStatus(): void {
    if (this.win === undefined || this.env.simulated) {
      return;
    }
    let mode: SparkWindowMode = 'unknown';
    let status: window.WindowStatusType;
    try {
      status = this.win.getWindowStatus();
    } catch (e) {
      return;
    }
    switch (status) {
      case window.WindowStatusType.FULL_SCREEN:
        mode = 'fullscreen';
        break;
      case window.WindowStatusType.MAXIMIZE:
        mode = 'maximized';
        break;
      case window.WindowStatusType.SPLIT_SCREEN:
        mode = 'split';
        break;
      case window.WindowStatusType.FLOATING:
        mode = 'floating';
        break;
      default:
        mode = 'unknown';
    }
    if (mode !== this.env.windowMode) {
      this.env.windowMode = mode;
    }
  }

  private attachFold(): void {
    try {
      if (!display.isFoldable()) {
        return;
      }
      this.readFold();
      this.foldCb = () => this.readFold();
      display.on('foldStatusChange', this.foldCb);
    } catch (e) {
    }
  }

  private readFold(): void {
    if (this.env.simulated) {
      return;
    }
    let posture: SparkPosture = 'flat';
    let crease: SparkRect | undefined = undefined;
    try {
      if (display.isFoldable() && display.getFoldStatus() === display.FoldStatus.FOLD_STATUS_HALF_FOLDED) {
        const region = display.getCurrentFoldCreaseRegion();
        if (region !== undefined && region.creaseRects.length > 0) {
          const r = region.creaseRects[0];
          // crease wider than tall → horizontal hinge → laptop-like "tabletop"; otherwise "book".
          posture = r.width > r.height ? 'tabletop' : 'book';
          let ox = 0;
          let oy = 0;
          if (this.win !== undefined) {
            const wr = this.win.getWindowProperties().windowRect;
            ox = wr.left;
            oy = wr.top;
          }
          crease = new SparkRect(this.px2vp(r.left - ox), this.px2vp(r.top - oy), this.px2vp(r.width),
            this.px2vp(r.height));
        }
      }
    } catch (e) {
      posture = 'flat';
    }
    if (posture !== this.env.posture) {
      this.env.posture = posture;
    }
    const prev = this.env.crease;
    const same = (prev === undefined && crease === undefined) ||
      (prev !== undefined && crease !== undefined && prev.x === crease.x && prev.y === crease.y &&
        prev.width === crease.width && prev.height === crease.height);
    if (!same) {
      this.env.crease = crease;
    }
  }

  private attachInput(): void {
    try {
      inputDevice.getDeviceList().then((ids: number[]) => {
        ids.forEach((id: number) => this.inspectDevice(id));
        this.updateModality();
      }).catch(() => {
      });
      this.inputCb = (e: inputDevice.DeviceListener) => {
        if (e.type === 'add') {
          this.inspectDevice(e.deviceId);
        } else {
          this.pointerDevices.delete(e.deviceId);
        }
        this.updateModality();
      };
      inputDevice.on('change', this.inputCb);
    } catch (e) {
    }
  }

  private inspectDevice(id: number): void {
    try {
      const info = inputDevice.getDeviceInfoSync(id);
      if (info.sources.includes('mouse') || info.sources.includes('touchpad')) {
        this.pointerDevices.add(id);
      }
    } catch (e) {
    }
  }

  private attachConfig(uiContext: UIContext): void {
    try {
      const host = uiContext.getHostContext() as common.UIAbilityContext;
      this.configPointer = host.config?.hasPointerDevice === true;
      this.appContext = host.getApplicationContext();
      this.envCallbackId = this.appContext.on('environment', {
        onConfigurationUpdated: (config) => {
          if (config.hasPointerDevice !== undefined) {
            this.configPointer = config.hasPointerDevice;
            this.updateModality();
          }
        },
        onMemoryLevel: () => {
        }
      });
      this.updateModality();
    } catch (e) {
    }
  }

  private hasPointerDevice(): boolean {
    return this.pointerDevices.size > 0 || this.configPointer || this.env.deviceType === '2in1';
  }

  private updateModality(): void {
    if (this.env.simulated) {
      return;
    }
    const m = this.hasPointerDevice() ? 'pointer' : 'touch';
    if (m !== this.env.modality) {
      this.env.modality = m;
    }
  }
}
