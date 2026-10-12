import { describe, it, expect } from '@ohos/hypium';
import { sparkGridColumns } from '../main/ets/layout/SparkLayouts';
import { Placement, PlacementRect, PlacementRequest, SparkAlign, SparkSide } from '../main/ets/primitives/overlay/Placement';

function req(side: SparkSide, align: SparkAlign, anchor: PlacementRect, w: number, h: number): PlacementRequest {
  const r = new PlacementRequest();
  r.viewport = new PlacementRect(0, 0, 400, 800);
  r.anchor = anchor;
  r.content = new PlacementRect(0, 0, w, h);
  r.side = side;
  r.alignment = align;
  return r;
}

export default function placementTest() {
  describe('Placement', () => {
    it('bottom_center_default', 0, () => {
      const r = Placement.compute(req('bottom', 'center', new PlacementRect(150, 100, 100, 40), 200, 100));
      expect(r.side).assertEqual('bottom');
      expect(r.x).assertEqual(100);
      expect(r.y).assertEqual(144);
      expect(r.arrowOffset).assertEqual(100);
      expect(r.originY).assertEqual(0);
    });
    it('alignment_start_end_and_rtl', 0, () => {
      const a = new PlacementRect(150, 100, 100, 40);
      expect(Placement.compute(req('bottom', 'start', a, 120, 50)).x).assertEqual(150);
      expect(Placement.compute(req('bottom', 'end', a, 120, 50)).x).assertEqual(130);
      const rtl = req('bottom', 'start', a, 120, 50);
      rtl.rtl = true;
      expect(Placement.compute(rtl).x).assertEqual(130);
    });
    it('flips_when_no_room', 0, () => {
      // anchor near bottom: content flips to top
      const r = Placement.compute(req('bottom', 'center', new PlacementRect(150, 700, 100, 40), 200, 200));
      expect(r.side).assertEqual('top');
      expect(r.y).assertEqual(700 - 4 - 200);
      expect(r.originY).assertEqual(200);
    });
    it('does_not_flip_when_opposite_is_worse', 0, () => {
      const r = Placement.compute(req('bottom', 'center', new PlacementRect(150, 380, 100, 40), 200, 600));
      // bottom: 800-420-12 = 368, top: 380-12 = 368 → equal, stays bottom, clamped inside
      expect(r.side).assertEqual('bottom');
      expect(r.y + 600 <= 792).assertTrue();
    });
    it('shifts_on_cross_axis', 0, () => {
      const r = Placement.compute(req('bottom', 'center', new PlacementRect(0, 100, 40, 40), 200, 100));
      expect(r.x).assertEqual(8);
      // arrow still points at the anchor centre
      expect(r.arrowOffset).assertEqual(12);
    });
    it('left_right_sides', 0, () => {
      const a = new PlacementRect(100, 300, 50, 50);
      const right = Placement.compute(req('right', 'center', a, 100, 80));
      expect(right.side).assertEqual('right');
      expect(right.x).assertEqual(154);
      expect(right.y).assertEqual(285);
      const left = Placement.compute(req('left', 'center', a, 120, 80));
      // only 100-12=88 room on the left, 400-150-12=238 on the right → flips
      expect(left.side).assertEqual('right');
    });
    it('available_space_and_offsets', 0, () => {
      const r0 = req('bottom', 'start', new PlacementRect(50, 100, 100, 40), 200, 100);
      r0.sideOffset = 8;
      r0.alignOffset = 10;
      const r = Placement.compute(r0);
      expect(r.y).assertEqual(148);
      expect(r.x).assertEqual(60);
      expect(r.availableHeight).assertEqual(800 - 140 - 8 - 8);
    });
    it('grid_auto_fill_columns', 0, () => {
      expect(sparkGridColumns(390, 200, 16, 0)).assertEqual(1);
      expect(sparkGridColumns(416, 200, 16, 0)).assertEqual(2);
      expect(sparkGridColumns(415, 200, 16, 0)).assertEqual(1);
      expect(sparkGridColumns(1200, 200, 16, 0)).assertEqual(5);
      expect(sparkGridColumns(1200, 200, 16, 4)).assertEqual(4);
      expect(sparkGridColumns(0, 200, 16, 0)).assertEqual(1);
    });
    it('no_collision_handling_when_disabled', 0, () => {
      const r0 = req('bottom', 'center', new PlacementRect(0, 760, 40, 40), 200, 100);
      r0.avoidCollisions = false;
      const r = Placement.compute(r0);
      expect(r.side).assertEqual('bottom');
      expect(r.x).assertEqual(-80);
    });
  });
}
