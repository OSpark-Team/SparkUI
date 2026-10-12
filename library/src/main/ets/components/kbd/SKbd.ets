import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue `Kbd`: `bg-muted text-muted-foreground h-5 min-w-5 rounded-sm px-1 font-sans text-xs font-medium`.
 *
 * ```
 * SKbd({ text: 'Ctrl' })
 * SKbd({ icon: 'command' })
 * ```
 */
@ComponentV2
export struct SKbd {
  @Param text: ResourceStr | undefined = undefined;
  /** lucide icon name (12vp), e.g. `command`, `corner-down-left`. */
  @Param icon: string | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 4 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 12, color: this.theme.colors.mutedForeground })
      }
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.xs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.mutedForeground)
          .fontFamily('monospace')
          .maxLines(1)
      }
      this.content()
    }
    .height(20)
    .constraintSize({ minWidth: 20 })
    .padding({ left: 4, right: 4 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .flexShrink(0)
    .backgroundColor(this.theme.colors.muted)
    .border({ width: 0, radius: this.theme.radiusSm })
  }
}

/**
 * shadcn-vue `KbdGroup`: `inline-flex items-center gap-1`.
 *
 * ```
 * SKbdGroup() { SKbd({ text: 'Ctrl' }); Text('+'); SKbd({ text: 'B' }) }
 * ```
 */
@ComponentV2
export struct SKbdGroup {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Row({ space: 4 }) {
      this.content()
    }
    .alignItems(VerticalAlign.Center)
  }
}
