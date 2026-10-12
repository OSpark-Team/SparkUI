// Extract the gallery documentation structure (headers, sections, DemoBlock code strings, demo state)
// from gallery/src/main/ets/docs/*.ets. Read-only use of the gallery sources.
import fs from 'node:fs';
import path from 'node:path';
import { parseProgram } from '../../.vitepress/theme/previewer/parser.js';
import { Interpreter, Scope } from '../../.vitepress/theme/previewer/interp.js';
import { classSources, defineClasses } from '../../.vitepress/theme/previewer/classes.js';

/** Stand-in for `this` in doc texts: any member chain stringifies to '…' (e.g. `${this.all.length} icons`). */
const HOLE = new Proxy(function hole() {}, {
  get(_, p) {
    return p === Symbol.toPrimitive || p === 'toString' ? () => '…' : HOLE;
  },
  apply() {
    return HOLE;
  }
});

const DOC_PARTS = new Set(['DocHeader', 'DocSection', 'DemoBlock', 'SCodeBlock', 'DemoCaption']);

/** Evaluate an expression to a plain JSON value, or undefined if it is not a literal-ish value. */
function literal(interp, expr, scope) {
  try {
    const v = interp.evaluate(expr, scope);
    return isPlain(v) ? v : undefined;
  } catch (e) {
    return undefined;
  }
}

function isPlain(v, depth = 0) {
  if (depth > 6) {
    return false;
  }
  if (v === null || ['string', 'number', 'boolean'].includes(typeof v)) {
    return true;
  }
  if (Array.isArray(v)) {
    return v.every((x) => isPlain(x, depth + 1));
  }
  if (typeof v === 'object' && (Object.getPrototypeOf(v) === Object.prototype || Object.getPrototypeOf(v) === null)) {
    return Object.values(v).every((x) => x === undefined || isPlain(x, depth + 1));
  }
  return false;
}

/** Depth-first walk over UI statements, yielding doc-kit calls in source order. */
function* walk(stmts) {
  for (const st of stmts || []) {
    if (st.type === 'expr') {
      yield* walkExpr(st.expr);
    } else if (st.type === 'if') {
      yield* walk(st.then);
      yield* walk(st.otherwise);
    } else if (st.type === 'block') {
      yield* walk(st.body);
    }
  }
}

function* walkExpr(e) {
  // unwind the attribute chain to the root call
  let root = e;
  while (root && (root.type === 'call' || root.type === 'member')) {
    if (root.type === 'call' && root.callee.type === 'ident') {
      break;
    }
    root = root.type === 'call' ? root.callee : root.object;
  }
  if (!root || root.type !== 'call' || root.callee.type !== 'ident') {
    return;
  }
  if (DOC_PARTS.has(root.callee.name)) {
    yield root;
  }
  if (root.callee.name === 'DemoBlock') {
    return; // the live demo inside (root.children) is collected as the demo's real body
  }
  for (const a of root.args) {
    if (a.type === 'arrow' && !a.expression) {
      yield* walk(a.body);
    }
  }
  yield* walk(root.children);
}

/** File-level constants a demo may reference (arrays / objects / numbers; code strings are skipped). */
function fileConsts(scope) {
  const out = {};
  for (const [k, v] of scope.vars) {
    if (typeof v !== 'string') {
      out[k] = v;
    }
  }
  return out;
}

/**
 * @param galleryDocsDir gallery/src/main/ets/docs
 * @param options.classes library class sources (scripts/lib/class-sources.mjs) so constants like
 *   `new SparkChartRow(...)` / a file's own `new Mail(...)` become plain data objects
 */
export function extractDemos(galleryDocsDir, { classes = {} } = {}) {
  const result = {};
  const errors = [];
  const modules = {};
  const sources = {};
  // gallery doc-kit helpers a demo may use (DemoCaption, DemoPropRow …)
  const extraSources = {};
  const kit = path.resolve(galleryDocsDir, '../shell/DocKit.ets');
  if (fs.existsSync(kit)) {
    extraSources['../shell/DocKit.ets'] = fs.readFileSync(kit, 'utf8');
  }
  const files = fs.readdirSync(galleryDocsDir).filter((f) => f.endsWith('.ets')).sort();
  const programs = {};
  // string constants of every gallery file, so a doc can use an imported code string
  // (`import { SIDEBAR_TOKENS_CODE } from './SidebarTokensDemo'`)
  const shared = new Scope();
  for (const file of files) {
    sources[file] = fs.readFileSync(path.join(galleryDocsDir, file), 'utf8');
    programs[file] = parseProgram(sources[file]);
    for (const d of programs[file].body) {
      if (d.type === 'var' && d.name && d.init && (d.init.type === 'tpl' || d.init.type === 'lit') && !shared.vars.has(d.name)) {
        const v = literal(new Interpreter({}, {}), d.init, shared);
        if (typeof v === 'string') {
          shared.vars.set(d.name, v);
        }
      }
    }
  }
  for (const file of files) {
    const src = sources[file];
    const program = programs[file];
    const classGlobals = defineClasses({ ...classes, ...classSources(src) }, {});
    const interp = new Interpreter({}, classGlobals);
    const top = new Scope(shared);
    for (const st of program.body) {
      const decls = st.type === 'var' ? [st] : st.type === 'block' && st.transparent ? st.body : [];
      for (const d of decls) {
        if (d.name && d.init) {
          const v = literal(interp, d.init, top);
          if (v !== undefined) {
            top.vars.set(d.name, v);
          }
        }
      }
      if (st.type === 'error') {
        errors.push(`${file}: ${st.message} @${st.pos}`);
      }
    }
    for (const st of program.body) {
      if (st.type !== 'struct') {
        continue;
      }
      const state = {};
      const getters = {};
      let build = null;
      for (const m of st.members) {
        if (m.type === 'field' && m.init && !m.decorators.some((d) => d.name === 'Consumer')) {
          const v = literal(interp, m.init, top);
          if (v !== undefined) {
            state[m.name] = v;
          }
        } else if (m.type === 'method' && m.getter && m.params.length === 0) {
          // `get mail(): Mail { return MAILS.find(…) }` — evaluated live by the previewer (runtime.js)
          getters[m.name] = m.body;
        } else if (m.type === 'method' && m.name === 'build') {
          build = m.body;
        } else if (m.type === 'error') {
          errors.push(`${file}/${st.name}: ${m.message} @${m.pos}`);
        }
      }
      if (!build) {
        continue;
      }
      const blocks = [];
      for (const call of walk(build)) {
        const arg = call.args[0];
        const props = {};
        if (arg && arg.type === 'object') {
          for (const p of arg.props) {
            if (p.key && p.value) {
              const v = literal(new Interpreter(HOLE, {}), p.value, top);
              props[p.key] = v;
            }
          }
        }
        const name = call.callee.name;
        if (name === 'DocHeader') {
          blocks.push({ kind: 'header', title: props.title ?? '', lead: props.lead ?? '' });
        } else if (name === 'DocSection') {
          blocks.push({ kind: 'section', title: props.title ?? '', description: props.description ?? '' });
        } else if (name === 'DemoCaption') {
          blocks.push({ kind: 'caption', text: props.text ?? '' });
        } else if (typeof props.code === 'string') {
          blocks.push({
            kind: name === 'DemoBlock' ? 'demo' : 'code',
            code: props.code,
            language: props.language ?? 'arkts',
            title: props.title,
            centered: props.centered !== false,
            // the gallery's live demo: DemoBlock's trailing closure (rendered by the previewer instead of `code`)
            body: name === 'DemoBlock' ? realBody(call.children) : undefined
          });
        }
      }
      if (blocks.length > 0) {
        result[st.name] = { file, state, consts: fileConsts(top), getters, blocks, struct: st };
      }
    }
    modules[file] = moduleOf(program, src);
  }
  for (const [file, src] of Object.entries(extraSources)) {
    if (!modules[file]) {
      modules[file] = moduleOf(parseProgram(src), src);
    }
  }
  return { docs: result, errors, modules, sources: Object.values(sources) };
}

/** The DemoBlock children, or null when they are missing or contain statements the parser could not read. */
function realBody(children) {
  if (!children || children.length === 0) {
    return null;
  }
  const errs = [];
  collectErrorNodes(children, errs);
  return errs.length ? null : children;
}

function collectErrorNodes(node, out) {
  if (Array.isArray(node)) {
    node.forEach((x) => collectErrorNodes(x, out));
  } else if (node && typeof node === 'object') {
    if (node.type === 'error') {
      out.push(node);
      return;
    }
    for (const v of Object.values(node)) {
      if (v && typeof v === 'object') {
        collectErrorNodes(v, out);
      }
    }
  }
}

/** File-level declarations (consts, functions), structs and class sources of one gallery file. */
function moduleOf(program, src) {
  const decls = [];
  const structs = {};
  for (const st of program.body) {
    if (st.type === 'var' && st.name) {
      decls.push(st);
    } else if (st.type === 'block' && st.transparent) {
      decls.push(...st.body.filter((d) => d.type === 'var' && d.name));
    } else if (st.type === 'struct') {
      structs[st.name] = st;
    }
  }
  return { decls, structs, classes: classSources(src) };
}

/** Every identifier / called name used inside an AST subtree (for dependency collection). */
function namesIn(node, out = new Set()) {
  if (Array.isArray(node)) {
    node.forEach((x) => namesIn(x, out));
  } else if (node && typeof node === 'object') {
    if (node.type === 'ident' && node.name) {
      out.add(node.name);
    }
    for (const [k, v] of Object.entries(node)) {
      if (k !== 'doc' && v && typeof v === 'object') {
        namesIn(v, out);
      }
    }
  }
  return out;
}

const DOC_KIT = new Set(['DocHeader', 'DocSection', 'DemoBlock']);

/**
 * Everything the real demo bodies of one doc struct need, as JSON-ready AST: the struct's own fields and
 * methods (state, getters, @Computed, @Builder / @LocalBuilder), the helper structs the bodies instantiate
 * (same file first, then any other gallery file — `import { X } from './X'`), the file-level constants and
 * functions they reference (transitively), and the class sources of the files involved.
 * Returns null when no demo of the doc has a usable body.
 */
export function demoBundle(doc, modules) {
  const bodies = doc.blocks.filter((b) => b.kind === 'demo').map((b) => b.body || null);
  if (!bodies.some(Boolean)) {
    return null;
  }
  const own = modules[doc.file];
  const findStruct = (name) => {
    if (own.structs[name]) {
      return { file: doc.file, st: own.structs[name] };
    }
    for (const [file, m] of Object.entries(modules)) {
      if (m.structs[name]) {
        return { file, st: m.structs[name] };
      }
    }
    return null;
  };
  const findDecl = (name, files) => {
    for (const f of files) {
      const d = modules[f]?.decls.find((x) => x.name === name);
      if (d) {
        return d;
      }
    }
    return null;
  };
  const members = doc.struct.members.filter((m) => !(m.type === 'method' && m.name === 'build') && m.type !== 'error');
  const structs = {};
  const files = [doc.file];
  const declNames = new Set();
  const decls = [];
  const queue = [...namesIn(bodies), ...namesIn(members)];
  const seen = new Set();
  while (queue.length) {
    const name = queue.shift();
    if (seen.has(name)) {
      continue;
    }
    seen.add(name);
    if (/^[A-Z]/.test(name) && !DOC_KIT.has(name) && name !== doc.struct.name) {
      const hit = findStruct(name);
      if (hit && hit.st.members.some((m) => m.type === 'method' && m.name === 'build')) {
        structs[name] = hit.st;
        if (!files.includes(hit.file)) {
          files.push(hit.file);
        }
        queue.push(...namesIn(hit.st.members));
        continue;
      }
    }
    const d = findDecl(name, files);
    if (d && !declNames.has(name)) {
      declNames.add(name);
      decls.push(d);
      queue.push(...namesIn(d.init));
    }
  }
  // keep source order of declarations (later constants may build on earlier ones)
  const order = (d) => {
    for (let k = 0; k < files.length; k++) {
      const i = modules[files[k]].decls.indexOf(d);
      if (i >= 0) {
        return (files.length - k) * 1e5 + i; // foreign files first, the doc's own file last
      }
    }
    return 0;
  };
  decls.sort((a, b) => order(a) - order(b));
  const classes = {};
  for (const f of [...files].reverse()) {
    Object.assign(classes, modules[f].classes);
  }
  return { members, structs, decls, classes, bodies };
}

/** JSON for a demo bundle: drops doc comments / source text, keeps regex literals as { __re: [body, flags] }. */
export function bundleJson(bundle) {
  return JSON.stringify(bundle, (k, v) => {
    if (k === 'doc' || k === 'initSrc' || k === 'typeSrc' || k === 'pos') {
      return undefined;
    }
    if (v instanceof RegExp) {
      return { __re: [v.source, v.flags] };
    }
    return v;
  });
}

/** Initial previewer state of a doc: its @Local values, plus `__consts` (file constants) and `__getters` (struct getters). */
export function demoState(doc) {
  const out = { ...doc.state };
  if (Object.keys(doc.consts || {}).length) {
    out.__consts = doc.consts;
  }
  if (Object.keys(doc.getters || {}).length) {
    out.__getters = doc.getters;
  }
  return out;
}
