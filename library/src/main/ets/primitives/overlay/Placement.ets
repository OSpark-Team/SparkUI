/**
 * Anchored placement (floating-ui style): side + alignment + offsets, with flip and shift collision
 * handling. Pure and unit-tested; all values in vp, window coordinates.
 */
export type SparkSide = 'top' | 'right' | 'bottom' | 'left';
export type SparkAlign = 'start' | 'center' | 'end';

export class PlacementRect {
  x: number;
  y: number;
  width: number;
  height: number;

  constructor(x: number, y: number, width: number, height: number) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

export class PlacementRequest {
  anchor: PlacementRect = new PlacementRect(0, 0, 0, 0);
  /** measured content size (width/height used) */
  content: PlacementRect = new PlacementRect(0, 0, 0, 0);
  /** usable area (window minus safe area / keyboard) */
  viewport: PlacementRect = new PlacementRect(0, 0, 0, 0);
  side: SparkSide = 'bottom';
  alignment: SparkAlign = 'center';
  /** gap between anchor and content (shadcn sideOffset, default 4) */
  sideOffset: number = 4;
  alignOffset: number = 0;
  /** minimum distance kept from the viewport edges */
  collisionPadding: number = 8;
  avoidCollisions: boolean = true;
  rtl: boolean = false;
}

export class PlacementResult {
  x: number = 0;
  y: number = 0;
  /** side actually used after flipping */
  side: SparkSide = 'bottom';
  /** anchor centre along the cross axis, relative to the content box (for arrows) */
  arrowOffset: number = 0;
  /** space available on the chosen side (for max-height / max-width of scrollable content) */
  availableWidth: number = 0;
  availableHeight: number = 0;
  /** transform origin for enter/exit animations, in content-local coordinates */
  originX: number = 0;
  originY: number = 0;
}

function opposite(side: SparkSide): SparkSide {
  switch (side) {
    case 'top':
      return 'bottom';
    case 'bottom':
      return 'top';
    case 'left':
      return 'right';
    default:
      return 'left';
  }
}

function isVertical(side: SparkSide): boolean {
  return side === 'top' || side === 'bottom';
}

/** Space between the anchor and the viewport edge on `side`, minus padding and offset. */
function spaceOn(r: PlacementRequest, side: SparkSide): number {
  const v = r.viewport;
  const a = r.anchor;
  const pad = r.collisionPadding + r.sideOffset;
  switch (side) {
    case 'top':
      return a.y - v.y - pad;
    case 'bottom':
      return v.y + v.height - (a.y + a.height) - pad;
    case 'left':
      return a.x - v.x - pad;
    default:
      return v.x + v.width - (a.x + a.width) - pad;
  }
}

function mainPos(r: PlacementRequest, side: SparkSide): number {
  const a = r.anchor;
  const c = r.content;
  switch (side) {
    case 'top':
      return a.y - r.sideOffset - c.height;
    case 'bottom':
      return a.y + a.height + r.sideOffset;
    case 'left':
      return a.x - r.sideOffset - c.width;
    default:
      return a.x + a.width + r.sideOffset;
  }
}

function crossPos(r: PlacementRequest, side: SparkSide): number {
  const a = r.anchor;
  const c = r.content;
  const vertical = isVertical(side);
  const aStart = vertical ? a.x : a.y;
  const aSize = vertical ? a.width : a.height;
  const cSize = vertical ? c.width : c.height;
  let align = r.alignment;
  if (vertical && r.rtl && align !== 'center') {
    align = align === 'start' ? 'end' : 'start';
  }
  let pos: number;
  if (align === 'start') {
    pos = aStart + r.alignOffset;
  } else if (align === 'end') {
    pos = aStart + aSize - cSize - r.alignOffset;
  } else {
    pos = aStart + (aSize - cSize) / 2 + r.alignOffset;
  }
  return pos;
}

function clamp(v: number, lo: number, hi: number): number {
  if (hi < lo) {
    return lo;
  }
  return Math.min(Math.max(v, lo), hi);
}

export class Placement {
  static compute(r: PlacementRequest): PlacementResult {
    let side = r.side;
    const need = isVertical(side) ? r.content.height : r.content.width;
    if (r.avoidCollisions && spaceOn(r, side) < need) {
      const alt = opposite(side);
      if (spaceOn(r, alt) > spaceOn(r, side)) {
        side = alt;
      }
    }
    const vertical = isVertical(side);
    let main = mainPos(r, side);
    let cross = crossPos(r, side);
    const v = r.viewport;
    const pad = r.collisionPadding;
    if (r.avoidCollisions) {
      // shift along the cross axis to stay inside the viewport
      if (vertical) {
        cross = clamp(cross, v.x + pad, v.x + v.width - pad - r.content.width);
      } else {
        cross = clamp(cross, v.y + pad, v.y + v.height - pad - r.content.height);
      }
      // keep the main axis inside too when neither side fits (content then needs max size)
      if (vertical) {
        main = clamp(main, v.y + pad, v.y + v.height - pad - r.content.height);
      } else {
        main = clamp(main, v.x + pad, v.x + v.width - pad - r.content.width);
      }
    }
    const res = new PlacementResult();
    res.side = side;
    res.x = vertical ? cross : main;
    res.y = vertical ? main : cross;
    const anchorCenter = vertical ? r.anchor.x + r.anchor.width / 2 : r.anchor.y + r.anchor.height / 2;
    const contentStart = vertical ? res.x : res.y;
    const contentSize = vertical ? r.content.width : r.content.height;
    res.arrowOffset = clamp(anchorCenter - contentStart, 0, contentSize);
    res.availableHeight = vertical ? Math.max(0, spaceOn(r, side)) : Math.max(0, v.height - pad * 2);
    res.availableWidth = vertical ? Math.max(0, v.width - pad * 2) : Math.max(0, spaceOn(r, side));
    // animation origin: the edge facing the anchor, at the anchor centre
    if (vertical) {
      res.originX = res.arrowOffset;
      res.originY = side === 'bottom' ? 0 : r.content.height;
    } else {
      res.originX = side === 'right' ? 0 : r.content.width;
      res.originY = res.arrowOffset;
    }
    return res;
  }
}
