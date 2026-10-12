import { SCalendar, SparkDateMatcher } from './SCalendar';
import { SparkDate, SparkDateLocale, SparkDateRange, SparkWeekStart } from './SparkDate';

/** cell size the two-month layout is designed for (vp) */
const TWO_UP_CELL: number = 36;
const GAP: number = 16;
const PAD: number = 12;

/**
 * shadcn-vue `RangeCalendar`: {@link SCalendar} in range mode that shows two months side by side when its own
 * width allows (≥ 2 × 7 × 36vp + gap + padding), otherwise one.
 *
 * ```
 * SRangeCalendar({ range: this.range!! })
 * SRangeCalendar({ range: this.range!!, bordered: true, minDate: SparkDates.today() })
 * ```
 * `numberOfMonths` pins the month count (undefined = automatic).
 */
@ComponentV2
export struct SRangeCalendar {
  @Param range: SparkDateRange = new SparkDateRange();
  @Event $range: (r: SparkDateRange) => void = () => {
  };
  @Event onRangeChange: (r: SparkDateRange) => void = () => {
  };
  @Param month: SparkDate | undefined = undefined;
  @Event $month: (m: SparkDate) => void = () => {
  };
  @Event onMonthChange: (m: SparkDate) => void = () => {
  };
  @Param defaultMonth: SparkDate | undefined = undefined;
  @Param minDate: SparkDate | undefined = undefined;
  @Param maxDate: SparkDate | undefined = undefined;
  @Param disabledDates: SparkDateMatcher | undefined = undefined;
  @Param weekStartsOn: SparkWeekStart = 1;
  @Param locale: SparkDateLocale = 'en';
  @Param showOutsideDays: boolean = true;
  /** undefined = 2 when they fit, else 1 */
  @Param numberOfMonths: number | undefined = undefined;
  @Param cellSize: number | undefined = undefined;
  @Param bordered: boolean = false;
  @Local measured: number = 0;

  @Computed
  get months(): number {
    if (this.numberOfMonths !== undefined) {
      return this.numberOfMonths;
    }
    const need = 2 * 7 * TWO_UP_CELL + GAP + 2 * PAD + (this.bordered ? 2 : 0);
    return this.measured >= need ? 2 : 1;
  }

  build() {
    Column() {
      SCalendar({
        mode: 'range',
        range: this.range,
        onRangeChange: (r: SparkDateRange) => {
          this.$range(r);
          this.onRangeChange(r);
        },
        month: this.month,
        onMonthChange: (m: SparkDate) => {
          this.$month(m);
          this.onMonthChange(m);
        },
        defaultMonth: this.defaultMonth,
        minDate: this.minDate,
        maxDate: this.maxDate,
        disabledDates: this.disabledDates,
        weekStartsOn: this.weekStartsOn,
        locale: this.locale,
        showOutsideDays: this.showOutsideDays,
        numberOfMonths: this.months,
        cellSize: this.cellSize,
        bordered: this.bordered
      })
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => {
      const w = Number(n.width);
      if (Math.abs(w - this.measured) >= 0.5) {
        this.measured = w;
      }
    })
  }
}
