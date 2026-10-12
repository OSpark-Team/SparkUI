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
