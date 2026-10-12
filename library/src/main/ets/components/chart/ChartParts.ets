import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SPARK_CHART_KEY, SparkChartConfig, SparkChartIndicator, SparkChartLegendPlacement, SparkChartSeries,
  SparkChartState, SparkChartTooltipItem
} from './ChartTypes';

/** Rough label width in vp for axis layout (CJK ≈ 1em, latin ≈ 0.6em). */
export function sparkChartTextWidth(text: string, fontSize: number): number {
  let w = 0;
  for (let i = 0; i < text.length; i++) {
    w += text.charCodeAt(i) >= 0x2E80 ? fontSize : fontSize * 0.6;
  }
  return Math.ceil(w);
}

/** Resolve the SChartContainer state around `id` (or undefined). */
export function sparkResolveChartState(uiContext: UIContext, id: number): SparkChartState | undefined {
  return SparkContext.resolve<SparkChartState>(uiContext, id, SPARK_CHART_KEY);
}

/** One legend entry: colour swatch + label; tap toggles the series when `interactive`. */
@ComponentV2
struct SChartLegendItem {
  @Param label: string = '';
  @Param color: string = '#FF000000';
  @Param muted: boolean = false;
  @Param interactive: boolean = true;
  @Event onToggle: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Styles
  normalStyle() {
    .backgroundColor(Color.Transparent)
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.theme.colors.accent)
  }

  @Builder
  body() {
    Column()
      .width(8)
      .height(8)
      .borderRadius(2)
      .backgroundColor(this.color)
    Text(this.label)
      .fontSize(this.theme.text.xs)
      .fontColor(this.muted ? this.theme.colors.mutedForeground : this.theme.colors.foreground)
      .maxLines(1)
  }

  build() {
    if (this.interactive) {
      Row({ space: 6 }) {
        this.body()
      }
      .padding({ left: 6, right: 6, top: 4, bottom: 4 })
      .borderRadius(this.theme.radiusSm)
      .opacity(this.muted ? 0.45 : 1)
      .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
      .accessibilityText(this.label)
      .accessibilitySelected(!this.muted)
      .onClick(() => this.onToggle())
    } else {
      Row({ space: 6 }) {
        this.body()
      }
      .padding({ left: 6, right: 6, top: 4, bottom: 4 })
      .opacity(this.muted ? 0.45 : 1)
      .focusable(false)
      .accessibilityText(this.label)
    }
  }
}

/**
 * shadcn `ChartLegend` + `ChartLegendContent`: centred, wrapping row of swatches. With `interactive`, tapping an
 * entry hides / shows that series (shared through `state`).
 */
@ComponentV2
export struct SChartLegend {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param state: SparkChartState | undefined = undefined;
  /** keys to list (default: every series of the config); pie charts pass their slice keys */
  @Param keys: string[] | undefined = undefined;
  @Param interactive: boolean = true;
  @Param compact: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  private listed(): string[] {
    return this.keys ?? this.config.keys();
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      justifyContent: FlexAlign.Center,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(this.compact ? 4 : 8), cross: LengthMetrics.vp(4) }
    }) {
      ForEach(this.listed(), (key: string, i: number) => {
        SChartLegendItem({
          label: this.config.label(key),
          color: this.config.color(this.theme, key, i),
          muted: this.state?.isHidden(key) ?? false,
          interactive: this.interactive && this.state !== undefined,
          onToggle: () => this.state?.toggle(key)
        })
      }, (key: string) => key)
    }
    .width('100%')
  }
}

/** shadcn `ChartTooltipContent`: label + one row per series (indicator, name, value). */
@ComponentV2
export struct SChartTooltipCard {
  @Param title: string = '';
  @Param items: SparkChartTooltipItem[] = [];
  @Param indicator: SparkChartIndicator = 'dot';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Builder
  mark(color: string) {
    if (this.indicator === 'line') {
      Column().width(3).height(14).borderRadius(2).backgroundColor(color)
    } else if (this.indicator === 'dashed') {
      Column().width(0).height(14).border({ width: { left: 1.5 }, color: color, style: BorderStyle.Dashed })
    } else {
      Column().width(10).height(10).borderRadius(2).backgroundColor(color)
    }
  }

  build() {
    Column({ space: 6 }) {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(this.theme.text.xs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.foreground)
          .maxLines(1)
      }
      Row() {
        Column({ space: 6 }) {
          ForEach(this.items, (it: SparkChartTooltipItem) => {
            Row({ space: 8 }) {
              this.mark(it.color)
              Text(it.label)
                .fontSize(this.theme.text.xs)
                .fontColor(this.theme.colors.mutedForeground)
                .maxLines(1)
            }
            .height(16)
          }, (it: SparkChartTooltipItem) => `${it.key}|${it.label}|${it.color}`)
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          ForEach(this.items, (it: SparkChartTooltipItem) => {
            Text(it.value)
              .height(16)
              .fontSize(this.theme.text.xs)
              .fontWeight(this.theme.text.weightMedium)
              .fontColor(this.theme.colors.foreground)
              .fontFeature('"tnum" on')
              .maxLines(1)
          }, (it: SparkChartTooltipItem) => `${it.key}|${it.value}`)
        }
        .alignItems(HorizontalAlign.End)
        .margin({ left: 16 })
      }
      .alignItems(VerticalAlign.Top)
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ minWidth: 128 })
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor(this.theme.colors.background)
    .border({ width: 1, color: SparkColor.alpha(this.theme.colors.border, 0.5), radius: this.theme.radiusLg })
    .shadow(this.theme.shadows.xl.toOptions())
  }
}

/**
 * Internal: transparent hit layer of a chart. Reports pointer positions (local vp) from mouse hover, taps and —
 * with `scrub` — horizontal pans (vertical pans keep scrolling the page). Pure gesture input, no pressed visuals.
 */
@ComponentV2
export struct SChartPointer {
  @Param scrub: boolean = true;
  @Param boxWidth: number = 0;
  @Param boxHeight: number = 0;
  @Event onPoint: (x: number, y: number) => void = () => {
  };
  @Event onTap: (x: number, y: number) => void = () => {
  };
  @Event onLeave: () => void = () => {
  };

  private pan(e: GestureEvent): void {
    if (e.fingerList.length > 0) {
      this.onPoint(e.fingerList[0].localX, e.fingerList[0].localY);
    }
  }

  private click(e: ClickEvent): void {
    if (e.source === SourceType.Mouse) {
      this.onPoint(e.x, e.y);
    } else {
      this.onTap(e.x, e.y);
    }
  }

  build() {
    if (this.scrub) {
      Column()
        .width(this.boxWidth)
        .height(this.boxHeight)
        .onHover((h: boolean) => {
          if (!h) {
            this.onLeave();
          }
        })
        .onMouse((e: MouseEvent) => this.onPoint(e.x, e.y))
        .onClick((e: ClickEvent) => this.click(e))
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart((e: GestureEvent) => this.pan(e))
            .onActionUpdate((e: GestureEvent) => this.pan(e))
        )
    } else {
      Column()
        .width(this.boxWidth)
        .height(this.boxHeight)
        .onHover((h: boolean) => {
          if (!h) {
            this.onLeave();
          }
        })
        .onMouse((e: MouseEvent) => this.onPoint(e.x, e.y))
        .onClick((e: ClickEvent) => this.click(e))
    }
  }
}

/** Muted "no data" block. */
@ComponentV2
export struct SChartEmpty {
  @Param text: ResourceStr = $r('app.string.spark_no_data');
  @Param boxHeight: number = 200;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 8 }) {
      SIcon({ name: 'chart-bar', sizing: 20, color: this.theme.colors.mutedForeground })
      Text(this.text)
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .width('100%')
    .height(this.boxHeight)
    .justifyContent(FlexAlign.Center)
  }
}

/**
 * shadcn `ChartContainer`: card-friendly frame around one or more charts. Shares series visibility with the
 * charts inside it (SparkContext), renders the legend (`legend`, tap to toggle) and an empty state.
 * It measures its own width: the legend tightens when the container is narrow.
 *
 * ```
 * SChartContainer({ config: this.config, legend: true }) {
 *   SBarChart({ config: this.config, data: this.rows })
 * }
 * ```
 */
@ComponentV2
export struct SChartContainer {
  @Param config: SparkChartConfig = new SparkChartConfig([]);
  @Param legend: boolean = false;
  @Param legendPlacement: SparkChartLegendPlacement = 'bottom';
  /** legend entries toggle their series */
  @Param legendToggle: boolean = true;
  /** show the empty state instead of the content */
  @Param empty: boolean = false;
  @Param emptyText: ResourceStr = $r('app.string.spark_no_data');
  @Param emptyHeight: number = 200;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkChartState = new SparkChartState();
  @Local measuredWidth: number = 0;

  aboutToAppear(): void {
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), SPARK_CHART_KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  build() {
    Column({ space: 12 }) {
      if (this.legend && this.legendPlacement === 'top' && !this.empty) {
        SChartLegend({
          config: this.config, state: this.state, interactive: this.legendToggle,
          compact: this.measuredWidth > 0 && this.measuredWidth < 360
        })
      }
      if (this.empty) {
        SChartEmpty({ text: this.emptyText, boxHeight: this.emptyHeight })
      } else {
        this.content()
      }
      if (this.legend && this.legendPlacement === 'bottom' && !this.empty) {
        SChartLegend({
          config: this.config, state: this.state, interactive: this.legendToggle,
          compact: this.measuredWidth > 0 && this.measuredWidth < 360
        })
      }
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
    })
  }
}

/** Series list helper used by the charts: visible keys of the config, in config order. */
export function sparkVisibleKeys(config: SparkChartConfig, state: SparkChartState | undefined): string[] {
  return config.series
    .filter((s: SparkChartSeries) => state === undefined || !state.isHidden(s.key))
    .map((s: SparkChartSeries) => s.key);
}
