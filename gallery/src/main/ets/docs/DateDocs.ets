import {
  SCalendar, SDatePicker, SDateRangePicker, SparkDate, SparkDateRange, SparkDates, SparkTheme, SparkUI, SRangeCalendar,
  SButton, SDrawer, SDrawerClose, SDrawerContent, SDrawerDescription, SDrawerFooter, SDrawerHeader, SDrawerTitle,
  SDrawerTrigger, sparkParseTime, SSwitch, STimePicker, STimeRangePicker, sparkTimeRangeNextDay
} from '@ospark/sparkui';
import { DemoBlock, DemoCaption, DocHeader, DocSection } from '../shell/DocKit';

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
          DemoCaption({ text: `selected: ${this.date !== undefined ? SparkDates.format(this.date, 'PPP') : '—'}` })
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
          DemoCaption({ text: `${this.days.length} selected${this.days.length > 0 ? ': ' +
            this.days.map((d: SparkDate) => SparkDates.format(d, 'MMM d')).join(', ') : ''}` })
        }
      }

      DocSection({
        title: 'Range',
        description: 'SRangeCalendar shows two months side by side when it is wide enough, otherwise one.'
      })
      DemoBlock({ code: CALENDAR_RANGE_CODE }) {
        Column() {
          SRangeCalendar({ range: this.range!!, bordered: true })
          DemoCaption({ text: rangeText(this.range) })
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
          DemoCaption({ text: `选中：${this.zhDate !== undefined ? SparkDates.format(this.zhDate, 'PPP', 'zh') : '—'}` })
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
          DemoCaption({ text: `value: ${this.date !== undefined ? SparkDates.toIso(this.date) : 'undefined'}` })
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
          DemoCaption({ text: rangeText(this.range) })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Time Picker

const TIME_CODE = `@Local time: string | undefined = undefined;

STimePicker({ value: this.time!! })`;

const TIME_12H_CODE = `STimePicker({ value: this.alarm!!, hour12: true, minuteStep: 5 })`;

const TIME_RANGE_CODE = `STimePicker({ value: this.meeting!!, minuteStep: 15, minTime: '09:00', maxTime: '17:30' })`;

const TIME_DISABLED_CODE = `STimePicker({ value: '22:00', disabled: true })`;

const TIME_DRAWER_CODE = `SDrawer({ open: this.drawerOpen!! }) {
  SDrawerTrigger() { SButton({ text: 'Set alarm', variant: 'outline' }) }
  SDrawerContent() {
    SDrawerHeader() {
      SDrawerTitle({ text: 'Alarm' })
      SDrawerDescription({ text: 'Drag the wheels up and down to pick a time.' })
    }
    STimePicker({ value: this.wake!!, minuteStep: 5 })
    SDrawerFooter() {
      SDrawerClose() { SButton({ text: 'Done' }) }
    }
  }
}`;

@ComponentV2
export struct TimePickerDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local time: string | undefined = undefined;
  @Local alarm: string | undefined = '07:30';
  @Local meeting: string | undefined = '10:00';
  @Local wake: string | undefined = '06:45';
  @Local drawerOpen: boolean = false;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Time Picker',
        lead: 'Picks a time of day with snapping hour and minute wheels. Opens a popover anchored to the trigger; ' +
          'on compact touch screens it becomes a bottom sheet. The value updates as soon as a wheel comes to rest.'
      })
      DemoBlock({ code: TIME_CODE }) {
        Column() {
          STimePicker({ value: this.time!! })
          DemoCaption({ text: `value: ${this.time ?? 'undefined'}` })
        }
      }

      DocSection({
        title: '12-hour clock & minute step',
        description: 'hour12 adds an AM / PM column (values stay HH:mm); minuteStep: 1 | 5 | 15 …'
      })
      DemoBlock({ code: TIME_12H_CODE }) {
        Column() {
          STimePicker({ value: this.alarm!!, hour12: true, minuteStep: 5 })
          DemoCaption({ text: `value: ${this.alarm ?? 'undefined'}` })
        }
      }

      DocSection({ title: 'Min & max', description: 'Times outside minTime – maxTime are dimmed and skipped.' })
      DemoBlock({ code: TIME_RANGE_CODE }) {
        Column() {
          STimePicker({ value: this.meeting!!, minuteStep: 15, minTime: '09:00', maxTime: '17:30' })
          DemoCaption({ text: `value: ${this.meeting ?? 'undefined'}` })
        }
      }

      DocSection({
        title: 'Inside a drawer',
        description: 'The wheels open in their own layer above the drawer, so dragging them scrolls the wheels; ' +
          'the drawer\'s drag-to-dismiss never takes the gesture.'
      })
      DemoBlock({ code: TIME_DRAWER_CODE }) {
        Column() {
          SDrawer({ open: this.drawerOpen!! }) {
            SDrawerTrigger() {
              SButton({ text: 'Set alarm', variant: 'outline' })
            }
            SDrawerContent() {
              SDrawerHeader() {
                SDrawerTitle({ text: 'Alarm' })
                SDrawerDescription({ text: 'Drag the wheels up and down to pick a time.' })
              }
              Row() {
                STimePicker({ value: this.wake!!, minuteStep: 5 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              SDrawerFooter() {
                SDrawerClose() {
                  SButton({ text: 'Done' }).width('100%')
                }
              }
            }
          }
          DemoCaption({ text: `value: ${this.wake ?? 'undefined'}` })
        }
      }

      DocSection({ title: 'Disabled' })
      DemoBlock({ code: TIME_DISABLED_CODE }) {
        STimePicker({ value: '22:00', disabled: true })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Time Range Picker

const TIME_RANGE_PICKER_CODE = `@Local from: string | undefined = undefined;
@Local to: string | undefined = undefined;

STimeRangePicker({ start: this.from!!, end: this.to!! })`;

const TIME_RANGE_NIGHT_CODE = `STimeRangePicker({ start: this.quietStart!!, end: this.quietEnd!!, minuteStep: 15 })`;

const TIME_RANGE_12H_CODE = `STimeRangePicker({ start: this.shiftStart!!, end: this.shiftEnd!!, hour12: true, minuteStep: 5 })`;

const TIME_RANGE_DRAWER_CODE = `SDrawer({ open: this.open!! }) {
  SDrawerTrigger() { SButton({ text: 'Quiet hours', variant: 'outline' }) }
  SDrawerContent() {
    SDrawerHeader() {
      SDrawerTitle({ text: 'Quiet hours' })
      SDrawerDescription({ text: 'Notifications are muted in this window.' })
    }
    STimeRangePicker({ start: this.quietStart!!, end: this.quietEnd!!, minuteStep: 15 })
    SDrawerFooter() {
      SDrawerClose() { SButton({ text: 'Done' }) }
    }
  }
}`;

const TIME_RANGE_DISABLED_CODE = `STimeRangePicker({ start: '09:00', end: '17:30', disabled: true })`;

function timeRangeText(start: string | undefined, end: string | undefined): string {
  const next = sparkTimeRangeNextDay(sparkParseTime(start), sparkParseTime(end));
  return `start: ${start ?? 'undefined'} · end: ${end ?? 'undefined'}${next ? ' (next day)' : ''}`;
}

@ComponentV2
export struct TimeRangePickerDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local from: string | undefined = undefined;
  @Local to: string | undefined = undefined;
  @Local quietStart: string | undefined = '22:00';
  @Local quietEnd: string | undefined = '07:00';
  @Local shiftStart: string | undefined = '08:30';
  @Local shiftEnd: string | undefined = '17:00';
  @Local open: boolean = false;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Time Range Picker',
        lead: 'Picks a start and an end time with two sets of snapping wheels side by side. Ranges may cross ' +
          'midnight: an end at or before the start is on the next day. Opens a popover; on compact touch screens ' +
          'it becomes a bottom sheet.'
      })
      DemoBlock({ code: TIME_RANGE_PICKER_CODE }) {
        Column() {
          STimeRangePicker({ start: this.from!!, end: this.to!! })
          DemoCaption({ text: timeRangeText(this.from, this.to) })
        }
      }

      DocSection({
        title: 'Across midnight',
        description: 'An end at or before the start ends on the next day; the End wheels show a "Next day" hint.'
      })
      DemoBlock({ code: TIME_RANGE_NIGHT_CODE }) {
        Column() {
          STimeRangePicker({ start: this.quietStart!!, end: this.quietEnd!!, minuteStep: 15 })
          DemoCaption({ text: timeRangeText(this.quietStart, this.quietEnd) })
        }
      }

      DocSection({
        title: '12-hour clock & minute step',
        description: 'hour12 adds AM / PM columns to both ends (values stay HH:mm).'
      })
      DemoBlock({ code: TIME_RANGE_12H_CODE }) {
        Column() {
          STimeRangePicker({ start: this.shiftStart!!, end: this.shiftEnd!!, hour12: true, minuteStep: 5 })
          DemoCaption({ text: timeRangeText(this.shiftStart, this.shiftEnd) })
        }
      }

      DocSection({
        title: 'Inside a drawer',
        description: 'The wheels open in their own layer above the drawer and keep vertical drags to themselves.'
      })
      DemoBlock({ code: TIME_RANGE_DRAWER_CODE }) {
        Column() {
          SDrawer({ open: this.open!! }) {
            SDrawerTrigger() {
              SButton({ text: 'Quiet hours', variant: 'outline' })
            }
            SDrawerContent() {
              SDrawerHeader() {
                SDrawerTitle({ text: 'Quiet hours' })
                SDrawerDescription({ text: 'Notifications are muted in this window.' })
              }
              Row() {
                STimeRangePicker({ start: this.quietStart!!, end: this.quietEnd!!, minuteStep: 15 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              SDrawerFooter() {
                SDrawerClose() {
                  SButton({ text: 'Done' }).width('100%')
                }
              }
            }
          }
          DemoCaption({ text: timeRangeText(this.quietStart, this.quietEnd) })
        }
      }

      DocSection({ title: 'Disabled' })
      DemoBlock({ code: TIME_RANGE_DISABLED_CODE }) {
        STimeRangePicker({ start: '09:00', end: '17:30', disabled: true })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
