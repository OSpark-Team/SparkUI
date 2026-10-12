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
import {
  SIDEBAR_FRAME_GAP, SIDEBAR_WIDTH, SIDEBAR_WIDTH_MOBILE, SidebarCollapsible, SidebarSide, SidebarVariant,
  sparkSidebarDockWidth, sparkSidebarIsMobile, sparkSidebarSheetWidth
} from '../BlocksLogic';

/** SparkContext key of the sidebar state (SSidebarProvider → every sidebar part, STopbar, SAppShell). */
export const SPARK_SIDEBAR_KEY: string = 'spark.sidebar';

const TRANSPARENT: string = '#00000000';

export type SidebarMenuButtonSize = 'default' | 'sm' | 'lg';
export type SidebarMenuButtonVariant = 'default' | 'outline';

/**
 * Shared state of a sidebar layout (shadcn `useSidebar()`): docked open/collapsed, the mobile sheet, the
 * active menu value and the configuration. Read it from any descendant with {@link resolveSparkSidebar}.
 */
@ObservedV2
export class SparkSidebarState {
  /** docked sidebar expanded (shadcn `open`) */
  @Trace open: boolean = true;
  /** overlay sheet shown while the container is narrow (shadcn `openMobile`) */
  @Trace openMobile: boolean = false;
  /** the container is too narrow for a docked sidebar: the sidebar is an overlay sheet */
  @Trace mobile: boolean = false;
  @Trace variant: SidebarVariant = 'sidebar';
  @Trace collapsible: SidebarCollapsible = 'offcanvas';
  @Trace side: SidebarSide = 'left';
  /** value of the active SSidebarMenuButton */
  @Trace value: string = '';
  /** pad the window safe area (immersive pages) */
  @Trace safeArea: boolean = false;
  @Trace sidebarWidth: number = SIDEBAR_WIDTH;
  @Trace mobileWidth: number = SIDEBAR_WIDTH_MOBILE;
  /** measured container width (vp) */
  @Trace width: number = 0;
  minInsetWidth: number = 360;
  closeOnSelect: boolean = true;
  controlledOpen: boolean = false;
  controlledValue: boolean = false;
  emitOpen: (open: boolean) => void = () => {
  };
  emitValue: (value: string) => void = () => {
  };
  private listeners: ((open: boolean) => void)[] = [];

  /** Width the docked sidebar takes in the row (0 while it is an overlay). */
  get dockWidth(): number {
    if (this.mobile) {
      return 0;
    }
    return sparkSidebarDockWidth(this.open, this.collapsible, this.variant, this.sidebarWidth);
  }

  /** Docked and collapsed. */
  get collapsed(): boolean {
    return !this.mobile && !this.open && this.collapsible !== 'none';
  }

  /** Collapsed to the icon rail: labels, badges and group labels hide. */
  get iconOnly(): boolean {
    return this.collapsed && this.collapsible === 'icon';
  }

  /** shadcn `state`: 'expanded' | 'collapsed'. */
  get state(): string {
    return this.collapsed ? 'collapsed' : 'expanded';
  }

  /** The main area is a framed card (variant 'inset' while docked). */
  get insetFramed(): boolean {
    return !this.mobile && this.variant === 'inset';
  }

  /** A trigger is useful (the sidebar can collapse or is an overlay). */
  get toggleable(): boolean {
    return this.mobile || this.collapsible !== 'none';
  }

  /** Update from the provider's measured width. Mode switches are instant (not animated). */
  measure(width: number): void {
    if (width !== this.width) {
      this.width = width;
    }
    const m = sparkSidebarIsMobile(width, this.sidebarWidth, this.minInsetWidth, this.collapsible);
    if (m !== this.mobile) {
      this.mobile = m;
      if (!m) {
        this.setOpenMobile(false);
      }
    }
  }

  /** shadcn `toggleSidebar()`: the sheet when narrow, the docked state otherwise. */
  toggle(ctx: UIContext, theme: SparkTheme): void {
    if (this.mobile) {
      this.setOpenMobile(!this.openMobile);
    } else {
      this.setOpen(ctx, theme, !this.open);
    }
  }

  /** Request a docked open state (owner decides when controlled). */
  setOpen(ctx: UIContext, theme: SparkTheme, open: boolean): void {
    if (open === this.open || this.collapsible === 'none') {
      return;
    }
    if (!this.controlledOpen) {
      this.apply(ctx, theme, open);
    }
    this.emitOpen(open);
  }

  /** Set the docked state with the width animation (motion key 'sidebar'). */
  apply(ctx: UIContext, theme: SparkTheme, open: boolean): void {
    if (open === this.open) {
      return;
    }
    SparkAnim.run(ctx, theme, 'sidebar', 'normal', () => {
      this.open = open;
    });
  }

  setOpenMobile(open: boolean): void {
    if (open === this.openMobile) {
      return;
    }
    this.openMobile = open;
    this.listeners.forEach((l: (o: boolean) => void) => l(open));
  }

  /** Activate a menu value. The highlight switches instantly (no cross-fade between two items). */
  select(value: string): void {
    if (value.length > 0) {
      if (!this.controlledValue) {
        this.value = value;
      }
      this.emitValue(value);
    }
    if (this.mobile && this.closeOnSelect) {
      this.setOpenMobile(false);
    }
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

const FALLBACK: SparkSidebarState = new SparkSidebarState();

// ------------------------------------------------------------------------------------------------ provider

/**
 * shadcn-vue `SidebarProvider`: lays out an `SSidebar` and an `SSidebarInset` side by side and owns the
 * sidebar state. Responsive without breakpoints: when the provider is too narrow to dock the sidebar next to
 * `minInsetWidth` of content, the sidebar becomes an overlay sheet opened by `SSidebarTrigger`.
 *
 * ```
 * SSidebarProvider({ collapsible: 'icon', value: this.page!! }) {
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
 * Props (on the provider, which owns the state): `variant` 'sidebar' | 'floating' | 'inset',
 * `collapsible` 'offcanvas' | 'icon' | 'none', `side` 'left' | 'right' (render order is flipped for you).
 * `open` / `defaultOpen` / `onOpenChange` control the docked state; `value` / `defaultValue` /
 * `onValueChange` the active menu button (an addition to shadcn's per-button `isActive`).
 */
@ComponentV2
export struct SSidebarProvider {
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
  @Param variant: SidebarVariant = 'sidebar';
  @Param collapsible: SidebarCollapsible = 'offcanvas';
  @Param side: SidebarSide = 'left';
  /** docked width (vp), shadcn `--sidebar-width` */
  @Param sidebarWidth: number = SIDEBAR_WIDTH;
  /** sheet width when narrow (vp), shadcn `--sidebar-width-mobile` */
  @Param sidebarWidthMobile: number = SIDEBAR_WIDTH_MOBILE;
  /** the sidebar docks only when the main area keeps at least this width (vp) */
  @Param minInsetWidth: number = 360;
  /** pad the window safe area (immersive pages, see SparkProvider `immersive`) */
  @Param safeArea: boolean = false;
  /** close the mobile sheet when a menu button is activated */
  @Param closeOnSelect: boolean = true;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkSidebarState = new SparkSidebarState();

  aboutToAppear(): void {
    const s = this.state;
    s.controlledOpen = this.open !== undefined;
    s.open = this.open ?? this.defaultOpen;
    s.controlledValue = this.value !== undefined;
    s.value = this.value ?? this.defaultValue;
    this.syncConfig();
    s.emitOpen = (v: boolean) => {
      this.$open(v);
      this.onOpenChange(v);
    };
    s.emitValue = (v: string) => {
      this.$value(v);
      this.onValueChange(v);
    };
    // first-frame guess from the window; replaced by the provider's own width after layout
    s.measure(SparkUI.layout.root.width);
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), SPARK_SIDEBAR_KEY, s);
  }

  aboutToDisappear(): void {
    this.state.setOpenMobile(false);
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('variant', 'collapsible', 'side', 'sidebarWidth', 'sidebarWidthMobile', 'minInsetWidth', 'safeArea',
    'closeOnSelect')
  syncConfig(): void {
    const s = this.state;
    s.variant = this.variant;
    s.collapsible = this.collapsible;
    s.side = this.side;
    s.sidebarWidth = this.sidebarWidth;
    s.mobileWidth = this.sidebarWidthMobile;
    s.minInsetWidth = this.minInsetWidth;
    s.safeArea = this.safeArea;
    s.closeOnSelect = this.closeOnSelect;
    if (s.width > 0) {
      s.measure(s.width);
    }
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.state.apply(this.getUIContext(), this.theme, this.open);
    }
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.value = this.value;
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
    .backgroundColor(this.state.insetFramed ? this.theme.colors.sidebar : this.theme.colors.background)
    .onAreaChange((_: Area, n: Area) => this.state.measure(Number(n.width)))
  }
}

// ------------------------------------------------------------------------------------------------ sidebar

/**
 * shadcn-vue `Sidebar`. Docked: a column whose width animates between expanded / icon rail / hidden
 * (motion key 'sidebar'). Narrow container: an overlay sheet from `side` (the SparkUI overlay base, so back
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

  private show(): void {
    if (this.scope !== undefined && SparkOverlayService.isOpen(this.scope)) {
      return;
    }
    const ctx = this.ctx;
    if (ctx === undefined) {
      return;
    }
    const scope = SparkOverlayService.createScope();
    scope.presentation = ctx.side === 'right' ? 'sheet-right' : 'sheet-left';
    scope.motionKey = 'sidebar';
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
      this.content()
    }
    .width(sparkSidebarSheetWidth(SparkUI.layout.root.width, this.s.mobileWidth))
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: this.layout.env.safeArea.top, bottom: this.layout.env.safeArea.bottom })
    .backgroundColor(this.theme.colors.sidebar)
    .border({
      width: this.s.side === 'right' ? { left: 1 } : { right: 1 },
      color: this.theme.colors.sidebarBorder
    })
    .shadow(this.theme.shadows.lg.toOptions())
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
    if (s.variant === 'floating') {
      return { width: 1, color: this.theme.colors.sidebarBorder, radius: this.theme.radiusLg };
    }
    if (s.variant === 'inset') {
      return { width: 0 };
    }
    return {
      width: s.side === 'left' ? { right: 1 } : { left: 1 },
      color: this.theme.colors.sidebarBorder
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
          .backgroundColor(this.s.variant === 'inset' ? TRANSPARENT : this.theme.colors.sidebar)
          .border(this.panelBorder())
          .shadow(this.s.variant === 'floating' ? this.theme.shadows.sm.toOptions() :
            { radius: 0, color: TRANSPARENT })
          .clip(true)
        }
        .width(this.s.collapsible === 'offcanvas' ? this.s.sidebarWidth : '100%')
        .height('100%')
        .padding(this.framed() ? this.safePadding(SIDEBAR_FRAME_GAP) : { top: 0 })
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

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get hidden(): boolean {
    return this.ctx?.iconOnly ?? false;
  }

  build() {
    Row() {
      Text(this.text)
        .fontSize(this.theme.text.xs)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.sidebarForeground)
        .opacity(0.7)
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

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveSparkSidebar(this.getUIContext(), this.getUniqueId());
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
    return this.ctx?.iconOnly ?? false;
  }

  @Computed
  get fg(): string {
    return this.active ? this.theme.colors.sidebarAccentForeground : this.theme.colors.sidebarForeground;
  }

  @Computed
  get pressMod(): SparkRowPressModifier {
    const accent = this.theme.colors.sidebarAccent;
    const rest = this.variant === 'outline' ? this.theme.colors.background : TRANSPARENT;
    return new SparkRowPressModifier(this.active || this.ix.hovered ? accent : rest, accent, 1, this.disabled);
  }

  @Computed
  get blocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  private rowHeight(): number {
    return this.sizing === 'sm' ? 28 : (this.sizing === 'lg' ? 48 : 32);
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
      Text(this.text)
        .layoutWeight(1)
        .fontSize(this.sizing === 'sm' ? this.theme.text.xs : this.theme.text.sm)
        .fontWeight(this.active ? this.theme.text.weightMedium : this.theme.text.weightNormal)
        .fontColor(this.fg)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.badge !== undefined) {
        Text(this.badge)
          .fontSize(this.theme.text.xs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.fg)
          .maxLines(1)
          .opacity(this.iconOnly ? 0 : 1)
      }
      this.content()
    }
    .width('100%')
    .height(this.rowHeight())
    .padding({ left: 8, right: 8 })
    .border({
      width: this.variant === 'outline' ? 1 : 0,
      color: this.theme.colors.sidebarBorder,
      radius: this.theme.radiusMd
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

  build() {
    Row() {
      Column()
        .height(1)
        .layoutWeight(1)
        .backgroundColor(this.theme.colors.sidebarBorder)
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
  @Param label: string = 'Toggle Sidebar';
  /** lucide icon; defaults to panel-left / panel-right by side */
  @Param icon: string | undefined = undefined;
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
        icon: this.icon ?? (this.ctx?.side === 'right' ? 'panel-right' : 'panel-left'),
        label: this.label
      })
        .onClick(() => this.ctx?.toggle(this.getUIContext(), this.theme))
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

  private frameMargin(): Margin {
    const s = this.s;
    if (!s.insetFramed) {
      return { top: 0 };
    }
    const sa = this.layout.env.safeArea;
    const g = SIDEBAR_FRAME_GAP;
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
    .backgroundColor(this.theme.colors.background)
    .border({ width: 0, radius: this.s.insetFramed ? this.theme.radiusXl : 0 })
    .shadow(this.s.insetFramed ? this.theme.shadows.sm.toOptions() : { radius: 0, color: TRANSPARENT })
    .clip(true)
  }
}
