import { describe, it, expect } from '@ohos/hypium';
import { CodeHighlighter, CodeToken } from '../main/ets/components/code/CodeHighlighter';
import { SparkCodeTheme } from '../main/ets/components/code/SparkCodeTheme';
import { SparkGrammar } from '../main/ets/components/code/SparkGrammar';
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
    it('template_interpolation', 0, () => {
      const k = kinds(CodeHighlighter.tokenize('`a ${n + 1} b`', 'ts'));
      expect(k).assertEqual('string:`a  punctuation:${ punctuation:+ number:1 punctuation:} string: b`');
      // unterminated / nested braces degrade without hanging
      const src = '`x ${ {a: 1} } y';
      expect(CodeHighlighter.tokenize(src, 'ts').map((t: CodeToken) => t.text).join('')).assertEqual(src);
    });
    it('bash_states', 0, () => {
      const k = kinds(CodeHighlighter.tokenize('FOO=1 echo $HOME | grep -i x; then ls', 'bash'));
      expect(k).assertEqual('variable:FOO punctuation:= string:1 function:echo variable:$HOME function:grep ' +
        'keyword:-i keyword:then function:ls');
    });
    it('more_builtins', 0, () => {
      expect(kinds(CodeHighlighter.tokenize('<a href="x">t</a>', 'html'))).assertEqual(
        'punctuation:< tag:a attribute:href punctuation:= string:"x" punctuation:> punctuation:</ tag:a punctuation:>');
      expect(kinds(CodeHighlighter.tokenize('def f(x):\n  return None', 'py')).indexOf('function:f') >= 0).assertTrue();
      expect(kinds(CodeHighlighter.tokenize('--- a\n+add\n-del', 'diff'))).assertEqual(
        'meta:--- a inserted:+add deleted:-del');
      expect(CodeHighlighter.grammar('TypeScript')?.name).assertEqual('ts');
      expect(kinds(CodeHighlighter.tokenize('if x', 'nope-lang'))).assertEqual('');
    });
    it('custom_grammar_registry', 0, () => {
      CodeHighlighter.register({
        name: 'mini-sql',
        aliases: ['msql'],
        caseInsensitive: true,
        rules: [
          { pattern: /\s+/ },
          { token: 'comment', pattern: '--[^\\n]*' },
          { token: 'string', pattern: /'(?:''|[^'])*'?/ },
          { token: 'keyword', words: ['select', 'from', 'where'] },
          { token: 'number', pattern: /\d+/ },
          { pattern: /\w+/ }
        ]
      });
      expect(CodeHighlighter.languages().indexOf('mini-sql') >= 0).assertTrue();
      expect(kinds(CodeHighlighter.tokenize("SELECT a FROM t WHERE b = 'it''s' -- c", 'MSQL'))).assertEqual(
        "keyword:SELECT keyword:FROM keyword:WHERE string:'it''s' comment:-- c");
      expect(kinds(CodeHighlighter.tokenize('selection', 'msql'))).assertEqual(''); // word boundary
      expect(CodeHighlighter.registerAlias('sqlx', 'mini-sql')).assertTrue();
      expect(CodeHighlighter.registerAlias('zz', 'missing')).assertFalse();
      expect(kinds(CodeHighlighter.tokenize('select 1', 'sqlx'))).assertEqual('keyword:select number:1');
    });
    it('grammar_object_captures_and_states', 0, () => {
      const inner: SparkGrammar = {
        name: 'inner', defaultToken: 'variable', rules: [{ token: 'punctuation', pattern: /\}/, pop: true }]
      };
      const blocks: SparkGrammar = {
        name: 'blocks',
        rules: [
          { pattern: /(fn)(\s+)(\w+)/, captures: ['keyword', 'plain', 'function'] },
          { token: 'punctuation', pattern: /\{/, push: inner },
          { token: 'keyword', words: ['fn'] }
        ]
      };
      const t = CodeHighlighter.tokenize('fn add {x} fn', blocks);
      expect(kinds(t)).assertEqual('keyword:fn function:add punctuation:{ variable:x punctuation:} keyword:fn');
    });
    it('inside_include_and_self', 0, () => {
      const esc: SparkGrammar = { name: 'esc', rules: [{ token: 'number', pattern: /\d+/ }] };
      const g = CodeHighlighter.register({
        name: 'nest',
        rules: [
          { token: 'punctuation', pattern: /\(/, push: '$self' },
          { token: 'punctuation', pattern: /\)/, pop: true },
          { token: 'string', pattern: /"[^"]*"/, inside: esc },
          { include: 'json' }
        ]
      });
      expect(kinds(CodeHighlighter.tokenize('(("a1b") true)', g))).assertEqual(
        'punctuation:(( string:"a number:1 string:b" punctuation:) keyword:true punctuation:)');
    });
    it('extend_builtin', 0, () => {
      const g = CodeHighlighter.extend('ts', { name: 'my-ts', keywords: ['observe'], exclude: ['type'] });
      const k = kinds(CodeHighlighter.tokenize('observe Foo; const x', g));
      expect(k).assertEqual('keyword:observe punctuation:; keyword:const');
      // the base grammar is untouched
      expect(kinds(CodeHighlighter.tokenize('observe Foo', 'ts'))).assertEqual('type:Foo');
    });
    it('bad_and_empty_patterns_are_safe', 0, () => {
      const bad: SparkGrammar = {
        name: 'bad',
        rules: [{ token: 'x', pattern: '(' }, { token: 'y', pattern: /a*?/ }, { token: 'z', pattern: /b/ }]
      };
      const t = CodeHighlighter.tokenize('aab', bad);
      expect(kinds(t)).assertEqual('z:b');
    });
    it('linear_on_pathological_input', 0, () => {
      const long = '"' + 'a\\'.repeat(5000) + '\n' + '`${'.repeat(3000) + '/*' + 'x'.repeat(20000);
      const start = Date.now();
      const text = CodeHighlighter.tokenize(long, 'ts').map((t: CodeToken) => t.text).join('');
      expect(text).assertEqual(long);
      expect(Date.now() - start < 2000).assertTrue();
    });
  });

  describe('SparkCodeTheme', () => {
    it('lookup_fallbacks_and_variables', 0, () => {
      const t = SparkCodeTheme.github().copy('x').color('keyword', '#FF111111', '#FF222222');
      expect(t.colorOf('keyword.control', false, '-')).assertEqual('#FF111111');
      expect(t.colorOf('keyword', true, '-')).assertEqual('#FF222222');
      expect(t.colorOf('nothing', false, '-')).assertEqual('-');
      expect(t.isItalic('comment', false)).assertTrue();
      const light = new Map<string, string>([['--code-keyword', '#ff0000'], ['--code-background', '#000'],
        ['--other', '#fff'], ['--code-string', 'nonsense']]);
      const dark = new Map<string, string>([['--code-keyword', '#00ff00']]);
      const v = SparkCodeTheme.fromVariables(light, dark);
      expect(v.colorOf('keyword', false, '-')).assertEqual('#FFFF0000');
      expect(v.colorOf('keyword', true, '-')).assertEqual('#FF00FF00');
      expect(v.backgroundOf(true)).assertEqual('#FF000000');
      expect(v.colorOf('string', false, '-')).assertEqual(SparkCodeTheme.github().colorOf('string', false, '?'));
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
