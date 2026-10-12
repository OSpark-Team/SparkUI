/**
 * Built-in grammars, expressed through the public SparkGrammar API (the same one apps use).
 * Registered by CodeHighlighter on first use; read them with `CodeHighlighter.grammar('ts')` to extend.
 */
import { SparkGrammar, SparkGrammarRule } from './SparkGrammar';

const WS: SparkGrammarRule = { pattern: /\s+/ };
const LINE_COMMENT: SparkGrammarRule = { token: 'comment', pattern: /\/\/[^\n]*/ };
const BLOCK_COMMENT: SparkGrammarRule = { token: 'comment', pattern: /\/\*[\s\S]*?(?:\*\/|$)/ };
const HASH_COMMENT: SparkGrammarRule = { token: 'comment', pattern: /#[^\n]*/ };
// Single-line strings; an unterminated string stops at the end of the line.
const DQ_STRING: SparkGrammarRule = { token: 'string', pattern: /"(?:\\[\s\S]|[^\\"\n])*"?/ };
const SQ_STRING: SparkGrammarRule = { token: 'string', pattern: /'(?:\\[\s\S]|[^\\'\n])*'?/ };

// ------------------------------------------------------------------------------------------------ TypeScript / ArkTS

const TS_KEYWORDS: string[] = [
  'abstract', 'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'delete',
  'do', 'else', 'enum', 'export', 'extends', 'false', 'finally', 'for', 'from', 'function', 'get', 'if', 'implements',
  'import', 'in', 'instanceof', 'interface', 'let', 'new', 'null', 'of', 'private', 'protected', 'public',
  'readonly', 'return', 'set', 'static', 'struct', 'super', 'switch', 'this', 'throw', 'true', 'try', 'type',
  'typeof', 'undefined', 'var', 'void', 'while', 'yield', 'build', 'number', 'string', 'boolean', 'any', 'unknown',
  'never', 'object'
];

/** `${ expr }` inside a template string: delimiters as punctuation, the expression as TypeScript. */
const TS_INTERPOLATION: SparkGrammar = {
  name: 'ts-interpolation',
  rules: [
    { token: 'punctuation', pattern: /^\$\{|\}$/ },
    { include: 'ts' }
  ]
};

/** Body of a template string (unmatched text stays 'string'). */
const TS_TEMPLATE: SparkGrammar = {
  name: 'ts-template',
  rules: [
    { token: 'string', pattern: /\\[\s\S]/ },
    { pattern: /\$\{[^{}`]*\}/, inside: TS_INTERPOLATION }
  ]
};

export const TS_GRAMMAR: SparkGrammar = {
  name: 'ts',
  aliases: ['typescript', 'arkts', 'ets', 'js', 'javascript', 'tsx', 'jsx'],
  rules: [
    WS,
    LINE_COMMENT,
    BLOCK_COMMENT,
    // unambiguous alternatives: `$` is either an interpolation start or a lone '$' (linear even when unterminated)
    { token: 'string', pattern: /`(?:\\[\s\S]|\$\{[^{}`]*\}|[^\\`$]|\$(?!\{))*`?/, inside: TS_TEMPLATE },
    DQ_STRING,
    SQ_STRING,
    {
      token: 'number',
      pattern: /(?:0[xX][\da-fA-F_]+|0[bB][01_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?)n?/
    },
    { token: 'decorator', pattern: /@[A-Za-z_$][\w$]*/ },
    { token: 'keyword', words: TS_KEYWORDS },
    { token: 'function', pattern: /[A-Za-z_$][\w$]*(?=[ \t]*\()/ },
    { token: 'type', pattern: /[A-Z][\w$]*/ },
    { pattern: /[A-Za-z_$][\w$]*/ },
    { token: 'punctuation', pattern: /[^\s\w\u0080-￿]/ }
  ]
};

// ------------------------------------------------------------------------------------------------ CSS

const CSS_BLOCK: SparkGrammar = {
  name: 'css-block',
  rules: [
    WS,
    BLOCK_COMMENT,
    DQ_STRING,
    SQ_STRING,
    { token: 'punctuation', pattern: /\}/, pop: true },
    { token: 'punctuation', pattern: /\{/, push: '$self' },
    { token: 'keyword', pattern: /@[\w-]+|!important\b/ },
    { token: 'number', pattern: /#[\da-fA-F]+/ },
    { token: 'number', pattern: /-?(?:\d[\d.]*|\.\d+)(?:[eE][+-]?\d+)?[a-zA-Z%]*/ },
    { token: 'property', pattern: /[\w-]+(?=[ \t]*:)/ },
    { token: 'function', pattern: /[\w-]+(?=[ \t]*\()/ },
    { pattern: /[\w-]+/ },
    { token: 'punctuation', pattern: /[^\s\w]/ }
  ]
};

export const CSS_GRAMMAR: SparkGrammar = {
  name: 'css',
  aliases: ['scss', 'less'],
  rules: [
    WS,
    BLOCK_COMMENT,
    DQ_STRING,
    SQ_STRING,
    { token: 'keyword', pattern: /@[\w-]+/ },
    { token: 'punctuation', pattern: /\{/, push: CSS_BLOCK },
    { token: 'number', pattern: /\d[\d.]*[a-zA-Z%]*/ },
    { token: 'type', pattern: /[.:#]?[\w-]+/ },
    { token: 'punctuation', pattern: /[^\s\w]/ }
  ]
};

// ------------------------------------------------------------------------------------------------ JSON

export const JSON_GRAMMAR: SparkGrammar = {
  name: 'json',
  aliases: ['json5', 'jsonc'],
  rules: [
    WS,
    LINE_COMMENT,
    BLOCK_COMMENT,
    { token: 'property', pattern: /"(?:\\[\s\S]|[^\\"\n])*"(?=\s*:)/ },
    DQ_STRING,
    { token: 'number', pattern: /-?\d[\d.]*(?:[eE][+-]?\d+)?/ },
    { token: 'keyword', words: ['true', 'false', 'null'] },
    { pattern: /[A-Za-z_]\w*/ },
    { token: 'punctuation', pattern: /[^\s]/ }
  ]
};

// ------------------------------------------------------------------------------------------------ Bash

const BASH_VARIABLE: SparkGrammarRule = { token: 'variable', pattern: /\$(?:\{[^}\n]*\}|\w+|[@#?*!$-])/ };

/** Arguments of a command, until the end of the line or a command separator. */
const BASH_ARGS: SparkGrammar = {
  name: 'bash-args',
  rules: [
    { pattern: /\n/, pop: true },
    { pattern: /[ \t]+/ },
    HASH_COMMENT,
    { token: 'string', pattern: /"(?:\\[\s\S]|[^\\"])*"?/ },
    { token: 'string', pattern: /'[^']*'?/ },
    BASH_VARIABLE,
    { pattern: /\|\||&&|\||;/, pop: true },
    { token: 'keyword', pattern: /-[^\s"'$;|&]*/ },
    { pattern: /[^\s"'$;|&]+/ }
  ]
};

export const BASH_GRAMMAR: SparkGrammar = {
  name: 'bash',
  aliases: ['sh', 'shell', 'zsh', 'console'],
  icon: 'terminal',
  rules: [
    WS,
    HASH_COMMENT,
    // keywords followed by a command stay in command position; the others take arguments
    { token: 'keyword', pattern: /(?:if|then|elif|else|fi|while|until|do|done|esac|sudo|time)(?![^\s;|&])/ },
    { token: 'keyword', pattern: /(?:for|case|function|return|export|local|unset)(?![^\s;|&])/, push: BASH_ARGS },
    { pattern: /([A-Za-z_]\w*)(=)([^\s;|&]*)/, captures: ['variable', 'punctuation', 'string'] },
    { token: 'string', pattern: /"(?:\\[\s\S]|[^\\"])*"?|'[^']*'?/, push: BASH_ARGS },
    { token: 'variable', pattern: /\$(?:\{[^}\n]*\}|\w+|[@#?*!$-])/, push: BASH_ARGS },
    { token: 'function', pattern: /[^\s"'#$;|&][^\s"'$;|&]*/, push: BASH_ARGS },
    { pattern: /[;|&]+/ }
  ]
};

// ------------------------------------------------------------------------------------------------ HTML / XML

const HTML_TAG: SparkGrammar = {
  name: 'html-tag',
  rules: [
    WS,
    { token: 'punctuation', pattern: /\/?>/, pop: true },
    { token: 'string', pattern: /"[^"]*"?|'[^']*'?/ },
    { token: 'punctuation', pattern: /=/ },
    { token: 'attribute', pattern: /[^\s"'=<>\/]+/ },
    { token: 'punctuation', pattern: /[^\s]/ }
  ]
};

export const HTML_GRAMMAR: SparkGrammar = {
  name: 'html',
  aliases: ['xml', 'svg', 'vue'],
  rules: [
    { token: 'comment', pattern: /<!--[\s\S]*?(?:-->|$)/ },
    { token: 'meta', pattern: /<[!?][^>]*>?/ },
    { pattern: /(<\/?)([\w:.-]+)/, captures: ['punctuation', 'tag'], push: HTML_TAG },
    { token: 'variable', pattern: /&#?\w+;/ },
    { pattern: /[^<&]+/ }
  ]
};

// ------------------------------------------------------------------------------------------------ Python

export const PYTHON_GRAMMAR: SparkGrammar = {
  name: 'python',
  aliases: ['py'],
  rules: [
    WS,
    HASH_COMMENT,
    { token: 'string', pattern: /[rRbBuUfF]{0,2}(?:"""[\s\S]*?(?:"""|$)|'''[\s\S]*?(?:'''|$))/ },
    { token: 'string', pattern: /[rRbBuUfF]{0,2}(?:"(?:\\[\s\S]|[^\\"\n])*"?|'(?:\\[\s\S]|[^\\'\n])*'?)/ },
    { token: 'decorator', pattern: /@[\w.]+/ },
    { token: 'number', pattern: /(?:0[xXbBoO][\da-fA-F_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?)j?/ },
    { pattern: /(def)(\s+)([A-Za-z_]\w*)/, captures: ['keyword', 'plain', 'function'] },
    { pattern: /(class)(\s+)([A-Za-z_]\w*)/, captures: ['keyword', 'plain', 'type'] },
    {
      token: 'keyword',
      words: ['False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def',
        'del', 'elif', 'else', 'except', 'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda',
        'match', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'self', 'try', 'while', 'with', 'yield']
    },
    { token: 'function', pattern: /[A-Za-z_]\w*(?=[ \t]*\()/ },
    { token: 'type', pattern: /[A-Z]\w*/ },
    { pattern: /[A-Za-z_]\w*/ },
    { token: 'punctuation', pattern: /[^\s\w\u0080-￿]/ }
  ]
};

// ------------------------------------------------------------------------------------------------ Diff

/** Every rule consumes a whole line, so each match starts at a line start. */
export const DIFF_GRAMMAR: SparkGrammar = {
  name: 'diff',
  aliases: ['patch'],
  rules: [
    { pattern: /\n/ },
    { token: 'meta', pattern: /(?:@@|diff |index |\+\+\+ |--- )[^\n]*/ },
    { token: 'inserted', pattern: /\+[^\n]*/ },
    { token: 'deleted', pattern: /-[^\n]*/ },
    { pattern: /[^\n]+/ }
  ]
};

/** Plain text: no rules, everything is 'plain'. Also the fallback for unknown languages. */
export const TEXT_GRAMMAR: SparkGrammar = {
  name: 'text',
  aliases: ['plain', 'txt', 'plaintext'],
  rules: []
};

export const SPARK_BUILTIN_GRAMMARS: SparkGrammar[] = [
  TS_GRAMMAR, CSS_GRAMMAR, JSON_GRAMMAR, BASH_GRAMMAR, HTML_GRAMMAR, PYTHON_GRAMMAR, DIFF_GRAMMAR, TEXT_GRAMMAR
];
