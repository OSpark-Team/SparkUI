import { describe, it, expect } from '@ohos/hypium';
import { SparkDate, SparkDates } from '../main/ets/components/calendar/SparkDate';

function d(y: number, m: number, day: number): SparkDate {
  return new SparkDate(y, m, day);
}

function iso(x: SparkDate | undefined): string {
  return x === undefined ? 'undefined' : SparkDates.toIso(x);
}

export default function dateTest() {
  describe('SparkDate', () => {
    it('days_in_month_and_leap_years', 0, () => {
      expect(SparkDates.daysInMonth(2024, 2)).assertEqual(29);
      expect(SparkDates.daysInMonth(2026, 2)).assertEqual(28);
      expect(SparkDates.daysInMonth(1900, 2)).assertEqual(28);
      expect(SparkDates.daysInMonth(2000, 2)).assertEqual(29);
      expect(SparkDates.daysInMonth(2026, 4)).assertEqual(30);
      expect(SparkDates.daysInMonth(2026, 12)).assertEqual(31);
    });
    it('ordinal_round_trip', 0, () => {
      expect(SparkDates.toOrdinal(d(1970, 1, 1))).assertEqual(0);
      expect(SparkDates.toOrdinal(d(1969, 12, 31))).assertEqual(-1);
      expect(SparkDates.toOrdinal(d(2000, 3, 1))).assertEqual(11017);
      for (let n = -800000; n <= 800000; n += 997) {
        expect(SparkDates.toOrdinal(SparkDates.fromOrdinal(n))).assertEqual(n);
      }
    });
    it('compare_and_same', 0, () => {
      expect(SparkDates.compare(d(2026, 1, 1), d(2025, 12, 31)) > 0).assertTrue();
      expect(SparkDates.compare(d(2026, 3, 1), d(2026, 3, 2)) < 0).assertTrue();
      expect(SparkDates.compare(d(2026, 3, 2), d(2026, 3, 2))).assertEqual(0);
      expect(SparkDates.isSame(d(2026, 3, 2), d(2026, 3, 2))).assertTrue();
      expect(SparkDates.isSame(d(2026, 3, 2), undefined)).assertFalse();
      expect(SparkDates.isSame(undefined, undefined)).assertTrue();
    });
    it('is_between_either_order', 0, () => {
      expect(SparkDates.isBetween(d(2026, 1, 5), d(2026, 1, 1), d(2026, 1, 10))).assertTrue();
      expect(SparkDates.isBetween(d(2026, 1, 5), d(2026, 1, 10), d(2026, 1, 1))).assertTrue();
      expect(SparkDates.isBetween(d(2026, 1, 1), d(2026, 1, 1), d(2026, 1, 10))).assertTrue();
      expect(SparkDates.isBetween(d(2026, 1, 1), d(2026, 1, 1), d(2026, 1, 10), true)).assertFalse();
      expect(SparkDates.isBetween(d(2026, 1, 11), d(2026, 1, 1), d(2026, 1, 10))).assertFalse();
    });
    it('add_days_across_boundaries', 0, () => {
      expect(iso(SparkDates.addDays(d(2026, 12, 31), 1))).assertEqual('2027-01-01');
      expect(iso(SparkDates.addDays(d(2024, 2, 28), 1))).assertEqual('2024-02-29');
      expect(iso(SparkDates.addDays(d(2024, 3, 1), -1))).assertEqual('2024-02-29');
      expect(iso(SparkDates.addDays(d(2026, 1, 1), 365))).assertEqual('2027-01-01');
      expect(iso(SparkDates.addDays(d(2026, 3, 29), 0))).assertEqual('2026-03-29');
    });
    it('add_months_clamps_day', 0, () => {
      expect(iso(SparkDates.addMonths(d(2026, 1, 31), 1))).assertEqual('2026-02-28');
      expect(iso(SparkDates.addMonths(d(2024, 1, 31), 1))).assertEqual('2024-02-29');
      expect(iso(SparkDates.addMonths(d(2026, 3, 31), -1))).assertEqual('2026-02-28');
      expect(iso(SparkDates.addMonths(d(2026, 12, 15), 1))).assertEqual('2027-01-15');
      expect(iso(SparkDates.addMonths(d(2026, 1, 15), -1))).assertEqual('2025-12-15');
      expect(iso(SparkDates.addMonths(d(2026, 5, 10), -17))).assertEqual('2024-12-10');
      expect(iso(SparkDates.addMonths(d(2026, 5, 10), 24))).assertEqual('2028-05-10');
    });
    it('weekday', 0, () => {
      expect(SparkDates.weekday(d(1970, 1, 1))).assertEqual(4);
      expect(SparkDates.weekday(d(2026, 10, 12))).assertEqual(1);
      expect(SparkDates.weekday(d(2000, 1, 1))).assertEqual(6);
      expect(SparkDates.weekday(d(1969, 12, 28))).assertEqual(0);
    });
    it('start_of_week', 0, () => {
      // Sunday 2026-10-11
      expect(iso(SparkDates.startOfWeek(d(2026, 10, 11), 0))).assertEqual('2026-10-11');
      expect(iso(SparkDates.startOfWeek(d(2026, 10, 11), 1))).assertEqual('2026-10-05');
      expect(iso(SparkDates.startOfWeek(d(2026, 10, 14), 1))).assertEqual('2026-10-12');
      expect(iso(SparkDates.startOfWeek(d(2026, 10, 14), 0))).assertEqual('2026-10-11');
      expect(iso(SparkDates.endOfWeek(d(2026, 10, 14), 1))).assertEqual('2026-10-18');
    });
    it('month_matrix_monday_first', 0, () => {
      const m = SparkDates.monthMatrix(2026, 10, 1);
      expect(m.length).assertEqual(6);
      m.forEach((w: SparkDate[]) => expect(w.length).assertEqual(7));
      // Oct 1 2026 is a Thursday → grid starts Mon Sep 28
      expect(iso(m[0][0])).assertEqual('2026-09-28');
      expect(iso(m[0][3])).assertEqual('2026-10-01');
      expect(iso(m[5][6])).assertEqual('2026-11-08');
      for (let w = 0; w < 6; w++) {
        expect(SparkDates.weekday(m[w][0])).assertEqual(1);
      }
    });
    it('month_matrix_sunday_first', 0, () => {
      const m = SparkDates.monthMatrix(2026, 2, 0);
      // Feb 1 2026 is a Sunday → no leading outside days
      expect(iso(m[0][0])).assertEqual('2026-02-01');
      expect(iso(m[3][6])).assertEqual('2026-02-28');
      expect(iso(m[4][0])).assertEqual('2026-03-01');
    });
    it('format_patterns', 0, () => {
      const x = d(2026, 1, 5);
      expect(SparkDates.format(x, 'YYYY-MM-DD')).assertEqual('2026-01-05');
      expect(SparkDates.format(x, 'yyyy-MM-dd')).assertEqual('2026-01-05');
      expect(SparkDates.format(x, 'MMM d, yyyy')).assertEqual('Jan 5, 2026');
      expect(SparkDates.format(x, 'MMM d, yyyy', 'zh')).assertEqual('2026年1月5日');
      expect(SparkDates.format(x, 'PPP')).assertEqual('Jan 5, 2026');
      expect(SparkDates.format(x, 'PPP', 'zh')).assertEqual('2026年1月5日');
      expect(SparkDates.format(x, 'MMMM d')).assertEqual('January 5');
      expect(SparkDates.format(x, 'EEEE')).assertEqual('Monday');
      expect(SparkDates.format(x, 'MM/dd/yy')).assertEqual('01/05/26');
      expect(SparkDates.monthCaption(2026, 10, 'en')).assertEqual('October 2026');
      expect(SparkDates.monthCaption(2026, 10, 'zh')).assertEqual('2026年10月');
    });
    it('weekday_labels', 0, () => {
      expect(SparkDates.weekdayLabels(0, 'en').join(' ')).assertEqual('Su Mo Tu We Th Fr Sa');
      expect(SparkDates.weekdayLabels(1, 'en').join(' ')).assertEqual('Mo Tu We Th Fr Sa Su');
      expect(SparkDates.weekdayLabels(1, 'zh').join('')).assertEqual('一二三四五六日');
    });
    it('parse_iso', 0, () => {
      expect(iso(SparkDates.parse('2026-10-12'))).assertEqual('2026-10-12');
      expect(iso(SparkDates.parse('2026-2-3'))).assertEqual('2026-02-03');
      expect(iso(SparkDates.parse('2026-10-12T23:59:59Z'))).assertEqual('2026-10-12');
      expect(iso(SparkDates.parse('2026-02-30'))).assertEqual('undefined');
      expect(iso(SparkDates.parse('2026-13-01'))).assertEqual('undefined');
      expect(iso(SparkDates.parse('12/10/2026'))).assertEqual('undefined');
      expect(iso(SparkDates.parse(''))).assertEqual('undefined');
    });
    it('clamp_and_today', 0, () => {
      expect(iso(SparkDates.clamp(d(2026, 1, 1), d(2026, 2, 1), d(2026, 3, 1)))).assertEqual('2026-02-01');
      expect(iso(SparkDates.clamp(d(2026, 4, 1), d(2026, 2, 1), d(2026, 3, 1)))).assertEqual('2026-03-01');
      expect(iso(SparkDates.clamp(d(2026, 2, 15), undefined, undefined))).assertEqual('2026-02-15');
      const t = SparkDates.today();
      const now = new Date();
      expect(t.year).assertEqual(now.getFullYear());
      expect(t.month).assertEqual(now.getMonth() + 1);
      expect(t.day).assertEqual(now.getDate());
      expect(SparkDates.isValid(t)).assertTrue();
    });
  });
}
