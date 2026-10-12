import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import {
  sparkCaptionReserve, sparkClampDecorHeight, SparkSystemButtons, SparkWindowStatus
} from './TitleBarLogic';

/** System caption-button rect in vp, relative to the window's top-right corner (`window.TitleButtonRect`). */
export class SparkTitleButtonRect {
  right: number = 0;
  top: number = 0;
  width: number = 0;
  height: number = 0;

  constructor(right: number, top: number, width: number, height: number) {
    this.right = right;
    this.top = top;
    this.width = width;
    this.height = height;
  }

  equals(o: SparkTitleButtonRect): boolean {
    return this.right === o.right && this.top === o.top && this.width === o.width && this.height === o.height;
  }
}

/** What an STitleBar asks of the window while it is mounted. */
export class SparkWindowChromeOptions {
  systemButtons: SparkSystemButtons = 'custom';
  /** bar height (vp) — the system decor height follows it (clamped to [37, 112]) so kept buttons centre in the bar */
  barHeight: number = 40;
  /** dark theme → light system buttons ('keep') */
  dark: boolean = false;
  /** corner radius of the kept system buttons' hover plate (vp, clamped to [4, 8]) */
  buttonRadius: number = 6;
}

/**
 * Window chrome service (singleton `SparkWindowChrome.shared`): mirrors the main window's free-window / status /
 * decor state as `@Trace` fields and performs the window actions a custom title bar needs.
 *
 * Free windows exist on PC/2in1 (always) and on tablets / some phones with 自由多窗 or 电脑模式 enabled. Everywhere
 * else every action is a graceful no-op (all window calls are guarded; they throw 801 outside free windows).
 *
 * Recommended setup (EntryAbility, inside the `loadContent` callback — decor APIs must run after loadContent):
 * ```
 * SparkWindowChrome.init(windowStage, this.context);
 * ```
 * Without `init`, the first STitleBar attaches lazily through its UIContext.
 *
 * APIs (all SDK ≤ 22): setWindowDecorVisible 11, setWindowDecorHeight / getWindowDecorHeight 11,
 * getTitleButtonRect / on('windowTitleButtonRectChange') 11, minimize 11, recover 11, maximize 12, getWindowStatus 12,
 * setWindowTitleButtonVisible 14, setDecorButtonStyle 14 (buttonIconSize / buttonBackgroundCornerRadius 20),
 * startMoving 14, getWindowDecorVisible 18, on('windowStatusDidChange') 20, isInFreeWindowMode /
 * on('freeWindowModeChange') 22.
 */
@ObservedV2
export class SparkWindowChrome {
  /**
   * Singleton, created after the class (see below) rather than in a static initializer: static initializers run
   * before the class decorators are applied, so an instance created there is not observed by V2 and its @Trace
   * fields would not refresh the UI.
   */
  static get shared(): SparkWindowChrome {
    return SPARK_WINDOW_CHROME;
  }

  /** Bind to the main window (call from EntryAbility after `loadContent` succeeded). */
  static init(windowStage: window.WindowStage, context?: common.UIAbilityContext): void {
    let win: window.Window | undefined = undefined;
    try {
      win = windowStage.getMainWindowSync();
    } catch (e) {
      win = undefined;
    }
    if (win !== undefined) {
      SparkWindowChrome.shared.bind(win, context);
    }
  }

  /** A main window is bound. */
  @Trace attached: boolean = false;
  /** The window is a free window (PC/2in1, tablet 自由多窗 / 电脑模式). */
  @Trace freeWindow: boolean = false;
  @Trace status: SparkWindowStatus = 'unknown';
  /** System title bar visible. */
  @Trace decorVisible: boolean = true;
  /** System title bar height (vp), 0 when unknown. */
  @Trace decorHeight: number = 0;
  /** System caption-button rect (vp, relative to the window's top-right). */
  @Trace titleButtonRect: SparkTitleButtonRect = new SparkTitleButtonRect(0, 0, 0, 0);
  /** Applied caption-button mode, 'system' when no STitleBar owns the window. */
  @Trace systemButtons: SparkSystemButtons | 'system' = 'system';
  /** `deviceInfo.deviceType` */
  @Trace deviceType: string = 'phone';

  private win: window.Window | undefined = undefined;
  private ability: common.UIAbilityContext | undefined = undefined;
  private owner: number = -1;
  private opts: SparkWindowChromeOptions = new SparkWindowChromeOptions();
  private savedDecorHeight: number = 0;
  private savedStyle: window.DecorButtonStyle | undefined = undefined;
  private statusCb: (s: window.WindowStatusType) => void = () => {
  };
  private freeCb: (free: boolean) => void = () => {
  };
  private rectCb: (r: window.TitleButtonRect) => void = () => {
  };

  constructor() {
    try {
      this.deviceType = deviceInfo.deviceType;
    } catch (e) {
    }
  }

  get isFloating(): boolean {
    return this.status === 'floating';
  }

  get isMaximized(): boolean {
    return this.status === 'maximized';
  }

  get isFullScreen(): boolean {
    return this.status === 'fullscreen';
  }

  /** An STitleBar currently owns the window chrome (system title bar hidden by SparkUI). */
  get owned(): boolean {
    return this.systemButtons !== 'system';
  }

  /** Trailing width (vp) to keep free for the system buttons ('keep' mode). */
  get captionReserve(): number {
    if (this.systemButtons !== 'keep' || !this.freeWindow) {
      return 0;
    }
    return sparkCaptionReserve(this.titleButtonRect.width, this.titleButtonRect.right);
  }

  /** Lazily bind through a UIContext (the window that hosts it). No-op when already attached. */
  attach(uiContext: UIContext): void {
    if (this.win !== undefined) {
      return;
    }
    let win: window.Window | undefined = undefined;
    let ability: common.UIAbilityContext | undefined = undefined;
    try {
      const name = uiContext.getWindowName();
      win = name !== undefined ? window.findWindow(name) : undefined;
    } catch (e) {
      win = undefined;
    }
    try {
      ability = uiContext.getHostContext() as common.UIAbilityContext;
    } catch (e) {
      ability = undefined;
    }
    if (win !== undefined) {
      this.bind(win, ability);
    }
  }

  /** Bind a window (re-binding the same window just refreshes and re-applies the active claim). */
  bind(win: window.Window, context?: common.UIAbilityContext): void {
    if (context !== undefined) {
      this.ability = context;
    }
    if (this.win !== win) {
      this.unlisten();
      this.win = win;
      this.listen();
    }
    this.attached = true;
    this.refresh();
    if (this.owner >= 0) {
      this.applyClaim();
    }
  }

  /** Unbind (window destroyed). Leaves the window decor as it is. */
  detach(): void {
    this.unlisten();
    this.win = undefined;
    this.attached = false;
    this.owner = -1;
    this.systemButtons = 'system';
  }

  /**
   * Take over the window chrome: hide the system title bar and apply `opts.systemButtons`.
   * The newest claim wins; `release(owner)` from an older owner is ignored.
   */
  claim(owner: number, opts: SparkWindowChromeOptions, uiContext?: UIContext): void {
    if (uiContext !== undefined) {
      this.attach(uiContext);
    }
    const first = this.owner < 0;
    this.owner = owner;
    this.opts = opts;
    if (first) {
      this.saveSystemLook();
    }
    this.applyClaim();
  }

  /** Give the chrome back to the system (title bar + buttons visible, original height and button style). */
  release(owner: number): void {
    if (this.owner !== owner) {
      return;
    }
    this.owner = -1;
    this.systemButtons = 'system';
    const w = this.win;
    if (w === undefined) {
      return;
    }
    try {
      w.setWindowDecorVisible(true);
    } catch (e) {
    }
    try {
      w.setWindowTitleButtonVisible(true, true, true);
    } catch (e) {
    }
    if (this.savedDecorHeight > 0) {
      try {
        w.setWindowDecorHeight(sparkClampDecorHeight(this.savedDecorHeight));
      } catch (e) {
      }
    }
    if (this.savedStyle !== undefined) {
      try {
        w.setDecorButtonStyle(this.savedStyle);
      } catch (e) {
      }
    }
    this.refresh();
  }

  /** Re-style kept system buttons (theme changes). */
  restyle(dark: boolean, buttonRadius: number): void {
    this.opts.dark = dark;
    this.opts.buttonRadius = buttonRadius;
    if (this.owner >= 0 && this.opts.systemButtons === 'keep') {
      this.applyButtonStyle();
    }
  }

  /** Change the bar height while claimed (keeps kept system buttons vertically centred). */
  setBarHeight(h: number): void {
    if (this.opts.barHeight === h) {
      return;
    }
    this.opts.barHeight = h;
    if (this.owner >= 0) {
      this.applyDecorHeight();
      this.readTitleButtonRect();
    }
  }

  // ---- actions ---------------------------------------------------------------------------------------------------

  minimize(): void {
    this.win?.minimize().catch((e: BusinessError) => {
    });
  }

  /**
   * Maximize. Default keeps the title bar and dock (`MaximizePresentation.EXIT_IMMERSIVE` → status MAXIMIZE);
   * `immersive` enters full screen (`ENTER_IMMERSIVE`, system hover title bar on the top edge).
   */
  maximize(immersive?: boolean): void {
    const p = immersive === true ? window.MaximizePresentation.ENTER_IMMERSIVE :
      window.MaximizePresentation.EXIT_IMMERSIVE;
    try {
      this.win?.maximize(p).catch((e: BusinessError) => {
      });
    } catch (e) {
    }
  }

  /** Back to a floating window (`recover`, from maximized / full screen / split). */
  restore(): void {
    try {
      this.win?.recover().catch((e: BusinessError) => {
      });
    } catch (e) {
    }
  }

  toggleMaximize(): void {
    if (this.status === 'maximized' || this.status === 'fullscreen') {
      this.restore();
    } else {
      this.maximize();
    }
  }

  /** Close the window by finishing its UIAbility (what the system close button does for a main window). */
  close(): void {
    try {
      this.ability?.terminateSelf().catch((e: BusinessError) => {
      });
    } catch (e) {
    }
  }

  /**
   * Start dragging the window. Only effective when called synchronously from an `onTouch` callback whose event
   * type is Down (or Move after a Down) — STitleBar does this on its drag region.
   */
  startMoving(): void {
    if (!this.freeWindow) {
      return;
    }
    try {
      this.win?.startMoving().catch((e: BusinessError) => {
      });
    } catch (e) {
    }
  }

  // ---- internals -------------------------------------------------------------------------------------------------

  private listen(): void {
    const w = this.win;
    if (w === undefined) {
      return;
    }
    this.statusCb = (s: window.WindowStatusType) => {
      this.status = SparkWindowChrome.mapStatus(s);
      this.readFreeWindow();
      this.readTitleButtonRect();
    };
    this.freeCb = (free: boolean) => {
      this.freeWindow = free;
      // setWindowTitleButtonVisible / setDecorButtonStyle throw 801 outside free windows: re-apply on entry.
      if (free && this.owner >= 0) {
        this.applyClaim();
      } else {
        this.refresh();
      }
    };
    this.rectCb = (r: window.TitleButtonRect) => {
      this.setRect(new SparkTitleButtonRect(r.right, r.top, r.width, r.height));
    };
    try {
      w.on('windowStatusDidChange', this.statusCb);
    } catch (e) {
    }
    try {
      w.on('freeWindowModeChange', this.freeCb);
    } catch (e) {
    }
    try {
      w.on('windowTitleButtonRectChange', this.rectCb);
    } catch (e) {
    }
  }

  private unlisten(): void {
    const w = this.win;
    if (w === undefined) {
      return;
    }
    try {
      w.off('windowStatusDidChange', this.statusCb);
    } catch (e) {
    }
    try {
      w.off('freeWindowModeChange', this.freeCb);
    } catch (e) {
    }
    try {
      w.off('windowTitleButtonRectChange', this.rectCb);
    } catch (e) {
    }
  }

  private static mapStatus(s: window.WindowStatusType): SparkWindowStatus {
    switch (s) {
      case window.WindowStatusType.FULL_SCREEN:
        return 'fullscreen';
      case window.WindowStatusType.MAXIMIZE:
        return 'maximized';
      case window.WindowStatusType.MINIMIZE:
        return 'minimized';
      case window.WindowStatusType.FLOATING:
        return 'floating';
      case window.WindowStatusType.SPLIT_SCREEN:
        return 'split';
      default:
        return 'unknown';
    }
  }

  private refresh(): void {
    const w = this.win;
    if (w === undefined) {
      return;
    }
    try {
      const s = SparkWindowChrome.mapStatus(w.getWindowStatus());
      if (s !== this.status) {
        this.status = s;
      }
    } catch (e) {
    }
    this.readFreeWindow();
    this.readDecor();
    this.readTitleButtonRect();
  }

  private readFreeWindow(): void {
    try {
      const free = this.win !== undefined && this.win.isInFreeWindowMode();
      if (free !== this.freeWindow) {
        this.freeWindow = free;
      }
    } catch (e) {
    }
  }

  private readDecor(): void {
    const w = this.win;
    if (w === undefined) {
      return;
    }
    try {
      const v = w.getWindowDecorVisible();
      if (v !== this.decorVisible) {
        this.decorVisible = v;
      }
    } catch (e) {
      // 801 outside free windows: no system title bar there.
      const v = this.freeWindow && this.owner < 0;
      if (v !== this.decorVisible) {
        this.decorVisible = v;
      }
    }
    try {
      const h = w.getWindowDecorHeight();
      if (h !== this.decorHeight) {
        this.decorHeight = h;
      }
    } catch (e) {
    }
  }

  private readTitleButtonRect(): void {
    const w = this.win;
    if (w === undefined) {
      return;
    }
    try {
      const r = w.getTitleButtonRect();
      this.setRect(new SparkTitleButtonRect(r.right, r.top, r.width, r.height));
    } catch (e) {
      this.setRect(new SparkTitleButtonRect(0, 0, 0, 0));
    }
  }

  private setRect(r: SparkTitleButtonRect): void {
    if (!r.equals(this.titleButtonRect)) {
      this.titleButtonRect = r;
    }
  }

  private saveSystemLook(): void {
    const w = this.win;
    if (w === undefined) {
      return;
    }
    try {
      this.savedDecorHeight = w.getWindowDecorHeight();
    } catch (e) {
      this.savedDecorHeight = 0;
    }
    try {
      this.savedStyle = w.getDecorButtonStyle();
    } catch (e) {
      this.savedStyle = undefined;
    }
  }

  private applyClaim(): void {
    const w = this.win;
    this.systemButtons = this.opts.systemButtons;
    if (w === undefined) {
      return;
    }
    if (this.savedDecorHeight <= 0 && this.savedStyle === undefined) {
      this.saveSystemLook();
    }
    try {
      // Takes effect immediately in a free window, otherwise when the window becomes one.
      w.setWindowDecorVisible(false);
    } catch (e) {
    }
    const keep = this.opts.systemButtons === 'keep';
    try {
      // 801 outside free windows — re-applied from 'freeWindowModeChange'.
      w.setWindowTitleButtonVisible(keep, keep, keep);
    } catch (e) {
    }
    if (keep) {
      this.applyDecorHeight();
      this.applyButtonStyle();
    }
    this.refresh();
  }

  private applyDecorHeight(): void {
    try {
      this.win?.setWindowDecorHeight(sparkClampDecorHeight(this.opts.barHeight));
    } catch (e) {
    }
  }

  private applyButtonStyle(): void {
    const style: window.DecorButtonStyle = {
      colorMode: this.opts.dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT,
      buttonBackgroundSize: 28,
      spacingBetweenButtons: 8,
      closeButtonRightMargin: 10,
      buttonIconSize: 16,
      buttonBackgroundCornerRadius: Math.max(4, Math.min(8, Math.round(this.opts.buttonRadius)))
    };
    try {
      this.win?.setDecorButtonStyle(style);
    } catch (e) {
    }
  }
}

const SPARK_WINDOW_CHROME: SparkWindowChrome = new SparkWindowChrome();
