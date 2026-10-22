import { sparkText, sparkTextOf } from '../../core/SparkText';
import { SparkUI } from '../../core/SparkUI';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { sparkSheetHandle } from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkSurface, sparkSurfaceDefaults, SparkSurfaceStyle, SparkSurfaceTokens
} from '../../theme/tokens/SparkTokenReader';
import { SButton } from '../button/SButton';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';
import {
  SPARK_TIME_SET_GAP, sparkDefaultRangeEnd, sparkFitColumnWidth, sparkFormatTime, sparkNearestTime, sparkParseTime,
  sparkTimeRangeLabel, sparkTimeRangeNextDay, sparkTimeWheelsWidth
} from './TimePickerLogic';
import {
  SPARK_TIME_COLUMN_POINTER, SPARK_TIME_COLUMN_TOUCH, SPARK_TIME_ROW_POINTER, SPARK_TIME_ROW_TOUCH, SparkTimeTrigger,
  SparkTimeWheels
} from './TimeWheels';

/** height of the "Start" / "End" caption row above each wheel set (vp) */
const CAPTION_HEIGHT: number = 24;
/** horizontal padding of the bottom-sheet panel (vp) */
const SHEET_PADDING: number = 16;

/**
 * Time-of-day range picker: the {@link SDateRangePicker} pattern for two `HH:mm` values.
 *
 * ```
 * STimeRangePicker({ start: this.from!!, end: this.to!! })                        // '09:00 – 17:30'
 * STimeRangePicker({ start: this.from!!, end: this.to!!, minuteStep: 15, hour12: true })
 * STimeRangePicker({ start: this.a, end: this.b, onValueChange: (start: string, end: string) => ... })
 * ```
 * One outline-button trigger with a clock icon showing `start – end` (`triggerWidth`, default 200vp). It opens
 * two sets of snapping wheels side by side — Start | End — in a popover below the trigger, and in a bottom
 * sheet with touch-sized rows and a Done button on compact touch windows (`adaptive: 'auto'`). Both ends
 * update live whenever a wheel comes to rest; tapping outside closes it. An empty end starts one hour after
 * the start.
 *
 * Ranges may cross midnight: an end at or before the start (`22:00 – 06:00`) ends on the next day, and the
 * End side then shows a small "Next day" hint. Values are always 24-hour `HH:mm` strings; `hour12` only
 * changes what is shown; `minuteStep` (1, 5, 15 …) sets the minute options of both ends.
 */
@ComponentV2
export struct STimeRangePicker {
  /** start, `HH:mm` (24-hour); undefined = empty (use with `!!`) */
  @Param start: string | undefined = undefined;
  @Event $start: (v: string) => void = () => {
  };
  @Event onStartChange: (v: string) => void = () => {
  };
  /** end, `HH:mm` (24-hour); at or before `start` = the next day (use with `!!`) */
  @Param end: string | undefined = undefined;
  @Event $end: (v: string) => void = () => {
  };
  @Event onEndChange: (v: string) => void = () => {
  };
  /** both ends, whenever either changes */
  @Event onValueChange: (start: string, end: string) => void = () => {
  };
  @Param placeholder: ResourceStr = $r('app.string.spark_pick_time_range');
  /** caption above the start wheels (default "Start") */
  @Param startLabel: ResourceStr = $r('app.string.spark_time_start');
  /** caption above the end wheels (default "End") */
  @Param endLabel: ResourceStr = $r('app.string.spark_time_end');
  /** show a 12-hour clock with AM / PM columns (values stay `HH:mm`) */
  @Param hour12: boolean = false;
  /** minute options: 1 (default), 5, 15 … (1..60) */
  @Param minuteStep: number = 1;
  @Param disabled: boolean = false;
  @Param triggerWidth: Length = 200;
  /** Accessible name of the trigger (default "Pick a time range"). */
  @Param label: string | undefined = undefined;
  @Param adaptive: SparkAdaptive = 'auto';
  /** Popover surface tokens (instance → `--popover-*` → recipe). */
  @Param surfaceTokens: SparkSurfaceTokens = {};
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  /** committed ends in minutes since midnight, -1 = empty */
  @Local currentStart: number = -1;
  @Local currentEnd: number = -1;
  /** times shown by the wheels while open */
  @Local wheelStart: number = 0;
  @Local wheelEnd: number = 60;
  @Local sheet: boolean = false;
  /** wheel column width of this opening (narrower in a bottom sheet on small phones) */
  @Local columnWidth: number = SPARK_TIME_COLUMN_POINTER;
  @Local disclosure: SparkDisclosure = new SparkDisclosure();
  private binding: OverlayBinding = new OverlayBinding();

  aboutToAppear(): void {
    this.currentStart = sparkParseTime(this.start);
    this.currentEnd = sparkParseTime(this.end);
    this.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
    this.disclosure.triggerUniqueId = this.getUniqueId();
    this.disclosure.emit = (open: boolean) => this.onOpenChange(open);
    this.binding.attach(this.getUIContext(), this.disclosure, (scope: SparkOverlayScope) => {
      this.sheet = sparkUseSheet(this.adaptive);
      this.columnWidth = this.sheet ? this.sheetColumnWidth() : SPARK_TIME_COLUMN_POINTER;
      this.initWheels();
      scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
      scope.motionKey = this.sheet ? 'sheet' : 'popover';
      scope.modal = this.sheet;
      scope.dismissOnOutside = true;
      scope.anchor = this.disclosure.anchorRect(this.getUIContext());
      scope.side = 'bottom';
      scope.alignment = 'start';
      scope.sideOffset = 4;
      scope.content = this.panel;
      scope.theme = this.theme;
      scope.layout = this.layout;
    });
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @Monitor('start')
  syncStart(): void {
    this.currentStart = sparkParseTime(this.start);
    if (this.currentStart >= 0 && this.currentStart !== this.wheelStart) {
      this.wheelStart = this.currentStart;
    }
  }

  @Monitor('end')
  syncEnd(): void {
    this.currentEnd = sparkParseTime(this.end);
    if (this.currentEnd >= 0 && this.currentEnd !== this.wheelEnd) {
      this.wheelEnd = this.currentEnd;
    }
  }

  @Monitor('disabled')
  syncDisabled(): void {
    if (this.disabled) {
      this.disclosure.setOpen(false);
    }
  }

  /** both columns of touch size when they fit the window, else narrower (two sets side by side) */
  private sheetColumnWidth(): number {
    const env = this.layout.env;
    const w = SparkUI.layout.root.width - env.safeArea.left - env.safeArea.right - 2 * SHEET_PADDING;
    return sparkFitColumnWidth(w, 2, this.hour12, SPARK_TIME_COLUMN_TOUCH);
  }

  /** the committed ends, or "now" and one hour later — snapped to the minute step */
  private initWheels(): void {
    const now = new Date();
    const base = this.currentStart >= 0 ? this.currentStart : now.getHours() * 60 + now.getMinutes();
    const s = sparkNearestTime(base, this.minuteStep, -1, -1);
    this.wheelStart = s >= 0 ? s : base;
    if (this.currentEnd >= 0) {
      const e = sparkNearestTime(this.currentEnd, this.minuteStep, -1, -1);
      this.wheelEnd = e >= 0 ? e : this.currentEnd;
    } else {
      this.wheelEnd = sparkDefaultRangeEnd(this.wheelStart, this.minuteStep);
    }
  }

  @Computed
  get am(): string {
    return sparkText(this.getUIContext(), $r('app.string.spark_time_am'), 'AM');
  }

  @Computed
  get pm(): string {
    return sparkText(this.getUIContext(), $r('app.string.spark_time_pm'), 'PM');
  }

  @Computed
  get nextDayText(): string {
    return sparkText(this.getUIContext(), $r('app.string.spark_time_next_day'), 'Next day');
  }

  @Computed
  get startText(): string {
    return sparkTextOf(this.getUIContext(), this.startLabel, 'Start');
  }

  @Computed
  get endText(): string {
    return sparkTextOf(this.getUIContext(), this.endLabel, 'End');
  }

  @Computed
  get text(): string | undefined {
    return sparkTimeRangeLabel(this.currentStart, this.currentEnd, this.hour12, this.am, this.pm);
  }

  @Computed
  get accessibleName(): string {
    return this.label ?? sparkText(this.getUIContext(), $r('app.string.spark_pick_time_range'), 'Pick a time range');
  }

  /** the wheels' end is on the next day (hint on the End side) */
  @Computed
  get wheelNextDay(): boolean {
    return sparkTimeRangeNextDay(this.wheelStart, this.wheelEnd);
  }

  @Computed
  get surface(): SparkSurfaceStyle {
    const t = this.theme;
    return sparkSurface(t, 'popover', sparkSurfaceDefaults(t.colors.popover, t.colors.border, t.borderWidth,
      t.radiusMd, 4, t.shadows.md), this.surfaceTokens);
  }

  @Computed
  get rowHeight(): number {
    return this.sheet ? SPARK_TIME_ROW_TOUCH : SPARK_TIME_ROW_POINTER;
  }

  @Computed
  get wheelsWidth(): number {
    return sparkTimeWheelsWidth(this.columnWidth, this.hour12);
  }

  @Computed
  get fontSize(): number {
    return this.sheet ? this.theme.text.base : this.theme.text.sm;
  }

  // ---------------------------------------------------------------------------------------------- picking

  /** commit both ends as shown by the wheels; emits only what changed */
  private commit(): void {
    const s = this.wheelStart;
    const e = this.wheelEnd;
    const startChanged = s !== this.currentStart;
    const endChanged = e !== this.currentEnd;
    if (!startChanged && !endChanged) {
      return;
    }
    this.currentStart = s;
    this.currentEnd = e;
    const sv = sparkFormatTime(s);
    const ev = sparkFormatTime(e);
    if (startChanged) {
      this.$start(sv);
      this.onStartChange(sv);
    }
    if (endChanged) {
      this.$end(ev);
      this.onEndChange(ev);
    }
    this.onValueChange(sv, ev);
  }

  private pickStart(t: number): void {
    this.wheelStart = t;
    this.commit();
  }

  private pickEnd(t: number): void {
    this.wheelEnd = t;
    this.commit();
  }

  private done(): void {
    this.commit();
    this.disclosure.setOpen(false);
  }

  @Builder
  caption(isEnd: boolean) {
    Row({ space: 6 }) {
      Text(isEnd ? this.endText : this.startText)
        .fontSize(this.theme.text.xs)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.mutedForeground)
        .maxLines(1)
      if (isEnd && this.wheelNextDay) {
        Text(this.nextDayText)
          .fontSize(this.theme.text.xs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.primary)
          .padding({ left: 6, right: 6 })
          .height(18)
          .borderRadius(9)
          .backgroundColor(this.theme.colors.accent)
          .maxLines(1)
      }
    }
    .width('100%')
    .height(CAPTION_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(isEnd && this.wheelNextDay ? `${this.endText}, ${this.nextDayText}` : (isEnd ? this.endText :
      this.startText))
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      Row({ space: SPARK_TIME_SET_GAP }) {
        Column() {
          this.caption(false)
          SparkTimeWheels({
            value: this.wheelStart,
            hour12: this.hour12,
            minuteStep: this.minuteStep,
            rowHeight: this.rowHeight,
            columnWidth: this.columnWidth,
            fontSize: this.fontSize,
            surfaceColor: this.surface.background,
            am: this.am,
            pm: this.pm,
            labelPrefix: this.startText,
            onChange: (t: number) => this.pickStart(t)
          })
        }
        .width(this.wheelsWidth)
        Column() {
          this.caption(true)
          SparkTimeWheels({
            value: this.wheelEnd,
            hour12: this.hour12,
            minuteStep: this.minuteStep,
            rowHeight: this.rowHeight,
            columnWidth: this.columnWidth,
            fontSize: this.fontSize,
            surfaceColor: this.surface.background,
            am: this.am,
            pm: this.pm,
            labelPrefix: this.endText,
            onChange: (t: number) => this.pickEnd(t)
          })
        }
        .width(this.wheelsWidth)
      }
      .alignItems(VerticalAlign.Top)
      if (this.sheet) {
        Row() {
          SButton({ text: $r('app.string.spark_done'), block: true })
            .onClick(() => this.done())
        }
        .width('100%')
        .padding({ top: 12 })
      }
    }
    .width(this.sheet ? '100%' :
      2 * this.wheelsWidth + SPARK_TIME_SET_GAP + 2 * this.surface.padding + 2 * this.surface.borderWidth)
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: this.sheet ? SHEET_PADDING : this.surface.padding,
      right: this.sheet ? SHEET_PADDING : this.surface.padding,
      top: this.sheet ? 8 : this.surface.padding,
      bottom: (this.sheet ? 16 : this.surface.padding) + (this.sheet ? this.layout.env.safeArea.bottom : 0)
    })
    .backgroundColor(this.surface.background)
    .border({
      width: this.sheet ? { top: this.surface.borderWidth } : this.surface.borderWidth,
      color: this.surface.borderColor,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.surface.radius
    })
    .shadow(SparkTokenOverride.shadowOptions(this.surface.shadow))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    SparkTimeTrigger({
      text: this.text ?? this.placeholder,
      empty: this.text === undefined,
      disabled: this.disabled,
      triggerWidth: this.triggerWidth,
      triggerKey: sparkTriggerKey(this.getUniqueId()),
      open: this.disclosure.open,
      label: this.accessibleName,
      detail: sparkTimeRangeNextDay(this.currentStart, this.currentEnd) ? this.nextDayText : '',
      onActivate: () => this.disclosure.toggle()
    })
  }
}
