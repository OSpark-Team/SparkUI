import { describe, it, expect } from '@ohos/hypium';
import {
  SPARK_FADE_THROUGH_SPLIT, SPARK_SHARED_AXIS_OFFSET, SparkEffectSpec, sparkNegateLength, sparkResolveForward,
  SparkTransitionHistory, sparkTransitionSpec
} from '../main/ets/components/transition/TransitionSpec';

const ORDER: string[] = ['intro', 'button', 'card', 'dialog'];

function tx(e: SparkEffectSpec): string {
  return e.translateX;
}

export default function transitionTest() {
  describe('Transition', () => {
    it('negate_length', 0, () => {
      expect(sparkNegateLength('100%')).assertEqual('-100%');
      expect(sparkNegateLength('-30vp')).assertEqual('30vp');
      expect(sparkNegateLength(' 12 ')).assertEqual('-12');
      expect(sparkNegateLength('')).assertEqual('');
    });

    it('fade_and_unknown_fall_back_to_opacity', 0, () => {
      const f = sparkTransitionSpec('fade', true);
      expect(f.enter.opacity).assertEqual(0);
      expect(f.leave.opacity).assertEqual(0);
      expect(f.enter.hasTransform()).assertFalse();
      const u = sparkTransitionSpec('bogus', true);
      expect(u.enter.opacity).assertEqual(0);
      expect(u.enter.none).assertFalse();
    });

    it('none_is_identity', 0, () => {
      const n = sparkTransitionSpec('none', true);
      expect(n.enter.none).assertTrue();
      expect(n.leave.none).assertTrue();
      expect(n.enter.span()).assertEqual(0);
    });

    it('slide_left_forward_and_back', 0, () => {
      const f = sparkTransitionSpec('slide-left', true);
      expect(tx(f.enter)).assertEqual('100%');
      expect(tx(f.leave)).assertEqual('-100%');
      const b = sparkTransitionSpec('slide-left', false);
      expect(tx(b.enter)).assertEqual('-100%');
      expect(tx(b.leave)).assertEqual('100%');
    });

    it('slide_right_mirrors_slide_left', 0, () => {
      const f = sparkTransitionSpec('slide-right', true);
      expect(tx(f.enter)).assertEqual('-100%');
      expect(tx(f.leave)).assertEqual('100%');
    });

    it('slide_vertical_and_custom_distance', 0, () => {
      const up = sparkTransitionSpec('slide-up', true, '24vp');
      expect(up.enter.translateY).assertEqual('24vp');
      expect(up.leave.translateY).assertEqual('-24vp');
      expect(up.enter.translateX).assertEqual('');
      const down = sparkTransitionSpec('slide-down', true, '24vp');
      expect(down.enter.translateY).assertEqual('-24vp');
      expect(down.leave.translateY).assertEqual('24vp');
      const downBack = sparkTransitionSpec('slide-down', false, '24vp');
      expect(downBack.enter.translateY).assertEqual('24vp');
    });

    it('scale_and_zoom', 0, () => {
      const s = sparkTransitionSpec('scale', false);
      expect(s.enter.scale).assertEqual(0.9);
      expect(s.leave.scale).assertEqual(0.9);
      const z = sparkTransitionSpec('zoom', true);
      expect(z.enter.scale).assertEqual(0.85);
      expect(z.leave.scale).assertEqual(1.15);
      const zb = sparkTransitionSpec('zoom', false);
      expect(zb.enter.scale).assertEqual(1.15);
      expect(zb.leave.scale).assertEqual(0.85);
    });

    it('fade_through_is_sequential', 0, () => {
      const f = sparkTransitionSpec('fade-through', true);
      expect(f.leave.opacityDelay).assertEqual(0);
      expect(f.leave.opacityDuration).assertEqual(SPARK_FADE_THROUGH_SPLIT);
      expect(f.enter.opacityDelay).assertEqual(SPARK_FADE_THROUGH_SPLIT);
      expect(f.enter.scale).assertEqual(0.92);
      expect(Math.abs(f.enter.span() - 1) < 1e-9).assertTrue();
    });

    it('shared_axis_is_direction_aware', 0, () => {
      const f = sparkTransitionSpec('shared-axis-x', true);
      expect(tx(f.enter)).assertEqual(SPARK_SHARED_AXIS_OFFSET);
      expect(tx(f.leave)).assertEqual('-' + SPARK_SHARED_AXIS_OFFSET);
      expect(f.enter.transformDuration).assertEqual(1);
      const b = sparkTransitionSpec('shared-axis-x', false);
      expect(tx(b.enter)).assertEqual('-' + SPARK_SHARED_AXIS_OFFSET);
      expect(tx(b.leave)).assertEqual(SPARK_SHARED_AXIS_OFFSET);
      const y = sparkTransitionSpec('shared-axis-y', true);
      expect(y.enter.translateY).assertEqual(SPARK_SHARED_AXIS_OFFSET);
      const z = sparkTransitionSpec('shared-axis-z', true);
      expect(z.enter.scale).assertEqual(0.8);
      expect(z.leave.scale).assertEqual(1.1);
      expect(sparkTransitionSpec('shared-axis-z', false).enter.scale).assertEqual(1.1);
    });

    it('explicit_direction_wins', 0, () => {
      expect(sparkResolveForward('forward', 'card', 'intro', ORDER, -1, -1)).assertTrue();
      expect(sparkResolveForward('back', 'intro', 'card', ORDER, -1, -1)).assertFalse();
    });

    it('auto_uses_index_then_order', 0, () => {
      expect(sparkResolveForward('auto', 'a', 'b', [], 3, 1)).assertFalse();
      expect(sparkResolveForward('auto', 'a', 'b', [], 1, 3)).assertTrue();
      expect(sparkResolveForward('auto', 'dialog', 'button', ORDER, -1, -1)).assertFalse();
      expect(sparkResolveForward('auto', 'button', 'dialog', ORDER, -1, -1)).assertTrue();
      // index takes precedence over order
      expect(sparkResolveForward('auto', 'button', 'dialog', ORDER, 5, 2)).assertFalse();
      // unknown keys default to forward
      expect(sparkResolveForward('auto', 'x', 'y', ORDER, -1, -1)).assertTrue();
    });

    it('history_detects_back_navigation', 0, () => {
      const h = new SparkTransitionHistory();
      h.reset('home');
      expect(h.visit('list')).assertTrue();
      expect(h.visit('detail')).assertTrue();
      expect(h.visit('list')).assertFalse();
      expect(h.top()).assertEqual('list');
      expect(h.visit('home')).assertFalse();
      expect(h.size()).assertEqual(1);
      expect(h.visit('home')).assertTrue();
      expect(h.size()).assertEqual(1);
    });

    it('auto_falls_back_to_history', 0, () => {
      const h = new SparkTransitionHistory();
      h.reset('a');
      expect(sparkResolveForward('auto', 'a', 'b', [], -1, -1, h)).assertTrue();
      expect(sparkResolveForward('auto', 'b', 'a', [], -1, -1, h)).assertFalse();
      // order wins over history but history stays in sync
      expect(sparkResolveForward('auto', 'a', 'c', ['c', 'a'], -1, -1, h)).assertFalse();
      expect(h.top()).assertEqual('c');
    });

    it('history_is_bounded', 0, () => {
      const h = new SparkTransitionHistory(3);
      h.visit('a');
      h.visit('b');
      h.visit('c');
      h.visit('d');
      expect(h.size()).assertEqual(3);
      expect(h.top()).assertEqual('d');
    });
  });
}
