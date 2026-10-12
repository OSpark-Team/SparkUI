import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { MenuItemVariant, MenuLabel, MenuSeparator } from '../../primitives/menu/MenuRow';
import {
  SparkMenuCheckboxPart, SparkMenuHandle, SparkMenuItemPart, SparkMenuRadioGroupPart, SparkMenuRadioPart,
  sparkSheetHandle
} from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { PlacementRect } from '../../primitives/overlay/Placement';
import { SparkOverlayScope, SparkOverlayService } from '../../primitives/overlay/SparkOverlay';
import { closeSparkOverlay, openSparkOverlay } from '../../primitives/overlay/SparkOverlayHost';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';

const BAR_KEY: string = 'spark.menubar';
const MENU_KEY: string = 'spark.menubar.menu';
/** key of the item handle inside a menu overlay */
const ITEM_KEY: string = 'spark.menubar.items';
const MORE_ID: number = -2;
/** gap after each trigger (gap-1) */
const GAP: number = 4;
/** width of the "More" trigger */
const MORE_WIDTH: number = 32;
/** bar border (1 + 1) + padding (p-1 × 2) */
const BAR_CHROME: number = 10;
const KEY_LEFT: number = 2014;
const KEY_RIGHT: number = 2015;

/** One menu of the bar. */
@ObservedV2
export class SparkMenubarMenuState {
  readonly id: number;
  readonly disclosure: SparkDisclosure = new SparkDisclosure();
  readonly handle: SparkMenuHandle = new SparkMenuHandle();
  @Trace label: string = '';
  /** measured trigger width while visible (vp) */
  naturalWidth: number = 0;
  /** renders this menu's items (for the overflow "More" menu) */
  items: () => void = () => {
  };

  constructor(id: number) {
    this.id = id;
    this.handle.close = () => this.disclosure.setOpen(false);
  }
}

class ProxyRect {
  id: number;
  x: number;
  y: number;
  w: number;
  h: number;

  constructor(id: number, x: number, y: number, w: number, h: number) {
    this.id = id;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }
}

/**
 * Menubar state: which menu is open, the registered menus (document order) and how many fit in the bar.
 */
@ObservedV2
export class SparkMenubarState {
  /** id of the open menu (-1: none, MORE_ID: the overflow menu) */
  @Trace openId: number = -1;
  @Trace menus: SparkMenubarMenuState[] = [];
  /** number of menus shown as triggers; the rest collapse into "More" */
  @Trace visibleCount: number = 1000;
  readonly more: SparkMenubarMenuState = new SparkMenubarMenuState(MORE_ID);
  barWidth: number = 0;
  /** set by SMenubar: after a menu opened (anchored) / after everything closed */
  onMenuShown: (sheet: boolean) => void = () => {
  };
  onAllClosed: () => void = () => {
  };

  constructor() {
    this.more.label = 'More';
    this.wire(this.more);
  }

  private wire(m: SparkMenubarMenuState): void {
    m.disclosure.emit = (open: boolean) => {
      if (!open && this.openId === m.id) {
        this.openId = -1;
        this.onAllClosed();
      }
    };
  }

  register(m: SparkMenubarMenuState): void {
    this.wire(m);
    const list = this.menus.filter((x: SparkMenubarMenuState) => x.id !== m.id);
    list.push(m);
    list.sort((a: SparkMenubarMenuState, b: SparkMenubarMenuState) => a.id - b.id);
    this.menus = list;
    this.relayout();
  }

  unregister(id: number): void {
    this.menus = this.menus.filter((x: SparkMenubarMenuState) => x.id !== id);
    this.relayout();
  }

  private find(id: number): SparkMenubarMenuState | undefined {
    return id === MORE_ID ? this.more : this.menus.find((x: SparkMenubarMenuState) => x.id === id);
  }

  indexOf(id: number): number {
    return this.menus.findIndex((x: SparkMenubarMenuState) => x.id === id);
  }

  isHidden(id: number): boolean {
    const i = this.indexOf(id);
    return i >= this.visibleCount;
  }

  get hasOverflow(): boolean {
    return this.visibleCount < this.menus.length;
  }

  get hiddenMenus(): SparkMenubarMenuState[] {
    return this.menus.slice(this.visibleCount);
  }

  /** menus reachable from the bar, in order (visible triggers, then More) */
  private reachable(): SparkMenubarMenuState[] {
    const list = this.menus.slice(0, Math.min(this.visibleCount, this.menus.length));
    if (this.hasOverflow) {
      list.push(this.more);
    }
    return list;
  }

  open(id: number): void {
    const target = this.find(id);
    if (target === undefined) {
      return;
    }
    this.openId = id;
    this.menus.forEach((m: SparkMenubarMenuState) => {
      if (m.id !== id) {
        m.disclosure.assign(false);
      }
    });
    if (id !== MORE_ID) {
      this.more.disclosure.assign(false);
    }
    target.disclosure.assign(true);
    this.onMenuShown(target.handle.sheet);
  }

  close(): void {
    const target = this.find(this.openId);
    if (target !== undefined) {
      target.disclosure.setOpen(false);
    } else {
      this.openId = -1;
      this.onAllClosed();
    }
  }

  toggle(id: number): void {
    if (this.openId === id) {
      this.close();
    } else {
      this.open(id);
    }
  }

  /** pointer moved onto a trigger: switch menus while one is open */
  hover(id: number): void {
    if (this.openId !== -1 && this.openId !== id) {
      this.open(id);
    }
  }

  /** ← / → inside an open menu */
  openAdjacent(delta: number): void {
    const list = this.reachable();
    if (list.length === 0 || this.openId === -1) {
      return;
    }
    const cur = list.findIndex((m: SparkMenubarMenuState) => m.id === this.openId);
    const next = list[((cur < 0 ? 0 : cur) + delta + list.length) % list.length];
    this.open(next.id);
  }

  setBarWidth(w: number): void {
    if (Math.abs(w - this.barWidth) >= 0.5) {
      this.barWidth = w;
      this.relayout();
    }
  }

  setTriggerWidth(m: SparkMenubarMenuState, w: number): void {
    if (w > 0 && Math.abs(w - m.naturalWidth) >= 0.5) {
      m.naturalWidth = w;
      this.relayout();
    }
  }

  /** Decide how many triggers fit; the rest go into "More". */
  relayout(): void {
    const n = this.menus.length;
    let count = n;
    const measured = n > 0 && this.barWidth > 0 && this.menus.every((m: SparkMenubarMenuState) => m.naturalWidth > 0);
    if (measured) {
      const avail = this.barWidth - BAR_CHROME;
      let total = 0;
      this.menus.forEach((m: SparkMenubarMenuState) => {
        total += m.naturalWidth + GAP;
      });
      if (total > avail) {
        let used = MORE_WIDTH + GAP;
        count = 0;
        while (count < n && used + this.menus[count].naturalWidth + GAP <= avail) {
          used += this.menus[count].naturalWidth + GAP;
          count++;
        }
      }
    }
    if (count !== this.visibleCount) {
      this.visibleCount = count;
      // an open menu whose trigger just collapsed into "More" closes
      if (this.openId >= 0 && this.isHidden(this.openId)) {
        this.close();
      }
    }
  }
}

/**
 * shadcn-vue `Menubar`: a horizontal bar (`h-9 rounded-md border p-1 shadow-xs`) of menu triggers, each
 * opening an anchored dropdown below it. While one menu is open, hovering (or tapping) another trigger
 * switches to it, and ← / → move between menus.
 *
 * Responsive: the bar measures itself; menus whose triggers don't fit collapse into a trailing "More"
 * (ellipsis) trigger listing their items under labels. On compact touch screens menus open as bottom sheets.
 *
 * ```
 * SMenubar() {
 *   SMenubarMenu() {
 *     SMenubarTrigger({ text: 'File' })
 *     SMenubarContent() {
 *       SMenubarItem({ text: 'New Tab', shortcut: '⌘T' }).onClick(() => ...)
 *       SMenubarSeparator()
 *       SMenubarItem({ text: 'Print…', shortcut: '⌘P', onSelect: () => ... })
 *     }
 *   }
 *   SMenubarMenu() {
 *     SMenubarTrigger({ text: 'View' })
 *     SMenubarContent() {
 *       SMenubarCheckboxItem({ text: 'Always Show Bookmarks Bar', checked: this.bookmarks!! })
 *     }
 *   }
 * }
 * ```
 */
@ComponentV2
export struct SMenubar {
  @Param adaptive: SparkAdaptive = 'auto';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local state: SparkMenubarState = new SparkMenubarState();
  @Local moreSheet: boolean = false;
  @Local proxyRects: ProxyRect[] = [];
  @Local proxyWidth: number = 0;
  @Local proxyHeight: number = 0;
  private moreBinding: OverlayBinding = new OverlayBinding();
  private proxy: SparkOverlayScope | undefined = undefined;

  aboutToAppear(): void {
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), BAR_KEY, this.state);
    this.state.onMenuShown = (sheet: boolean) => sheet ? this.hideProxy() : this.showProxy();
    this.state.onAllClosed = () => this.hideProxy();
    const more = this.state.more;
    this.moreBinding.attach(this.getUIContext(), more.disclosure, (scope: SparkOverlayScope) => {
      this.moreSheet = sparkUseSheet(this.adaptive);
      more.handle.sheet = this.moreSheet;
      scope.presentation = this.moreSheet ? 'sheet-bottom' : 'anchored';
      scope.motionKey = 'menu';
      scope.modal = this.moreSheet;
      scope.dismissOnOutside = true;
      scope.anchor = more.disclosure.anchorRect(this.getUIContext());
      scope.side = 'bottom';
      scope.alignment = 'end';
      scope.sideOffset = 8;
      scope.content = this.morePanel;
      scope.contextKey = ITEM_KEY;
      scope.contextValue = more.handle;
      scope.theme = this.theme;
      scope.layout = this.layout;
    });
  }

  aboutToDisappear(): void {
    this.moreBinding.dispose();
    this.hideProxy();
    SparkContext.revoke(this.getUniqueId());
  }

  /**
   * While a menu is open, its layer's outside-tap catcher covers the page, so the bar's triggers no longer
   * see the pointer. A transparent, pass-through layer opened above it re-creates hit areas exactly over
   * the triggers: hovering one switches menus, tapping one toggles it.
   */
  private showProxy(): void {
    this.hideProxy();
    const ui = this.getUIContext();
    const bar = ui.getFrameNodeByUniqueId(this.getUniqueId());
    if (bar === null) {
      return;
    }
    const bp = bar.getPositionToWindowWithTransform();
    const bw = ui.px2vp(bar.getMeasuredSize().width);
    const bh = ui.px2vp(bar.getMeasuredSize().height);
    const rects: ProxyRect[] = [];
    const add = (id: number, m: SparkMenubarMenuState): void => {
      const r = m.disclosure.anchorRect(ui);
      if (r !== undefined && r.width > 0) {
        rects.push(new ProxyRect(id, r.x - bp.x, r.y - bp.y, r.width, r.height));
      }
    };
    this.state.menus.slice(0, this.state.visibleCount).forEach((m: SparkMenubarMenuState) => add(m.id, m));
    if (this.state.hasOverflow) {
      add(MORE_ID, this.state.more);
    }
    this.proxyRects = rects;
    this.proxyWidth = bw;
    this.proxyHeight = bh;
    const scope = SparkOverlayService.createScope();
    scope.presentation = 'anchored';
    scope.motionKey = 'menu';
    scope.modal = false;
    scope.passThrough = true;
    scope.focusable = false;
    scope.dismissOnOutside = false;
    scope.restoreFocusId = '';
    scope.anchor = new PlacementRect(bp.x, bp.y, bw, bh);
    scope.side = 'bottom';
    scope.alignment = 'start';
    // place the (bar-sized) layer exactly over the bar
    scope.sideOffset = -bh;
    scope.content = this.proxyPanel;
    scope.theme = this.theme;
    scope.layout = this.layout;
    this.proxy = scope;
    openSparkOverlay(ui, scope);
  }

  private hideProxy(): void {
    if (this.proxy !== undefined) {
      closeSparkOverlay(this.proxy);
      this.proxy = undefined;
    }
  }

  @LocalBuilder
  proxyPanel() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.proxyRects, (r: ProxyRect) => {
        Column()
          .position({ x: r.x, y: r.y })
          .width(r.w)
          .height(r.h)
          .backgroundColor(Color.Transparent)
          .onHover((h: boolean) => {
            if (h) {
              this.state.hover(r.id);
            }
          })
          .onClick(() => this.state.toggle(r.id))
      }, (r: ProxyRect) => `${r.id}`)
    }
    .width(this.proxyWidth)
    .height(this.proxyHeight)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @LocalBuilder
  morePanel() {
    Column() {
      if (this.moreSheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      ForEach(this.state.hiddenMenus, (m: SparkMenubarMenuState, i: number) => {
        if (i > 0) {
          MenuSeparator()
        }
        MenuLabel({ text: m.label, muted: true })
        MenubarItemsHost({ items: m.items })
      }, (m: SparkMenubarMenuState) => `${m.id}`)
    }
    .width(this.moreSheet ? '100%' : 224)
    .padding(this.moreSheet ? { left: 8, right: 8, top: 8, bottom: 8 + this.layout.env.safeArea.bottom } : 4)
    .backgroundColor(this.theme.colors.popover)
    .border({
      width: this.moreSheet ? { top: 1 } : 1,
      color: this.theme.colors.border,
      radius: this.moreSheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusMd
    })
    .shadow(this.theme.shadows.md.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .alignItems(HorizontalAlign.Start)
    .onKeyEvent((e: KeyEvent) => menubarArrowKeys(this.state, e))
  }

  build() {
    Row() {
      this.content()
      if (this.state.hasOverflow) {
        MenubarMoreTrigger({ bar: this.state })
      }
    }
    .width('100%')
    .height(36)
    .padding(4)
    .backgroundColor(this.theme.colors.background)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
    .shadow(this.theme.shadows.xs.toOptions())
    .onAreaChange((_: Area, n: Area) => this.state.setBarWidth(Number(n.width)))
  }
}

function menubarArrowKeys(bar: SparkMenubarState, e: KeyEvent): void {
  if (e.type !== KeyType.Down) {
    return;
  }
  if (e.keyCode === KEY_LEFT) {
    bar.openAdjacent(-1);
  } else if (e.keyCode === KEY_RIGHT) {
    bar.openAdjacent(1);
  }
}

/** Renders a hidden menu's items inside the "More" menu. */
@ComponentV2
struct MenubarItemsHost {
  @BuilderParam items: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.items()
    }
    .width('100%')
  }
}

@ComponentV2
struct MenubarTriggerLook {
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  @Param active: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Styles
  normalStyle() {
    .backgroundColor(this.active || this.ix.hovered ? this.theme.colors.accent : Color.Transparent)
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.theme.colors.accent)
  }

  build() {
    Row() {
      if (this.icon !== undefined) {
        SIcon({
          name: this.icon,
          sizing: 16,
          color: this.active ? this.theme.colors.accentForeground : this.theme.colors.foreground
        })
      } else {
        Text(this.text)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.active ? this.theme.colors.accentForeground : this.theme.colors.foreground)
          .maxLines(1)
      }
    }
    .height(26)
    .constraintSize({ minWidth: this.icon !== undefined ? MORE_WIDTH : 0 })
    .justifyContent(FlexAlign.Center)
    .padding({ left: 8, right: 8 })
    .borderRadius(this.theme.radiusSm)
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .focusable(true)
    .focusBox(sparkFocusRing(this.theme))
  }
}

/** The trailing ellipsis trigger for menus that don't fit. */
@ComponentV2
struct MenubarMoreTrigger {
  @Param @Require bar: SparkMenubarState;

  aboutToAppear(): void {
    this.bar.more.disclosure.triggerUniqueId = this.getUniqueId();
    this.bar.more.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
  }

  build() {
    Stack() {
      MenubarTriggerLook({ icon: 'ellipsis', active: this.bar.openId === MORE_ID })
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .accessibilityText('More menus')
    .onHover((h: boolean) => {
      if (h) {
        this.bar.hover(MORE_ID);
      }
    })
    .onClick(() => this.bar.toggle(MORE_ID))
  }
}

/** One menu of the bar: a trigger plus its content. */
@ComponentV2
export struct SMenubarMenu {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local menu: SparkMenubarMenuState | undefined = undefined;
  @Local bar: SparkMenubarState | undefined = undefined;

  aboutToAppear(): void {
    this.menu = new SparkMenubarMenuState(this.getUniqueId());
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), MENU_KEY, this.menu);
  }

  aboutToDisappear(): void {
    this.bar?.unregister(this.getUniqueId());
    SparkContext.revoke(this.getUniqueId());
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.bar === undefined && this.menu !== undefined) {
      this.bar = SparkContext.resolve<SparkMenubarState>(this.getUIContext(), this.getUniqueId(), BAR_KEY);
      this.bar?.register(this.menu);
    }
  }

  build() {
    Stack() {
      this.content()
    }
  }
}

/** `rounded-sm px-2 py-1 text-sm font-medium`, accent while its menu is open. */
@ComponentV2
export struct SMenubarTrigger {
  @Param text: ResourceStr = '';
  @Local menu: SparkMenubarMenuState | undefined = undefined;
  @Local bar: SparkMenubarState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.menu === undefined) {
      const menu = SparkContext.resolve<SparkMenubarMenuState>(this.getUIContext(), this.getUniqueId(), MENU_KEY);
      this.bar = SparkContext.resolve<SparkMenubarState>(this.getUIContext(), this.getUniqueId(), BAR_KEY);
      this.menu = menu;
      if (menu !== undefined) {
        menu.label = typeof this.text === 'string' ? this.text : '';
        menu.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
        menu.disclosure.triggerUniqueId = this.getUniqueId();
      }
    }
  }

  @Monitor('text')
  syncText(): void {
    if (this.menu !== undefined) {
      this.menu.label = typeof this.text === 'string' ? this.text : '';
    }
  }

  @Computed
  get hidden(): boolean {
    const m = this.menu;
    const b = this.bar;
    return m !== undefined && b !== undefined && b.indexOf(m.id) >= b.visibleCount;
  }

  @Computed
  get active(): boolean {
    const m = this.menu;
    return m !== undefined && this.bar !== undefined && this.bar.openId === m.id;
  }

  build() {
    Stack() {
      MenubarTriggerLook({ text: this.text, active: this.active })
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .margin({ right: GAP })
    .visibility(this.hidden ? Visibility.None : Visibility.Visible)
    .onAreaChange((_: Area, n: Area) => {
      if (this.menu !== undefined && !this.hidden) {
        this.bar?.setTriggerWidth(this.menu, Number(n.width));
      }
    })
    .onHover((h: boolean) => {
      if (h && this.menu !== undefined) {
        this.bar?.hover(this.menu.id);
      }
    })
    .onClick(() => {
      if (this.menu !== undefined) {
        this.bar?.toggle(this.menu.id);
      }
    })
  }
}

/** The menu's dropdown: `bg-popover min-w-[12rem] rounded-md border p-1 shadow-md`, below its trigger. */
@ComponentV2
export struct SMenubarContent {
  /** panel width in vp (min-w-[12rem] = 192); rows size against it */
  @Param panelWidth: number = 192;
  @Param adaptive: SparkAdaptive = 'auto';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local menu: SparkMenubarMenuState | undefined = undefined;
  @Local bar: SparkMenubarState | undefined = undefined;
  @Local sheet: boolean = false;
  private binding: OverlayBinding = new OverlayBinding();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.menu === undefined) {
      const menu = SparkContext.resolve<SparkMenubarMenuState>(this.getUIContext(), this.getUniqueId(), MENU_KEY);
      this.bar = SparkContext.resolve<SparkMenubarState>(this.getUIContext(), this.getUniqueId(), BAR_KEY);
      this.menu = menu;
      if (menu !== undefined) {
        menu.items = this.itemsOnly;
        this.binding.attach(this.getUIContext(), menu.disclosure, (scope: SparkOverlayScope) => {
          this.sheet = sparkUseSheet(this.adaptive);
          menu.handle.sheet = this.sheet;
          scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
          scope.motionKey = 'menu';
          scope.modal = this.sheet;
          scope.dismissOnOutside = true;
          scope.anchor = menu.disclosure.anchorRect(this.getUIContext());
          scope.side = 'bottom';
          scope.alignment = 'start';
          scope.sideOffset = 8;
          scope.alignOffset = -4;
          scope.content = this.panel;
          scope.contextKey = ITEM_KEY;
          scope.contextValue = menu.handle;
          scope.theme = this.theme;
          scope.layout = this.layout;
        });
      }
    }
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @LocalBuilder
  itemsOnly() {
    this.content()
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      this.content()
    }
    // a definite width: with an auto-width panel, '100%' rows resolve against the overlay layer
    .width(this.sheet ? '100%' : this.panelWidth)
    .padding(this.sheet ? { left: 8, right: 8, top: 8, bottom: 8 + this.layout.env.safeArea.bottom } : 4)
    .backgroundColor(this.theme.colors.popover)
    .border({
      width: this.sheet ? { top: 1 } : 1,
      color: this.theme.colors.border,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusMd
    })
    .shadow(this.theme.shadows.md.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .alignItems(HorizontalAlign.Start)
    .onKeyEvent((e: KeyEvent) => {
      if (this.bar !== undefined) {
        menubarArrowKeys(this.bar, e);
      }
    })
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}

/** Action row; closes the menu after activation (`onSelect` and the native `.onClick()` both fire). */
@ComponentV2
export struct SMenubarItem {
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  @Param shortcut: string | undefined = undefined;
  @Param variant: MenuItemVariant = 'default';
  @Param disabled: boolean = false;
  @Param inset: boolean = false;
  @Param keepOpen: boolean = false;
  @Event onSelect: () => void = () => {
  };

  build() {
    SparkMenuItemPart({
      menuKey: ITEM_KEY,
      text: this.text,
      icon: this.icon,
      shortcut: this.shortcut,
      variant: this.variant,
      disabled: this.disabled,
      inset: this.inset,
      keepOpen: this.keepOpen,
      onSelect: () => this.onSelect()
    })
  }
}

@ComponentV2
export struct SMenubarCheckboxItem {
  @Param text: ResourceStr = '';
  @Param shortcut: string | undefined = undefined;
  @Param checked: boolean | undefined = undefined;
  @Event $checked: (v: boolean) => void = () => {
  };
  @Param defaultChecked: boolean = false;
  @Event onCheckedChange: (v: boolean) => void = () => {
  };
  @Param disabled: boolean = false;

  build() {
    SparkMenuCheckboxPart({
      menuKey: ITEM_KEY,
      text: this.text,
      shortcut: this.shortcut,
      checked: this.checked,
      $checked: (v: boolean) => this.$checked(v),
      defaultChecked: this.defaultChecked,
      onCheckedChange: (v: boolean) => this.onCheckedChange(v),
      disabled: this.disabled
    })
  }
}

@ComponentV2
export struct SMenubarRadioGroup {
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SparkMenuRadioGroupPart({
      menuKey: ITEM_KEY,
      value: this.value,
      $value: (v: string) => this.$value(v),
      defaultValue: this.defaultValue,
      onValueChange: (v: string) => this.onValueChange(v)
    }) {
      this.content()
    }
  }
}

@ComponentV2
export struct SMenubarRadioItem {
  @Param value: string = '';
  @Param text: ResourceStr = '';
  @Param disabled: boolean = false;

  build() {
    SparkMenuRadioPart({ menuKey: ITEM_KEY, value: this.value, text: this.text, disabled: this.disabled })
  }
}

@ComponentV2
export struct SMenubarLabel {
  @Param text: ResourceStr = '';
  @Param inset: boolean = false;

  build() {
    MenuLabel({ text: this.text, inset: this.inset })
  }
}

@ComponentV2
export struct SMenubarSeparator {
  build() {
    MenuSeparator()
  }
}

@ComponentV2
export struct SMenubarGroup {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
  }
}
