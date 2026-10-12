import { sparkText } from '../../core/SparkText';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkCaptionPlate, SparkTitleBarStyle, sparkTitleBarStyle, TitleBarTokens } from '../BlockTokens';
import { SparkSidebarState, SSidebarTrigger } from '../sidebar/SSidebar';
import { SparkWindowChrome, SparkWindowChromeOptions } from './SparkWindowChrome';
import {
  SparkCaptionAction, sparkMaximizeAction, SparkSystemButtons, sparkTitleBarHeight, SparkTitleBarShow,
  sparkTitleBarVisible, SparkWindowStatus
} from './TitleBarLogic';

/** Width (vp) the detached preview reserves for the mock system buttons in 'keep' mode. */
const PREVIEW_SYSTEM_RESERVE: number = 112;

/**
 * One caption button (minimize / maximize / restore / close), ghost-styled like `SButton` 'ghost' 'icon-sm'.
 * Pressed visuals come from the system pressed state (SparkRowPressModifier → applyPressedAttribute); its onTouch
 * only stops propagation so a press never starts a window drag.
 */
@ComponentV2
struct SCaptionButton {
  @Param icon: string = 'minus';
  @Param label: string = '';
  /** close: destructive hover */
  @Param danger: boolean = false;
  /** plate size (vp) */
  @Param plate: number = 28;
  /** the bar's resolved look (`--titlebar-caption-*` / `--titlebar-close-*`) */
  @Param look: SparkTitleBarStyle = new SparkTitleBarStyle();
  @Event onPress: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get plateColor(): string {
    if (!this.ix.hovered) {
      return SparkColor.alpha(this.look.captionHoverBackground, 0);
    }
    return this.danger ? this.look.closeHoverBackground : this.look.captionHoverBackground;
  }

  @Computed
  get pressedBackground(): string {
    return this.danger ? this.look.closePressedBackground : this.look.captionPressedBackground;
  }

  @Computed
  get glyph(): string {
    return this.danger && this.ix.hovered ? this.look.closeHoverForeground : this.look.captionForeground;
  }

  build() {
    Row() {
      SIcon({ name: this.icon, sizing: 16, color: this.glyph, strokeWidth: 1.75 })
    }
    .width(this.plate + 8)
    .height(this.plate)
    .justifyContent(FlexAlign.Center)
    .borderRadius(this.look.captionRadius)
    .attributeModifier(new SparkRowPressModifier(this.plateColor, this.pressedBackground, 1, false))
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onTouch((e: TouchEvent) => e.stopPropagation())
    .onClick(() => this.onPress())
    .accessibilityText(this.label)
  }
}

/**
 * Window title bar for free windows (PC/2in1, tablet 自由多窗 / 电脑模式): app icon + title, start / leading /
 * centre regions, an actions slot (trailing closure) and caption buttons drawn in the SparkUI style. The empty
 * bar area drags the window (`window.startMoving` from onTouch, as the docs require) and double-click maximizes /
 * restores.
 *
 * ```
 * @Builder function noteTabs() { NoteTabs() }     // global @Builder (a component holds the state)
 *
 * STitleBar({ title: 'Inbox', icon: 'mail', sidebarController: this.sidebar, centerBuilder: wrapBuilder(noteTabs) }) {
 *   SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'search', label: 'Search' })   // actions slot
 * }
 * ```
 * One @BuilderParam (the trailing actions closure); the other regions are `WrappedBuilder`s (`startBuilder`,
 * `leadingBuilder`, `centerBuilder`) and `sidebarController` covers the usual start content.
 * While mounted (and not `detached`) it owns the window chrome through `SparkWindowChrome.shared`: the system
 * title bar is hidden and `systemButtons` applied ('keep' restyles the system buttons and reserves their rect,
 * 'custom' draws ours, 'hidden' shows none); unmounting gives the chrome back to the system.
 * With `showWhen: 'auto'` it renders nothing on phones, outside free windows and in full screen (the system shows
 * its hover title bar there). Put it outside scrolling content (top of the page / SAppShell title-bar slot).
 *
 * Props renamed for ArkUI: the bar height is `barHeight` (0 = 40 vp with a pointer, 48 vp for touch).
 * `detached` draws a preview that never touches the real window (docs, mock-ups); caption presses only emit
 * `onCaption`. `detached` and the window claim are read once, when the bar appears.
 */
@ComponentV2
export struct STitleBar {
  @Param title: ResourceStr = '';
  /** lucide icon before the title */
  @Param icon: string | undefined = undefined;
  /** image (app icon) before the title; takes precedence over `icon` */
  @Param appIcon: ResourceStr | undefined = undefined;
  @Param systemButtons: SparkSystemButtons = 'custom';
  @Param showWhen: SparkTitleBarShow = 'auto';
  /** preview mode: never touches the window */
  @Param detached: boolean = false;
  /** vp; 0 = by input modality */
  @Param barHeight: number = 0;
  @Param bordered: boolean = true;
  /** translucent, backdrop-blurred background */
  @Param translucent: boolean = false;
  /** per-instance look (ADR D13): instance → `--titlebar-*` tokens → recipe */
  @Param tokens: TitleBarTokens = {};
  /** window status the detached preview starts in */
  @Param previewStatus: SparkWindowStatus = 'floating';
  /** fired for every caption action (also in detached mode) */
  @Event onCaption: (action: SparkCaptionAction) => void = () => {
  };
  /**
   * Shows an SSidebarTrigger for this controller before the app icon (the common `start` content: the bar
   * usually sits outside the SSidebarProvider).
   */
  @Param sidebarController: SparkSidebarState | undefined = undefined;
  /**
   * Region before the app icon (after the sidebar trigger; back, a menu…) — no-drag. A `WrappedBuilder`:
   * `startBuilder: wrapBuilder(myStart)` of a global `@Builder` (no `this`: render a component or read shared state).
   */
  @Param startBuilder: WrappedBuilder<[]> | undefined = undefined;
  /** region after the icon / title (menus, breadcrumbs) — no-drag; `wrapBuilder(globalBuilder)` */
  @Param leadingBuilder: WrappedBuilder<[]> | undefined = undefined;
  /** centred region (tabs, search) — no-drag, the space around it drags; `wrapBuilder(globalBuilder)` */
  @Param centerBuilder: WrappedBuilder<[]> | undefined = undefined;
  /** trailing actions before the caption buttons — the trailing closure (the only @BuilderParam), no-drag */
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local chrome: SparkWindowChrome = SparkWindowChrome.shared;
  @Local simulated: SparkWindowStatus = 'floating';
  private live: boolean = false;
  private touchDown: boolean = false;
  private moving: boolean = false;

  aboutToAppear(): void {
    this.simulated = this.previewStatus;
    this.live = !this.detached;
    if (this.live) {
      this.chrome.claim(this.getUniqueId(), this.options(), this.getUIContext());
    }
  }

  aboutToDisappear(): void {
    if (this.live) {
      this.chrome.release(this.getUniqueId());
    }
  }

  private options(): SparkWindowChromeOptions {
    const o = new SparkWindowChromeOptions();
    o.systemButtons = this.systemButtons;
    o.barHeight = this.resolvedHeight;
    o.dark = this.theme.isDark;
    o.buttonRadius = this.look.captionRadius;
    return o;
  }

  /** instance `tokens` → `--titlebar-*` tokens → recipe */
  @Computed
  get look(): SparkTitleBarStyle {
    return sparkTitleBarStyle(this.theme, this.tokens);
  }

  @Computed
  get captionRadius(): number {
    return this.look.captionRadius;
  }

  @Monitor('systemButtons')
  onModeChange(): void {
    if (this.live) {
      this.chrome.claim(this.getUniqueId(), this.options());
    }
  }

  @Monitor('theme.isDark', 'captionRadius')
  onDarkChange(): void {
    if (this.live) {
      this.chrome.restyle(this.theme.isDark, this.captionRadius);
    }
  }

  @Monitor('resolvedHeight')
  onHeightChange(): void {
    if (this.live) {
      this.chrome.setBarHeight(this.resolvedHeight);
    }
  }

  @Computed
  get resolvedHeight(): number {
    if (this.barHeight > 0) {
      return sparkTitleBarHeight(this.barHeight, false);
    }
    return this.layout.env.modality === 'pointer' ? this.look.height : this.look.heightTouch;
  }

  @Computed
  get status(): SparkWindowStatus {
    return this.detached ? this.simulated : this.chrome.status;
  }

  @Computed
  get visible(): boolean {
    if (this.detached) {
      return true;
    }
    return sparkTitleBarVisible(this.showWhen, this.chrome.freeWindow, this.chrome.owned, this.chrome.status);
  }

  /** our caption buttons do something only in a free window (or in the preview) */
  @Computed
  get drawCaptions(): boolean {
    return this.systemButtons === 'custom' && (this.detached || this.chrome.freeWindow);
  }

  @Computed
  get reserve(): number {
    if (this.systemButtons !== 'keep') {
      return 0;
    }
    return this.detached ? PREVIEW_SYSTEM_RESERVE : this.chrome.captionReserve;
  }

  @Computed
  get plate(): number {
    return sparkCaptionPlate(this.look, this.resolvedHeight);
  }

  private act(a: SparkCaptionAction): void {
    this.onCaption(a);
    if (this.detached) {
      if (a === 'maximize') {
        this.simulated = 'maximized';
      } else if (a === 'restore') {
        this.simulated = 'floating';
      }
      return;
    }
    switch (a) {
      case 'minimize':
        this.chrome.minimize();
        break;
      case 'maximize':
        this.chrome.maximize();
        break;
      case 'restore':
        this.chrome.restore();
        break;
      case 'close':
        this.chrome.close();
        break;
    }
  }

  /** Drag region: startMoving must be called from onTouch (Down, or Move after Down) — official pattern. */
  private dragTouch(e: TouchEvent): void {
    if (this.detached) {
      return;
    }
    if (e.type === TouchType.Down) {
      this.touchDown = true;
      this.moving = false;
    } else if (e.type === TouchType.Move) {
      if (this.touchDown && !this.moving) {
        this.moving = true;
        this.chrome.startMoving();
      }
    } else {
      this.touchDown = false;
      this.moving = false;
    }
  }

  @Builder
  mockSystemButtons() {
    Row({ space: 14 }) {
      SIcon({ name: 'minus', sizing: 14, color: this.theme.colors.mutedForeground })
      SIcon({ name: 'square', sizing: 12, color: this.theme.colors.mutedForeground })
      SIcon({ name: 'x', sizing: 14, color: this.theme.colors.mutedForeground })
    }
    .height(this.plate)
    .padding({ left: 10, right: 10 })
    .borderRadius(this.theme.radiusSm)
    .border({ width: 1, color: this.theme.colors.border, style: BorderStyle.Dashed, radius: this.theme.radiusSm })
  }

  build() {
    if (this.visible) {
      Row({ space: 8 }) {
        if (this.sidebarController !== undefined || this.startBuilder !== undefined) {
          Row({ space: 4 }) {
            if (this.sidebarController !== undefined) {
              SSidebarTrigger({ controller: this.sidebarController })
            }
            if (this.startBuilder !== undefined) {
              this.startBuilder.builder()
            }
          }
          .onTouch((e: TouchEvent) => e.stopPropagation())
        }
        if (this.appIcon !== undefined) {
          Image(this.appIcon)
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .draggable(false)
        } else if (this.icon !== undefined) {
          SIcon({ name: this.icon, sizing: 16, color: this.look.titleColor })
        }
        Text(this.title)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.look.titleColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(1)
        if (this.leadingBuilder !== undefined) {
          Row() {
            this.leadingBuilder.builder()
          }
          .onTouch((e: TouchEvent) => e.stopPropagation())
        }

        // the space around the centre region stays draggable
        Row() {
          if (this.centerBuilder !== undefined) {
            Row() {
              this.centerBuilder.builder()
            }
            .onTouch((e: TouchEvent) => e.stopPropagation())
          }
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)

        Row({ space: 4 }) {
          this.content()
        }
        .onTouch((e: TouchEvent) => e.stopPropagation())

        if (this.drawCaptions) {
          Row({ space: 2 }) {
            SCaptionButton({ icon: 'minus', label: sparkText(this.getUIContext(), $r('app.string.spark_minimize'), 'Minimize'), plate: this.plate, look: this.look,
              onPress: () => this.act('minimize') })
            SCaptionButton({
              icon: sparkMaximizeAction(this.status) === 'restore' ? 'copy' : 'square',
              label: sparkMaximizeAction(this.status) === 'restore' ? sparkText(this.getUIContext(), $r('app.string.spark_restore'), 'Restore') : sparkText(this.getUIContext(), $r('app.string.spark_maximize'), 'Maximize'),
              plate: this.plate, look: this.look,
              onPress: () => this.act(sparkMaximizeAction(this.status))
            })
            SCaptionButton({ icon: 'x', label: sparkText(this.getUIContext(), $r('app.string.spark_close'), 'Close'), danger: true, plate: this.plate, look: this.look,
              onPress: () => this.act('close') })
          }
        }
        if (this.reserve > 0) {
          if (this.detached) {
            this.mockSystemButtons()
          } else {
            // kept system buttons are drawn by the system over this space
            Column()
              .width(this.reserve)
              .height('100%')
              .onTouch((e: TouchEvent) => e.stopPropagation())
          }
        }
      }
      .width('100%')
      .height(this.resolvedHeight)
      .padding({ left: 12, right: this.drawCaptions ? 6 : (this.reserve > 0 && !this.detached ? 0 : 12) })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.translucent ? this.look.translucentBackground : this.look.background)
      .backdropBlur(this.translucent ? this.look.translucentBlur : 0)
      .border({ width: { bottom: this.bordered ? this.look.borderWidth : 0 }, color: this.look.borderColor })
      .onTouch((e: TouchEvent) => this.dragTouch(e))
      .gesture(TapGesture({ count: 2 }).onAction(() => this.act(sparkMaximizeAction(this.status))))
    }
  }
}
