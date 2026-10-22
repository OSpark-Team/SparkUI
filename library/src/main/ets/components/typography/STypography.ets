import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue Typography (the docs page's utility classes as components).
 *
 * ```
 * SH1({ text: 'Taxing Laughter: The Joke Tax Chronicles' })
 * SP({ text: 'Once upon a time…' })
 * SBlockquote({ text: '"After all," he said, "everyone enjoys a good joke."' })
 * SList({ items: ['1st level of puns', '2nd level of jokes'] })
 * ```
 *
 * `tracking-tight` = letter-spacing -0.025em. `font-extrabold` maps to the boldest weight token (`weightBold`).
 */
const TRACKING_TIGHT: number = -0.025;

/** `text-4xl font-extrabold tracking-tight text-balance`. */
@ComponentV2
export struct SH1 {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.xxxxl)
      .lineHeight(this.theme.text.leadingXxxxl)
      .fontWeight(this.theme.text.weightBold)
      .letterSpacing(TRACKING_TIGHT * this.theme.text.xxxxl)
      .fontColor(this.theme.colors.foreground)
  }
}

/** `border-b pb-2 text-3xl font-semibold tracking-tight`. */
@ComponentV2
export struct SH2 {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column() {
      Text(this.text)
        .fontSize(this.theme.text.xxxl)
        .lineHeight(this.theme.text.leadingXxxl)
        .fontWeight(this.theme.text.weightSemibold)
        .letterSpacing(TRACKING_TIGHT * this.theme.text.xxxl)
        .fontColor(this.theme.colors.foreground)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 8 })
    .border({ width: { bottom: 1 }, color: this.theme.colors.border })
  }
}

/** `text-2xl font-semibold tracking-tight`. */
@ComponentV2
export struct SH3 {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.xxl)
      .lineHeight(this.theme.text.leadingXxl)
      .fontWeight(this.theme.text.weightSemibold)
      .letterSpacing(TRACKING_TIGHT * this.theme.text.xxl)
      .fontColor(this.theme.colors.foreground)
  }
}

/** `text-xl font-semibold tracking-tight`. */
@ComponentV2
export struct SH4 {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.xl)
      .lineHeight(this.theme.text.leadingXl)
      .fontWeight(this.theme.text.weightSemibold)
      .letterSpacing(TRACKING_TIGHT * this.theme.text.xl)
      .fontColor(this.theme.colors.foreground)
  }
}

/** `leading-7` body paragraph. */
@ComponentV2
export struct SP {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.base)
      .lineHeight(28)
      .fontColor(this.theme.colors.foreground)
  }
}

/** `text-xl text-muted-foreground`. */
@ComponentV2
export struct SLead {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.xl)
      .lineHeight(this.theme.text.leadingXl)
      .fontColor(this.theme.colors.mutedForeground)
  }
}

/** `text-lg font-semibold`. */
@ComponentV2
export struct SLarge {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.lg)
      .lineHeight(this.theme.text.leadingLg)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.theme.colors.foreground)
  }
}

/** `text-sm leading-none font-medium`. */
@ComponentV2
export struct SSmall {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(Math.ceil(this.theme.text.sm * 1.25)) // leading-none clips CJK glyphs (top of 已 / 毕) — keep 1.25x
      .fontWeight(this.theme.text.weightMedium)
      .fontColor(this.theme.colors.foreground)
  }
}

/** `text-sm text-muted-foreground`. */
@ComponentV2
export struct SMuted {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
  }
}

/** `mt-6 border-l-2 pl-6 italic`. */
@ComponentV2
export struct SBlockquote {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column() {
      Text(this.text)
        .fontSize(this.theme.text.base)
        .lineHeight(this.theme.text.leadingBase)
        .fontStyle(FontStyle.Italic)
        .fontColor(this.theme.colors.foreground)
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 24 })
    .border({ width: { left: 2 }, color: this.theme.colors.border })
  }
}

/** `relative rounded bg-muted px-[0.3rem] py-[0.2rem] font-mono text-sm font-semibold`. */
@ComponentV2
export struct SInlineCode {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .fontWeight(this.theme.text.weightSemibold)
      .fontFamily('monospace')
      .fontColor(this.theme.colors.foreground)
      .padding({ left: 4.8, right: 4.8, top: 3.2, bottom: 3.2 })
      .backgroundColor(this.theme.colors.muted)
      .border({ width: 0, radius: this.theme.radiusSm })
  }
}

/** `my-6 ml-6 list-disc [&>li]:mt-2`. */
@ComponentV2
export struct SList {
  @Param items: string[] = [];
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 8 }) {
      ForEach(this.items, (item: string) => {
        Row({ space: 10 }) {
          // disc marker, vertically centred on the first line (leading-7)
          Column()
            .width(5)
            .height(5)
            .margin({ top: (28 - 5) / 2 })
            .backgroundColor(this.theme.colors.foreground)
            .border({ width: 0, radius: 2.5 })
            .flexShrink(0)
          Text(item)
            .fontSize(this.theme.text.base)
            .lineHeight(28)
            .fontColor(this.theme.colors.foreground)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (item: string, idx: number) => `${idx}:${item}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14 })
  }
}
