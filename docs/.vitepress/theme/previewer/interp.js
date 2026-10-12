/**
 * Expression evaluator for the ArkTS subset produced by parser.js. Framework-free so the build scripts can
 * reuse it. Evaluation is forgiving: unknown identifiers resolve to "enum proxies" (`FlexAlign.Center`
 * evaluates to the string 'FlexAlign.Center'), unknown calls return undefined, and nothing throws for
 * missing members.
 */
import { parseProgram } from './parser.js';

export class Scope {
  constructor(parent = null, vars = {}) {
    this.parent = parent;
    this.vars = new Map(Object.entries(vars));
  }

  lookup(name) {
    let s = this;
    while (s) {
      if (s.vars.has(name)) {
        return { found: true, value: s.vars.get(name), scope: s };
      }
      s = s.parent;
    }
    return { found: false };
  }

  set(name, value) {
    const r = this.lookup(name);
    (r.found ? r.scope : this).vars.set(name, value);
  }

  child(vars = {}) {
    return new Scope(this, vars);
  }
}

const ENUM_TAG = Symbol('enum');

/** `FlexAlign` → proxy; `FlexAlign.Center` → 'FlexAlign.Center'; `Color.Red` → 'Color.Red'. */
export function enumProxy(name) {
  return new Proxy(
    { [ENUM_TAG]: name },
    {
      get(target, prop) {
        if (prop === ENUM_TAG) {
          return name;
        }
        if (prop === Symbol.toPrimitive || prop === 'toString' || prop === 'valueOf') {
          return () => name;
        }
        if (typeof prop === 'symbol') {
          return undefined;
        }
        return `${name}.${prop}`;
      }
    }
  );
}

export function isEnumProxy(v) {
  return v !== null && typeof v === 'object' && v[ENUM_TAG] !== undefined;
}

/** LengthMetrics.vp(8) etc. */
const LENGTH_METRICS = {
  vp: (v) => v,
  px: (v) => v,
  fp: (v) => v,
  lpx: (v) => v,
  percent: (v) => `${v * 100}%`,
  resource: () => undefined
};

const SAFE_GLOBALS = {
  Math,
  JSON,
  Number,
  String,
  Boolean,
  Array,
  Object: { keys: Object.keys, values: Object.values, entries: Object.entries, assign: Object.assign },
  Date,
  Map,
  Set,
  parseInt,
  parseFloat,
  isNaN,
  isFinite,
  console: { info() {}, log() {}, warn() {}, error() {}, debug() {} },
  LengthMetrics: LENGTH_METRICS,
  setTimeout: (fn, ms) => setTimeout(fn, Math.min(Number(ms) || 0, 5000)),
  clearTimeout: (id) => clearTimeout(id),
  setInterval: () => -1,
  clearInterval: () => {},
  $r: () => undefined,
  $rawfile: () => undefined
};

const BLOCKED_PROPS = new Set(['constructor', '__proto__', 'prototype', '__defineGetter__', '__defineSetter__']);

const BREAK = { break: true };
const CONTINUE = { continue: true };
/** loops in helper code run at most this many iterations (the previewer must never hang a page) */
const MAX_ITERATIONS = 20000;

class ReturnSignal {
  constructor(value) {
    this.value = value;
  }
}

export class Interpreter {
  /**
   * @param {object} self the `this` object (reactive demo state)
   * @param {object} globals extra globals, e.g. a theme proxy or `SparkUI`
   */
  constructor(self, globals = {}) {
    this.self = self;
    this.globals = globals;
    this.methods = {};
  }

  evaluate(node, scope) {
    if (!node) {
      return undefined;
    }
    switch (node.type) {
      case 'lit':
        // a regex literal shipped as JSON (generated demo bodies): { __re: [body, flags] }
        if (node.value && typeof node.value === 'object' && Array.isArray(node.value.__re)) {
          try {
            return new RegExp(node.value.__re[0], node.value.__re[1]);
          } catch (e) {
            return undefined;
          }
        }
        return node.value;
      case 'tpl': {
        let s = node.quasis[0];
        for (let k = 0; k < node.exprs.length; k++) {
          s += fmt(this.evaluate(node.exprs[k], scope)) + node.quasis[k + 1];
        }
        return s;
      }
      case 'this':
        return this.self;
      case 'ident':
        return this.ident(node.name, scope);
      case 'array': {
        const out = [];
        for (const it of node.items) {
          if (it.type === 'spread') {
            const v = this.evaluate(it.arg, scope);
            if (v && typeof v[Symbol.iterator] === 'function') {
              out.push(...v);
            }
          } else {
            out.push(this.evaluate(it, scope));
          }
        }
        return out;
      }
      case 'object': {
        const out = {};
        for (const p of node.props) {
          if (p.spread) {
            Object.assign(out, this.evaluate(p.spread, scope));
          } else if (!p.ellipsis) {
            const key = p.computed ? String(this.evaluate(p.computed, scope)) : p.key;
            if (!BLOCKED_PROPS.has(key)) {
              out[key] = this.evaluate(p.value, scope);
            }
          }
        }
        return out;
      }
      case 'member': {
        const obj = this.evaluate(node.object, scope);
        const key = node.computed ? this.evaluate(node.prop, scope) : node.prop;
        return getMember(obj, key);
      }
      case 'call':
        return this.call(node, scope);
      case 'new':
        return this.construct(node, scope);
      case 'arrow':
        return this.makeFunction(node, scope);
      case 'unary': {
        const v = this.evaluate(node.arg, scope);
        switch (node.op) {
          case '!':
            return !v;
          case '-':
            return -v;
          case '+':
            return +v;
          case '~':
            return ~v;
          case 'typeof':
            return typeof v;
          default:
            return v;
        }
      }
      case 'bin':
        return this.binary(node, scope);
      case 'cond':
        return this.evaluate(node.test, scope) ? this.evaluate(node.cons, scope) : this.evaluate(node.alt, scope);
      case 'as':
        return this.evaluate(node.expr, scope);
      case 'bind':
        return this.evaluate(node.target, scope);
      case 'assign':
        return this.assign(node, scope);
      case 'update': {
        const old = Number(this.evaluate(node.arg, scope)) || 0;
        const nv = node.op === '++' ? old + 1 : old - 1;
        this.store(node.arg, nv, scope);
        return node.prefix ? nv : old;
      }
      case 'seq': {
        let v;
        for (const e of node.list) {
          v = this.evaluate(e, scope);
        }
        return v;
      }
      case 'ellipsis':
      case 'spread':
        return undefined;
      default:
        return undefined;
    }
  }

  ident(name, scope) {
    const r = scope ? scope.lookup(name) : { found: false };
    if (r.found) {
      return r.value;
    }
    if (Object.prototype.hasOwnProperty.call(this.globals, name)) {
      return this.globals[name];
    }
    if (Object.prototype.hasOwnProperty.call(SAFE_GLOBALS, name)) {
      return SAFE_GLOBALS[name];
    }
    if (/^[A-Z]/.test(name)) {
      return enumProxy(name);
    }
    return undefined;
  }

  binary(node, scope) {
    const op = node.op;
    if (op === '&&') {
      return this.evaluate(node.left, scope) && this.evaluate(node.right, scope);
    }
    if (op === '||') {
      return this.evaluate(node.left, scope) || this.evaluate(node.right, scope);
    }
    if (op === '??') {
      const l = this.evaluate(node.left, scope);
      return l ?? this.evaluate(node.right, scope);
    }
    const a = this.evaluate(node.left, scope);
    const b = this.evaluate(node.right, scope);
    switch (op) {
      case '+':
        return (typeof a === 'string' || typeof b === 'string') ? fmt(a) + fmt(b) : a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        return a / b;
      case '%':
        return a % b;
      case '**':
        return a ** b;
      case '==':
      case '===':
        return a === b || (isEnumProxy(a) || isEnumProxy(b) ? String(a) === String(b) : false);
      case '!=':
      case '!==':
        return !(a === b || (isEnumProxy(a) || isEnumProxy(b) ? String(a) === String(b) : false));
      case '<':
        return a < b;
      case '>':
        return a > b;
      case '<=':
        return a <= b;
      case '>=':
        return a >= b;
      case '&':
        return a & b;
      case '|':
        return a | b;
      case '^':
        return a ^ b;
      case '<<':
        return a << b;
      case '>>':
        return a >> b;
      case '>>>':
        return a >>> b;
      case 'in':
        return b !== null && typeof b === 'object' && a in b;
      case 'instanceof':
        return false;
      default:
        return undefined;
    }
  }

  assign(node, scope) {
    let v = this.evaluate(node.right, scope);
    if (node.op !== '=') {
      const old = this.evaluate(node.left, scope);
      switch (node.op) {
        case '+=':
          v = (typeof old === 'string' || typeof v === 'string') ? fmt(old) + fmt(v) : old + v;
          break;
        case '-=':
          v = old - v;
          break;
        case '*=':
          v = old * v;
          break;
        case '/=':
          v = old / v;
          break;
        case '%=':
          v = old % v;
          break;
        case '||=':
          v = old || v;
          break;
        case '&&=':
          v = old && v;
          break;
        case '??=':
          v = old ?? v;
          break;
        default:
          break;
      }
    }
    this.store(node.left, v, scope);
    return v;
  }

  /** Assign to `this.x`, `this.a.b`, `local`, `arr[i]`. */
  store(target, value, scope) {
    if (target.type === 'ident') {
      if (scope) {
        scope.set(target.name, value);
      }
      return;
    }
    if (target.type === 'member') {
      const obj = this.evaluate(target.object, scope);
      const key = target.computed ? this.evaluate(target.prop, scope) : target.prop;
      if (obj !== null && typeof obj === 'object' && !BLOCKED_PROPS.has(String(key)) && !isEnumProxy(obj)) {
        obj[key] = value;
      }
    }
  }

  call(node, scope) {
    const args = [];
    for (const a of node.args) {
      if (a.type === 'spread') {
        const v = this.evaluate(a.arg, scope);
        if (Array.isArray(v)) {
          args.push(...v);
        }
      } else {
        args.push(this.evaluate(a, scope));
      }
    }
    if (node.callee.type === 'member') {
      const obj = this.evaluate(node.callee.object, scope);
      const key = node.callee.computed ? this.evaluate(node.callee.prop, scope) : node.callee.prop;
      if (obj === this.self && typeof this.methods[key] === 'function') {
        return this.methods[key](...args);
      }
      const fn = getMember(obj, key);
      if (typeof fn === 'function') {
        try {
          return fn.apply(obj, args);
        } catch (e) {
          return undefined;
        }
      }
      return undefined;
    }
    const fn = this.evaluate(node.callee, scope);
    if (typeof fn === 'function') {
      try {
        return fn(...args);
      } catch (e) {
        return undefined;
      }
    }
    return undefined;
  }

  construct(node, scope) {
    const name = node.callee.type === 'ident' ? node.callee.name : '';
    const args = node.args.map((a) => this.evaluate(a, scope));
    switch (name) {
      case 'Array':
        return new Array(...args);
      case 'Date':
        return new Date(...args);
      case 'Map':
        return new Map(...args);
      case 'Set':
        return new Set(...args);
      default: {
        const ctor = this.globals[name];
        if (typeof ctor === 'function') {
          try {
            return ctor(...args);
          } catch (e) {
            return { __class: name, args };
          }
        }
        return { __class: name, args };
      }
    }
  }

  makeFunction(node, scope) {
    const interp = this;
    return function arrowFn(...args) {
      const local = (scope || new Scope()).child();
      node.params.forEach((p, k) => {
        local.vars.set(p.name, args[k] === undefined && p.def ? interp.evaluate(p.def, scope) : args[k]);
      });
      if (node.expression) {
        return interp.evaluate(node.body, local);
      }
      return interp.runBlock(node.body, local);
    };
  }

  /** Run imperative statements (event handlers, helper methods). */
  runBlock(stmts, scope) {
    try {
      this.exec(stmts, scope);
    } catch (e) {
      if (e instanceof ReturnSignal) {
        return e.value;
      }
      return undefined;
    }
    return undefined;
  }

  /** `for (init; test; update)` / `while (test)` */
  loop(st, scope) {
    const s = scope.child();
    if (st.init) {
      this.exec([st.init], s);
    }
    for (let k = 0; k < MAX_ITERATIONS; k++) {
      if (st.test && !this.evaluate(st.test, s)) {
        return;
      }
      if (this.iteration(st.body, s.child())) {
        return;
      }
      if (st.update) {
        this.evaluate(st.update, s);
      }
    }
  }

  /** One loop iteration; true when the body hit `break`. */
  iteration(body, scope) {
    try {
      this.exec(body, scope);
    } catch (e) {
      if (e === BREAK) {
        return true;
      }
      if (e !== CONTINUE) {
        throw e;
      }
    }
    return false;
  }

  exec(stmts, scope) {
    for (const st of stmts) {
      switch (st.type) {
        case 'expr':
          this.evaluate(st.expr, scope);
          break;
        case 'var':
          if (st.name) {
            scope.vars.set(st.name, this.evaluate(st.init, scope));
          }
          break;
        case 'block':
          this.exec(st.body, st.transparent ? scope : scope.child());
          break;
        case 'if':
          if (this.evaluate(st.test, scope)) {
            this.exec(st.then, scope.child());
          } else if (st.otherwise) {
            this.exec(st.otherwise, scope.child());
          }
          break;
        case 'return':
          throw new ReturnSignal(this.evaluate(st.arg, scope));
        case 'break':
          throw BREAK;
        case 'continue':
          throw CONTINUE;
        case 'loop':
          this.loop(st, scope);
          break;
        case 'forOf': {
          const v = this.evaluate(st.iter, scope);
          let items = [];
          if (st.mode === 'in') {
            items = v && typeof v === 'object' ? Object.keys(v) : [];
          } else if (v && typeof v[Symbol.iterator] === 'function') {
            items = [...v];
          }
          for (const item of items.slice(0, MAX_ITERATIONS)) {
            if (this.iteration(st.body, scope.child({ [st.name]: item }))) {
              break;
            }
          }
          break;
        }
        case 'throw':
          throw new Error('thrown');
        case 'try':
          try {
            this.exec(st.block, scope.child());
          } catch (e) {
            if (e instanceof ReturnSignal || e === BREAK || e === CONTINUE || !st.handler) {
              throw e;
            }
            this.exec(st.handler, scope.child(st.param ? { [st.param]: e } : {}));
          } finally {
            if (st.finalizer) {
              this.exec(st.finalizer, scope.child());
            }
          }
          break;
        case 'switch': {
          const v = this.evaluate(st.disc, scope);
          let k = st.cases.findIndex((c) => c.test && this.evaluate(c.test, scope) === v);
          if (k < 0) {
            k = st.cases.findIndex((c) => !c.test);
          }
          if (k >= 0) {
            try {
              for (; k < st.cases.length; k++) {
                this.exec(st.cases[k].body, scope);
              }
            } catch (e) {
              if (e !== BREAK) {
                throw e;
              }
            }
          }
          break;
        }
        default:
          break;
      }
    }
  }
}

function getMember(obj, key) {
  if (obj === null || obj === undefined) {
    return undefined;
  }
  if (typeof key === 'symbol' || BLOCKED_PROPS.has(String(key))) {
    return undefined;
  }
  if (isEnumProxy(obj)) {
    return obj[key];
  }
  try {
    const v = obj[key];
    if (typeof v === 'function' && (typeof obj === 'string' || Array.isArray(obj) || typeof obj === 'number' ||
      obj instanceof Map || obj instanceof Set || obj instanceof Date)) {
      return v.bind(obj);
    }
    return v;
  } catch (e) {
    return undefined;
  }
}

export function fmt(v) {
  if (v === undefined) {
    return 'undefined';
  }
  if (v === null) {
    return 'null';
  }
  if (isEnumProxy(v)) {
    return String(v);
  }
  if (typeof v === 'object') {
    if (Array.isArray(v)) {
      return v.map(fmt).join(',');
    }
    return '[object Object]';
  }
  return String(v);
}

/**
 * Split a program into demo state (struct fields), helper methods, top-level declarations and the UI body.
 * @returns {{ state: object, ui: object[], methods: object[], decls: object[], errors: object[] }}
 */
export function analyzeProgram(program) {
  const errors = [];
  const fields = [];
  const methods = [];
  const decls = [];
  let ui = [];
  let struct = null;
  for (const st of program.body) {
    if (st.type === 'struct') {
      const hasBuild = st.members.some((m) => m.type === 'method' && m.name === 'build');
      if (!struct || (hasBuild && st.decorators.some((d) => d.name === 'Entry'))) {
        struct = st;
      }
    }
  }
  for (const st of program.body) {
    if (st.type === 'error') {
      errors.push(st);
    } else if (st.type === 'var' || (st.type === 'block' && st.transparent)) {
      decls.push(st);
    } else if (st.type === 'field') {
      fields.push(st);
    } else if (st.type === 'method') {
      if (st.name === 'build') {
        ui = st.body;
      } else {
        methods.push(st);
      }
    } else if (st.type !== 'struct' && !struct) {
      ui.push(st);
    }
  }
  if (struct) {
    for (const m of struct.members) {
      if (m.type === 'field') {
        fields.push(m);
      } else if (m.type === 'method') {
        if (m.name === 'build') {
          ui = m.body;
        } else {
          methods.push(m);
        }
      } else if (m.type === 'error') {
        errors.push(m);
      }
    }
  }
  collectErrors(ui, errors);
  return { fields, methods, decls, ui, errors };
}

function collectErrors(stmts, out) {
  for (const st of stmts || []) {
    if (st.type === 'error') {
      out.push(st);
    } else if (st.type === 'if') {
      collectErrors(st.then, out);
      collectErrors(st.otherwise, out);
    } else if (st.type === 'expr') {
      walkCalls(st.expr, out);
    }
  }
}

function walkCalls(e, out) {
  while (e) {
    if (e.type === 'call') {
      if (e.children) {
        collectErrors(e.children, out);
      }
      for (const a of e.args) {
        if (a.type === 'arrow' && !a.expression) {
          collectErrors(a.body, out);
        }
      }
      e = e.callee;
    } else if (e.type === 'member') {
      e = e.object;
    } else {
      return;
    }
  }
}

/** Convenience: parse + evaluate a constant string expression (used by the build scripts). */
export function evaluateSource(src, vars = {}) {
  const program = parseProgram(`(${src})`);
  const st = program.body[0];
  if (!st || st.type !== 'expr') {
    return undefined;
  }
  return new Interpreter({}, {}).evaluate(st.expr, new Scope(null, vars));
}
