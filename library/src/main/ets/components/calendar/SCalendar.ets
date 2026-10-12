import { LengthMetrics } from '@kit.ArkUI';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';
import { sparkCalendarCanPage, SparkMonthPager } from './CalendarPaging';
import { SparkDate, SparkDateLocale, SparkDateRange, SparkDates, SparkWeekStart } from './SparkDate';

/** Selection behaviour of {@link SCalendar}. */
export type SparkCalendarMode = 'single' | 'multiple' | 'range';

/** Predicate for days that cannot be picked. */
export type SparkDateMatcher = (d: SparkDate) => boolean;

/** card padding (shadcn p-3) */
const PAD: number = 12;
/** gap between months (gap-4) */
const GAP: number = 16;
const MIN_CELL: number = 32;
const MAX_CELL: number = 44;
const DEFAULT_CELL: number = 36;
/** vertical gap between weeks (mt-2) */
const ROW_GAP: number = 8;
/** horizontal travel of the month slide (vp) */
const SLIDE: number = 16;
/** swipe distance that pages a month (vp) */
const SWIPE: number = 48;
const MOTION: string = 'calendar';

const WEEK_IDX: number[] = [0, 1, 2, 3, 4, 5];
const DAY_IDX: number[] = [0, 1, 2, 3, 4, 5, 6];

const KEY_UP: number = 2012;
const KEY_DOWN: number = 2013;
const KEY_LEFT: number = 2014;
const KEY_RIGHT: number = 2015;
const KEY_PAGE_UP: number = 2068;
const KEY_PAGE_DOWN: number = 2069;
const KEY_HOME: number = 2081;
const KEY_END: number = 2082;
const KEY_ENTER: number = 2054;
const KEY_SPACE: number = 2050;
// KEYCODE_NUMPAD_ENTER (2119 in the SDK KeyCode table)
const KEY_NUMPAD_ENTER: number = 2119;

const NO_RADIUS: BorderRadiuses = { topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0 };

/** Resolved look of one day cell (pure data; computed once per state change for the whole grid). */
export class SparkCalendarDayInfo {
  date: SparkDate = new SparkDate(1970, 1, 1);
  label: string = '';
  /** false: an outside day while showOutsideDays is off (renders an empty slot) */
  shown: boolean = true;
  outside: boolean = false;
  disabled: boolean = false;
  selected: boolean = false;
  today: boolean = false;
  /** day button */
  background: string = '#00000000';
  pressedBackground: string = '#00000000';
  foreground: string = '#FF000000';
  radius: BorderRadiuses = NO_RADIUS;
  /** range strip behind the day button (the shadcn `range_start` / `range_end` cell background) */
  strip: string = '#00000000';
  stripRadius: BorderRadiuses = NO_RADIUS;
  dim: number = 1;
  focusRing: boolean = false;
  a11y: string = '';
}

class CalendarMonthView {
  year: number;
  month: number;
  weeks: SparkDate[][];

  constructor(year: number, month: number, weeks: SparkDate[][]) {
    this.year = year;
    this.month = month;
    this.weeks = weeks;
  }
}

/**
 * Day button look: background in the normal state; pressing only fades it (system pressed state, never
 * animated — component-guide §3).
 */
class SparkCalendarDayModifier implements AttributeModifier<StackAttribute> {
  info: SparkCalendarDayInfo;
  sizeVp: number;

  constructor(info: SparkCalendarDayInfo, sizeVp: number) {
    this.info = info;
    this.sizeVp = sizeVp;
  }

  applyNormalAttribute(instance: StackAttribute): void {
    instance
      .width(this.sizeVp)
      .height(this.sizeVp)
      .backgroundColor(this.info.background)
      .borderRadius(this.info.radius)
      .opacity(1)
  }

  applyPressedAttribute(instance: StackAttribute): void {
    if (this.info.disabled || !this.info.shown) {
      return;
    }
    // selection-type cell: pressing fades it — a pressed background next to the selected day reads as two
    // selected days (component-guide §3)
    instance.opacity(0.6)
  }
}

/** Sizes SButton nav buttons to the cell size (shadcn `size-(--cell-size)`). */
class SparkCalendarNavSize implements AttributeModifier<ButtonAttribute> {
  sizeVp: number;

  constructor(sizeVp: number) {
    this.sizeVp = sizeVp;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    instance.width(this.sizeVp).height(this.sizeVp).constraintSize({ minHeight: this.sizeVp })
  }
}

/**
 * shadcn-vue `Calendar` (v4 look, react-day-picker semantics).
 *
 * ```
 * SCalendar({ selected: this.date!! })                                     // single
 * SCalendar({ mode: 'multiple', selectedDates: this.days!! })
 * SCalendar({ mode: 'range', range: this.range!!, numberOfMonths: 2 })
 * SCalendar({ minDate: SparkDates.today(), disabledDates: (d: SparkDate) => SparkDates.weekday(d) === 0 })
 * ```
 * - One value prop per mode keeps the types simple: `selected` (single), `selectedDates` (multiple),
 *   `range` (range). Each has `$name` for `!!` and an `on…Change` event. Leave them unset to let the calendar
 *   keep its own selection.
 * - `month` / `defaultMonth`: the (first) displayed month; `onMonthChange` reports paging.
 * - Self-measuring (D11): the cell size follows the width the calendar gets (32–44vp); with `numberOfMonths` > 1
 *   months sit side by side when they fit and stack otherwise. `cellSize` pins the cell size.
 * - Paging: header chevrons, horizontal swipe on the grid, PageUp / PageDown (Shift: year). Arrow keys move the
 *   focused day (Home / End: week start / end), Enter / Space pick it.
 * - Motion key `calendar`: month changes slide + fade the grid (one container); the selected day always
 *   switches instantly.
 * - `weekStartsOn`: 1 = Monday (default), 0 = Sunday. `locale`: 'en' | 'zh' labels.
 */
@ComponentV2
export struct SCalendar {
  @Param mode: SparkCalendarMode = 'single';
  /** single mode */
  @Param selected: SparkDate | undefined = undefined;
  @Event $selected: (d: SparkDate | undefined) => void = () => {
  };
  @Event onSelectedChange: (d: SparkDate | undefined) => void = () => {
  };
  /** multiple mode */
  @Param selectedDates: SparkDate[] = [];
  @Event $selectedDates: (d: SparkDate[]) => void = () => {
  };
  @Event onSelectedDatesChange: (d: SparkDate[]) => void = () => {
  };
  /** range mode */
  @Param range: SparkDateRange = new SparkDateRange();
  @Event $range: (r: SparkDateRange) => void = () => {
  };
  @Event onRangeChange: (r: SparkDateRange) => void = () => {
  };
  /** Displayed (first) month — any day in it. Controlled when set. */
  @Param month: SparkDate | undefined = undefined;
  @Event $month: (m: SparkDate) => void = () => {
  };
  @Event onMonthChange: (m: SparkDate) => void = () => {
  };
  /** Initially displayed month (default: the selection, else today). */
  @Param defaultMonth: SparkDate | undefined = undefined;
  @Param minDate: SparkDate | undefined = undefined;
  @Param maxDate: SparkDate | undefined = undefined;
  /** Extra disabled days, e.g. weekends. */
  @Param disabledDates: SparkDateMatcher | undefined = undefined;
  /** single / multiple: tapping the selected day again keeps it (no deselect). */
  @Param required: boolean = false;
  @Param weekStartsOn: SparkWeekStart = 1;
  @Param locale: SparkDateLocale = 'en';
  @Param showOutsideDays: boolean = true;
  @Param numberOfMonths: number = 1;
  /** Fixed cell size in vp; undefined = adapt to the available width (32–44). */
  @Param cellSize: number | undefined = undefined;
  /** Card look: `rounded-lg border shadow-sm` (off inside popovers). */
  @Param bordered: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local cur: SparkDate | undefined = undefined;
  @Local curDates: SparkDate[] = [];
  @Local curRange: SparkDateRange = new SparkDateRange();
  /** first day of the first displayed month */
  @Local view: SparkDate = new SparkDate(1970, 1, 1);
  @Local focusDate: SparkDate = new SparkDate(1970, 1, 1);
  @Local gridFocused: boolean = false;
  @Local hoverKey: string = '';
  @Local measured: number = 0;
  @Local slideX: number = 0;
  @Local fade: number = 1;
  private todayDate: SparkDate = SparkDates.today();
  private pager: SparkMonthPager = new SparkMonthPager();
  private alive: boolean = true;

  aboutToAppear(): void {
    this.todayDate = SparkDates.today();
    this.cur = this.selected;
    this.curDates = this.selectedDates;
    this.curRange = this.range;
    const anchor: SparkDate = this.month ?? this.defaultMonth ?? this.selectionAnchor() ?? this.todayDate;
    this.view = SparkDates.startOfMonth(anchor);
    this.focusDate = this.initialFocus();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.pager.reset();
  }

  @Monitor('selected')
  syncSelected(): void {
    this.cur = this.selected;
  }

  @Monitor('selectedDates')
  syncDates(): void {
    this.curDates = this.selectedDates;
  }

  @Monitor('range')
  syncRange(): void {
    this.curRange = this.range;
  }

  @Monitor('month')
  syncMonth(): void {
    if (this.month !== undefined && !SparkDates.isSameMonth(this.month, this.view)) {
      this.view = SparkDates.startOfMonth(this.month);
      this.focusDate = this.initialFocus();
    }
  }

  // ------------------------------------------------------------------ layout

  @Computed
  get monthCount(): number {
    return Math.max(1, Math.floor(this.numberOfMonths));
  }

  @Computed
  get sideBySide(): boolean {
    const n = this.monthCount;
    if (n <= 1 || this.measured <= 0) {
      return true;
    }
    return this.innerWidth() >= n * 7 * MIN_CELL + (n - 1) * GAP;
  }

  @Computed
  get cell(): number {
    if (this.cellSize !== undefined) {
      return this.cellSize;
    }
    if (this.measured <= 0) {
      return DEFAULT_CELL;
    }
    const n = this.monthCount;
    const per = this.sideBySide ? (this.innerWidth() - (n - 1) * GAP) / n : this.innerWidth();
    return Math.max(MIN_CELL, Math.min(MAX_CELL, Math.floor(per / 7)));
  }

  private innerWidth(): number {
    return this.measured - 2 * PAD - (this.bordered ? 2 : 0);
  }

  @Computed
  get monthIndices(): number[] {
    const out: number[] = [];
    for (let i = 0; i < this.monthCount; i++) {
      out.push(i);
    }
    return out;
  }

  @Computed
  get months(): CalendarMonthView[] {
    const out: CalendarMonthView[] = [];
    for (let i = 0; i < this.monthCount; i++) {
      const m = SparkDates.addMonths(this.view, i);
      out.push(new CalendarMonthView(m.year, m.month, SparkDates.monthMatrix(m.year, m.month, this.weekStartsOn)));
    }
    return out;
  }

  @Computed
  get weekdays(): string[] {
    return SparkDates.weekdayLabels(this.weekStartsOn, this.locale);
  }

  @Computed
  get prevDisabled(): boolean {
    const min = this.minDate;
    return min !== undefined && SparkDates.compare(SparkDates.addDays(this.view, -1), min) < 0;
  }

  @Computed
  get nextDisabled(): boolean {
    const max = this.maxDate;
    return max !== undefined &&
      SparkDates.compare(SparkDates.addMonths(this.view, this.monthCount), max) > 0;
  }

  /** Visual state of every cell: [month][week][weekday]. */
  @Computed
  get cells(): SparkCalendarDayInfo[][][] {
    const out: SparkCalendarDayInfo[][][] = [];
    const months = this.months;
    for (let mi = 0; mi < months.length; mi++) {
      const m = months[mi];
      const weeks: SparkCalendarDayInfo[][] = [];
      for (let wi = 0; wi < m.weeks.length; wi++) {
        const row: SparkCalendarDayInfo[] = [];
        for (let ci = 0; ci < 7; ci++) {
          row.push(this.describe(m.weeks[wi][ci], m, ci));
        }
        weeks.push(row);
      }
      out.push(weeks);
    }
    return out;
  }

  private cellAt(mi: number, wi: number, ci: number): SparkCalendarDayInfo {
    const c = this.cells;
    if (mi < c.length && wi < c[mi].length && ci < c[mi][wi].length) {
      return c[mi][wi][ci];
    }
    const empty = new SparkCalendarDayInfo();
    empty.shown = false;
    return empty;
  }

  private caption(mi: number): string {
    const ms = this.months;
    return mi < ms.length ? SparkDates.monthCaption(ms[mi].year, ms[mi].month, this.locale) : '';
  }

  // ------------------------------------------------------------------ state helpers

  private selectionAnchor(): SparkDate | undefined {
    switch (this.mode) {
      case 'multiple':
        return this.curDates.length > 0 ? this.curDates[0] : undefined;
      case 'range':
        return this.curRange.from;
      default:
        return this.cur;
    }
  }

  private lastShown(): SparkDate {
    return SparkDates.endOfMonth(SparkDates.addMonths(this.view, this.monthCount - 1));
  }

  private isShown(d: SparkDate): boolean {
    return SparkDates.compare(d, this.view) >= 0 && SparkDates.compare(d, this.lastShown()) <= 0;
  }

  private initialFocus(): SparkDate {
    const a = this.selectionAnchor();
    if (a !== undefined && this.isShown(a)) {
      return a;
    }
    if (this.isShown(this.todayDate)) {
      return this.todayDate;
    }
    return this.view;
  }

  isDayDisabled(d: SparkDate): boolean {
    if (this.minDate !== undefined && SparkDates.compare(d, this.minDate) < 0) {
      return true;
    }
    if (this.maxDate !== undefined && SparkDates.compare(d, this.maxDate) > 0) {
      return true;
    }
    const f = this.disabledDates;
    return f !== undefined && f(d);
  }

  private describe(d: SparkDate, m: CalendarMonthView, col: number): SparkCalendarDayInfo {
    const t = this.theme;
    const c = t.colors;
    const info = new SparkCalendarDayInfo();
    const r = t.radiusMd;
    const rounded: BorderRadiuses = { topLeft: r, topRight: r, bottomLeft: r, bottomRight: r };
    info.date = d;
    info.label = String(d.day);
    info.outside = d.month !== m.month || d.year !== m.year;
    info.shown = !info.outside || this.showOutsideDays;
    info.disabled = this.isDayDisabled(d);
    info.today = SparkDates.isSame(d, this.todayDate);
    info.radius = rounded;
    info.foreground = info.outside ? c.mutedForeground : c.foreground;
    // outside days carry selection styles only in single-month view (else the same day would show twice)
    const styled = !info.outside || this.monthCount === 1;
    let selected = false;
    let middle = false;
    let rangeStart = false;
    let rangeEnd = false;
    if (styled) {
      if (this.mode === 'single') {
        selected = SparkDates.isSame(d, this.cur);
      } else if (this.mode === 'multiple') {
        selected = this.curDates.some((x: SparkDate) => SparkDates.isSame(x, d));
      } else {
        const from = this.curRange.from;
        const to = this.curRange.to;
        rangeStart = from !== undefined && SparkDates.isSame(d, from);
        rangeEnd = to !== undefined && SparkDates.isSame(d, to);
        middle = from !== undefined && to !== undefined && SparkDates.isBetween(d, from, to, true);
        selected = rangeStart || rangeEnd;
        const span = from !== undefined && to !== undefined && !SparkDates.isSame(from, to);
        if (span && rangeStart !== rangeEnd) {
          const lo = SparkDates.compare(from as SparkDate, to as SparkDate) <= 0;
          // the strip runs from the start's centre to the end's centre
          const leftEnd = rangeStart === lo;
          info.strip = c.accent;
          info.stripRadius = leftEnd ? { topLeft: r, bottomLeft: r, topRight: 0, bottomRight: 0 } :
            { topLeft: 0, bottomLeft: 0, topRight: r, bottomRight: r };
        }
      }
    }
    info.selected = selected || middle;
    const hovered = !info.disabled && this.hoverKey === SparkDates.toIso(d);
    const accentPressed = t.isDark ? SparkColor.mix(c.accent, c.foreground, 0.12) :
      SparkColor.mix(c.accent, c.foreground, 0.06);
    if (selected) {
      info.background = c.primary;
      info.pressedBackground = SparkColor.alpha(c.primary, 0.85);
      info.foreground = c.primaryForeground;
    } else if (middle) {
      info.background = c.accent;
      info.pressedBackground = accentPressed;
      info.foreground = c.accentForeground;
      info.radius = {
        topLeft: col === 0 ? r : 0, bottomLeft: col === 0 ? r : 0,
        topRight: col === 6 ? r : 0, bottomRight: col === 6 ? r : 0
      };
    } else {
      info.background = info.today || hovered ? c.accent : '#00000000';
      info.pressedBackground = accentPressed;
      if (info.today) {
        info.foreground = c.accentForeground;
      }
    }
    if (info.disabled) {
      info.foreground = c.mutedForeground;
      info.dim = 0.5;
    }
    info.focusRing = this.gridFocused && !info.outside && SparkDates.isSame(d, this.focusDate);
    let a11y: string;
    if (this.locale === 'zh') {
      a11y = `${SparkDates.format(d, 'PPP', 'zh')} ${SparkDates.weekdayName(SparkDates.weekday(d), 'zh', true)}`;
    } else {
      a11y = `${SparkDates.weekdayName(SparkDates.weekday(d), 'en', true)}, ${SparkDates.format(d, 'PPP', 'en')}`;
    }
    if (info.today) {
      a11y = (this.locale === 'zh' ? '今天，' : 'Today, ') + a11y;
    }
    info.a11y = a11y;
    return info;
  }

  // ------------------------------------------------------------------ selection

  private pick(d: SparkDate): void {
    if (this.isDayDisabled(d)) {
      return;
    }
    // committed synchronously: a month animation started next must never include the selection change (it would
    // cross-fade two cells)
    SparkAnim.commit(() => this.applyPick(d));
    // an outside day of a month that is not displayed: page to it
    if (!this.isShown(d)) {
      this.navigate(SparkDates.compare(d, this.view) < 0 ? -1 : 1, d);
    }
  }

  private applyPick(d: SparkDate): void {
    this.focusDate = d;
    if (this.mode === 'single') {
      const next: SparkDate | undefined = SparkDates.isSame(d, this.cur) && !this.required ? undefined : d;
      this.cur = next;
      this.$selected(next);
      this.onSelectedChange(next);
    } else if (this.mode === 'multiple') {
      const has = this.curDates.some((x: SparkDate) => SparkDates.isSame(x, d));
      let next: SparkDate[];
      if (has) {
        next = this.required && this.curDates.length <= 1 ? this.curDates :
          this.curDates.filter((x: SparkDate) => !SparkDates.isSame(x, d));
      } else {
        next = this.curDates.concat([d]);
        next.sort((a: SparkDate, b: SparkDate) => SparkDates.compare(a, b));
      }
      this.curDates = next;
      this.$selectedDates(next);
      this.onSelectedDatesChange(next);
    } else {
      const from = this.curRange.from;
      const to = this.curRange.to;
      let next: SparkDateRange;
      if (from === undefined || to !== undefined) {
        next = new SparkDateRange(d, undefined);
      } else if (SparkDates.compare(d, from) < 0) {
        next = new SparkDateRange(d, from);
      } else {
        next = new SparkDateRange(from, d);
      }
      this.curRange = next;
      this.$range(next);
      this.onRangeChange(next);
    }
  }

  // ------------------------------------------------------------------ month paging

  private canPage(delta: number): boolean {
    return sparkCalendarCanPage(this.pager.base(this.view), delta, this.monthCount, this.minDate, this.maxDate);
  }

  private applyView(target: SparkDate, focus: SparkDate | undefined): void {
    this.view = SparkDates.startOfMonth(target);
    this.focusDate = focus ?? SparkDates.clamp(SparkDates.addMonths(this.focusDate,
      (target.year - this.focusDate.year) * 12 + target.month - this.focusDate.month), this.view, this.lastShown());
    this.$month(this.view);
    this.onMonthChange(this.view);
  }

  /**
   * Page by `delta` months: the grid slides out, the month changes un-animated, the grid slides back in.
   * Requests during a slide accumulate (counted from the pending month) and the slide lands on the latest one,
   * so every tap counts and `onMonthChange` fires once per month actually shown (see SparkMonthPager).
   */
  navigate(delta: number, focus?: SparkDate): void {
    if (delta === 0) {
      return;
    }
    if (SparkAnim.duration(this.theme, MOTION, 'fast') <= 0) {
      const target = SparkDates.addMonths(this.pager.base(this.view), delta);
      this.pager.reset();
      SparkAnim.commit(() => this.applyView(target, focus));
      return;
    }
    if (this.pager.request(this.view, delta, focus)) {
      this.slide(this.pager.direction(this.view));
    }
  }

  /** One slide out → apply the pending month while hidden → slide in; repeats while requests keep arriving. */
  private slide(dir: number): void {
    const ui = this.getUIContext();
    const outDir: number = dir < 0 ? -1 : 1;
    SparkAnim.run(ui, this.theme, MOTION, 'fast', () => {
      this.slideX = -outDir * SLIDE;
      this.fade = 0;
    }, () => {
      if (!this.alive) {
        return;
      }
      const d = this.pager.direction(this.view);
      const inDir: number = d === 0 ? outDir : d;
      const focus = this.pager.focus;
      const target = this.pager.take(this.view);
      // committed (flushed) now, outside any animation: the new month's cells switch while the grid is invisible
      SparkAnim.commit(() => {
        if (target !== undefined) {
          this.applyView(target, focus);
        } else if (focus !== undefined) {
          this.focusDate = focus;
        }
        this.slideX = inDir * SLIDE;
      });
      SparkAnim.run(ui, this.theme, MOTION, 'fast', () => {
        this.slideX = 0;
        this.fade = 1;
      }, () => {
        if (this.alive && this.pager.finish(this.view)) {
          this.slide(this.pager.direction(this.view));
        }
      });
    });
  }

  private page(delta: number): void {
    if (this.canPage(delta)) {
      this.navigate(delta);
    }
  }

  // ------------------------------------------------------------------ keyboard

  private moveFocus(target: SparkDate): void {
    const t = SparkDates.clamp(target, this.minDate, this.maxDate);
    // count from the month a running slide is heading to, not the one still on screen
    const base = this.pager.base(this.view);
    const last = SparkDates.endOfMonth(SparkDates.addMonths(base, this.monthCount - 1));
    const before = SparkDates.compare(t, base) < 0;
    const after = SparkDates.compare(t, last) > 0;
    if (!before && !after) {
      if (this.pager.hasPending) {
        this.pager.request(this.view, 0, t);
      } else {
        this.focusDate = t;
      }
      return;
    }
    const delta = before ? (t.year - base.year) * 12 + t.month - base.month :
      (t.year - last.year) * 12 + t.month - last.month;
    this.navigate(delta, t);
  }

  private onKey(e: KeyEvent): boolean {
    if (e.type !== KeyType.Down) {
      return false;
    }
    const f = this.focusDate;
    let shift = false;
    try {
      shift = e.getModifierKeyState !== undefined && e.getModifierKeyState(['Shift']);
    } catch (err) {
      shift = false;
    }
    switch (e.keyCode) {
      case KEY_LEFT:
        this.moveFocus(SparkDates.addDays(f, -1));
        return true;
      case KEY_RIGHT:
        this.moveFocus(SparkDates.addDays(f, 1));
        return true;
      case KEY_UP:
        this.moveFocus(SparkDates.addDays(f, -7));
        return true;
      case KEY_DOWN:
        this.moveFocus(SparkDates.addDays(f, 7));
        return true;
      case KEY_HOME:
        this.moveFocus(SparkDates.startOfWeek(f, this.weekStartsOn));
        return true;
      case KEY_END:
        this.moveFocus(SparkDates.endOfWeek(f, this.weekStartsOn));
        return true;
      case KEY_PAGE_UP:
        this.moveFocus(shift ? SparkDates.addYears(f, -1) : SparkDates.addMonths(f, -1));
        return true;
      case KEY_PAGE_DOWN:
        this.moveFocus(shift ? SparkDates.addYears(f, 1) : SparkDates.addMonths(f, 1));
        return true;
      case KEY_ENTER:
      case KEY_NUMPAD_ENTER:
      case KEY_SPACE:
        this.pick(f);
        return true;
      default:
        return false;
    }
  }

  // ------------------------------------------------------------------ view

  @Builder
  navButton(prev: boolean) {
    SButton({
      variant: 'ghost',
      sizing: 'icon-sm',
      icon: prev ? 'chevron-left' : 'chevron-right',
      label: prev ? (this.locale === 'zh' ? '上个月' : 'Go to the previous month') :
        (this.locale === 'zh' ? '下个月' : 'Go to the next month'),
      disabled: prev ? this.prevDisabled : this.nextDisabled,
      modifier: new SparkCalendarNavSize(this.cell)
    })
      .onClick(() => this.page(prev ? -1 : 1))
  }

  @Builder
  header(mi: number) {
    Row() {
      if (mi === 0) {
        this.navButton(true)
      } else {
        Column().width(this.cell).height(this.cell)
      }
      Text(this.caption(mi))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize(this.theme.text.sm)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
        .maxLines(1)
        .translate({ x: this.slideX })
        .opacity(this.fade)
        .accessibilityLevel('yes')
      if ((this.sideBySide && mi === this.monthCount - 1) || (!this.sideBySide && mi === 0)) {
        this.navButton(false)
      } else {
        Column().width(this.cell).height(this.cell)
      }
    }
    .width(this.cell * 7)
    .height(this.cell)
  }

  @Builder
  dayCell(mi: number, wi: number, ci: number) {
    Stack() {
      if (this.cellAt(mi, wi, ci).shown) {
        Stack() {
          Text(this.cellAt(mi, wi, ci).label)
            .fontSize(this.theme.text.sm)
            .fontWeight(this.theme.text.weightNormal)
            .fontColor(this.cellAt(mi, wi, ci).foreground)
        }
        .attributeModifier(new SparkCalendarDayModifier(this.cellAt(mi, wi, ci), this.cell))
        .outline({
          width: this.cellAt(mi, wi, ci).focusRing ? 3 : 0,
          color: SparkColor.alpha(this.theme.colors.ring, 0.5),
          radius: this.theme.radiusMd
        })
        .opacity(this.cellAt(mi, wi, ci).dim)
        .accessibilityText(this.cellAt(mi, wi, ci).a11y)
        .accessibilitySelected(this.cellAt(mi, wi, ci).selected)
        .onHover((h: boolean) => {
          SparkUI.layout.reportPointerEvent(true);
          const key = SparkDates.toIso(this.cellAt(mi, wi, ci).date);
          if (h) {
            this.hoverKey = key;
          } else if (this.hoverKey === key) {
            this.hoverKey = '';
          }
        })
        .onClick(() => {
          const info = this.cellAt(mi, wi, ci);
          if (info.shown && !info.disabled) {
            this.pick(info.date);
          }
        })
      }
    }
    .width(this.cell)
    .height(this.cell)
    .backgroundColor(this.cellAt(mi, wi, ci).strip)
    .borderRadius(this.cellAt(mi, wi, ci).stripRadius)
  }

  @Builder
  monthGrid(mi: number) {
    Column() {
      Row() {
        ForEach(DAY_IDX, (ci: number) => {
          Text(ci < this.weekdays.length ? this.weekdays[ci] : '')
            .width(this.cell)
            .height(24)
            .textAlign(TextAlign.Center)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }, (ci: number) => `wd-${ci}`)
      }

      Column() {
        ForEach(WEEK_IDX, (wi: number) => {
          Row() {
            ForEach(DAY_IDX, (ci: number) => {
              this.dayCell(mi, wi, ci)
            }, (ci: number) => `d-${ci}`)
          }
          .margin({ top: ROW_GAP })
        }, (wi: number) => `w-${wi}`)
      }
      .translate({ x: this.slideX })
      .opacity(this.fade)
    }
    .margin({ top: 8 })
    .focusable(true)
    .focusBox({ strokeWidth: LengthMetrics.vp(0), margin: LengthMetrics.vp(0) })
    .onFocus(() => {
      this.gridFocused = true;
      if (!this.isShown(this.focusDate)) {
        this.focusDate = this.initialFocus();
      }
    })
    .onBlur(() => {
      this.gridFocused = false;
    })
    .onKeyEvent((e: KeyEvent): boolean => this.onKey(e))
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 16 })
        .onActionEnd((e: GestureEvent) => {
          if (e.offsetX <= -SWIPE) {
            this.page(1);
          } else if (e.offsetX >= SWIPE) {
            this.page(-1);
          }
        })
    )
  }

  @Builder
  monthView(mi: number) {
    Column() {
      this.header(mi)
      this.monthGrid(mi)
    }
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Column() {
        if (this.sideBySide) {
          Row({ space: GAP }) {
            ForEach(this.monthIndices, (mi: number) => {
              this.monthView(mi)
            }, (mi: number) => `m-${mi}`)
          }
          .alignItems(VerticalAlign.Top)
        } else {
          Column({ space: GAP }) {
            ForEach(this.monthIndices, (mi: number) => {
              this.monthView(mi)
            }, (mi: number) => `m-${mi}`)
          }
        }
      }
      .padding(PAD)
      .clip(true)
      .backgroundColor(this.bordered ? this.theme.colors.background : Color.Transparent)
      .border({
        width: this.bordered ? 1 : 0,
        color: this.theme.colors.border,
        radius: this.theme.radiusLg
      })
      .shadow(this.bordered ? this.theme.shadows.sm.toOptions() : { radius: 0, color: Color.Transparent })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_: Area, n: Area) => {
      const w = Number(n.width);
      if (Math.abs(w - this.measured) >= 0.5) {
        this.measured = w;
      }
    })
  }
}
