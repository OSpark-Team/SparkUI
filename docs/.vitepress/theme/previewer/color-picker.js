/**
 * Web imitations of SColorPanel / SColorPicker (components/color-picker): saturation / brightness area, hue and
 * alpha sliders, preview, colour input with format toggle, swatches, and the trigger + floating panel.
 * Colour math mirrors ColorPickerLogic.ets (hsv ↔ rgb, CSS-order hex, rgb / hsl / oklch formatting).
 */
import { h, ref, watch, defineComponent } from 'vue';

const DEFAULT_SWATCHES = [
  '#000000', '#737373', '#ffffff', '#ef4444', '#f97316', '#f59e0b', '#eab308', '#84cc16', '#22c55e', '#10b981',
  '#14b8a6', '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1', '#8b5cf6', '#a855f7', '#d946ef', '#ec4899', '#f43f5e'
];
const FORMATS = ['hex', 'rgb', 'hsl', 'oklch'];
const CHECKER = 'repeating-conic-gradient(var(--muted) 0% 25%, var(--background) 0% 50%) 50% / 8px 8px';

const clamp = (v, lo, hi) => (Number.isNaN(v) ? lo : Math.min(hi, Math.max(lo, v)));

function hsvToRgb(h, s, v) {
  const f = (n) => {
    const k = (n + h / 60) % 6;
    return v - v * s * Math.max(0, Math.min(k, 4 - k, 1));
  };
  return [f(5), f(3), f(1)];
}

function hueOf(r, g, b, fallback) {
  const max = Math.max(r, g, b);
  const d = max - Math.min(r, g, b);
  if (d < 1e-9) {
    return fallback;
  }
  let hh = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
  hh *= 60;
  return hh < 0 ? hh + 360 : hh;
}

function srgbToLinear(c) {
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function linearToSrgb(c) {
  return c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055;
}

function rgbToOklch(r, g, b) {
  const [lr, lg, lb] = [r, g, b].map(srgbToLinear);
  const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  const s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  const L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
  const A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  const C = Math.sqrt(A * A + B * B);
  let H = (Math.atan2(B, A) * 180) / Math.PI;
  if (H < 0) {
    H += 360;
  }
  return [L, C, C < 0.0001 ? 0 : H];
}

function oklchToRgb(L, C, H) {
  const a = C * Math.cos((H * Math.PI) / 180);
  const b = C * Math.sin((H * Math.PI) / 180);
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  return [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s
  ].map((c) => clamp(linearToSrgb(c), 0, 1));
}

/** CSS colour → [r, g, b, a] (0..1) or null. hex (CSS order), rgb(), hsl(), oklch(). */
function parse(text) {
  const t = String(text ?? '').trim().toLowerCase();
  const hex = /^#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/.exec(t);
  if (hex) {
    let v = hex[1];
    if (v.length === 3) {
      v = v.split('').map((c) => c + c).join('');
    }
    const ch = (i) => parseInt(v.substring(i, i + 2), 16) / 255;
    return [ch(0), ch(2), ch(4), v.length === 8 ? ch(6) : 1];
  }
  const fn = /^(rgba?|hsla?|oklch)\(([^)]*)\)$/.exec(t);
  if (!fn) {
    return null;
  }
  const [main, alphaPart] = fn[2].split('/');
  const parts = main.split(/[\s,]+/).filter(Boolean);
  if (parts.length < 3) {
    return null;
  }
  const num = (s, scale) => (s.endsWith('%') ? (parseFloat(s) / 100) * scale : parseFloat(s));
  const alpha = alphaPart !== undefined ? num(alphaPart.trim(), 1) : parts.length > 3 ? num(parts[3], 1) : 1;
  let rgb;
  if (fn[1].startsWith('rgb')) {
    rgb = parts.slice(0, 3).map((p) => num(p, 255) / 255);
  } else if (fn[1].startsWith('hsl')) {
    const hh = parseFloat(parts[0]);
    const s = num(parts[1], 1);
    const l = num(parts[2], 1);
    const f = (n) => {
      const k = (n + hh / 30) % 12;
      const a = s * Math.min(l, 1 - l);
      return l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1));
    };
    rgb = [f(0), f(8), f(4)];
  } else {
    rgb = oklchToRgb(num(parts[0], 1), num(parts[1], 0.4), parseFloat(parts[2]));
  }
  if (rgb.some((c) => Number.isNaN(c)) || Number.isNaN(alpha)) {
    return null;
  }
  return [...rgb.map((c) => clamp(c, 0, 1)), clamp(alpha, 0, 1)];
}

const n2 = (v, d) => String(Number(v.toFixed(d)));
const hex2 = (c) => Math.round(clamp(c, 0, 1) * 255).toString(16).padStart(2, '0');

function format([r, g, b, a], fmt, alpha) {
  const suffix = alpha && Math.round(a * 255) < 255 ? ` / ${n2(a, 2)}` : '';
  if (fmt === 'rgb') {
    return `rgb(${[r, g, b].map((c) => Math.round(c * 255)).join(' ')}${suffix})`;
  }
  if (fmt === 'hsl') {
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const l = (max + min) / 2;
    const d = max - min;
    const s = d < 1e-9 ? 0 : d / (1 - Math.abs(2 * l - 1));
    return `hsl(${Math.round(hueOf(r, g, b, 0)) % 360} ${Math.round(s * 100)}% ${Math.round(l * 100)}%${suffix})`;
  }
  if (fmt === 'oklch') {
    const [L, C, H] = rgbToOklch(r, g, b);
    return `oklch(${n2(L, 3)} ${n2(C, 3)} ${n2(H, 1)}${suffix})`;
  }
  const base = `#${hex2(r)}${hex2(g)}${hex2(b)}`;
  return alpha && Math.round(a * 255) < 255 ? base + hex2(a) : base;
}

const css = ([r, g, b, a]) => `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${a})`;

function chip(rgba, size, radius) {
  return h('span', {
    style: { position: 'relative', display: 'inline-block', flex: 'none', width: `${size}px`, height: `${size}px`, borderRadius: radius,
      border: '1px solid var(--border)', overflow: 'hidden', background: CHECKER }
  }, h('span', { style: { position: 'absolute', inset: 0, background: css(rgba) } }));
}

/** pointer drag inside `el` → callback(x 0..1, y 0..1) */
function drag(e, cb, done) {
  const el = e.currentTarget;
  const move = (ev) => {
    const r = el.getBoundingClientRect();
    cb(clamp((ev.clientX - r.left) / r.width, 0, 1), clamp((ev.clientY - r.top) / r.height, 0, 1));
  };
  move(e);
  const up = () => {
    window.removeEventListener('pointermove', move);
    window.removeEventListener('pointerup', up);
    done?.();
  };
  window.addEventListener('pointermove', move);
  window.addEventListener('pointerup', up);
}

function track(background, ratio, thumbColor, onPick, done) {
  return h('div', {
    style: { position: 'relative', height: '16px', cursor: 'pointer', touchAction: 'none' },
    onPointerdown: (e) => drag(e, (x) => onPick(x), done)
  }, [
    h('div', { style: { position: 'absolute', left: 0, right: 0, top: '2px', height: '12px', borderRadius: '6px', border: '1px solid var(--border)', background } }),
    h('span', { style: { position: 'absolute', top: 0, left: `calc(${ratio * 100}% - ${ratio * 16}px)`, width: '16px', height: '16px', borderRadius: '50%',
      border: '2px solid #fff', boxShadow: 'var(--ark-shadow-sm)', background: thumbColor, boxSizing: 'border-box' } })
  ]);
}

/** Shared state of a panel: hsv + alpha, kept in sync with a controlled `value`. */
function usePanel(getValue, emit, commit, opts) {
  const hsv = ref([0, 0, 0, 1]);
  const load = (text) => {
    const c = parse(text);
    if (!c) {
      return false;
    }
    const [r, g, b, a] = c;
    const max = Math.max(r, g, b);
    hsv.value = [hueOf(r, g, b, hsv.value[0]), max <= 1e-9 ? hsv.value[1] : (max - Math.min(r, g, b)) / max, max, a];
    return true;
  };
  load(getValue());
  let last = format(rgba(), opts().format || 'hex', !!opts().alpha);
  watch(getValue, (v) => {
    if (v !== undefined && v !== last) {
      load(v);
      last = v;
    }
  });
  function rgba() {
    const [hh, s, v, a] = hsv.value;
    return [...hsvToRgb(hh, s, v), opts().alpha ? a : 1];
  }
  const update = (next) => {
    hsv.value = next;
    const v = format(rgba(), opts().format || 'hex', !!opts().alpha);
    if (v !== last) {
      last = v;
      emit(v);
    }
  };
  return { hsv, rgba, load, update, commit: () => commit(last), pick: (text) => load(text) && update([...hsv.value]) };
}

function panelView(p, o, display, setDisplay, footer) {
  const [hh, s, v, a] = p.hsv.value;
  const cur = p.rgba();
  const fmt = display.value;
  const swatches = Array.isArray(o.swatches) ? o.swatches : DEFAULT_SWATCHES;
  const hueCss = css([...hsvToRgb(hh, 1, 1), 1]);
  const opaque = css([...hsvToRgb(hh, s, v), 1]);
  const kids = [
    h('div', {
      style: { position: 'relative', height: '160px', borderRadius: 'var(--ark-radius-md)', border: '1px solid var(--border)', cursor: 'crosshair',
        touchAction: 'none', background: `linear-gradient(to bottom, transparent, #000), linear-gradient(to right, #fff, transparent), ${hueCss}` },
      onPointerdown: (e) => !o.disabled && drag(e, (x, y) => p.update([hh, x, 1 - y, a]), p.commit)
    }, h('span', { style: { position: 'absolute', left: `calc(${s * 100}% - 8px)`, top: `calc(${(1 - v) * 100}% - 8px)`, width: '16px', height: '16px',
      borderRadius: '50%', border: '2px solid #fff', boxShadow: 'var(--ark-shadow-sm)', background: opaque, boxSizing: 'border-box' } })),
    h('div', { style: { display: 'flex', alignItems: 'center', gap: '12px' } }, [
      h('div', { style: { flex: 1, display: 'flex', flexDirection: 'column', gap: '8px' } }, [
        track('linear-gradient(to right, #f00, #ff0, #0f0, #0ff, #00f, #f0f, #f00)', hh / 360, hueCss,
          (x) => !o.disabled && p.update([x * 360, s, v, a]), p.commit),
        o.alpha ? track(`linear-gradient(to right, transparent, ${opaque}), ${CHECKER}`, a, css(cur),
          (x) => !o.disabled && p.update([hh, s, v, x]), p.commit) : null
      ]),
      chip(cur, o.alpha ? 40 : 28, 'var(--ark-radius-md)')
    ])
  ];
  if (o.showInput !== false) {
    kids.push(h('div', { style: { display: 'flex', gap: '8px' } }, [
      o.formatToggle ? h('button', { class: ['ark-btn', 'ark-btn-outline'], style: { flex: 'none' },
        onClick: () => setDisplay(FORMATS[(FORMATS.indexOf(fmt) + 1) % FORMATS.length]) }, fmt.toUpperCase()) : null,
      h('label', { class: ['ark-input', 'size-default'], style: { flex: 1 } }, h('input', {
        class: 'ark-input-inner', value: format(cur, fmt, !!o.alpha), disabled: o.disabled,
        onChange: (e) => p.pick(e.target.value) && p.commit()
      }))
    ]));
  }
  if (swatches.length) {
    kids.push(h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '8px', padding: '4px' } }, swatches.map((sw) => {
      const c = parse(sw) || [0, 0, 0, 0];
      const on = c.slice(0, 3).every((x, i) => Math.abs(x - cur[i]) < 1.5);
      // selected: background gap + foreground ring (same as the library swatch)
      return h('span', { title: sw, style: { cursor: 'pointer', display: 'inline-flex', borderRadius: 'var(--ark-radius-sm)',
        boxShadow: on ? '0 0 0 2px var(--background), 0 0 0 4px var(--foreground)' : 'none' },
        onClick: () => !o.disabled && p.pick(sw) && p.commit() },
        chip(c, 20, 'var(--ark-radius-sm)'));
    })));
  }
  kids.push(...footer);
  return kids;
}

const def = (name, setup) => defineComponent({ name, props: { n: { type: Object, required: true } }, setup });

function wiring(props) {
  const o = () => props.n.props;
  const local = ref(o().value ?? o().defaultValue ?? '#000000');
  watch(() => props.n.props.value, (v) => {
    if (v !== undefined) {
      local.value = v;
    }
  });
  const emit = (v) => {
    local.value = v;
    props.n.binds.value?.(v);
    if (typeof o().onValueChange === 'function') {
      o().onValueChange(v);
    }
  };
  const commit = (v) => {
    if (typeof o().onValueCommit === 'function') {
      o().onValueCommit(v);
    }
  };
  return { local, panel: usePanel(() => local.value, emit, commit, o) };
}

export const SColorPanel = def('SColorPanel', (props) => {
  const { panel } = wiring(props);
  const display = ref(props.n.props.format || 'hex');
  return () => {
    const o = props.n.props;
    return h('div', {
      class: 'ark-color-panel', ...props.n.events,
      style: [{ display: 'flex', flexDirection: 'column', gap: '12px', width: '240px', maxWidth: '100%', opacity: o.disabled ? 0.5 : 1 }, props.n.style]
    }, panelView(panel, o, display, (f) => (display.value = f), props.n.children()));
  };
});

export const SColorPicker = def('SColorPicker', (props) => {
  const { local, panel } = wiring(props);
  const open = ref(false);
  const display = ref(props.n.props.format || 'hex');
  return () => {
    const o = props.n.props;
    const c = parse(local.value) || [0, 0, 0, 0];
    const text = format(c, o.format || 'hex', !!o.alpha);
    const sm = o.sizing === 'sm';
    return h('span', { class: 'ark-overlay-root', ...props.n.events, style: props.n.style }, [
      h('button', {
        class: ['ark-btn', 'ark-btn-outline', o.disabled && 'disabled'],
        disabled: !!o.disabled,
        style: { height: sm ? '32px' : '36px', width: o.iconOnly ? (sm ? '32px' : '36px') : (o.triggerWidth === '100%' ? '100%' : undefined),
          padding: o.iconOnly ? 0 : '0 12px 0 8px', justifyContent: o.iconOnly ? 'center' : 'flex-start', fontWeight: 400 },
        onClick: () => (open.value = !open.value)
      }, [chip(c, sm ? 16 : 18, 'var(--ark-radius-sm)'), o.iconOnly ? null : h('span', { style: { fontVariantNumeric: 'tabular-nums' } }, text)]),
      open.value ? h('div', { class: 'ark-floating side-bottom align-start', style: { padding: '12px', width: '266px' } },
        h('div', { style: { display: 'flex', flexDirection: 'column', gap: '12px' } },
          panelView(panel, o, display, (f) => (display.value = f), props.n.children()))) : null
    ]);
  };
});
