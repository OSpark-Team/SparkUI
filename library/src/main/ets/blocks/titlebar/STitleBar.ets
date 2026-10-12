import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
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
  @Event onPress: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get plateColor(): string {
    if (!this.ix.hovered) {
      return SparkColor.alpha(this.theme.colors.accent, 0);
    }
    return this.danger ? this.theme.colors.destructive : this.theme.colors.accent;
  }

  @Computed
  get pressedBackground(): string {
    return this.danger ? SparkColor.alpha(this.theme.colors.destructive, 0.85) :
      SparkColor.mix(this.theme.colors.accent, this.theme.colors.foreground, 0.08);
  }

  @Computed
  get glyph(): string {
    return this.danger && this.ix.hovered ? this.theme.colors.destructiveForeground : this.theme.colors.foreground;
  }

  build() {
    Row() {
      SIcon({ name: this.icon, sizing: 16, color: this.glyph, strokeWidth: 1.75 })
    }
    .width(this.plate + 8)
    .height(this.plate)
    .justifyContent(FlexAlign.Center)
    .borderRadius(this.theme.radiusMd)
    .attributeModifier(new SparkRowPressModifier(this.plateColor, this.pressedBackground, 1, false))
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onTouch((e: TouchEvent) => e.stopPropagation())
    .onClick(() => this.onPress())
    .accessibilityText(this.label)
  }
}

/**
 * Window title bar for free windows (PC/2in1, tablet 自由多窗 / 电脑模式): app icon + title, a centre slot, an
 * actions slot (trailing closure) and caption buttons drawn in the SparkUI style. The empty bar area drags the
 * window (`window.startMoving` from onTouch, as the docs require) and double-click maximizes / restores.
 *
 * ```
 * STitleBar({ title: 'Inbox', icon: 'mail', systemButtons: 'custom', center: this.tabs }) {
 *   SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'search', label: 'Search' })   // actions slot
 * }
 * ```
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
  /** window status the detached preview starts in */
  @Param previewStatus: SparkWindowStatus = 'floating';
  /** fired for every caption action (also in detached mode) */
  @Event onCaption: (action: SparkCaptionAction) => void = () => {
  };
  /** content after the icon / title (menus, breadcrumbs) — a no-drag region */
  /** before the app icon (sidebar toggle, back) — a no-drag region */
  @BuilderParam start: () => void = sparkEmptyBuilder;
  @BuilderParam leading: () => void = sparkEmptyBuilder;
  /** centred content (tabs, search) — a no-drag region; the space around it drags */
  @BuilderParam center: () => void = sparkEmptyBuilder;
  /** trailing actions before the caption buttons — a no-drag region */
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
    o.buttonRadius = this.theme.radiusMd;
    return o;
  }

  @Monitor('systemButtons')
  onModeChange(): void {
    if (this.live) {
      this.chrome.claim(this.getUniqueId(), this.options());
    }
  }

  @Monitor('theme.isDark')
  onDarkChange(): void {
    if (this.live) {
      this.chrome.restyle(this.theme.isDark, this.theme.radiusMd);
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
    return sparkTitleBarHeight(this.barHeight, this.layout.env.modality === 'pointer');
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
    return Math.min(32, Math.max(24, this.resolvedHeight - 12));
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
        if (this.start !== sparkEmptyBuilder) {
          Row() {
            this.start()
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
          SIcon({ name: this.icon, sizing: 16, color: this.theme.colors.foreground })
        }
        Text(this.title)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.foreground)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(1)
        Row() {
          this.leading()
        }
        .onTouch((e: TouchEvent) => e.stopPropagation())

        // the space around the centre slot stays draggable
        Row() {
          Row() {
            this.center()
          }
          .onTouch((e: TouchEvent) => e.stopPropagation())
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
            SCaptionButton({ icon: 'minus', label: 'Minimize', plate: this.plate,
              onPress: () => this.act('minimize') })
            SCaptionButton({
              icon: sparkMaximizeAction(this.status) === 'restore' ? 'copy' : 'square',
              label: sparkMaximizeAction(this.status) === 'restore' ? 'Restore' : 'Maximize',
              plate: this.plate,
              onPress: () => this.act(sparkMaximizeAction(this.status))
            })
            SCaptionButton({ icon: 'x', label: 'Close', danger: true, plate: this.plate,
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
      .backgroundColor(this.translucent ? SparkColor.alpha(this.theme.colors.background, 0.8) :
        this.theme.colors.background)
      .backdropBlur(this.translucent ? 20 : 0)
      .border({ width: { bottom: this.bordered ? 1 : 0 }, color: this.theme.colors.border })
      .onTouch((e: TouchEvent) => this.dragTouch(e))
      .gesture(TapGesture({ count: 2 }).onAction(() => this.act(sparkMaximizeAction(this.status))))
    }
  }
}
