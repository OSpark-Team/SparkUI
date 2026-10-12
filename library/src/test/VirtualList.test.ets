import { describe, it, expect } from '@ohos/hypium';
import {
  SparkOptionEntry, sparkOptionEntries, sparkOptionFirst, sparkOptionIndexOf, sparkOptionListHeight, sparkOptionSizes,
  sparkOptionStep
} from '../main/ets/primitives/list/SparkOptionLogic';
import { SparkSelectOption } from '../main/ets/components/select/SSelect';
import { sparkComboboxEntries } from '../main/ets/components/combobox/SCombobox';
import { SparkTableMembers } from '../main/ets/components/table/STable';
import {
  SPARK_TABLE_BODY_HEIGHT, sparkSortedIndex, sparkTableBodyFixed, sparkTableBodyMax
} from '../main/ets/components/table/TableLayout';

const OPTS: SparkSelectOption[] = [
  new SparkSelectOption('apple', 'Apple', false, 'Fruits'),
  new SparkSelectOption('banana', 'Banana'),
  new SparkSelectOption('grapes', 'Grapes', true),
  new SparkSelectOption('carrot', 'Carrot', false, 'Vegetables'),
  new SparkSelectOption('pea', 'Pea')
];

function keys(e: SparkOptionEntry[]): string {
  return e.map((x: SparkOptionEntry) => x.key).join(',');
}

export default function virtualListTest() {
  describe('VirtualOptionList', () => {
    it('entries_insert_group_headings', 0, () => {
      const e = sparkOptionEntries(OPTS);
      expect(keys(e)).assertEqual('g:0,o:apple,o:banana,o:grapes,g:3,o:carrot,o:pea');
      expect(e[0].kind).assertEqual('label');
      expect(e[0].label).assertEqual('Fruits');
      expect(e[3].disabled).assertTrue();
    });

    it('filter_drops_empty_groups_keeps_keys', 0, () => {
      const e = sparkOptionEntries(OPTS, (o) => o.label.toLowerCase().indexOf('p') >= 0);
      // apple, grapes (Fruits) and pea (Vegetables); carrot / banana filtered out
      expect(keys(e)).assertEqual('g:0,o:apple,o:grapes,g:3,o:pea');
      const veg = sparkOptionEntries(OPTS, (o) => o.value === 'carrot');
      expect(keys(veg)).assertEqual('g:3,o:carrot');
      expect(sparkOptionEntries(OPTS, (o) => false).length).assertEqual(0);
    });

    it('combobox_filter_uses_command_score', 0, () => {
      expect(keys(sparkComboboxEntries(OPTS, ''))).assertEqual(keys(sparkOptionEntries(OPTS)));
      expect(keys(sparkComboboxEntries(OPTS, 'bna'))).assertEqual('g:0,o:banana');
      expect(keys(sparkComboboxEntries(OPTS, '  PEA '))).assertEqual('g:3,o:pea');
      expect(sparkComboboxEntries(OPTS, 'zzz').length).assertEqual(0);
    });

    it('keyboard_step_skips_headings_and_disabled', 0, () => {
      const e = sparkOptionEntries(OPTS);
      expect(sparkOptionFirst(e)).assertEqual('apple');
      expect(sparkOptionStep(e, 'apple', 1)).assertEqual('banana');
      expect(sparkOptionStep(e, 'banana', 1)).assertEqual('carrot'); // grapes disabled, heading skipped
      expect(sparkOptionStep(e, 'pea', 1)).assertEqual('apple'); // wraps
      expect(sparkOptionStep(e, 'apple', -1)).assertEqual('pea');
      expect(sparkOptionStep(e, '', 1)).assertEqual('apple');
      expect(sparkOptionStep(e, '', -1)).assertEqual('pea');
      expect(sparkOptionStep(e, 'banana', 0, 'last')).assertEqual('pea');
      expect(sparkOptionStep([], '', 1)).assertEqual('');
      expect(sparkOptionIndexOf(e, 'carrot')).assertEqual(5);
      expect(sparkOptionIndexOf(e, 'nope')).assertEqual(-1);
    });

    it('height_and_sizes', 0, () => {
      const e = sparkOptionEntries(OPTS);
      expect(sparkOptionListHeight(e, 32, 28, 1000)).assertEqual(2 * 28 + 5 * 32);
      expect(sparkOptionListHeight(e, 32, 28, 100)).assertEqual(100);
      expect(sparkOptionSizes(e, 44, 32).join(',')).assertEqual('32,44,44,44,32,44,44');
    });

    it('large_lists_are_linear', 0, () => {
      const run = (n: number): number => {
        const big: SparkSelectOption[] = [];
        for (let i = 0; i < n; i++) {
          big.push(new SparkSelectOption(`v${i}`, `Value ${i}`, false, i % 1000 === 0 ? `G${i}` : undefined));
        }
        const start = Date.now();
        const e = sparkOptionEntries(big);
        const f = sparkComboboxEntries(big, 'value 1999');
        expect(e.length).assertEqual(n + Math.ceil(n / 1000));
        expect(f.some((x: SparkOptionEntry) => x.value === 'v1999')).assertTrue();
        return Math.max(1, Date.now() - start);
      };
      const small = run(2000);
      const large = run(8000);
      console.info(`SPARKTIME options 2000=${small}ms 8000=${large}ms`);
    });
  });

  describe('VirtualTable', () => {
    it('sorted_index', 0, () => {
      const a = [2, 5, 9];
      expect(sparkSortedIndex(a, 1)).assertEqual(0);
      expect(sparkSortedIndex(a, 5)).assertEqual(1);
      expect(sparkSortedIndex(a, 6)).assertEqual(2);
      expect(sparkSortedIndex(a, 10)).assertEqual(3);
      expect(sparkSortedIndex([], 3)).assertEqual(0);
    });

    it('body_viewport', 0, () => {
      expect(isFinite(sparkTableBodyMax(10, undefined))).assertFalse();
      expect(sparkTableBodyMax(51, undefined)).assertEqual(SPARK_TABLE_BODY_HEIGHT);
      expect(sparkTableBodyMax(3, 200)).assertEqual(200);
      expect(sparkTableBodyFixed(10000, 400)).assertEqual(400);
      expect(sparkTableBodyFixed(3, 400)).assertEqual(0);
      expect(sparkTableBodyFixed(10000, Infinity)).assertEqual(0);
    });

    it('members_order_and_last_flags', 0, () => {
      const m = new SparkTableMembers();
      m.add(10);
      m.add(30);
      m.add(20);
      m.add(20);
      expect(m.indexOf(10)).assertEqual(0);
      expect(m.indexOf(20)).assertEqual(1);
      expect(m.indexOf(30)).assertEqual(2);
      expect(m.isLast(30)).assertTrue();
      expect(m.isLast(20)).assertFalse();
      m.remove(30);
      expect(m.isLast(20)).assertTrue();
      expect(m.indexOf(30)).assertEqual(-1);
      m.add(5);
      expect(m.indexOf(5)).assertEqual(0);
      expect(m.isLast(20)).assertTrue();
    });

    it('members_scale', 0, () => {
      const fill = (n: number): number => {
        const m = new SparkTableMembers();
        const start = Date.now();
        for (let i = 0; i < n; i++) {
          m.add(i);
        }
        expect(m.isLast(n - 1)).assertTrue();
        expect(m.isLast(n - 2)).assertFalse();
        expect(m.indexOf(n >> 1)).assertEqual(n >> 1);
        return Math.max(1, Date.now() - start);
      };
      const small = fill(2000);
      const large = fill(8000);
      console.info(`SPARKTIME members 2000=${small}ms 8000=${large}ms`);
      // 4x the rows: ~4x the time when linear (the old copy + sort per add was 16x+); the instrumented test
      // runtime is noisy (GC), hence the wide margin
      expect(large < small * 12 + 100).assertTrue();
    });
  });
}
