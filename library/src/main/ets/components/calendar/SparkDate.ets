/**
 * Plain calendar dates for SCalendar / SDatePicker.
 *
 * A `SparkDate` is a wall-calendar day (`year`, `month` 1-12, `day`) with no time and no timezone, so it can
 * never shift by a day the way `Date.toISOString()` does around midnight in UTC+X. All arithmetic is pure
 * (proleptic Gregorian, day ordinals); the JS `Date` is only used to read "today" in local time.
 */
export class SparkDate {
  readonly year: number;
  /** 1-12 */
  readonly month: number;
  readonly day: number;

  constructor(year: number, month: number, day: number) {
    this.year = year;
    this.month = month;
    this.day = day;
  }

  /** 'YYYY-MM-DD' */
  toString(): string {
    return SparkDates.toIso(this);
  }
}

/** A date range; `to` is undefined while the user has picked only the start. */
export class SparkDateRange {
  from: SparkDate | undefined;
  to: SparkDate | undefined;

  constructor(from?: SparkDate, to?: SparkDate) {
    this.from = from;
    this.to = to;
  }
}

/** 0 = weeks start on Sunday, 1 = on Monday. */
export type SparkWeekStart = 0 | 1;

/** Label language of the calendar and the date formats. */
export type SparkDateLocale = 'en' | 'zh';

const MONTHS_EN: string[] = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December'];
const MONTHS_ZH: string[] = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月',
  '十二月'];
/** Sunday first */
const WEEKDAYS_EN: string[] = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
const WEEKDAYS_EN_LONG: string[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const WEEKDAYS_ZH: string[] = ['日', '一', '二', '三', '四', '五', '六'];
const WEEKDAYS_ZH_LONG: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];

function pad(n: number, width: number): string {
  let s = String(Math.abs(Math.trunc(n)));
  while (s.length < width) {
    s = '0' + s;
  }
  return n < 0 ? '-' + s : s;
}

function floorDiv(a: number, b: number): number {
  return Math.floor(a / b);
}

/**
 * Date utilities (all pure, all on {@link SparkDate}).
 *
 * ```
 * const d = SparkDates.parse('2026-01-31');          // SparkDate | undefined
 * SparkDates.addMonths(d, 1);                       // 2026-02-28 (clamped)
 * SparkDates.format(d, 'MMM d, yyyy');              // 'Jan 31, 2026'  (zh: '2026年1月31日')
 * SparkDates.monthMatrix(2026, 1, 1);               // 6 × 7 weeks, Monday first, incl. outside days
 * ```
 */
export class SparkDates {
  static of(year: number, month: number, day: number): SparkDate {
    return new SparkDate(year, month, day);
  }

  /** Today in the device's local time. */
  static today(): SparkDate {
    const now = new Date();
    return new SparkDate(now.getFullYear(), now.getMonth() + 1, now.getDate());
  }

  static isLeapYear(year: number): boolean {
    return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
  }

  static daysInMonth(year: number, month: number): number {
    switch (month) {
      case 2:
        return SparkDates.isLeapYear(year) ? 29 : 28;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
  }

  /** A real calendar day (month 1-12, day within the month)? */
  static isValid(d: SparkDate): boolean {
    return Number.isInteger(d.year) && Number.isInteger(d.month) && Number.isInteger(d.day) &&
      d.month >= 1 && d.month <= 12 && d.day >= 1 && d.day <= SparkDates.daysInMonth(d.year, d.month);
  }

  /** Days since 1970-01-01 (negative before). Pure arithmetic (H. Hinnant's days_from_civil). */
  static toOrdinal(d: SparkDate): number {
    const y = d.month <= 2 ? d.year - 1 : d.year;
    const era = floorDiv(y, 400);
    const yoe = y - era * 400;
    const mp = (d.month + 9) % 12;
    const doy = floorDiv(153 * mp + 2, 5) + d.day - 1;
    const doe = yoe * 365 + floorDiv(yoe, 4) - floorDiv(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
  }

  /** Inverse of {@link toOrdinal}. */
  static fromOrdinal(n: number): SparkDate {
    const z = n + 719468;
    const era = floorDiv(z, 146097);
    const doe = z - era * 146097;
    const yoe = floorDiv(doe - floorDiv(doe, 1460) + floorDiv(doe, 36524) - floorDiv(doe, 146096), 365);
    const doy = doe - (365 * yoe + floorDiv(yoe, 4) - floorDiv(yoe, 100));
    const mp = floorDiv(5 * doy + 2, 153);
    const day = doy - floorDiv(153 * mp + 2, 5) + 1;
    const month = mp < 10 ? mp + 3 : mp - 9;
    const year = yoe + era * 400 + (month <= 2 ? 1 : 0);
    return new SparkDate(year, month, day);
  }

  /** Negative when a < b, 0 when the same day, positive when a > b. */
  static compare(a: SparkDate, b: SparkDate): number {
    if (a.year !== b.year) {
      return a.year - b.year;
    }
    if (a.month !== b.month) {
      return a.month - b.month;
    }
    return a.day - b.day;
  }

  static isSame(a: SparkDate | undefined, b: SparkDate | undefined): boolean {
    if (a === undefined || b === undefined) {
      return a === b;
    }
    return a.year === b.year && a.month === b.month && a.day === b.day;
  }

  static isSameMonth(a: SparkDate, b: SparkDate): boolean {
    return a.year === b.year && a.month === b.month;
  }

  static isBefore(a: SparkDate, b: SparkDate): boolean {
    return SparkDates.compare(a, b) < 0;
  }

  static isAfter(a: SparkDate, b: SparkDate): boolean {
    return SparkDates.compare(a, b) > 0;
  }

  /** `d` lies between `a` and `b` (either order). Inclusive of the ends unless `exclusive`. */
  static isBetween(d: SparkDate, a: SparkDate, b: SparkDate, exclusive?: boolean): boolean {
    const lo = SparkDates.compare(a, b) <= 0 ? a : b;
    const hi = lo === a ? b : a;
    const cl = SparkDates.compare(d, lo);
    const ch = SparkDates.compare(d, hi);
    return exclusive === true ? cl > 0 && ch < 0 : cl >= 0 && ch <= 0;
  }

  static addDays(d: SparkDate, n: number): SparkDate {
    return SparkDates.fromOrdinal(SparkDates.toOrdinal(d) + Math.trunc(n));
  }

  /** Adds calendar months; the day is clamped to the target month (Jan 31 + 1 → Feb 28/29). */
  static addMonths(d: SparkDate, n: number): SparkDate {
    const total = d.year * 12 + (d.month - 1) + Math.trunc(n);
    const year = floorDiv(total, 12);
    const month = total - year * 12 + 1;
    return new SparkDate(year, month, Math.min(d.day, SparkDates.daysInMonth(year, month)));
  }

  static addYears(d: SparkDate, n: number): SparkDate {
    return SparkDates.addMonths(d, Math.trunc(n) * 12);
  }

  /** Whole days from a to b (b - a). */
  static diffDays(a: SparkDate, b: SparkDate): number {
    return SparkDates.toOrdinal(b) - SparkDates.toOrdinal(a);
  }

  /** 0 = Sunday … 6 = Saturday. */
  static weekday(d: SparkDate): number {
    // 1970-01-01 was a Thursday (4)
    const w = (SparkDates.toOrdinal(d) + 4) % 7;
    return w < 0 ? w + 7 : w;
  }

  static startOfWeek(d: SparkDate, weekStartsOn: SparkWeekStart): SparkDate {
    const back = (SparkDates.weekday(d) - weekStartsOn + 7) % 7;
    return SparkDates.addDays(d, -back);
  }

  static endOfWeek(d: SparkDate, weekStartsOn: SparkWeekStart): SparkDate {
    return SparkDates.addDays(SparkDates.startOfWeek(d, weekStartsOn), 6);
  }

  static startOfMonth(d: SparkDate): SparkDate {
    return new SparkDate(d.year, d.month, 1);
  }

  static endOfMonth(d: SparkDate): SparkDate {
    return new SparkDate(d.year, d.month, SparkDates.daysInMonth(d.year, d.month));
  }

  static min(a: SparkDate, b: SparkDate): SparkDate {
    return SparkDates.compare(a, b) <= 0 ? a : b;
  }

  static max(a: SparkDate, b: SparkDate): SparkDate {
    return SparkDates.compare(a, b) >= 0 ? a : b;
  }

  /** Clamp into [minDate, maxDate] (either bound may be undefined). */
  static clamp(d: SparkDate, minDate?: SparkDate, maxDate?: SparkDate): SparkDate {
    if (minDate !== undefined && SparkDates.compare(d, minDate) < 0) {
      return minDate;
    }
    if (maxDate !== undefined && SparkDates.compare(d, maxDate) > 0) {
      return maxDate;
    }
    return d;
  }

  /**
   * The month grid: always 6 weeks × 7 days, starting on `weekStartsOn`, including the trailing days of the
   * previous month and the leading days of the next ("outside days"). A constant row count keeps the
   * calendar's height stable while paging months.
   */
  static monthMatrix(year: number, month: number, weekStartsOn: SparkWeekStart): SparkDate[][] {
    const first = SparkDates.startOfWeek(new SparkDate(year, month, 1), weekStartsOn);
    const start = SparkDates.toOrdinal(first);
    const weeks: SparkDate[][] = [];
    for (let w = 0; w < 6; w++) {
      const row: SparkDate[] = [];
      for (let i = 0; i < 7; i++) {
        row.push(SparkDates.fromOrdinal(start + w * 7 + i));
      }
      weeks.push(row);
    }
    return weeks;
  }

  /** 'YYYY-MM-DD' (also a stable key). */
  static toIso(d: SparkDate): string {
    return `${pad(d.year, 4)}-${pad(d.month, 2)}-${pad(d.day, 2)}`;
  }

  /** Strict ISO date 'YYYY-MM-DD' (a trailing 'T…' time part is ignored); undefined when invalid. */
  static parse(s: string): SparkDate | undefined {
    const m = /^\s*(\d{4})-(\d{1,2})-(\d{1,2})(?:[T\s].*)?$/.exec(s);
    if (m === null) {
      return undefined;
    }
    const d = new SparkDate(parseInt(m[1], 10), parseInt(m[2], 10), parseInt(m[3], 10));
    return SparkDates.isValid(d) ? d : undefined;
  }

  static monthName(month: number, locale: SparkDateLocale, short?: boolean): string {
    const i = Math.max(1, Math.min(12, month)) - 1;
    if (locale === 'zh') {
      return short === true ? `${i + 1}月` : MONTHS_ZH[i];
    }
    return short === true ? MONTHS_EN[i].substring(0, 3) : MONTHS_EN[i];
  }

  /** Weekday label for 0 = Sunday … 6; short = 'Mo' / '一', long = 'Monday' / '星期一'. */
  static weekdayName(weekday: number, locale: SparkDateLocale, long?: boolean): string {
    const i = ((weekday % 7) + 7) % 7;
    if (locale === 'zh') {
      return long === true ? WEEKDAYS_ZH_LONG[i] : WEEKDAYS_ZH[i];
    }
    return long === true ? WEEKDAYS_EN_LONG[i] : WEEKDAYS_EN[i];
  }

  /** The 7 short weekday labels in display order. */
  static weekdayLabels(weekStartsOn: SparkWeekStart, locale: SparkDateLocale): string[] {
    const out: string[] = [];
    for (let i = 0; i < 7; i++) {
      out.push(SparkDates.weekdayName(i + weekStartsOn, locale));
    }
    return out;
  }

  /** Month caption: 'October 2026' / '2026年10月'. */
  static monthCaption(year: number, month: number, locale: SparkDateLocale): string {
    return locale === 'zh' ? `${year}年${month}月` : `${MONTHS_EN[month - 1]} ${year}`;
  }

  /**
   * Format with tokens `yyyy`/`YYYY` (year), `MMMM` (month name), `MMM` (short month), `MM`, `M`, `dd`/`DD`, `d`/`D`,
   * `EEEE` (weekday), `EEE` (short weekday). Other characters are copied.
   * `'PPP'` (and `'MMM d, yyyy'` in zh) is the locale's medium date: 'Oct 12, 2026' / '2026年10月12日'.
   */
  static format(d: SparkDate, pattern: string, locale?: SparkDateLocale): string {
    const loc: SparkDateLocale = locale ?? 'en';
    let p = pattern;
    if (p === 'PPP') {
      p = loc === 'zh' ? 'yyyy年M月d日' : 'MMM d, yyyy';
    } else if (loc === 'zh' && p === 'MMM d, yyyy') {
      p = 'yyyy年M月d日';
    }
    let out = '';
    let i = 0;
    while (i < p.length) {
      const c = p.charAt(i);
      let j = i;
      while (j < p.length && p.charAt(j) === c) {
        j++;
      }
      const n = j - i;
      switch (c) {
        case 'y':
        case 'Y':
          out += n === 2 ? pad(d.year % 100, 2) : pad(d.year, n >= 4 ? 4 : 1);
          break;
        case 'M':
          out += n >= 4 ? SparkDates.monthName(d.month, loc) :
            (n === 3 ? SparkDates.monthName(d.month, loc, true) : pad(d.month, n));
          break;
        case 'd':
        case 'D':
          out += pad(d.day, n >= 2 ? 2 : 1);
          break;
        case 'E':
          out += SparkDates.weekdayName(SparkDates.weekday(d), loc, n >= 4);
          break;
        default:
          out += p.substring(i, j);
      }
      i = j;
    }
    return out;
  }
}
