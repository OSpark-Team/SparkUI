/**
 * Turns a parsed ArkTS snippet into Vue VNodes.
 *
 * Every UI call (`Name(args) { children }.attr(...)...`) becomes a descriptor `n`:
 *   n.name, n.props (evaluated first object-literal arg), n.args (all evaluated args), n.binds (setters for
 *   `x!!` two-way bindings), n.attrs (chained attributes), n.style (CSS from common attributes),
 *   n.onClick, n.children() → VNode[]
 * and is rendered by the component registry (components.js) or as a labelled placeholder.
 */
import { h, reactive, markRaw } from 'vue';
import { parseProgram } from './parser.js';
import { Interpreter, Scope, analyzeProgram, isEnumProxy } from './interp.js';
import { createTheme, createGlobals } from './globals.js';

/** Parse + analyse once per code string. */
export function compile(code) {
  const program = parseProgram(code);
  return analyzeProgram(program);
}

/**
 * Create the runtime for one preview instance.
 * @param analysis result of compile()
 * @param initialState demo state (e.g. gallery @Local values)
 * @param services { toast(msg, opts) }
 */
export function createRuntime(analysis, initialState, services) {
  const theme = markRaw(createTheme());
  const { __consts: consts, ...initial } = clone(initialState || {});
  const state = reactive({ theme, ...initial });
  const globals = createGlobals(theme, services);
  const interp = new Interpreter(state, globals);
  // file-level constants of the gallery page (e.g. a FRUITS array the snippet passes to ForEach)
  const root = new Scope(null, consts || {});
  // top-level declarations (const arrays used by ForEach etc.)
  try {
    interp.exec(analysis.decls, root);
  } catch (e) {
    // ignore
  }
  // struct fields → state (unless the gallery demo already provided a value)
  for (const f of analysis.fields) {
    if (f.decorators.some((d) => d.name === 'Consumer') && f.name === 'theme') {
      continue;
    }
    if (!(f.name in state) || state[f.name] === undefined) {
      try {
        state[f.name] = f.init ? interp.evaluate(f.init, root) : undefined;
      } catch (e) {
        state[f.name] = undefined;
      }
    }
  }
  const builders = {};
  for (const m of analysis.methods) {
    const isBuilder = m.decorators?.some((d) => d.name === 'Builder' || d.name === 'LocalBuilder');
    if (isBuilder) {
      builders[m.name] = m;
    }
    interp.methods[m.name] = (...args) => {
      const s = root.child();
      m.params.forEach((p, k) => s.vars.set(p.name, args[k]));
      return interp.runBlock(m.body, s);
    };
  }
  return { state, interp, root, builders, analysis };
}

function clone(v) {
  try {
    return JSON.parse(JSON.stringify(v));
  } catch (e) {
    return {};
  }
}

// --------------------------------------------------------------------------------------------- rendering

/**
 * @param rt runtime from createRuntime
 * @param registry name → (n, ctx) => VNode | VNode[]
 */
export function renderStatements(stmts, scope, rt, registry) {
  const out = [];
  for (const st of stmts || []) {
    try {
      renderStatement(st, scope, rt, registry, out);
    } catch (e) {
      out.push(errorBox(String(e && e.message || e)));
    }
  }
  return out;
}

function renderStatement(st, scope, rt, registry, out) {
  switch (st.type) {
    case 'expr':
      renderExpr(st.expr, scope, rt, registry, out);
      break;
    case 'if':
      if (rt.interp.evaluate(st.test, scope)) {
        out.push(...renderStatements(st.then, scope.child(), rt, registry));
      } else if (st.otherwise) {
        out.push(...renderStatements(st.otherwise, scope.child(), rt, registry));
      }
      break;
    case 'block':
      out.push(...renderStatements(st.body, st.transparent ? scope : scope.child(), rt, registry));
      break;
    case 'var':
      if (st.name) {
        scope.vars.set(st.name, rt.interp.evaluate(st.init, scope));
      }
      break;
    case 'error':
      out.push(errorBox(st.message));
      break;
    default:
      break;
  }
}

/** Unwind `Root(args){children}.a(..).b(..)` into { root call, attrs[] } */
export function decompose(expr) {
  const attrs = [];
  let e = expr;
  while (e && e.type === 'call' && e.callee.type === 'member') {
    attrs.unshift({ name: e.callee.prop, args: e.args, node: e });
    e = e.callee.object;
  }
  return { root: e, attrs };
}

function renderExpr(expr, scope, rt, registry, out) {
  const { root, attrs } = decompose(expr);
  if (!root) {
    return;
  }
  // this.builder(...)  — @Builder method of the snippet's struct
  if (root.type === 'this' && attrs.length > 0) {
    const first = attrs[0];
    const b = rt.builders[first.name];
    if (b) {
      const s = rt.root.child();
      const args = first.args.map((a) => rt.interp.evaluate(a, scope));
      b.params.forEach((p, k) => s.vars.set(p.name, args[k]));
      out.push(...renderStatements(b.body, s, rt, registry));
    } else if (first.name === 'content' || first.name.endsWith('Builder')) {
      out.push(placeholder(`this.${first.name}()`, () => []));
    }
    return;
  }
  if (root.type !== 'call' || root.callee.type !== 'ident') {
    // plain expression statements (assignments, SparkToast.show at top level, …) render nothing
    return;
  }
  const name = root.callee.name;
  if (name === 'ForEach' || name === 'LazyForEach') {
    const list = toArray(rt.interp.evaluate(root.args[0], scope));
    const fn = root.args[1];
    if (!fn || fn.type !== 'arrow') {
      return;
    }
    list.forEach((item, idx) => {
      const s = scope.child();
      if (fn.params[0]) {
        s.vars.set(fn.params[0].name, item);
      }
      if (fn.params[1]) {
        s.vars.set(fn.params[1].name, idx);
      }
      if (fn.expression) {
        renderExpr(fn.body, s, rt, registry, out);
      } else {
        out.push(...renderStatements(fn.body, s, rt, registry));
      }
    });
    return;
  }
  if (!/^[A-Z]/.test(name)) {
    return;
  }
  const n = describe(root, attrs, scope, rt, registry);
  const r = registry[name];
  let vnode;
  if (r) {
    vnode = r(n);
  } else {
    vnode = placeholder(name, n.children, n);
  }
  if (Array.isArray(vnode)) {
    out.push(...vnode);
  } else if (vnode) {
    out.push(vnode);
  }
}

function toArray(v) {
  if (Array.isArray(v)) {
    return v;
  }
  if (v && typeof v[Symbol.iterator] === 'function' && typeof v !== 'string') {
    return [...v];
  }
  if (typeof v === 'number' && v > 0 && v < 500) {
    return Array.from({ length: v }, (_, i) => i);
  }
  return [];
}

function describe(call, attrs, scope, rt, registry) {
  const interp = rt.interp;
  const args = call.args.map((a) => (a.type === 'ellipsis' ? undefined : interp.evaluate(a, scope)));
  const binds = {};
  /** identifier names used as prop values (lets imitations guess sample data for unresolved `config` / `rows`) */
  const refs = {};
  const first = call.args[0];
  if (first && first.type === 'object') {
    for (const p of first.props) {
      if (p.key && p.value && p.value.type === 'ident') {
        refs[p.key] = p.value.name;
      }
      if (p.key && p.value && p.value.type === 'bind') {
        const target = p.value.target;
        binds[p.key] = (v) => interp.store(target, v, scope);
      }
    }
  }
  const props = args[0] !== null && typeof args[0] === 'object' && !Array.isArray(args[0]) && !isEnumProxy(args[0]) ?
    args[0] : {};
  const evAttrs = attrs.map((a) => ({ name: a.name, args: a.args.map((x) => interp.evaluate(x, scope)) }));
  const n = {
    name: call.callee.name,
    props,
    args,
    binds,
    refs,
    attrs: evAttrs,
    attr(name) {
      const a = evAttrs.filter((x) => x.name === name).pop();
      return a ? a.args : undefined;
    },
    children: () => (call.children ? renderStatements(call.children, scope.child(), rt, registry) : []),
    hasChildren: !!(call.children && call.children.length),
    rt
  };
  const { style, events } = attrStyle(evAttrs);
  n.style = style;
  n.events = events;
  return n;
}

// --------------------------------------------------------------------------------------------- attributes

export function len(v) {
  if (v === undefined || v === null) {
    return undefined;
  }
  if (typeof v === 'number') {
    return `${v}px`;
  }
  if (typeof v === 'string') {
    if (/^-?[\d.]+(vp|fp|px|lpx)?$/.test(v)) {
      return `${parseFloat(v)}px`;
    }
    if (v === 'LayoutPolicy.matchParent') {
      return '100%';
    }
    if (v.startsWith('LayoutPolicy.')) {
      return 'fit-content';
    }
    return v;
  }
  if (typeof v === 'object' && v.value !== undefined) {
    return len(v.value);
  }
  return undefined;
}

/** ArkUI '#AARRGGBB' → css; enums → named colours; css strings pass through. */
export function color(v) {
  if (v === undefined || v === null) {
    return undefined;
  }
  if (typeof v === 'number') {
    const hex = (v >>> 0).toString(16).padStart(8, '0');
    return argb(hex);
  }
  if (isEnumProxy(v)) {
    v = String(v);
  }
  if (typeof v !== 'string') {
    return undefined;
  }
  if (v.startsWith('Color.')) {
    const c = v.slice(6).toLowerCase();
    return c === 'transparent' ? 'transparent' : c;
  }
  if (/^#[0-9a-fA-F]{8}$/.test(v)) {
    return argb(v.slice(1));
  }
  return v;
}

function argb(hex) {
  const a = parseInt(hex.slice(0, 2), 16) / 255;
  const r = parseInt(hex.slice(2, 4), 16);
  const g = parseInt(hex.slice(4, 6), 16);
  const b = parseInt(hex.slice(6, 8), 16);
  return `rgba(${r}, ${g}, ${b}, ${Math.round(a * 1000) / 1000})`;
}

function sides(v, prop, style) {
  if (v === undefined || v === null) {
    return;
  }
  if (typeof v === 'object' && !isEnumProxy(v)) {
    const map = { top: 'Top', bottom: 'Bottom', left: 'Left', right: 'Right', start: 'Left', end: 'Right' };
    for (const [k, s] of Object.entries(map)) {
      if (v[k] !== undefined) {
        style[`${prop}${s}`] = len(v[k]);
      }
    }
    return;
  }
  style[prop] = len(v);
}

const FLEX_ALIGN = {
  Start: 'flex-start', Center: 'center', End: 'flex-end', SpaceBetween: 'space-between',
  SpaceAround: 'space-around', SpaceEvenly: 'space-evenly', Top: 'flex-start', Bottom: 'flex-end',
  Stretch: 'stretch', Baseline: 'baseline', Auto: 'stretch'
};

export function flexAlign(v) {
  if (v === undefined) {
    return undefined;
  }
  const k = String(v).split('.').pop();
  return FLEX_ALIGN[k];
}

const FONT_WEIGHT = { Lighter: 300, Normal: 400, Regular: 400, Medium: 500, Bold: 700, Bolder: 800 };

function weight(v) {
  if (typeof v === 'number') {
    return v;
  }
  if (typeof v === 'string') {
    const k = v.split('.').pop();
    return FONT_WEIGHT[k] ?? (Number(k) || undefined);
  }
  if (isEnumProxy(v)) {
    return weight(String(v));
  }
  return undefined;
}

function shadow(v) {
  if (!v) {
    return undefined;
  }
  if (typeof v === 'object' && v.__shadow) {
    return `var(--ark-shadow-${v.__shadow})`;
  }
  if (typeof v === 'object' && v.radius !== undefined) {
    if (!v.radius) {
      return 'none';
    }
    return `${v.offsetX || 0}px ${v.offsetY || 0}px ${v.radius}px ${color(v.color) || 'rgba(0,0,0,.15)'}`;
  }
  if (typeof v === 'string' && v.startsWith('ShadowStyle.')) {
    return 'var(--ark-shadow-md)';
  }
  return undefined;
}

/** Common attributes → inline style + events. */
export function attrStyle(attrs) {
  const style = {};
  const events = {};
  for (const { name, args } of attrs) {
    const a = args[0];
    switch (name) {
      case 'width':
        style.width = len(a);
        break;
      case 'height':
        style.height = len(a);
        break;
      case 'size':
        if (a) {
          style.width = len(a.width);
          style.height = len(a.height);
        }
        break;
      case 'constraintSize':
        if (a) {
          style.minWidth = len(a.minWidth);
          style.maxWidth = len(a.maxWidth);
          style.minHeight = len(a.minHeight);
          style.maxHeight = len(a.maxHeight);
        }
        break;
      case 'padding':
        sides(a, 'padding', style);
        break;
      case 'margin':
        sides(a, 'margin', style);
        break;
      case 'backgroundColor':
        style.background = color(a);
        break;
      case 'linearGradient':
        if (a && Array.isArray(a.colors)) {
          const stops = a.colors.map((c) => (Array.isArray(c) ? `${color(c[0])} ${c[1] * 100}%` : color(c)));
          style.background = `linear-gradient(${a.angle ?? 180}deg, ${stops.join(', ')})`;
        }
        break;
      case 'borderRadius':
        style.borderRadius = typeof a === 'object' && a ? undefined : len(a);
        break;
      case 'border':
        if (a) {
          if (a.width !== undefined) {
            style.borderWidth = len(typeof a.width === 'object' ? (a.width.bottom ?? a.width.top ?? 1) : a.width);
            style.borderStyle = a.style && String(a.style).includes('Dashed') ? 'dashed' : 'solid';
          }
          if (a.color !== undefined) {
            style.borderColor = color(typeof a.color === 'object' && !isEnumProxy(a.color) ? (a.color.bottom ?? a.color.top) : a.color);
          }
          if (a.radius !== undefined) {
            style.borderRadius = len(typeof a.radius === 'object' ? a.radius.topLeft : a.radius);
          }
        }
        break;
      case 'borderWidth':
        style.borderWidth = len(a);
        style.borderStyle = 'solid';
        break;
      case 'borderColor':
        style.borderColor = color(a);
        break;
      case 'opacity':
        style.opacity = a;
        break;
      case 'layoutWeight':
        style.flex = `${a} 1 0`;
        style.minWidth = style.minWidth ?? '0';
        break;
      case 'flexGrow':
        style.flexGrow = a;
        break;
      case 'flexShrink':
        style.flexShrink = a;
        break;
      case 'flexBasis':
        style.flexBasis = len(a);
        break;
      case 'alignSelf':
        style.alignSelf = flexAlign(a);
        break;
      case 'aspectRatio':
        style.aspectRatio = a;
        break;
      case 'fontSize':
        style.fontSize = len(a);
        break;
      case 'fontColor':
        style.color = color(a);
        break;
      case 'fontWeight':
        style.fontWeight = weight(a);
        break;
      case 'fontStyle':
        style.fontStyle = String(a).includes('Italic') ? 'italic' : undefined;
        break;
      case 'fontFamily':
        style.fontFamily = /mono/i.test(String(a)) ? 'var(--vp-font-family-mono)' : String(a);
        break;
      case 'lineHeight':
        style.lineHeight = len(a);
        break;
      case 'letterSpacing':
        style.letterSpacing = len(a);
        break;
      case 'textAlign': {
        const k = String(a).split('.').pop();
        style.textAlign = { Start: 'left', Center: 'center', End: 'right', JUSTIFY: 'justify' }[k] ?? 'left';
        break;
      }
      case 'maxLines':
        style.display = '-webkit-box';
        style.WebkitLineClamp = String(a);
        style.WebkitBoxOrient = 'vertical';
        style.overflow = 'hidden';
        break;
      case 'decoration':
        if (a && String(a.type).includes('Underline')) {
          style.textDecoration = 'underline';
        } else if (a && String(a.type).includes('LineThrough')) {
          style.textDecoration = 'line-through';
        }
        break;
      case 'shadow':
        style.boxShadow = shadow(a);
        break;
      case 'visibility': {
        const k = String(a).split('.').pop();
        if (k === 'None') {
          style.display = 'none';
        } else if (k === 'Hidden') {
          style.visibility = 'hidden';
        }
        break;
      }
      case 'clip':
        if (a) {
          style.overflow = 'hidden';
        }
        break;
      case 'zIndex':
        style.zIndex = a;
        break;
      case 'offset':
      case 'translate':
        if (a) {
          style.transform = `${style.transform || ''} translate(${len(a.x ?? 0)}, ${len(a.y ?? 0)})`;
        }
        break;
      case 'rotate':
        if (a && a.angle !== undefined) {
          style.transform = `${style.transform || ''} rotate(${a.angle}deg)`;
        }
        break;
      case 'scale':
        if (a) {
          style.transform = `${style.transform || ''} scale(${a.x ?? 1}, ${a.y ?? 1})`;
        }
        break;
      case 'position':
        if (a) {
          style.position = 'absolute';
          style.left = len(a.x ?? a.left);
          style.top = len(a.y ?? a.top);
        }
        break;
      case 'enabled':
        if (a === false) {
          style.opacity = 0.5;
          style.pointerEvents = 'none';
        }
        break;
      case 'onClick':
        if (typeof a === 'function') {
          events.onClick = (ev) => {
            ev.stopPropagation();
            a({});
          };
        }
        break;
      default:
        break;
    }
  }
  for (const k of Object.keys(style)) {
    if (style[k] === undefined) {
      delete style[k];
    }
  }
  return { style, events };
}

// --------------------------------------------------------------------------------------------- fallbacks

export function placeholder(name, children, n) {
  const kids = children ? children() : [];
  return h('div', { class: 'ark-unknown', style: n?.style, title: `${name}: no web imitation yet` }, [
    h('span', { class: 'ark-unknown-label' }, name),
    kids.length ? h('div', { class: 'ark-unknown-body' }, kids) : null
  ]);
}

function errorBox(msg) {
  return h('div', { class: 'ark-error', title: msg }, `⚠ ${msg}`);
}
