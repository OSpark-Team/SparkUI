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

/** Whether the top bar condenses at `width`; `below` overrides the threshold (STopbar `condenseBelow`). */
export function sparkTopbarCondensed(width: number, below: number = TOPBAR_CONDENSED_BELOW): boolean {
  return width > 0 && width < below;
}

/** Top bar height without safe-area inset. */
export function sparkTopbarHeight(condensed: boolean): number {
  return condensed ? 48 : 56;
}

// ------------------------------------------------------------------------------------------------ policies
// Layout decisions are plain functions so apps can replace them (see docs/design/blocks-extensibility.md).
// They receive measured container widths (never window breakpoints) and return a presentation.

/**
 * How a sidebar is presented:
 * - 'docked': in the row, expanded or collapsed (`collapsible`)
 * - 'rail': in the row, forced to the icon rail; the trigger opens the full sidebar as a sheet
 * - 'sheet': out of the row; the trigger opens it as an overlay sheet
 */
export type SidebarPresentation = 'docked' | 'rail' | 'sheet';

/** Input of a {@link SparkSidebarLayoutPolicy}. Widths in vp. */
export interface SparkSidebarLayoutInput {
  /** measured width of the SSidebarProvider (0 = not measured yet) */
  containerWidth: number;
  /** expanded sidebar width */
  sidebarWidth: number;
  /** width of the icon rail */
  railWidth: number;
  /** the main area should keep at least this width */
  minInsetWidth: number;
  collapsible: SidebarCollapsible;
}

/** Decides docked / rail / sheet from the measured container. Replace it to change when the sidebar moves. */
export type SparkSidebarLayoutPolicy = (input: SparkSidebarLayoutInput) => SidebarPresentation;

/** Default policy (shadcn behaviour): docked when the expanded sidebar fits next to `minInsetWidth`, else a sheet. */
export function sparkSidebarDefaultPolicy(input: SparkSidebarLayoutInput): SidebarPresentation {
  return sparkSidebarIsMobile(input.containerWidth, input.sidebarWidth, input.minInsetWidth, input.collapsible) ?
    'sheet' : 'docked';
}

/**
 * Material-style policy factory: docked when the expanded sidebar fits, an icon rail when only the rail fits
 * next to `minRailInsetWidth` of content, a sheet below that. `collapsible: 'none'` always docks.
 */
export function sparkSidebarRailPolicy(minRailInsetWidth: number = 480): SparkSidebarLayoutPolicy {
  return (input: SparkSidebarLayoutInput): SidebarPresentation => {
    if (input.collapsible === 'none' || input.containerWidth <= 0) {
      return 'docked';
    }
    if (input.containerWidth >= input.sidebarWidth + input.minInsetWidth) {
      return 'docked';
    }
    return input.containerWidth >= input.railWidth + minRailInsetWidth ? 'rail' : 'sheet';
  };
}

/**
 * Width the sidebar occupies in the row for a presentation: 0 as a sheet, the icon rail (plus the frame for
 * floating / inset) as a rail, {@link sparkSidebarDockWidth} when docked.
 */
export function sparkSidebarRowWidth(presentation: SidebarPresentation, open: boolean,
  collapsible: SidebarCollapsible, variant: SidebarVariant, sidebarWidth: number): number {
  if (presentation === 'sheet') {
    return 0;
  }
  if (presentation === 'rail') {
    return sparkSidebarDockWidth(false, 'icon', variant, sidebarWidth);
  }
  return sparkSidebarDockWidth(open, collapsible, variant, sidebarWidth);
}

/** Input of a {@link SparkSplitPolicy} (SListDetail, SSupportingPane). Widths in vp. */
export interface SparkSplitInput {
  /** measured container width (0 = not measured yet) */
  containerWidth: number;
  /** width of the fixed pane (list / supporting pane) */
  paneWidth: number;
  /** the other pane should keep at least this width */
  minOtherWidth: number;
}

/** Decides whether two panes sit side by side (true) or collapse to one (false). */
export type SparkSplitPolicy = (input: SparkSplitInput) => boolean;

/** Default SListDetail policy: {@link sparkListDetailWide}. */
export function sparkListDetailDefaultPolicy(input: SparkSplitInput): boolean {
  return sparkListDetailWide(input.containerWidth, input.paneWidth, input.minOtherWidth);
}

/** Default SSupportingPane policy: {@link sparkSupportingWide}. */
export function sparkSupportingDefaultPolicy(input: SparkSplitInput): boolean {
  return sparkSupportingWide(input.containerWidth, input.paneWidth, input.minOtherWidth);
}
