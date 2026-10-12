import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { sparkIsEnterUp } from '../menu/MenuRow';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SPARK_EMPTY_OPTION_ENTRY, SparkOptionEntry, sparkOptionIndexOf, sparkOptionListHeight, sparkOptionSizes
} from './SparkOptionLogic';

/** Row heights (vp): options `h-8` (`h-11` roomy / bottom sheet), group headings `py-1.5 text-xs`. */
export const SPARK_OPTION_ROW_HEIGHT: number = 32;
export const SPARK_OPTION_ROW_HEIGHT_ROOMY: number = 44;
export const SPARK_OPTION_LABEL_HEIGHT: number = 28;
export const SPARK_OPTION_LABEL_HEIGHT_ROOMY: number = 32;

/**
 * Virtualized option list (ADR D14): `List` + `Repeat(...).virtualScroll()`, so only the rows inside the
 * viewport (plus `cachedCount` on each side) exist, and rows leaving it are reused for rows entering it. Used by
 * the data modes of SSelect and SCombobox; 10 000 options open as fast as 10.
 *
 * The list owns no selection state: `selected` (check mark) and `highlighted` (keyboard / hover row) come from
 * the parent, which also filters `entries` (see `sparkOptionEntries`). The list is exactly as tall as its rows,
 * capped at `maxListHeight`; its height is explicit, so laziness never depends on the parent's constraints.
 */
@ComponentV2
export struct SparkOptionList {
  @Param entries: SparkOptionEntry[] = [];
  /** value with the check mark */
  @Param selected: string = '';
  /** value of the highlighted row ('' = none); the list scrolls to keep it visible */
  @Param highlighted: string = '';
  /** touch-friendly rows (bottom-sheet presentation) */
  @Param roomy: boolean = false;
  @Param maxListHeight: number = 300;
  /** rows take keyboard focus (Select); false when a search field drives the highlight (Combobox) */
  @Param rowsFocusable: boolean = true;
  /** highlighted row colours ('' = theme accent / accent-foreground) */
  @Param highlightBackground: string = '';
  @Param highlightForeground: string = '';
  @Event onPick: (value: string) => void = () => {
  };
  /** pointer hover over an enabled option */
  @Event onHighlight: (value: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private scroller: Scroller = new Scroller();
  private sizes: ChildrenMainSize = new ChildrenMainSize(SPARK_OPTION_ROW_HEIGHT);
  private sizeCount: number = 0;
  /** first visible row when the list is created: the selected option, a few rows of context above it */
  private startIndex: number = 0;

  aboutToAppear(): void {
    this.startIndex = Math.max(0, sparkOptionIndexOf(this.entries, this.selected) - 3);
    this.syncSizes();
  }

  @Computed
  get rowHeight(): number {
    return this.roomy ? SPARK_OPTION_ROW_HEIGHT_ROOMY : SPARK_OPTION_ROW_HEIGHT;
  }

  @Computed
  get labelHeight(): number {
    return this.roomy ? SPARK_OPTION_LABEL_HEIGHT_ROOMY : SPARK_OPTION_LABEL_HEIGHT;
  }

  @Computed
  get listHeight(): number {
    return sparkOptionListHeight(this.entries, this.rowHeight, this.labelHeight, this.maxListHeight);
  }

  @Monitor('entries', 'roomy')
  syncSizes(): void {
    const next = sparkOptionSizes(this.entries, this.rowHeight, this.labelHeight);
    this.sizes.childDefaultSize = this.rowHeight;
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
    List({ scroller: this.scroller, initialIndex: this.startIndex }) {
      Repeat<SparkOptionEntry>(this.entries)
        .each((ri: RepeatItem<SparkOptionEntry>) => {
          ListItem() {
            SparkOptionRow({
              entry: ri.item,
              selected: this.selected,
              highlighted: this.highlighted,
              roomy: this.roomy,
              rowsFocusable: this.rowsFocusable,
              highlightBackground: this.highlightBackground,
              highlightForeground: this.highlightForeground,
              onPick: (v: string) => this.onPick(v),
              onHighlight: (v: string) => this.onHighlight(v)
            })
          }
        })
        .key((e: SparkOptionEntry) => e.key)
        .virtualScroll({ totalCount: this.entries.length })
        .templateId((e: SparkOptionEntry) => e.kind)
        .template('label', (ri: RepeatItem<SparkOptionEntry>) => {
          ListItem() {
            SparkOptionHeading({ text: ri.item.label, roomy: this.roomy })
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

/** Group heading row: `px-2 py-1.5 text-xs text-muted-foreground`. */
@ComponentV2
struct SparkOptionHeading {
  @Param text: string = '';
  @Param roomy: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .width('100%')
      .height(this.roomy ? SPARK_OPTION_LABEL_HEIGHT_ROOMY : SPARK_OPTION_LABEL_HEIGHT)
      .padding({ left: 8, right: 8 })
      .fontSize(this.theme.text.xs)
      .fontColor(this.theme.colors.mutedForeground)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}

/**
 * Option row: `flex h-8 items-center rounded-sm px-2 text-sm`, trailing check on the selected option, accent
 * background on the highlighted row (keyboard / hover: switches instantly). It is a selection row, so pressing
 * only fades its opacity (system pressed state, no animation); activation is the native click (touch, mouse,
 * Enter / Space on a focused row, accessibility click).
 */
@ComponentV2
export struct SparkOptionRow {
  @Param entry: SparkOptionEntry = SPARK_EMPTY_OPTION_ENTRY;
  @Param selected: string = '';
  @Param highlighted: string = '';
  @Param roomy: boolean = false;
  @Param rowsFocusable: boolean = true;
  @Param highlightBackground: string = '';
  @Param highlightForeground: string = '';
  @Event onPick: (value: string) => void = () => {
  };
  @Event onHighlight: (value: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get isSelected(): boolean {
    return this.selected.length > 0 && this.entry.value === this.selected;
  }

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
      Text(this.entry.label)
        .layoutWeight(1)
        .fontSize(this.roomy ? this.theme.text.base : this.theme.text.sm)
        .fontColor(this.isHighlighted ?
          (this.highlightForeground.length > 0 ? this.highlightForeground : this.theme.colors.accentForeground) :
          this.theme.colors.popoverForeground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Stack() {
        if (this.isSelected) {
          SIcon({ name: 'check', sizing: 16, color: this.theme.colors.popoverForeground })
        }
      }
      .width(16)
      .height(16)
    }
    .width('100%')
    .height(this.roomy ? SPARK_OPTION_ROW_HEIGHT_ROOMY : SPARK_OPTION_ROW_HEIGHT)
    .padding({ left: 8, right: 8 })
    .borderRadius(this.theme.radiusSm)
    .backgroundColor(this.isHighlighted ?
      (this.highlightBackground.length > 0 ? this.highlightBackground : this.theme.colors.accent) : Color.Transparent)
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
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.OPTION)
    .accessibilityText(this.entry.label)
    .accessibilitySelected(this.isSelected)
  }
}
