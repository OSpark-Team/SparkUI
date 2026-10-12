import { SparkColor } from '../theme/color/SparkColor';
import { SparkShadow } from '../theme/tokens/SparkShadow';
import { SparkTheme } from '../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../theme/tokens/SparkTokenReader';
import { SIDEBAR_FRAME_GAP, SIDEBAR_WIDTH, SIDEBAR_WIDTH_ICON, SIDEBAR_WIDTH_MOBILE } from './BlocksLogic';
import { SPARK_TITLEBAR_HEIGHT_POINTER, SPARK_TITLEBAR_HEIGHT_TOUCH } from './titlebar/TitleBarLogic';

/*
 * Component tokens of the layout blocks (ADR D13): every block reads
 * **instance `tokens` → theme `--<block>-<prop>` → built-in recipe**, so nothing changes while no token is set.
 * The resolvers are plain functions of the theme (unit-tested in ThemeCss.test.ets); the blocks call them from
 * `@Computed` getters, which re-run when the theme or a component token changes.
 */

// ------------------------------------------------------------------------------------------------ sidebar

/**
 * Per-instance tokens of a sidebar layout (`SSidebarProvider({ tokens })`, `SAppShell({ tokens: { sidebar } })`);
 * every sidebar part inside the provider reads them. Theme tokens: `--sidebar-<prop>` (kebab-case of the field).
 * Base values are the semantic `--sidebar`, `--sidebar-foreground`, `--sidebar-accent(-foreground)`,
 * `--sidebar-border` tokens. Widths are provider props (`sidebarWidth` …, 0 = `--sidebar-width` …).
 */
export interface SidebarTokens {
  /** panel surface (default `--sidebar`; also the frame around an 'inset' main area) */
  background?: string;
  /** panel edge / outline menu buttons / separators (default `--sidebar-border`) */
  borderColor?: string;
  /** panel edge (default `--border-width`) */
  borderWidth?: number;
  /** padding around a floating / inset sidebar and the inset card (default 8) */
  frameGap?: number;
  /** menu button text / icon (default `--sidebar-foreground`) */
  menuForeground?: string;
  menuHoverBackground?: string;
  /** active menu button (default `--sidebar-accent`) */
  menuActiveBackground?: string;
  menuActiveForeground?: string;
  /** rest background of `variant: 'outline'` menu buttons (default `--background`) */
  menuOutlineBackground?: string;
  menuRadius?: number;
  /** menu button heights per `sizing` (default 32 / 28 / 48) */
  menuHeight?: number;
  menuHeightSm?: number;
  menuHeightLg?: number;
  /** opacity of a pressed menu button (default 0.6; pressing never paints a second highlight) */
  menuPressedOpacity?: number;
  /** group label text (default `--sidebar-foreground` at 70%) */
  groupLabelColor?: string;
  /** variant 'floating' panel */
  floatingRadius?: number;
  floatingShadow?: string;
  /** variant 'inset': the main card */
  insetBackground?: string;
  insetRadius?: number;
  insetShadow?: string;
  /** the overlay sheet (narrow / rail) */
  sheetShadow?: string;
}

/** Resolved sidebar look (see {@link sparkSidebarStyle}). */
export class SparkSidebarStyle {
  background: string = '#00000000';
  borderColor: string = '#00000000';
  borderWidth: number = 1;
  frameGap: number = SIDEBAR_FRAME_GAP;
  menuForeground: string = '#00000000';
  menuHoverBackground: string = '#00000000';
  menuActiveBackground: string = '#00000000';
  menuActiveForeground: string = '#00000000';
  menuOutlineBackground: string = '#00000000';
  menuRadius: number = 6;
  menuHeight: number = 32;
  menuHeightSm: number = 28;
  menuHeightLg: number = 48;
  menuPressedOpacity: number = 0.6;
  groupLabelColor: string = '#00000000';
  floatingRadius: number = 8;
  floatingShadow: SparkShadow | undefined = undefined;
  insetBackground: string = '#00000000';
  insetRadius: number = 12;
  insetShadow: SparkShadow | undefined = undefined;
  sheetShadow: SparkShadow | undefined = undefined;
}

const NO_SIDEBAR_TOKENS: SidebarTokens = {};

/** Sidebar recipe: instance tokens → `--sidebar-*` component tokens → the shadcn sidebar look. */
export function sparkSidebarStyle(t: SparkTheme, tokens?: SidebarTokens): SparkSidebarStyle {
  const k = tokens ?? NO_SIDEBAR_TOKENS;
  const c = t.colors;
  const r = new SparkTokenReader(t, 'sidebar');
  const s = new SparkSidebarStyle();
  s.background = r.color('background', k.background, c.sidebar);
  s.borderColor = r.color('border-color', k.borderColor, c.sidebarBorder);
  s.borderWidth = r.len('border-width', k.borderWidth, t.borderWidth);
  s.frameGap = r.len('frame-gap', k.frameGap, SIDEBAR_FRAME_GAP);
  s.menuForeground = r.color('menu-foreground', k.menuForeground, c.sidebarForeground);
  s.menuHoverBackground = r.color('menu-hover-background', k.menuHoverBackground, c.sidebarAccent);
  s.menuActiveBackground = r.color('menu-active-background', k.menuActiveBackground, c.sidebarAccent);
  s.menuActiveForeground = r.color('menu-active-foreground', k.menuActiveForeground, c.sidebarAccentForeground);
  s.menuOutlineBackground = r.color('menu-outline-background', k.menuOutlineBackground, c.background);
  s.menuRadius = r.len('menu-radius', k.menuRadius, t.radiusMd);
  s.menuHeight = r.len('menu-height', k.menuHeight, 32);
  s.menuHeightSm = r.len('menu-height-sm', k.menuHeightSm, 28);
  s.menuHeightLg = r.len('menu-height-lg', k.menuHeightLg, 48);
  s.menuPressedOpacity = r.num('menu-pressed-opacity', k.menuPressedOpacity, 0.6);
  s.groupLabelColor = r.color('group-label-color', k.groupLabelColor, SparkColor.alpha(c.sidebarForeground, 0.7));
  s.floatingRadius = r.len('floating-radius', k.floatingRadius, t.radiusLg);
  s.floatingShadow = r.shadow('floating-shadow', k.floatingShadow, t.shadows.sm);
  s.insetBackground = r.color('inset-background', k.insetBackground, c.background);
  s.insetRadius = r.len('inset-radius', k.insetRadius, t.radiusXl);
  s.insetShadow = r.shadow('inset-shadow', k.insetShadow, t.shadows.sm);
  s.sheetShadow = r.shadow('sheet-shadow', k.sheetShadow, t.shadows.lg);
  return s;
}

/** Docked / sheet / rail widths: a positive prop wins, else `--sidebar-width[-mobile|-icon]`, else shadcn. */
export function sparkSidebarWidth(t: SparkTheme, prop: number): number {
  return new SparkTokenReader(t, 'sidebar').len('width', prop > 0 ? prop : undefined, SIDEBAR_WIDTH);
}

export function sparkSidebarMobileWidth(t: SparkTheme, prop: number): number {
  return new SparkTokenReader(t, 'sidebar').len('width-mobile', prop > 0 ? prop : undefined, SIDEBAR_WIDTH_MOBILE);
}

export function sparkSidebarRailWidth(t: SparkTheme, prop: number): number {
  return new SparkTokenReader(t, 'sidebar').len('width-icon', prop > 0 ? prop : undefined, SIDEBAR_WIDTH_ICON);
}

// ------------------------------------------------------------------------------------------------ top bar

/** Per-instance tokens of an STopbar (theme: `--topbar-<prop>`). */
export interface TopbarTokens {
  /** default `--background` */
  background?: string;
  /** `translucent: true` (default `--background` at 80%) */
  translucentBackground?: string;
  /** backdrop blur radius when translucent (default 20) */
  translucentBlur?: number;
  borderColor?: string;
  /** bottom border when `bordered` (default `--border-width`) */
  borderWidth?: number;
  titleColor?: string;
  subtitleColor?: string;
  /** bar height without the safe-area inset (default 56 / 48 condensed; the `barHeight` prop wins) */
  height?: number;
  heightCondensed?: number;
  paddingX?: number;
  paddingXCondensed?: number;
}

export class SparkTopbarStyle {
  background: string = '#00000000';
  translucentBackground: string = '#00000000';
  translucentBlur: number = 20;
  borderColor: string = '#00000000';
  borderWidth: number = 1;
  titleColor: string = '#00000000';
  subtitleColor: string = '#00000000';
  height: number = 56;
  heightCondensed: number = 48;
  paddingX: number = 16;
  paddingXCondensed: number = 8;
}

const NO_TOPBAR_TOKENS: TopbarTokens = {};

export function sparkTopbarStyle(t: SparkTheme, tokens?: TopbarTokens): SparkTopbarStyle {
  const k = tokens ?? NO_TOPBAR_TOKENS;
  const c = t.colors;
  const r = new SparkTokenReader(t, 'topbar');
  const s = new SparkTopbarStyle();
  s.background = r.color('background', k.background, c.background);
  s.translucentBackground = r.color('translucent-background', k.translucentBackground,
    SparkColor.alpha(s.background, 0.8));
  s.translucentBlur = r.len('translucent-blur', k.translucentBlur, 20);
  s.borderColor = r.color('border-color', k.borderColor, c.border);
  s.borderWidth = r.len('border-width', k.borderWidth, t.borderWidth);
  s.titleColor = r.color('title-color', k.titleColor, c.foreground);
  s.subtitleColor = r.color('subtitle-color', k.subtitleColor, c.mutedForeground);
  s.height = r.len('height', k.height, 56);
  s.heightCondensed = r.len('height-condensed', k.heightCondensed, 48);
  s.paddingX = r.len('padding-x', k.paddingX, 16);
  s.paddingXCondensed = r.len('padding-x-condensed', k.paddingXCondensed, 8);
  return s;
}

// ------------------------------------------------------------------------------------------------ title bar

/** Per-instance tokens of an STitleBar (theme: `--titlebar-<prop>`). */
export interface TitleBarTokens {
  background?: string;
  translucentBackground?: string;
  translucentBlur?: number;
  borderColor?: string;
  borderWidth?: number;
  titleColor?: string;
  /** bar height with a pointer / for touch (default 40 / 48; the `barHeight` prop wins) */
  height?: number;
  heightTouch?: number;
  /** caption button plate height (default: bar height − 12, clamped to 24…32); the plate is 8 vp wider */
  captionSize?: number;
  captionRadius?: number;
  captionForeground?: string;
  captionHoverBackground?: string;
  captionPressedBackground?: string;
  /** the close button (default `--destructive` / `--destructive-foreground`) */
  closeHoverBackground?: string;
  closeHoverForeground?: string;
  closePressedBackground?: string;
}

export class SparkTitleBarStyle {
  background: string = '#00000000';
  translucentBackground: string = '#00000000';
  translucentBlur: number = 20;
  borderColor: string = '#00000000';
  borderWidth: number = 1;
  titleColor: string = '#00000000';
  height: number = SPARK_TITLEBAR_HEIGHT_POINTER;
  heightTouch: number = SPARK_TITLEBAR_HEIGHT_TOUCH;
  /** 0 = derived from the bar height */
  captionSize: number = 0;
  captionRadius: number = 6;
  captionForeground: string = '#00000000';
  captionHoverBackground: string = '#00000000';
  captionPressedBackground: string = '#00000000';
  closeHoverBackground: string = '#00000000';
  closeHoverForeground: string = '#00000000';
  closePressedBackground: string = '#00000000';
}

const NO_TITLEBAR_TOKENS: TitleBarTokens = {};

export function sparkTitleBarStyle(t: SparkTheme, tokens?: TitleBarTokens): SparkTitleBarStyle {
  const k = tokens ?? NO_TITLEBAR_TOKENS;
  const c = t.colors;
  const r = new SparkTokenReader(t, 'titlebar');
  const s = new SparkTitleBarStyle();
  s.background = r.color('background', k.background, c.background);
  s.translucentBackground = r.color('translucent-background', k.translucentBackground,
    SparkColor.alpha(s.background, 0.8));
  s.translucentBlur = r.len('translucent-blur', k.translucentBlur, 20);
  s.borderColor = r.color('border-color', k.borderColor, c.border);
  s.borderWidth = r.len('border-width', k.borderWidth, t.borderWidth);
  s.titleColor = r.color('title-color', k.titleColor, c.foreground);
  s.height = r.len('height', k.height, SPARK_TITLEBAR_HEIGHT_POINTER);
  s.heightTouch = r.len('height-touch', k.heightTouch, SPARK_TITLEBAR_HEIGHT_TOUCH);
  s.captionSize = r.len('caption-size', k.captionSize, 0);
  s.captionRadius = r.len('caption-radius', k.captionRadius, t.radiusMd);
  s.captionForeground = r.color('caption-foreground', k.captionForeground, c.foreground);
  s.captionHoverBackground = r.color('caption-hover-background', k.captionHoverBackground, c.accent);
  s.captionPressedBackground = r.color('caption-pressed-background', k.captionPressedBackground,
    SparkColor.mix(s.captionHoverBackground, c.foreground, 0.08));
  s.closeHoverBackground = r.color('close-hover-background', k.closeHoverBackground, c.destructive);
  s.closeHoverForeground = r.color('close-hover-foreground', k.closeHoverForeground, c.destructiveForeground);
  s.closePressedBackground = r.color('close-pressed-background', k.closePressedBackground,
    SparkColor.alpha(s.closeHoverBackground, 0.85));
  return s;
}

/** Caption plate height: the token / instance value, else bar height − 12 clamped to 24…32. */
export function sparkCaptionPlate(style: SparkTitleBarStyle, barHeight: number): number {
  return style.captionSize > 0 ? style.captionSize : Math.min(32, Math.max(24, barHeight - 12));
}

// ------------------------------------------------------------------------------------------------ app shell

/** Per-instance tokens of an SAppShell: its own (`--app-shell-*`) plus those of the sidebar and top bar it builds. */
export interface AppShellTokens {
  /** max width of the page content (default 1200; the `maxContentWidth` prop wins, 0 = unlimited) */
  contentMaxWidth?: number;
  /** padding around the page content (default: the adaptive gutter, 16 / 24 / 32 by width) */
  contentPadding?: number;
  sidebar?: SidebarTokens;
  topbar?: TopbarTokens;
}

/** Content max width: prop (when set) → instance → `--app-shell-content-max-width` → 1200. */
export function sparkShellMaxWidth(t: SparkTheme, prop: number | undefined, tokens?: AppShellTokens): number {
  if (prop !== undefined) {
    return prop;
  }
  return new SparkTokenReader(t, 'app-shell').len('content-max-width', tokens?.contentMaxWidth, 1200);
}

/** Content padding: instance → `--app-shell-content-padding` → `gutter` (the adaptive default). */
export function sparkShellPadding(t: SparkTheme, gutter: number, tokens?: AppShellTokens): number {
  return new SparkTokenReader(t, 'app-shell').len('content-padding', tokens?.contentPadding, gutter);
}

// ------------------------------------------------------------------------------------------------ list / detail

/** Per-instance tokens of an SListDetail (theme: `--list-detail-<prop>`); the panes read them from the provider. */
export interface ListDetailTokens {
  /** the line between list and detail, and under the detail title bar (default `--border`) */
  dividerColor?: string;
  listBackground?: string;
  detailBackground?: string;
  /** detail title bar height (default 48) */
  headerHeight?: number;
  /** shadow of the detail pushed over the list (narrow; default `--shadow-lg`) */
  detailShadow?: string;
}

export class SparkListDetailStyle {
  dividerColor: string = '#00000000';
  listBackground: string = '#00000000';
  detailBackground: string = '#00000000';
  headerHeight: number = 48;
  detailShadow: SparkShadow | undefined = undefined;
}

const NO_LIST_DETAIL_TOKENS: ListDetailTokens = {};

export function sparkListDetailStyle(t: SparkTheme, tokens?: ListDetailTokens): SparkListDetailStyle {
  const k = tokens ?? NO_LIST_DETAIL_TOKENS;
  const r = new SparkTokenReader(t, 'list-detail');
  const s = new SparkListDetailStyle();
  s.dividerColor = r.color('divider-color', k.dividerColor, t.colors.border);
  s.listBackground = r.color('list-background', k.listBackground, t.colors.background);
  s.detailBackground = r.color('detail-background', k.detailBackground, t.colors.background);
  s.headerHeight = r.len('header-height', k.headerHeight, 48);
  s.detailShadow = r.shadow('detail-shadow', k.detailShadow, t.shadows.lg);
  return s;
}

/** List pane width: a positive prop wins, else `--list-detail-list-width`, else 320. */
export function sparkListWidth(t: SparkTheme, prop: number): number {
  return new SparkTokenReader(t, 'list-detail').len('list-width', prop > 0 ? prop : undefined, 320);
}

// ------------------------------------------------------------------------------------------------ supporting pane

/** Per-instance tokens of an SSupportingPane (theme: `--supporting-pane-<prop>`). */
export interface SupportingPaneTokens {
  dividerColor?: string;
  /** divider between main and aside (default `--border-width`) */
  dividerWidth?: number;
  /** inline aside background (default transparent) */
  background?: string;
  /** bottom-sheet presentation */
  sheetBackground?: string;
  sheetRadius?: number;
  sheetShadow?: string;
  handleBackground?: string;
}

export class SparkSupportingPaneStyle {
  dividerColor: string = '#00000000';
  dividerWidth: number = 1;
  background: string = '#00000000';
  sheetBackground: string = '#00000000';
  sheetRadius: number = 12;
  sheetShadow: SparkShadow | undefined = undefined;
  handleBackground: string = '#00000000';
}

const NO_SUPPORTING_TOKENS: SupportingPaneTokens = {};

export function sparkSupportingPaneStyle(t: SparkTheme, tokens?: SupportingPaneTokens): SparkSupportingPaneStyle {
  const k = tokens ?? NO_SUPPORTING_TOKENS;
  const r = new SparkTokenReader(t, 'supporting-pane');
  const s = new SparkSupportingPaneStyle();
  s.dividerColor = r.color('divider-color', k.dividerColor, t.colors.border);
  s.dividerWidth = r.len('divider-width', k.dividerWidth, t.borderWidth);
  s.background = r.color('background', k.background, '#00000000');
  s.sheetBackground = r.color('sheet-background', k.sheetBackground, t.colors.background);
  s.sheetRadius = r.len('sheet-radius', k.sheetRadius, t.radiusXl);
  s.sheetShadow = r.shadow('sheet-shadow', k.sheetShadow, t.shadows.lg);
  s.handleBackground = r.color('handle-background', k.handleBackground, t.colors.muted);
  return s;
}

/** Pane width: a positive prop wins, else `--supporting-pane-width`, else 320. */
export function sparkSupportingPaneWidth(t: SparkTheme, prop: number): number {
  return new SparkTokenReader(t, 'supporting-pane').len('width', prop > 0 ? prop : undefined, 320);
}

