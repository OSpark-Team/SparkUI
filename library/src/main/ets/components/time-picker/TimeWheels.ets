import { KeyCode } from '@kit.InputKit';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkText } from '../../core/SparkText';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { ButtonStyle, ButtonStyleModifier, ButtonVariants } from '../button/ButtonVariants';
import {
  SPARK_TIME_COLON_WIDTH, SPARK_TIME_PERIOD_GAP, sparkHour12, sparkHourEnabled, sparkMinuteOptions,
  sparkNearestEnabled, sparkNearestInHour, sparkNearestTime, sparkStepEnabled, sparkTimeInRange,
  sparkTimeWheelsWidth
} from './TimePickerLogic';

/** visible rows of a wheel column (odd: the middle one is the selection) */
export const SPARK_TIME_ROWS: number = 5;
/** row height / column width in the anchored popover (pointer) */
export const SPARK_TIME_ROW_POINTER: number = 32;
export const SPARK_TIME_COLUMN_POINTER: number = 56;
/** row height / column width in the bottom sheet (touch targets) */
export const SPARK_TIME_ROW_TOUCH: number = 44;
export const SPARK_TIME_COLUMN_TOUCH: number = 72;

/**
 * One wheel column: a snapping List whose middle row is the selection. Settling (fling end, tap, arrow keys)
 * reports the index through `onPick`; disabled rows are skipped (the wheel snaps to the nearest enabled one).
 */
@ComponentV2
struct SparkTimeColumn {
  @Param labels: string[] = [];
  @Param disabledRows: boolean[] = [];
  @Param selected: number = 0;
  @Param rowHeight: number = SPARK_TIME_ROW_POINTER;
  @Param columnWidth: number = SPARK_TIME_COLUMN_POINTER;
  @Param fontSize: number = 14;
  /** accessible name of the column (Hours / Minutes / AM-PM) */
  @Param label: string = '';
  @Event onPick: (index: number) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  /** row currently under the highlight (follows the finger while scrolling) */
  @Local center: number = 0;
  private scroller: Scroller = new Scroller();
  private scrolling: boolean = false;

  aboutToAppear(): void {
    this.center = this.selected;
  }

  @Monitor('selected')
  syncSelected(): void {
    if (!this.scrolling && this.center !== this.selected) {
      this.center = this.selected;
      this.scroller.scrollToIndex(this.selected, true, ScrollAlign.CENTER);
    }
  }

  private isDisabled(i: number): boolean {
    return this.disabledRows[i] === true;
  }

  /** the wheel came to rest: snap off disabled rows, then report */
  private settle(): void {
    this.scrolling = false;
    const i = sparkNearestEnabled(this.disabledRows, this.center);
    if (i < 0) {
      return;
    }
    if (i !== this.center) {
      this.center = i;
      this.scroller.scrollToIndex(i, true, ScrollAlign.CENTER);
    }
    if (i !== this.selected) {
      this.onPick(i);
    }
  }

  private select(i: number): void {
    if (i < 0 || i >= this.labels.length || this.isDisabled(i)) {
      return;
    }
    this.center = i;
    this.scroller.scrollToIndex(i, true, ScrollAlign.CENTER);
    this.onPick(i);
  }

  @Computed
  get edgeOffset(): number {
    return this.rowHeight * (SPARK_TIME_ROWS - 1) / 2;
  }

  build() {
    List({ scroller: this.scroller, initialIndex: this.selected }) {
      ForEach(this.labels, (text: string, i: number) => {
        ListItem() {
          Row() {
            Text(text)
              .fontSize(this.fontSize)
              .fontFeature('"tnum" on')
              .fontWeight(i === this.center ? this.theme.text.weightMedium : this.theme.text.weightNormal)
              .fontColor(i === this.center ? this.theme.colors.accentForeground : this.theme.colors.mutedForeground)
              .maxLines(1)
          }
          .width('100%')
          .height(this.rowHeight)
          .justifyContent(FlexAlign.Center)
          .opacity(this.isDisabled(i) ? 0.4 : 1)
        }
        .onClick(() => this.select(i))
        .accessibilityText(text)
        .accessibilitySelected(i === this.selected)
        .accessibilityDescription(this.isDisabled(i) ?
          sparkText(this.getUIContext(), $r('app.string.spark_state_disabled'), 'disabled') : '')
      }, (text: string) => text)
    }
    .width(this.columnWidth)
    .height(this.rowHeight * SPARK_TIME_ROWS)
    .contentStartOffset(this.edgeOffset)
    .contentEndOffset(this.edgeOffset)
    .scrollSnapAlign(ScrollSnapAlign.CENTER)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    // the wheel keeps its own drags: it never hands them to an enclosing scroll container / sheet
    .nestedScroll({ scrollForward: NestedScrollMode.SELF_ONLY, scrollBackward: NestedScrollMode.SELF_ONLY })
    .onScrollIndex((_start: number, _end: number, center: number) => {
      if (center !== this.center) {
        this.center = center;
      }
    })
    .onScrollStart(() => {
      this.scrolling = true;
    })
    .onScrollStop(() => this.settle())
    .onAppear(() => this.scroller.scrollToIndex(this.selected, false, ScrollAlign.CENTER))
    .focusable(true)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityText(this.label)
    .onKeyEvent((e: KeyEvent) => {
      if (e.type !== KeyType.Down) {
        return;
      }
      if (e.keyCode === KeyCode.KEYCODE_DPAD_UP) {
        this.select(sparkStepEnabled(this.disabledRows, this.selected, -1));
      } else if (e.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
        this.select(sparkStepEnabled(this.disabledRows, this.selected, 1));
      } else if (e.keyCode === KeyCode.KEYCODE_MOVE_HOME) {
        this.select(sparkNearestEnabled(this.disabledRows, 0));
      } else if (e.keyCode === KeyCode.KEYCODE_MOVE_END) {
        this.select(sparkNearestEnabled(this.disabledRows, this.labels.length - 1));
      }
    })
  }
}

/**
 * One set of time wheels — hours : minutes (+ AM / PM with `hour12`) over a selection highlight, with soft
 * fades at the top and bottom edge. Shared by STimePicker and STimeRangePicker. `value` is minutes since
 * midnight; every wheel that comes to rest reports the resulting time through `onChange` (snapped to the
 * minute step and kept within [minBound, maxBound]).
 *
 * Touch routing: the wheels are the only hit-testable layer. The highlight and the fades are decoration
 * stacked below / above the Lists, and every node of them is `HitTestMode.None` — a `None` parent alone is
 * not enough, because its children still hit-test with `Default` and a hit on the top-most Stack child stops
 * the Stack from testing the children below it (the Lists never received the drag on touch screens).
 */
@ComponentV2
export struct SparkTimeWheels {
  @Param value: number = 0;
  @Param hour12: boolean = false;
  @Param minuteStep: number = 1;
  /** selectable range in minutes, -1 = open */
  @Param minBound: number = -1;
  @Param maxBound: number = -1;
  @Param rowHeight: number = SPARK_TIME_ROW_POINTER;
  @Param columnWidth: number = SPARK_TIME_COLUMN_POINTER;
  @Param fontSize: number = 14;
  /** surface colour behind the wheels (the edge fades blend into it) */
  @Param surfaceColor: string = '#00000000';
  @Param am: string = 'AM';
  @Param pm: string = 'PM';
  /** prefix of the columns' accessible names (e.g. "Start" → "Start Hours") */
  @Param labelPrefix: string = '';
  @Event onChange: (minutes: number) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get wheelHour(): number {
    return Math.floor(this.value / 60);
  }

  @Computed
  get wheelMinute(): number {
    return this.value % 60;
  }

  /** 0 = AM, 1 = PM */
  @Computed
  get period(): number {
    return this.wheelHour < 12 ? 0 : 1;
  }

  @Computed
  get minuteOptions(): number[] {
    return sparkMinuteOptions(this.minuteStep);
  }

  /** hour shown by row `i` of the hour column */
  private hourAt(i: number): number {
    return this.hour12 ? this.period * 12 + i : i;
  }

  @Computed
  get hourLabels(): string[] {
    const out: string[] = [];
    for (let i = 0; i < (this.hour12 ? 12 : 24); i++) {
      out.push(this.hour12 ? `${sparkHour12(i)}` : `${i < 10 ? '0' : ''}${i}`);
    }
    return out;
  }

  @Computed
  get hourDisabled(): boolean[] {
    const out: boolean[] = [];
    for (let i = 0; i < (this.hour12 ? 12 : 24); i++) {
      out.push(!sparkHourEnabled(this.hourAt(i), this.minuteStep, this.minBound, this.maxBound));
    }
    return out;
  }

  @Computed
  get hourIndex(): number {
    return this.hour12 ? this.wheelHour % 12 : this.wheelHour;
  }

  @Computed
  get minuteLabels(): string[] {
    return this.minuteOptions.map((m: number) => `${m < 10 ? '0' : ''}${m}`);
  }

  @Computed
  get minuteDisabled(): boolean[] {
    return this.minuteOptions.map((m: number) =>
      !sparkTimeInRange(this.wheelHour * 60 + m, this.minBound, this.maxBound));
  }

  @Computed
  get minuteIndex(): number {
    const opts = this.minuteOptions;
    for (let i = 0; i < opts.length; i++) {
      if (opts[i] === this.wheelMinute) {
        return i;
      }
    }
    return 0;
  }

  @Computed
  get periodLabels(): string[] {
    return [this.am, this.pm];
  }

  @Computed
  get periodDisabled(): boolean[] {
    const out: boolean[] = [];
    for (let p = 0; p < 2; p++) {
      let any = false;
      for (let h = p * 12; h < p * 12 + 12 && !any; h++) {
        any = sparkHourEnabled(h, this.minuteStep, this.minBound, this.maxBound);
      }
      out.push(!any);
    }
    return out;
  }

  @Computed
  get wheelsWidth(): number {
    return sparkTimeWheelsWidth(this.columnWidth, this.hour12);
  }

  private columnLabel(name: string): string {
    return this.labelPrefix.length > 0 ? `${this.labelPrefix} ${name}` : name;
  }

  // ---------------------------------------------------------------------------------------------- picking

  private emit(t: number): void {
    if (t >= 0) {
      this.onChange(t);
    }
  }

  private pickHour(i: number): void {
    this.emit(sparkNearestInHour(this.hourAt(i), this.wheelMinute, this.minuteStep, this.minBound,
      this.maxBound));
  }

  private pickMinute(i: number): void {
    const t = this.wheelHour * 60 + (this.minuteOptions[i] ?? 0);
    if (sparkTimeInRange(t, this.minBound, this.maxBound)) {
      this.emit(t);
    }
  }

  private pickPeriod(p: number): void {
    const h = p * 12 + this.wheelHour % 12;
    const t = sparkNearestInHour(h, this.wheelMinute, this.minuteStep, this.minBound, this.maxBound);
    this.emit(t >= 0 ? t : sparkNearestTime(h * 60 + this.wheelMinute, this.minuteStep, this.minBound,
      this.maxBound));
  }

  /** a soft edge fade; decoration only, never hit-tested */
  @Builder
  fade(top: boolean) {
    Column()
      .width('100%')
      .height(this.rowHeight * 1.5)
      .linearGradient({
        direction: top ? GradientDirection.Bottom : GradientDirection.Top,
        colors: [[this.surfaceColor, 0], [SparkColor.alpha(this.surfaceColor, 0), 1]]
      })
      .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack() {
      // selection highlight behind the middle row
      Row()
        .width('100%')
        .height(this.rowHeight)
        .borderRadius(this.theme.radiusSm)
        .backgroundColor(this.theme.colors.accent)
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
      Row() {
        SparkTimeColumn({
          labels: this.hourLabels,
          disabledRows: this.hourDisabled,
          selected: this.hourIndex,
          rowHeight: this.rowHeight,
          columnWidth: this.columnWidth,
          fontSize: this.fontSize,
          label: this.columnLabel(sparkText(this.getUIContext(), $r('app.string.spark_hours'), 'Hours')),
          onPick: (i: number) => this.pickHour(i)
        })
        Text(':')
          .width(SPARK_TIME_COLON_WIDTH)
          .textAlign(TextAlign.Center)
          .fontSize(this.fontSize)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.accentForeground)
          .accessibilityLevel('no')
        SparkTimeColumn({
          labels: this.minuteLabels,
          disabledRows: this.minuteDisabled,
          selected: this.minuteIndex,
          rowHeight: this.rowHeight,
          columnWidth: this.columnWidth,
          fontSize: this.fontSize,
          label: this.columnLabel(sparkText(this.getUIContext(), $r('app.string.spark_minutes'), 'Minutes')),
          onPick: (i: number) => this.pickMinute(i)
        })
        if (this.hour12) {
          SparkTimeColumn({
            labels: this.periodLabels,
            disabledRows: this.periodDisabled,
            selected: this.period,
            rowHeight: this.rowHeight,
            columnWidth: this.columnWidth,
            fontSize: this.fontSize,
            label: this.columnLabel(`${this.am} / ${this.pm}`),
            onPick: (p: number) => this.pickPeriod(p)
          })
            .margin({ left: SPARK_TIME_PERIOD_GAP })
        }
      }
      .alignItems(VerticalAlign.Center)
      // soft fade at the top / bottom edge of the wheels: the container and both fades are HitTestMode.None
      Column() {
        this.fade(true)
        this.fade(false)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
    }
    .width(this.wheelsWidth)
    .height(this.rowHeight * SPARK_TIME_ROWS)
    .alignContent(Alignment.Center)
  }
}

/** Outline-button trigger (the SDatePicker trigger with a clock icon); muted text while empty. */
@ComponentV2
export struct SparkTimeTrigger {
  @Param text: ResourceStr = '';
  @Param empty: boolean = true;
  @Param disabled: boolean = false;
  @Param triggerWidth: Length = 140;
  @Param triggerKey: string = '';
  @Param open: boolean = false;
  @Param label: string = '';
  /** extra spoken detail after the value (e.g. "next day") */
  @Param detail: string = '';
  @Event onActivate: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get styles(): ButtonStyle {
    return ButtonVariants.resolve(this.theme, 'outline', 'default');
  }

  @Computed
  get recipe(): ButtonStyleModifier {
    return new ButtonStyleModifier(this.styles, this.ix.hovered, this.disabled, 1);
  }

  build() {
    Button() {
      Row({ space: 8 }) {
        SIcon({ name: 'clock', sizing: 16, color: this.empty ? this.theme.colors.mutedForeground :
          this.theme.colors.foreground })
        Text(this.text)
          .layoutWeight(1)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightNormal)
          .fontFeature('"tnum" on')
          .fontColor(this.empty ? this.theme.colors.mutedForeground : this.theme.colors.foreground)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(this.recipe)
    .width(this.triggerWidth)
    .padding({ left: 12, right: 12, top: 0, bottom: 0 })
    .id(this.triggerKey)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.label)
    .accessibilityDescription(`${typeof this.text === 'string' ? this.text : ''}${this.detail.length > 0 ?
      ` ${this.detail}` : ''}, ${this.open ?
      sparkText(this.getUIContext(), $r('app.string.spark_state_expanded'), 'expanded') :
      sparkText(this.getUIContext(), $r('app.string.spark_state_collapsed'), 'collapsed')}`)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => {
      if (!this.disabled) {
        this.onActivate();
      }
    })
  }
}
