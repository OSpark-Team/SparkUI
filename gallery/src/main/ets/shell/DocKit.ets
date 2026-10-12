import { CodeLanguage, SCodeBlock, SparkTheme, SparkUI, SToggleGroup, SToggleGroupItem } from '@ospark/sparkui';

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
        SToggleGroupItem({ value: 'preview', text: $r('app.string.gallery_preview'), icon: 'eye' })
        SToggleGroupItem({ value: 'code', text: $r('app.string.gallery_code'), icon: 'code' })
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

/**
 * Live status line under a demo ("selected: …"). A component, not a @Builder: primitive arguments passed to a
 * @Builder are evaluated once by value and do not re-render when the demo's state changes.
 */
@ComponentV2
export struct DemoCaption {
  @Param text: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.xs)
      .fontColor(this.theme.colors.mutedForeground)
      .margin({ top: 8 })
  }
}

/** Key / value row that follows live values (see DemoCaption). */
@ComponentV2
export struct DemoPropRow {
  @Param label: string = '';
  @Param value: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row() {
      Text(this.label).fontSize(this.theme.text.sm).fontColor(this.theme.colors.mutedForeground).width(160)
      Text(this.value).fontSize(this.theme.text.sm).fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: this.theme.colors.border })
  }
}
