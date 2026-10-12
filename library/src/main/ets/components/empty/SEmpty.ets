import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type EmptyMediaVariant = 'default' | 'icon';

/**
 * shadcn-vue `Empty`: `flex flex-col items-center justify-center gap-6 rounded-lg border-dashed p-6 md:p-12
 * text-center`. Padding follows the component's own width (24vp below 480vp, 48vp above); `bordered` draws the
 * dashed outline.
 *
 * ```
 * SEmpty({ bordered: true }) {
 *   SEmptyHeader() {
 *     SEmptyMedia({ icon: 'folder', variant: 'icon' })
 *     SEmptyTitle({ text: 'No Projects Yet' })
 *     SEmptyDescription({ text: "You haven't created any projects yet." })
 *   }
 *   SEmptyContent() { SButton({ text: 'Create Project' }) }
 * }
 * ```
 */
@ComponentV2
export struct SEmpty {
  @Param bordered: boolean = false;
  @Param modifier: AttributeModifier<ColumnAttribute> = new SparkNoopModifier<ColumnAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local inset: number = 24;

  build() {
    Column({ space: 24 }) {
      this.content()
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(this.inset)
    .border({
      width: this.bordered ? 1 : 0,
      color: this.theme.colors.border,
      radius: this.theme.radiusLg,
      style: BorderStyle.Dashed
    })
    .onAreaChange((_: Area, n: Area) => {
      const w = Number(n.width);
      const p = w > 0 && w < 480 ? 24 : 48;
      if (p !== this.inset) {
        this.inset = p;
      }
    })
    .attributeModifier(this.modifier)
  }
}

/** `flex max-w-sm flex-col items-center gap-2 text-center`. */
@ComponentV2
export struct SEmptyHeader {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 8 }) {
      this.content()
    }
    .width('100%')
    .constraintSize({ maxWidth: 384 })
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * `mb-2 flex shrink-0 items-center justify-center`; the `icon` variant is `bg-muted size-10 rounded-lg` with a
 * 24vp icon. Put avatars or images in the slot with the default variant.
 */
@ComponentV2
export struct SEmptyMedia {
  @Param icon: string | undefined = undefined;
  @Param variant: EmptyMediaVariant = 'default';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Stack() {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 24, color: this.theme.colors.foreground })
      }
      this.content()
    }
    .constraintSize(this.variant === 'icon' ? { minWidth: 40, minHeight: 40 } : { minWidth: 0, minHeight: 0 })
    .backgroundColor(this.variant === 'icon' ? this.theme.colors.muted : Color.Transparent)
    .border({ width: 0, radius: this.theme.radiusLg })
    .margin({ bottom: 8 })
    .flexShrink(0)
  }
}

/** `text-lg font-medium tracking-tight`. */
@ComponentV2
export struct SEmptyTitle {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.lg)
      .lineHeight(this.theme.text.leadingLg)
      .fontWeight(this.theme.text.weightMedium)
      .letterSpacing(-0.025 * this.theme.text.lg)
      .fontColor(this.theme.colors.foreground)
      .textAlign(TextAlign.Center)
  }
}

/** `text-muted-foreground text-sm/relaxed`. */
@ComponentV2
export struct SEmptyDescription {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.sm * 1.625)
      .fontColor(this.theme.colors.mutedForeground)
      .textAlign(TextAlign.Center)
  }
}

/** `flex w-full max-w-sm min-w-0 flex-col items-center gap-4 text-sm`. */
@ComponentV2
export struct SEmptyContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 16 }) {
      this.content()
    }
    .width('100%')
    .constraintSize({ maxWidth: 384 })
    .alignItems(HorizontalAlign.Center)
  }
}
