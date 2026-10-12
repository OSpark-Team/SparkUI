import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.alert';

export type AlertVariant = 'default' | 'destructive';

/** Alert variant shared with SAlertTitle / SAlertDescription. */
@ObservedV2
export class SparkAlertState {
  @Trace variant: AlertVariant = 'default';
}

function resolveAlert(uiContext: UIContext, id: number): SparkAlertState | undefined {
  return SparkContext.resolve<SparkAlertState>(uiContext, id, KEY);
}

/**
 * shadcn-vue `Alert`: `relative w-full rounded-lg border px-4 py-3 text-sm grid grid-cols-[16px_1fr] gap-x-3
 * gap-y-0.5 items-start`, `bg-card`. The `destructive` variant tints title / icon with `text-destructive` and the
 * description with `text-destructive/90`.
 *
 * `heading` / `description` are shortcuts for a title / description without a slot.
 *
 * ```
 * SAlert({ icon: 'circle-check' }) {
 *   SAlertTitle({ text: 'Success! Your changes have been saved' })
 *   SAlertDescription({ text: 'This is an alert with icon, title and description.' })
 * }
 * SAlert({ variant: 'destructive', icon: 'circle-alert', heading: 'Error', description: 'Session expired.' })
 * ```
 */
@ComponentV2
export struct SAlert {
  @Param variant: AlertVariant = 'default';
  /** lucide icon name shown in the leading column. */
  @Param icon: string | undefined = undefined;
  @Param heading: ResourceStr | undefined = undefined;
  @Param description: ResourceStr | undefined = undefined;
  @Param modifier: AttributeModifier<RowAttribute> = new SparkNoopModifier<RowAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkAlertState = new SparkAlertState();

  aboutToAppear(): void {
    this.state.variant = this.variant;
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('variant')
  syncVariant(): void {
    this.state.variant = this.variant;
  }

  @Computed
  get fg(): string {
    return this.variant === 'destructive' ? this.theme.colors.destructive : this.theme.colors.cardForeground;
  }

  build() {
    Row({ space: 12 }) {
      if (this.icon !== undefined) {
        // [&>svg]:size-4 [&>svg]:translate-y-0.5 text-current
        SIcon({ name: this.icon, sizing: 16, color: this.fg })
          .margin({ top: 2 })
      }
      Column({ space: 2 }) {
        if (this.heading !== undefined) {
          SAlertTitle({ text: this.heading })
        }
        if (this.description !== undefined) {
          SAlertDescription({ text: this.description })
        }
        this.content()
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.theme.colors.card)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
    .accessibilityGroup(true)
    .attributeModifier(this.modifier)
  }
}

/** `col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight`. */
@ComponentV2
export struct SAlertTitle {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local alert: SparkAlertState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.alert === undefined) {
      this.alert = resolveAlert(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontWeight(this.theme.text.weightMedium)
      .letterSpacing(-0.025 * this.theme.text.sm)
      .fontColor(this.alert?.variant === 'destructive' ? this.theme.colors.destructive :
        this.theme.colors.cardForeground)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ minHeight: 16 })
  }
}

/** `text-muted-foreground col-start-2 text-sm [&_p]:leading-relaxed` (destructive: `text-destructive/90`). */
@ComponentV2
export struct SAlertDescription {
  @Param text: ResourceStr | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local alert: SparkAlertState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.alert === undefined) {
      this.alert = resolveAlert(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get fg(): string {
    return this.alert?.variant === 'destructive' ? SparkColor.alpha(this.theme.colors.destructive, 0.9) :
      this.theme.colors.mutedForeground;
  }

  build() {
    Column({ space: 4 }) {
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.sm)
          // leading-relaxed (1.625)
          .lineHeight(this.theme.text.sm * 1.625)
          .fontColor(this.fg)
      }
      this.content()
    }
    .alignItems(HorizontalAlign.Start)
  }
}
