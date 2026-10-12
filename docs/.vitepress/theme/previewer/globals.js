/**
 * Web stand-ins for the SparkUI runtime objects examples refer to: `this.theme` / `SparkUI.theme`
 * (colours resolve to the CSS variables generated from Presets.ets), `SparkColor`, `SparkToast`, `SparkUI.layout`.
 */
import CLASSES from '../../generated/classes.json';
import { defineClasses } from './classes.js';

function kebab(name) {
  return name.replace(/([a-z])([A-Z0-9])/g, '$1-$2').toLowerCase();
}

/** `theme.colors.mutedForeground` → 'var(--muted-foreground)' */
const colorsProxy = new Proxy({}, {
  get(_, prop) {
    if (typeof prop !== 'string') {
      return undefined;
    }
    return `var(--${kebab(prop)})`;
  }
});

function shadowToken(name) {
  return { __shadow: name, toOptions: () => ({ __shadow: name }) };
}

export function createTheme() {
  const radius = 10;
  return {
    name: 'neutral',
    isDark: false,
    colors: colorsProxy,
    radius,
    radiusSm: radius - 4,
    radiusMd: radius - 2,
    radiusLg: radius,
    radiusXl: radius + 4,
    spacing: 4,
    borderWidth: 1,
    sp: (n) => 4 * n,
    text: {
      xs: 12, sm: 14, base: 16, lg: 18, xl: 20, xxl: 24, xxxl: 30, xxxxl: 36,
      leadingXs: 16, leadingSm: 20, leadingBase: 24, leadingLg: 28, leadingXl: 28, leadingXxl: 32, leadingXxxl: 36,
      leadingXxxxl: 40,
      weightNormal: 400, weightMedium: 500, weightSemibold: 600, weightBold: 700
    },
    shadows: {
      xs: shadowToken('xs'), sm: shadowToken('sm'), md: shadowToken('md'), lg: shadowToken('lg'),
      xl: shadowToken('xl'), xxl: shadowToken('xxl')
    },
    motion: {}
  };
}

const noop = () => undefined;

/** An object whose every method is a no-op (SparkUI.themes.*, SparkAnim.*, …). */
function noopObject(extra = {}) {
  return new Proxy(extra, {
    get(target, prop) {
      if (prop in target) {
        return target[prop];
      }
      return typeof prop === 'string' ? noop : undefined;
    }
  });
}

/** `:root { --a: b; } .dark { … }` → { root: {name: value}, dark: {…} } (enough of the SparkUI CSS subset). */
export function parseThemeCss(css) {
  const out = { root: {}, dark: {} };
  const src = String(css ?? '').replace(/\/\*[\s\S]*?\*\//g, '');
  const re = /(:root|\.dark)\s*\{([^}]*)\}/g;
  let m;
  while ((m = re.exec(src))) {
    const target = m[1] === ':root' ? out.root : out.dark;
    for (const decl of m[2].split(';')) {
      const i = decl.indexOf(':');
      const k = decl.slice(0, i).trim();
      if (i > 0 && k.startsWith('--')) {
        target[k] = decl.slice(i + 1).trim();
      }
    }
  }
  return out;
}

/** SparkUI.themes stand-in: variables / dark mode apply to the preview the snippet runs in. */
function themesApi(vars) {
  const v = vars || { root: {}, dark: {}, mode: null };
  const ok = () => ({ ok: true, diagnostics: [] });
  return noopObject({
    preset: 'neutral', accent: 'none',
    get mode() {
      return v.mode ?? 'system';
    },
    setVariable: (name, value, block = 'root') => {
      if (typeof name === 'string' && name.startsWith('--')) {
        const k = block === 'dark' ? 'dark' : 'root';
        v[k] = { ...v[k], [name]: String(value) };
      }
      return ok();
    },
    removeVariable: (name, block = 'root') => {
      const k = block === 'dark' ? 'dark' : 'root';
      const { [name]: _, ...rest } = v[k];
      v[k] = rest;
      return ok();
    },
    loadString: (css) => {
      const t = parseThemeCss(css);
      v.root = { ...v.root, ...t.root };
      v.dark = { ...v.dark, ...t.dark };
      return ok();
    },
    resetOverrides: () => {
      v.root = {};
      v.dark = {};
    },
    reset: () => {
      v.root = {};
      v.dark = {};
    },
    setMode: (m) => {
      v.mode = m === 'system' ? null : m;
      v.flip = false;
    },
    toggleDark: () => {
      // relative to whatever the preview currently shows (site mode or setMode)
      v.flip = !v.flip;
    },
    exportCss: () => [':root {', ...Object.entries(v.root).map(([k, x]) => `  ${k}: ${x};`), '}'].join('\n')
  });
}

export function createGlobals(theme, services = {}) {
  const env = {
    modality: 'pointer', posture: 'flat', windowMode: 'fullscreen', deviceType: 'web', simulated: false,
    safeArea: { top: 0, bottom: 0, left: 0, right: 0 }, keyboardHeight: 0
  };
  const layoutRoot = {
    widthClass: 'expanded', heightClass: 'medium', width: 800, height: 600, env,
    atLeast: (c) => ['compact', 'medium', 'expanded'].indexOf(c) <= 2,
    below: () => false
  };
  const toast = (message, opts) => services.toast?.(message, opts);
  const toastApi = Object.assign(toast, {
    show: toast,
    success: (m, o) => toast(m, { ...(o || {}), variant: 'success' }),
    error: (m, o) => toast(m, { ...(o || {}), variant: 'error' }),
    warning: (m, o) => toast(m, { ...(o || {}), variant: 'warning' }),
    info: (m, o) => toast(m, { ...(o || {}), variant: 'info' }),
    dismiss: noop
  });
  const globals = {
    SparkUI: {
      theme,
      themes: themesApi(services.themeVars),
      layout: { root: layoutRoot, env, simulate: noop }
    },
    SparkColor: {
      alpha: (c, a) => `color-mix(in oklab, ${c} ${Math.round(a * 100)}%, transparent)`,
      mix: (a, b, t) => `color-mix(in oklab, ${a}, ${b} ${Math.round(t * 100)}%)`
    },
    SparkToast: toastApi,
    toast: toastApi,
    SparkAnim: noopObject(),
    SparkIcons: noopObject({ names: () => [] }),
    UIUtils: noopObject(),
    sparkEmptyBuilder: noop
  };
  // library classes the snippets construct (new SparkChartSeries(...), new SparkShellNavItem(...) …)
  return defineClasses(CLASSES, globals);
}
