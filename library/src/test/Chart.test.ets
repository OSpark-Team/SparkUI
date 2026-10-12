import { describe, it, expect } from '@ohos/hypium';
import {
  SparkArc, sparkArcIndex, sparkArcPath, sparkAreaPath, SparkBandScale, sparkChartCompact, sparkChartFormat,
  sparkCirclePath, sparkCurvePath, sparkLabelStep, SparkLinearScale, sparkMonotoneTangents, sparkNearestIndex,
  sparkNiceDomain, sparkNiceTicks, sparkPieArcs, sparkPointPositions, sparkPolar, sparkRingIndex,
  sparkRoundRectPath, sparkShapeCommands, sparkShapeLine, sparkShapeRects, sparkSpokeIndex, sparkStack,
  sparkTickCount, sparkTickStep, sparkTooltipPlace, sparkValueDomain
} from '../main/ets/components/chart/ChartMath';

function near(a: number, b: number): boolean {
  return Math.abs(a - b) < 1e-6;
}

function joined(v: number[]): string {
  return v.join(',');
}

export default function chartTest() {
  describe('ChartMath ticks', () => {
    it('tick_step_is_1_2_5', 0, () => {
      expect(sparkTickStep(0, 10, 5)).assertEqual(2);
      expect(sparkTickStep(0, 100, 5)).assertEqual(20);
      expect(sparkTickStep(0, 1, 10)).assertEqual(0.1);
      expect(sparkTickStep(0, 305, 5)).assertEqual(50);
      expect(sparkTickStep(0, 0, 5)).assertEqual(0);
    });
    it('nice_ticks_like_d3', 0, () => {
      expect(joined(sparkNiceTicks(0, 10, 5))).assertEqual('0,2,4,6,8,10');
      expect(joined(sparkNiceTicks(0, 1, 5))).assertEqual('0,0.2,0.4,0.6,0.8,1');
      expect(joined(sparkNiceTicks(-12, 37, 5))).assertEqual('-10,0,10,20,30');
      expect(joined(sparkNiceTicks(0.1, 0.3, 4))).assertEqual('0.1,0.15,0.2,0.25,0.3');
    });
    it('nice_domain_extends_to_ticks', 0, () => {
      expect(joined(sparkNiceDomain(0, 305, 5))).assertEqual('0,350');
      expect(joined(sparkNiceDomain(3, 97, 5))).assertEqual('0,100');
      expect(joined(sparkNiceDomain(-7, 13, 4))).assertEqual('-10,15');
    });
    it('degenerate_domains', 0, () => {
      expect(joined(sparkNiceDomain(0, 0, 5))).assertEqual('0,1');
      expect(joined(sparkNiceDomain(5, 5, 5))).assertEqual('0,5');
      expect(joined(sparkNiceDomain(-4, -4, 4))).assertEqual('-4,0');
      expect(joined(sparkValueDomain([], true, 5))).assertEqual('0,1');
    });
    it('value_domain_includes_zero', 0, () => {
      expect(joined(sparkValueDomain([186, 305, 237, 73], true, 5))).assertEqual('0,350');
      expect(joined(sparkValueDomain([120, 180], false, 4))).assertEqual('120,180');
    });
    it('tick_count_and_label_step', 0, () => {
      expect(sparkTickCount(200, 48, 2, 6)).assertEqual(4);
      expect(sparkTickCount(20, 48, 2, 6)).assertEqual(2);
      expect(sparkTickCount(1000, 48, 2, 6)).assertEqual(6);
      expect(sparkLabelStep(12, 600, 40)).assertEqual(1);
      expect(sparkLabelStep(12, 240, 40)).assertEqual(2);
      expect(sparkLabelStep(1, 10, 40)).assertEqual(1);
    });
    it('formats_numbers', 0, () => {
      expect(sparkChartFormat(1234.5)).assertEqual('1,234.5');
      expect(sparkChartFormat(1000000)).assertEqual('1,000,000');
      expect(sparkChartFormat(-42.125, 2)).assertEqual('-42.13');
      expect(sparkChartFormat(0.1 + 0.2)).assertEqual('0.3');
      expect(sparkChartCompact(950)).assertEqual('950');
      expect(sparkChartCompact(1250)).assertEqual('1.3k');
      expect(sparkChartCompact(3400000)).assertEqual('3.4M');
    });
  });

  describe('ChartMath scales', () => {
    it('linear_scale_maps_and_inverts', 0, () => {
      const s = new SparkLinearScale(0, 100, 200, 0);
      expect(s.map(0)).assertEqual(200);
      expect(s.map(25)).assertEqual(150);
      expect(s.invert(150)).assertEqual(25);
      expect(s.mapClamped(-50)).assertEqual(200);
      expect(new SparkLinearScale(5, 5, 0, 10).map(5)).assertEqual(5);
    });
    it('band_scale_like_d3', 0, () => {
      const b = new SparkBandScale(4, 0, 100, 0.2, 0.1);
      // step = 100 / (4 - 0.2 + 0.2) = 25
      expect(near(b.step, 25)).assertTrue();
      expect(near(b.bandwidth, 20)).assertTrue();
      expect(near(b.start(0), 2.5)).assertTrue();
      expect(near(b.center(3), 2.5 + 75 + 10)).assertTrue();
      expect(b.centers().length).assertEqual(4);
    });
    it('point_positions', 0, () => {
      expect(joined(sparkPointPositions(3, 0, 100))).assertEqual('0,50,100');
      expect(joined(sparkPointPositions(1, 0, 100))).assertEqual('50');
      expect(sparkPointPositions(0, 0, 100).length).assertEqual(0);
    });
    it('nearest_index', 0, () => {
      const p = [0, 50, 100, 150];
      expect(sparkNearestIndex(p, -20)).assertEqual(0);
      expect(sparkNearestIndex(p, 74)).assertEqual(1);
      expect(sparkNearestIndex(p, 76)).assertEqual(2);
      expect(sparkNearestIndex(p, 999)).assertEqual(3);
      expect(sparkNearestIndex([], 5)).assertEqual(-1);
    });
  });

  describe('ChartMath stacking and polar', () => {
    it('stack_positive_and_negative', 0, () => {
      const st = sparkStack([[1, 2, -1], [3, -4, -2]]);
      expect(joined(st.lower[0])).assertEqual('0,0,-1');
      expect(joined(st.upper[0])).assertEqual('1,2,0');
      expect(joined(st.lower[1])).assertEqual('1,-4,-3');
      expect(joined(st.upper[1])).assertEqual('4,0,-1');
    });
    it('pie_arcs_cover_the_circle', 0, () => {
      const arcs: SparkArc[] = sparkPieArcs([1, 1, 2], 0, Math.PI * 2, 0);
      expect(near(arcs[0].a0, 0)).assertTrue();
      expect(near(arcs[0].a1, Math.PI / 2)).assertTrue();
      expect(near(arcs[2].a0, Math.PI)).assertTrue();
      expect(near(arcs[2].a1, Math.PI * 2)).assertTrue();
    });
    it('pie_arcs_padding_and_zero', 0, () => {
      const arcs = sparkPieArcs([1, 0, 1], 0, Math.PI * 2, 0.2);
      expect(near(arcs[1].a1 - arcs[1].a0, 0)).assertTrue();
      expect(near(arcs[0].a0, 0.1)).assertTrue();
      expect(near(arcs[2].a1, Math.PI * 2 - 0.1)).assertTrue();
      expect(near(arcs[0].a1 - arcs[0].a0, arcs[2].a1 - arcs[2].a0)).assertTrue();
      const none = sparkPieArcs([0, 0], 0, Math.PI * 2, 0);
      expect(near(none[1].a1, 0)).assertTrue();
    });
    it('polar_coordinates_clockwise_from_top', 0, () => {
      const top = sparkPolar(0, 0, 10, 0);
      const right = sparkPolar(0, 0, 10, Math.PI / 2);
      expect(near(top[0], 0) && near(top[1], -10)).assertTrue();
      expect(near(right[0], 10) && near(right[1], 0)).assertTrue();
    });
    it('arc_hit_testing', 0, () => {
      const arcs = sparkPieArcs([1, 1, 1, 1], 0, Math.PI * 2, 0);
      expect(sparkArcIndex(arcs, 50, 50, 0, 40, 70, 30, 0)).assertEqual(0); // upper right
      expect(sparkArcIndex(arcs, 50, 50, 0, 40, 70, 70, 0)).assertEqual(1); // lower right
      expect(sparkArcIndex(arcs, 50, 50, 0, 40, 30, 70, 0)).assertEqual(2);
      expect(sparkArcIndex(arcs, 50, 50, 0, 40, 30, 30, 0)).assertEqual(3);
      expect(sparkArcIndex(arcs, 50, 50, 20, 40, 52, 52, 0)).assertEqual(-1); // in the hole
      expect(sparkArcIndex(arcs, 50, 50, 0, 40, 99, 50, 0)).assertEqual(-1); // outside
    });
    it('spoke_and_ring_index', 0, () => {
      expect(sparkSpokeIndex(0, 0, 4, 0, -10)).assertEqual(0);
      expect(sparkSpokeIndex(0, 0, 4, 10, 1)).assertEqual(1);
      expect(sparkSpokeIndex(0, 0, 4, -1, -10)).assertEqual(0);
      expect(sparkRingIndex(3, 10, 40, 15)).assertEqual(0);
      expect(sparkRingIndex(3, 10, 40, 39)).assertEqual(2);
      expect(sparkRingIndex(3, 10, 40, 5)).assertEqual(-1);
    });
    it('tooltip_flips_and_clamps', 0, () => {
      expect(joined(sparkTooltipPlace(10, 50, 100, 40, 300, 200, 12))).assertEqual('22,30');
      expect(joined(sparkTooltipPlace(250, 50, 100, 40, 300, 200, 12))).assertEqual('138,30');
      expect(joined(sparkTooltipPlace(50, 190, 100, 40, 120, 200, 12))).assertEqual('0,160');
    });
  });

  describe('ChartMath paths', () => {
    it('linear_and_step_paths', 0, () => {
      expect(sparkCurvePath([0, 10, 20], [5, 0, 5], 'linear', 1, true)).assertEqual('M0 5 L10 0 L20 5');
      expect(sparkCurvePath([0, 10], [5, 0], 'step', 1, true)).assertEqual('M0 5 L5 5 L5 0 L10 0');
      expect(sparkCurvePath([0, 10], [5, 0], 'linear', 2, false)).assertEqual('L0 10 L20 0');
    });
    it('monotone_keeps_monotonic_data_monotonic', 0, () => {
      const t = sparkMonotoneTangents([0, 1, 2, 3], [0, 1, 1, 2]);
      expect(t[2]).assertEqual(0); // flat neighbour → zero tangent, no overshoot
      expect(t[1]).assertEqual(0);
      const p = sparkCurvePath([0, 3, 6], [0, 3, 6], 'monotone', 1, true);
      expect(p).assertEqual('M0 0 C1 1 2 2 3 3 C4 4 5 5 6 6');
    });
    it('area_closes_along_reversed_base', 0, () => {
      expect(sparkAreaPath([0, 10], [0, 5], [10, 10], 'linear', 1)).assertEqual('M0 0 L10 5 L10 10 L0 10 Z');
    });
    it('rounded_rect_clamps_radius', 0, () => {
      expect(sparkRoundRectPath(0, 0, 10, 20, 0, 0, 0, 0, 1)).assertEqual('M0 0 L10 0 L10 20 L0 20 L0 0 Z');
      const r = sparkRoundRectPath(0, 20, 10, -20, 99, 99, 0, 0, 1);
      expect(r.startsWith('M5 0 L5 0 A5 5 0 0 1 10 5')).assertTrue();
      expect(sparkRoundRectPath(0, 0, 10, 0, 4, 4, 4, 4, 1)).assertEqual('');
    });
    it('arc_paths', 0, () => {
      expect(sparkArcPath(0, 0, 0, 10, 0, Math.PI / 2, false, 1)).assertEqual('M0 -10 A10 10 0 0 1 10 0 L0 0 Z');
      expect(sparkArcPath(0, 0, 5, 10, 0, 0, false, 1)).assertEqual('');
      const ring = sparkArcPath(0, 0, 5, 10, 0, Math.PI * 2, false, 1);
      expect(ring.split('M').length).assertEqual(3); // outer + inner sub-paths
      expect(sparkCirclePath(5, 5, 5, 1)).assertEqual('M0 5 A5 5 0 1 0 10 5 A5 5 0 1 0 0 5 Z');
    });
    it('shape_vectors_decode', 0, () => {
      expect(sparkShapeCommands(sparkShapeLine([0, 10], [5, 0], 'linear', 2))).assertEqual('M0 10 L20 0');
      expect(sparkShapeCommands(sparkShapeRects([0, 0, 10, 20, 0, 0, 0, 0], 1)))
        .assertEqual('M0 0 L10 0 L10 20 L0 20 L0 0 Z');
      expect(sparkShapeCommands([])).assertEqual('');
      expect(sparkShapeCommands([1, 1, 0, 5, 1])).assertEqual(''); // truncated
    });
  });
}
