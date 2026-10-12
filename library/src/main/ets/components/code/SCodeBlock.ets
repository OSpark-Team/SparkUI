import { pasteboard } from '@kit.BasicServicesKit';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';
import { CodeHighlighter, CodeLanguage, CodeToken, CodeTokenKind } from './CodeHighlighter';
import { SparkCodeTheme } from './SparkCodeTheme';
import { SparkGrammar } from './SparkGrammar';

/**
 * Syntax colours (GitHub light / dark inspired), chosen by the theme's appearance.
 * @deprecated use SparkCodeTheme (SparkCodeTheme.github() holds the same colours); kept for compatibility.
 */
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
    const t = SparkCodeTheme.github();
    this.keyword = t.colorOf('keyword', dark, '');
    this.string = t.colorOf('string', dark, '');
    this.comment = t.colorOf('comment', dark, '');
    this.number = t.colorOf('number', dark, '');
    this.decorator = t.colorOf('decorator', dark, '');
    this.type = t.colorOf('type', dark, '');
    this.func = t.colorOf('function', dark, '');
    this.property = t.colorOf('property', dark, '');
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

const DEFAULT_CODE_THEME: SparkCodeTheme = SparkCodeTheme.github();

/** One highlighted line, with a stable key for ForEach. */
class CodeLine {
  index: number;
  tokens: CodeToken[];
  marked: boolean;

  constructor(index: number, tokens: CodeToken[], marked: boolean) {
    this.index = index;
    this.tokens = tokens;
    this.marked = marked;
  }
}

/**
 * Highlighted code block with optional title, line numbers, highlighted lines and a copy button.
 *
 * - `language`: a registered language name / alias (see CodeHighlighter; unknown names render as plain text).
 * - `grammar`: a SparkGrammar object, used instead of `language` (e.g. from `CodeHighlighter.extend`).
 * - `codeTheme`: token → colour mapping (default SparkCodeTheme.github()).
 * - `highlightLines`: 1-based line numbers (relative to `startLine`) drawn with a tinted background.
 *
 * ```
 * SCodeBlock({ code: 'SButton({ text: "Save" })', language: 'arkts', title: 'Index.ets', highlightLines: [1] })
 * ```
 */
@ComponentV2
export struct SCodeBlock {
  @Param code: string = '';
  @Param language: CodeLanguage = 'arkts';
  /** Grammar object overriding `language`. */
  @Param grammar: SparkGrammar | undefined = undefined;
  @Param codeTheme: SparkCodeTheme | undefined = undefined;
  /** File name / caption shown in the header; defaults to the language (or grammar name). */
  @Param title: string | undefined = undefined;
  @Param showLineNumbers: boolean = true;
  /** Number shown for the first line. */
  @Param startLine: number = 1;
  /** Line numbers (as displayed, i.e. counting from `startLine`) to emphasise. */
  @Param highlightLines: number[] = [];
  @Param copyable: boolean = true;
  /** Max height in vp before the block scrolls vertically (0 = no limit). */
  @Param maxHeight: number = 0;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local copied: boolean = false;
  @Local viewportWidth: number = 0;

  @Computed
  get resolvedGrammar(): SparkGrammar {
    return this.grammar ?? CodeHighlighter.resolveGrammar(this.language);
  }

  @Computed
  get lines(): CodeLine[] {
    const marks = this.highlightLines;
    const start = this.startLine;
    return CodeHighlighter.highlight(this.code, this.resolvedGrammar)
      .map((tokens: CodeToken[], i: number) => new CodeLine(i, tokens, marks.indexOf(i + start) >= 0));
  }

  @Computed
  get palette(): SparkCodeTheme {
    if (this.codeTheme !== undefined) {
      return this.codeTheme;
    }
    // --code-* component tokens of the live theme (ADR D13) restyle blocks without an explicit codeTheme
    const comp = this.theme.comp;
    const vars = new Map<string, string>();
    comp.keys().forEach((k: string) => {
      if (k.startsWith('code-')) {
        vars.set('--' + k, comp.raw('code', k.substring(5)) ?? '');
      }
    });
    return vars.size === 0 ? DEFAULT_CODE_THEME : SparkCodeTheme.fromVariables(vars, undefined, DEFAULT_CODE_THEME);
  }

  @Computed
  get gutterWidth(): number {
    return String(this.lines.length + this.startLine - 1).length * 9 + 16;
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

  private lineBackground(line: CodeLine): string {
    if (line.marked) {
      return SparkColor.alpha(this.theme.colors.primary, this.theme.isDark ? 0.18 : 0.08);
    }
    const first = line.tokens.length > 0 ? line.tokens[0].kind : '';
    if (first === 'inserted' || first === 'deleted') {
      return SparkColor.alpha(this.palette.colorOf(first, this.theme.isDark, this.theme.colors.foreground), 0.1);
    }
    return '#00000000';
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        ForEach(this.lines, (line: CodeLine) => {
          Row() {
            if (this.showLineNumbers) {
              Text(String(line.index + this.startLine))
                .width(this.gutterWidth)
                .padding({ right: 12 })
                .textAlign(TextAlign.End)
                .fontSize(13)
                .lineHeight(20)
                .fontFamily('monospace')
                .fontColor(line.marked ? this.theme.colors.foreground :
                  SparkColor.alpha(this.theme.colors.mutedForeground, 0.6))
            }
            Text() {
              ForEach(line.tokens, (t: CodeToken) => {
                Span(t.text)
                  .fontColor(this.palette.colorOf(t.kind, this.theme.isDark, this.theme.colors.foreground))
                  .fontStyle(this.palette.isItalic(t.kind, this.theme.isDark) ? FontStyle.Italic : FontStyle.Normal)
                  .fontWeight(this.palette.isBold(t.kind, this.theme.isDark) ? FontWeight.Bold : FontWeight.Normal)
              }, (t: CodeToken, i: number) => `${i}:${t.kind}:${t.text}`)
            }
            .fontSize(13)
            .lineHeight(20)
            .fontFamily('monospace')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.None })
          }
          .alignItems(VerticalAlign.Top)
          .constraintSize({ minWidth: this.viewportWidth })
          .padding({ left: this.showLineNumbers ? 4 : 16, right: 16 })
          .backgroundColor(this.lineBackground(line))
        }, (line: CodeLine) =>
        `${line.index}:${line.marked}:${line.tokens.map((t: CodeToken) => t.kind + '\u0001' + t.text).join('\u0002')}`)
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, bottom: 12 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .width('100%')
    .onAreaChange((_old: Area, area: Area) => {
      this.viewportWidth = Number(area.width);
    })
  }

  build() {
    Column() {
      Row() {
        Row({ space: 8 }) {
          SIcon({ name: this.resolvedGrammar.icon ?? 'code', sizing: 14, color: this.theme.colors.mutedForeground })
          Text(this.title ?? (this.grammar !== undefined ? this.grammar.name : this.language))
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
    .backgroundColor(this.palette.backgroundOf(this.theme.isDark) ??
      (this.theme.isDark ? SparkColor.alpha(this.theme.colors.muted, 0.4) :
      SparkColor.mix(this.theme.colors.background, this.theme.colors.muted, 0.6)))
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
    .clip(true)
  }
}
