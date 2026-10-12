/**
 * Small, dependency-free, grammar-driven syntax highlighter for SCodeBlock. Pure and unit-tested.
 *
 * Built-in languages (all defined with the public SparkGrammar API in CodeGrammars.ets):
 * ts (typescript, arkts, ets, js, javascript, tsx, jsx), css (scss, less), json (json5, jsonc),
 * bash (sh, shell, zsh, console), html (xml, svg, vue), python (py), diff (patch), text (plain, txt).
 *
 * ```
 * CodeHighlighter.register({ name: 'ini', rules: [ { token: 'comment', pattern: ';[^\\n]*' }, … ] });
 * const myTs = CodeHighlighter.extend('ts', { name: 'my-ts', keywords: ['observe', 'emit'] });
 * SCodeBlock({ code, grammar: myTs })
 * ```
 */
import { SPARK_BUILTIN_GRAMMARS, TEXT_GRAMMAR } from './CodeGrammars';
import { SparkGrammar, SparkGrammarExtension, SparkGrammarRef, SparkGrammarRule } from './SparkGrammar';

/** A registered language name or alias (case-insensitive). Unknown names render as plain text. */
export type CodeLanguage = string;

/** Token type, e.g. 'keyword' or 'keyword.control' (see SparkGrammar.ets for the standard set). */
export type CodeTokenKind = string;

export class CodeToken {
  text: string;
  kind: CodeTokenKind;

  constructor(text: string, kind: CodeTokenKind) {
    this.text = text;
    this.kind = kind;
  }
}

/** Max nesting of `inside` re-tokenization and of the `push` state stack. */
const MAX_INSIDE_DEPTH = 8;
const MAX_STATE_DEPTH = 32;

class CompiledRule {
  re: RegExp | undefined = undefined;
  token: string = 'plain';
  captures: string[] | undefined = undefined;
  inside: SparkGrammarRef | undefined = undefined;
  push: SparkGrammarRef | undefined = undefined;
  pop: boolean = false;
}

class CompiledGrammar {
  grammar: SparkGrammar;
  rules: CompiledRule[] = [];

  constructor(grammar: SparkGrammar) {
    this.grammar = grammar;
  }
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\\/-]/g, '\\$&');
}

export class CodeHighlighter {
  private static grammars: Map<string, SparkGrammar> = new Map<string, SparkGrammar>();
  private static builtinsLoaded: boolean = false;
  private static compiled: WeakMap<SparkGrammar, CompiledGrammar> = new WeakMap<SparkGrammar, CompiledGrammar>();

  // ---------------------------------------------------------------------------------------------- registry

  /**
   * Register (or replace) a grammar under its name and aliases; returns it, so a module-level
   * `const G = CodeHighlighter.register({...})` can be passed to `SCodeBlock({ grammar: G })` too.
   */
  static register(grammar: SparkGrammar): SparkGrammar {
    CodeHighlighter.ensureBuiltins();
    CodeHighlighter.add(grammar);
    return grammar;
  }

  /** Make `alias` resolve to the grammar registered as `name`. Returns false when `name` is unknown. */
  static registerAlias(alias: string, name: string): boolean {
    const g = CodeHighlighter.grammar(name);
    if (g === undefined) {
      return false;
    }
    CodeHighlighter.grammars.set(alias.toLowerCase(), g);
    CodeHighlighter.invalidate();
    return true;
  }

  /** The grammar registered under a name or alias (case-insensitive). */
  static grammar(language: CodeLanguage): SparkGrammar | undefined {
    CodeHighlighter.ensureBuiltins();
    return CodeHighlighter.grammars.get(language.toLowerCase());
  }

  /** Canonical names of all registered grammars (aliases excluded). */
  static languages(): string[] {
    CodeHighlighter.ensureBuiltins();
    const names: string[] = [];
    CodeHighlighter.grammars.forEach((g: SparkGrammar, key: string) => {
      if (key === g.name.toLowerCase()) {
        names.push(g.name);
      }
    });
    return names;
  }

  /**
   * Derive a grammar from a built-in or registered one (not registered automatically):
   * rules = [keywords] + before + base rules (minus `exclude` tokens) + after.
   */
  static extend(base: SparkGrammarRef, ext: SparkGrammarExtension): SparkGrammar {
    const b = CodeHighlighter.resolve(base, TEXT_GRAMMAR) ?? TEXT_GRAMMAR;
    const rules: SparkGrammarRule[] = [];
    if (ext.keywords !== undefined && ext.keywords.length > 0) {
      const kw: SparkGrammarRule = { token: 'keyword', words: ext.keywords };
      rules.push(kw);
    }
    (ext.before ?? []).forEach((r: SparkGrammarRule) => rules.push(r));
    const exclude = ext.exclude ?? [];
    b.rules.forEach((r: SparkGrammarRule) => {
      if (r.include !== undefined || exclude.indexOf(r.token ?? 'plain') < 0) {
        rules.push(r);
      }
    });
    (ext.after ?? []).forEach((r: SparkGrammarRule) => rules.push(r));
    const g: SparkGrammar = {
      name: ext.name,
      aliases: ext.aliases ?? [],
      rules: rules,
      caseInsensitive: ext.caseInsensitive ?? b.caseInsensitive,
      defaultToken: ext.defaultToken ?? b.defaultToken,
      icon: ext.icon ?? b.icon
    };
    return g;
  }

  /** Grammar for a language name / alias or a grammar object; unknown names fall back to plain text. */
  static resolveGrammar(language: CodeLanguage | SparkGrammar): SparkGrammar {
    if (typeof language === 'string') {
      return CodeHighlighter.grammar(language as string) ?? TEXT_GRAMMAR;
    }
    return language as SparkGrammar;
  }

  // ---------------------------------------------------------------------------------------------- tokenizing

  /** Tokenise and split into lines (tokens never span lines). Tabs become two spaces. */
  static highlight(code: string, language: CodeLanguage | SparkGrammar): CodeToken[][] {
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

  /** Flat token stream; joining all token texts gives back `src` exactly. */
  static tokenize(src: string, language: CodeLanguage | SparkGrammar): CodeToken[] {
    const g = CodeHighlighter.resolveGrammar(language);
    const out: CodeToken[] = [];
    CodeHighlighter.run(src, g, 'plain', out, 0);
    return out;
  }

  private static run(src: string, root: SparkGrammar, defaultToken: string, out: CodeToken[], depth: number): void {
    const stack: CompiledGrammar[] = [CodeHighlighter.compile(root)];
    let pos = 0;
    while (pos < src.length) {
      const state = stack[stack.length - 1];
      let matched = false;
      for (const rule of state.rules) {
        const re = rule.re;
        if (re === undefined) {
          continue;
        }
        re.lastIndex = pos;
        const m = re.exec(src);
        if (m === null || m[0].length === 0) {
          continue;
        }
        CodeHighlighter.emit(m, rule, state.grammar, out, depth);
        pos += m[0].length;
        if (rule.pop) {
          if (stack.length > 1) {
            stack.pop();
          }
        } else if (rule.push !== undefined && stack.length < MAX_STATE_DEPTH) {
          const next = CodeHighlighter.resolve(rule.push, state.grammar);
          if (next !== undefined) {
            stack.push(CodeHighlighter.compile(next));
          }
        }
        matched = true;
        break;
      }
      if (!matched) {
        CodeHighlighter.push(out, src[pos], state.grammar.defaultToken ?? defaultToken, true);
        pos++;
      }
    }
  }

  private static emit(m: RegExpExecArray, rule: CompiledRule, owner: SparkGrammar, out: CodeToken[],
    depth: number): void {
    const text = m[0];
    if (rule.inside !== undefined && depth < MAX_INSIDE_DEPTH) {
      const inner = CodeHighlighter.resolve(rule.inside, owner);
      if (inner !== undefined) {
        CodeHighlighter.run(text, inner, rule.token, out, depth + 1);
        return;
      }
    }
    const caps = rule.captures;
    if (caps !== undefined && m.length > 1) {
      let joined = '';
      for (let i = 1; i < m.length; i++) {
        const part: string | undefined = m[i];
        joined += part ?? '';
      }
      if (joined === text) {
        for (let i = 1; i < m.length; i++) {
          const part: string | undefined = m[i];
          if (part !== undefined && part.length > 0) {
            CodeHighlighter.push(out, part, i - 1 < caps.length ? caps[i - 1] : rule.token, false);
          }
        }
        return;
      }
    }
    CodeHighlighter.push(out, text, rule.token, false);
  }

  private static push(out: CodeToken[], text: string, kind: string, fallback: boolean): void {
    const last = out.length > 0 ? out[out.length - 1] : undefined;
    if (last !== undefined && last.kind === kind && (fallback || kind === 'plain' || kind === 'punctuation')) {
      last.text += text;
    } else {
      out.push(new CodeToken(text, kind));
    }
  }

  // ---------------------------------------------------------------------------------------------- compiling

  private static ensureBuiltins(): void {
    if (CodeHighlighter.builtinsLoaded) {
      return;
    }
    CodeHighlighter.builtinsLoaded = true;
    SPARK_BUILTIN_GRAMMARS.forEach((g: SparkGrammar) => CodeHighlighter.add(g));
  }

  private static add(grammar: SparkGrammar): void {
    CodeHighlighter.grammars.set(grammar.name.toLowerCase(), grammar);
    (grammar.aliases ?? []).forEach((a: string) => CodeHighlighter.grammars.set(a.toLowerCase(), grammar));
    CodeHighlighter.invalidate();
  }

  /** Includes are resolved at compile time, so any registry change drops the compiled cache. */
  private static invalidate(): void {
    CodeHighlighter.compiled = new WeakMap<SparkGrammar, CompiledGrammar>();
  }

  private static resolve(ref: SparkGrammarRef, self: SparkGrammar): SparkGrammar | undefined {
    if (typeof ref === 'string') {
      const name = ref as string;
      return name === '$self' ? self : CodeHighlighter.grammar(name);
    }
    return ref as SparkGrammar;
  }

  private static compile(g: SparkGrammar): CompiledGrammar {
    CodeHighlighter.ensureBuiltins();
    const hit = CodeHighlighter.compiled.get(g);
    if (hit !== undefined) {
      return hit;
    }
    const c = new CompiledGrammar(g);
    CodeHighlighter.compiled.set(g, c);
    const seen: SparkGrammar[] = [g];
    CodeHighlighter.expand(g, c.rules, seen);
    return c;
  }

  private static expand(g: SparkGrammar, out: CompiledRule[], seen: SparkGrammar[]): void {
    const ci = g.caseInsensitive === true;
    g.rules.forEach((rule: SparkGrammarRule) => {
      if (rule.include !== undefined) {
        const inc = CodeHighlighter.resolve(rule.include, g);
        if (inc !== undefined && seen.indexOf(inc) < 0) {
          seen.push(inc);
          CodeHighlighter.expand(inc, out, seen);
          seen.pop();
        }
        return;
      }
      out.push(CodeHighlighter.compileRule(rule, ci));
    });
  }

  private static compileRule(rule: SparkGrammarRule, ci: boolean): CompiledRule {
    const c = new CompiledRule();
    c.token = rule.token ?? 'plain';
    c.captures = rule.captures;
    c.inside = rule.inside;
    c.push = rule.push;
    c.pop = rule.pop === true;
    let source: string | undefined = undefined;
    let flags = '';
    if (rule.words !== undefined && rule.words.length > 0) {
      const words = rule.words.slice().sort((a: string, b: string) => b.length - a.length);
      source = '(?:' + words.map((w: string) => escapeRegExp(w)).join('|') + ')(?![\\w$])';
    } else if (typeof rule.pattern === 'string') {
      source = rule.pattern as string;
    } else if (rule.pattern !== undefined) {
      const re = rule.pattern as RegExp;
      source = re.source;
      flags = re.flags.replace(/[gy]/g, '');
    }
    if (source === undefined) {
      return c;
    }
    if (ci && flags.indexOf('i') < 0) {
      flags += 'i';
    }
    try {
      c.re = new RegExp(source, flags + 'y');
    } catch (e) {
      c.re = undefined; // invalid user pattern: the rule never matches
    }
    return c;
  }
}
