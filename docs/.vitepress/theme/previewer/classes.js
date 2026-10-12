/**
 * Plain-object stand-ins for ArkTS classes (`new SparkChartSeries('desktop', 'Desktop')`,
 * `new SparkShellNavItem(...)`, a gallery `new Mail(...)`): the class body is parsed with the previewer's own
 * parser (as a struct) and run by the interpreter, so field initialisers, the constructor body, methods and
 * getters behave like the source. Methods / getters are non-enumerable, so the objects stay JSON-friendly.
 */
import { parseProgram } from './parser.js';
import { Interpreter, Scope } from './interp.js';

/** `class Name … { body }` → { Name: 'body' } (strings, templates and comments are skipped while matching braces). */
export function classSources(src) {
  const out = {};
  const re = /(?:^|\n)[ \t]*(?:@\w+(?:\([^)]*\))?\s*)*(?:export\s+)?(?:default\s+)?class\s+(\w+)[^{]*\{/g;
  let m;
  while ((m = re.exec(src))) {
    const start = re.lastIndex;
    const end = matchBrace(src, start);
    if (end < 0) {
      break;
    }
    out[m[1]] = src.slice(start, end);
    re.lastIndex = end + 1;
  }
  return out;
}

function matchBrace(src, i) {
  let depth = 1;
  while (i < src.length) {
    const c = src[i];
    if (c === '/' && src[i + 1] === '/') {
      i = src.indexOf('\n', i);
      if (i < 0) {
        return -1;
      }
      continue;
    }
    if (c === '/' && src[i + 1] === '*') {
      i = src.indexOf('*/', i + 2);
      if (i < 0) {
        return -1;
      }
      i += 2;
      continue;
    }
    if (c === '\'' || c === '"' || c === '`') {
      i++;
      while (i < src.length && src[i] !== c) {
        i += src[i] === '\\' ? 2 : 1;
      }
      i++;
      continue;
    }
    if (c === '{') {
      depth++;
    } else if (c === '}') {
      depth--;
      if (depth === 0) {
        return i;
      }
    }
    i++;
  }
  return -1;
}

/**
 * Turn class sources into constructor functions and add them to `globals` (so classes can construct each
 * other). Returns the same `globals` object.
 * @param {Record<string, string>} sources name → class body source (from classSources)
 * @param {object} globals interpreter globals the class code runs with
 */
export function defineClasses(sources, globals) {
  for (const [name, body] of Object.entries(sources || {})) {
    let members = null;
    const lazy = () => {
      if (members === null) {
        try {
          const program = parseProgram(`struct ${name} {\n${body}\n}`);
          members = program.body.find((s) => s.type === 'struct')?.members || [];
        } catch (e) {
          members = [];
        }
      }
      return members;
    };
    globals[name] = (...args) => construct(name, lazy(), args, globals);
  }
  return globals;
}

function construct(name, members, args, globals) {
  const obj = {};
  Object.defineProperty(obj, '__class', { value: name, enumerable: false });
  const interp = new Interpreter(obj, globals);
  const root = new Scope();
  for (const m of members) {
    if (m.type === 'method' && m.name !== 'constructor') {
      const fn = function method(...a) {
        const self = this && typeof this === 'object' ? this : obj;
        const it = new Interpreter(self, globals);
        const s = root.child();
        m.params.forEach((p, k) => s.vars.set(p.name, a[k] === undefined && p.def ? it.evaluate(p.def, s) : a[k]));
        return it.runBlock(m.body, s);
      };
      if (m.getter) {
        Object.defineProperty(obj, m.name, { get: fn, enumerable: false, configurable: true });
      } else {
        Object.defineProperty(obj, m.name, { value: fn, enumerable: false, writable: true, configurable: true });
      }
    }
  }
  for (const m of members) {
    if (m.type === 'field') {
      try {
        obj[m.name] = m.init ? interp.evaluate(m.init, root) : undefined;
      } catch (e) {
        obj[m.name] = undefined;
      }
    }
  }
  const ctor = members.find((m) => m.type === 'method' && m.name === 'constructor');
  if (ctor) {
    const s = root.child();
    ctor.params.forEach((p, k) => s.vars.set(p.name, args[k] === undefined && p.def ? interp.evaluate(p.def, s) : args[k]));
    interp.runBlock(ctor.body, s);
  }
  for (const k of Object.keys(obj)) {
    if (obj[k] === undefined) {
      delete obj[k];
    }
  }
  return obj;
}
