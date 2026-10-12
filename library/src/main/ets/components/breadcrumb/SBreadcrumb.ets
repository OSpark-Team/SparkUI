import { sparkText, sparkTextOf } from '../../core/SparkText';
import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue `Breadcrumb`: the path to the current resource as a hierarchy of links.
 *
 * ```
 * SBreadcrumb() {
 *   SBreadcrumbList() {
 *     SBreadcrumbItem() { SBreadcrumbLink({ text: 'Home' }).onClick(() => this.go('/')) }
 *     SBreadcrumbSeparator()
 *     SBreadcrumbItem() { SBreadcrumbEllipsis() }
 *     SBreadcrumbSeparator()
 *     SBreadcrumbItem() { SBreadcrumbPage({ text: 'Breadcrumb' }) }
 *   }
 * }
 * ```
 */
@ComponentV2
export struct SBreadcrumb {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column() {
      this.content()
    }
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * `flex flex-wrap items-center gap-1.5 text-sm break-words sm:gap-2.5`. Responsive: wraps onto several lines
 * instead of overflowing, and uses the wider gap only when the list itself has room (≥ 640vp).
 */
@ComponentV2
export struct SBreadcrumbList {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local measuredWidth: number = 0;

  @Computed
  get gap(): number {
    return this.measuredWidth >= 640 ? 10 : 6;
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(this.gap), cross: LengthMetrics.vp(6) }
    }) {
      this.content()
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
    })
  }
}

/** `inline-flex items-center gap-1.5` */
@ComponentV2
export struct SBreadcrumbItem {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Row({ space: 6 }) {
      this.content()
    }
    .alignItems(VerticalAlign.Center)
  }
}

/**
 * A navigable crumb: `text-muted-foreground hover:text-foreground transition-colors`.
 * Navigate with the native `.onClick()` on the link.
 */
@ComponentV2
export struct SBreadcrumbLink {
  @Param text: ResourceStr | undefined = undefined;
  /** Leading lucide icon name. */
  @Param icon: string | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  @Computed
  get tint(): string {
    return this.ix.hovered ? this.theme.colors.foreground : this.theme.colors.mutedForeground;
  }

  @Computed
  get press(): SparkRowPressModifier {
    return new SparkRowPressModifier('#00000000', '#00000000', 0.6, false);
  }

  build() {
    Row({ space: 6 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 14, color: this.tint })
      }
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.sm)
          .lineHeight(this.theme.text.leadingSm)
          .fontColor(this.tint)
      }
      this.content()
    }
    .alignItems(VerticalAlign.Center)
    .attributeModifier(this.press)
    .border({ width: 0, radius: this.theme.radiusSm })
    .focusable(true)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.HYPERLINK)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
  }
}

/** The current page: `text-foreground font-normal`, not interactive. */
@ComponentV2
export struct SBreadcrumbPage {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontWeight(this.theme.text.weightNormal)
      .fontColor(this.theme.colors.foreground)
      .accessibilityDescription(sparkText(this.getUIContext(), $r('app.string.spark_current_page'), 'current page'))
  }
}

/** Separator between items; a 14vp chevron-right unless custom content is given. */
@ComponentV2
export struct SBreadcrumbSeparator {
  /** Lucide icon of the separator; pass '' to show only custom slot content (e.g. a slash Text). */
  @Param icon: string = 'chevron-right';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row() {
      if (this.icon.length > 0) {
        SIcon({ name: this.icon, sizing: 14, color: this.theme.colors.mutedForeground })
      }
      this.content()
    }
    .alignItems(VerticalAlign.Center)
    .accessibilityLevel('no')
  }
}

/** Collapsed crumbs: `flex size-9 items-center justify-center` with an ellipsis icon. */
@ComponentV2
export struct SBreadcrumbEllipsis {
  @Param label: ResourceStr = $r('app.string.spark_more');
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row() {
      SIcon({ name: 'ellipsis', sizing: 16, color: this.theme.colors.mutedForeground })
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(sparkTextOf(this.getUIContext(), this.label, 'More'))
  }
}
