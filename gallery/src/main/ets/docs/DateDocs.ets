import {
  SCalendar, SDatePicker, SDateRangePicker, SparkDate, SparkDateRange, SparkDates, SparkTheme, SparkUI, SRangeCalendar,
  SSwitch
} from '@sparkui/core';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

function rangeText(r: SparkDateRange): string {
  const a = r.from !== undefined ? SparkDates.toIso(r.from) : '—';
  const b = r.to !== undefined ? SparkDates.toIso(r.to) : '—';
  return `${a} → ${b}`;
}

// ------------------------------------------------------------------------------------------------ Calendar

const CALENDAR_CODE = `@Local date: SparkDate | undefined = SparkDates.today();

SCalendar({ selected: this.date!!, bordered: true })`;

const CALENDAR_MULTIPLE_CODE = `@Local days: SparkDate[] = [];

SCalendar({ mode: 'multiple', selectedDates: this.days!!, bordered: true })`;

const CALENDAR_RANGE_CODE = `@Local range: SparkDateRange = new SparkDateRange(SparkDates.today(),
  SparkDates.addDays(SparkDates.today(), 6));

// two months side by side when there is room, otherwise one
SRangeCalendar({ range: this.range!!, bordered: true })`;

const CALENDAR_OPTIONS_CODE = `SCalendar({
  selected: this.date!!,
  locale: 'zh',
  weekStartsOn: 1,
  minDate: SparkDates.today(),
  disabledDates: (d: SparkDate) => SparkDates.weekday(d) === 0 || SparkDates.weekday(d) === 6,
  showOutsideDays: false,
  bordered: true
})`;

@ComponentV2
export struct CalendarDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local date: SparkDate | undefined = SparkDates.today();
  @Local days: SparkDate[] = [];
  @Local range: SparkDateRange = new SparkDateRange(SparkDates.today(), SparkDates.addDays(SparkDates.today(), 6));
  @Local zhDate: SparkDate | undefined = undefined;
  @Local sundayFirst: boolean = false;

  @Builder
  caption(text: string) {
    Text(text)
      .fontSize(this.theme.text.xs)
      .fontColor(this.theme.colors.mutedForeground)
      .margin({ top: 8 })
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Calendar',
        lead: 'A date field component that allows users to enter and edit date. Cells grow with the space they get; ' +
          'swipe the grid or use PageUp / PageDown to change months, arrow keys to move between days.'
      })
      DemoBlock({ code: CALENDAR_CODE }) {
        Column() {
          SCalendar({ selected: this.date!!, bordered: true, weekStartsOn: this.sundayFirst ? 0 : 1 })
          this.caption(`selected: ${this.date !== undefined ? SparkDates.format(this.date, 'PPP') : '—'}`)
          Row({ space: 8 }) {
            SSwitch({ checked: this.sundayFirst!! })
            Text('Week starts on Sunday').fontSize(this.theme.text.sm).fontColor(this.theme.colors.foreground)
          }
          .margin({ top: 8 })
        }
      }

      DocSection({ title: 'Multiple', description: "mode: 'multiple' — tap days to toggle them." })
      DemoBlock({ code: CALENDAR_MULTIPLE_CODE }) {
        Column() {
          SCalendar({ mode: 'multiple', selectedDates: this.days!!, bordered: true })
          this.caption(`${this.days.length} selected${this.days.length > 0 ? ': ' +
            this.days.map((d: SparkDate) => SparkDates.format(d, 'MMM d')).join(', ') : ''}`)
        }
      }

      DocSection({
        title: 'Range',
        description: 'SRangeCalendar shows two months side by side when it is wide enough, otherwise one.'
      })
      DemoBlock({ code: CALENDAR_RANGE_CODE }) {
        Column() {
          SRangeCalendar({ range: this.range!!, bordered: true })
          this.caption(rangeText(this.range))
        }
      }

      DocSection({
        title: 'Locale & constraints',
        description: 'locale, weekStartsOn, minDate / maxDate, disabledDates (weekends here) and showOutsideDays.'
      })
      DemoBlock({ code: CALENDAR_OPTIONS_CODE }) {
        Column() {
          SCalendar({
            selected: this.zhDate!!,
            locale: 'zh',
            weekStartsOn: 1,
            minDate: SparkDates.today(),
            disabledDates: (d: SparkDate) => SparkDates.weekday(d) === 0 || SparkDates.weekday(d) === 6,
            showOutsideDays: false,
            bordered: true
          })
          this.caption(`选中：${this.zhDate !== undefined ? SparkDates.format(this.zhDate, 'PPP', 'zh') : '—'}`)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Date Picker

const PICKER_CODE = `@Local date: SparkDate | undefined = undefined;

SDatePicker({ value: this.date!! })`;

const PICKER_FORMAT_CODE = `SDatePicker({ value: this.date!!, locale: 'zh', placeholder: '选择日期', format: 'YYYY-MM-DD' })`;

const RANGE_PICKER_CODE = `@Local range: SparkDateRange = new SparkDateRange();

SDateRangePicker({ value: this.range!! })`;

@ComponentV2
export struct DatePickerDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local date: SparkDate | undefined = undefined;
  @Local zhDate: SparkDate | undefined = undefined;
  @Local range: SparkDateRange = new SparkDateRange();

  @Builder
  caption(text: string) {
    Text(text)
      .fontSize(this.theme.text.xs)
      .fontColor(this.theme.colors.mutedForeground)
      .margin({ top: 8 })
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Date Picker',
        lead: 'A date picker component with range and presets. Opens a popover anchored to the trigger; on compact ' +
          'touch screens it becomes a bottom sheet. Picking a date closes it.'
      })
      DemoBlock({ code: PICKER_CODE }) {
        Column() {
          SDatePicker({ value: this.date!! })
          this.caption(`value: ${this.date !== undefined ? SparkDates.toIso(this.date) : 'undefined'}`)
        }
      }

      DocSection({ title: 'Locale & format', description: "format: 'PPP' (default) | 'YYYY-MM-DD' | 'MMM d, yyyy' …" })
      DemoBlock({ code: PICKER_FORMAT_CODE }) {
        SDatePicker({ value: this.zhDate!!, locale: 'zh', placeholder: '选择日期', format: 'YYYY-MM-DD' })
      }

      DocSection({ title: 'Date range', description: 'Closes once both ends are picked.' })
      DemoBlock({ code: RANGE_PICKER_CODE }) {
        Column() {
          SDateRangePicker({ value: this.range!! })
          this.caption(rangeText(this.range))
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
