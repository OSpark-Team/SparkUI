import { CodeLanguage, SCodeBlock, SparkTheme, SparkUI, SToggleGroup, SToggleGroupItem } from '@sparkui/core';

@Builder
function emptyDemo() {
}

/** Page heading: title + lead paragraph (like the shadcn docs). */
@ComponentV2
export struct DocHeader {
  @Param title: string = '';
  @Param lead: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(this.theme.text.xxxl)
        .fontWeight(this.theme.text.weightBold)
        .fontColor(this.theme.colors.foreground)
      Text(this.lead)
        .fontSize(this.theme.text.base)
        .lineHeight(this.theme.text.leadingBase)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ bottom: 8 })
  }
}

@ComponentV2
export struct DocSection {
  @Param title: string = '';
  @Param description: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize(this.theme.text.xl)
        .fontWeight(this.theme.text.weightSemibold)
        .fontColor(this.theme.colors.foreground)
      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(this.theme.text.sm)
          .lineHeight(this.theme.text.leadingSm)
          .fontColor(this.theme.colors.mutedForeground)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ top: 16 })
  }
}

/** A live example with a Preview / Code switch. */
@ComponentV2
export struct DemoBlock {
  @Param code: string = '';
  @Param language: CodeLanguage = 'arkts';
  /** Centre the preview (default) or align it to the start. */
  @Param centered: boolean = true;
  @BuilderParam content: () => void = emptyDemo;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local showCode: boolean = false;

  build() {
    Column({ space: 8 }) {
      SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.showCode ? 'code' : 'preview'],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            this.showCode = v[0] === 'code';
          }
        } }) {
        SToggleGroupItem({ value: 'preview', text: 'Preview', icon: 'eye' })
        SToggleGroupItem({ value: 'code', text: 'Code', icon: 'code' })
      }

      if (this.showCode) {
        SCodeBlock({ code: this.code, language: this.language })
      } else {
        Column() {
          this.content()
        }
        .width('100%')
        .constraintSize({ minHeight: 160 })
        .padding(24)
        .justifyContent(FlexAlign.Center)
        .alignItems(this.centered ? HorizontalAlign.Center : HorizontalAlign.Start)
        .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
