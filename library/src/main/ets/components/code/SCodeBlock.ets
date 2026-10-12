import { pasteboard } from '@kit.BasicServicesKit';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';
import { CodeHighlighter, CodeLanguage, CodeToken, CodeTokenKind } from './CodeHighlighter';

/** Syntax colours (GitHub light / dark inspired), chosen by the theme's appearance. */
export class CodePalette {
  keyword: string;
  string: string;
  comment: string;
  number: string;
  decorator: string;
  type: string;
  func: string;
  property: string;

  constructor(dark: boolean) {
    this.keyword = dark ? '#FFFF7B72' : '#FFCF222E';
    this.string = dark ? '#FFA5D6FF' : '#FF0A3069';
    this.comment = dark ? '#FF8B949E' : '#FF6E7781';
    this.number = dark ? '#FF79C0FF' : '#FF0550AE';
    this.decorator = dark ? '#FFD2A8FF' : '#FF8250DF';
    this.type = dark ? '#FFFFA657' : '#FF953800';
    this.func = dark ? '#FFD2A8FF' : '#FF8250DF';
    this.property = dark ? '#FF79C0FF' : '#FF0550AE';
  }

  color(kind: CodeTokenKind, fallback: string): string {
    switch (kind) {
      case 'keyword':
        return this.keyword;
      case 'string':
        return this.string;
      case 'comment':
        return this.comment;
      case 'number':
        return this.number;
      case 'decorator':
        return this.decorator;
      case 'type':
        return this.type;
      case 'function':
        return this.func;
      case 'property':
        return this.property;
      default:
        return fallback;
    }
  }
}

/** One highlighted line, with a stable key for ForEach. */
class CodeLine {
  index: number;
  tokens: CodeToken[];

  constructor(index: number, tokens: CodeToken[]) {
    this.index = index;
    this.tokens = tokens;
  }
}

/**
 * Highlighted code block with optional title, line numbers and a copy button.
 *
 * ```
 * SCodeBlock({ code: 'SButton({ text: "Save" })', language: 'arkts', title: 'Index.ets' })
 * ```
 */
@ComponentV2
export struct SCodeBlock {
  @Param code: string = '';
  @Param language: CodeLanguage = 'arkts';
  /** File name / caption shown in the header; defaults to the language. */
  @Param title: string | undefined = undefined;
  @Param showLineNumbers: boolean = true;
  @Param copyable: boolean = true;
  /** Max height in vp before the block scrolls vertically (0 = no limit). */
  @Param maxHeight: number = 0;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local copied: boolean = false;

  @Computed
  get lines(): CodeLine[] {
    return CodeHighlighter.highlight(this.code, this.language)
      .map((tokens: CodeToken[], i: number) => new CodeLine(i, tokens));
  }

  @Computed
  get palette(): CodePalette {
    return new CodePalette(this.theme.isDark);
  }

  @Computed
  get gutterWidth(): number {
    return String(this.lines.length).length * 9 + 16;
  }

  private copy(): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.code);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.copied = true;
      setTimeout(() => {
        this.copied = false;
      }, 2000);
    } catch (e) {
      this.copied = false;
    }
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        ForEach(this.lines, (line: CodeLine) => {
          Row() {
            if (this.showLineNumbers) {
              Text(String(line.index + 1))
                .width(this.gutterWidth)
                .padding({ right: 12 })
                .textAlign(TextAlign.End)
                .fontSize(13)
                .lineHeight(20)
                .fontFamily('monospace')
                .fontColor(SparkColor.alpha(this.theme.colors.mutedForeground, 0.6))
            }
            Text() {
              ForEach(line.tokens, (t: CodeToken) => {
                Span(t.text)
                  .fontColor(this.palette.color(t.kind, this.theme.colors.foreground))
                  .fontStyle(t.kind === 'comment' ? FontStyle.Italic : FontStyle.Normal)
              }, (t: CodeToken, i: number) => `${i}:${t.kind}:${t.text}`)
            }
            .fontSize(13)
            .lineHeight(20)
            .fontFamily('monospace')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.None })
          }
          .alignItems(VerticalAlign.Top)
        }, (line: CodeLine) => `${line.index}:${line.tokens.map((t: CodeToken) => t.text).join('')}`)
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, bottom: 12, left: this.showLineNumbers ? 4 : 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        Row({ space: 8 }) {
          SIcon({ name: this.language === 'bash' ? 'terminal' : 'code', sizing: 14,
            color: this.theme.colors.mutedForeground })
          Text(this.title ?? this.language)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }

        if (this.copyable) {
          SButton({ variant: 'ghost', sizing: 'icon-sm', icon: this.copied ? 'check' : 'copy', label: 'Copy code' })
            .onClick(() => this.copy())
        }
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 4 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 1 }, color: this.theme.colors.border })

      if (this.maxHeight > 0) {
        Scroll() {
          this.body()
        }
        .constraintSize({ maxHeight: this.maxHeight })
        .scrollBar(BarState.Auto)
        .align(Alignment.TopStart)
      } else {
        this.body()
      }
    }
    .width('100%')
    .backgroundColor(this.theme.isDark ? SparkColor.alpha(this.theme.colors.muted, 0.4) :
      SparkColor.mix(this.theme.colors.background, this.theme.colors.muted, 0.6))
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
    .clip(true)
  }
}
