import { sparkTextOf } from '../../core/SparkText';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkTapBlocker } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SButton } from '../../components/button/SButton';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { closeSparkOverlay, openSparkOverlay } from '../../primitives/overlay/SparkOverlayHost';
import { SparkOverlayScope, SparkOverlayService } from '../../primitives/overlay/SparkOverlay';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import {
  SidebarTokens, sparkSidebarMobileWidth, sparkSidebarRailWidth, SparkSidebarStyle, sparkSidebarStyle,
  sparkSidebarWidth
} from '../BlockTokens';
import {
  SIDEBAR_FRAME_GAP, SIDEBAR_WIDTH, SIDEBAR_WIDTH_ICON, SIDEBAR_WIDTH_MOBILE, SidebarCollapsible,
  SidebarPresentation, SidebarSide, SidebarVariant, sparkSidebarDefaultPolicy, SparkSidebarLayoutInput,
  SparkSidebarLayoutPolicy, sparkSidebarRowWidth, sparkSidebarSheetWidth
} from '../BlocksLogic';

/** SparkContext key of the sidebar state (SSidebarProvider → every sidebar part, STopbar, SAppShell). */
export const SPARK_SIDEBAR_KEY: string = 'spark.sidebar';
/** SparkContext key marking content rendered inside the sidebar's overlay sheet. */
const SPARK_SIDEBAR_SHEET_KEY: string = 'spark.sidebar.sheet';

const TRANSPARENT: string = '#00000000';

export type SidebarMenuButtonSize = 'default' | 'sm' | 'lg';
export type SidebarMenuButtonVariant = 'default' | 'outline';

/**
 * Shared state and controller of a sidebar layout (shadcn `useSidebar()`): presentation (docked / rail /
 * sheet), docked open/collapsed, the sheet, the active value and the configuration.
 *
 * Headless use: create one yourself and pass it as `SSidebarProvider({ controller })` to drive the sidebar
 * from anywhere (keyboard shortcuts, a router, a custom trigger outside the provider) and to read the
 * reactive `@Trace` fields in your own components. Inside a provider, descendants can also get it with
 * {@link resolveSparkSidebar}. Configuration (variant, widths, policy…) still comes from provider props.
 */
@ObservedV2
export class SparkSidebarState {
  /** docked sidebar expanded (shadcn `open`) */
  @Trace open: boolean = true;
  /** overlay sheet shown (shadcn `openMobile`; also the expanded sidebar over a rail) */
  @Trace openMobile: boolean = false;
  /** current presentation, decided by the provider's `layoutPolicy` */
  @Trace presentation: SidebarPresentation = 'docked';
  @Trace variant: SidebarVariant = 'sidebar';
  @Trace collapsible: SidebarCollapsible = 'offcanvas';
  @Trace side: SidebarSide = 'left';
  /** value of the active SSidebarMenuButton */
  @Trace value: string = '';
  /** pad the window safe area (immersive pages) */
  @Trace safeArea: boolean = false;
  /** resolved widths (vp): provider props, else `--sidebar-width` / `-width-mobile` / `-width-icon` */
  @Trace sidebarWidth: number = SIDEBAR_WIDTH;
  @Trace mobileWidth: number = SIDEBAR_WIDTH_MOBILE;
  @Trace railWidth: number = SIDEBAR_WIDTH_ICON;
  /** resolved look (provider `tokens` → `--sidebar-*` tokens → shadcn); every sidebar part reads it */
  @Trace style: SparkSidebarStyle | undefined = undefined;
  /** measured container width (vp) */
  @Trace width: number = 0;
  minInsetWidth: number = 360;
  closeOnSelect: boolean = true;
  /** motion key of the collapse animation and the sheet (`--motion-<key>-*`) */
  motionKey: string = 'sidebar';
  policy: SparkSidebarLayoutPolicy = sparkSidebarDefaultPolicy;
  controlledOpen: boolean = false;
  controlledValue: boolean = false;
  emitOpen: (open: boolean) => void = () => {
  };
  emitValue: (value: string) => void = () => {
  };
  emitNavigate: (value: string) => void = () => {
  };
  emitOpenMobile: (open: boolean) => void = () => {
  };
  emitPresentation: (presentation: SidebarPresentation) => void = () => {
  };
  private uiContext: UIContext | undefined = undefined;
  private theme: SparkTheme = SparkUI.theme;
  private listeners: ((open: boolean) => void)[] = [];

  /** Bind the UI context / theme used for animations (the provider does this). */
  attach(uiContext: UIContext, theme: SparkTheme): void {
    this.uiContext = uiContext;
    this.theme = theme;
  }

  /** The sidebar is out of the row and only reachable as a sheet (shadcn `isMobile`). */
  get mobile(): boolean {
    return this.presentation === 'sheet';
  }

  /** The sidebar is forced to the icon rail by the layout policy. */
  get rail(): boolean {
    return this.presentation === 'rail';
  }

  /** Width the sidebar takes in the row (0 while it is a sheet). */
  get dockWidth(): number {
    return sparkSidebarRowWidth(this.presentation, this.open, this.collapsible, this.variant, this.sidebarWidth,
      this.railWidth, this.frameGap);
  }

  /** Padding around a floating / inset sidebar (`--sidebar-frame-gap`, default 8). */
  get frameGap(): number {
    return this.style?.frameGap ?? SIDEBAR_FRAME_GAP;
  }

  /** In the row but not expanded (collapsed by the user, or a rail). */
  get collapsed(): boolean {
    if (this.presentation === 'rail') {
      return true;
    }
    return this.presentation === 'docked' && !this.open && this.collapsible !== 'none';
  }

  /** Showing the icon rail: labels, badges and group labels hide (except inside the sheet). */
  get iconOnly(): boolean {
    return this.presentation === 'rail' || (this.collapsed && this.collapsible === 'icon');
  }

  /** shadcn `state`: 'expanded' | 'collapsed'. */
  get state(): string {
    return this.collapsed ? 'collapsed' : 'expanded';
  }

  /** The main area is a framed card (variant 'inset' while in the row). */
  get insetFramed(): boolean {
    return this.presentation !== 'sheet' && this.variant === 'inset';
  }

  /** A trigger is useful (the sidebar can collapse, is a rail or a sheet). */
  get toggleable(): boolean {
    return this.presentation !== 'docked' || this.collapsible !== 'none';
  }

  /** Update from the provider's measured width and re-run the layout policy. */
  measure(width: number): void {
    if (width !== this.width) {
      this.width = width;
    }
    this.relayout();
  }

  /** Re-run the layout policy (e.g. after changing something it reads). Presentation switches are instant. */
  relayout(): void {
    const input: SparkSidebarLayoutInput = {
      containerWidth: this.width,
      sidebarWidth: this.sidebarWidth,
      railWidth: this.railWidth,
      minInsetWidth: this.minInsetWidth,
      collapsible: this.collapsible
    };
    const p = this.policy(input);
    if (p !== this.presentation) {
      this.presentation = p;
      if (p === 'docked') {
        this.setOpenMobile(false);
      }
      this.emitPresentation(p);
    }
  }

  /** shadcn `toggleSidebar()`: the sheet when it is a sheet / rail, the docked collapse otherwise. */
  toggle(): void {
    if (this.presentation !== 'docked') {
      this.setOpenMobile(!this.openMobile);
    } else {
      this.setOpen(!this.open);
    }
  }

  /** Request a docked open state (the owner decides when `open` is controlled). */
  setOpen(open: boolean): void {
    if (open === this.open || this.collapsible === 'none') {
      return;
    }
    if (!this.controlledOpen) {
      this.apply(open);
    }
    this.emitOpen(open);
  }

  /** Set the docked state with the width animation (motion key `motionKey`), without events. */
  apply(open: boolean): void {
    if (open === this.open) {
      return;
    }
    const ctx = this.uiContext;
    if (ctx === undefined) {
      this.open = open;
      return;
    }
    SparkAnim.run(ctx, this.theme, this.motionKey, 'normal', () => {
      this.open = open;
    });
  }

  /** Show / hide the overlay sheet (sheet and rail presentations). */
  setOpenMobile(open: boolean): void {
    if (open === this.openMobile) {
      return;
    }
    this.openMobile = open;
    this.listeners.forEach((l: (o: boolean) => void) => l(open));
    this.emitOpenMobile(open);
  }

  /**
   * User activation of a menu value (what SSidebarMenuButton calls). Fires `onNavigate` on every activation
   * and `onValueChange` when the value changes; the highlight switches instantly. Closes the sheet when
   * `closeOnSelect`.
   */
  select(value: string): void {
    if (value.length > 0) {
      const changed = value !== this.value;
      if (changed && !this.controlledValue) {
        this.value = value;
      }
      this.emitNavigate(value);
      if (changed) {
        this.emitValue(value);
      }
    }
    if (this.presentation !== 'docked' && this.closeOnSelect) {
      this.setOpenMobile(false);
    }
  }

  /** Programmatic active value (e.g. from a router), without events. */
  setValue(value: string): void {
    if (value !== this.value) {
      this.value = value;
    }
  }

  /**
   * Back handling for a page's `onBackPress`: closes the sheet and returns true when it was open.
   * (The sheet itself already handles the back gesture while it has focus.)
   */
  back(): boolean {
    if (this.openMobile) {
      this.setOpenMobile(false);
      return true;
    }
    return false;
  }

  /** Listen to `openMobile` changes; returns the unsubscribe function. */
  subscribe(fn: (open: boolean) => void): () => void {
    this.listeners.push(fn);
    return () => {
      this.listeners = this.listeners.filter((l: (o: boolean) => void) => l !== fn);
    };
  }
}

/** Nearest sidebar state of a component (render-tree lookup, call from `onDidBuild` via whenAttached). */
export function resolveSparkSidebar(uiContext: UIContext, componentId: number): SparkSidebarState | undefined {
  return SparkContext.resolve<SparkSidebarState>(uiContext, componentId, SPARK_SIDEBAR_KEY);
}

class SidebarSheetMark {
  sheet: boolean = true;
}

const SHEET_MARK: SidebarSheetMark = new SidebarSheetMark();

/**
 * Whether a component renders inside the sidebar's overlay sheet (rather than the docked panel / rail).
 * Custom menu items use it to keep labels visible in the sheet while the docked sidebar is an icon rail.
 */
export function sparkSidebarInSheet(uiContext: UIContext, componentId: number): boolean {
  return SparkContext.resolve<SidebarSheetMark>(uiContext, componentId, SPARK_SIDEBAR_SHEET_KEY) !== undefined;
}

const FALLBACK: SparkSidebarState = new SparkSidebarState();

/** The provider's resolved look, or the theme's (before the state resolves / outside a provider). */
function sidebarLook(ctx: SparkSidebarState | undefined, theme: SparkTheme): SparkSidebarStyle {
  return ctx?.style ?? sparkSidebarStyle(theme);
}

/** Marks its content as rendered in the sidebar sheet (see sparkSidebarInSheet). */
@ComponentV2
struct SidebarSheetSurface {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  aboutToAppear(): void {
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), SPARK_SIDEBAR_SHEET_KEY, SHEET_MARK);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// ------------------------------------------------------------------------------------------------ provider

/**
 * shadcn-vue `SidebarProvider`: lays out an `SSidebar` and an `SSidebarInset` side by side and owns the
 * sidebar state. Responsive without breakpoints: `layoutPolicy` decides from the provider's own width whether
 * the sidebar is docked, an icon rail or an overlay sheet (default: a sheet when the expanded sidebar does not
 * fit next to `minInsetWidth` of content; `sparkSidebarRailPolicy()` adds the rail step).
 *
 * ```
 * SSidebarProvider({ collapsible: 'icon', value: this.page!!, onNavigate: (v: string) => router.go(v) }) {
 *   SSidebar() {
 *     SSidebarHeader() { ... }
 *     SSidebarContent() {
 *       SSidebarGroup() {
 *         SSidebarGroupLabel({ text: 'Application' })
 *         SSidebarMenu() {
 *           SSidebarMenuItem() { SSidebarMenuButton({ value: 'inbox', icon: 'inbox', text: 'Inbox', badge: '24' }) }
 *         }
 *       }
 *     }
 *     SSidebarFooter() { ... }
 *   }
 *   SSidebarInset() {
 *     STopbar({ title: 'Inbox' })
 *     SPage() { ... }
 *   }
 * }
 * ```
 * Props: `variant` 'sidebar' | 'floating' | 'inset', `collapsible` 'offcanvas' | 'icon' | 'none', `side`
 * 'left' | 'right' (render order is flipped for you). `open` / `defaultOpen` / `onOpenChange` control the
 * docked state (persist it by feeding a stored value to `defaultOpen` and saving in `onOpenChange`);
 * `value` / `defaultValue` / `onValueChange` / `onNavigate` the active menu value (no routing built in: wire
 * any router to `value` + `onNavigate`). `controller` lets you own the state object.
 */
@ComponentV2
export struct SSidebarProvider {
  /** your own state object (headless control); one is created when omitted */
  @Param controller: SparkSidebarState | undefined = undefined;
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = true;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @Param value: string | undefined = undefined;
  @Event $value: (value: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (value: string) => void = () => {
  };
  /** every activation of a menu value, even the current one (router hook: re-tap = pop to root) */
  @Event onNavigate: (value: string) => void = () => {
  };
  /** the overlay sheet opened / closed */
  @Event onOpenMobileChange: (open: boolean) => void = () => {
  };
  /** the layout policy switched between docked / rail / sheet */
  @Event onPresentationChange: (presentation: SidebarPresentation) => void = () => {
  };
  /** decides docked / rail / sheet from the measured width (replaceable) */
  @Event layoutPolicy: SparkSidebarLayoutPolicy = sparkSidebarDefaultPolicy;
  @Param variant: SidebarVariant = 'sidebar';
  @Param collapsible: SidebarCollapsible = 'offcanvas';
  @Param side: SidebarSide = 'left';
  /** docked width (vp); 0 = the `--sidebar-width` token, else 256 (shadcn 16rem) */
  @Param sidebarWidth: number = 0;
  /** sheet width (vp); 0 = the `--sidebar-width-mobile` token, else 288 */
  @Param sidebarWidthMobile: number = 0;
  /** icon rail width (vp); 0 = the `--sidebar-width-icon` token, else 48 */
  @Param sidebarWidthIcon: number = 0;
  /** per-instance look (ADR D13): instance → `--sidebar-*` component tokens → shadcn recipe */
  @Param tokens: SidebarTokens = {};
  /** the main area should keep at least this width (vp); input of `layoutPolicy` */
  @Param minInsetWidth: number = 360;
  /** pad the window safe area (immersive pages, see SparkProvider `immersive`) */
  @Param safeArea: boolean = false;
  /** close the sheet when a menu button is activated */
  @Param closeOnSelect: boolean = true;
  /** motion key of the collapse animation and the sheet */
  @Param motionKey: string = 'sidebar';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkSidebarState = new SparkSidebarState();

  aboutToAppear(): void {
    if (this.controller !== undefined) {
      this.state = this.controller;
    }
    const s = this.state;
    s.attach(this.getUIContext(), this.theme);
    s.controlledOpen = this.open !== undefined;
    if (this.open !== undefined) {
      s.open = this.open;
    } else if (this.controller === undefined) {
      s.open = this.defaultOpen;
    }
    s.controlledValue = this.value !== undefined;
    if (this.value !== undefined) {
      s.value = this.value;
    } else if (this.controller === undefined) {
      s.value = this.defaultValue;
    }
    s.policy = (input: SparkSidebarLayoutInput): SidebarPresentation => this.layoutPolicy(input);
    s.emitOpen = (v: boolean) => {
      this.$open(v);
      this.onOpenChange(v);
    };
    s.emitValue = (v: string) => {
      this.$value(v);
      this.onValueChange(v);
    };
    s.emitNavigate = (v: string) => this.onNavigate(v);
    s.emitOpenMobile = (v: boolean) => this.onOpenMobileChange(v);
    s.emitPresentation = (p: SidebarPresentation) => this.onPresentationChange(p);
    this.syncConfig();
    // first-frame guess from the window; replaced by the provider's own width after layout
    if (s.width <= 0) {
      s.measure(SparkUI.layout.root.width);
    }
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), SPARK_SIDEBAR_KEY, s);
  }

  aboutToDisappear(): void {
    this.state.setOpenMobile(false);
    SparkContext.revoke(this.getUniqueId());
  }

  /** resolved look; re-resolves when the theme, a `--sidebar-*` token or `tokens` changes */
  @Computed
  get look(): SparkSidebarStyle {
    return sparkSidebarStyle(this.theme, this.tokens);
  }

  @Computed
  get resolvedWidth(): number {
    return sparkSidebarWidth(this.theme, this.sidebarWidth);
  }

  @Computed
  get resolvedMobileWidth(): number {
    return sparkSidebarMobileWidth(this.theme, this.sidebarWidthMobile);
  }

  @Computed
  get resolvedRailWidth(): number {
    return sparkSidebarRailWidth(this.theme, this.sidebarWidthIcon);
  }

  @Monitor('variant', 'collapsible', 'side', 'resolvedWidth', 'resolvedMobileWidth', 'resolvedRailWidth', 'look',
    'minInsetWidth', 'safeArea', 'closeOnSelect', 'motionKey')
  syncConfig(): void {
    const s = this.state;
    s.variant = this.variant;
    s.collapsible = this.collapsible;
    s.side = this.side;
    s.sidebarWidth = this.resolvedWidth;
    s.mobileWidth = this.resolvedMobileWidth;
    s.railWidth = this.resolvedRailWidth;
    s.style = this.look;
    s.minInsetWidth = this.minInsetWidth;
    s.safeArea = this.safeArea;
    s.closeOnSelect = this.closeOnSelect;
    s.motionKey = this.motionKey;
    if (s.width > 0) {
      s.relayout();
    }
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.state.apply(this.open);
    }
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.setValue(this.value);
    }
  }

  build() {
    Flex({
      direction: this.state.side === 'right' ? FlexDirection.RowReverse : FlexDirection.Row,
      alignItems: ItemAlign.Stretch
    }) {
      this.content()
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(this.state.insetFramed ? this.look.background : this.theme.colors.background)
    .onAreaChange((_: Area, n: Area) => this.state.measure(Number(n.width)))
  }
}

// ------------------------------------------------------------------------------------------------ sidebar

/**
 * shadcn-vue `Sidebar`. Docked: a column whose width animates between expanded / icon rail / hidden
 * (provider `motionKey`, default 'sidebar'). Rail: the icon rail, plus the full sidebar as a sheet when
 * toggled. Sheet: an overlay sheet from `side` (the SparkUI overlay base, so back
 * gesture, backdrop tap and focus work like SSheet).
 */
@ComponentV2
export struct SSidebar {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkSidebarState | undefined = undefined;
  private scope: SparkOverlayScope | undefined = undefined;
  private unsubscribe: () => void = () => {
  };

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
      this.ctx = ctx;
      if (ctx !== undefined) {
        this.unsubscribe = ctx.subscribe((open: boolean) => open ? this.show() : this.hide());
        if (ctx.openMobile) {
          this.show();
        }
      }
    }
  }

  aboutToDisappear(): void {
    this.unsubscribe();
    this.hide();
  }

  get s(): SparkSidebarState {
    return this.ctx ?? FALLBACK;
  }

  @Computed
  get look(): SparkSidebarStyle {
    return sidebarLook(this.ctx, this.theme);
  }

  private show(): void {
    if (this.scope !== undefined && SparkOverlayService.isOpen(this.scope)) {
      return;
    }
    const ctx = this.ctx;
    if (ctx === undefined || ctx.presentation === 'docked') {
      return;
    }
    const scope = SparkOverlayService.createScope();
    scope.presentation = ctx.side === 'right' ? 'sheet-right' : 'sheet-left';
    scope.motionKey = ctx.motionKey;
    scope.modal = true;
    scope.dismissOnOutside = true;
    scope.content = this.panel;
    // sidebar parts inside the sheet resolve the same state through the overlay host
    scope.contextKey = SPARK_SIDEBAR_KEY;
    scope.contextValue = ctx;
    scope.theme = this.theme;
    scope.layout = this.layout;
    scope.onDismiss = () => ctx.setOpenMobile(false);
    this.scope = scope;
    openSparkOverlay(this.getUIContext(), scope);
  }

  private hide(): void {
    if (this.scope !== undefined) {
      closeSparkOverlay(this.scope);
    }
  }

  /** Mobile sheet panel (rendered in the overlay layer). */
  @LocalBuilder
  panel() {
    Column() {
      // marks the sheet so menu parts keep their labels while the docked sidebar is an icon rail
      SidebarSheetSurface() {
        this.content()
      }
    }
    .width(sparkSidebarSheetWidth(SparkUI.layout.root.width, this.s.mobileWidth))
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: this.layout.env.safeArea.top, bottom: this.layout.env.safeArea.bottom })
    .backgroundColor(this.look.background)
    .border({
      width: this.s.side === 'right' ? { left: this.look.borderWidth } : { right: this.look.borderWidth },
      color: this.look.borderColor
    })
    .shadow(SparkTokenOverride.shadowOptions(this.look.sheetShadow))
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT])
  }

  private framed(): boolean {
    return this.s.variant !== 'sidebar';
  }

  /** Safe-area insets of the docked sidebar (top / bottom / outer edge). */
  private safePadding(extra: number): Padding {
    const sa = this.layout.env.safeArea;
    const on = this.s.safeArea;
    const left = this.s.side === 'left';
    return {
      top: extra + (on ? sa.top : 0),
      bottom: extra + (on ? sa.bottom : 0),
      left: extra + (on && left ? sa.left : 0),
      right: extra + (on && !left ? sa.right : 0)
    };
  }

  private panelBorder(): BorderOptions {
    const s = this.s;
    const l = this.look;
    if (s.variant === 'floating') {
      return { width: l.borderWidth, color: l.borderColor, radius: l.floatingRadius };
    }
    if (s.variant === 'inset') {
      return { width: 0 };
    }
    return {
      width: s.side === 'left' ? { right: l.borderWidth } : { left: l.borderWidth },
      color: l.borderColor
    };
  }

  build() {
    if (this.s.mobile) {
      Column()
        .width(0)
        .height(0)
    } else {
      // outer: animated width + clip; inner frame keeps the full width for 'offcanvas' so it slides out
      Stack({ alignContent: this.s.side === 'left' ? Alignment.TopEnd : Alignment.TopStart }) {
        Column() {
          Column() {
            this.content()
          }
          .width('100%')
          .height('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(this.framed() ? { top: 0 } : this.safePadding(0))
          .backgroundColor(this.s.variant === 'inset' ? TRANSPARENT : this.look.background)
          .border(this.panelBorder())
          .shadow(this.s.variant === 'floating' ? SparkTokenOverride.shadowOptions(this.look.floatingShadow) :
            { radius: 0, color: TRANSPARENT })
          .clip(true)
        }
        .width(this.s.collapsible === 'offcanvas' && this.s.presentation === 'docked' ? this.s.sidebarWidth : '100%')
        .height('100%')
        .padding(this.framed() ? this.safePadding(this.s.frameGap) : { top: 0 })
      }
      .width(this.s.dockWidth)
      .height('100%')
      .clip(true)
    }
  }
}

// ------------------------------------------------------------------------------------------------ sections

/** Top section (brand, team switcher…): `flex flex-col gap-2 p-2`. */
@ComponentV2
export struct SSidebarHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 8 }) {
      this.content()
    }
    .width('100%')
    .padding(8)
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct SSidebarFooter {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 8 }) {
      this.content()
    }
    .width('100%')
    .padding(8)
    .alignItems(HorizontalAlign.Start)
  }
}

/** Scrollable middle section; takes the remaining height between header and footer. */
@ComponentV2
export struct SSidebarContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Scroll() {
      Column() {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}

@ComponentV2
export struct SSidebarGroup {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(8)
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct SSidebarGroupContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** `h-8 px-2 text-xs font-medium text-sidebar-foreground/70`; folds away on the icon rail. */
@ComponentV2
export struct SSidebarGroupLabel {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkSidebarState | undefined = undefined;
  @Local inSheet: boolean = false;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
      this.inSheet = sparkSidebarInSheet(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get hidden(): boolean {
    return !this.inSheet && (this.ctx?.iconOnly ?? false);
  }

  /** `--sidebar-group-label-color` (default sidebar-foreground/70) */
  @Computed
  get labelColor(): string {
    return sidebarLook(this.ctx, this.theme).groupLabelColor;
  }

  build() {
    Row() {
      Text(this.text)
        .fontSize(this.theme.text.xs)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.labelColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Clip })
    }
    .width('100%')
    // height / opacity change inside the sidebar's width animation, so they animate with it
    .height(this.hidden ? 0 : 32)
    .opacity(this.hidden ? 0 : 1)
    .padding({ left: 8, right: 8 })
    .clip(true)
  }
}

@ComponentV2
export struct SSidebarMenu {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 4 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct SSidebarMenuItem {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * shadcn-vue `SidebarMenuButton`: icon + text (+ badge, + trailing slot). Active when `isActive` is true, or
 * when `value` equals the provider's `value`. Activating calls `onSelect`, updates the provider value and
 * closes the mobile sheet. On the icon rail only the icon stays visible (the label is clipped by the
 * animating width).
 *
 * Pressed feedback comes from the system pressed state (SparkRowPressModifier.applyPressedAttribute) and the
 * active highlight switches instantly — never animated.
 */
@ComponentV2
export struct SSidebarMenuButton {
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  /** identifies the button for the provider's `value` */
  @Param value: string = '';
  /** explicit active state (overrides `value` matching) */
  @Param isActive: boolean | undefined = undefined;
  /** short count / label on the trailing edge (shadcn `SidebarMenuBadge`) */
  @Param badge: string | undefined = undefined;
  @Param sizing: SidebarMenuButtonSize = 'default';
  @Param variant: SidebarMenuButtonVariant = 'default';
  @Param disabled: boolean = false;
  @Event onSelect: () => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkSidebarState | undefined = undefined;
  @Local ix: SparkInteraction = new SparkInteraction();
  @Local inSheet: boolean = false;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
      this.inSheet = sparkSidebarInSheet(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get active(): boolean {
    if (this.isActive !== undefined) {
      return this.isActive;
    }
    const c = this.ctx;
    return c !== undefined && this.value.length > 0 && c.value === this.value;
  }

  @Computed
  get iconOnly(): boolean {
    return !this.inSheet && (this.ctx?.iconOnly ?? false);
  }

  /** provider `tokens` → `--sidebar-menu-*` tokens → shadcn */
  @Computed
  get look(): SparkSidebarStyle {
    return sidebarLook(this.ctx, this.theme);
  }

  @Computed
  get fg(): string {
    return this.active ? this.look.menuActiveForeground : this.look.menuForeground;
  }

  @Computed
  get pressMod(): SparkRowPressModifier {
    const l = this.look;
    const rest = this.variant === 'outline' ? l.menuOutlineBackground : TRANSPARENT;
    const bg = this.active ? l.menuActiveBackground : (this.ix.hovered ? l.menuHoverBackground : rest);
    // selection item: pressing fades it, it never paints a second highlight next to the active one
    return new SparkRowPressModifier(bg, bg, l.menuPressedOpacity, this.disabled);
  }

  @Computed
  get blocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  private rowHeight(): number {
    const l = this.look;
    return this.sizing === 'sm' ? l.menuHeightSm : (this.sizing === 'lg' ? l.menuHeightLg : l.menuHeight);
  }

  private activate(): void {
    if (this.disabled) {
      return;
    }
    this.onSelect();
    this.ctx?.select(this.value);
  }

  build() {
    Row({ space: 8 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 16, color: this.fg })
      }
      // icon rail: the label and badge leave the layout (not just clipped), so a rail wider than the
      // shadcn 3rem never shows a truncated "…" and the icon sits centred
      Text(this.text)
        .layoutWeight(1)
        .fontSize(this.sizing === 'sm' ? this.theme.text.xs : this.theme.text.sm)
        .fontWeight(this.active ? this.theme.text.weightMedium : this.theme.text.weightNormal)
        .fontColor(this.fg)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .visibility(this.iconOnly ? Visibility.None : Visibility.Visible)
      if (this.badge !== undefined) {
        Text(this.badge)
          .fontSize(this.theme.text.xs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.fg)
          .maxLines(1)
          .visibility(this.iconOnly ? Visibility.None : Visibility.Visible)
      }
      if (!this.iconOnly) {
        this.content()
      }
    }
    .justifyContent(this.iconOnly ? FlexAlign.Center : FlexAlign.Start)
    .width('100%')
    .height(this.rowHeight())
    .padding({ left: 8, right: 8 })
    .border({
      width: this.variant === 'outline' ? this.look.borderWidth : 0,
      color: this.look.borderColor,
      radius: this.look.menuRadius
    })
    .clip(true)
    // system pressed state only; no .animation() on this chain
    .attributeModifier(this.pressMod)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .gestureModifier(this.blocker)
    .focusable(!this.disabled)
    .onClick(() => this.activate())
    .accessibilityText(typeof this.text === 'string' ? this.text : '')
    .accessibilitySelected(this.active)
  }
}

/** `h-px mx-2 bg-sidebar-border` */
@ComponentV2
export struct SSidebarSeparator {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkSidebarState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => {
      if (this.ctx === undefined) {
        this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
      }
    });
  }

  /** `--sidebar-border-color` (default sidebar-border) */
  @Computed
  get lineColor(): string {
    return sidebarLook(this.ctx, this.theme).borderColor;
  }

  build() {
    Row() {
      Column()
        .height(1)
        .layoutWeight(1)
        .backgroundColor(this.lineColor)
    }
    .width('100%')
    .padding({ left: 8, right: 8 })
  }
}

/**
 * shadcn-vue `SidebarTrigger`: ghost icon button that toggles the sidebar (the sheet when narrow, the
 * docked collapse otherwise). Works anywhere inside the provider (e.g. in STopbar).
 */
@ComponentV2
export struct SSidebarTrigger {
  @Param label: ResourceStr = $r('app.string.spark_toggle_sidebar');
  /** lucide icon; defaults to panel-left / panel-right by side */
  @Param icon: string | undefined = undefined;
  /** toggle this controller instead of the nearest provider (a trigger outside the provider) */
  @Param controller: SparkSidebarState | undefined = undefined;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkSidebarState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Stack() {
      SButton({
        variant: 'ghost',
        sizing: 'icon-sm',
        icon: this.icon ?? ((this.controller ?? this.ctx)?.side === 'right' ? 'panel-right' : 'panel-left'),
        label: sparkTextOf(this.getUIContext(), this.label, 'Toggle Sidebar')
      })
        .onClick(() => (this.controller ?? this.ctx)?.toggle())
    }
  }
}

/**
 * shadcn-vue `SidebarInset`: the main area next to the sidebar. Takes the remaining width; with variant
 * 'inset' it becomes a rounded, raised card inside the sidebar-coloured frame.
 */
@ComponentV2
export struct SSidebarInset {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local ctx: SparkSidebarState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
    }
  }

  get s(): SparkSidebarState {
    return this.ctx ?? FALLBACK;
  }

  @Computed
  get look(): SparkSidebarStyle {
    return sidebarLook(this.ctx, this.theme);
  }

  private frameMargin(): Margin {
    const s = this.s;
    if (!s.insetFramed) {
      return { top: 0 };
    }
    const sa = this.layout.env.safeArea;
    const g = s.frameGap;
    const near = s.dockWidth > 0 ? 0 : g;
    const left = s.side === 'left';
    return {
      top: g + (s.safeArea ? sa.top : 0),
      bottom: g + (s.safeArea ? sa.bottom : 0),
      left: left ? near : g + (s.safeArea ? sa.left : 0),
      right: left ? g + (s.safeArea ? sa.right : 0) : near
    };
  }

  build() {
    Column() {
      this.content()
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .margin(this.frameMargin())
    .backgroundColor(this.s.insetFramed ? this.look.insetBackground : this.theme.colors.background)
    .border({ width: 0, radius: this.s.insetFramed ? this.look.insetRadius : 0 })
    .shadow(this.s.insetFramed ? SparkTokenOverride.shadowOptions(this.look.insetShadow) :
      { radius: 0, color: TRANSPARENT })
    .clip(true)
  }
}
