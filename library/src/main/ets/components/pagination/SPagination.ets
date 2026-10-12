import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';
import { SPARK_PAGINATION_ELLIPSIS, sparkPaginationRange, sparkPaginationSiblings } from './PaginationRange';

/** one page button (36 vp) + gap (4 vp) */
const PAGE_SLOT: number = 40;
/** Previous + Next with text */
const TEXT_CHROME: number = 220;
/** Previous + Next as icons */
const ICON_CHROME: number = 80;

/** Below this own width (vp) the labels of Previous / Next are hidden and no sibling pages are shown. */

/**
 * shadcn-vue `Pagination` (rendered as one component): Previous, page links, ellipses and Next.
 * Page links use the button recipe (`ghost`, active page `outline`, `icon` size).
 *
 * ```
 * SPagination({ total: 10, defaultPage: 2 })
 * SPagination({ total: 20, page: this.page!!, siblingCount: 2 })      // controlled, 1-based
 * ```
 *
 * Responsive without breakpoints: when the pagination itself is narrower than 480vp the Previous / Next labels
 * collapse to icons and `siblingCount` drops to 0. The page window comes from {@link sparkPaginationRange}.
 */
@ComponentV2
export struct SPagination {
  /** Controlled current page, 1-based (use with `!!`). Leave undefined for uncontrolled. */
  @Param page: number | undefined = undefined;
  @Event $page: (page: number) => void = () => {
  };
  @Param defaultPage: number = 1;
  @Event onPageChange: (page: number) => void = () => {
  };
  /** Number of pages. */
  @Param total: number = 1;
  /** Pages shown on each side of the current page (wide layout). */
  @Param siblingCount: number = 1;
  @Param previousText: ResourceStr = 'Previous';
  @Param nextText: ResourceStr = 'Next';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: number = 1;
  @Local measuredWidth: number = 0;

  aboutToAppear(): void {
    this.current = this.clamp(this.page ?? this.defaultPage);
  }

  @Monitor('page', 'total')
  syncPage(): void {
    this.current = this.clamp(this.page ?? this.current);
  }

  private clamp(p: number): number {
    return Math.min(Math.max(1, Math.floor(p)), Math.max(1, Math.floor(this.total)));
  }

  private go(p: number): void {
    const next = this.clamp(p);
    if (next === this.current) {
      return;
    }
    if (this.page === undefined) {
      this.current = next;
    }
    this.$page(next);
    this.onPageChange(next);
  }

  /** Previous / Next show their text only when the minimal page window still fits beside them. */
  @Computed
  get compact(): boolean {
    return this.measuredWidth > 0 && this.measuredWidth < 5 * PAGE_SLOT + TEXT_CHROME;
  }

  /** As many sibling pages as fit the measured width (up to `siblingCount`) — no breakpoints. */
  @Computed
  get siblings(): number {
    return sparkPaginationSiblings(this.measuredWidth, this.compact ? ICON_CHROME : TEXT_CHROME, PAGE_SLOT,
      this.siblingCount);
  }

  @Computed
  get items(): number[] {
    return sparkPaginationRange(this.current, this.total, this.siblings);
  }

  @Computed
  get pageCount(): number {
    return Math.max(1, Math.floor(this.total));
  }

  build() {
    Row({ space: 4 }) {
      SButton({
        variant: 'ghost',
        sizing: this.compact ? 'icon' : 'default',
        icon: 'chevron-left',
        text: this.compact ? undefined : this.previousText,
        label: typeof this.previousText === 'string' ? this.previousText : 'Previous',
        disabled: this.current <= 1
      })
        .onClick(() => this.go(this.current - 1))

      ForEach(this.items, (p: number) => {
        if (p === SPARK_PAGINATION_ELLIPSIS) {
          Row() {
            SIcon({ name: 'ellipsis', sizing: 16, color: this.theme.colors.foreground })
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .accessibilityText('More pages')
        } else {
          SButton({
            variant: p === this.current ? 'outline' : 'ghost',
            sizing: 'icon',
            text: `${p}`,
            label: p === this.current ? `Page ${p}, current` : `Page ${p}`
          })
            .onClick(() => this.go(p))
        }
      }, (p: number, idx: number) => `${idx}:${p}`)

      SButton({
        variant: 'ghost',
        sizing: this.compact ? 'icon' : 'default',
        iconRight: 'chevron-right',
        text: this.compact ? undefined : this.nextText,
        label: typeof this.nextText === 'string' ? this.nextText : 'Next',
        disabled: this.current >= this.pageCount
      })
        .onClick(() => this.go(this.current + 1))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
    })
  }
}
