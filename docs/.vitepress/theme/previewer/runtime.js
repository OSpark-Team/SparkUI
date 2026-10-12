/**
 * Turns a parsed ArkTS snippet into Vue VNodes.
 *
 * Every UI call (`Name(args) { children }.attr(...)...`) becomes a descriptor `n`:
 *   n.name, n.props (evaluated first object-literal arg), n.args (all evaluated args), n.binds (setters for
 *   `x!!` two-way bindings), n.attrs (chained attributes), n.style (CSS from common attributes),
 *   n.onClick, n.children() → VNode[]
 * and is rendered by the component registry (components.js) or as a labelled placeholder.
 */
import { h, reactive, markRaw, defineComponent, cloneVNode } from 'vue';
import { parseProgram } from './parser.js';
import { Interpreter, Scope, analyzeProgram, isEnumProxy } from './interp.js';
import { createTheme, createGlobals } from './globals.js';
import { defineClasses } from './classes.js';

/** Parse + analyse once per code string. */
export function compile(code) {
  const program = parseProgram(code);
  return analyzeProgram(program);
}

/**
 * Analysis for the gallery's real demo body `index` of a demo bundle (generated/demo-bodies/<Doc>.json, built by
 * scripts/lib/extract-demos.mjs): the doc struct's fields / methods, the file-level declarations, helper structs
 * and class sources the body uses. Returns null when that demo has no usable body.
 */
export function bundleAnalysis(bundle, index) {
  const ui = bundle && bundle.bodies ? bundle.bodies[index] : null;
  if (!ui) {
    return null;
  }
  const members = bundle.members || [];
  return {
    fields: members.filter((m) => m.type === 'field'),
    methods: members.filter((m) => m.type === 'method'),
    decls: bundle.decls || [],
    ui,
    errors: [],
    structs: bundle.structs || {},
    classes: bundle.classes || {},
    real: true
  };
}

/**
 * Create the runtime for one preview instance.
 * @param analysis result of compile()
 * @param initialState demo state (e.g. gallery @Local values)
 * @param services { toast(msg, opts) }
 */
export function createRuntime(analysis, initialState, services) {
  const theme = markRaw(createTheme());
  const { __consts: consts, __getters: getters, ...initial } = clone(initialState || {});
  const raw = { theme, ...initial };
  // struct getters (`get mail(): Mail { … }` of the gallery page or the snippet) are evaluated live on `this`
  const getterBodies = { ...(getters || {}) };
  for (const m of analysis.methods) {
    if (m.getter && m.params.length === 0) {
      getterBodies[m.name] = m.body;
    }
  }
  let interpRef = null;
  let rootRef = null;
  for (const [name, body] of Object.entries(getterBodies)) {
    if (!(name in raw)) {
      Object.defineProperty(raw, name, {
        get: () => (interpRef ? interpRef.runBlock(body, rootRef.child()) : undefined),
        enumerable: false,
        configurable: true
      });
    }
  }
  const state = reactive(raw);
  // theme variables set by the snippet (SparkUI.themes.setVariable / loadString / toggleDark): ArkPreview applies them
  const themeVars = reactive({ root: {}, dark: {}, mode: null, flip: false });
  const globals = createGlobals(theme, { ...services, themeVars });
  if (analysis.classes) {
    // the gallery file's own classes (`new DemoNav(…)`, `new Mail(…)`)
    defineClasses(analysis.classes, globals);
  }
  const interp = new Interpreter(state, globals);
  // file-level constants of the gallery page (e.g. a FRUITS array the snippet passes to ForEach)
  const root = new Scope(null, consts || {});
  interpRef = interp;
  rootRef = root;
  // top-level declarations (const arrays used by ForEach etc.); `@Builder function x()` become UI builders
  const builderFns = {};
  if (analysis.real) {
    for (const d of analysis.decls) {
      if (d.decorators?.some((x) => x.name === 'Builder') && d.init?.type === 'arrow') {
        builderFns[d.name] = d.init;
      }
      try {
        interp.exec([d], root);
      } catch (e) {
        // keep the constant extracted at build time (__consts), if any
      }
    }
  } else {
    try {
      interp.exec(analysis.decls, root);
    } catch (e) {
      // ignore
    }
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
  // top-level theme calls of the snippet (`SparkUI.themes.setVariable('--card-radius', '24px')`) run once, so the
  // preview shows their effect; other top-level expression statements stay inert (no toasts on page load)
  for (const st of analysis.ui || []) {
    if (st.type === 'expr' && isThemeCall(st.expr)) {
      try {
        interp.evaluate(st.expr, root.child());
      } catch (e) {
        // ignore
      }
    }
  }
  const rt = { state, interp, root, builders, analysis, themeVars, structs: analysis.structs || {}, builderFns, slots: {} };
  if (analysis.real) {
    lifecycle(analysis.methods, interp, root);
  }
  return rt;
}

/** Run a struct's `aboutToAppear()` once (state set-up such as `this.pct = this.initialPct`). */
function lifecycle(methods, interp, root) {
  const m = methods.find((x) => x.name === 'aboutToAppear' && x.params.length === 0);
  if (m) {
    try {
      interp.runBlock(m.body, root.child());
    } catch (e) {
      // ignore
    }
  }
}

// --------------------------------------------------------------------------------------------- helper structs

const PARAM_DECORATORS = new Set(['Param', 'Prop', 'Link', 'ObjectLink', 'Event', 'Once', 'Require', 'State', 'Trace']);
const structComponents = new WeakMap();

/**
 * A gallery helper struct (`ResizableFrame({ frameHeight: 520 }) { … }`, `MailRow({ mail })`) rendered from its own
 * source: one Vue component per struct, so its @Local state survives re-renders. @Param / @Event fields read the
 * caller's current props, the trailing closure (or a builder prop) fills its @BuilderParam, @Consumer theme is the
 * preview theme, and attributes chained on the call (`.layoutWeight(1)`) style its root.
 */
function structComponent(def) {
  let comp = structComponents.get(def);
  if (comp) {
    return comp;
  }
  comp = defineComponent({
    name: `Ark${def.name}`,
    props: { n: { type: Object, required: true }, rt: { type: Object, required: true }, registry: { type: Object, required: true } },
    setup(props) {
      const parent = props.rt;
      const fields = def.members.filter((m) => m.type === 'field');
      const methods = def.members.filter((m) => m.type === 'method');
      const raw = { theme: parent.state.theme };
      const local = {};
      const interp = new Interpreter(null, parent.interp.globals);
      const root = parent.root;
      const slots = {};
      let childRt = null;
      let contentTaken = false;
      const builderFields = fields.filter((f) => f.decorators.some((d) => d.name === 'BuilderParam'));
      for (const f of fields) {
        const decs = f.decorators.map((d) => d.name);
        if ((decs.includes('Consumer') || decs.includes('Consume')) && f.name === 'theme') {
          continue;
        }
        if (decs.includes('BuilderParam')) {
          const single = builderFields.length === 1 || f.name === 'content';
          const trailing = !contentTaken && single && props.n.hasChildren;
          if (trailing) {
            contentTaken = true;
          }
          const fallback = f.init && f.init.type === 'ident' ? f.init.name : null;
          slots[f.name] = (...args) => {
            const given = props.n.slots && props.n.slots[f.name];
            if (given) {
              return given(...args);
            }
            if (trailing) {
              return props.n.children();
            }
            const fn = fallback && parent.builderFns && parent.builderFns[fallback];
            return fn ? renderBuilderFn(fn, args, childRt, props.registry) : [];
          };
          continue;
        }
        let init;
        try {
          init = f.init ? interp.evaluate(f.init, root.child()) : undefined;
        } catch (e) {
          init = undefined;
        }
        if (decs.some((d) => PARAM_DECORATORS.has(d))) {
          local[f.name] = init;
          Object.defineProperty(raw, f.name, {
            get: () => (props.n.props && props.n.props[f.name] !== undefined ? props.n.props[f.name] : local[f.name]),
            set: (v) => {
              local[f.name] = v;
            },
            enumerable: true,
            configurable: true
          });
        } else {
          raw[f.name] = init;
        }
      }
      for (const m of methods) {
        if (m.getter && m.params.length === 0) {
          Object.defineProperty(raw, m.name, {
            get: () => interp.runBlock(m.body, root.child()),
            enumerable: false,
            configurable: true
          });
        }
      }
      const state = reactive(raw);
      interp.self = state;
      const builders = {};
      for (const m of methods) {
        if (m.getter) {
          continue;
        }
        if (m.decorators?.some((d) => d.name === 'Builder' || d.name === 'LocalBuilder')) {
          builders[m.name] = m;
        }
        interp.methods[m.name] = (...args) => {
          const sc = root.child();
          m.params.forEach((p, k) => sc.vars.set(p.name, args[k]));
          return interp.runBlock(m.body, sc);
        };
      }
      const build = methods.find((m) => m.name === 'build');
      childRt = {
        ...parent, state, interp, builders, slots,
        analysis: { ...parent.analysis, ui: build ? build.body : [], fields, methods }
      };
      lifecycle(methods, interp, root);
      return () => {
        let nodes;
        try {
          nodes = renderStatements(childRt.analysis.ui, root.child(), childRt, props.registry);
        } catch (e) {
          return errorBox(String(e && e.message || e));
        }
        const n = props.n;
        const hasStyle = n.style && Object.keys(n.style).length > 0;
        const hasEvents = n.events && Object.keys(n.events).length > 0;
        if (nodes.length === 1 && nodes[0] && typeof nodes[0] === 'object' && (hasStyle || hasEvents)) {
          return cloneVNode(nodes[0], { style: n.style, ...n.events });
        }
        return nodes;
      };
    }
  });
  structComponents.set(def, comp);
  return comp;
}

/** Render a top-level `@Builder function name(params) { … }`. */
function renderBuilderFn(fn, args, rt, registry) {
  const s = rt.root.child();
  fn.params.forEach((p, k) => s.vars.set(p.name, args[k]));
  if (fn.expression) {
    const out = [];
    renderExpr(fn.body, s, rt, registry, out);
    return out;
  }
  return renderStatements(fn.body, s, rt, registry);
}

/** `SparkUI.themes.<fn>(…)` */
function isThemeCall(e) {
  if (!e || e.type !== 'call' || e.callee.type !== 'member') {
    return false;
  }
  const o = e.callee.object;
  return o.type === 'member' && o.prop === 'themes' && o.object.type === 'ident' && o.object.name === 'SparkUI';
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
    const slot = rt.slots && rt.slots[first.name];
    if (slot) {
      out.push(...slot(...first.args.map((a) => rt.interp.evaluate(a, scope))));
    } else if (b) {
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
  // `myBuilder(x)` — a top-level @Builder function of the gallery file
  if (rt.builderFns && rt.builderFns[name]) {
    out.push(...renderBuilderFn(rt.builderFns[name], root.args.map((a) => rt.interp.evaluate(a, scope)), rt, registry));
    return;
  }
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
  const def = rt.structs && rt.structs[name];
  const r = registry[name];
  let vnode;
  if (def) {
    vnode = h(structComponent(def), { n, rt, registry });
  } else if (r) {
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
  /** @BuilderParam props given as `this.someBuilder` (a @Builder / @LocalBuilder of the snippet) */
  const slots = {};
  const first = call.args[0];
  if (first && first.type === 'object') {
    for (const p of first.props) {
      if (p.key && p.value && p.value.type === 'ident') {
        refs[p.key] = p.value.name;
      }
      // `config: this.series === 'desktop' ? desktopConfig : mobileConfig` → the identifier of the taken branch
      if (p.key && p.value && p.value.type === 'cond') {
        let branch;
        try {
          branch = interp.evaluate(p.value.test, scope) ? p.value.cons : p.value.alt;
        } catch (e) {
          branch = undefined;
        }
        if (branch && branch.type === 'ident') {
          refs[p.key] = branch.name;
        }
      }
      // `content: this.content` — pass a @BuilderParam of the enclosing helper struct further down
      if (p.key && p.value && p.value.type === 'member' && p.value.object.type === 'this' && rt.slots && rt.slots[p.value.prop]) {
        slots[p.key] = rt.slots[p.value.prop];
      } else if (p.key && p.value && p.value.type === 'ident' && rt.builderFns && rt.builderFns[p.value.name]) {
        const fn = rt.builderFns[p.value.name];
        slots[p.key] = (...args) => renderBuilderFn(fn, args, rt, registry);
      }
      if (p.key && p.value && p.value.type === 'member' && p.value.object.type === 'this' && rt.builders[p.value.prop]) {
        const b = rt.builders[p.value.prop];
        slots[p.key] = (...args) => {
          const s = rt.root.child();
          b.params.forEach((bp, k) => s.vars.set(bp.name, args[k]));
          return renderStatements(b.body, s, rt, registry);
        };
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
    slots,
    attrs: evAttrs,
    attr(name) {
      const a = evAttrs.filter((x) => x.name === name).pop();
      return a ? a.args : undefined;
    },
    // the trailing closure, or a builder passed as `content: this.someBuilder` (the same @BuilderParam in ArkUI)
    children: () => (call.children ? renderStatements(call.children, scope.child(), rt, registry) :
      (slots.content ? slots.content() : [])),
    hasChildren: !!(call.children && call.children.length) || !!slots.content,
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
