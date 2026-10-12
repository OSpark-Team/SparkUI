import { SparkDisclosure } from '../SparkDisclosure';
import { SparkOverlayScope, SparkOverlayService } from './SparkOverlay';
import { closeSparkOverlay, openSparkOverlay } from './SparkOverlayHost';

/** Fills in a freshly created scope each time the overlay opens. */
export type OverlayConfigurator = (scope: SparkOverlayScope, ctx: SparkDisclosure) => void;

/**
 * Glue between a compound component's {@link SparkDisclosure} and an overlay layer: opens a fresh layer
 * whenever the state opens, closes it (with exit animation) when it closes, and cleans up on unmount.
 * Used by every `S*Content` overlay part.
 *
 * ```
 * private binding: OverlayBinding = new OverlayBinding();
 * onDidBuild() { this.ctx = this.binding.bind(this.getUIContext(), this.getUniqueId(), KEY, (s, ctx) => {...}); }
 * aboutToDisappear() { this.binding.dispose(); }
 * ```
 */
export class OverlayBinding {
  private scope: SparkOverlayScope | undefined = undefined;
  private unsubscribe: () => void = () => {
  };
  private ctx: SparkDisclosure | undefined = undefined;
  private uiContext: UIContext | undefined = undefined;
  private configure: OverlayConfigurator = () => {
  };

  /** Attach to `ctx` (already resolved). Opens immediately when it is already open. */
  attach(uiContext: UIContext, ctx: SparkDisclosure, configure: OverlayConfigurator): void {
    if (this.ctx !== undefined) {
      return;
    }
    this.ctx = ctx;
    this.uiContext = uiContext;
    this.configure = configure;
    this.unsubscribe = ctx.subscribe((open: boolean) => open ? this.show() : this.hide());
    if (ctx.open) {
      this.show();
    }
  }

  get current(): SparkOverlayScope | undefined {
    return this.scope;
  }

  show(): void {
    if (this.scope !== undefined && SparkOverlayService.isOpen(this.scope)) {
      return;
    }
    const ctx = this.ctx;
    const ui = this.uiContext;
    if (ctx === undefined || ui === undefined) {
      return;
    }
    const scope = SparkOverlayService.createScope();
    scope.restoreFocusId = ctx.triggerKey;
    scope.contextValue = ctx;
    scope.onDismiss = () => ctx.setOpen(false);
    this.configure(scope, ctx);
    this.scope = scope;
    openSparkOverlay(ui, scope);
  }

  hide(): void {
    if (this.scope !== undefined) {
      closeSparkOverlay(this.scope);
    }
  }

  dispose(): void {
    this.unsubscribe();
    this.hide();
  }
}

/**
 * Non-competing activation: fires `action` on the next tick after a touch is released without moving
 * (or on Enter / Space). Touch events reach every ancestor and never enter the gesture arena, so the
 * developer's own `.onClick()` on the component still fires first — a child TapGesture (even "parallel")
 * would win against an ancestor's onClick and swallow it (verified on device).
 */
export class SparkActivation {
  private downX: number = 0;
  private downY: number = 0;
  private moved: boolean = false;

  /** Pass to `.onTouch()`. */
  touch(e: TouchEvent, disabled: boolean, action: () => void): void {
    const t = e.touches.length > 0 ? e.touches[0] : (e.changedTouches.length > 0 ? e.changedTouches[0] : undefined);
    if (t === undefined) {
      return;
    }
    if (e.type === TouchType.Down) {
      this.downX = t.windowX;
      this.downY = t.windowY;
      this.moved = false;
    } else if (e.type === TouchType.Move) {
      if (Math.abs(t.windowX - this.downX) > 10 || Math.abs(t.windowY - this.downY) > 10) {
        this.moved = true;
      }
    } else if (e.type === TouchType.Up && !this.moved && !disabled) {
      setTimeout(action, 0);
    } else if (e.type === TouchType.Cancel) {
      this.moved = true;
    }
  }

  /** Pass to `.onKeyEvent()`: Enter / Space activate. */
  key(e: KeyEvent, disabled: boolean, action: () => void): void {
    if (!disabled && e.type === KeyType.Up && (e.keyCode === 2054 || e.keyCode === 2050)) {
      action();
    }
  }
}
