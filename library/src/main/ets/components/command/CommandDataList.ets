import { sparkText } from '../../core/SparkText';
import { SparkUI } from '../../core/SparkUI';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SIcon } from '../../icons/SIcon';
import { sparkOptionIndexOf, sparkOptionListHeight, sparkOptionSizes } from '../../primitives/list/SparkOptionLogic';
import { sparkIsEnterUp } from '../../primitives/menu/MenuRow';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SPARK_EMPTY_COMMAND_ROW, SparkCommandRow } from './CommandData';

/** Row heights (vp): items `h-8`, group headings `px-2 py-1.5 text-xs`. */
export const SPARK_COMMAND_ROW_HEIGHT: number = 32;
export const SPARK_COMMAND_HEADING_HEIGHT: number = 28;

/**
 * Virtualized result list of `SCommand({ items })` (ADR D14): `List` + `Repeat(...).virtualScroll()` with two
 * templates (item / heading). Only rows in view (plus `cachedCount`) exist; filtered-out items are not in
 * `entries` at all. The height is explicit (sum of the row heights, capped at `maxListHeight`), and
 * `childrenMainSize` gives every row's exact height, so `scrollToIndex` keeps the highlight in view without
 * measuring frame nodes. Rows take only `@Param`s (reused rows never register anywhere).
 */
@ComponentV2
export struct SparkCommandDataList {
  @Param entries: SparkCommandRow[] = [];
  @Param highlighted: string = '';
  @Param maxListHeight: number = 300;
  /** rows take keyboard focus (no search field); false while an input keeps focus and drives the highlight */
  @Param rowsFocusable: boolean = false;
  @Event onPick: (value: string) => void = () => {
  };
  @Event onHighlight: (value: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private scroller: Scroller = new Scroller();
  private sizes: ChildrenMainSize = new ChildrenMainSize(SPARK_COMMAND_ROW_HEIGHT);
  private sizeCount: number = 0;

  aboutToAppear(): void {
    this.syncSizes();
  }

  @Computed
  get listHeight(): number {
    return sparkOptionListHeight(this.entries, SPARK_COMMAND_ROW_HEIGHT, SPARK_COMMAND_HEADING_HEIGHT,
      this.maxListHeight);
  }

  @Monitor('entries')
  syncSizes(): void {
    const next = sparkOptionSizes(this.entries, SPARK_COMMAND_ROW_HEIGHT, SPARK_COMMAND_HEADING_HEIGHT);
    this.sizes.splice(0, this.sizeCount, next);
    this.sizeCount = next.length;
  }

  /** keep the keyboard highlight in view */
  @Monitor('highlighted')
  follow(): void {
    const i = sparkOptionIndexOf(this.entries, this.highlighted);
    if (i >= 0) {
      this.scroller.scrollToIndex(i, false, ScrollAlign.AUTO);
    }
  }

  build() {
    List({ scroller: this.scroller }) {
      Repeat<SparkCommandRow>(this.entries)
        .each((ri: RepeatItem<SparkCommandRow>) => {
          ListItem() {
            SparkCommandDataRow({
              entry: ri.item,
              highlighted: this.highlighted,
              rowsFocusable: this.rowsFocusable,
              onPick: (v: string) => this.onPick(v),
              onHighlight: (v: string) => this.onHighlight(v)
            })
          }
        })
        .key((e: SparkCommandRow) => e.key)
        .virtualScroll({ totalCount: this.entries.length })
        .templateId((e: SparkCommandRow) => e.kind)
        .template('label', (ri: RepeatItem<SparkCommandRow>) => {
          ListItem() {
            SparkCommandHeading({ text: ri.item.label })
          }
        }, { cachedCount: 2 })
    }
    .width('100%')
    .height(this.listHeight)
    .cachedCount(4)
    .childrenMainSize(this.sizes)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.None)
    .accessibilityRole(AccessibilityRoleType.LIST)
  }
}

/** Group heading: `px-2 py-1.5 text-xs font-medium text-muted-foreground`. */
@ComponentV2
struct SparkCommandHeading {
  @Param text: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .width('100%')
      .height(SPARK_COMMAND_HEADING_HEIGHT)
      .padding({ left: 8, right: 8 })
      .fontSize(this.theme.text.xs)
      .fontWeight(this.theme.text.weightMedium)
      .fontColor(this.theme.colors.mutedForeground)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}

/**
 * Item row (same look as `SCommandItem`): icon, label, shortcut; accent background on the highlighted row
 * (switches instantly). A selection row: pressing only fades its opacity (system pressed state, no animation).
 * Activation is the native click (touch, mouse, Space on a focused row, accessibility click) plus Enter.
 */
@ComponentV2
struct SparkCommandDataRow {
  @Param entry: SparkCommandRow = SPARK_EMPTY_COMMAND_ROW;
  @Param highlighted: string = '';
  @Param rowsFocusable: boolean = false;
  @Event onPick: (value: string) => void = () => {
  };
  @Event onHighlight: (value: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get isHighlighted(): boolean {
    return !this.entry.disabled && this.highlighted.length > 0 && this.entry.value === this.highlighted;
  }

  @Styles
  normalStyle() {
    .opacity(this.entry.disabled ? 0.5 : 1)
  }

  @Styles
  pressedStyle() {
    .opacity(this.entry.disabled ? 0.5 : 0.6)
  }

  build() {
    Row({ space: 8 }) {
      if (this.entry.icon !== undefined) {
        SIcon({ name: this.entry.icon, sizing: 16, color: this.theme.colors.mutedForeground })
      }
      Text(this.entry.label)
        .layoutWeight(1)
        .fontSize(this.theme.text.sm)
        .fontColor(this.isHighlighted ? this.theme.colors.accentForeground : this.theme.colors.popoverForeground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.entry.shortcut !== undefined) {
        Text(this.entry.shortcut)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.mutedForeground)
          .letterSpacing(1.5)
      }
    }
    .width('100%')
    .height(SPARK_COMMAND_ROW_HEIGHT)
    .padding({ left: 8, right: 8 })
    .borderRadius(this.theme.radiusSm)
    .backgroundColor(this.isHighlighted ? this.theme.colors.accent : Color.Transparent)
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .onHover((h: boolean) => {
      SparkUI.layout.reportPointerEvent(true);
      if (h && !this.entry.disabled) {
        this.onHighlight(this.entry.value);
      }
    })
    .onClick(() => {
      if (!this.entry.disabled) {
        this.onPick(this.entry.value);
      }
    })
    .onKeyEvent((e: KeyEvent) => {
      if (sparkIsEnterUp(e) && !this.entry.disabled) {
        this.onPick(this.entry.value);
      }
    })
    .focusable(this.rowsFocusable && !this.entry.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .onFocus(() => {
      if (!this.entry.disabled) {
        this.onHighlight(this.entry.value);
      }
    })
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.OPTION)
    .accessibilityText(this.entry.label)
    .accessibilityDescription(this.entry.disabled ? sparkText(this.getUIContext(), $r('app.string.spark_state_disabled'), 'disabled') : '')
    .accessibilitySelected(this.isHighlighted)
  }
}
