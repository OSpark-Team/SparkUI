import { KeyCode } from '@kit.InputKit';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkText } from '../../core/SparkText';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { sparkSheetHandle } from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkSurface, sparkSurfaceDefaults, SparkSurfaceStyle, SparkSurfaceTokens
} from '../../theme/tokens/SparkTokenReader';
import { ButtonStyle, ButtonStyleModifier, ButtonVariants } from '../button/ButtonVariants';
import { SButton } from '../button/SButton';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';
import {
  sparkFormatTime, sparkHour12, sparkHourEnabled, sparkMinuteOptions, sparkNearestEnabled, sparkNearestInHour,
  sparkNearestTime, sparkParseTime, sparkStepEnabled, sparkTimeInRange, sparkTimeLabel
} from './TimePickerLogic';

/** visible rows of a wheel column (odd: the middle one is the selection) */
const ROWS: number = 5;
/** row height / column width in the anchored popover (pointer) */
const ROW_POINTER: number = 32;
const COLUMN_POINTER: number = 56;
/** row height / column width in the bottom sheet (touch targets) */
const ROW_TOUCH: number = 44;
const COLUMN_TOUCH: number = 72;
/** the ':' between hours and minutes */
const COLON_WIDTH: number = 12;
/** gap before the AM / PM column */
const PERIOD_GAP: number = 8;

/**
 * One wheel column: a snapping List whose middle row is the selection. Settling (fling end, tap, arrow keys)
 * reports the index through `onPick`; disabled rows are skipped (the wheel snaps to the nearest enabled one).
 */
@ComponentV2
struct SparkTimeColumn {
  @Param labels: string[] = [];
  @Param disabledRows: boolean[] = [];
  @Param selected: number = 0;
  @Param rowHeight: number = ROW_POINTER;
  @Param columnWidth: number = COLUMN_POINTER;
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
    return this.rowHeight * (ROWS - 1) / 2;
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
    .height(this.rowHeight * ROWS)
    .contentStartOffset(this.edgeOffset)
    .contentEndOffset(this.edgeOffset)
    .scrollSnapAlign(ScrollSnapAlign.CENTER)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
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

/** Outline-button trigger (the SDatePicker trigger with a clock icon); muted text while empty. */
@ComponentV2
struct SparkTimeTrigger {
  @Param text: ResourceStr = '';
  @Param empty: boolean = true;
  @Param disabled: boolean = false;
  @Param triggerWidth: Length = 140;
  @Param triggerKey: string = '';
  @Param open: boolean = false;
  @Param label: string = '';
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
    .accessibilityDescription(`${typeof this.text === 'string' ? this.text : ''}, ${this.open ?
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

  // ---------------------------------------------------------------------------------------------- columns

  @Computed
  get wheelHour(): number {
    return Math.floor(this.wheel / 60);
  }

  @Computed
  get wheelMinute(): number {
    return this.wheel % 60;
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
  get rowHeight(): number {
    return this.sheet ? ROW_TOUCH : ROW_POINTER;
  }

  @Computed
  get columnWidth(): number {
    return this.sheet ? COLUMN_TOUCH : COLUMN_POINTER;
  }

  @Computed
  get wheelsWidth(): number {
    return 2 * this.columnWidth + COLON_WIDTH + (this.hour12 ? PERIOD_GAP + this.columnWidth : 0);
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

  private pickHour(i: number): void {
    this.commit(sparkNearestInHour(this.hourAt(i), this.wheelMinute, this.minuteStep, this.minBound,
      this.maxBound));
  }

  private pickMinute(i: number): void {
    const t = this.wheelHour * 60 + (this.minuteOptions[i] ?? 0);
    if (sparkTimeInRange(t, this.minBound, this.maxBound)) {
      this.commit(t);
    }
  }

  private pickPeriod(p: number): void {
    const h = p * 12 + this.wheelHour % 12;
    const t = sparkNearestInHour(h, this.wheelMinute, this.minuteStep, this.minBound, this.maxBound);
    this.commit(t >= 0 ? t : sparkNearestTime(h * 60 + this.wheelMinute, this.minuteStep, this.minBound,
      this.maxBound));
  }

  private done(): void {
    this.commit(this.wheel);
    this.disclosure.setOpen(false);
  }

  @Builder
  fade(top: boolean) {
    Column()
      .width('100%')
      .height(this.rowHeight * 1.5)
      .linearGradient({
        direction: top ? GradientDirection.Bottom : GradientDirection.Top,
        colors: [[this.surface.background, 0], [SparkColor.alpha(this.surface.background, 0), 1]]
      })
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        sparkSheetHandle(this.theme.colors.muted)
      }
      Stack() {
        // selection highlight behind the middle row
        Row()
          .width('100%')
          .height(this.rowHeight)
          .borderRadius(this.theme.radiusSm)
          .backgroundColor(this.theme.colors.accent)
        Row() {
          SparkTimeColumn({
            labels: this.hourLabels,
            disabledRows: this.hourDisabled,
            selected: this.hourIndex,
            rowHeight: this.rowHeight,
            columnWidth: this.columnWidth,
            fontSize: this.sheet ? this.theme.text.base : this.theme.text.sm,
            label: sparkText(this.getUIContext(), $r('app.string.spark_hours'), 'Hours'),
            onPick: (i: number) => this.pickHour(i)
          })
          Text(':')
            .width(COLON_WIDTH)
            .textAlign(TextAlign.Center)
            .fontSize(this.sheet ? this.theme.text.base : this.theme.text.sm)
            .fontWeight(this.theme.text.weightMedium)
            .fontColor(this.theme.colors.accentForeground)
            .accessibilityLevel('no')
          SparkTimeColumn({
            labels: this.minuteLabels,
            disabledRows: this.minuteDisabled,
            selected: this.minuteIndex,
            rowHeight: this.rowHeight,
            columnWidth: this.columnWidth,
            fontSize: this.sheet ? this.theme.text.base : this.theme.text.sm,
            label: sparkText(this.getUIContext(), $r('app.string.spark_minutes'), 'Minutes'),
            onPick: (i: number) => this.pickMinute(i)
          })
          if (this.hour12) {
            SparkTimeColumn({
              labels: this.periodLabels,
              disabledRows: this.periodDisabled,
              selected: this.period,
              rowHeight: this.rowHeight,
              columnWidth: this.columnWidth,
              fontSize: this.sheet ? this.theme.text.base : this.theme.text.sm,
              label: `${this.am} / ${this.pm}`,
              onPick: (p: number) => this.pickPeriod(p)
            })
              .margin({ left: PERIOD_GAP })
          }
        }
        .alignItems(VerticalAlign.Center)
        // soft fade at the top / bottom edge of the wheels (touches pass through)
        Column() {
          this.fade(true)
          Blank()
          this.fade(false)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
      }
      .width(this.wheelsWidth)
      .height(this.rowHeight * ROWS)
      .alignContent(Alignment.Center)
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
