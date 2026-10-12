import { describe, it, expect } from '@ohos/hypium';
import { sparkCommandScore } from '../main/ets/components/command/CommandScore';

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
}
