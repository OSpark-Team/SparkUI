import { sparkText } from '../../core/SparkText';
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
import { sparkFormatTime, sparkNearestTime, sparkParseTime, sparkTimeLabel, sparkTimeWheelsWidth } from './TimePickerLogic';
import {
  SPARK_TIME_COLUMN_POINTER, SPARK_TIME_COLUMN_TOUCH, SPARK_TIME_ROW_POINTER, SPARK_TIME_ROW_TOUCH, SparkTimeTrigger,
  SparkTimeWheels
} from './TimeWheels';

/**
 * Time-of-day picker (the {@link SDatePicker} pattern for `HH:mm`).
 *
 * ```
 * STimePicker({ value: this.time!! })                                   // '09:30'
 * STimePicker({ value: this.time!!, hour12: true, minuteStep: 15 })      // shows '9:30 AM'
 * STimePicker({ value: this.start, minTime: '08:00', maxTime: '20:00', onValueChange: (v: string) => ... })
 * ```
 * Outline-button trigger with a clock icon (`triggerWidth`, default 140vp); opens two snapping wheel columns
 * (hours, minutes — plus AM / PM with `hour12`) in a popover below the trigger, and in a bottom sheet with
 * touch-sized rows and a Done button on compact touch windows (`adaptive: 'auto'`). The value updates live
 * whenever a column comes to rest (fling, tap, arrow keys); tapping outside closes it.
 *
 * Values are always 24-hour `HH:mm` strings; `hour12` only changes what is shown. `minuteStep` (1, 5, 15 …)
 * sets the minute options; `minTime` / `maxTime` (`HH:mm`, same day) disable the times outside the range.
 */
@ComponentV2
export struct STimePicker {
  /** `HH:mm` (24-hour), undefined = empty (use with `!!`) */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Event onValueChange: (v: string) => void = () => {
  };
  @Param placeholder: ResourceStr = $r('app.string.spark_pick_time');
  /** show a 12-hour clock with an AM / PM column (values stay `HH:mm`) */
  @Param hour12: boolean = false;
  /** minute options: 1 (default), 5, 15 … (1..60) */
  @Param minuteStep: number = 1;
  /** earliest selectable time, `HH:mm` */
  @Param minTime: string | undefined = undefined;
  /** latest selectable time, `HH:mm` */
  @Param maxTime: string | undefined = undefined;
  @Param disabled: boolean = false;
  @Param triggerWidth: Length = 140;
  /** Accessible name of the trigger (default "Pick a time"). */
  @Param label: string | undefined = undefined;
  @Param adaptive: SparkAdaptive = 'auto';
  /** Popover surface tokens (instance → `--popover-*` → recipe). */
  @Param surfaceTokens: SparkSurfaceTokens = {};
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  /** committed value in minutes since midnight, -1 = empty */
  @Local current: number = -1;
  /** time shown by the wheels while open */
  @Local wheel: number = 0;
  @Local sheet: boolean = false;
  @Local disclosure: SparkDisclosure = new SparkDisclosure();
  private binding: OverlayBinding = new OverlayBinding();

  aboutToAppear(): void {
    this.current = sparkParseTime(this.value);
    this.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
    this.disclosure.triggerUniqueId = this.getUniqueId();
    this.disclosure.emit = (open: boolean) => this.onOpenChange(open);
    this.binding.attach(this.getUIContext(), this.disclosure, (scope: SparkOverlayScope) => {
      this.sheet = sparkUseSheet(this.adaptive);
      this.wheel = this.initialWheel();
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

  @Monitor('value')
  syncValue(): void {
    this.current = sparkParseTime(this.value);
    if (this.current >= 0 && this.current !== this.wheel) {
      this.wheel = this.current;
    }
  }

  @Monitor('disabled')
  syncDisabled(): void {
    if (this.disabled) {
      this.disclosure.setOpen(false);
    }
  }

  /** the committed value, or "now" — snapped to the step and kept within the range */
  private initialWheel(): number {
    const now = new Date();
    const base = this.current >= 0 ? this.current : now.getHours() * 60 + now.getMinutes();
    const t = sparkNearestTime(base, this.minuteStep, this.minBound, this.maxBound);
    return t >= 0 ? t : base;
  }

  @Computed
  get minBound(): number {
    return sparkParseTime(this.minTime);
  }

  @Computed
  get maxBound(): number {
    return sparkParseTime(this.maxTime);
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
  get text(): string | undefined {
    return this.current >= 0 ? sparkTimeLabel(this.current, this.hour12, this.am, this.pm) : undefined;
  }

  @Computed
  get accessibleName(): string {
    return this.label ?? sparkText(this.getUIContext(), $r('app.string.spark_pick_time'), 'Pick a time');
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
  get columnWidth(): number {
    return this.sheet ? SPARK_TIME_COLUMN_TOUCH : SPARK_TIME_COLUMN_POINTER;
  }

  @Computed
  get wheelsWidth(): number {
    return sparkTimeWheelsWidth(this.columnWidth, this.hour12);
  }

  // ---------------------------------------------------------------------------------------------- picking

  private commit(t: number): void {
    if (t < 0) {
      return;
    }
    if (t !== this.wheel) {
      this.wheel = t;
    }
    if (t !== this.current) {
      this.current = t;
      const v = sparkFormatTime(t);
      this.$value(v);
      this.onValueChange(v);
    }
  }

  private done(): void {
    this.commit(this.wheel);
    this.disclosure.setOpen(false);
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      SparkTimeWheels({
        value: this.wheel,
        hour12: this.hour12,
        minuteStep: this.minuteStep,
        minBound: this.minBound,
        maxBound: this.maxBound,
        rowHeight: this.rowHeight,
        columnWidth: this.columnWidth,
        fontSize: this.sheet ? this.theme.text.base : this.theme.text.sm,
        surfaceColor: this.surface.background,
        am: this.am,
        pm: this.pm,
        onChange: (t: number) => this.commit(t)
      })
      if (this.sheet) {
        Row() {
          SButton({ text: $r('app.string.spark_done'), block: true })
            .onClick(() => this.done())
        }
        .width('100%')
        .padding({ top: 12 })
      }
    }
    .width(this.sheet ? '100%' : this.wheelsWidth + 2 * this.surface.padding + 2 * this.surface.borderWidth)
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: this.sheet ? 16 : this.surface.padding,
      right: this.sheet ? 16 : this.surface.padding,
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
      onActivate: () => this.disclosure.toggle()
    })
  }
}
