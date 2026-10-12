import { describe, it, expect } from '@ohos/hypium';
import {
  sparkDecimalsOf, sparkNumberClamp, sparkNumberFormat, sparkNumberParse, sparkNumberStep, sparkRoundTo
} from '../main/ets/components/number-field/NumberFieldLogic';
import {
  sparkPinActiveIndex, sparkPinGroups, sparkPinSanitize, sparkPinSlotSize
} from '../main/ets/components/pin-input/PinInputLogic';
import { sparkTagsAdd, sparkTagsParse, sparkTagsRemoveAt } from '../main/ets/components/tags-input/TagsInputLogic';
import {
  sparkStepperHorizontal, sparkStepReachable, sparkStepState
} from '../main/ets/components/stepper/StepperLogic';
import {
  sparkTableColumnWidths, sparkTableMinWidth, sparkTableTotal, sparkTableUseCards, STableColumn
} from '../main/ets/components/table/TableLayout';

function join(a: number[]): string {
  return a.map((n: number) => String(Math.round(n * 100) / 100)).join(' ');
}

export default function dataTest() {
  describe('NumberField', () => {
    it('decimals_of', 0, () => {
      expect(sparkDecimalsOf(1)).assertEqual(0);
      expect(sparkDecimalsOf(0.25)).assertEqual(2);
      expect(sparkDecimalsOf(0.000001)).assertEqual(6);
    });
    it('round_without_drift', 0, () => {
      expect(sparkRoundTo(0.1 + 0.2, 2)).assertEqual(0.3);
    });
    it('clamp', 0, () => {
      expect(sparkNumberClamp(5, 0, 3)).assertEqual(3);
      expect(sparkNumberClamp(-1, 0, undefined)).assertEqual(0);
      expect(sparkNumberClamp(7, undefined, undefined)).assertEqual(7);
      expect(sparkNumberClamp(NaN, 2, 9)).assertEqual(2);
    });
    it('step_and_clamp', 0, () => {
      expect(sparkNumberStep(1, 1, 1, 0, 10)).assertEqual(2);
      expect(sparkNumberStep(10, 1, 1, 0, 10)).assertEqual(10);
      expect(sparkNumberStep(0, 1, -1, 0, 10)).assertEqual(0);
      expect(sparkNumberStep(0.2, 0.1, 1, undefined, undefined)).assertEqual(0.3);
      expect(sparkNumberStep(1, 0, 1, undefined, undefined)).assertEqual(2);
    });
    it('parse', 0, () => {
      expect(sparkNumberParse('12')).assertEqual(12);
      expect(sparkNumberParse(' -3,5 ')).assertEqual(-3.5);
      expect(sparkNumberParse('.5')).assertEqual(0.5);
      expect(sparkNumberParse('abc') === undefined).assertTrue();
      expect(sparkNumberParse('') === undefined).assertTrue();
      expect(sparkNumberParse('1.2.3') === undefined).assertTrue();
    });
    it('format', 0, () => {
      expect(sparkNumberFormat(1.5, 2)).assertEqual('1.50');
      expect(sparkNumberFormat(1.5)).assertEqual('1.5');
      expect(sparkNumberFormat(3, 0)).assertEqual('3');
    });
  });

  describe('PinInput', () => {
    it('sanitize_digits', 0, () => {
      expect(sparkPinSanitize('12a3-4 5678', 'digits', 6)).assertEqual('123456');
    });
    it('sanitize_alphanumeric', 0, () => {
      expect(sparkPinSanitize('ab-12 cD', 'alphanumeric', 6)).assertEqual('ab12cD');
    });
    it('groups', 0, () => {
      expect(sparkPinGroups(6, [3, 3]).join(',')).assertEqual('3,3');
      expect(sparkPinGroups(6, [2, 2]).join(',')).assertEqual('6');
      expect(sparkPinGroups(6, undefined).join(',')).assertEqual('6');
      expect(sparkPinGroups(4, [2, 0, 2]).join(',')).assertEqual('4');
    });
    it('active_index', 0, () => {
      expect(sparkPinActiveIndex(0, 6)).assertEqual(0);
      expect(sparkPinActiveIndex(3, 6)).assertEqual(3);
      expect(sparkPinActiveIndex(6, 6)).assertEqual(5);
    });
    it('slot_size_fits', 0, () => {
      expect(sparkPinSlotSize(0, 6, 1)).assertEqual(36);
      expect(sparkPinSlotSize(400, 6, 2)).assertEqual(36);
      expect(sparkPinSlotSize(200, 6, 1)).assertEqual(33);
      expect(sparkPinSlotSize(100, 6, 1)).assertEqual(28);
    });
  });

  describe('TagsInput', () => {
    it('parse_keeps_rest', 0, () => {
      const r = sparkTagsParse('vue, react,sv', ',', false);
      expect(r.tags.join('|')).assertEqual('vue|react');
      expect(r.rest).assertEqual('sv');
    });
    it('parse_commit', 0, () => {
      const r = sparkTagsParse(' svelte ', ',', true);
      expect(r.tags.join('|')).assertEqual('svelte');
      expect(r.rest).assertEqual('');
    });
    it('parse_skips_empty', 0, () => {
      const r = sparkTagsParse(',, a,', ',', false);
      expect(r.tags.join('|')).assertEqual('a');
      expect(r.rest).assertEqual('');
    });
    it('add_dedupes_and_caps', 0, () => {
      expect(sparkTagsAdd(['a'], ['a', 'b', 'c'], 2).join('|')).assertEqual('a|b');
      expect(sparkTagsAdd(['a'], ['a'], 0, true).join('|')).assertEqual('a|a');
      expect(sparkTagsAdd([], ['  ', 'x']).join('|')).assertEqual('x');
    });
    it('remove_at', 0, () => {
      expect(sparkTagsRemoveAt(['a', 'b', 'c'], 1).join('|')).assertEqual('a|c');
      expect(sparkTagsRemoveAt(['a'], 4).join('|')).assertEqual('a');
    });
  });

  describe('Stepper', () => {
    it('orientation', 0, () => {
      expect(sparkStepperHorizontal('horizontal', 100, 5)).assertTrue();
      expect(sparkStepperHorizontal('vertical', 2000, 3)).assertFalse();
      expect(sparkStepperHorizontal('responsive', 420, 3)).assertTrue();
      expect(sparkStepperHorizontal('responsive', 419, 3)).assertFalse();
      expect(sparkStepperHorizontal('responsive', 0, 3)).assertTrue();
    });
    it('step_state', 0, () => {
      expect(sparkStepState(1, 2)).assertEqual('completed');
      expect(sparkStepState(2, 2)).assertEqual('active');
      expect(sparkStepState(3, 2)).assertEqual('inactive');
    });
    it('reachable', 0, () => {
      expect(sparkStepReachable(3, 2, true)).assertTrue();
      expect(sparkStepReachable(4, 2, true)).assertFalse();
      expect(sparkStepReachable(4, 2, false)).assertTrue();
    });
  });

  describe('TableLayout', () => {
    const cols: STableColumn[] = [
      new STableColumn('invoice', 'Invoice', { fixedWidth: 100 }),
      new STableColumn('status', 'Status'),
      new STableColumn('method', 'Method', { weight: 2 }),
      new STableColumn('amount', 'Amount', { alignment: 'end', minWidth: 80 })
    ];
    it('min_width', 0, () => {
      expect(sparkTableMinWidth(cols)).assertEqual(100 + 96 + 96 + 80);
    });
    it('weights_share_remaining', 0, () => {
      // 500 - 100 = 400 → 100 / 200 / 100
      expect(join(sparkTableColumnWidths(cols, 500))).assertEqual('100 100 200 100');
    });
    it('clamps_to_min_and_redistributes', 0, () => {
      // 420 - 100 = 320: shares 80 / 160 / 80 → status clamps to 96, amount stays 80 → method 144
      expect(join(sparkTableColumnWidths(cols, 420))).assertEqual('100 96 144 80');
    });
    it('overflows_when_too_narrow', 0, () => {
      const w = sparkTableColumnWidths(cols, 200);
      expect(join(w)).assertEqual('100 96 96 80');
      expect(sparkTableTotal(w) > 200).assertTrue();
    });
    it('cards_switch', 0, () => {
      expect(sparkTableUseCards('auto', 300, cols)).assertTrue();
      expect(sparkTableUseCards('auto', 372, cols)).assertFalse();
      expect(sparkTableUseCards('table', 100, cols)).assertFalse();
      expect(sparkTableUseCards('cards', 2000, cols)).assertTrue();
      expect(sparkTableUseCards('auto', 0, cols)).assertFalse();
    });
  });
}
