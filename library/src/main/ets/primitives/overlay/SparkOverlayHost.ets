import { sparkText } from '../../core/SparkText';
import { SparkAnim } from '../../core/SparkAnim';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { Placement, PlacementRect, PlacementRequest, PlacementResult } from './Placement';
import { SparkOverlayScope, SparkOverlayService } from './SparkOverlay';

/** Default backdrop colour: shadcn `bg-black/50` (`--overlay-backdrop`, per component `--<key>-overlay`). */
const BACKDROP: string = '#80000000';

/**
 * Root of every SparkUI overlay layer (rendered inside a ComponentContent). Draws the backdrop, places the
 * content (centred / edge sheet / anchored with flip & shift), runs enter / exit transitions and re-provides
 * theme, layout and compound-component context to the content.
 */
@ComponentV2
export struct SparkOverlayHost {
  @Param @Require scope: SparkOverlayScope;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Provider('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Provider('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local originX: number = 0;
  @Local originY: number = 0;
  @Local hostX: number = 0;
  @Local hostY: number = 0;
  /** content-sized anchored layers: dialog offset applied so far, and whether the host position is known */
  private offX: number = 0;
  private offY: number = -10000;
  private areaKnown: boolean = false;

  aboutToAppear(): void {
    this.theme = this.scope.theme;
    this.layout = this.scope.layout;
    if (this.scope.contextKey.length > 0 && this.scope.contextValue !== undefined) {
      SparkContext.provide(this.getUIContext(), this.getUniqueId(), this.scope.contextKey, this.scope.contextValue);
      this.scope.hostComponentId = this.getUniqueId();
    }
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  /** `--<motion key>-overlay` (e.g. --dialog-overlay, --sheet-overlay) → `--overlay-backdrop` → black/50 */
  private backdrop(): string {
    const comp = this.theme.comp;
    return comp.color(this.scope.motionKey, 'overlay', comp.color('overlay', 'backdrop', BACKDROP));
  }

  private get anchored(): boolean {
    return this.scope.presentation === 'anchored';
  }

  private enter(): void {
    if (this.scope.visible) {
      return;
    }
    SparkAnim.run(this.getUIContext(), this.theme, this.scope.motionKey, 'normal', () => {
      this.scope.visible = true;
    });
  }

  private dismiss(): void {
    if (this.scope.dismissOnOutside) {
      this.scope.onDismiss('outside');
    }
  }

  /** Recompute anchored placement from the latest anchor / content size / viewport. */
  private place(): void {
    const s = this.scope;
    if (!this.anchored || s.anchor === undefined || s.measuredWidth <= 0) {
      return;
    }
    if (s.contentSized && !this.areaKnown) {
      return;
    }
    // Placement frame origin in window coordinates: the full-window host itself, or — for a content-sized
    // layer — the dialog's TopStart point (its current position minus the offset applied so far).
    const bx = s.contentSized ? this.hostX - this.offX : this.hostX;
    const by = s.contentSized ? this.hostY - this.offY : this.hostY;
    const env = this.layout.env;
    const r = new PlacementRequest();
    r.anchor = new PlacementRect(s.anchor.x - bx, s.anchor.y - by, s.anchor.width, s.anchor.height);
    r.content = new PlacementRect(0, 0, s.measuredWidth, s.measuredHeight);
    const w = SparkUI.layout.root.width;
    const h = SparkUI.layout.root.height;
    r.viewport = new PlacementRect(env.safeArea.left - bx, env.safeArea.top - by,
      w - env.safeArea.left - env.safeArea.right,
      h - env.safeArea.top - Math.max(env.safeArea.bottom, env.keyboardHeight));
    r.side = s.side;
    r.alignment = s.alignment;
    r.sideOffset = s.sideOffset;
    r.alignOffset = s.alignOffset;
    const result: PlacementResult = Placement.compute(r);
    s.placement = result;
    this.originX = result.originX;
    this.originY = result.originY;
    if (s.contentSized && (Math.abs(result.x - this.offX) > 0.5 || Math.abs(result.y - this.offY) > 0.5)) {
      this.offX = result.x;
      this.offY = result.y;
      SparkOverlayService.moveTo(s, result.x, result.y);
    }
  }

  // ---- transition values (functions of `visible`) ----

  private panelOpacity(): number {
    if (this.scope.presentation.startsWith('sheet')) {
      return 1;
    }
    return this.scope.visible ? 1 : 0;
  }

  private panelScale(): ScaleOptions {
    const p = this.scope.presentation;
    const k = this.scope.visible || (p !== 'center' && p !== 'anchored') ? 1 : 0.95;
    if (p === 'anchored') {
      return { x: k, y: k, centerX: this.originX, centerY: this.originY };
    }
    return { x: k, y: k };
  }

  private panelTranslate(): TranslateOptions {
    const s = this.scope;
    if (s.visible) {
      return { x: 0, y: 0 };
    }
    switch (s.presentation) {
      case 'sheet-bottom':
        return { x: 0, y: s.measuredHeight > 0 ? s.measuredHeight : '100%' };
      case 'sheet-top':
        return { x: 0, y: s.measuredHeight > 0 ? -s.measuredHeight : '-100%' };
      case 'sheet-left':
        return { x: s.measuredWidth > 0 ? -s.measuredWidth : '-100%', y: 0 };
      case 'sheet-right':
        return { x: s.measuredWidth > 0 ? s.measuredWidth : '100%', y: 0 };
      case 'anchored': {
        const side = s.placement?.side ?? s.side;
        const d = 8;
        return side === 'bottom' ? { x: 0, y: -d } : side === 'top' ? { x: 0, y: d } :
          side === 'right' ? { x: -d, y: 0 } : { x: d, y: 0 };
      }
      case 'toast':
        return { x: 0, y: 16 };
      default:
        return { x: 0, y: 0 };
    }
  }

  private stackAlign(): Alignment {
    switch (this.scope.presentation) {
      case 'center':
        return Alignment.Center;
      case 'sheet-bottom':
        return Alignment.Bottom;
      case 'sheet-top':
        return Alignment.Top;
      case 'sheet-left':
        return Alignment.Start;
      case 'sheet-right':
        return Alignment.End;
      case 'toast':
        return this.layout.env.windowWidthClass === 'compact' ? Alignment.Bottom : Alignment.BottomEnd;
      default:
        return Alignment.TopStart;
    }
  }

  build() {
    Stack({ alignContent: this.stackAlign() }) {
      if (this.scope.modal) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.backdrop())
          .opacity(this.scope.visible ? 1 : 0)
          .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT])
          .onClick(() => this.dismiss())
          .accessibilityText(sparkText(this.getUIContext(), $r('app.string.spark_close'), 'Close'))
      } else if (!this.scope.passThrough) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT])
          .onClick(() => this.dismiss())
      }
      Column() {
        this.content()
      }
      .position(this.anchored && !this.scope.contentSized ? {
        x: this.scope.placement?.x ?? 0,
        y: this.scope.placement?.y ?? 0
      } : undefined)
      .opacity(this.anchored && this.scope.placement === undefined ? 0 : this.panelOpacity())
      .scale(this.panelScale())
      .translate(this.panelTranslate())
      .hitTestBehavior(HitTestMode.Default)
      .onSizeChange((_: SizeOptions, n: SizeOptions) => {
        this.scope.measuredWidth = Number(n.width);
        this.scope.measuredHeight = Number(n.height);
        this.place();
        this.enter();
      })
    }
    .width(this.scope.contentSized ? 'auto' : '100%')
    .height(this.scope.contentSized ? 'auto' : '100%')
    .padding({ bottom: this.anchored || this.scope.contentSized ? 0 : this.layout.env.keyboardHeight })
    .hitTestBehavior(this.scope.passThrough ? HitTestMode.Transparent : HitTestMode.Default)
    .onAreaChange((_: Area, n: Area) => {
      this.hostX = Number(n.globalPosition.x ?? 0);
      this.hostY = Number(n.globalPosition.y ?? 0);
      this.areaKnown = true;
      this.place();
    })
  }
}

@Builder
function sparkOverlayHostBuilder(scope: SparkOverlayScope) {
  SparkOverlayHost({ scope: scope, content: scope.content })
}

const HOST: WrappedBuilder<[SparkOverlayScope]> = wrapBuilder(sparkOverlayHostBuilder);

/** Open an overlay layer for `scope` (see SparkOverlayService). */
export function openSparkOverlay(uiContext: UIContext, scope: SparkOverlayScope): void {
  SparkOverlayService.open(uiContext, scope, HOST);
}

/** Close with exit animation. */
export function closeSparkOverlay(scope: SparkOverlayScope): void {
  SparkOverlayService.close(scope);
}
