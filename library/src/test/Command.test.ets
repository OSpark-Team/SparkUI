import { describe, it, expect } from '@ohos/hypium';
import { sparkCommandScore } from '../main/ets/components/command/CommandScore';
import {
  SparkCommandEntryData, sparkCommandEntries, sparkCommandItemOf, SparkCommandRow
} from '../main/ets/components/command/CommandData';
import { sparkOptionFirst, sparkOptionStep } from '../main/ets/primitives/list/SparkOptionLogic';

export default function commandTest() {
  describe('CommandScore', () => {
    it('empty_query_matches_everything', 0, () => {
      expect(sparkCommandScore('', 'Calendar')).assertEqual(1);
      expect(sparkCommandScore('   ', 'Calendar')).assertEqual(1);
    });
    it('exact_and_case_insensitive', 0, () => {
      expect(sparkCommandScore('calendar', 'Calendar')).assertEqual(1);
      expect(sparkCommandScore('CALENDAR', 'calendar')).assertEqual(1);
    });
    it('prefix_beats_substring', 0, () => {
      const prefix = sparkCommandScore('cal', 'Calendar');
      const sub = sparkCommandScore('end', 'Calendar');
      expect(prefix).assertEqual(0.9);
      expect(sub).assertEqual(0.7);
      expect(prefix > sub).assertTrue();
    });
    it('word_start_substring', 0, () => {
      expect(sparkCommandScore('emoji', 'Search Emoji')).assertEqual(0.8);
    });
    it('subsequence_matches', 0, () => {
      const s = sparkCommandScore('gtl', 'Go to line');
      expect(s > 0).assertTrue();
      expect(s <= 0.6).assertTrue();
      // compact word-start subsequence beats a scattered one
      expect(s > sparkCommandScore('gtl', 'begotten roll')).assertTrue();
    });
    it('no_match_is_zero', 0, () => {
      expect(sparkCommandScore('xyz', 'Calendar')).assertEqual(0);
      expect(sparkCommandScore('calendars', 'Calendar')).assertEqual(0);
      expect(sparkCommandScore('a', '')).assertEqual(0);
    });
    it('order_matters_for_subsequence', 0, () => {
      expect(sparkCommandScore('cdr', 'Calendar') > 0).assertTrue();
      expect(sparkCommandScore('zc', 'Calendar')).assertEqual(0);
    });
    it('keywords_match_slightly_lower', 0, () => {
      const viaKeyword = sparkCommandScore('date', 'Calendar', ['date', 'schedule']);
      expect(viaKeyword).assertEqual(0.95);
      expect(sparkCommandScore('cal', 'Calendar', ['calendar']) >= 0.9).assertTrue();
      expect(sparkCommandScore('zzz', 'Calendar', ['date'])).assertEqual(0);
    });
    it('query_spaces_ignored_in_subsequence', 0, () => {
      expect(sparkCommandScore('go ln', 'Go to line') > 0).assertTrue();
    });
  });

  describe('CommandData', () => {
    const items: SparkCommandEntryData[] = [
      new SparkCommandEntryData({ value: 'calendar', label: 'Calendar', group: 'Suggestions', keywords: ['date'] }),
      new SparkCommandEntryData({ value: 'emoji', label: 'Search Emoji', group: 'Suggestions' }),
      new SparkCommandEntryData({ value: 'calculator', label: 'Calculator', group: 'Suggestions', disabled: true }),
      new SparkCommandEntryData({ value: 'profile', label: 'Profile', group: 'Settings', shortcut: '⌘P' }),
      new SparkCommandEntryData({ value: 'billing', label: 'Billing', group: 'Settings' }),
      new SparkCommandEntryData({ value: 'loose' })
    ];
    const keys = (rows: SparkCommandRow[]): string => rows.map((r: SparkCommandRow) => r.key).join(',');

    it('data_defaults', 0, () => {
      const d = new SparkCommandEntryData({ value: 'x' });
      expect(d.label).assertEqual('x');
      expect(d.disabled).assertFalse();
      expect(d.keywords.length).assertEqual(0);
      expect(d.group === undefined).assertTrue();
    });
    it('empty_query_lists_all_with_headings', 0, () => {
      const rows = sparkCommandEntries(items, '');
      expect(keys(rows)).assertEqual('g:0,o:calendar,o:emoji,o:calculator,g:3,o:profile,o:billing,o:loose');
      expect(rows[0].kind).assertEqual('label');
      expect(rows[0].label).assertEqual('Suggestions');
      expect(rows[5].shortcut).assertEqual('⌘P');
    });
    it('filter_keeps_document_order_and_stable_heading_keys', 0, () => {
      // 'cal' matches Calendar and Calculator (prefix); the disabled one stays listed (shown dimmed)
      expect(keys(sparkCommandEntries(items, 'cal'))).assertEqual('g:0,o:calendar,o:calculator');
      expect(keys(sparkCommandEntries(items, 'billing'))).assertEqual('g:3,o:billing');
    });
    it('keywords_match', 0, () => {
      expect(keys(sparkCommandEntries(items, 'date'))).assertEqual('g:0,o:calendar');
    });
    it('no_match_is_empty', 0, () => {
      expect(sparkCommandEntries(items, 'zzzz').length).assertEqual(0);
    });
    it('filter_false_shows_everything', 0, () => {
      expect(sparkCommandEntries(items, 'zzzz', false).length).assertEqual(8);
    });
    it('step_skips_headings_and_disabled', 0, () => {
      const rows = sparkCommandEntries(items, '');
      expect(sparkOptionFirst(rows)).assertEqual('calendar');
      expect(sparkOptionStep(rows, 'emoji', 1)).assertEqual('profile');
      expect(sparkOptionStep(rows, 'profile', -1)).assertEqual('emoji');
      expect(sparkOptionStep(rows, 'loose', 1)).assertEqual('calendar');
      expect(sparkOptionStep(rows, 'calendar', -1)).assertEqual('loose');
    });
    it('item_lookup_ignores_disabled_and_filtered', 0, () => {
      const rows = sparkCommandEntries(items, '');
      expect(sparkCommandItemOf(rows, 'profile')?.label).assertEqual('Profile');
      expect(sparkCommandItemOf(rows, 'calculator') === undefined).assertTrue();
      expect(sparkCommandItemOf(sparkCommandEntries(items, 'bill'), 'profile') === undefined).assertTrue();
      expect(sparkCommandItemOf(rows, '') === undefined).assertTrue();
    });
    it('split_group_runs_get_own_headings', 0, () => {
      const split: SparkCommandEntryData[] = [
        new SparkCommandEntryData({ value: 'a', group: 'A' }),
        new SparkCommandEntryData({ value: 'b', group: 'B' }),
        new SparkCommandEntryData({ value: 'c', group: 'A' })
      ];
      expect(keys(sparkCommandEntries(split, ''))).assertEqual('g:0,o:a,g:1,o:b,g:2,o:c');
      expect(keys(sparkCommandEntries(split, 'c'))).assertEqual('g:2,o:c');
    });
    it('many_items_filter_linear', 0, () => {
      const many: SparkCommandEntryData[] = [];
      for (let i = 0; i < 2000; i++) {
        many.push(new SparkCommandEntryData({ value: `v${i}`, label: `Item ${i}`, group: `G${Math.floor(i / 100)}` }));
      }
      expect(sparkCommandEntries(many, '').length).assertEqual(2020);
      // "item 1999" → exactly one match, with its group heading
      expect(keys(sparkCommandEntries(many, 'item 1999'))).assertEqual('g:1900,o:v1999');
    });
  });
}
