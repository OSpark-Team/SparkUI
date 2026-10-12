import {
  SButton, SIcon, SparkCaptionAction, SparkSystemButtons, SparkTheme, SparkUI, SparkWindowChrome, SSwitch,
  STitleBar, SToggleGroup, SToggleGroupItem, SparkSidebarState, sparkTitleBarVisible
} from '@sparkui/core';
import { DemoBlock, DemoCaption, DemoPropRow, DocHeader, DocSection } from '../shell/DocKit';

const PREVIEW_CODE = `STitleBar({ title: 'SparkUI Gallery', icon: 'sparkles', systemButtons: 'custom' }) {
  SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'search', label: 'Search' })   // actions slot
}

// systemButtons:
//   'keep'   — system buttons stay (restyled via setDecorButtonStyle), the bar reserves getTitleButtonRect
//   'custom' — system buttons hidden, SparkUI draws its own (minimize / maximize·restore / close)
//   'hidden' — no caption buttons`;

const SLOTS_CODE = `// regions take wrapBuilder(globalBuilder); a component keeps the region's state
@Builder function noteMenu() { SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'menu', label: 'Menu' }) }
@Builder function noteTabs() { NoteTabs() }   // @ComponentV2 struct with its own @Local tab

STitleBar({
  title: 'Notes', icon: 'file-text',
  sidebarController: this.sidebar,            // SSidebarTrigger before the icon
  leadingBuilder: wrapBuilder(noteMenu),       // after the title
  centerBuilder: wrapBuilder(noteTabs)         // centred
}) {
  SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'share', label: 'Share' })   // trailing actions
}
// every region is no-drag; the free bar area drags the window, double-click maximizes / restores.`;

const SETUP_CODE = `// EntryAbility.onWindowStageCreate — inside the loadContent callback (decor APIs need it):
windowStage.loadContent('pages/Index', (err) => {
  if (err.code) { return; }
  SparkWindowChrome.init(windowStage, this.context);
});

// Page: the bar lives outside the scrolling content. On phones / outside free windows /
// in full screen it renders nothing, and the system title bar comes back when it unmounts.
Column() {
  STitleBar({ title: 'My App', icon: 'sparkles' })
  MyContent().layoutWeight(1)
}`;

@Builder
function noteMenu() {
  SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'menu', label: 'Menu' })
}

/** Centre region of the slots demo: a component, so the selected tab is its own state. */
@ComponentV2
struct NoteTabs {
  @Local tab: string = 'files';

  build() {
    SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.tab],
      onValueChange: (v: string[]) => {
        if (v.length > 0) {
          this.tab = v[0];
        }
      } }) {
      SToggleGroupItem({ value: 'files', text: 'Files' })
      SToggleGroupItem({ value: 'edit', text: 'Edit' })
      SToggleGroupItem({ value: 'view', text: 'View' })
    }
  }
}

@Builder
function noteTabs() {
  NoteTabs()
}

/** Gallery-wide switch for the live title bar ("apply to this window"). Read by the gallery root. */
@ObservedV2
export class GalleryWindowChrome {
  /**
   * Singleton, created after the class (see below) rather than in a static initializer: static initializers run
   * before the class decorators are applied, so an instance created there is not observed by V2 and its @Trace
   * fields would not refresh the UI.
   */
  static get shared(): GalleryWindowChrome {
    return GALLERY_WINDOW_CHROME;
  }
  @Trace enabled: boolean = false;
  @Trace systemButtons: SparkSystemButtons = 'custom';

  /**
   * The live title bar is on screen (switch on, free window, not full screen / minimized). While it is, it hosts
   * the sidebar and theme toggles and the app's top bar drops its own copies (one control per action).
   */
  get active(): boolean {
    const c = SparkWindowChrome.shared;
    return this.enabled && sparkTitleBarVisible('auto', c.freeWindow, c.owned, c.status);
  }
}

const GALLERY_WINDOW_CHROME: GalleryWindowChrome = new GalleryWindowChrome();

/**
 * The gallery's live title bar: renders only while "Apply to this window" is on (and the window is free). It then
 * carries the sidebar toggle and the theme toggle; the top bar hides its own (see GalleryWindowChrome.active).
 */
@ComponentV2
export struct GalleryTitleBar {
  /** the app's sidebar controller, so the toggle works from outside the sidebar provider */
  @Param sidebar: SparkSidebarState | undefined = undefined;
  @Local g: GalleryWindowChrome = GalleryWindowChrome.shared;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column() {
      if (this.g.enabled) {
        // sidebar toggle at the start (sidebarController), theme toggle in the trailing closure
        STitleBar({
          title: 'SparkUI Gallery',
          icon: 'sparkles',
          systemButtons: this.g.systemButtons,
          sidebarController: this.sidebar
        }) {
          SButton({ variant: 'ghost', sizing: 'icon-sm', icon: this.theme.isDark ? 'sun' : 'moon',
            label: 'Toggle theme' })
            .onClick(() => SparkUI.themes.toggleDark())
        }
      }
    }
    .width('100%')
  }
}

/** Mock window around a detached STitleBar. */
@ComponentV2
struct WindowFrame {
  @Param mode: SparkSystemButtons = 'custom';
  @Param title: string = 'SparkUI Gallery';
  @Event onCaption: (a: SparkCaptionAction) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column() {
      STitleBar({
        title: this.title,
        icon: 'sparkles',
        systemButtons: this.mode,
        detached: true,
        onCaption: (a: SparkCaptionAction) => this.onCaption(a)
      }) {
        SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'search', label: 'Search' })
      }
      Column({ space: 8 }) {
        ForEach([0.9, 0.7, 0.8], (w: number, i: number) => {
          Column()
            .width(`${Math.round(w * 100)}%`)
            .height(12)
            .borderRadius(this.theme.radiusSm)
            .backgroundColor(this.theme.colors.muted)
        }, (w: number, i: number) => `${i}`)
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor(this.theme.colors.background)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
    .shadow(this.theme.shadows.lg.toOptions())
    .clip(true)
  }
}

@ComponentV2
struct ModePicker {
  @Param mode: SparkSystemButtons = 'custom';
  @Event onPick: (m: SparkSystemButtons) => void = () => {
  };

  build() {
    SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.mode],
      onValueChange: (v: string[]) => {
        if (v.length > 0) {
          this.onPick(v[0] as SparkSystemButtons);
        }
      } }) {
      SToggleGroupItem({ value: 'custom', text: 'Custom' })
      SToggleGroupItem({ value: 'keep', text: 'Keep system' })
      SToggleGroupItem({ value: 'hidden', text: 'Hidden' })
    }
  }
}

@ComponentV2
export struct TitleBarDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local chrome: SparkWindowChrome = SparkWindowChrome.shared;
  @Local g: GalleryWindowChrome = GalleryWindowChrome.shared;
  @Local previewMode: SparkSystemButtons = 'custom';
  @Local lastCaption: string = '—';

  aboutToAppear(): void {
    // read the live window state (no claim: only "Apply to this window" changes the window)
    this.chrome.attach(this.getUIContext());
  }

  rectText(): string {
    const r = this.chrome.titleButtonRect;
    return `right ${r.right} · top ${r.top} · ${r.width}×${r.height} vp`;
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Title Bar',
        lead: 'A window title bar for free windows — PC/2in1 and tablets in 自由多窗 / 电脑模式. It replaces the ' +
          'system title bar with a SparkUI one: icon, title, slots, caption buttons in the theme, drag to move and ' +
          'double-click to maximize. On phones and full-screen windows it disappears by itself.'
      })

      DocSection({
        title: 'Preview',
        description: 'Detached previews never touch the real window; caption presses only report the action.'
      })
      ModePicker({ mode: this.previewMode, onPick: (m: SparkSystemButtons) => {
        this.previewMode = m;
      } })
      DemoBlock({ code: PREVIEW_CODE, centered: false }) {
        Column() {
          WindowFrame({ mode: this.previewMode, onCaption: (a: SparkCaptionAction) => {
            this.lastCaption = a;
          } })
          DemoCaption({ text: `last caption action: ${this.lastCaption}` })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      DocSection({
        title: 'Slots',
        description: 'The trailing closure holds the actions; sidebarController adds a sidebar toggle at the ' +
          'start; startBuilder / leadingBuilder / centerBuilder take wrapBuilder(globalBuilder) for anything else. ' +
          'Regions never start a window drag; the free space around them does.'
      })
      DemoBlock({ code: SLOTS_CODE, centered: false }) {
        Column() {
          STitleBar({
            title: 'Notes',
            icon: 'file-text',
            detached: true,
            leadingBuilder: wrapBuilder(noteMenu),
            centerBuilder: wrapBuilder(noteTabs)
          }) {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'share', label: 'Share' })
          }
        }
        .width('100%')
        .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
        .clip(true)
      }

      DocSection({
        title: 'This window',
        description: 'Live state from SparkWindowChrome. "Apply" hides the system title bar of this window and ' +
          'shows STitleBar at the top of the gallery; it needs a free window.'
      })
      Column() {
        DemoPropRow({ label: 'device type', value: this.chrome.deviceType })
        DemoPropRow({ label: 'free window', value: this.chrome.freeWindow ? 'yes' : 'no' })
        DemoPropRow({ label: 'status', value: this.chrome.status })
        DemoPropRow({ label: 'system title bar', value: this.chrome.decorVisible ? 'visible' : 'hidden' })
        DemoPropRow({ label: 'decor height', value: `${this.chrome.decorHeight} vp` })
        DemoPropRow({ label: 'system buttons rect', value: this.rectText() })
        DemoPropRow({ label: 'owner mode', value: this.chrome.systemButtons })
      }
      .width('100%')

      Row({ space: 12 }) {
        SSwitch({
          checked: this.g.enabled,
          disabled: !this.chrome.freeWindow && !this.g.enabled,
          label: 'Apply to this window',
          description: this.chrome.freeWindow ? 'Uses the caption mode below.' :
            'Not a free window here (phone, or tablet without 自由多窗 / 电脑模式).',
          onCheckedChange: (v: boolean) => {
            this.g.enabled = v;
          }
        })
      }
      .width('100%')
      ModePicker({ mode: this.g.systemButtons, onPick: (m: SparkSystemButtons) => {
        this.g.systemButtons = m;
      } })

      DocSection({ title: 'Setup', description: 'Bind the main window once, then place the bar on top of the page.' })
      DemoBlock({ code: SETUP_CODE, centered: false }) {
        Row({ space: 8 }) {
          SIcon({ name: 'laptop', sizing: 16, color: this.theme.colors.mutedForeground })
          Text('See the Code tab.')
            .fontSize(this.theme.text.sm)
            .fontColor(this.theme.colors.mutedForeground)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
