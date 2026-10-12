import { ThemeDiagnostic, ThemeSource, ThemeVar, ThemeJsonDoc } from './ThemeSource';

const SIZE_CLASSES: string[] = ['compact', 'medium', 'expanded', 'large'];

enum BlockTarget {
  ROOT,
  DARK,
  SIZE,
  SKIP
}

/**
 * Parser for the SparkUI theme CSS subset.
 *
 * Grammar: `:root {}`, `.dark {}`, `@size(compact|medium|expanded|large) {}`, `--var: value;`, comments.
 * To accept shadcn / tweakcn exports verbatim, `@theme`, `@layer`, `@import`, `@custom-variant`,
 * rules for other selectors and non-custom properties are recognised and skipped with an `info`
 * diagnostic. `@layer` / `@media (prefers-color-scheme: dark)` bodies are descended into.
 * The parser never throws; structural problems become `error` diagnostics.
 */
export class ThemeCssParser {
  private src: string = '';
  private lineStarts: number[] = [];
  private out: ThemeSource = new ThemeSource();

  static parse(css: string): ThemeSource {
    const p = new ThemeCssParser();
    return p.run(css);
  }

  /** Parse the JSON form: `{ "root": {...}, "dark": {...}, "sizes": { "compact": {...} } }`. */
  static parseJson(json: string): ThemeSource {
    const out = new ThemeSource();
    let doc: ThemeJsonDoc;
    try {
      doc = JSON.parse(json) as ThemeJsonDoc;
    } catch (e) {
      out.diagnostics.push(new ThemeDiagnostic('error', 0, '', `invalid JSON: ${(e as Error).message}`));
      return out;
    }
    if (doc === null || typeof doc !== 'object') {
      out.diagnostics.push(new ThemeDiagnostic('error', 0, '', 'theme JSON must be an object'));
      return out;
    }
    const fill = (rec: Record<string, string> | undefined, to: Map<string, ThemeVar>, block: string): void => {
      if (rec === undefined || rec === null) {
        return;
      }
      if (typeof rec !== 'object') {
        out.diagnostics.push(new ThemeDiagnostic('error', 0, '', `"${block}" must be an object`));
        return;
      }
      Object.keys(rec).forEach((k: string) => {
        const v: Object = rec[k];
        const name = k.startsWith('--') ? k : '--' + k;
        if (typeof v !== 'string' && typeof v !== 'number') {
          out.diagnostics.push(new ThemeDiagnostic('error', 0, name, `value must be a string`));
          return;
        }
        to.set(name, new ThemeVar(String(v), 0));
      });
    };
    fill(doc.root, out.root, 'root');
    fill(doc.dark, out.dark, 'dark');
    if (doc.sizes !== undefined && doc.sizes !== null) {
      Object.keys(doc.sizes).forEach((size: string) => {
        if (!SIZE_CLASSES.includes(size)) {
          out.diagnostics.push(new ThemeDiagnostic('error', 0, '', `unknown size class "${size}"`));
          return;
        }
        fill(doc.sizes[size], out.sizeBlock(size), `sizes.${size}`);
      });
    }
    return out;
  }

  private run(css: string): ThemeSource {
    this.src = ThemeCssParser.stripComments(css);
    this.lineStarts = [0];
    for (let i = 0; i < this.src.length; i++) {
      if (this.src.charCodeAt(i) === 10) {
        this.lineStarts.push(i + 1);
      }
    }
    try {
      this.parseRules(0, this.src.length, false);
    } catch (e) {
      this.out.diagnostics.push(new ThemeDiagnostic('error', 0, '', `parser failure: ${(e as Error).message}`));
    }
    return this.out;
  }

  /** Replace comment characters with spaces, keeping newlines so line numbers stay correct. */
  private static stripComments(css: string): string {
    let out = '';
    let i = 0;
    let quote = '';
    while (i < css.length) {
      const ch = css[i];
      if (quote.length > 0) {
        out += ch;
        if (ch === quote && css[i - 1] !== '\\') {
          quote = '';
        }
        i++;
        continue;
      }
      if (ch === '"' || ch === '\'') {
        quote = ch;
        out += ch;
        i++;
        continue;
      }
      if (ch === '/' && css[i + 1] === '*') {
        let end = css.indexOf('*/', i + 2);
        end = end < 0 ? css.length : end + 2;
        for (let j = i; j < end; j++) {
          out += css[j] === '\n' ? '\n' : ' ';
        }
        i = end;
        continue;
      }
      out += ch;
      i++;
    }
    return out;
  }

  private lineAt(pos: number): number {
    let lo = 0;
    let hi = this.lineStarts.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (this.lineStarts[mid] <= pos) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  private info(pos: number, message: string): void {
    this.out.diagnostics.push(new ThemeDiagnostic('info', this.lineAt(pos), '', message));
  }

  private error(pos: number, variable: string, message: string): void {
    this.out.diagnostics.push(new ThemeDiagnostic('error', this.lineAt(pos), variable, message));
  }

  /** Find the next top-level `{` or `;` (outside parentheses / quotes) in [from, end). */
  private scanPrelude(from: number, end: number): number {
    let depth = 0;
    let quote = '';
    for (let i = from; i < end; i++) {
      const ch = this.src[i];
      if (quote.length > 0) {
        if (ch === quote) {
          quote = '';
        }
        continue;
      }
      if (ch === '"' || ch === '\'') {
        quote = ch;
      } else if (ch === '(') {
        depth++;
      } else if (ch === ')') {
        depth = Math.max(0, depth - 1);
      } else if (depth === 0 && (ch === '{' || ch === ';' || ch === '}')) {
        return i;
      }
    }
    return end;
  }

  /** Index of the `}` matching the `{` at `open`, or -1. */
  private matchBrace(open: number, end: number): number {
    let depth = 0;
    let quote = '';
    for (let i = open; i < end; i++) {
      const ch = this.src[i];
      if (quote.length > 0) {
        if (ch === quote) {
          quote = '';
        }
        continue;
      }
      if (ch === '"' || ch === '\'') {
        quote = ch;
      } else if (ch === '{') {
        depth++;
      } else if (ch === '}') {
        depth--;
        if (depth === 0) {
          return i;
        }
      }
    }
    return -1;
  }

  private parseRules(from: number, end: number, darkContext: boolean): void {
    let i = from;
    while (i < end) {
      while (i < end && /\s/.test(this.src[i])) {
        i++;
      }
      if (i >= end) {
        return;
      }
      const stop = this.scanPrelude(i, end);
      const prelude = this.src.substring(i, stop).trim();
      if (stop >= end) {
        if (prelude.length > 0) {
          this.error(i, '', `unexpected end of input after "${ThemeCssParser.clip(prelude)}"`);
        }
        return;
      }
      const ch = this.src[stop];
      if (ch === ';') {
        if (prelude.startsWith('--')) {
          this.error(i, prelude.split(':')[0].trim(), 'declaration outside of a rule block');
        } else if (prelude.length > 0) {
          this.info(i, `skipped statement "${ThemeCssParser.clip(prelude)}"`);
        }
        i = stop + 1;
        continue;
      }
      if (ch === '}') {
        this.error(stop, '', 'unexpected "}"');
        i = stop + 1;
        continue;
      }
      // ch === '{'
      let close = this.matchBrace(stop, end);
      if (close < 0) {
        this.error(stop, '', `missing "}" for "${ThemeCssParser.clip(prelude)}"`);
        close = end;
      }
      this.handleBlock(prelude, i, stop + 1, close, darkContext);
      i = close + 1;
    }
  }

  private handleBlock(prelude: string, preludePos: number, bodyStart: number, bodyEnd: number,
    darkContext: boolean): void {
    const lower = prelude.toLowerCase();
    if (lower.startsWith('@size')) {
      const m = /^@size\s*\(\s*([a-z-]+)\s*\)$/.exec(lower);
      if (m === null || !SIZE_CLASSES.includes(m[1])) {
        this.error(preludePos, '', `invalid @size rule "${prelude}"; expected compact|medium|expanded|large`);
        return;
      }
      this.parseDeclarations(bodyStart, bodyEnd, BlockTarget.SIZE, m[1]);
      return;
    }
    if (lower.startsWith('@layer') || lower.startsWith('@media')) {
      const dark = darkContext || /prefers-color-scheme\s*:\s*dark/.test(lower);
      if (lower.startsWith('@media') && !dark) {
        this.info(preludePos, `skipped "${ThemeCssParser.clip(prelude)}"`);
        return;
      }
      this.parseRules(bodyStart, bodyEnd, dark);
      return;
    }
    if (lower.startsWith('@')) {
      this.info(preludePos, `skipped "${ThemeCssParser.clip(prelude)}" block`);
      return;
    }
    const target = ThemeCssParser.classifySelector(lower, darkContext);
    if (target === BlockTarget.SKIP) {
      this.info(preludePos, `skipped rule "${ThemeCssParser.clip(prelude)}"`);
      return;
    }
    this.parseDeclarations(bodyStart, bodyEnd, target, '');
  }

  private static classifySelector(selectorList: string, darkContext: boolean): BlockTarget {
    const selectors = selectorList.split(',').map((s: string) => s.trim().replace(/\s+/g, ' '));
    let root = false;
    for (const s of selectors) {
      if (s === '.dark' || s === ':root.dark' || s === 'html.dark' || s === ':root .dark' ||
        s === '[data-theme="dark"]' || s === '[data-theme=dark]' || s === ':root[data-theme="dark"]' ||
        s === '.dark:root') {
        return BlockTarget.DARK;
      }
      if (s === ':root' || s === 'html' || s === ':host' || s === '.light' || s === ':root.light') {
        root = true;
      }
    }
    if (root) {
      return darkContext ? BlockTarget.DARK : BlockTarget.ROOT;
    }
    return BlockTarget.SKIP;
  }

  private parseDeclarations(from: number, end: number, target: BlockTarget, size: string): void {
    let i = from;
    while (i < end) {
      while (i < end && /[\s;]/.test(this.src[i])) {
        i++;
      }
      if (i >= end) {
        return;
      }
      const stop = this.scanPrelude(i, end);
      const decl = this.src.substring(i, stop).trim();
      if (stop < end && this.src[stop] === '{') {
        // nested rule — not part of the subset
        const close = this.matchBrace(stop, end);
        this.info(i, `skipped nested rule "${ThemeCssParser.clip(decl)}"`);
        i = close < 0 ? end : close + 1;
        continue;
      }
      i = stop + 1;
      if (decl.length === 0) {
        continue;
      }
      const colon = decl.indexOf(':');
      if (colon <= 0) {
        this.error(i - decl.length - 1, '', `invalid declaration "${ThemeCssParser.clip(decl)}"`);
        continue;
      }
      const name = decl.substring(0, colon).trim();
      let value = decl.substring(colon + 1).trim();
      if (!name.startsWith('--')) {
        continue; // ordinary CSS property (e.g. in a copied `body {}`), silently ignored
      }
      if (!/^--[a-zA-Z0-9_-]+$/.test(name)) {
        this.error(this.src.indexOf(name, i - decl.length - 1), name, 'invalid variable name');
        continue;
      }
      value = value.replace(/\s*!important\s*$/i, '').trim();
      const pos = this.src.lastIndexOf(name, stop);
      const line = this.lineAt(pos < 0 ? i : pos);
      if (value.length === 0) {
        this.out.diagnostics.push(new ThemeDiagnostic('error', line, name, 'empty value'));
        continue;
      }
      const v = new ThemeVar(value, line);
      if (target === BlockTarget.ROOT) {
        this.out.root.set(name, v);
      } else if (target === BlockTarget.DARK) {
        this.out.dark.set(name, v);
      } else if (target === BlockTarget.SIZE) {
        this.out.sizeBlock(size).set(name, v);
      }
    }
  }

  private static clip(s: string): string {
    const one = s.replace(/\s+/g, ' ');
    return one.length > 40 ? one.substring(0, 40) + '…' : one;
  }
}
