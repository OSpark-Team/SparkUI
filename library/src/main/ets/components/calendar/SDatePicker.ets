import { sparkText } from '../../core/SparkText';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { ButtonStyle, ButtonStyleModifier, ButtonVariants } from '../button/ButtonVariants';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';
import { SCalendar, SparkDateMatcher } from './SCalendar';
import { SparkDate, SparkDateLocale, SparkDateRange, SparkDates, SparkWeekStart } from './SparkDate';
import { SRangeCalendar } from './SRangeCalendar';

/** cell size inside the anchored popover (vp) */
const PANEL_CELL: number = 36;
/** calendar padding (p-3) */
const PAD: number = 12;
const GAP: number = 16;
/** popover border, both sides */
const BORDER: number = 2;
/** one-month popover width: 7 cells + padding + border = 278vp (definite: rule for anchored panels) */
const ONE_MONTH_WIDTH: number = 7 * PANEL_CELL + 2 * PAD + BORDER;
const TWO_MONTH_WIDTH: number = 14 * PANEL_CELL + GAP + 2 * PAD + BORDER;

function formatDate(d: SparkDate, pattern: string, locale: SparkDateLocale): string {
  return SparkDates.format(d, pattern, locale);
}

/**
 * Trigger shared by the pickers: shadcn `Button variant="outline" class="w-[240px] justify-start text-left
 * font-normal"` with a calendar icon; muted text while empty.
 */
@ComponentV2
struct SparkDateTrigger {
  @Param text: ResourceStr = '';
  @Param empty: boolean = true;
  @Param disabled: boolean = false;
  @Param triggerWidth: Length = 240;
  @Param triggerKey: string = '';
  @Param open: boolean = false;
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
        SIcon({ name: 'calendar', sizing: 16, color: this.empty ? this.theme.colors.mutedForeground :
          this.theme.colors.foreground })
        Text(this.text)
          .layoutWeight(1)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightNormal)
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
    .accessibilityText(typeof this.text === 'string' ? this.text : '')
    .accessibilityDescription(this.open ? sparkText(this.getUIContext(), $r('app.string.spark_state_expanded'), 'expanded') : sparkText(this.getUIContext(), $r('app.string.spark_state_collapsed'), 'collapsed'))
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => {
      if (!this.disabled) {
        this.onActivate();
      }
    })
  }
}

/**
 * shadcn-vue Date Picker (Popover + Calendar).
 *
 * ```
 * SDatePicker({ value: this.date!! })
 * SDatePicker({ value: this.date!!, placeholder: '选择日期', locale: 'zh', format: 'YYYY-MM-DD' })
 * ```
 * Outline-button trigger (`triggerWidth`, default 240vp); the calendar opens in a popover below the trigger
 * (aligned to its start) and in a bottom sheet on compact touch windows (`adaptive: 'auto'`). Picking a day
 * closes it. `format`: 'PPP' (default: 'Oct 12, 2026' / '2026年10月12日'), 'YYYY-MM-DD', 'MMM d, yyyy' …
 */
@ComponentV2
export struct SDatePicker {
  @Param value: SparkDate | undefined = undefined;
  @Event $value: (d: SparkDate | undefined) => void = () => {
  };
  @Event onValueChange: (d: SparkDate | undefined) => void = () => {
  };
  @Param placeholder: ResourceStr = $r('app.string.spark_pick_date');
  @Param format: string = 'PPP';
  @Param locale: SparkDateLocale = 'en';
  @Param minDate: SparkDate | undefined = undefined;
  @Param maxDate: SparkDate | undefined = undefined;
  @Param disabledDates: SparkDateMatcher | undefined = undefined;
  @Param weekStartsOn: SparkWeekStart = 1;
  @Param disabled: boolean = false;
  /** trigger width (shadcn w-[240px]) */
  @Param triggerWidth: Length = 240;
  @Param adaptive: SparkAdaptive = 'auto';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local current: SparkDate | undefined = undefined;
  @Local sheet: boolean = false;
  @Local disclosure: SparkDisclosure = new SparkDisclosure();
  private binding: OverlayBinding = new OverlayBinding();

  aboutToAppear(): void {
    this.current = this.value;
    this.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
    this.disclosure.triggerUniqueId = this.getUniqueId();
    this.binding.attach(this.getUIContext(), this.disclosure, (scope: SparkOverlayScope) => {
      this.sheet = sparkUseSheet(this.adaptive);
      scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
      scope.motionKey = this.sheet ? 'sheet' : 'date-picker';
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
    this.current = this.value;
  }

  @Monitor('disabled')
  syncDisabled(): void {
    if (this.disabled) {
      this.disclosure.setOpen(false);
    }
  }

  @Computed
  get label(): string | undefined {
    return this.current !== undefined ? formatDate(this.current, this.format, this.locale) : undefined;
  }

  private pick(d: SparkDate | undefined): void {
    this.current = d;
    this.$value(d);
    this.onValueChange(d);
    if (d !== undefined) {
      this.disclosure.setOpen(false);
    }
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        Row() {
          Column().width(40).height(4).borderRadius(2).backgroundColor(this.theme.colors.muted)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 4 })
      }
      SCalendar({
        mode: 'single',
        selected: this.current,
        required: true,
        onSelectedChange: (d: SparkDate | undefined) => this.pick(d),
        minDate: this.minDate,
        maxDate: this.maxDate,
        disabledDates: this.disabledDates,
        weekStartsOn: this.weekStartsOn,
        locale: this.locale,
        cellSize: this.sheet ? undefined : PANEL_CELL
      })
    }
    .width(this.sheet ? '100%' : ONE_MONTH_WIDTH)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.sheet ? 8 : 0, bottom: this.sheet ? 8 + this.layout.env.safeArea.bottom : 0 })
    .backgroundColor(this.theme.colors.popover)
    .border({
      width: this.sheet ? { top: 1 } : 1,
      color: this.theme.colors.border,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusMd
    })
    .shadow(this.theme.shadows.md.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    SparkDateTrigger({
      text: this.label ?? this.placeholder,
      empty: this.label === undefined,
      disabled: this.disabled,
      triggerWidth: this.triggerWidth,
      triggerKey: sparkTriggerKey(this.getUniqueId()),
      open: this.disclosure.open,
      onActivate: () => this.disclosure.toggle()
    })
  }
}

/**
 * Date range picker: the {@link SDatePicker} trigger with an {@link SRangeCalendar} (two months side by side
 * when the window allows). Closes once both ends are picked.
 *
 * ```
 * SDateRangePicker({ value: this.range!! })
 * ```
 */
@ComponentV2
export struct SDateRangePicker {
  @Param value: SparkDateRange | undefined = undefined;
  @Event $value: (r: SparkDateRange) => void = () => {
  };
  @Event onValueChange: (r: SparkDateRange) => void = () => {
  };
  @Param placeholder: ResourceStr = $r('app.string.spark_pick_date_range');
  @Param format: string = 'PPP';
  @Param locale: SparkDateLocale = 'en';
  @Param minDate: SparkDate | undefined = undefined;
  @Param maxDate: SparkDate | undefined = undefined;
  @Param disabledDates: SparkDateMatcher | undefined = undefined;
  @Param weekStartsOn: SparkWeekStart = 1;
  @Param disabled: boolean = false;
  @Param triggerWidth: Length = 300;
  @Param adaptive: SparkAdaptive = 'auto';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local current: SparkDateRange = new SparkDateRange();
  @Local sheet: boolean = false;
  @Local twoUp: boolean = true;
  @Local disclosure: SparkDisclosure = new SparkDisclosure();
  private binding: OverlayBinding = new OverlayBinding();

  aboutToAppear(): void {
    this.current = this.value ?? new SparkDateRange();
    this.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
    this.disclosure.triggerUniqueId = this.getUniqueId();
    this.binding.attach(this.getUIContext(), this.disclosure, (scope: SparkOverlayScope) => {
      this.sheet = sparkUseSheet(this.adaptive);
      // anchored: two months when the window has room for the 2-month panel (+ 8vp margins)
      this.twoUp = SparkUI.layout.root.width <= 0 || SparkUI.layout.root.width >= TWO_MONTH_WIDTH + 16;
      scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
      scope.motionKey = this.sheet ? 'sheet' : 'date-picker';
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
    this.current = this.value ?? new SparkDateRange();
  }

  @Monitor('disabled')
  syncDisabled(): void {
    if (this.disabled) {
      this.disclosure.setOpen(false);
    }
  }

  @Computed
  get label(): string | undefined {
    const from = this.current.from;
    const to = this.current.to;
    if (from === undefined) {
      return undefined;
    }
    const a = formatDate(from, this.format, this.locale);
    return to === undefined ? a : `${a} - ${formatDate(to, this.format, this.locale)}`;
  }

  private pick(r: SparkDateRange): void {
    this.current = r;
    this.$value(r);
    this.onValueChange(r);
    if (r.from !== undefined && r.to !== undefined) {
      this.disclosure.setOpen(false);
    }
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        Row() {
          Column().width(40).height(4).borderRadius(2).backgroundColor(this.theme.colors.muted)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 4 })
      }
      SRangeCalendar({
        range: this.current,
        onRangeChange: (r: SparkDateRange) => this.pick(r),
        minDate: this.minDate,
        maxDate: this.maxDate,
        disabledDates: this.disabledDates,
        weekStartsOn: this.weekStartsOn,
        locale: this.locale,
        numberOfMonths: this.sheet ? undefined : (this.twoUp ? 2 : 1),
        cellSize: this.sheet ? undefined : PANEL_CELL
      })
    }
    .width(this.sheet ? '100%' : (this.twoUp ? TWO_MONTH_WIDTH : ONE_MONTH_WIDTH))
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.sheet ? 8 : 0, bottom: this.sheet ? 8 + this.layout.env.safeArea.bottom : 0 })
    .backgroundColor(this.theme.colors.popover)
    .border({
      width: this.sheet ? { top: 1 } : 1,
      color: this.theme.colors.border,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusMd
    })
    .shadow(this.theme.shadows.md.toOptions())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    SparkDateTrigger({
      text: this.label ?? this.placeholder,
      empty: this.label === undefined,
      disabled: this.disabled,
      triggerWidth: this.triggerWidth,
      triggerKey: sparkTriggerKey(this.getUniqueId()),
      open: this.disclosure.open,
      onActivate: () => this.disclosure.toggle()
    })
  }
}
