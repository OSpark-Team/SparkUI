/**
 * Pure title-bar / window-chrome logic (no ArkUI or window imports) so it can be unit tested.
 */

/**
 * What happens to the system caption buttons (minimize / maximize / close) while an STitleBar owns the window:
 * - 'keep': the system title bar is hidden but the system buttons stay (restyled through `setDecorButtonStyle`);
 *   STitleBar reserves their rect (`getTitleButtonRect`).
 * - 'custom': system buttons hidden too; STitleBar draws its own caption buttons.
 * - 'hidden': no caption buttons at all (kiosk-like windows; closing is left to the app / system gestures).
 */
export type SparkSystemButtons = 'keep' | 'custom' | 'hidden';

/** Window status mirrored from `window.WindowStatusType`. */
export type SparkWindowStatus = 'fullscreen' | 'maximized' | 'minimized' | 'floating' | 'split' | 'unknown';

/** When STitleBar renders: 'auto' only in a free window whose system title bar is owned by SparkUI; 'always' always. */
export type SparkTitleBarShow = 'auto' | 'always';

/** Caption action ids emitted by STitleBar (`onCaption`). */
export type SparkCaptionAction = 'minimize' | 'maximize' | 'restore' | 'close';

/** `setWindowDecorHeight` accepts integers in [37, 112] vp. */
export const SPARK_DECOR_HEIGHT_MIN: number = 37;
export const SPARK_DECOR_HEIGHT_MAX: number = 112;
/** Default bar heights (vp): pointer (2in1 / mouse) and touch (tablet free window). */
export const SPARK_TITLEBAR_HEIGHT_POINTER: number = 40;
export const SPARK_TITLEBAR_HEIGHT_TOUCH: number = 48;

export function sparkClampDecorHeight(h: number): number {
  return Math.max(SPARK_DECOR_HEIGHT_MIN, Math.min(SPARK_DECOR_HEIGHT_MAX, Math.floor(h)));
}

/** Bar height: explicit value, else by input modality. */
export function sparkTitleBarHeight(explicit: number, pointer: boolean): number {
  if (explicit > 0) {
    return explicit;
  }
  return pointer ? SPARK_TITLEBAR_HEIGHT_POINTER : SPARK_TITLEBAR_HEIGHT_TOUCH;
}

/**
 * Width (vp) to keep free on the trailing edge for the system caption buttons. `TitleButtonRect` is relative to
 * the window's top-right corner: `right` is the gap to the window edge, `width` the buttons' width.
 */
export function sparkCaptionReserve(rectWidth: number, rectRight: number): number {
  if (rectWidth <= 0) {
    return 0;
  }
  return rectWidth + Math.max(0, rectRight);
}

/** Whether a window-bound STitleBar should render. */
export function sparkTitleBarVisible(show: SparkTitleBarShow, freeWindow: boolean, owned: boolean,
  status: SparkWindowStatus): boolean {
  if (show === 'always') {
    return true;
  }
  if (!freeWindow || !owned) {
    return false;
  }
  return status !== 'fullscreen' && status !== 'minimized';
}

/** Maximize button semantics: maximized / full-screen windows restore, others maximize. */
export function sparkMaximizeAction(status: SparkWindowStatus): SparkCaptionAction {
  return status === 'maximized' || status === 'fullscreen' ? 'restore' : 'maximize';
}
