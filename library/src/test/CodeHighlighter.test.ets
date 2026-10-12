import { describe, it, expect } from '@ohos/hypium';
import { CodeHighlighter, CodeToken } from '../main/ets/components/code/CodeHighlighter';
import { accentCss, presetCss, SPARK_ACCENTS } from '../main/ets/theme/presets/Presets';
import { ThemeCssParser } from '../main/ets/theme/css/ThemeCssParser';
import { ThemeResolver } from '../main/ets/theme/css/ThemeResolver';
import { SparkTheme } from '../main/ets/theme/tokens/SparkTheme';

function kinds(tokens: CodeToken[]): string {
  return tokens.filter((t: CodeToken) => t.kind !== 'plain').map((t: CodeToken) => `${t.kind}:${t.text}`).join(' ');
}

export default function codeHighlighterTest() {
  describe('CodeHighlighter', () => {
    it('arkts_tokens', 0, () => {
      const t = CodeHighlighter.tokenize("@Local count: number = 0; // c\nSButton({ text: 'Hi' })", 'arkts');
      expect(kinds(t)).assertEqual(
        "decorator:@Local punctuation:: keyword:number punctuation:= number:0 punctuation:; comment:// c " +
          "function:SButton punctuation:({ punctuation:: string:'Hi' punctuation:})");
    });
    it('splits_lines_and_block_comments', 0, () => {
      const lines = CodeHighlighter.highlight('/* a\nb */\nconst x = `t\nu`;\n', 'ts');
      expect(lines.length).assertEqual(4);
      expect(lines[0][0].kind).assertEqual('comment');
      expect(lines[1][0].text).assertEqual('b */');
      expect(lines[3][0].kind).assertEqual('string');
    });
    it('types_and_functions', 0, () => {
      const t = CodeHighlighter.tokenize('new SparkTheme(); theme.copyFrom (x)', 'ts');
      expect(kinds(t).indexOf('function:SparkTheme') >= 0).assertTrue();
      expect(kinds(t).indexOf('function:copyFrom') >= 0).assertTrue();
      expect(kinds(CodeHighlighter.tokenize('let a: Foo', 'ts')).indexOf('type:Foo') >= 0).assertTrue();
    });
    it('css_tokens', 0, () => {
      const t = CodeHighlighter.tokenize(':root {\n  --radius: 0.625rem;\n  --primary: oklch(0.2 0 0);\n}', 'css');
      const k = kinds(t);
      expect(k.indexOf('type::root') >= 0).assertTrue();
      expect(k.indexOf('property:--radius') >= 0).assertTrue();
      expect(k.indexOf('number:0.625rem') >= 0).assertTrue();
      expect(k.indexOf('function:oklch') >= 0).assertTrue();
    });
    it('json_tokens', 0, () => {
      const k = kinds(CodeHighlighter.tokenize('{"a": "b", "n": -1.5, "t": true}', 'json'));
      expect(k).assertEqual(
        'punctuation:{ property:"a" punctuation:: string:"b" punctuation:, property:"n" punctuation:: number:-1.5 ' +
          'punctuation:, property:"t" punctuation:: keyword:true punctuation:}');
    });
    it('bash_tokens', 0, () => {
      const k = kinds(CodeHighlighter.tokenize('ohpm install @sparkui/core # add\ndevecocli build --modules lib', 'bash'));
      expect(k).assertEqual('function:ohpm comment:# add function:devecocli keyword:--modules');
    });
    it('round_trips_text', 0, () => {
      const src = 'a  b\n\tc "d" /* e */';
      const text = CodeHighlighter.tokenize(src, 'ts').map((t: CodeToken) => t.text).join('');
      expect(text).assertEqual(src);
    });
  });

  describe('Accent themes', () => {
    it('accents_resolve_without_errors', 0, () => {
      const base = ThemeCssParser.parse(presetCss('neutral') as string);
      SPARK_ACCENTS.forEach((a: string) => {
        const src = base.merge(ThemeCssParser.parse(accentCss(a)));
        expect(src.diagnostics.length).assertEqual(0);
        const t = new SparkTheme();
        expect(ThemeResolver.apply(src, false, 'compact', t).length).assertEqual(0);
        expect(ThemeResolver.apply(src, true, 'compact', t).length).assertEqual(0);
      });
      const blue = new SparkTheme();
      ThemeResolver.apply(base.merge(ThemeCssParser.parse(accentCss('blue'))), false, 'compact', blue);
      expect(blue.colors.primary).assertEqual('#FF155DFC'); // Tailwind blue-600
    });
  });
}
