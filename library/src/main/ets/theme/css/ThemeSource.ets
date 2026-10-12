export type ThemeDiagnosticSeverity = 'error' | 'warning' | 'info';

/** A typed, non-fatal problem found while parsing or applying a theme. */
export class ThemeDiagnostic {
  severity: ThemeDiagnosticSeverity;
  /** 1-based line in the source, 0 when unknown (e.g. JSON) */
  line: number;
  /** CSS variable name including "--", or '' for structural problems */
  variable: string;
  message: string;

  constructor(severity: ThemeDiagnosticSeverity, line: number, variable: string, message: string) {
    this.severity = severity;
    this.line = line;
    this.variable = variable;
    this.message = message;
  }

  toString(): string {
    const where = this.line > 0 ? `line ${this.line}` : 'json';
    const v = this.variable.length > 0 ? ` ${this.variable}` : '';
    return `[${this.severity}] ${where}${v}: ${this.message}`;
  }
}

export class ThemeVar {
  value: string;
  line: number;

  constructor(value: string, line: number) {
    this.value = value;
    this.line = line;
  }
}

export type SparkSizeClass = 'compact' | 'medium' | 'expanded' | 'large';

/**
 * Raw (unresolved) theme variables, as written in a CSS / JSON theme file.
 * Keys are variable names including the leading "--".
 */
export class ThemeSource {
  root: Map<string, ThemeVar> = new Map<string, ThemeVar>();
  dark: Map<string, ThemeVar> = new Map<string, ThemeVar>();
  sizes: Map<string, Map<string, ThemeVar>> = new Map<string, Map<string, ThemeVar>>();
  diagnostics: ThemeDiagnostic[] = [];

  sizeBlock(size: string): Map<string, ThemeVar> {
    let m = this.sizes.get(size);
    if (m === undefined) {
      m = new Map<string, ThemeVar>();
      this.sizes.set(size, m);
    }
    return m;
  }

  get hasErrors(): boolean {
    return this.diagnostics.some((d: ThemeDiagnostic) => d.severity === 'error');
  }

  /** Overlay `other` on top of this source (used to apply a user theme over a preset). */
  merge(other: ThemeSource): ThemeSource {
    const out = new ThemeSource();
    const copy = (from: Map<string, ThemeVar>, to: Map<string, ThemeVar>): void => {
      from.forEach((v: ThemeVar, k: string) => {
        to.set(k, v);
      });
    };
    copy(this.root, out.root);
    copy(other.root, out.root);
    copy(this.dark, out.dark);
    copy(other.dark, out.dark);
    this.sizes.forEach((m: Map<string, ThemeVar>, k: string) => copy(m, out.sizeBlock(k)));
    other.sizes.forEach((m: Map<string, ThemeVar>, k: string) => copy(m, out.sizeBlock(k)));
    out.diagnostics = this.diagnostics.concat(other.diagnostics);
    return out;
  }

  /** Serialise back to the CSS subset (used by the theme editor export). */
  toCss(): string {
    const block = (head: string, m: Map<string, ThemeVar>): string => {
      if (m.size === 0) {
        return '';
      }
      let s = `${head} {\n`;
      m.forEach((v: ThemeVar, k: string) => {
        s += `  ${k}: ${v.value};\n`;
      });
      return s + '}\n';
    };
    let css = block(':root', this.root);
    const dark = block('.dark', this.dark);
    if (dark.length > 0) {
      css += '\n' + dark;
    }
    this.sizes.forEach((m: Map<string, ThemeVar>, k: string) => {
      css += '\n' + block(`@size(${k})`, m);
    });
    return css;
  }

  /** Serialise to the equivalent JSON format. */
  toJson(): string {
    const obj = (m: Map<string, ThemeVar>): Record<string, string> => {
      const r: Record<string, string> = {};
      m.forEach((v: ThemeVar, k: string) => {
        r[k] = v.value;
      });
      return r;
    };
    const sizes: Record<string, Record<string, string>> = {};
    this.sizes.forEach((m: Map<string, ThemeVar>, k: string) => {
      sizes[k] = obj(m);
    });
    const doc: ThemeJsonDoc = { root: obj(this.root), dark: obj(this.dark), sizes: sizes };
    return JSON.stringify(doc, null, 2);
  }
}

export interface ThemeJsonDoc {
  root: Record<string, string>;
  dark: Record<string, string>;
  sizes: Record<string, Record<string, string>>;
}
