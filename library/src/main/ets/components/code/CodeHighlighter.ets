/**
 * Small, dependency-free syntax highlighter for SCodeBlock. Pure and unit-tested.
 * Supported languages: ts / arkts / js, css, json, bash, text.
 */
export type CodeLanguage = 'ts' | 'arkts' | 'js' | 'css' | 'json' | 'bash' | 'text';

export type CodeTokenKind = 'plain' | 'keyword' | 'string' | 'comment' | 'number' | 'decorator' | 'type' |
  'function' | 'property' | 'punctuation';

export class CodeToken {
  text: string;
  kind: CodeTokenKind;

  constructor(text: string, kind: CodeTokenKind) {
    this.text = text;
    this.kind = kind;
  }
}

const TS_KEYWORDS: Set<string> = new Set<string>([
  'abstract', 'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'delete',
  'do', 'else', 'enum', 'export', 'extends', 'false', 'finally', 'for', 'from', 'function', 'get', 'if', 'implements',
  'import', 'in', 'instanceof', 'interface', 'let', 'new', 'null', 'of', 'private', 'protected', 'public',
  'readonly', 'return', 'set', 'static', 'struct', 'super', 'switch', 'this', 'throw', 'true', 'try', 'type',
  'typeof', 'undefined', 'var', 'void', 'while', 'yield', 'build', 'number', 'string', 'boolean', 'any', 'unknown',
  'never', 'object'
]);

const JSON_KEYWORDS: Set<string> = new Set<string>(['true', 'false', 'null']);

function isIdentStart(c: string): boolean {
  return /[A-Za-z_$]/.test(c);
}

function isIdentPart(c: string): boolean {
  return /[A-Za-z0-9_$]/.test(c);
}

function isDigit(c: string): boolean {
  return c >= '0' && c <= '9';
}

/** Scan a quoted string starting at `i` (quote char at i); returns end index (exclusive). */
function scanString(src: string, i: number): number {
  const q = src[i];
  let j = i + 1;
  while (j < src.length) {
    const c = src[j];
    if (c === '\\') {
      j += 2;
      continue;
    }
    if (c === q) {
      return j + 1;
    }
    if (c === '\n' && q !== '`') {
      return j;
    }
    j++;
  }
  return src.length;
}

function scanNumber(src: string, i: number, allowUnits: boolean): number {
  let j = i;
  if (src[j] === '0' && (src[j + 1] === 'x' || src[j + 1] === 'X')) {
    j += 2;
    while (j < src.length && /[0-9a-fA-F_]/.test(src[j])) {
      j++;
    }
    return j;
  }
  while (j < src.length && /[0-9._]/.test(src[j])) {
    j++;
  }
  if (j < src.length && (src[j] === 'e' || src[j] === 'E') && /[0-9+-]/.test(src[j + 1] ?? '')) {
    j += 2;
    while (j < src.length && isDigit(src[j])) {
      j++;
    }
  }
  if (allowUnits) {
    while (j < src.length && /[a-zA-Z%]/.test(src[j])) {
      j++;
    }
  }
  return j;
}

function nextNonSpace(src: string, i: number): string {
  let j = i;
  while (j < src.length && (src[j] === ' ' || src[j] === '\t')) {
    j++;
  }
  return src[j] ?? '';
}

export class CodeHighlighter {
  /** Tokenise and split into lines (tokens never span lines). */
  static highlight(code: string, language: CodeLanguage): CodeToken[][] {
    const tokens = CodeHighlighter.tokenize(code.replace(/\r\n/g, '\n').replace(/\t/g, '  '), language);
    const lines: CodeToken[][] = [[]];
    for (const t of tokens) {
      const parts = t.text.split('\n');
      parts.forEach((part: string, idx: number) => {
        if (idx > 0) {
          lines.push([]);
        }
        if (part.length > 0) {
          lines[lines.length - 1].push(new CodeToken(part, t.kind));
        }
      });
    }
    // drop a single trailing empty line
    if (lines.length > 1 && lines[lines.length - 1].length === 0) {
      lines.pop();
    }
    return lines;
  }

  static tokenize(src: string, language: CodeLanguage): CodeToken[] {
    switch (language) {
      case 'css':
        return CodeHighlighter.tokenizeCss(src);
      case 'json':
        return CodeHighlighter.tokenizeJson(src);
      case 'bash':
        return CodeHighlighter.tokenizeBash(src);
      case 'text':
        return [new CodeToken(src, 'plain')];
      default:
        return CodeHighlighter.tokenizeTs(src);
    }
  }

  private static push(out: CodeToken[], text: string, kind: CodeTokenKind): void {
    const last = out.length > 0 ? out[out.length - 1] : undefined;
    if (last !== undefined && last.kind === kind && (kind === 'plain' || kind === 'punctuation')) {
      last.text += text;
    } else {
      out.push(new CodeToken(text, kind));
    }
  }

  private static tokenizeTs(src: string): CodeToken[] {
    const out: CodeToken[] = [];
    let i = 0;
    while (i < src.length) {
      const c = src[i];
      const n = src[i + 1] ?? '';
      if (c === '/' && n === '/') {
        let j = src.indexOf('\n', i);
        j = j < 0 ? src.length : j;
        CodeHighlighter.push(out, src.substring(i, j), 'comment');
        i = j;
      } else if (c === '/' && n === '*') {
        let j = src.indexOf('*/', i + 2);
        j = j < 0 ? src.length : j + 2;
        CodeHighlighter.push(out, src.substring(i, j), 'comment');
        i = j;
      } else if (c === '"' || c === '\'' || c === '`') {
        const j = scanString(src, i);
        CodeHighlighter.push(out, src.substring(i, j), 'string');
        i = j;
      } else if (isDigit(c) || (c === '.' && isDigit(n))) {
        const j = scanNumber(src, i, false);
        CodeHighlighter.push(out, src.substring(i, j), 'number');
        i = j;
      } else if (c === '@' && isIdentStart(n)) {
        let j = i + 1;
        while (j < src.length && isIdentPart(src[j])) {
          j++;
        }
        CodeHighlighter.push(out, src.substring(i, j), 'decorator');
        i = j;
      } else if (isIdentStart(c)) {
        let j = i;
        while (j < src.length && isIdentPart(src[j])) {
          j++;
        }
        const word = src.substring(i, j);
        let kind: CodeTokenKind = 'plain';
        if (TS_KEYWORDS.has(word)) {
          kind = 'keyword';
        } else if (nextNonSpace(src, j) === '(') {
          kind = 'function';
        } else if (/^[A-Z]/.test(word)) {
          kind = 'type';
        }
        CodeHighlighter.push(out, word, kind);
        i = j;
      } else if (/\s/.test(c)) {
        let j = i;
        while (j < src.length && /\s/.test(src[j])) {
          j++;
        }
        CodeHighlighter.push(out, src.substring(i, j), 'plain');
        i = j;
      } else {
        CodeHighlighter.push(out, c, 'punctuation');
        i++;
      }
    }
    return out;
  }

  private static tokenizeCss(src: string): CodeToken[] {
    const out: CodeToken[] = [];
    let i = 0;
    let depth = 0;
    while (i < src.length) {
      const c = src[i];
      const n = src[i + 1] ?? '';
      if (c === '/' && n === '*') {
        let j = src.indexOf('*/', i + 2);
        j = j < 0 ? src.length : j + 2;
        CodeHighlighter.push(out, src.substring(i, j), 'comment');
        i = j;
      } else if (c === '"' || c === '\'') {
        const j = scanString(src, i);
        CodeHighlighter.push(out, src.substring(i, j), 'string');
        i = j;
      } else if (c === '@') {
        let j = i + 1;
        while (j < src.length && /[\w-]/.test(src[j])) {
          j++;
        }
        CodeHighlighter.push(out, src.substring(i, j), 'keyword');
        i = j;
      } else if (c === '#' && depth > 0) {
        let j = i + 1;
        while (j < src.length && /[0-9a-fA-F]/.test(src[j])) {
          j++;
        }
        CodeHighlighter.push(out, src.substring(i, j), 'number');
        i = j;
      } else if (isDigit(c) || (c === '.' && isDigit(n)) || (c === '-' && (isDigit(n) || n === '.') && depth > 0)) {
        const j = scanNumber(src, c === '-' ? i + 1 : i, true);
        CodeHighlighter.push(out, src.substring(i, j), 'number');
        i = j;
      } else if (/[\w-]/.test(c) || ((c === '.' || c === ':') && depth === 0 && /[\w-]/.test(n))) {
        let j = i + 1;
        while (j < src.length && /[\w-]/.test(src[j])) {
          j++;
        }
        const word = src.substring(i, j);
        let kind: CodeTokenKind = 'plain';
        if (depth === 0) {
          kind = 'type';
        } else if (nextNonSpace(src, j) === ':') {
          kind = 'property';
        } else if (nextNonSpace(src, j) === '(') {
          kind = 'function';
        }
        CodeHighlighter.push(out, word, kind);
        i = j;
      } else {
        if (c === '{') {
          depth++;
        } else if (c === '}') {
          depth = Math.max(0, depth - 1);
        }
        CodeHighlighter.push(out, c, /\s/.test(c) ? 'plain' : 'punctuation');
        i++;
      }
    }
    return out;
  }

  private static tokenizeJson(src: string): CodeToken[] {
    const out: CodeToken[] = [];
    let i = 0;
    while (i < src.length) {
      const c = src[i];
      if (c === '"') {
        const j = scanString(src, i);
        CodeHighlighter.push(out, src.substring(i, j), nextNonSpace(src, j) === ':' ? 'property' : 'string');
        i = j;
      } else if (isDigit(c) || c === '-') {
        const j = scanNumber(src, c === '-' ? i + 1 : i, false);
        CodeHighlighter.push(out, src.substring(i, j), 'number');
        i = j;
      } else if (/[a-z]/.test(c)) {
        let j = i;
        while (j < src.length && /[a-z]/.test(src[j])) {
          j++;
        }
        const w = src.substring(i, j);
        CodeHighlighter.push(out, w, JSON_KEYWORDS.has(w) ? 'keyword' : 'plain');
        i = j;
      } else {
        CodeHighlighter.push(out, c, /\s/.test(c) ? 'plain' : 'punctuation');
        i++;
      }
    }
    return out;
  }

  private static tokenizeBash(src: string): CodeToken[] {
    const out: CodeToken[] = [];
    let i = 0;
    let lineStart = true;
    while (i < src.length) {
      const c = src[i];
      if (c === '\n') {
        CodeHighlighter.push(out, c, 'plain');
        lineStart = true;
        i++;
      } else if (c === ' ' || c === '\t') {
        CodeHighlighter.push(out, c, 'plain');
        i++;
      } else if (c === '#') {
        let j = src.indexOf('\n', i);
        j = j < 0 ? src.length : j;
        CodeHighlighter.push(out, src.substring(i, j), 'comment');
        i = j;
      } else if (c === '"' || c === '\'') {
        const j = scanString(src, i);
        CodeHighlighter.push(out, src.substring(i, j), 'string');
        lineStart = false;
        i = j;
      } else {
        let j = i;
        while (j < src.length && !/[\s"']/.test(src[j])) {
          j++;
        }
        const word = src.substring(i, j);
        const kind: CodeTokenKind = lineStart ? 'function' : (word.startsWith('-') ? 'keyword' : 'plain');
        CodeHighlighter.push(out, word, kind);
        lineStart = word === '|' || word === '&&' || word === ';';
        i = j;
      }
    }
    return out;
  }
}
