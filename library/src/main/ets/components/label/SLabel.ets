import { sparkText } from '../../core/SparkText';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue `Label`: `flex items-center gap-2 text-sm leading-none font-medium select-none`,
 * `opacity-50` when the associated control is disabled (`disabled` param here, since ArkUI has no `peer-disabled`).
 *
 * ```
 * SLabel({ text: 'Email' })
 * SLabel({ text: 'Password', required: true })
 * SLabel({ text: 'Accept terms' }) { SBadge(...) }   // extra trailing content
 * ```
 */
@ComponentV2
export struct SLabel {
  @Param text: ResourceStr | undefined = undefined;
  /** Appends a destructive `*`. */
  @Param required: boolean = false;
  /** Disabled look (opacity 50%). */
  @Param disabled: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 8 }) {
      if (this.text !== undefined) {
        Row({ space: 2 }) {
          Text(this.text)
            .fontSize(this.theme.text.sm)
            .fontWeight(this.theme.text.weightMedium)
            .lineHeight(this.theme.text.sm)
            .fontColor(this.theme.colors.foreground)
          if (this.required) {
            Text('*')
              .fontSize(this.theme.text.sm)
              .fontWeight(this.theme.text.weightMedium)
              .lineHeight(this.theme.text.sm)
              .fontColor(this.theme.colors.destructive)
              .accessibilityLevel('no')
          }
        }
      }
      this.content()
    }
    .alignItems(VerticalAlign.Center)
    .opacity(this.disabled ? 0.5 : 1)
    .accessibilityDescription(this.required ? sparkText(this.getUIContext(), $r('app.string.spark_state_required'), 'required') : '')
  }
}
