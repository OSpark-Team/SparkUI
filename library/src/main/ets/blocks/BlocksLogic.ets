/**
 * Pure layout maths of the layout blocks (SSidebar, SListDetail, SSupportingPane, STopbar). Kept free of
 * ArkUI types so it can be unit-tested (library/src/test/Blocks.test.ets).
 */

export type SidebarVariant = 'sidebar' | 'floating' | 'inset';
export type SidebarCollapsible = 'offcanvas' | 'icon' | 'none';
export type SidebarSide = 'left' | 'right';

/** shadcn `--sidebar-width` (16rem). */
export const SIDEBAR_WIDTH: number = 256;
/** shadcn `--sidebar-width-mobile` (18rem). */
export const SIDEBAR_WIDTH_MOBILE: number = 288;
/** shadcn `--sidebar-width-icon` (3rem). */
export const SIDEBAR_WIDTH_ICON: number = 48;
/** Padding around a floating / inset sidebar (shadcn `p-2`). */
export const SIDEBAR_FRAME_GAP: number = 8;

/**
 * Width the docked sidebar occupies in the row (vp).
 * - expanded: `sidebarWidth`
 * - collapsed `icon`: 48, plus the 8 vp frame on both sides for floating / inset (shadcn `3rem + spacing*4`)
 * - collapsed `offcanvas`: 0 (slides out)
 * - `none`: never collapses
 */
export function sparkSidebarDockWidth(open: boolean, collapsible: SidebarCollapsible, variant: SidebarVariant,
  sidebarWidth: number): number {
  if (open || collapsible === 'none') {
    return sidebarWidth;
  }
  if (collapsible === 'icon') {
    return variant === 'sidebar' ? SIDEBAR_WIDTH_ICON : SIDEBAR_WIDTH_ICON + SIDEBAR_FRAME_GAP * 2;
  }
  return 0;
}

/**
 * Whether the sidebar should leave the row and become an overlay sheet: true when the container cannot hold
 * the expanded sidebar and still give the main area `minInsetWidth`. Not used for `collapsible: 'none'`
 * (a static sidebar, as in shadcn). A width of 0 means "not measured yet" and keeps the docked layout.
 */
export function sparkSidebarIsMobile(containerWidth: number, sidebarWidth: number, minInsetWidth: number,
  collapsible: SidebarCollapsible): boolean {
  if (collapsible === 'none' || containerWidth <= 0) {
    return false;
  }
  return containerWidth < sidebarWidth + minInsetWidth;
}

/** Mobile sheet width: `sidebarWidthMobile`, never more than 85% of the window. */
export function sparkSidebarSheetWidth(windowWidth: number, mobileWidth: number): number {
  if (windowWidth <= 0) {
    return mobileWidth;
  }
  return Math.min(mobileWidth, Math.floor(windowWidth * 0.85));
}

/** Master / detail fit side by side when the detail still gets `minDetailWidth` next to the list. */
export function sparkListDetailWide(width: number, listWidth: number, minDetailWidth: number): boolean {
  if (width <= 0) {
    return false;
  }
  return width >= listWidth + 1 + minDetailWidth;
}

/** Width of the list pane: fixed when side by side (clamped to 45% of the width), full otherwise. */
export function sparkListPaneWidth(width: number, listWidth: number, wide: boolean): number {
  if (!wide) {
    return width;
  }
  return Math.min(listWidth, Math.floor(width * 0.45));
}

/** Main + supporting pane fit side by side when the main area still gets `minMainWidth`. */
export function sparkSupportingWide(width: number, paneWidth: number, minMainWidth: number): boolean {
  if (width <= 0) {
    return false;
  }
  return width >= paneWidth + minMainWidth;
}

/** The top bar condenses (smaller height, search behind an icon) below this width (vp). */
export const TOPBAR_CONDENSED_BELOW: number = 520;

export function sparkTopbarCondensed(width: number): boolean {
  return width > 0 && width < TOPBAR_CONDENSED_BELOW;
}

/** Top bar height without safe-area inset. */
export function sparkTopbarHeight(condensed: boolean): number {
  return condensed ? 48 : 56;
}
