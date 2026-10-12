import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type SeparatorOrientation = 'horizontal' | 'vertical';
export type SeparatorLineStyle = 'solid' | 'dashed' | 'dotted';
/** Where the label of a horizontal separator sits. */
export type SeparatorLabelAlignment = 'start' | 'center' | 'end';

/**
 * shadcn-vue `Separator`: `bg-border shrink-0`, 1px tall (horizontal, full width) or 1px wide (vertical,
 * full height of the parent — give the parent a height, like shadcn's `h-5`).
 *
 * Variants: `lineStyle` solid | dashed | dotted, `thickness`, and a `label` cut into a horizontal line
 * ("OR CONTINUE WITH"), placed by `labelAlignment` start | center | end.
 *
 * ```
 * SSeparator()
 * Row({ space: 16 }) { Text('Blog'); SSeparator({ orientation: 'vertical' }); Text('Docs') }.height(20)
 * SSeparator({ label: 'Or continue with' })
 * SSeparator({ lineStyle: 'dashed', label: 'Today', labelAlignment: 'start' })
 * ```
 */
@ComponentV2
export struct SSeparator {
  @Param orientation: SeparatorOrientation = 'horizontal';
  /** Purely visual (hidden from accessibility). Set false when it separates meaningful groups. */
  @Param decorative: boolean = true;
  /** Optional explicit length; defaults to 100% of the parent along the orientation. */
  @Param length: Length = '100%';
  @Param lineStyle: SeparatorLineStyle = 'solid';
  /** Line thickness in vp. */
  @Param thickness: number = 1;
  /** Text cut into a horizontal separator. */
  @Param label: ResourceStr | undefined = undefined;
  @Param labelAlignment: SeparatorLabelAlignment = 'center';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get vertical(): boolean {
    return this.orientation === 'vertical';
  }

  @Computed
  get accessibleName(): string {
    if (this.decorative) {
      return '';
    }
    return typeof this.label === 'string' ? this.label : 'separator';
  }

  build() {
    if (this.label !== undefined && !this.vertical) {
      Row({ space: 12 }) {
        if (this.labelAlignment !== 'start') {
          this.line(true)
        } else {
          this.line(false)
        }
        Text(this.label)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.mutedForeground)
          .maxLines(1)
          .flexShrink(0)
        if (this.labelAlignment !== 'end') {
          this.line(true)
        } else {
          this.line(false)
        }
      }
      .width(this.length)
      .alignItems(VerticalAlign.Center)
      .accessibilityGroup(true)
      .accessibilityLevel(this.decorative ? 'no' : 'auto')
      .accessibilityText(this.accessibleName)
    } else {
      this.line(true)
    }
  }

  /** One line; `grow` false makes the short 16vp lead-in next to a start / end label. */
  @Builder
  line(grow: boolean) {
    if (this.lineStyle === 'solid') {
      Column()
        .width(this.vertical ? this.thickness : (this.label !== undefined ? (grow ? 0 : 16) : this.length))
        .height(this.vertical ? this.length : this.thickness)
        .layoutWeight(this.label !== undefined && grow ? 1 : 0)
        .flexShrink(0)
        .backgroundColor(this.theme.colors.border)
        .accessibilityLevel(this.decorative ? 'no' : 'auto')
        .accessibilityText(this.accessibleName)
    } else {
      // a dashed / dotted border on one side of a zero-size box
      Column()
        .width(this.vertical ? 0 : (this.label !== undefined ? (grow ? 0 : 16) : this.length))
        .height(this.vertical ? this.length : 0)
        .layoutWeight(this.label !== undefined && grow ? 1 : 0)
        .flexShrink(0)
        .border({
          width: this.vertical ? { left: this.thickness } : { top: this.thickness },
          color: this.theme.colors.border,
          style: this.lineStyle === 'dashed' ? BorderStyle.Dashed : BorderStyle.Dotted
        })
        .accessibilityLevel(this.decorative ? 'no' : 'auto')
        .accessibilityText(this.accessibleName)
    }
  }
}
