/**
 * A small, tolerant parser for the subset of ArkTS used in SparkUI examples.
 *
 * It understands enough of TypeScript/ArkTS to build a tree out of declarative UI code:
 *  - component calls with object-literal args, trailing-closure children and chained attributes
 *    (`Column({ space: 8 }) { Text('a') }.width('100%')`)
 *  - literals (string, template, number, boolean, null/undefined, arrays, objects), arrow functions,
 *    member access, calls, `new`, unary/binary/ternary/assignment operators, `as` casts, `!` / `!!`
 *  - `if / else`, `ForEach(...)`, `const/let` declarations, struct declarations
 *    (`@Local x: T = v` fields become demo state, `build()` becomes the UI body)
 *
 * The parser never throws on a whole program: a statement it cannot read becomes an `error` node and
 * parsing resumes at the next line. Shared by the docs build scripts (Node) and the browser previewer.
 */

const PUNCT = [
  '>>>=', '...', '===', '!==', '**=', '<<=', '>>=', '>>>', '&&=', '||=', '??=',
  '=>', '==', '!=', '<=', '>=', '&&', '||', '??', '?.', '++', '--', '+=', '-=', '*=', '/=', '%=', '&=', '|=',
  '^=', '**', '<<', '>>',
  '{', '}', '(', ')', '[', ']', ';', ',', '<', '>', '+', '-', '*', '/', '%', '&', '|', '^', '!', '~', '?', ':',
  '=', '.', '@'
];

export class ParseError extends Error {
  constructor(message, pos) {
    super(message);
    this.pos = pos;
  }
}

function isIdStart(c) {
  return /[A-Za-z_$À-￿]/.test(c);
}

function isIdPart(c) {
  return /[A-Za-z0-9_$À-￿]/.test(c);
}

/** Tokenize source. Tokens: {t: kind, v: value, s: start, e: end, nl: newline before, sp: space before} */
export function tokenize(src) {
  const out = [];
  let i = 0;
  let nl = false;
  let sp = false;
  let doc = null;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === '\n') {
      nl = true;
      sp = true;
      i++;
      continue;
    }
    if (c === ' ' || c === '\t' || c === '\r' || c === '\f' || c === '\v' || c === ' ') {
      sp = true;
      i++;
      continue;
    }
    if (c === '/' && src[i + 1] === '/') {
      while (i < n && src[i] !== '\n') {
        i++;
      }
      sp = true;
      continue;
    }
    if (c === '/' && src[i + 1] === '*') {
      const end = src.indexOf('*/', i + 2);
      const stop = end < 0 ? n : end + 2;
      doc = src[i + 2] === '*' ? src.slice(i + 3, stop - 2) : doc;
      if (src.slice(i, stop).includes('\n')) {
        nl = true;
      }
      i = stop;
      sp = true;
      continue;
    }
    const start = i;
    let tok;
    if (c === '\'' || c === '"') {
      let v = '';
      i++;
      while (i < n && src[i] !== c) {
        if (src[i] === '\\') {
          v += unescape(src[i + 1]);
          i += 2;
        } else if (src[i] === '\n') {
          break;
        } else {
          v += src[i++];
        }
      }
      i++;
      tok = { t: 'str', v };
    } else if (c === '`') {
      // template literal: quasis + raw expression sources
      const quasis = [];
      const exprs = [];
      let cur = '';
      i++;
      while (i < n && src[i] !== '`') {
        if (src[i] === '\\') {
          cur += unescape(src[i + 1]);
          i += 2;
        } else if (src[i] === '$' && src[i + 1] === '{') {
          quasis.push(cur);
          cur = '';
          i += 2;
          let depth = 1;
          const es = i;
          while (i < n && depth > 0) {
            const d = src[i];
            if (d === '{') {
              depth++;
            } else if (d === '}') {
              depth--;
            } else if (d === '\'' || d === '"' || d === '`') {
              i = skipString(src, i);
              continue;
            }
            i++;
          }
          exprs.push(src.slice(es, i - 1));
        } else {
          cur += src[i++];
        }
      }
      quasis.push(cur);
      i++;
      tok = { t: 'tpl', quasis, exprs };
    } else if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(src[i + 1] || ''))) {
      let m = /^(0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:\d[\d_]*)?\.?\d[\d_]*(?:[eE][+-]?\d+)?)/.exec(src.slice(i));
      const raw = m ? m[0] : c;
      i += raw.length;
      tok = { t: 'num', v: Number(raw.replace(/_/g, '')) };
    } else if (c === '/' && regexAllowed(out[out.length - 1])) {
      // regular expression literal
      i++;
      let inClass = false;
      while (i < n && src[i] !== '\n') {
        const d = src[i];
        if (d === '\\') {
          i += 2;
          continue;
        }
        if (d === '[') {
          inClass = true;
        } else if (d === ']') {
          inClass = false;
        } else if (d === '/' && !inClass) {
          break;
        }
        i++;
      }
      i++;
      const bodyEnd = i;
      while (i < n && /[a-z]/.test(src[i])) {
        i++;
      }
      tok = { t: 'regex', v: src.slice(start, i), body: src.slice(start + 1, bodyEnd - 1), flags: src.slice(bodyEnd, i) };
    } else if (isIdStart(c)) {
      while (i < n && isIdPart(src[i])) {
        i++;
      }
      tok = { t: 'id', v: src.slice(start, i) };
    } else {
      let p = PUNCT.find((x) => src.startsWith(x, i));
      if (!p) {
        p = c;
      }
      i += p.length;
      tok = { t: 'p', v: p };
    }
    tok.s = start;
    tok.e = i;
    tok.nl = nl;
    tok.sp = sp;
    if (doc !== null) {
      tok.doc = doc;
      doc = null;
    }
    nl = false;
    sp = false;
    out.push(tok);
  }
  out.push({ t: 'eof', v: '', s: n, e: n, nl: true, sp: true });
  return out;
}

const REGEX_AFTER_ID = new Set(['return', 'typeof', 'case', 'in', 'of', 'new', 'delete', 'void', 'throw', 'else', 'do']);

/** A '/' starts a regex unless it follows something that ends an expression. */
function regexAllowed(prev) {
  if (!prev) {
    return true;
  }
  if (prev.t === 'num' || prev.t === 'str' || prev.t === 'tpl' || prev.t === 'regex') {
    return false;
  }
  if (prev.t === 'id') {
    return REGEX_AFTER_ID.has(prev.v);
  }
  return !(prev.v === ')' || prev.v === ']' || prev.v === '}');
}

function skipString(src, i) {
  const q = src[i];
  i++;
  while (i < src.length && src[i] !== q) {
    if (src[i] === '\\') {
      i++;
    } else if (q === '`' && src[i] === '$' && src[i + 1] === '{') {
      let depth = 1;
      i += 2;
      while (i < src.length && depth > 0) {
        if (src[i] === '{') {
          depth++;
        } else if (src[i] === '}') {
          depth--;
        }
        i++;
      }
      continue;
    }
    i++;
  }
  return i + 1;
}

function unescape(c) {
  switch (c) {
    case 'n':
      return '\n';
    case 't':
      return '\t';
    case 'r':
      return '\r';
    case undefined:
      return '';
    default:
      return c;
  }
}

const BINARY = {
  '??': 1, '||': 2, '&&': 3, '|': 4, '^': 5, '&': 6,
  '==': 7, '!=': 7, '===': 7, '!==': 7,
  '<': 8, '>': 8, '<=': 8, '>=': 8, 'instanceof': 8, 'in': 8, 'as': 8,
  '<<': 9, '>>': 9, '>>>': 9,
  '+': 10, '-': 10, '*': 11, '/': 11, '%': 11, '**': 12
};

const ASSIGN = new Set(['=', '+=', '-=', '*=', '/=', '%=', '&&=', '||=', '??=', '**=', '&=', '|=', '^=']);

class Parser {
  constructor(src) {
    this.src = src;
    this.toks = tokenize(src);
    this.i = 0;
  }

  get tok() {
    return this.toks[this.i];
  }

  peek(k = 1) {
    return this.toks[Math.min(this.i + k, this.toks.length - 1)];
  }

  is(v, k = 0) {
    const t = this.peek(k);
    return (t.t === 'p' || t.t === 'id') && t.v === v;
  }

  next() {
    const t = this.tok;
    if (this.i < this.toks.length - 1) {
      this.i++;
    }
    return t;
  }

  eat(v) {
    if (this.is(v)) {
      return this.next();
    }
    return null;
  }

  expect(v) {
    if (!this.is(v)) {
      throw new ParseError(`Expected '${v}' but found '${this.tok.v || this.tok.t}'`, this.tok.s);
    }
    return this.next();
  }

  // ------------------------------------------------------------------------------------------ statements

  parseProgram() {
    const body = this.parseStatements('eof');
    return { type: 'program', body };
  }

  parseStatements(end) {
    const out = [];
    while (this.tok.t !== 'eof' && !(end === '}' && this.is('}'))) {
      const start = this.i;
      try {
        const st = this.parseStatement();
        if (st) {
          out.push(st);
        }
      } catch (e) {
        out.push({ type: 'error', message: e.message, pos: e.pos ?? this.tok.s });
        this.recover(start, end);
      }
      if (this.i === start) {
        this.next();
      }
    }
    return out;
  }

  /** Skip to the next token that starts a new line at the current nesting depth. */
  recover(start, end) {
    let depth = 0;
    if (this.i === start) {
      this.next();
    }
    while (this.tok.t !== 'eof') {
      const t = this.tok;
      if (depth === 0 && t.nl && this.i > start) {
        return;
      }
      if (t.t === 'p' && (t.v === '{' || t.v === '(' || t.v === '[')) {
        depth++;
      } else if (t.t === 'p' && (t.v === '}' || t.v === ')' || t.v === ']')) {
        if (depth === 0) {
          if (end === '}' && t.v === '}') {
            return;
          }
        } else {
          depth--;
        }
      }
      this.next();
    }
  }

  parseBlockOrStatement() {
    if (this.is('{')) {
      this.next();
      const body = this.parseStatements('}');
      this.expect('}');
      return body;
    }
    const st = this.parseStatement();
    return st ? [st] : [];
  }

  parseStatement() {
    const t = this.tok;
    if (t.t === 'p' && t.v === ';') {
      this.next();
      return null;
    }
    if (t.t === 'p' && t.v === '@' || t.t === 'id' && t.v.startsWith('@')) {
      return this.parseDecorated();
    }
    if (t.t === 'p' && t.v === '{') {
      return { type: 'block', body: this.parseBlockOrStatement() };
    }
    if (t.t === 'id') {
      switch (t.v) {
        case 'import':
          this.skipLine();
          return null;
        case 'export':
          this.next();
          this.lastExport = this.is('struct');
          if (this.is('default')) {
            this.next();
          }
          return this.parseStatement();
        case 'if':
          return this.parseIf();
        case 'const':
        case 'let':
        case 'var':
          return this.parseVar();
        case 'return': {
          this.next();
          const arg = this.atStatementEnd() ? null : this.parseExpression();
          this.eat(';');
          return { type: 'return', arg };
        }
        case 'struct':
          return this.parseStruct([]);
        case 'switch':
          return this.parseSwitch();
        case 'try': {
          this.next();
          const block = this.parseBlockOrStatement();
          let param = null;
          let handler = null;
          let finalizer = null;
          if (this.eat('catch')) {
            if (this.eat('(')) {
              param = this.next().v;
              if (this.eat(':')) {
                this.skipType([')']);
              }
              this.expect(')');
            }
            handler = this.parseBlockOrStatement();
          }
          if (this.eat('finally')) {
            finalizer = this.parseBlockOrStatement();
          }
          return { type: 'try', block, param, handler, finalizer };
        }
        case 'throw':
          this.next();
          this.parseExpression();
          this.eat(';');
          return { type: 'throw' };
        case 'break':
        case 'continue': {
          const kw = this.next().v;
          this.eat(';');
          return { type: kw === 'continue' ? 'continue' : 'break' };
        }
        case 'class':
        case 'interface':
        case 'enum':
          this.next();
          this.skipUntilBlock();
          return null;
        case 'type':
          if (this.peek().t === 'id' && this.is('=', 2)) {
            this.skipLine();
            return null;
          }
          break;
        case 'function':
          return this.parseFunctionDecl();
        case 'private':
        case 'public':
        case 'protected':
        case 'readonly':
        case 'static':
          this.next();
          return this.parseStatement();
        case 'for':
        case 'while':
          return this.parseLoop();
        default:
          break;
      }
      // member declarations as they appear inside a struct: `x: T = v;` / method `name(): T {`
      if (this.peek().t === 'p' && this.peek().v === ':' && this.inStruct) {
        return this.parseField([]);
      }
      if (/^[a-z_$]/.test(t.v) && this.isMethodDecl()) {
        return this.parseMethod([]);
      }
      // class getters (`get size(): number {`), parsed when class bodies are read as structs (classes.js)
      if (this.inStruct && t.v === 'get' && this.peek().t === 'id' && this.peek(2).t === 'p' && this.peek(2).v === '(') {
        this.next();
        const m = this.parseMethod([]);
        m.getter = true;
        return m;
      }
    }
    const expr = this.parseExpression(true);
    this.eat(';');
    return { type: 'expr', expr, s: t.s, e: this.toks[this.i - 1].e };
  }

  atStatementEnd() {
    const t = this.tok;
    return t.t === 'eof' || t.nl || (t.t === 'p' && (t.v === ';' || t.v === '}'));
  }

  skipLine() {
    let depth = 0;
    this.next();
    while (this.tok.t !== 'eof') {
      const t = this.tok;
      if (depth === 0 && (t.nl || (t.t === 'p' && t.v === ';'))) {
        this.eat(';');
        return;
      }
      if (t.t === 'p' && '{(['.includes(t.v)) {
        depth++;
      } else if (t.t === 'p' && '})]'.includes(t.v)) {
        depth--;
      }
      this.next();
    }
  }

  skipUntilBlock() {
    while (this.tok.t !== 'eof' && !this.is('{')) {
      this.next();
    }
    this.skipBalanced();
  }

  skipBalanced() {
    const open = this.tok.v;
    const close = open === '{' ? '}' : open === '(' ? ')' : open === '[' ? ']' : '>';
    let depth = 0;
    do {
      const t = this.next();
      if (t.t === 'p' && t.v === open) {
        depth++;
      } else if (t.t === 'p' && t.v === close) {
        depth--;
      }
    } while (depth > 0 && this.tok.t !== 'eof');
  }

  /** `name(params)(: type)? {` at statement start */
  isMethodDecl() {
    if (!(this.peek().t === 'p' && this.peek().v === '(')) {
      return false;
    }
    let k = 1;
    let depth = 0;
    for (; this.i + k < this.toks.length; k++) {
      const t = this.peek(k);
      if (t.t === 'p' && t.v === '(') {
        depth++;
      } else if (t.t === 'p' && t.v === ')') {
        depth--;
        if (depth === 0) {
          break;
        }
      } else if (t.t === 'eof') {
        return false;
      }
    }
    const after = this.peek(k + 1);
    if (after.t === 'p' && after.v === ':') {
      return true;
    }
    return after.t === 'p' && after.v === '{' && (this.tok.v === 'build' || (this.inStruct && this.tok.v === 'constructor'));
  }

  parseDecorated() {
    const doc = this.tok.doc;
    const decorators = [];
    while (this.is('@') || (this.tok.t === 'id' && this.tok.v.startsWith('@'))) {
      if (this.is('@')) {
        this.next();
      }
      const name = this.next().v.replace(/^@/, '');
      let args = [];
      if (this.is('(') && !this.tok.sp) {
        args = this.parseArgs();
      }
      decorators.push({ name, args });
    }
    while (this.tok.t === 'id' && ['export', 'private', 'public', 'protected', 'readonly', 'static', 'default'].includes(this.tok.v)) {
      if (this.tok.v === 'export') {
        this.lastExport = true;
      }
      this.next();
    }
    if (this.is('struct')) {
      return this.parseStruct(decorators, doc);
    }
    if (this.is('class')) {
      this.next();
      this.skipUntilBlock();
      return null;
    }
    if (this.is('function')) {
      // `@Builder function emptyFrame() {}`: keep the decorators so the previewer can render it as UI
      const fn = this.parseFunctionDecl();
      fn.decorators = decorators;
      return fn;
    }
    if (this.is('get') && this.peek().t === 'id') {
      this.next();
      const m = this.parseMethod(decorators);
      m.getter = true;
      return m;
    }
    if (this.tok.t === 'id' && this.peek().t === 'p' && this.peek().v === '(') {
      return this.parseMethod(decorators);
    }
    return this.parseField(decorators, doc);
  }

  parseField(decorators, doc) {
    doc = doc ?? this.tok.doc;
    const name = this.next().v;
    this.eat('?');
    this.eat('!');
    let typeSrc = '';
    if (this.eat(':')) {
      typeSrc = this.skipType(['=', ';', '}']);
    }
    let init = null;
    let initSrc = '';
    if (this.eat('=')) {
      const s0 = this.tok.s;
      init = this.parseExpression();
      initSrc = this.src.slice(s0, this.toks[this.i - 1].e);
    }
    this.eat(';');
    return { type: 'field', name, decorators, typeSrc, init, initSrc, doc };
  }

  parseMethod(decorators) {
    const name = this.next().v;
    const params = this.parseParams();
    if (this.eat(':')) {
      this.skipType(['{']);
    }
    const prev = this.inStruct;
    this.inStruct = false;
    const body = this.parseBlockOrStatement();
    this.inStruct = prev;
    return { type: 'method', name, params, body, decorators };
  }

  parseFunctionDecl() {
    this.expect('function');
    const name = this.next().v;
    if (this.is('<')) {
      this.skipBalanced();
    }
    const params = this.parseParams();
    if (this.eat(':')) {
      this.skipType(['{']);
    }
    const body = this.parseBlockOrStatement();
    return { type: 'var', kind: 'const', name, init: { type: 'arrow', params, body } };
  }

  parseStruct(decorators, doc) {
    const exportedFlag = this.lastExport === true;
    this.lastExport = false;
    this.expect('struct');
    const name = this.next().v;
    this.expect('{');
    const prev = this.inStruct;
    this.inStruct = true;
    const members = this.parseStatements('}');
    this.inStruct = prev;
    this.expect('}');
    const exported = exportedFlag;
    return { type: 'struct', name, decorators, members, doc, exported };
  }

  parseIf() {
    this.expect('if');
    this.expect('(');
    const test = this.parseExpression();
    this.expect(')');
    const then = this.parseBlockOrStatement();
    let otherwise = null;
    if (this.eat('else')) {
      otherwise = this.is('if') ? [this.parseIf()] : this.parseBlockOrStatement();
    }
    return { type: 'if', test, then, otherwise };
  }

  parseSwitch() {
    this.expect('switch');
    this.expect('(');
    const disc = this.parseExpression();
    this.expect(')');
    this.expect('{');
    const cases = [];
    while (!this.is('}') && this.tok.t !== 'eof') {
      let test = null;
      if (this.eat('default')) {
        test = null;
      } else {
        this.expect('case');
        test = this.parseExpression();
      }
      this.expect(':');
      const body = [];
      while (!this.is('case') && !this.is('default') && !this.is('}') && this.tok.t !== 'eof') {
        const st = this.parseStatement();
        if (st) {
          body.push(st);
        }
      }
      cases.push({ test, body });
    }
    this.expect('}');
    return { type: 'switch', disc, cases };
  }

  /** `while (t) …`, `for (init; test; update) …`, `for (const x of xs) …`, `for (const k in o) …` (helper code). */
  parseLoop() {
    const kw = this.next().v;
    this.expect('(');
    if (kw === 'while') {
      const test = this.parseExpression();
      this.expect(')');
      return { type: 'loop', test, body: this.parseBlockOrStatement() };
    }
    const decl = this.is('const') || this.is('let') || this.is('var');
    if (decl && this.peek().t === 'id' && (this.is('of', 2) || this.is('in', 2))) {
      this.next();
      const name = this.next().v;
      const mode = this.next().v;
      const iter = this.parseExpression();
      this.expect(')');
      return { type: 'forOf', name, mode, iter, body: this.parseBlockOrStatement() };
    }
    let init = null;
    if (decl) {
      init = this.parseVar(); // consumes the ';'
    } else {
      if (!this.is(';')) {
        init = { type: 'expr', expr: this.parseExpression() };
      }
      this.expect(';');
    }
    const test = this.is(';') ? null : this.parseExpression();
    this.expect(';');
    const update = this.is(')') ? null : this.parseExpression();
    this.expect(')');
    return { type: 'loop', init, test, update, body: this.parseBlockOrStatement() };
  }

  parseVar() {
    const kind = this.next().v;
    const decls = [];
    do {
      let name;
      if (this.is('{') || this.is('[')) {
        // destructuring is not in the subset: keep it opaque
        this.skipBalanced();
        name = null;
      } else {
        name = this.next().v;
      }
      if (this.eat(':')) {
        this.skipType(['=', ';', ',']);
      }
      let init = null;
      if (this.eat('=')) {
        init = this.parseExpression();
      }
      decls.push({ type: 'var', kind, name, init });
    } while (this.eat(','));
    this.eat(';');
    return decls.length === 1 ? decls[0] : { type: 'block', body: decls, transparent: true };
  }

  /** Skip a type annotation; stops (without consuming) at one of `stops` on depth 0. */
  skipType(stops) {
    const start = this.tok.s;
    let depth = 0;
    let end = start;
    const enders = [')', ']', '}', ',', ';', '&&', '||', '??'];
    while (this.tok.t !== 'eof') {
      const t = this.tok;
      if (depth === 0 && t.t === 'p' && (stops.includes(t.v) || enders.includes(t.v))) {
        break;
      }
      if (depth === 0 && t.nl && end !== start && !(t.t === 'p' && (t.v === '|' || t.v === '&'))) {
        const prev = this.toks[this.i - 1];
        if (!(prev.t === 'p' && (prev.v === '|' || prev.v === '&' || prev.v === '=>' || prev.v === ':'))) {
          break;
        }
      }
      if (t.t === 'p' && (t.v === '(' || t.v === '[' || t.v === '{' || t.v === '<')) {
        depth++;
      } else if (t.t === 'p' && (t.v === ')' || t.v === ']' || t.v === '}' || t.v === '>')) {
        depth--;
      } else if (t.t === 'p' && t.v === '>>') {
        depth -= 2;
      }
      end = t.e;
      this.next();
      if (depth < 0) {
        depth = 0;
      }
    }
    return this.src.slice(start, end).trim();
  }

  parseParams() {
    this.expect('(');
    const params = [];
    while (!this.is(')') && this.tok.t !== 'eof') {
      this.eat('...');
      let name;
      if (this.is('{') || this.is('[')) {
        this.skipBalanced();
        name = '_';
      } else {
        name = this.next().v;
      }
      this.eat('?');
      if (this.eat(':')) {
        this.skipType([',', ')', '=']);
      }
      let def = null;
      if (this.eat('=')) {
        def = this.parseAssign();
      }
      params.push({ name, def });
      if (!this.eat(',')) {
        break;
      }
    }
    this.expect(')');
    return params;
  }

  // ----------------------------------------------------------------------------------------- expressions

  parseExpression(statement = false) {
    let e = this.parseAssign(statement);
    if (this.is(',') && statement) {
      const list = [e];
      while (this.eat(',')) {
        list.push(this.parseAssign(statement));
      }
      e = { type: 'seq', list };
    }
    return e;
  }

  parseAssign(statement = false) {
    if (this.isArrowStart()) {
      return this.parseArrow();
    }
    const left = this.parseTernary(statement);
    if (this.tok.t === 'p' && ASSIGN.has(this.tok.v)) {
      const op = this.next().v;
      const right = this.parseAssign();
      return { type: 'assign', op, left, right };
    }
    return left;
  }

  isArrowStart() {
    const t = this.tok;
    if (t.t === 'id' && this.peek().t === 'p' && this.peek().v === '=>') {
      return true;
    }
    if (t.t === 'id' && t.v === 'async' && (this.peek().v === '(' || this.peek(2).v === '=>')) {
      return true;
    }
    if (!(t.t === 'p' && t.v === '(')) {
      return false;
    }
    let depth = 0;
    let k = 0;
    for (; this.i + k < this.toks.length; k++) {
      const x = this.peek(k);
      if (x.t === 'eof') {
        return false;
      }
      if (x.t === 'p' && (x.v === '(' || x.v === '[' || x.v === '{')) {
        depth++;
      } else if (x.t === 'p' && (x.v === ')' || x.v === ']' || x.v === '}')) {
        depth--;
        if (depth === 0) {
          break;
        }
      }
    }
    const after = this.peek(k + 1);
    if (after.t === 'p' && after.v === '=>') {
      return true;
    }
    if (!(after.t === 'p' && after.v === ':')) {
      return false;
    }
    // `(a): T => …` (return type) vs `cond ? (a) : b` — look for `=>` after the type
    let d = 0;
    for (let j = k + 2; this.i + j < this.toks.length; j++) {
      const x = this.peek(j);
      if (x.t === 'eof') {
        return false;
      }
      if (x.t === 'p') {
        if (d === 0 && x.v === '=>') {
          return true;
        }
        if ('([{<'.includes(x.v)) {
          d++;
        } else if (')]}>'.includes(x.v)) {
          if (d === 0) {
            return false;
          }
          d--;
        } else if (d === 0 && (x.v === ',' || x.v === ';' || x.v === '?' || x.v === ':' || x.v === '=')) {
          return false;
        }
      }
    }
    return false;
  }

  parseArrow() {
    this.eat('async');
    let params;
    if (this.tok.t === 'id') {
      params = [{ name: this.next().v, def: null }];
    } else {
      params = this.parseParams();
      if (this.eat(':')) {
        this.skipType(['=>']);
      }
    }
    this.expect('=>');
    let body;
    let expression = false;
    if (this.is('{')) {
      this.next();
      body = this.parseStatements('}');
      this.expect('}');
    } else {
      body = this.parseAssign();
      expression = true;
    }
    return { type: 'arrow', params, body, expression };
  }

  parseTernary(statement) {
    const test = this.parseBinary(0, statement);
    if (this.is('?')) {
      this.next();
      const cons = this.parseAssign();
      this.expect(':');
      const alt = this.parseAssign();
      return { type: 'cond', test, cons, alt };
    }
    return test;
  }

  parseBinary(minPrec, statement) {
    let left = this.parseUnary(statement);
    for (;;) {
      const t = this.tok;
      const op = t.v;
      if (!((t.t === 'p' || t.t === 'id') && Object.prototype.hasOwnProperty.call(BINARY, op))) {
        break;
      }
      // a new line that starts with `<` / `-` etc. still continues; but a UI statement starting with an id does not
      const prec = BINARY[op];
      if (prec <= minPrec) {
        break;
      }
      if (statement && t.nl && t.t === 'p' && (op === '<' || op === '-' || op === '+' || op === '*')) {
        break;
      }
      this.next();
      if (op === 'as') {
        const typeSrc = this.skipType([',', ')', ';', '}', ']', '?', ':', '=']);
        left = { type: 'as', expr: left, typeSrc };
        continue;
      }
      const right = this.parseBinary(op === '**' ? prec - 1 : prec);
      left = { type: 'bin', op, left, right };
    }
    return left;
  }

  parseUnary(statement) {
    const t = this.tok;
    if (t.t === 'p' && (t.v === '!' || t.v === '-' || t.v === '+' || t.v === '~')) {
      this.next();
      return { type: 'unary', op: t.v, arg: this.parseUnary() };
    }
    if (t.t === 'p' && (t.v === '++' || t.v === '--')) {
      this.next();
      return { type: 'update', op: t.v, prefix: true, arg: this.parseUnary() };
    }
    if (t.t === 'id' && (t.v === 'typeof' || t.v === 'void' || t.v === 'await' || t.v === 'delete')) {
      this.next();
      return { type: 'unary', op: t.v, arg: this.parseUnary() };
    }
    if (t.t === 'p' && t.v === '<' && this.peek().t === 'id' && this.peek(2).v === '>') {
      // old-style cast <T>x
      this.next();
      this.next();
      this.next();
      return this.parseUnary();
    }
    return this.parsePostfix(statement);
  }

  parsePostfix(statement) {
    let e = this.parsePrimary(statement);
    for (;;) {
      const t = this.tok;
      if (t.t === 'p' && (t.v === '.' || t.v === '?.')) {
        this.next();
        if (this.is('(')) {
          // f?.(x)
          e = { type: 'call', callee: e, args: this.parseArgs(), optional: true };
          continue;
        }
        if (this.is('[')) {
          this.next();
          const prop = this.parseExpression();
          this.expect(']');
          e = { type: 'member', object: e, prop, computed: true };
          continue;
        }
        const name = this.next();
        e = { type: 'member', object: e, prop: name.v, computed: false };
        continue;
      }
      if (t.t === 'p' && t.v === '[' && !t.nl) {
        this.next();
        const prop = this.parseExpression();
        this.expect(']');
        e = { type: 'member', object: e, prop, computed: true };
        continue;
      }
      if (t.t === 'p' && t.v === '(' && !(t.nl && statement)) {
        e = { type: 'call', callee: e, args: this.parseArgs() };
        // trailing closure: Column() { ... } (UI statements only, uppercase component names)
        if (statement && this.is('{') && isComponentCallee(e.callee)) {
          this.next();
          const prev = this.inStruct;
          this.inStruct = false;
          e.children = this.parseStatements('}');
          this.inStruct = prev;
          this.expect('}');
        }
        continue;
      }
      if (t.t === 'p' && t.v === '<' && !t.sp && e.type === 'ident') {
        // generic call f<T>(...) or new Map<K, V>()
        const save = this.i;
        try {
          this.skipBalanced();
          if (this.is('(')) {
            continue;
          }
        } catch (err) {
          // fallthrough
        }
        this.i = save;
        break;
      }
      if (t.t === 'p' && t.v === '!' && !t.sp) {
        // non-null assertion `x!` or two-way binding `x!!`
        this.next();
        if (this.is('!') && !this.tok.sp) {
          this.next();
          e = { type: 'bind', target: e };
        }
        continue;
      }
      if (t.t === 'p' && (t.v === '++' || t.v === '--') && !t.nl) {
        this.next();
        e = { type: 'update', op: t.v, prefix: false, arg: e };
        continue;
      }
      if (t.t === 'tpl' && !t.sp) {
        // tagged template: ignore the tag
        e = this.parsePrimary();
        continue;
      }
      break;
    }
    return e;
  }

  parseArgs() {
    this.expect('(');
    const args = [];
    while (!this.is(')') && this.tok.t !== 'eof') {
      if (this.is('...')) {
        this.next();
        if (this.is(')') || this.is(',')) {
          args.push({ type: 'ellipsis' });
        } else {
          args.push({ type: 'spread', arg: this.parseAssign() });
        }
      } else {
        args.push(this.parseAssign());
      }
      if (!this.eat(',')) {
        break;
      }
    }
    this.expect(')');
    return args;
  }

  parsePrimary(statement) {
    const t = this.next();
    switch (t.t) {
      case 'num':
        return { type: 'lit', value: t.v };
      case 'str':
        return { type: 'lit', value: t.v };
      case 'regex':
        try {
          return { type: 'lit', value: new RegExp(t.body, t.flags) };
        } catch (e) {
          return { type: 'lit', value: t.v };
        }
      case 'tpl':
        return {
          type: 'tpl',
          quasis: t.quasis,
          exprs: t.exprs.map((src) => {
            try {
              return parseExpression(src);
            } catch (e) {
              return { type: 'lit', value: '…' };
            }
          })
        };
      case 'id':
        switch (t.v) {
          case 'true':
            return { type: 'lit', value: true };
          case 'false':
            return { type: 'lit', value: false };
          case 'null':
            return { type: 'lit', value: null };
          case 'undefined':
            return { type: 'lit', value: undefined };
          case 'this':
            return { type: 'this' };
          case 'new': {
            let callee = { type: 'ident', name: this.next().v };
            while (this.is('.')) {
              this.next();
              callee = { type: 'member', object: callee, prop: this.next().v, computed: false };
            }
            if (this.is('<')) {
              this.skipBalanced();
            }
            const args = this.is('(') ? this.parseArgs() : [];
            return { type: 'new', callee, args };
          }
          case 'function': {
            if (this.tok.t === 'id') {
              this.next();
            }
            const params = this.parseParams();
            if (this.eat(':')) {
              this.skipType(['{']);
            }
            this.expect('{');
            const body = this.parseStatements('}');
            this.expect('}');
            return { type: 'arrow', params, body, expression: false };
          }
          default:
            return { type: 'ident', name: t.v };
        }
      case 'p':
        if (t.v === '(') {
          const e = this.parseExpression();
          this.expect(')');
          return e;
        }
        if (t.v === '[') {
          const items = [];
          while (!this.is(']') && this.tok.t !== 'eof') {
            if (this.is('...')) {
              this.next();
              if (!this.is(']') && !this.is(',')) {
                items.push({ type: 'spread', arg: this.parseAssign() });
              }
            } else if (this.is(',')) {
              items.push({ type: 'lit', value: undefined });
            } else {
              items.push(this.parseAssign());
            }
            if (!this.eat(',')) {
              break;
            }
          }
          this.expect(']');
          return { type: 'array', items };
        }
        if (t.v === '{') {
          return this.parseObjectRest();
        }
        if (t.v === '...') {
          return { type: 'ellipsis' };
        }
        if (t.v === '@') {
          // inline decorator in an odd place; ignore it
          this.next();
          return this.parsePrimary(statement);
        }
        if (t.v === '$' ) {
          return this.parsePrimary(statement);
        }
        break;
      default:
        break;
    }
    throw new ParseError(`Unexpected '${t.v || t.t}'`, t.s);
  }

  parseObjectRest() {
    const props = [];
    while (!this.is('}') && this.tok.t !== 'eof') {
      if (this.is('...')) {
        this.next();
        if (this.is('}') || this.is(',')) {
          props.push({ ellipsis: true });
        } else {
          props.push({ spread: this.parseAssign() });
        }
      } else {
        const kt = this.next();
        let key;
        let computed = null;
        if (kt.t === 'p' && kt.v === '[') {
          computed = this.parseAssign();
          this.expect(']');
        } else {
          key = kt.t === 'num' ? String(kt.v) : kt.v;
        }
        if (this.eat(':')) {
          props.push({ key, computed, value: this.parseAssign() });
        } else if (this.is('(')) {
          // method shorthand
          const params = this.parseParams();
          if (this.eat(':')) {
            this.skipType(['{']);
          }
          this.expect('{');
          const body = this.parseStatements('}');
          this.expect('}');
          props.push({ key, value: { type: 'arrow', params, body } });
        } else {
          props.push({ key, value: { type: 'ident', name: key } });
        }
      }
      if (!this.eat(',')) {
        this.eat(';');
        if (!this.is('}')) {
          if (this.tok.nl) {
            continue;
          }
          break;
        }
      }
    }
    this.expect('}');
    return { type: 'object', props };
  }
}

function isComponentCallee(callee) {
  return callee.type === 'ident' && /^[A-Z]/.test(callee.name);
}

/** Parse a whole snippet (statements, struct declarations…). Never throws. */
export function parseProgram(src) {
  const p = new Parser(src);
  try {
    return p.parseProgram();
  } catch (e) {
    return { type: 'program', body: [{ type: 'error', message: e.message, pos: e.pos ?? 0 }] };
  }
}

/** Parse a single expression (throws ParseError on failure). */
export function parseExpression(src) {
  const p = new Parser(src);
  const e = p.parseExpression();
  if (p.tok.t !== 'eof') {
    throw new ParseError(`Unexpected '${p.tok.v}' after expression`, p.tok.s);
  }
  return e;
}
