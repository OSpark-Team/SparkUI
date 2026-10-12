/**
 * Public grammar API for SCodeBlock / CodeHighlighter (a tiny Prism / Shiki-lite).
 *
 * A grammar is an ordered list of rules. At every position the tokenizer tries the rules of the current
 * state in order (sticky regex, anchored at the position) and the first non-empty match wins. Text that no
 * rule matches is emitted one character at a time with the grammar's `defaultToken` (default 'plain').
 *
 * ```
 * CodeHighlighter.register({
 *   name: 'sql', aliases: ['psql'], caseInsensitive: true,
 *   rules: [
 *     { token: 'comment', pattern: '--[^\\n]*' }, // string patterns are RegExp sources
 *     { token: 'string', pattern: /'(?:''|[^'])*'?/ },
 *     { token: 'keyword', words: ['select', 'from', 'where', 'and', 'or'] },
 *     { token: 'number', pattern: /\d+(?:\.\d+)?/ }
 *   ]
 * });
 * ```
 *
 * Token types are free-form strings. The standard set coloured by `SparkCodeTheme.github()` is:
 * plain, keyword, string, comment, number, decorator, type, function, property, punctuation, operator,
 * variable, tag, attribute, regex, inserted, deleted, meta. Dotted names fall back to their prefix when the
 * theme has no exact entry ('keyword.control' → 'keyword').
 *
 * Writing fast rules: patterns run anchored at the current position, so never start them with `.*`; avoid
 * nested quantifiers over overlapping alternatives (`(a|a)*`, `(\w+)*`); prefer an optional closing
 * delimiter (`"(?:\\.|[^\\"\n])*"?`) over a pattern that can fail after scanning far.
 */

/** A grammar reference: a grammar object, a registered name / alias, or '$self' (the current state's grammar; for an
 * `include`, the including grammar). Named references resolve through the CodeHighlighter registry. */
export type SparkGrammarRef = SparkGrammar | string;

export interface SparkGrammarRule {
  /** Token type of the match (default 'plain'). */
  token?: string;
  /** Regular expression; its 'g' / 'y' flags are ignored (matching is always sticky at the scan position). */
  pattern?: RegExp | string;
  /** Shortcut for a keyword list: compiled to `(?:w1|w2|…)(?![\w$])`, longest words first. */
  words?: string[];
  /**
   * Token type per top-level capture group. Applied only when the groups tile the whole match in order
   * (e.g. `/(fn)(\s+)(\w+)/` with ['keyword', 'plain', 'function']); otherwise the match gets `token`.
   */
  captures?: string[];
  /** Tokenize the matched text again with this grammar; text it does not match keeps `token`. */
  inside?: SparkGrammarRef;
  /** After the match, enter this grammar as a new state (until a rule with `pop` matches). */
  push?: SparkGrammarRef;
  /** After the match, leave the current state (ignored in the root state). */
  pop?: boolean;
  /** Splice all rules of another grammar here (resolved when the grammar is first used). */
  include?: SparkGrammarRef;
}

export interface SparkGrammar {
  /** Language name used by `SCodeBlock({ language })` and as the default header caption. */
  name: string;
  aliases?: string[];
  rules: SparkGrammarRule[];
  /** Adds the 'i' flag to every pattern and `words` list. */
  caseInsensitive?: boolean;
  /** Token type for unmatched characters (default 'plain'). */
  defaultToken?: string;
  /** SIcon name for the SCodeBlock header (default 'code'). */
  icon?: string;
}

/** Overrides for `CodeHighlighter.extend(base, …)`. */
export interface SparkGrammarExtension {
  name: string;
  aliases?: string[];
  /** Extra keywords, matched before every base rule. */
  keywords?: string[];
  /** Rules tried before the base rules (after `keywords`). */
  before?: SparkGrammarRule[];
  /** Rules tried after the base rules (only reached where no base rule matches). */
  after?: SparkGrammarRule[];
  /** Drop base rules whose token is in this list (e.g. ['type'] to disable the PascalCase heuristic). */
  exclude?: string[];
  caseInsensitive?: boolean;
  defaultToken?: string;
  icon?: string;
}
