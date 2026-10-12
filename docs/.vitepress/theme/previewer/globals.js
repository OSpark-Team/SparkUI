/**
 * Web stand-ins for the SparkUI runtime objects examples refer to: `this.theme` / `SparkUI.theme`
 * (colours resolve to the CSS variables generated from Presets.ets), `SparkColor`, `SparkToast`, `SparkUI.layout`.
 */

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
  return {
    SparkUI: {
      theme,
      themes: noopObject({ mode: 'light', accent: 'none', preset: 'neutral', exportCss: () => '/* theme.css */' }),
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
}
