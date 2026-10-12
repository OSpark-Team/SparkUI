/**
 * Web imitations of ArkUI containers and SparkUI components, styled with the shadcn tokens generated from
 * Presets.ets (see preview.css). They follow the SparkUI recipes (sizes, radii, variants) closely but not
 * pixel-perfectly; anything not listed here renders as a labelled placeholder (runtime.js).
 */
import {
  h, ref, reactive, computed, watch, provide, inject, defineComponent, onMounted, onBeforeUnmount, Teleport,
  Fragment
} from 'vue';
import { icon } from './icons.js';
import { len, color, flexAlign } from './runtime.js';
import { isEnumProxy } from './interp.js';
import { cartesian, pie, radial, radar, chartContainer } from './charts.js';

// ------------------------------------------------------------------------------------------------ helpers

function txt(v) {
  if (v === undefined || v === null) {
    return '';
  }
  if (typeof v === 'object' && !isEnumProxy(v)) {
    return '';
  }
  return String(v);
}

function en(v) {
  return v === undefined || v === null ? '' : String(v).split('.').pop();
}

function rootProps(n, cls, style, extra = {}) {
  return { class: cls, style: [style || {}, n.style], ...n.events, ...extra };
}

const def = (name, setup) => defineComponent({ name, props: { n: { type: Object, required: true } }, setup });
const C = (comp) => (n) => h(comp, { n });

/** Controlled / uncontrolled value with `!!` binding and change event (SparkUI convention). */
function useModel(props, key, defKey, fallback, event) {
  const p = () => props.n.props;
  const init = p()[key] !== undefined ? p()[key] : (p()[defKey] !== undefined ? p()[defKey] : fallback);
  const local = ref(init);
  watch(() => props.n.props[key], (v) => {
    if (v !== undefined) {
      local.value = v;
    }
  });
  const set = (v) => {
    local.value = v;
    props.n.binds[key]?.(v);
    const fn = props.n.props[event];
    if (typeof fn === 'function') {
      fn(v);
    }
  };
  return [local, set];
}

function call(fn, ...args) {
  if (typeof fn === 'function') {
    try {
      return fn(...args);
    } catch (e) {
      return undefined;
    }
  }
  return undefined;
}

const ICON_SIZES = { sm: 14, default: 16, lg: 18 };

// ------------------------------------------------------------------------------------------------ ArkUI basics

function flexBox(n, dir, defaults) {
  const o = n.props;
  const style = { display: 'flex', flexDirection: dir, ...defaults };
  if (o.space !== undefined && typeof o.space !== 'object') {
    style.gap = len(o.space);
  }
  const ai = n.attr('alignItems');
  if (ai) {
    style.alignItems = flexAlign(ai[0]);
  }
  const jc = n.attr('justifyContent');
  if (jc) {
    style.justifyContent = flexAlign(jc[0]);
  }
  return style;
}

const Column = (n) => h('div', rootProps(n, 'ark-col', flexBox(n, 'column', { alignItems: 'center' })), n.children());
const Row = (n) => h('div', rootProps(n, 'ark-row', flexBox(n, 'row', { alignItems: 'center' })), n.children());

function Flex(n) {
  const o = n.props;
  const dir = en(o.direction);
  const style = {
    display: 'flex',
    flexDirection: { Column: 'column', RowReverse: 'row-reverse', ColumnReverse: 'column-reverse' }[dir] || 'row',
    flexWrap: en(o.wrap) === 'Wrap' ? 'wrap' : en(o.wrap) === 'WrapReverse' ? 'wrap-reverse' : 'nowrap',
    justifyContent: flexAlign(o.justifyContent) || 'flex-start',
    alignItems: flexAlign(o.alignItems) || 'flex-start',
    alignContent: flexAlign(o.alignContent)
  };
  if (o.space) {
    style.rowGap = len(o.space.cross ?? 0);
    style.columnGap = len(o.space.main ?? 0);
  }
  return h('div', rootProps(n, 'ark-flex', style), n.children());
}

const STACK_ALIGN = {
  TopStart: ['start', 'start'], Top: ['start', 'center'], TopEnd: ['start', 'end'],
  Start: ['center', 'start'], Center: ['center', 'center'], End: ['center', 'end'],
  BottomStart: ['end', 'start'], Bottom: ['end', 'center'], BottomEnd: ['end', 'end']
};

function Stack(n) {
  const a = STACK_ALIGN[en(n.props.alignContent ?? n.attr('alignContent')?.[0])] || STACK_ALIGN.Center;
  return h('div', rootProps(n, 'ark-stack', { alignItems: a[0], justifyItems: a[1] }), n.children());
}

function Text(n) {
  const content = n.args[0];
  const kids = n.hasChildren ? n.children() : null;
  return h('span', rootProps(n, 'ark-text'), kids && kids.length ? kids : txt(content));
}

const Span = (n) => h('span', rootProps(n, 'ark-span'), txt(n.args[0]));

function NativeButton(n) {
  const label = typeof n.args[0] === 'string' ? n.args[0] : undefined;
  return h('button', rootProps(n, 'ark-native-button'), label !== undefined ? label : n.children());
}

function Image(n) {
  const src = n.args[0];
  if (typeof src === 'string' && /^(https?:|data:)/.test(src)) {
    return h('img', rootProps(n, 'ark-image', {}, { src, alt: '' }));
  }
  return h('div', rootProps(n, 'ark-image-placeholder'), icon('image', 20));
}

const Divider = (n) => h('div', rootProps(n, n.attr('vertical')?.[0] ? 'ark-divider vertical' : 'ark-divider'));
const Blank = (n) => h('div', rootProps(n, 'ark-blank'));

function Scroll(n) {
  const horizontal = en(n.attr('scrollable')?.[0]) === 'Horizontal';
  return h('div', rootProps(n, horizontal ? 'ark-scroll horizontal' : 'ark-scroll'), n.children());
}

function List(n) {
  const horizontal = en(n.attr('listDirection')?.[0]) === 'Horizontal';
  const style = { display: 'flex', flexDirection: horizontal ? 'row' : 'column', gap: len(n.props.space) };
  return h('div', rootProps(n, 'ark-list', style), n.children());
}

const ListItem = (n) => h('div', rootProps(n, 'ark-list-item'), n.children());

function Grid(n) {
  const cols = n.attr('columnsTemplate')?.[0];
  const style = { display: 'grid', gridTemplateColumns: cols || '1fr', columnGap: len(n.attr('columnsGap')?.[0]), rowGap: len(n.attr('rowsGap')?.[0]) };
  return h('div', rootProps(n, 'ark-grid', style), n.children());
}

const GridItem = (n) => h('div', rootProps(n, 'ark-grid-item'), n.children());

const NativeToggle = def('NativeToggle', (props) => {
  const on = ref(!!props.n.props.isOn);
  return () => {
    const type = en(props.n.props.type);
    if (type === 'Checkbox') {
      return h('span', rootProps(props.n, ['ark-checkbox', on.value && 'checked'], {}, { onClick: () => (on.value = !on.value) }),
        on.value ? icon('check', 14, 'var(--primary-foreground)', 3) : null);
    }
    if (type === 'Button') {
      return h('button', rootProps(props.n, ['ark-native-button', !on.value && 'off'], {}, { onClick: () => (on.value = !on.value) }), props.n.children());
    }
    return h('span', rootProps(props.n, ['ark-switch', on.value && 'checked'], {}, {
      role: 'switch', onClick: () => (on.value = !on.value)
    }), h('span', { class: 'ark-switch-thumb' }));
  };
});

const NativeTextInput = (n) => h('input', rootProps(n, 'ark-input', {}, {
  placeholder: txt(n.props.placeholder), value: txt(n.props.text), type: en(n.attr('type')?.[0]) === 'Password' ? 'password' : 'text'
}));
const NativeTextArea = (n) => h('textarea', rootProps(n, 'ark-input ark-textarea', {}, {
  placeholder: txt(n.props.placeholder), value: txt(n.props.text)
}));

function NativeProgress(n) {
  const v = Number(n.props.value ?? 0);
  const total = Number(n.props.total ?? 100) || 100;
  return h('div', rootProps(n, 'ark-progress'), h('div', { class: 'ark-progress-bar', style: { width: `${(v / total) * 100}%` } }));
}

const LoadingProgress = (n) => h('span', rootProps(n, 'ark-spin', { width: '24px', height: '24px' }), icon('loader-circle', 24));

function Shape(kind) {
  return (n) => {
    const w = len(n.props.width ?? n.style.width ?? 40);
    const hh = len(n.props.height ?? n.style.height ?? 40);
    const fill = color(n.attr('fill')?.[0]) || 'var(--muted)';
    const r = kind === 'circle' ? '50%' : len(n.attr('radius')?.[0] ?? n.props.radius ?? 0);
    return h('div', rootProps(n, 'ark-shape', { width: w, height: hh, background: fill, borderRadius: r }));
  };
}

const SymbolGlyph = (n) => h('span', rootProps(n, 'ark-symbol'), icon('sparkles', len(n.attr('fontSize')?.[0]) ? parseFloat(len(n.attr('fontSize')[0])) : 16));

// ------------------------------------------------------------------------------------------------ SButton & co.

const BUTTON_SIZES = {
  default: { h: 36, px: 16, icon: 16 }, sm: { h: 32, px: 12, icon: 16 }, lg: { h: 40, px: 24, icon: 16 },
  icon: { h: 36, px: 0, icon: 16, square: true }, 'icon-sm': { h: 32, px: 0, icon: 16, square: true },
  'icon-lg': { h: 40, px: 0, icon: 16, square: true }
};

function buttonContent(o, n, spinning) {
  const kids = [];
  const sz = BUTTON_SIZES[o.sizing] || BUTTON_SIZES.default;
  if (o.loading) {
    kids.push(h('span', { class: 'ark-spin' }, icon('loader-circle', sz.icon)));
  } else if (o.icon) {
    kids.push(icon(o.icon, sz.icon));
  }
  const text = o.loading && o.loadingText !== undefined ? o.loadingText : o.text;
  if (text !== undefined && text !== null && txt(text) !== '') {
    kids.push(h('span', { class: 'ark-btn-text' }, txt(text)));
  }
  kids.push(...n.children());
  if (o.iconRight) {
    kids.push(icon(o.iconRight, sz.icon));
  }
  return kids;
}

function SButton(n) {
  const o = n.props;
  const variant = o.variant || 'default';
  const sz = BUTTON_SIZES[o.sizing] || BUTTON_SIZES.default;
  const disabled = o.disabled || o.loading;
  const style = { height: `${sz.h}px`, padding: `0 ${sz.px}px` };
  if (sz.square) {
    style.width = `${sz.h}px`;
  }
  if (o.block) {
    style.width = '100%';
  }
  if (o.tokens && typeof o.tokens === 'object') {
    if (o.tokens.radius !== undefined) {
      style.borderRadius = len(o.tokens.radius);
    }
    if (o.tokens.background !== undefined) {
      style.background = color(o.tokens.background);
    }
    if (o.tokens.foreground !== undefined) {
      style.color = color(o.tokens.foreground);
    }
  }
  const events = disabled ? {} : n.events;
  return h('button', {
    class: ['ark-btn', `ark-btn-${variant}`, disabled && 'disabled'],
    style: [style, n.style],
    disabled: !!disabled,
    'aria-label': o.label,
    ...events
  }, buttonContent(o, n));
}

function SIcon(n) {
  const o = n.props;
  return h('span', rootProps(n, 'ark-icon-wrap', { color: color(o.color) }), icon(o.name, o.sizing ?? 16, undefined, o.strokeWidth ?? 2));
}

function SBadge(n) {
  const o = n.props;
  const v = o.variant || 'default';
  let text = txt(o.text);
  if (o.count !== undefined) {
    const c = Number(o.count);
    if (c === 0 && !o.showZero) {
      return h('span', rootProps(n, 'ark-badge-host'), n.children());
    }
    text = c > (o.max ?? 99) ? `${o.max ?? 99}+` : String(c);
  }
  const kids = [];
  if (o.dot) {
    kids.push(h('span', { class: 'ark-badge-dot', style: { background: color(o.dotColor) } }));
  }
  if (o.icon) {
    kids.push(icon(o.icon, 12));
  }
  if (text) {
    kids.push(text);
  }
  kids.push(...n.children());
  if (o.iconRight) {
    kids.push(icon(o.iconRight, 12));
  }
  if (o.removable) {
    kids.push(h('span', { class: 'ark-badge-x', onClick: (e) => { e.stopPropagation(); call(o.onRemove); } }, icon('x', 12)));
  }
  return h('span', rootProps(n, ['ark-badge', `ark-badge-${v}`, o.soft && 'soft', o.pill && 'pill', `size-${o.sizing || 'default'}`,
    o.count !== undefined && 'count']), kids);
}

// ------------------------------------------------------------------------------------------------ Card

function SCard(n) {
  const o = n.props;
  const kids = [];
  if (o.image) {
    kids.push(h('div', { class: 'ark-card-image', style: { height: len(o.imageHeight ?? 160) } }, icon('image', 24)));
  }
  kids.push(...n.children());
  return h('div', rootProps(n, ['ark-card', `ark-card-${o.variant || 'default'}`, o.sizing === 'sm' && 'sm', o.interactive && 'interactive']), kids);
}

const SCardHeader = (n) => h('div', rootProps(n, 'ark-card-header'), n.children());
const SCardTitle = (n) => h('div', rootProps(n, 'ark-card-title'), [txt(n.props.text), ...n.children()]);
const SCardDescription = (n) => h('div', rootProps(n, 'ark-card-description'), [txt(n.props.text), ...n.children()]);
const SCardAction = (n) => h('div', rootProps(n, 'ark-card-action'), n.children());
const SCardContent = (n) => h('div', rootProps(n, 'ark-card-content'), n.children());
const SCardFooter = (n) => h('div', rootProps(n, 'ark-card-footer'), n.children());

// ------------------------------------------------------------------------------------------------ Form controls

const SInput = def('SInput', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  return () => {
    const n = props.n;
    const o = n.props;
    const kids = [];
    if (o.icon) {
      kids.push(h('span', { class: 'ark-input-icon' }, icon(o.icon, 16)));
    }
    kids.push(h('input', {
      class: 'ark-input-inner',
      placeholder: txt(o.placeholder),
      value: value.value,
      disabled: o.disabled,
      maxlength: o.maxLength,
      type: o.inputType === 'password' ? 'password' : o.inputType === 'number' ? 'number' : o.inputType === 'email' ? 'email' : 'text',
      onInput: (e) => set(e.target.value),
      onKeydown: (e) => {
        if (e.key === 'Enter') {
          call(o.onSubmit, value.value);
        }
      }
    }));
    if (o.clearable && value.value) {
      kids.push(h('span', { class: 'ark-input-icon clickable', onClick: () => set('') }, icon('circle-x', 16)));
    }
    if (o.iconRight) {
      kids.push(h('span', { class: 'ark-input-icon' }, icon(o.iconRight, 16)));
    }
    if (o.showCount && o.maxLength) {
      kids.push(h('span', { class: 'ark-input-count' }, `${String(value.value || '').length}/${o.maxLength}`));
    }
    return h('label', rootProps(n, ['ark-input', `size-${o.sizing || 'default'}`, o.invalid && 'invalid', o.disabled && 'disabled']), kids);
  };
});

const STextarea = def('STextarea', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  return () => {
    const o = props.n.props;
    return h('div', rootProps(props.n, ['ark-textarea-wrap', o.invalid && 'invalid']), [
      h('textarea', {
        class: 'ark-input ark-textarea', placeholder: txt(o.placeholder), value: value.value, disabled: o.disabled,
        maxlength: o.maxLength, onInput: (e) => set(e.target.value)
      }),
      o.showCount && o.maxLength ? h('span', { class: 'ark-input-count block' }, `${String(value.value || '').length}/${o.maxLength}`) : null
    ]);
  };
});

const SLabel = (n) => h('label', rootProps(n, ['ark-label', n.props.disabled && 'disabled']), [
  txt(n.props.text), ...n.children(), n.props.required ? h('span', { class: 'ark-required' }, ' *') : null
]);

function choiceLabel(o, control, onToggle, n, cls) {
  if (o.label === undefined && o.description === undefined) {
    return h('span', rootProps(n, ['ark-choice-bare', cls]), control);
  }
  return h('label', rootProps(n, ['ark-choice', o.card && 'card', o.disabled && 'disabled', cls], {}, {
    onClick: (e) => {
      if (e.target.closest('.ark-choice-control')) {
        return;
      }
      e.preventDefault();
      onToggle();
    }
  }), [
    control,
    h('span', { class: 'ark-choice-text' }, [
      h('span', { class: 'ark-choice-label' }, txt(o.label)),
      o.description !== undefined ? h('span', { class: 'ark-choice-desc' }, txt(o.description)) : null
    ]),
    ...n.children()
  ]);
}

const SSwitch = def('SSwitch', (props) => {
  const [checked, set] = useModel(props, 'checked', 'defaultChecked', false, 'onCheckedChange');
  return () => {
    const o = props.n.props;
    const toggle = () => !o.disabled && set(!checked.value);
    const control = h('span', {
      class: ['ark-switch', 'ark-choice-control', checked.value && 'checked', o.sizing === 'sm' && 'sm', o.sizing === 'lg' && 'lg', o.disabled && 'disabled'],
      role: 'switch', 'aria-checked': String(!!checked.value), onClick: toggle
    }, h('span', { class: 'ark-switch-thumb' }));
    return choiceLabel(o, control, toggle, props.n, 'switch-row');
  };
});

const SCheckbox = def('SCheckbox', (props) => {
  const [checked, set] = useModel(props, 'checked', 'defaultChecked', false, 'onCheckedChange');
  return () => {
    const o = props.n.props;
    const toggle = () => !o.disabled && set(!checked.value);
    const on = checked.value || o.indeterminate;
    const control = h('span', {
      class: ['ark-checkbox', 'ark-choice-control', on && 'checked', o.invalid && 'invalid', o.disabled && 'disabled', o.sizing === 'sm' && 'sm', o.sizing === 'lg' && 'lg'],
      role: 'checkbox', onClick: toggle
    }, on ? icon(o.indeterminate && !checked.value ? 'minus' : 'check', 12, 'currentColor', 3) : null);
    return choiceLabel(o, control, toggle, props.n);
  };
});

const RADIO_KEY = Symbol('radio');

const SRadioGroup = def('SRadioGroup', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  provide(RADIO_KEY, { value, set, disabled: () => props.n.props.disabled });
  return () => h('div', rootProps(props.n, ['ark-radio-group', props.n.props.orientation === 'horizontal' && 'horizontal'], {}, { role: 'radiogroup' }),
    props.n.children());
});

const SRadioGroupItem = def('SRadioGroupItem', (props) => {
  const g = inject(RADIO_KEY, null);
  return () => {
    const o = props.n.props;
    const on = g ? g.value.value === o.value : false;
    const disabled = o.disabled || (g && g.disabled());
    const pick = () => !disabled && g && g.set(o.value);
    const control = h('span', {
      class: ['ark-radio', 'ark-choice-control', on && 'checked', disabled && 'disabled', o.invalid && 'invalid'], onClick: pick
    }, on ? h('span', { class: 'ark-radio-dot' }) : null);
    return choiceLabel({ ...o, disabled }, control, pick, props.n);
  };
});

const SSlider = def('SSlider', (props) => {
  const range = props.n.props.values !== undefined || props.n.props.defaultValues?.length > 0;
  const [value, set] = range ?
    useModel(props, 'values', 'defaultValues', [], 'onValuesChange') :
    useModel(props, 'value', 'defaultValue', 0, 'onValueChange');
  return () => {
    const o = props.n.props;
    const min = o.min ?? 0;
    const max = o.max ?? 100;
    const vertical = o.orientation === 'vertical';
    const pct = (v) => ((Number(v) - min) / (max - min || 1)) * 100;
    const vals = range ? value.value : [value.value];
    const lo = range ? Math.min(...vals) : min;
    const hi = range ? Math.max(...vals) : vals[0];
    const length = len(o.length ?? 160);
    const onPointer = (e) => {
      if (o.disabled) {
        return;
      }
      const track = e.currentTarget;
      const move = (ev) => {
        const r = track.getBoundingClientRect();
        let t = vertical ? 1 - (ev.clientY - r.top) / r.height : (ev.clientX - r.left) / r.width;
        t = Math.max(0, Math.min(1, t));
        const step = o.step || 1;
        const v = Math.round((min + t * (max - min)) / step) * step;
        if (range) {
          const arr = [...vals];
          const k = Math.abs(arr[0] - v) <= Math.abs(arr[arr.length - 1] - v) ? 0 : arr.length - 1;
          arr[k] = v;
          set(arr.sort((a, b) => a - b));
        } else {
          set(v);
        }
      };
      move(e);
      const up = () => {
        window.removeEventListener('pointermove', move);
        window.removeEventListener('pointerup', up);
      };
      window.addEventListener('pointermove', move);
      window.addEventListener('pointerup', up);
    };
    const fill = vertical ? { bottom: `${pct(lo)}%`, height: `${pct(hi) - pct(lo)}%` } : { left: `${pct(lo)}%`, width: `${pct(hi) - pct(lo)}%` };
    return h('div', rootProps(props.n, ['ark-slider', vertical && 'vertical', o.disabled && 'disabled'],
      vertical ? { height: length } : { width: o.length !== undefined ? length : (props.n.style.width ? undefined : length) }), [
      h('div', { class: 'ark-slider-track', onPointerdown: onPointer }, [
        h('div', { class: 'ark-slider-range', style: fill }),
        ...vals.map((v) => h('span', { class: 'ark-slider-thumb', style: vertical ? { bottom: `${pct(v)}%` } : { left: `${pct(v)}%` } }))
      ])
    ]);
  };
});

function SProgress(n) {
  const o = n.props;
  const max = o.max || 100;
  const p = Math.max(0, Math.min(100, (Number(o.value) / max) * 100));
  const tone = o.tone && o.tone !== 'default' ? `var(--${o.tone})` : undefined;
  if (o.shape === 'circle' || o.shape === 'gauge') {
    const d = o.diameter ?? (o.sizing === 'sm' ? 32 : o.sizing === 'lg' ? 64 : 48);
    const th = o.thickness ?? Math.max(3, d / 10);
    const r = (d - th) / 2;
    const c = 2 * Math.PI * r;
    const frac = o.shape === 'gauge' ? 0.75 : 1;
    return h('div', rootProps(n, 'ark-progress-ring', { width: `${d}px`, height: `${d}px` }), [
      h('svg', { width: d, height: d, viewBox: `0 0 ${d} ${d}`, style: { transform: o.shape === 'gauge' ? 'rotate(135deg)' : 'rotate(-90deg)' } }, [
        h('circle', { cx: d / 2, cy: d / 2, r, fill: 'none', stroke: 'var(--muted)', 'stroke-width': th, 'stroke-dasharray': `${c * frac} ${c}`, 'stroke-linecap': 'round' }),
        h('circle', { cx: d / 2, cy: d / 2, r, fill: 'none', stroke: tone || 'var(--primary)', 'stroke-width': th, 'stroke-dasharray': `${(c * frac * p) / 100} ${c}`, 'stroke-linecap': 'round' })
      ]),
      o.showValue ? h('span', { class: 'ark-progress-value' }, o.valueText ?? `${Math.round(p)}%`) : null
    ]);
  }
  const height = o.thickness ?? (o.sizing === 'sm' ? 4 : o.sizing === 'lg' ? 12 : 8);
  const bar = h('div', { class: 'ark-progress', style: { height: `${height}px` } }, [
    o.buffer !== undefined ? h('div', { class: 'ark-progress-buffer', style: { width: `${(o.buffer / max) * 100}%` } }) : null,
    h('div', { class: ['ark-progress-bar', o.indeterminate && 'indeterminate', o.striped && 'striped'], style: { width: o.indeterminate ? '40%' : `${p}%`, background: tone } })
  ]);
  if (o.label === undefined && !o.showValue && o.caption === undefined) {
    return h('div', rootProps(n, 'ark-progress-wrap'), bar);
  }
  return h('div', rootProps(n, 'ark-progress-wrap labeled'), [
    h('div', { class: 'ark-progress-head' }, [h('span', txt(o.label)), o.showValue ? h('span', { class: 'muted' }, o.valueText ?? `${Math.round(p)}%`) : null]),
    bar,
    o.caption !== undefined ? h('div', { class: 'ark-progress-caption' }, txt(o.caption)) : null
  ]);
}

// ------------------------------------------------------------------------------------------------ Tabs / Accordion / Collapsible

const TABS_KEY = Symbol('tabs');

const STabs = def('STabs', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  provide(TABS_KEY, { value, set });
  return () => h('div', rootProps(props.n, 'ark-tabs'), props.n.children());
});

const STabsList = (n) => h('div', rootProps(n, 'ark-tabs-list', {}, { role: 'tablist' }), n.children());

const STabsTrigger = def('STabsTrigger', (props) => {
  const t = inject(TABS_KEY, null);
  if (t && !t.value.value && props.n.props.value) {
    t.value.value = props.n.props.value;
  }
  return () => {
    const o = props.n.props;
    const active = t && t.value.value === o.value;
    return h('button', rootProps(props.n, ['ark-tabs-trigger', active && 'active'], {}, {
      role: 'tab', disabled: o.disabled, onClick: () => !o.disabled && t && t.set(o.value)
    }), [o.icon ? icon(o.icon, 16) : null, txt(o.text), ...props.n.children()]);
  };
});

const STabsContent = def('STabsContent', (props) => {
  const t = inject(TABS_KEY, null);
  return () => (t && t.value.value === props.n.props.value ?
    h('div', rootProps(props.n, 'ark-tabs-content'), props.n.children()) : null);
});

const ACC_KEY = Symbol('accordion');
const ACC_ITEM_KEY = Symbol('accordion-item');

const SAccordion = def('SAccordion', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', [], 'onValueChange');
  const toggle = (v) => {
    const cur = Array.isArray(value.value) ? value.value : [value.value].filter(Boolean);
    const open = cur.includes(v);
    if (props.n.props.type === 'multiple') {
      set(open ? cur.filter((x) => x !== v) : [...cur, v]);
    } else if (open) {
      if (props.n.props.collapsible) {
        set([]);
      }
    } else {
      set([v]);
    }
  };
  provide(ACC_KEY, { isOpen: (v) => (Array.isArray(value.value) ? value.value : [value.value]).includes(v), toggle });
  return () => h('div', rootProps(props.n, 'ark-accordion'), props.n.children());
});

const SAccordionItem = def('SAccordionItem', (props) => {
  const acc = inject(ACC_KEY, null);
  provide(ACC_ITEM_KEY, {
    open: () => acc && acc.isOpen(props.n.props.value),
    toggle: () => !props.n.props.disabled && acc && acc.toggle(props.n.props.value),
    disabled: () => props.n.props.disabled
  });
  return () => h('div', rootProps(props.n, ['ark-accordion-item', props.n.props.disabled && 'disabled']), props.n.children());
});

const SAccordionTrigger = def('SAccordionTrigger', (props) => {
  const item = inject(ACC_ITEM_KEY, null);
  return () => h('button', rootProps(props.n, ['ark-accordion-trigger', item?.open() && 'open'], {}, { onClick: () => item?.toggle() }), [
    h('span', { class: 'ark-accordion-title' }, [txt(props.n.props.text), ...props.n.children()]),
    h('span', { class: 'ark-chevron' }, icon('chevron-down', 16))
  ]);
});

const SAccordionContent = def('SAccordionContent', (props) => {
  const item = inject(ACC_ITEM_KEY, null);
  return () => h('div', { class: ['ark-collapse', item?.open() && 'open'] },
    h('div', { class: 'ark-collapse-inner' }, h('div', rootProps(props.n, 'ark-accordion-content'), props.n.children())));
});

const COLL_KEY = Symbol('collapsible');

const SCollapsible = def('SCollapsible', (props) => {
  const [open, set] = useModel(props, 'open', 'defaultOpen', false, 'onOpenChange');
  provide(COLL_KEY, { open, toggle: () => !props.n.props.disabled && set(!open.value) });
  return () => h('div', rootProps(props.n, 'ark-collapsible'), props.n.children());
});

const SCollapsibleTrigger = def('SCollapsibleTrigger', (props) => {
  const c = inject(COLL_KEY, null);
  return () => h('div', rootProps(props.n, 'ark-collapsible-trigger', {}, { onClick: () => c?.toggle() }), props.n.children());
});

const SCollapsibleContent = def('SCollapsibleContent', (props) => {
  const c = inject(COLL_KEY, null);
  return () => h('div', { class: ['ark-collapse', c?.open.value && 'open'] },
    h('div', { class: 'ark-collapse-inner' }, h('div', rootProps(props.n, 'ark-collapsible-content'), props.n.children())));
});

// ------------------------------------------------------------------------------------------------ Toggle / ToggleGroup / ButtonGroup

const SToggle = def('SToggle', (props) => {
  const [pressed, set] = useModel(props, 'pressed', 'defaultPressed', false, 'onPressedChange');
  return () => {
    const o = props.n.props;
    return h('button', rootProps(props.n, ['ark-toggle', `ark-toggle-${o.variant || 'default'}`, `size-${o.sizing || 'default'}`, pressed.value && 'on'], {}, {
      disabled: o.disabled, 'aria-pressed': String(!!pressed.value), onClick: () => set(!pressed.value)
    }), [o.icon ? icon(o.icon, 16) : null, o.text !== undefined ? txt(o.text) : null, ...props.n.children()]);
  };
});

const TG_KEY = Symbol('toggle-group');

const SToggleGroup = def('SToggleGroup', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', [], 'onValueChange');
  provide(TG_KEY, {
    has: (v) => (value.value || []).includes(v),
    toggle: (v) => {
      const o = props.n.props;
      const cur = value.value || [];
      if (o.type === 'multiple') {
        set(cur.includes(v) ? cur.filter((x) => x !== v) : [...cur, v]);
      } else if (cur.includes(v)) {
        if (o.deselectable !== false) {
          set([]);
        }
      } else {
        set([v]);
      }
    },
    variant: () => props.n.props.variant || 'default',
    sizing: () => props.n.props.sizing || 'default',
    joined: () => !props.n.props.spacing
  });
  return () => {
    const o = props.n.props;
    return h('div', rootProps(props.n, ['ark-toggle-group', !o.spacing && 'joined', `ark-toggle-group-${o.variant || 'default'}`],
      { gap: o.spacing ? `${o.spacing}px` : undefined, flexWrap: o.wrap ? 'wrap' : undefined }), props.n.children());
  };
});

const SToggleGroupItem = def('SToggleGroupItem', (props) => {
  const g = inject(TG_KEY, null);
  return () => {
    const o = props.n.props;
    const on = g?.has(o.value);
    return h('button', rootProps(props.n, ['ark-toggle', `ark-toggle-${g?.variant() || 'default'}`, `size-${g?.sizing() || 'default'}`, on && 'on'], {}, {
      disabled: o.disabled, onClick: () => g?.toggle(o.value)
    }), [o.icon ? icon(o.icon, 16) : null, o.text !== undefined ? txt(o.text) : null, ...props.n.children()]);
  };
});

const SButtonGroup = (n) => h('div', rootProps(n, ['ark-button-group', n.props.orientation === 'vertical' && 'vertical']), n.children());
const SButtonGroupSeparator = (n) => h('div', rootProps(n, 'ark-button-group-sep'));

// ------------------------------------------------------------------------------------------------ Display

const ALERT_ICONS = { default: 'info', destructive: 'circle-alert', success: 'circle-check', warning: 'triangle-alert', info: 'info' };

const SAlert = def('SAlert', (props) => {
  const dismissed = ref(false);
  return () => {
    if (dismissed.value) {
      return null;
    }
    const n = props.n;
    const o = n.props;
    const v = o.variant || 'default';
    const kids = [];
    const ic = o.icon ?? (o.heading !== undefined || o.description !== undefined ? ALERT_ICONS[v] : undefined);
    if (ic) {
      kids.push(h('span', { class: 'ark-alert-icon' }, icon(ic, 16)));
    }
    const body = [];
    if (o.heading !== undefined) {
      body.push(h('div', { class: 'ark-alert-title' }, txt(o.heading)));
    }
    if (o.description !== undefined) {
      body.push(h('div', { class: 'ark-alert-description' }, txt(o.description)));
    }
    body.push(...n.children());
    kids.push(h('div', { class: 'ark-alert-body' }, body));
    if (o.actionLabel !== undefined) {
      kids.push(h('button', { class: 'ark-btn ark-btn-outline ark-alert-action', style: { height: '28px', padding: '0 10px' }, onClick: () => call(o.onAction) }, txt(o.actionLabel)));
    }
    if (o.dismissible) {
      kids.push(h('button', { class: 'ark-alert-x', onClick: () => { dismissed.value = true; call(o.onDismiss); } }, icon('x', 14)));
    }
    return h('div', rootProps(n, ['ark-alert', `ark-alert-${v}`, o.soft && 'soft', o.compact && 'compact'], {}, { role: 'alert' }), kids);
  };
});

const SAlertTitle = (n) => h('div', rootProps(n, 'ark-alert-title'), [txt(n.props.text), ...n.children()]);
const SAlertDescription = (n) => h('div', rootProps(n, 'ark-alert-description'), [txt(n.props.text), ...n.children()]);

const AVATAR_SIZES = { xs: 24, sm: 28, default: 32, md: 40, lg: 48, xl: 64 };

function avatarSize(s) {
  return typeof s === 'number' ? s : AVATAR_SIZES[s] ?? 32;
}

function avatar(o, size, extraCls, style) {
  const s = avatarSize(size ?? o.sizing);
  const shape = o.shape || 'circle';
  const radius = shape === 'circle' ? '50%' : shape === 'rounded' ? `${Math.round(s / 4)}px` : '4px';
  const src = typeof o.src === 'string' && /^(https?:|data:)/.test(o.src) ? o.src : undefined;
  return h('span', { class: ['ark-avatar', o.ring && 'ring', extraCls], style: [{ width: `${s}px`, height: `${s}px`, borderRadius: radius, fontSize: `${Math.max(10, s * 0.38)}px` }, style] }, [
    src ? h('img', { src, alt: '' }) : txt(o.fallback),
    o.status ? h('span', { class: ['ark-avatar-status', o.status] }) : null
  ]);
}

const SAvatar = (n) => h('span', rootProps(n, 'ark-avatar-host'), [avatar(n.props), ...n.children()]);

function SAvatarGroup(n) {
  const o = n.props;
  const fb = o.fallbacks || [];
  const max = o.max || fb.length;
  const shown = fb.slice(0, max);
  const extra = (fb.length - shown.length) + (o.extra || 0);
  const s = avatarSize(o.sizing);
  const overlap = o.overlap ?? Math.round(s / 4);
  const kids = shown.map((f, i) => avatar({ fallback: f, src: (o.sources || [])[i], shape: o.shape, ring: true }, s, null, { marginLeft: i ? `${-overlap}px` : 0 }));
  if (extra > 0) {
    kids.push(avatar({ fallback: `+${extra}`, shape: o.shape, ring: true }, s, 'extra', { marginLeft: `${-overlap}px` }));
  }
  return h('span', rootProps(n, 'ark-avatar-group'), kids);
}

function SSeparator(n) {
  const o = n.props;
  const vertical = o.orientation === 'vertical';
  const style = vertical ? { height: len(o.length === '100%' ? undefined : o.length) } : {};
  const line = (extra) => h('div', {
    class: ['ark-separator', vertical && 'vertical', o.lineStyle && o.lineStyle !== 'solid' && o.lineStyle],
    style: { ...(vertical ? { width: `${o.thickness ?? 1}px` } : { height: `${o.thickness ?? 1}px` }), ...extra }
  });
  if (o.label !== undefined && !vertical) {
    const a = o.labelAlignment || 'center';
    return h('div', rootProps(n, 'ark-separator-labeled'), [
      line({ flex: a === 'start' ? '0 0 16px' : '1' }),
      h('span', { class: 'ark-separator-label' }, txt(o.label)),
      line({ flex: a === 'end' ? '0 0 16px' : '1' })
    ]);
  }
  return h('div', rootProps(n, ['ark-separator-host', vertical && 'vertical'], style), line(vertical ? { height: '100%' } : {}));
}

function SSkeleton(n) {
  const o = n.props;
  const cls = ['ark-skeleton', o.motion === 'shimmer' ? 'shimmer' : o.motion === 'none' ? '' : 'pulse'];
  if (o.preset || o.lines) {
    const rows = [];
    if (o.preset === 'card') {
      rows.push(h('div', { class: cls, style: { height: '120px', width: '100%' } }));
    }
    if (o.preset === 'list') {
      for (let i = 0; i < 3; i++) {
        rows.push(h('div', { class: 'ark-row', style: { gap: '12px', width: '100%' } }, [
          h('div', { class: cls, style: { width: '40px', height: '40px', borderRadius: '50%' } }),
          h('div', { class: 'ark-col', style: { gap: '6px', flex: 1, alignItems: 'stretch' } }, [
            h('div', { class: cls, style: { height: '12px', width: '70%' } }), h('div', { class: cls, style: { height: '12px', width: '45%' } })
          ])
        ]));
      }
    } else {
      const lines = o.lines || 3;
      for (let i = 0; i < lines; i++) {
        rows.push(h('div', { class: cls, style: { height: '14px', width: i === lines - 1 && lines > 1 ? '60%' : '100%' } }));
      }
    }
    return h('div', rootProps(n, 'ark-skeleton-stack', { width: len(o.boxWidth) || '100%' }), rows);
  }
  const style = { width: len(o.boxWidth) || '100%', height: len(o.boxHeight) || '16px' };
  if (o.circle) {
    style.borderRadius = '50%';
  }
  return h('div', rootProps(n, cls, style));
}

const SSpinner = (n) => h('span', rootProps(n, 'ark-spin', { color: color(n.props.color), width: `${n.props.sizing ?? 16}px`, height: `${n.props.sizing ?? 16}px` }, { role: 'status', 'aria-label': n.props.label }),
  icon('loader-circle', n.props.sizing ?? 16));

function kbd(text, ic, o) {
  return h('kbd', { class: ['ark-kbd', `size-${o.sizing || 'default'}`, o.variant === 'outline' && 'outline'] }, [ic ? icon(ic, 12) : null, txt(text)]);
}

const SKbd = (n) => h('span', rootProps(n, 'ark-kbd-host'), [kbd(n.props.text, n.props.icon, n.props), ...n.children()]);

function SKbdGroup(n) {
  const o = n.props;
  const keys = o.keys || [];
  const kids = [];
  keys.forEach((k, i) => {
    if (i > 0 && o.separator) {
      kids.push(h('span', { class: 'ark-kbd-sep' }, o.separator));
    }
    kids.push(kbd(k, undefined, o));
  });
  kids.push(...n.children());
  return h('span', rootProps(n, 'ark-kbd-group'), kids);
}

function typo(cls, tag = 'div') {
  return (n) => h(tag, rootProps(n, cls), [txt(n.props.text), ...n.children()]);
}

function SList(n) {
  const items = n.props.items || [];
  return h('ul', rootProps(n, 'ark-typo-list'), [...items.map((t) => h('li', txt(t))), ...n.children()]);
}

// Empty
function SEmpty(n) {
  const o = n.props;
  return h('div', rootProps(n, ['ark-empty', o.bordered && 'bordered', o.filled && 'filled', o.compact && 'compact']), n.children());
}
const SEmptyHeader = (n) => h('div', rootProps(n, 'ark-empty-header'), n.children());
const SEmptyMedia = (n) => h('div', rootProps(n, ['ark-empty-media', n.props.variant === 'icon' && 'icon']), [n.props.icon ? icon(n.props.icon, n.props.variant === 'icon' ? 24 : 32) : null, ...n.children()]);
const SEmptyTitle = typo('ark-empty-title');
const SEmptyDescription = typo('ark-empty-description');
const SEmptyContent = (n) => h('div', rootProps(n, 'ark-empty-content'), n.children());

// Item
function SItemGroup(n) {
  const o = n.props;
  return h('div', rootProps(n, ['ark-item-group', o.bordered && 'bordered', o.separators && 'separators'], { gap: o.spacing ? `${o.spacing}px` : undefined }), n.children());
}
const SItem = (n) => h('div', rootProps(n, ['ark-item', `ark-item-${n.props.variant || 'default'}`, n.props.sizing === 'sm' && 'sm', n.props.interactive && 'interactive']), n.children());
const SItemSeparator = (n) => h('div', rootProps(n, 'ark-separator'));
function SItemMedia(n) {
  const o = n.props;
  if (o.variant === 'image') {
    return h('div', rootProps(n, 'ark-item-media image'), icon('image', 18));
  }
  return h('div', rootProps(n, ['ark-item-media', o.variant === 'icon' && 'icon'], { color: color(o.tint) }), [o.icon ? icon(o.icon, 16) : null, ...n.children()]);
}
const SItemContent = (n) => h('div', rootProps(n, 'ark-item-content'), n.children());
const SItemTitle = typo('ark-item-title');
const SItemDescription = typo('ark-item-description');
const SItemActions = (n) => h('div', rootProps(n, 'ark-item-actions'), n.children());

// Breadcrumb
const SBreadcrumb = (n) => h('nav', rootProps(n, 'ark-breadcrumb'), n.children());
const SBreadcrumbList = (n) => h('ol', rootProps(n, 'ark-breadcrumb-list'), n.children());
const SBreadcrumbItem = (n) => h('li', rootProps(n, 'ark-breadcrumb-item'), n.children());
const SBreadcrumbLink = (n) => h('a', rootProps(n, 'ark-breadcrumb-link'), [n.props.icon ? icon(n.props.icon, 14) : null, txt(n.props.text), ...n.children()]);
const SBreadcrumbPage = (n) => h('span', rootProps(n, 'ark-breadcrumb-page'), [txt(n.props.text), ...n.children()]);
const SBreadcrumbSeparator = (n) => h('li', rootProps(n, 'ark-breadcrumb-sep'), n.hasChildren ? n.children() : icon(n.props.icon || 'chevron-right', 14));
const SBreadcrumbEllipsis = (n) => h('span', rootProps(n, 'ark-breadcrumb-ellipsis'), icon('ellipsis', 16));

// Pagination
const SPagination = def('SPagination', (props) => {
  const [page, set] = useModel(props, 'page', 'defaultPage', 1, 'onPageChange');
  return () => {
    const o = props.n.props;
    const total = Math.max(1, o.total || 1);
    const sib = o.siblingCount ?? 1;
    const cur = page.value;
    const items = [];
    const start = Math.max(2, cur - sib);
    const end = Math.min(total - 1, cur + sib);
    items.push(1);
    if (start > 2) {
      items.push('…');
    }
    for (let i = start; i <= end; i++) {
      items.push(i);
    }
    if (end < total - 1) {
      items.push('…');
    }
    if (total > 1) {
      items.push(total);
    }
    return h('nav', rootProps(props.n, 'ark-pagination'), [
      h('button', { class: 'ark-btn ark-btn-ghost', style: { height: '36px', padding: '0 10px' }, disabled: cur <= 1, onClick: () => set(cur - 1) }, [icon('chevron-left', 16), txt(o.previousText ?? 'Previous')]),
      ...items.map((p) => (p === '…' ? h('span', { class: 'ark-pagination-ellipsis' }, icon('ellipsis', 16)) :
        h('button', { class: ['ark-btn', p === cur ? 'ark-btn-outline' : 'ark-btn-ghost'], style: { width: '36px', height: '36px', padding: 0 }, onClick: () => set(p) }, String(p)))),
      h('button', { class: 'ark-btn ark-btn-ghost', style: { height: '36px', padding: '0 10px' }, disabled: cur >= total, onClick: () => set(cur + 1) }, [txt(o.nextText ?? 'Next'), icon('chevron-right', 16)])
    ]);
  };
});

// Field
function SField(n) {
  const o = n.props;
  return h('div', rootProps(n, ['ark-field', o.orientation === 'horizontal' && 'horizontal', o.invalid && 'invalid', o.disabled && 'disabled']), n.children());
}
const SFieldLabel = (n) => h('label', rootProps(n, 'ark-label'), [txt(n.props.text), ...n.children(), n.props.required ? h('span', { class: 'ark-required' }, ' *') : null]);
const SFieldContent = (n) => h('div', rootProps(n, 'ark-field-content'), n.children());
const SFieldDescription = typo('ark-field-description');
const SFieldError = typo('ark-field-error');
const SFieldGroup = (n) => h('div', rootProps(n, 'ark-field-group'), n.children());
const SFieldSet = (n) => h('fieldset', rootProps(n, 'ark-field-set'), n.children());
const SFieldLegend = (n) => h('legend', rootProps(n, ['ark-field-legend', n.props.variant === 'label' && 'label']), [txt(n.props.text), ...n.children()]);
const SFieldSeparator = (n) => h('div', rootProps(n, 'ark-separator'));

// Layout primitives (breakpoint-free): CSS grid / flex do the same job on the web
const SPage = (n) => h('div', rootProps(n, 'ark-page', { maxWidth: len(n.props.maxWidth ?? 1200), gap: len(n.props.gap ?? 24) }), [
  n.props.title !== undefined ? h('div', { class: 'ark-page-title' }, txt(n.props.title)) : null,
  n.props.description !== undefined ? h('div', { class: 'ark-page-description' }, txt(n.props.description)) : null,
  ...n.children()
]);
const SStack = (n) => h('div', rootProps(n, 'ark-col', { gap: len(n.props.gap ?? 16), alignItems: flexAlign(n.props.alignment) || 'stretch', width: '100%' }), n.children());
const SRow = (n) => h('div', rootProps(n, 'ark-row', { gap: len(n.props.gap ?? 8), justifyContent: flexAlign(n.props.justify) || 'flex-start', width: '100%' }), n.children());
const SFlow = (n) => h('div', rootProps(n, 'ark-row', { gap: len(n.props.gap ?? 8), flexWrap: 'wrap', justifyContent: flexAlign(n.props.justify) || 'flex-start', width: '100%' }), n.children());
function SGrid(n) {
  const o = n.props;
  const min = o.minItemWidth ?? 280;
  const cols = o.maxColumns ? `repeat(auto-fill, minmax(max(${min}px, calc((100% - ${(o.maxColumns - 1) * (o.gap ?? 16)}px) / ${o.maxColumns})), 1fr))` :
    `repeat(auto-fill, minmax(min(${min}px, 100%), 1fr))`;
  return h('div', rootProps(n, 'ark-sgrid', { gridTemplateColumns: cols, gap: len(o.gap ?? 16) }), n.children());
}
const SGridItem = (n) => h('div', rootProps(n, 'ark-sgrid-item', { gridColumn: n.props.full ? '1 / -1' : n.props.span > 1 ? `span ${n.props.span}` : undefined }), n.children());
const SColumns = (n) => h('div', rootProps(n, 'ark-columns', { gap: len(n.props.gap ?? 24), '--min-col': len(n.props.minColumnWidth ?? 280) }), n.children());
const SColumn = (n) => h('div', rootProps(n, 'ark-column', { flex: `${n.props.weight ?? 1} 1 var(--min-col, 280px)` }), n.children());

// Table (composition API)
const STable = (n) => h('div', rootProps(n, 'ark-table-wrap'), h('table', { class: 'ark-table' }, n.children()));
const STableCaption = (n) => h('caption', rootProps(n, 'ark-table-caption'), [txt(n.props.text), ...n.children()]);
const STableHeader = (n) => h('thead', rootProps(n), n.children());
const STableBody = (n) => h('tbody', rootProps(n), n.children());
const STableFooter = (n) => h('tfoot', rootProps(n), n.children());
const STableRow = (n) => h('tr', rootProps(n, n.props.selected && 'selected'), n.children());
const STableHead = (n) => h('th', rootProps(n), [txt(n.props.text), ...n.children()]);
const STableCell = (n) => h('td', rootProps(n), [txt(n.props.text), ...n.children()]);

const SAspectRatio = (n) => h('div', rootProps(n, 'ark-aspect', { aspectRatio: String(n.props.ratio ?? 1) }), n.children());
const SScrollArea = (n) => h('div', rootProps(n, ['ark-scroll-area', n.props.bordered && 'bordered', n.props.orientation === 'horizontal' && 'horizontal'],
  { maxHeight: len(n.props.maxScrollHeight) }), n.children());

const SNumberField = def('SNumberField', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', 0, 'onValueChange');
  return () => {
    const o = props.n.props;
    const step = o.step ?? 1;
    const clamp = (v) => Math.min(o.max ?? Infinity, Math.max(o.min ?? -Infinity, v));
    const fmtv = (v) => (o.decimals !== undefined ? Number(v).toFixed(o.decimals) : String(Math.round(v * 1e6) / 1e6));
    return h('div', rootProps(props.n, ['ark-input', 'ark-number', o.invalid && 'invalid', o.disabled && 'disabled']), [
      h('button', { class: 'ark-number-btn', disabled: o.disabled || (o.min !== undefined && value.value <= o.min), onClick: () => set(clamp(value.value - step)) }, icon('minus', 14)),
      h('input', { class: 'ark-input-inner center', value: fmtv(value.value), onChange: (e) => set(clamp(Number(e.target.value) || 0)) }),
      h('button', { class: 'ark-number-btn', disabled: o.disabled || (o.max !== undefined && value.value >= o.max), onClick: () => set(clamp(value.value + step)) }, icon('plus', 14))
    ]);
  };
});

const SPinInput = def('SPinInput', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  return () => {
    const o = props.n.props;
    const n = o.length ?? 6;
    const groups = o.groups || [n];
    const v = String(value.value || '');
    const kids = [];
    let k = 0;
    groups.forEach((g, gi) => {
      if (gi > 0) {
        kids.push(h('span', { class: 'ark-pin-sep' }, icon('minus', 14)));
      }
      const slots = [];
      for (let i = 0; i < g; i++, k++) {
        const ch = v[k];
        slots.push(h('span', { class: ['ark-pin-slot', k === v.length && 'active', o.invalid && 'invalid'] }, ch ? (o.masked ? '•' : ch) : ''));
      }
      kids.push(h('span', { class: 'ark-pin-group' }, slots));
    });
    return h('label', rootProps(props.n, 'ark-pin'), [
      ...kids,
      h('input', {
        class: 'ark-pin-input', value: v, maxlength: n, inputmode: o.pattern === 'alphanumeric' ? 'text' : 'numeric', disabled: o.disabled,
        onInput: (e) => {
          const clean = e.target.value.replace(o.pattern === 'alphanumeric' ? /[^0-9a-z]/gi : /\D/g, '').slice(0, n);
          e.target.value = clean;
          set(clean);
          if (clean.length === n) {
            call(o.onComplete, clean);
          }
        }
      })
    ]);
  };
});

const STagsInput = def('STagsInput', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', [], 'onValueChange');
  const draft = ref('');
  return () => {
    const o = props.n.props;
    const tags = value.value || [];
    const add = () => {
      const parts = draft.value.split(o.delimiter || ',').map((s) => s.trim()).filter(Boolean);
      let next = [...tags];
      for (const p of parts) {
        if ((o.allowDuplicates || !next.includes(p)) && (!o.max || next.length < o.max)) {
          next.push(p);
        }
      }
      draft.value = '';
      set(next);
    };
    return h('div', rootProps(props.n, ['ark-input', 'ark-tags', o.invalid && 'invalid', o.disabled && 'disabled']), [
      ...tags.map((t, i) => h('span', { class: 'ark-badge ark-badge-secondary' }, [t, h('span', { class: 'ark-badge-x', onClick: () => set(tags.filter((_, j) => j !== i)) }, icon('x', 12))])),
      h('input', {
        class: 'ark-input-inner', placeholder: tags.length ? '' : txt(o.placeholder), value: draft.value,
        onInput: (e) => {
          draft.value = e.target.value;
          if (draft.value.includes(o.delimiter || ',')) {
            add();
          }
        },
        onKeydown: (e) => {
          if (e.key === 'Enter') {
            add();
          } else if (e.key === 'Backspace' && !draft.value && tags.length) {
            set(tags.slice(0, -1));
          }
        }
      })
    ]);
  };
});

// Input group
const SInputGroup = (n) => h('div', rootProps(n, ['ark-input', 'ark-input-group', n.props.invalid && 'invalid']), n.children());
function SInputGroupAddon(n) {
  const a = n.props.alignment || 'inline-start';
  return h('div', rootProps(n, ['ark-input-addon', a]), n.children());
}
const SInputGroupText = (n) => h('span', rootProps(n, 'ark-input-addon-text'), [n.props.icon ? icon(n.props.icon, 16) : null, txt(n.props.text), ...n.children()]);
const SInputGroupButton = (n) => SButton({ ...n, props: { variant: 'ghost', ...n.props, sizing: { xs: 'sm', sm: 'sm', 'icon-xs': 'icon-sm', 'icon-sm': 'icon-sm' }[n.props.sizing || 'xs'] }, style: { height: '24px', ...n.style } });
const SInputGroupInput = def('SInputGroupInput', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  return () => h('input', rootProps(props.n, 'ark-input-inner grow', {}, {
    placeholder: txt(props.n.props.placeholder), value: value.value, type: props.n.props.inputType === 'password' ? 'password' : 'text',
    onInput: (e) => set(e.target.value)
  }));
});

// Stepper
const STEP_KEY = Symbol('stepper');
const SStepper = def('SStepper', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', 1, 'onValueChange');
  provide(STEP_KEY, { value, set, linear: () => props.n.props.linear !== false });
  return () => h('div', rootProps(props.n, ['ark-stepper', props.n.props.orientation === 'vertical' && 'vertical']), props.n.children());
});
const SStepperItem = def('SStepperItem', (props) => {
  const s = inject(STEP_KEY, null);
  return () => {
    const o = props.n.props;
    const cur = s ? s.value.value : 1;
    const state = o.step < cur ? 'completed' : o.step === cur ? 'active' : 'inactive';
    return h('div', rootProps(props.n, ['ark-step', state], {}, { onClick: () => !o.disabled && s && (!s.linear() || o.step <= cur + 1) && s.set(o.step) }), [
      h('span', { class: 'ark-step-dot' }, state === 'completed' ? icon('check', 14) : o.icon ? icon(o.icon, 14) : String(o.step)),
      h('span', { class: 'ark-step-text' }, [
        h('span', { class: 'ark-step-title' }, txt(o.title)),
        o.description !== undefined ? h('span', { class: 'ark-step-desc' }, txt(o.description)) : null
      ]),
      h('span', { class: 'ark-step-line' })
    ]);
  };
});

function SCodeBlock(n) {
  const o = n.props;
  return h('div', rootProps(n, 'ark-codeblock'), [
    o.title ? h('div', { class: 'ark-codeblock-title' }, txt(o.title)) : null,
    h('pre', h('code', txt(o.code)))
  ]);
}

function SSparkline(n) {
  const o = n.props;
  const vals = (o.values || []).map(Number);
  const w = parseFloat(n.style.width) || 120;
  const hh = o.chartHeight ?? 32;
  if (vals.length < 2) {
    return h('div', rootProps(n, 'ark-sparkline', { width: `${w}px`, height: `${hh}px` }));
  }
  const min = Math.min(...vals);
  const max = Math.max(...vals);
  const pts = vals.map((v, i) => [(i / (vals.length - 1)) * w, hh - 2 - ((v - min) / (max - min || 1)) * (hh - 4)]);
  const d = pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const c = String(o.color || 'chart-1').startsWith('var(') ? o.color : `var(--${o.color || 'chart-1'})`;
  return h('svg', rootProps(n, 'ark-sparkline', { width: `${w}px`, height: `${hh}px` }, { viewBox: `0 0 ${w} ${hh}` }), [
    o.filled !== false ? h('path', { d: `${d} L${w} ${hh} L0 ${hh} Z`, fill: c, opacity: 0.15 }) : null,
    h('path', { d, fill: 'none', stroke: c, 'stroke-width': o.lineWidth ?? 1.5 })
  ]);
}

// ------------------------------------------------------------------------------------------------ Overlays

const OVERLAY_KEY = Symbol('overlay');
const THEME_KEY = 'arkThemeClass';

/** Root of any overlay family: holds `open`, closes on outside click / Escape. */
function overlayRoot(name, kind, { openKey = 'open', defaultKey = 'defaultOpen' } = {}) {
  return def(name, (props) => {
    const [open, set] = useModel(props, openKey, defaultKey, false, 'onOpenChange');
    const el = ref(null);
    const pos = reactive({ x: 0, y: 0 });
    const api = { open, set, kind, el, pos, name };
    provide(OVERLAY_KEY, api);
    const onDoc = (e) => {
      if (!open.value || kind === 'modal') {
        return;
      }
      if (el.value && !el.value.contains(e.target)) {
        set(false);
      }
    };
    const onKey = (e) => {
      if (e.key === 'Escape' && open.value) {
        set(false);
      }
    };
    onMounted(() => {
      document.addEventListener('pointerdown', onDoc);
      document.addEventListener('keydown', onKey);
    });
    onBeforeUnmount(() => {
      document.removeEventListener('pointerdown', onDoc);
      document.removeEventListener('keydown', onKey);
    });
    return () => h('span', rootProps(props.n, ['ark-overlay-root', `kind-${kind}`], {}, { ref: el }), props.n.children());
  });
}

const OverlayTrigger = def('OverlayTrigger', (props) => {
  const o = inject(OVERLAY_KEY, null);
  return () => {
    if (!o) {
      return h('span', rootProps(props.n, 'ark-overlay-trigger'), props.n.children());
    }
    const handlers = {};
    if (o.kind === 'hover') {
      handlers.onMouseenter = () => o.set(true);
      handlers.onMouseleave = () => o.set(false);
      handlers.onFocusin = () => o.set(true);
      handlers.onFocusout = () => o.set(false);
    } else if (o.kind === 'context') {
      handlers.onContextmenu = (e) => {
        e.preventDefault();
        const r = o.el.value.getBoundingClientRect();
        o.pos.x = e.clientX - r.left;
        o.pos.y = e.clientY - r.top;
        o.set(true);
      };
    } else {
      handlers.onClick = (e) => {
        e.stopPropagation();
        o.set(!o.open.value);
      };
    }
    return h('span', rootProps(props.n, 'ark-overlay-trigger', {}, handlers), props.n.children());
  };
});

const OverlayClose = def('OverlayClose', (props) => {
  const o = inject(OVERLAY_KEY, null);
  return () => h('span', rootProps(props.n, 'ark-overlay-close', {}, { onClick: () => o?.set(false) }), props.n.children());
});

/** Modal panel (dialog / alert dialog / sheet / drawer): teleported to <body> inside a themed wrapper. */
function modalContent(name, variant) {
  return def(name, (props) => {
    const o = inject(OVERLAY_KEY, null);
    const themeClass = inject(THEME_KEY, ref('ark-theme'));
    return () => {
      if (!o || !o.open.value) {
        return null;
      }
      const c = props.n.props;
      const side = variant === 'sheet' ? (c.side || 'right') : variant === 'drawer' ? 'bottom' : 'center';
      const dismiss = () => {
        if (c.dismissOnOutside !== false && name !== 'SAlertDialogContent') {
          o.set(false);
        }
      };
      return h(Teleport, { to: 'body' }, h('div', { class: [themeClass.value, 'ark-modal-layer'] }, [
        h('div', { class: 'ark-modal-backdrop', onClick: dismiss }),
        h('div', { class: ['ark-modal-panel', `side-${side}`], role: 'dialog', style: props.n.style }, [
          variant === 'drawer' ? h('div', { class: 'ark-drawer-handle' }) : null,
          ...props.n.children(),
          c.showCloseButton !== false && variant !== 'drawer' && name !== 'SAlertDialogContent' ?
            h('button', { class: 'ark-modal-x', onClick: () => o.set(false), 'aria-label': 'Close' }, icon('x', 16)) : null
        ])
      ]));
    };
  });
}

/** Anchored panel (popover, menus, tooltip, hover card, select). */
function floatingContent(name, cls, defaults = {}) {
  return def(name, (props) => {
    const o = inject(OVERLAY_KEY, null);
    return () => {
      if (!o || !o.open.value) {
        return null;
      }
      const c = { ...defaults, ...props.n.props };
      const side = c.side || 'bottom';
      const style = {};
      if (o.kind === 'context') {
        style.left = `${o.pos.x}px`;
        style.top = `${o.pos.y}px`;
      }
      if (c.panelWidth) {
        style.width = `${c.panelWidth}px`;
      }
      const kids = [];
      if (c.text !== undefined) {
        kids.push(txt(c.text));
      }
      kids.push(...props.n.children());
      return h('div', {
        class: ['ark-floating', cls, `side-${side}`, `align-${c.alignment || 'center'}`, o.kind === 'context' && 'at-pointer'],
        style: [style, props.n.style],
        onClick: (e) => e.stopPropagation()
      }, kids);
    };
  });
}

// Menu items (dropdown / context / menubar share these)
const MenuItem = def('MenuItem', (props) => {
  const o = inject(OVERLAY_KEY, null);
  return () => {
    const c = props.n.props;
    return h('div', rootProps(props.n, ['ark-menu-item', c.variant === 'destructive' && 'destructive', c.disabled && 'disabled', c.inset && 'inset'], {}, {
      role: 'menuitem',
      onClick: (e) => {
        if (c.disabled) {
          return;
        }
        props.n.events.onClick?.(e);
        call(c.onSelect);
        if (!c.keepOpen) {
          o?.set(false);
        }
      }
    }), [
      c.icon ? icon(c.icon, 16) : null,
      h('span', { class: 'ark-menu-text' }, [txt(c.text), ...props.n.children()]),
      c.shortcut ? h('span', { class: 'ark-menu-shortcut' }, txt(c.shortcut)) : null
    ]);
  };
});

const MenuCheckboxItem = def('MenuCheckboxItem', (props) => {
  const [checked, set] = useModel(props, 'checked', 'defaultChecked', false, 'onCheckedChange');
  return () => {
    const c = props.n.props;
    return h('div', rootProps(props.n, ['ark-menu-item', 'inset', c.disabled && 'disabled'], {}, {
      role: 'menuitemcheckbox', onClick: () => !c.disabled && set(!checked.value)
    }), [
      h('span', { class: 'ark-menu-indicator' }, checked.value ? icon('check', 16) : null),
      h('span', { class: 'ark-menu-text' }, txt(c.text))
    ]);
  };
});

const MENU_RADIO_KEY = Symbol('menu-radio');
const MenuRadioGroup = def('MenuRadioGroup', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  provide(MENU_RADIO_KEY, { value, set });
  return () => h('div', rootProps(props.n, 'ark-menu-group', {}, { role: 'group' }), props.n.children());
});
const MenuRadioItem = def('MenuRadioItem', (props) => {
  const g = inject(MENU_RADIO_KEY, null);
  return () => {
    const c = props.n.props;
    const on = g && g.value.value === c.value;
    return h('div', rootProps(props.n, ['ark-menu-item', 'inset', c.disabled && 'disabled'], {}, {
      role: 'menuitemradio', onClick: () => !c.disabled && g?.set(c.value)
    }), [
      h('span', { class: 'ark-menu-indicator' }, on ? h('span', { class: 'ark-menu-dot' }) : null),
      h('span', { class: 'ark-menu-text' }, txt(c.text))
    ]);
  };
});
const MenuLabel = (n) => h('div', rootProps(n, ['ark-menu-label', n.props.inset && 'inset']), [txt(n.props.text), ...n.children()]);
const MenuSeparator = (n) => h('div', rootProps(n, 'ark-menu-separator'));
const MenuGroup = (n) => h('div', rootProps(n, 'ark-menu-group'), n.children());

// Select
const SELECT_KEY = Symbol('select');
function optionOf(x) {
  if (x && typeof x === 'object') {
    return { value: x.value ?? x.args?.[0], label: x.label ?? x.text ?? x.args?.[1] ?? x.value ?? x.args?.[0], disabled: x.disabled ?? x.args?.[2] };
  }
  return { value: x, label: x };
}

const SSelect = def('SSelect', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  const open = ref(false);
  const el = ref(null);
  const labels = reactive({});
  provide(OVERLAY_KEY, { open, set: (v) => (open.value = v), kind: 'click', el, pos: {} });
  provide(SELECT_KEY, { value, pick: (v) => { set(v); open.value = false; }, labels, placeholder: () => props.n.props.placeholder });
  const onDoc = (e) => {
    if (open.value && el.value && !el.value.contains(e.target)) {
      open.value = false;
    }
  };
  onMounted(() => document.addEventListener('pointerdown', onDoc));
  onBeforeUnmount(() => document.removeEventListener('pointerdown', onDoc));
  return () => {
    const o = props.n.props;
    const options = (Array.isArray(o.options) ? o.options : []).map(optionOf);
    for (const op of options) {
      labels[op.value] = op.label;
    }
    if (options.length) {
      // data-driven: SSelect({ options, placeholder })
      return h('span', rootProps(props.n, 'ark-overlay-root', {}, { ref: el }), [
        selectTrigger(value.value, labels, o.placeholder, () => !o.disabled && (open.value = !open.value), {}, o.disabled),
        open.value ? h('div', { class: 'ark-floating ark-menu side-bottom align-start', style: { minWidth: '100%' } },
          options.map((op) => selectItem(op, value.value === op.value, () => { set(op.value); open.value = false; }))) : null
      ]);
    }
    return h('span', rootProps(props.n, 'ark-overlay-root', {}, { ref: el }), props.n.children());
  };
});

function selectTrigger(v, labels, placeholder, onClick, style, disabled) {
  const label = v !== '' && v !== undefined ? (labels[v] ?? v) : undefined;
  return h('button', { class: ['ark-input', 'ark-select-trigger', disabled && 'disabled'], style, onClick }, [
    h('span', { class: label === undefined ? 'ark-placeholder' : '' }, label === undefined ? txt(placeholder ?? 'Select…') : txt(label)),
    icon('chevron-down', 16, undefined, 2, { class: 'ark-icon muted' })
  ]);
}

function selectItem(op, selected, onClick) {
  return h('div', { class: ['ark-menu-item', op.disabled && 'disabled'], onClick: () => !op.disabled && onClick() }, [
    h('span', { class: 'ark-menu-text' }, txt(op.label)),
    selected ? h('span', { class: 'ark-menu-check' }, icon('check', 16)) : null
  ]);
}

const SSelectTrigger = def('SSelectTrigger', (props) => {
  const s = inject(SELECT_KEY, null);
  const o = inject(OVERLAY_KEY, null);
  return () => selectTrigger(s?.value.value, s?.labels || {}, props.n.props.placeholder ?? s?.placeholder(),
    (e) => { e.stopPropagation(); o?.set(!o.open.value); }, props.n.style);
});

const SSelectItem = def('SSelectItem', (props) => {
  const s = inject(SELECT_KEY, null);
  if (s) {
    s.labels[props.n.props.value] = props.n.props.text;
  }
  return () => selectItem({ value: props.n.props.value, label: props.n.props.text, disabled: props.n.props.disabled }, s?.value.value === props.n.props.value, () => s?.pick(props.n.props.value));
});

// Combobox (data-driven)
const SCombobox = def('SCombobox', (props) => {
  const [value, set] = useModel(props, 'value', 'defaultValue', '', 'onValueChange');
  const open = ref(false);
  const q = ref('');
  const el = ref(null);
  const onDoc = (e) => {
    if (open.value && el.value && !el.value.contains(e.target)) {
      open.value = false;
    }
  };
  onMounted(() => document.addEventListener('pointerdown', onDoc));
  onBeforeUnmount(() => document.removeEventListener('pointerdown', onDoc));
  return () => {
    const o = props.n.props;
    const options = (Array.isArray(o.options) ? o.options : []).map(optionOf);
    const labels = Object.fromEntries(options.map((op) => [op.value, op.label]));
    const shown = options.filter((op) => String(op.label).toLowerCase().includes(q.value.toLowerCase()));
    return h('span', rootProps(props.n, 'ark-overlay-root', {}, { ref: el }), [
      selectTrigger(value.value, labels, o.placeholder ?? 'Select option…', () => !o.disabled && (open.value = !open.value), { width: `${o.triggerWidth ?? 200}px` }, o.disabled),
      open.value ? h('div', { class: 'ark-floating ark-menu ark-command side-bottom align-start', style: { width: `${o.triggerWidth ?? 200}px` } }, [
        h('div', { class: 'ark-command-input' }, [icon('search', 16), h('input', { placeholder: txt(o.searchPlaceholder ?? 'Search…'), value: q.value, onInput: (e) => (q.value = e.target.value) })]),
        shown.length ? shown.map((op) => selectItem(op, value.value === op.value, () => {
          set(value.value === op.value && o.deselectable !== false ? '' : op.value);
          open.value = false;
        })) : h('div', { class: 'ark-command-empty' }, txt(o.emptyText ?? 'No results found.'))
      ]) : null
    ]);
  };
});

// Command (inline palette)
const CMD_KEY = Symbol('command');
const SCommand = def('SCommand', (props) => {
  const q = ref('');
  provide(CMD_KEY, { q });
  return () => h('div', rootProps(props.n, 'ark-command'), props.n.children());
});
const SCommandInput = def('SCommandInput', (props) => {
  const c = inject(CMD_KEY, null);
  return () => h('div', rootProps(props.n, 'ark-command-input'), [icon('search', 16), h('input', {
    placeholder: txt(props.n.props.placeholder ?? 'Type a command or search…'), value: c?.q.value, onInput: (e) => c && (c.q.value = e.target.value)
  })]);
});
const SCommandList = (n) => h('div', rootProps(n, 'ark-command-list'), n.children());
const SCommandEmpty = def('SCommandEmpty', (props) => {
  const c = inject(CMD_KEY, null);
  return () => (c && c.q.value && !document.querySelector('.ark-command .ark-menu-item') ? h('div', rootProps(props.n, 'ark-command-empty'), txt(props.n.props.text ?? 'No results found.')) : null);
});
const SCommandGroup = (n) => h('div', rootProps(n, 'ark-menu-group'), [n.props.heading !== undefined ? h('div', { class: 'ark-menu-label muted' }, txt(n.props.heading)) : null, ...n.children()]);
const SCommandItem = def('SCommandItem', (props) => {
  const c = inject(CMD_KEY, null);
  return () => {
    const o = props.n.props;
    const hay = [o.text, o.value, ...(o.keywords || [])].join(' ').toLowerCase();
    if (c && c.q.value && !hay.includes(c.q.value.toLowerCase())) {
      return null;
    }
    return h('div', rootProps(props.n, ['ark-menu-item', o.disabled && 'disabled'], {}, { onClick: () => !o.disabled && call(o.onSelect, o.value) }), [
      o.icon ? icon(o.icon, 16) : null,
      h('span', { class: 'ark-menu-text' }, [txt(o.text), ...props.n.children()]),
      o.checked ? icon('check', 16) : null,
      o.shortcut ? h('span', { class: 'ark-menu-shortcut' }, txt(o.shortcut)) : null
    ]);
  };
});
const SCommandSeparator = (n) => h('div', rootProps(n, 'ark-menu-separator'));

// Tooltip: content is shown next to the trigger on hover
const STooltipContent = floatingContent('STooltipContent', 'ark-tooltip', { side: 'top' });

// Menubar: each menu is its own overlay root, triggers sit in a bar
const SMenubar = (n) => h('div', rootProps(n, 'ark-menubar'), n.children());
const SMenubarMenu = overlayRoot('SMenubarMenu', 'click');
const SMenubarTrigger = def('SMenubarTrigger', (props) => {
  const o = inject(OVERLAY_KEY, null);
  return () => h('button', rootProps(props.n, ['ark-menubar-trigger', o?.open.value && 'open'], {}, {
    onClick: (e) => { e.stopPropagation(); o?.set(!o.open.value); }
  }), [txt(props.n.props.text), ...props.n.children()]);
});

// Dialog-family typography
const DialogHeader = (n) => h('div', rootProps(n, 'ark-dialog-header'), n.children());
const DialogFooter = (n) => h('div', rootProps(n, 'ark-dialog-footer'), n.children());
const DialogTitle = typo('ark-dialog-title');
const DialogDescription = typo('ark-dialog-description');

const AlertDialogAction = def('AlertDialogAction', (props) => {
  const o = inject(OVERLAY_KEY, null);
  return () => SButton({
    ...props.n,
    props: { text: props.n.props.text ?? 'Continue', variant: props.n.props.variant, disabled: props.n.props.disabled },
    events: { onClick: (e) => { props.n.events.onClick?.(e); o?.set(false); } }
  });
});
const AlertDialogCancel = def('AlertDialogCancel', (props) => {
  const o = inject(OVERLAY_KEY, null);
  return () => SButton({
    ...props.n,
    props: { text: props.n.props.text ?? 'Cancel', variant: 'outline' },
    events: { onClick: (e) => { props.n.events.onClick?.(e); o?.set(false); } }
  });
});

// Date (very small month grid)
const SCalendar = def('SCalendar', (props) => {
  const today = new Date();
  const view = ref(new Date(today.getFullYear(), today.getMonth(), 1));
  const picked = ref(null);
  return () => {
    const v = view.value;
    const first = new Date(v.getFullYear(), v.getMonth(), 1);
    const startDow = (first.getDay() - (props.n.props.weekStartsOn ?? 0) + 7) % 7;
    const days = new Date(v.getFullYear(), v.getMonth() + 1, 0).getDate();
    const cells = [];
    for (let i = 0; i < startDow; i++) {
      cells.push(h('span', { class: 'ark-cal-cell outside' }));
    }
    for (let d = 1; d <= days; d++) {
      const isToday = d === today.getDate() && v.getMonth() === today.getMonth() && v.getFullYear() === today.getFullYear();
      cells.push(h('button', {
        class: ['ark-cal-cell', isToday && 'today', picked.value === d && 'selected'], onClick: () => {
          picked.value = d;
          call(props.n.props.onPick, new Date(v.getFullYear(), v.getMonth(), d));
        }
      }, String(d)));
    }
    const zh = props.n.props.locale === 'zh';
    const wd = zh ? ['日', '一', '二', '三', '四', '五', '六'] : ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    const ws = props.n.props.weekStartsOn ?? 0;
    const caption = zh ? `${v.getFullYear()}年${v.getMonth() + 1}月` : v.toLocaleString('en', { month: 'long', year: 'numeric' });
    return h('div', rootProps(props.n, ['ark-calendar', props.n.props.bordered !== false && 'bordered']), [
      h('div', { class: 'ark-cal-head' }, [
        h('button', { class: 'ark-btn ark-btn-ghost', style: { width: '28px', height: '28px', padding: 0 }, onClick: () => (view.value = new Date(v.getFullYear(), v.getMonth() - 1, 1)) }, icon('chevron-left', 16)),
        h('span', { class: 'ark-cal-caption' }, caption),
        h('button', { class: 'ark-btn ark-btn-ghost', style: { width: '28px', height: '28px', padding: 0 }, onClick: () => (view.value = new Date(v.getFullYear(), v.getMonth() + 1, 1)) }, icon('chevron-right', 16))
      ]),
      h('div', { class: 'ark-cal-grid' }, [...[...wd.slice(ws), ...wd.slice(0, ws)].map((x) => h('span', { class: 'ark-cal-wd' }, x)), ...cells])
    ]);
  };
});

// Dashboard tiles
const SDashboardGrid = (n) => SGrid({ ...n, props: { minItemWidth: n.props.minTileWidth ?? n.props.minItemWidth ?? 200, gap: n.props.gap ?? 16 } });
function SDashboardTile(n) {
  const o = n.props;
  const trend = o.trend === 'up' ? 'var(--success)' : o.trend === 'down' ? 'var(--destructive)' : 'var(--muted-foreground)';
  return h('div', rootProps(n, 'ark-card ark-tile', { gridColumn: o.full ? '1 / -1' : o.span > 1 ? `span ${o.span}` : undefined }), [
    h('div', { class: 'ark-tile-head' }, [h('span', txt(o.title)), o.icon ? icon(o.icon, 16) : null]),
    o.value !== undefined ? h('div', { class: 'ark-tile-value' }, txt(o.value)) : null,
    o.delta !== undefined ? h('div', { class: 'ark-tile-delta', style: { color: trend } }, [
      o.trend === 'up' ? icon('trending-up', 14) : o.trend === 'down' ? icon('trending-down', 14) : null, txt(o.delta)]) : null,
    ...n.children()
  ]);
}

// Date picker: trigger + popover calendar
const SDatePicker = def('SDatePicker', (props) => {
  const open = ref(false);
  const picked = ref('');
  return () => {
    const o = props.n.props;
    const zh = o.locale === 'zh';
    return h('span', rootProps(props.n, 'ark-overlay-root'), [
      h('button', { class: ['ark-btn', 'ark-btn-outline'], style: { width: '240px', justifyContent: 'flex-start', fontWeight: 400 }, onClick: () => (open.value = !open.value) }, [
        icon('calendar', 16),
        h('span', { class: picked.value ? '' : 'ark-placeholder' }, picked.value || txt(o.placeholder ?? (zh ? '选择日期' : 'Pick a date')))
      ]),
      open.value ? h('div', { class: 'ark-floating side-bottom align-start', style: { padding: 0 } },
        h(SCalendar, { n: { ...props.n, style: {}, events: {}, props: { locale: o.locale, bordered: false, onPick: (d) => { picked.value = d.toLocaleDateString(zh ? 'zh-CN' : 'en-US', { year: 'numeric', month: 'short', day: 'numeric' }); open.value = false; } } } })) : null
    ]);
  };
});

// ------------------------------------------------------------------------------------------------ registry

const passthrough = (n) => h('div', rootProps(n, 'ark-passthrough'), n.children());

export function createRegistry() {
  const PopRoot = overlayRoot('SPopover', 'click');
  const DialogRoot = overlayRoot('SDialog', 'modal');
  const AlertDialogRoot = overlayRoot('SAlertDialog', 'modal');
  const SheetRoot = overlayRoot('SSheet', 'modal');
  const DrawerRoot = overlayRoot('SDrawer', 'modal');
  const MenuRoot = overlayRoot('SDropdownMenu', 'click');
  const TooltipRoot = overlayRoot('STooltip', 'hover');
  const HoverRoot = overlayRoot('SHoverCard', 'hover');
  const ContextRoot = overlayRoot('SContextMenu', 'context');
  const CommandDialogRoot = overlayRoot('SCommandDialog', 'modal');
  const CommandDialogContent = modalContent('SCommandDialogContent', 'dialog');

  const reg = {
    // ArkUI containers & basics
    Column, Row, Flex, Stack, Text, Span, Button: NativeButton, Image, Divider, Blank, Scroll, List, ListItem,
    ListItemGroup: List, Grid, GridItem, WaterFlow: Grid, FlowItem: GridItem, RelativeContainer: Stack,
    GridRow: Grid, GridCol: GridItem, Toggle: C(NativeToggle), TextInput: NativeTextInput, TextArea: NativeTextArea,
    Search: NativeTextInput, Progress: NativeProgress, LoadingProgress, Circle: Shape('circle'), Rect: Shape('rect'),
    Ellipse: Shape('circle'), SymbolGlyph, Checkbox: (n) => h(SCheckbox, { n: { ...n, props: { defaultChecked: n.attr('select')?.[0] } } }),
    Radio: (n) => h('span', rootProps(n, ['ark-radio', n.props.checked && 'checked'])),
    Slider: (n) => h(SSlider, { n: { ...n, props: { defaultValue: n.props.value, min: n.props.min, max: n.props.max } } }),

    // providers / context
    SparkProvider: passthrough, SparkContainer: passthrough, SparkLayoutContainer: passthrough,

    // components
    SButton, SIcon, SBadge,
    SCard, SCardHeader, SCardTitle, SCardDescription, SCardAction, SCardContent, SCardFooter,
    SInput: C(SInput), STextarea: C(STextarea), SLabel, SSwitch: C(SSwitch), SCheckbox: C(SCheckbox),
    SRadioGroup: C(SRadioGroup), SRadioGroupItem: C(SRadioGroupItem), SSlider: C(SSlider), SProgress,
    STabs: C(STabs), STabsList, STabsTrigger: C(STabsTrigger), STabsContent: C(STabsContent),
    SAccordion: C(SAccordion), SAccordionItem: C(SAccordionItem), SAccordionTrigger: C(SAccordionTrigger),
    SAccordionContent: C(SAccordionContent),
    SCollapsible: C(SCollapsible), SCollapsibleTrigger: C(SCollapsibleTrigger), SCollapsibleContent: C(SCollapsibleContent),
    SToggle: C(SToggle), SToggleGroup: C(SToggleGroup), SToggleGroupItem: C(SToggleGroupItem),
    SButtonGroup, SButtonGroupSeparator,
    SAlert: C(SAlert), SAlertTitle, SAlertDescription, SAvatar, SAvatarGroup, SSeparator, SSkeleton, SSpinner, SKbd, SKbdGroup,
    SH1: typo('ark-h1'), SH2: typo('ark-h2'), SH3: typo('ark-h3'), SH4: typo('ark-h4'), SP: typo('ark-p'), SLead: typo('ark-lead'),
    SLarge: typo('ark-large'), SSmall: typo('ark-small'), SMuted: typo('ark-muted'), SBlockquote: typo('ark-blockquote'),
    SInlineCode: typo('ark-inline-code', 'code'), SList,
    SEmpty, SEmptyHeader, SEmptyMedia, SEmptyTitle, SEmptyDescription, SEmptyContent,
    SItemGroup, SItem, SItemSeparator, SItemMedia, SItemContent, SItemTitle, SItemDescription, SItemActions,
    SBreadcrumb, SBreadcrumbList, SBreadcrumbItem, SBreadcrumbLink, SBreadcrumbPage, SBreadcrumbSeparator, SBreadcrumbEllipsis,
    SPagination: C(SPagination),
    SField, SFieldLabel, SFieldContent, SFieldDescription, SFieldError, SFieldGroup, SFieldSet, SFieldLegend, SFieldSeparator,
    SPage, SStack, SRow, SFlow, SGrid, SGridItem, SColumns, SColumn,
    STable, STableCaption, STableHeader, STableBody, STableFooter, STableRow, STableHead, STableCell,
    SAspectRatio, SScrollArea, SNumberField: C(SNumberField), SPinInput: C(SPinInput), STagsInput: C(STagsInput),
    SInputGroup, SInputGroupAddon, SInputGroupText, SInputGroupButton, SInputGroupInput: C(SInputGroupInput),
    SStepper: C(SStepper), SStepperItem: C(SStepperItem), SCodeBlock, SSparkline, SCalendar: C(SCalendar),
    SRangeCalendar: C(SCalendar), SDatePicker: C(SDatePicker), SDateRangePicker: C(SDatePicker),
    SDashboardGrid, SDashboardTile,
    SLineChart: cartesian('line'), SAreaChart: cartesian('area'), SBarChart: cartesian('bar'), SPieChart: pie(false),
    SDonutChart: pie(true), SRadialChart: radial, SRadarChart: radar, SChartContainer: chartContainer,
    // transitions: children render without the animation
    STransition: passthrough, STransitionGroup: passthrough, SSwitchTransition: passthrough, SPageTransition: passthrough,

    // overlays
    SPopover: C(PopRoot), SPopoverTrigger: C(OverlayTrigger), SPopoverClose: C(OverlayClose),
    SPopoverContent: C(floatingContent('SPopoverContent', 'ark-popover')),
    SDialog: C(DialogRoot), SDialogTrigger: C(OverlayTrigger), SDialogClose: C(OverlayClose),
    SDialogContent: C(modalContent('SDialogContent', 'dialog')),
    SDialogHeader: DialogHeader, SDialogFooter: DialogFooter, SDialogTitle: DialogTitle, SDialogDescription: DialogDescription,
    SAlertDialog: C(AlertDialogRoot), SAlertDialogTrigger: C(OverlayTrigger),
    SAlertDialogContent: C(modalContent('SAlertDialogContent', 'dialog')),
    SAlertDialogAction: C(AlertDialogAction), SAlertDialogCancel: C(AlertDialogCancel),
    SAlertDialogHeader: DialogHeader, SAlertDialogFooter: DialogFooter, SAlertDialogTitle: DialogTitle,
    SAlertDialogDescription: DialogDescription,
    SSheet: C(SheetRoot), SSheetTrigger: C(OverlayTrigger), SSheetClose: C(OverlayClose),
    SSheetContent: C(modalContent('SSheetContent', 'sheet')),
    SSheetHeader: DialogHeader, SSheetFooter: DialogFooter, SSheetTitle: DialogTitle, SSheetDescription: DialogDescription,
    SDrawer: C(DrawerRoot), SDrawerTrigger: C(OverlayTrigger), SDrawerClose: C(OverlayClose),
    SDrawerContent: C(modalContent('SDrawerContent', 'drawer')),
    SDrawerHeader: DialogHeader, SDrawerFooter: DialogFooter, SDrawerTitle: DialogTitle, SDrawerDescription: DialogDescription,
    SDropdownMenu: C(MenuRoot), SDropdownMenuTrigger: C(OverlayTrigger),
    SDropdownMenuContent: C(floatingContent('SDropdownMenuContent', 'ark-menu', { alignment: 'start' })),
    SDropdownMenuItem: C(MenuItem), SDropdownMenuCheckboxItem: C(MenuCheckboxItem), SDropdownMenuRadioGroup: C(MenuRadioGroup),
    SDropdownMenuRadioItem: C(MenuRadioItem), SDropdownMenuLabel: MenuLabel, SDropdownMenuSeparator: MenuSeparator,
    SDropdownMenuGroup: MenuGroup,
    SContextMenu: C(ContextRoot), SContextMenuTrigger: C(OverlayTrigger),
    SContextMenuContent: C(floatingContent('SContextMenuContent', 'ark-menu', { alignment: 'start' })),
    SContextMenuItem: C(MenuItem), SContextMenuCheckboxItem: C(MenuCheckboxItem), SContextMenuRadioGroup: C(MenuRadioGroup),
    SContextMenuRadioItem: C(MenuRadioItem), SContextMenuLabel: MenuLabel, SContextMenuSeparator: MenuSeparator,
    SContextMenuGroup: MenuGroup,
    SMenubar, SMenubarMenu: C(SMenubarMenu), SMenubarTrigger: C(SMenubarTrigger),
    SMenubarContent: C(floatingContent('SMenubarContent', 'ark-menu', { alignment: 'start' })),
    SMenubarItem: C(MenuItem), SMenubarCheckboxItem: C(MenuCheckboxItem), SMenubarRadioGroup: C(MenuRadioGroup),
    SMenubarRadioItem: C(MenuRadioItem), SMenubarLabel: MenuLabel, SMenubarSeparator: MenuSeparator, SMenubarGroup: MenuGroup,
    STooltip: C(TooltipRoot), STooltipTrigger: C(OverlayTrigger), STooltipContent: C(STooltipContent),
    SHoverCard: C(HoverRoot), SHoverCardTrigger: C(OverlayTrigger),
    SHoverCardContent: C(floatingContent('SHoverCardContent', 'ark-popover', { panelWidth: 256 })),
    SSelect: C(SSelect), SSelectTrigger: C(SSelectTrigger),
    SSelectContent: C(floatingContent('SSelectContent', 'ark-menu', { alignment: 'start' })),
    SSelectItem: C(SSelectItem), SSelectLabel: MenuLabel, SSelectSeparator: MenuSeparator, SSelectGroup: MenuGroup,
    SCombobox: C(SCombobox),
    SCommand: C(SCommand), SCommandInput: C(SCommandInput), SCommandList, SCommandEmpty: C(SCommandEmpty),
    SCommandGroup, SCommandItem: C(SCommandItem), SCommandSeparator,
    SCommandDialog: (n) => h(CommandDialogRoot, {
      n: {
        ...n,
        style: {},
        events: {},
        children: () => [h(CommandDialogContent, {
          n: { ...n, props: { showCloseButton: false }, style: { padding: 0, gap: 0 }, events: {}, children: () => [h(SCommand, { n: { ...n, style: { border: 0 }, events: {} } })] }
        })]
      }
    })
  };
  return reg;
}

export { Fragment, computed };
