import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkUI } from '../../core/SparkUI';
import { SCard, SCardContent } from '../../components/card/SCard';
import { SIcon } from '../../icons/SIcon';
import { SGrid, SGridItem } from '../../layout/SparkLayouts';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type DashboardTrend = 'up' | 'down' | 'none';

/**
 * Dashboard section: optional heading + an auto-fill grid of tiles (`repeat(auto-fill, minmax(minTileWidth,
 * 1fr))`) — 1 column on a phone, 2–4+ on tablets and desktops, no breakpoints. Tiles span columns with
 * `span` (clamped to the current column count) or the whole row with `full`.
 *
 * ```
 * SDashboardGrid({ title: 'Overview', minTileWidth: 220 }) {
 *   SDashboardTile({ title: 'Revenue', value: '$45,231', delta: '+20.1%', trend: 'up', icon: 'dollar-sign' })
 *   SDashboardTile({ title: 'Sales', span: 2 }) { SalesChart() }
 *   SDashboardTile({ full: true }) { RecentOrders() }
 * }
 * ```
 */
@ComponentV2
export struct SDashboardGrid {
  @Param title: ResourceStr | undefined = undefined;
  @Param description: ResourceStr | undefined = undefined;
  /** minimum tile width (vp) */
  @Param minTileWidth: number = 240;
  @Param gap: number = 16;
  /** upper bound on columns (0 = unlimited) */
  @Param maxColumns: number = 0;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 12 }) {
      if (this.title !== undefined) {
        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(this.theme.text.lg)
            .fontWeight(this.theme.text.weightSemibold)
            .fontColor(this.theme.colors.foreground)
          if (this.description !== undefined) {
            Text(this.description)
              .fontSize(this.theme.text.sm)
              .fontColor(this.theme.colors.mutedForeground)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      SGrid({ minItemWidth: this.minTileWidth, gap: this.gap, maxColumns: this.maxColumns }) {
        this.content()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * A dashboard card. Quick props render a KPI tile (title + icon, big value, delta with trend icon); the slot
 * adds anything else (charts, tables, lists) below.
 */
@ComponentV2
export struct SDashboardTile {
  @Param title: ResourceStr | undefined = undefined;
  @Param icon: string | undefined = undefined;
  @Param value: ResourceStr | undefined = undefined;
  @Param delta: ResourceStr | undefined = undefined;
  @Param trend: DashboardTrend = 'none';
  /** columns spanned (clamped to the current column count) */
  @Param span: number = 1;
  /** span the whole row */
  @Param full: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  private trendIcon(): string {
    return this.trend === 'up' ? 'trending-up' : 'trending-down';
  }

  build() {
    SGridItem({ span: this.span, full: this.full }) {
      SCard() {
        SCardContent() {
          if (this.title !== undefined || this.icon !== undefined) {
            Row({ space: 8 }) {
              Text(this.title ?? '')
                .layoutWeight(1)
                .fontSize(this.theme.text.sm)
                .fontWeight(this.theme.text.weightMedium)
                .fontColor(this.theme.colors.cardForeground)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.icon !== undefined) {
                SIcon({ name: this.icon, sizing: 16, color: this.theme.colors.mutedForeground })
              }
            }
            .width('100%')
          }
          if (this.value !== undefined) {
            Text(this.value)
              .fontSize(this.theme.text.xxl)
              .fontWeight(this.theme.text.weightBold)
              .fontColor(this.theme.colors.cardForeground)
          }
          if (this.delta !== undefined) {
            Row({ space: 4 }) {
              if (this.trend !== 'none') {
                SIcon({
                  name: this.trendIcon(),
                  sizing: 14,
                  color: this.trend === 'down' ? this.theme.colors.destructive : this.theme.colors.mutedForeground
                })
              }
              Text(this.delta)
                .fontSize(this.theme.text.xs)
                .fontColor(this.theme.colors.mutedForeground)
            }
          }
          this.content()
        }
      }
    }
  }
}
