import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.card';

/** Card measurement shared with its parts: padding adapts to the card's own width. */
@ObservedV2
export class SparkCardState {
  /** horizontal / vertical padding in vp (shadcn px-6 / py-6, 16 when the card is narrow) */
  @Trace padding: number = 24;
  @Trace width: number = 0;

  update(width: number): void {
    this.width = width;
    const p = width > 0 && width < 360 ? 16 : 24;
    if (p !== this.padding) {
      this.padding = p;
    }
  }
}

function resolveCard(uiContext: UIContext, id: number): SparkCardState | undefined {
  return SparkContext.resolve<SparkCardState>(uiContext, id, KEY);
}

/**
 * shadcn-vue `Card`: `bg-card text-card-foreground flex flex-col gap-6 rounded-xl border py-6 shadow-sm`.
 * Responsive without breakpoints: padding tightens automatically when the card itself is narrow.
 *
 * ```
 * SCard() {
 *   SCardHeader() {
 *     SCardTitle({ text: 'Account' })
 *     SCardDescription({ text: 'Manage your profile.' })
 *   }
 *   SCardContent() { TextInput({ placeholder: 'Name' }) }
 *   SCardFooter() { SButton({ text: 'Save' }) }
 * }
 * ```
 */
@ComponentV2
export struct SCard {
  @Param modifier: AttributeModifier<ColumnAttribute> = new SparkNoopModifier<ColumnAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCardState = new SparkCardState();

  aboutToAppear(): void {
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  build() {
    Column({ space: this.state.padding }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: this.state.padding, bottom: this.state.padding })
    .backgroundColor(this.theme.colors.card)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusXl })
    .shadow(this.theme.shadows.sm.toOptions())
    .onAreaChange((_: Area, n: Area) => this.state.update(Number(n.width)))
    .attributeModifier(this.modifier)
  }
}

/** Title + description (+ optional SCardAction on the right). */
@ComponentV2
export struct SCardHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Column({ space: 6 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: this.card?.padding ?? 24, right: this.card?.padding ?? 24 })
  }
}

@ComponentV2
export struct SCardTitle {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.base)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.theme.colors.cardForeground)
  }
}

@ComponentV2
export struct SCardDescription {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
  }
}

/** Header action placed at the top-right corner of the card. */
@ComponentV2
export struct SCardAction {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Row() {
      this.content()
    }
    .position({ right: this.card?.padding ?? 24, top: 0 })
  }
}

@ComponentV2
export struct SCardContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Column({ space: 12 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: this.card?.padding ?? 24, right: this.card?.padding ?? 24 })
  }
}

/** Actions row; wraps onto several lines when the card is narrow. */
@ComponentV2
export struct SCardFooter {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local card: SparkCardState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.card === undefined) {
      this.card = resolveCard(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }
    }) {
      this.content()
    }
    .width('100%')
    .padding({ left: this.card?.padding ?? 24, right: this.card?.padding ?? 24 })
  }
}
