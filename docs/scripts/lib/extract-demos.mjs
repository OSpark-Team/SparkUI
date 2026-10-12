// Extract the gallery documentation structure (headers, sections, DemoBlock code strings, demo state)
// from gallery/src/main/ets/docs/*.ets. Read-only use of the gallery sources.
import fs from 'node:fs';
import path from 'node:path';
import { parseProgram } from '../../.vitepress/theme/previewer/parser.js';
import { Interpreter, Scope } from '../../.vitepress/theme/previewer/interp.js';

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
    return; // the live demo inside is the gallery's own rendering
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

export function extractDemos(galleryDocsDir) {
  const result = {};
  const errors = [];
  for (const file of fs.readdirSync(galleryDocsDir).filter((f) => f.endsWith('.ets')).sort()) {
    const src = fs.readFileSync(path.join(galleryDocsDir, file), 'utf8');
    const program = parseProgram(src);
    const interp = new Interpreter({}, {});
    const top = new Scope();
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
      let build = null;
      for (const m of st.members) {
        if (m.type === 'field' && m.init && !m.decorators.some((d) => d.name === 'Consumer')) {
          const v = literal(interp, m.init, top);
          if (v !== undefined) {
            state[m.name] = v;
          }
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
            centered: props.centered !== false
          });
        }
      }
      if (blocks.length > 0) {
        result[st.name] = { file, state, consts: fileConsts(top), blocks };
      }
    }
  }
  return { docs: result, errors };
}
