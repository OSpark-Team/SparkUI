/**
 * Web imitations of the SparkUI chart family (SLineChart / SAreaChart / SBarChart, SPieChart / SDonutChart,
 * SRadialChart, SRadarChart, SSparkline, SChartContainer). Layout follows the library engines
 * (SCartesianChart.ets, SPieChart.ets, SRadialChart.ets, SRadarChart.ets, SSparkline.ets) with the maths ported
 * in chart-math.js: nice ticks, band / point scales, diverging stacks, monotone curves, rounded bars, pie arcs,
 * label thinning. Hover shows the crosshair / cursor and the tooltip card, legend entries toggle series, and
 * shapes draw in with CSS animations (re-played when the data changes).
 *
 * Snippets often reference `config` / `rows` declared elsewhere on the gallery page: unresolved identifiers are
 * mapped to the page's constants (DEVICES, MONTHS, BROWSERS …) and finally to the shadcn sample data.
 */
import { h, ref, reactive, computed, provide, inject, defineComponent, onMounted, onBeforeUnmount, onUpdated, useId } from 'vue';
import { isEnumProxy } from './interp.js';
import * as M from './chart-math.js';

const FS = 12;
const LABEL_H = 16;
const GROW = 8;
const CHART_KEY = Symbol('chart-state');

// ------------------------------------------------------------------------------------------------ data

const SAMPLE_CONFIG = { series: [{ key: 'desktop', label: 'Desktop', color: 'chart-1' }, { key: 'mobile', label: 'Mobile', color: 'chart-2' }] };
const SAMPLE_ROWS = [['January', 186, 80], ['February', 305, 200], ['March', 237, 120], ['April', 73, 190], ['May', 209, 130],
  ['June', 214, 140]].map(([label, desktop, mobile]) => ({ label, values: { desktop, mobile } }));
const SAMPLE_BROWSERS = { series: ['Chrome', 'Safari', 'Firefox', 'Edge', 'Other'].map((l, i) => ({ key: l.toLowerCase(), label: l, color: `chart-${i + 1}` })) };
const SAMPLE_BROWSER_ROWS = [['chrome', 275], ['safari', 200], ['firefox', 187], ['edge', 173], ['other', 90]]
  .map(([label, visitors]) => ({ label, values: { visitors } }));

/** identifier used in a snippet → gallery constant (ChartDocs.ets) */
const CONFIG_REFS = { config: 'DESKTOP', desktopConfig: 'DESKTOP', devices: 'DEVICES', browsers: 'BROWSERS', visitors: 'VISITORS', mobileConfig: 'MOBILE' };
const ROW_REFS = { profit: 'PROFIT', months: 'MONTHS', browserRows: 'BROWSER_ROWS', safariOnly: 'SAFARI_ONLY' };

function lookupConst(n, name) {
  if (!name || !n.rt) {
    return undefined;
  }
  const r = n.rt.root.lookup(name);
  return r.found ? r.value : undefined;
}

function seriesList(config) {
  const list = config?.series ?? config?.args?.[0];
  if (!Array.isArray(list)) {
    return undefined;
  }
  return list.map((s) => {
    const key = String(s?.key ?? s?.args?.[0] ?? '');
    return { key, label: String(s?.label ?? s?.args?.[1] ?? key), color: String(s?.color ?? s?.args?.[2] ?? '') };
  });
}

function rowList(data) {
  if (!Array.isArray(data)) {
    return undefined;
  }
  return data.map((r) => ({ label: String(r?.label ?? r?.args?.[0] ?? ''), values: r?.values ?? r?.args?.[1] ?? {} }));
}

/** Resolve config + rows of a chart node (props → page constants by identifier → samples). */
function chartData(n, polar) {
  const o = n.props;
  let series = seriesList(o.config);
  if (!series) {
    series = seriesList(lookupConst(n, CONFIG_REFS[n.refs?.config])) ??
      seriesList(polar ? SAMPLE_BROWSERS : (o.legend || o.stacked ? SAMPLE_CONFIG : { series: SAMPLE_CONFIG.series.slice(0, 1) }));
  }
  let rows = rowList(o.data);
  if (!rows) {
    const ref = n.refs?.data;
    rows = rowList(lookupConst(n, ROW_REFS[ref])) ??
      (polar ? rowList(lookupConst(n, 'BROWSER_ROWS')) ?? SAMPLE_BROWSER_ROWS : rowList(lookupConst(n, 'MONTHS')) ?? SAMPLE_ROWS);
  }
  return { series, rows };
}

function value(row, key) {
  const v = Number(row.values?.[key]);
  return isFinite(v) ? v : 0;
}

/** sparkChartColor: '#hex' as is, a token name → var(--token), empty → chart-1…5 by index */
export function chartColor(c, i) {
  const s = c === undefined || c === null ? '' : String(c);
  if (s.startsWith('#') || s.startsWith('var(') || s.startsWith('rgb') || s.startsWith('oklch') || s.startsWith('hsl')) {
    return s;
  }
  if (s.length > 0) {
    return `var(--${s})`;
  }
  return `var(--chart-${(((i % 5) + 5) % 5) + 1})`;
}

function configLabel(series, key) {
  return series.find((s) => s.key === key)?.label ?? key;
}

function configColor(series, key, fallbackIndex) {
  const i = series.findIndex((s) => s.key === key);
  return i >= 0 ? chartColor(series[i].color, i) : chartColor('', fallbackIndex ?? 0);
}

function fmtValue(o) {
  return (v) => {
    if (typeof o.valueFormatter === 'function') {
      try {
        const r = o.valueFormatter(v);
        if (r !== undefined) {
          return String(r);
        }
      } catch (e) {
        // fall through
      }
    }
    return M.chartFormat(v);
  };
}

function fmtLabel(o) {
  return (s) => {
    if (typeof o.labelFormatter === 'function') {
      try {
        const r = o.labelFormatter(s);
        if (r !== undefined) {
          return String(r);
        }
      } catch (e) {
        // fall through
      }
    }
    return s;
  };
}

function enumName(v) {
  return v === undefined || v === null ? undefined : (isEnumProxy(v) ? String(v) : v);
}

// ------------------------------------------------------------------------------------------------ shared parts

/** Width of the element (ResizeObserver); `fallback` until measured (SSR / first paint). */
function useWidth(fallback) {
  const el = ref(null);
  const width = ref(0);
  let ro = null;
  onMounted(() => {
    if (!el.value) {
      return;
    }
    width.value = el.value.getBoundingClientRect().width;
    if (typeof ResizeObserver !== 'undefined') {
      ro = new ResizeObserver((entries) => {
        const w = entries[0]?.contentRect?.width ?? 0;
        if (Math.abs(w - width.value) > 0.5) {
          width.value = w;
        }
      });
      ro.observe(el.value);
    }
  });
  onBeforeUnmount(() => ro?.disconnect());
  return { el, width: computed(() => (width.value > 0 ? width.value : fallback)), measured: computed(() => width.value > 0) };
}

/** Series visibility (SparkChartState): from an enclosing SChartContainer, else the chart's own. */
function useChartState() {
  const shared = inject(CHART_KEY, null);
  const own = reactive({ hidden: [] });
  const st = shared ?? own;
  return {
    isHidden: (k) => st.hidden.includes(k),
    toggle: (k) => {
      st.hidden = st.hidden.includes(k) ? st.hidden.filter((x) => x !== k) : [...st.hidden, k];
    },
    shared: !!shared
  };
}

function legend(items, state, compact, interactive = true) {
  return h('div', { class: ['ark-chart-legend', compact && 'compact'] }, items.map((it) => {
    const muted = state.isHidden(it.key);
    return h(interactive ? 'button' : 'span', {
      class: ['ark-chart-legend-item', muted && 'muted', interactive && 'interactive'],
      type: interactive ? 'button' : undefined,
      'aria-pressed': interactive ? String(!muted) : undefined,
      onClick: interactive ? () => state.toggle(it.key) : undefined
    }, [h('i', { style: { background: it.color } }), h('span', it.label)]);
  }));
}

function tooltipCard(title, items, indicator) {
  const mark = (c) => h('i', { class: ['ark-chart-tip-mark', indicator || 'dot'], style: { '--c': c } });
  return h('div', { class: 'ark-chart-tooltip' }, [
    title ? h('div', { class: 'ark-chart-tip-title' }, title) : null,
    h('div', { class: 'ark-chart-tip-rows' }, items.map((it) => h('div', { class: 'ark-chart-tip-row' }, [
      mark(it.color), h('span', { class: 'ark-chart-tip-label' }, it.label), h('span', { class: 'ark-chart-tip-value' }, it.value)
    ])))
  ]);
}

/** Pointer handling: local coordinates of mouse / touch over the chart box. */
function pointer(onPoint, onLeave) {
  const at = (e) => {
    const r = e.currentTarget.getBoundingClientRect();
    onPoint(e.clientX - r.left, e.clientY - r.top);
  };
  return { onPointermove: at, onPointerdown: at, onPointerleave: onLeave };
}

/** Tooltip size measured after render (for tooltipPlace). */
function useTipSize() {
  const tip = ref(null);
  const size = reactive({ w: 140, h: 60 });
  onUpdated(() => {
    const el = tip.value;
    if (el) {
      const w = el.offsetWidth;
      const hh = el.offsetHeight;
      if (Math.abs(w - size.w) > 0.5 || Math.abs(hh - size.h) > 0.5) {
        size.w = w;
        size.h = hh;
      }
    }
  });
  return { tip, size };
}

function emptyBox(text, height, n) {
  return h('div', { class: 'ark-chart ark-chart-empty', style: [{ height: `${height}px` }, n?.style] }, String(text ?? 'No data'));
}

function axisLabels(labels) {
  return labels.map((l) => h('span', {
    class: ['ark-chart-axis-label', l.end && 'end'],
    style: { left: `${l.x}px`, top: `${l.y}px`, width: `${l.w}px` }
  }, l.text));
}

/** SSR-stable id for gradient / mask ids (Vue useId; falls back to a counter outside an app). */
let uidCounter = 0;
function chartUid() {
  const id = typeof useId === 'function' ? useId() : undefined;
  return `c${String(id ?? ++uidCounter).replace(/[^A-Za-z0-9_-]/g, '')}`;
}

/** A key that changes with the data, so shapes re-mount and their CSS enter animation replays. */
function dataKey(...parts) {
  return JSON.stringify(parts);
}

// ------------------------------------------------------------------------------------------------ cartesian

function cartesianGeo(kind, o, series, rows, keys, W, H, radiusMd) {
  const g = { w: W, h: H, positions: [], step: 0, grid: '', labels: [], series: [], plotL: 0, plotT: 0, plotW: 0, plotH: 0, base: 0 };
  const n = rows.length;
  if (W <= 0 || n === 0) {
    return g;
  }
  const label = fmtLabel(o);
  const vals = keys.map((key) => rows.map((r) => value(r, key)));
  const stacked = !!o.stacked && kind !== 'line';
  const st = M.stack(stacked ? vals : []);
  const all = [];
  if (stacked) {
    st.upper.forEach((s) => s.forEach((v) => all.push(v)));
    st.lower.forEach((s) => s.forEach((v) => all.push(v)));
  } else {
    vals.forEach((s) => s.forEach((v) => all.push(v)));
  }
  const bar = kind === 'bar';
  const horizontal = bar && !!o.horizontal;
  const categoryAxis = o.categoryAxis !== false;
  const valueAxis = !!o.valueAxis;
  const catTexts = rows.map((r) => label(r.label));
  let catW = 0;
  catTexts.forEach((t) => (catW = Math.max(catW, M.textWidth(t, FS))));

  let plotL;
  let plotT;
  let plotW;
  let plotH;
  let ticks;
  let scale;
  if (!horizontal) {
    plotT = o.dots || !bar ? 8 : 4;
    const bottom = categoryAxis ? LABEL_H + 10 : 4;
    plotH = Math.max(1, H - plotT - bottom);
    const count = M.tickCount(plotH, 48, 2, 6);
    const dom = M.valueDomain(all, true, count);
    ticks = M.niceTicks(dom[0], dom[1], count);
    let valW = 0;
    ticks.forEach((t) => (valW = Math.max(valW, M.textWidth(M.chartCompact(t), FS))));
    plotL = valueAxis ? valW + 8 : (bar ? 0 : 12);
    const right = bar ? 0 : 12;
    plotW = Math.max(1, W - plotL - right);
    scale = new M.LinearScale(dom[0], dom[1], plotT + plotH, plotT);
  } else {
    plotT = 0;
    const bottom = valueAxis ? LABEL_H + 10 : 0;
    plotH = Math.max(1, H - plotT - bottom);
    plotL = categoryAxis ? Math.min(catW, W * 0.35) + 8 : 0;
    plotW = Math.max(1, W - plotL - 8);
    const count = M.tickCount(plotW, 80, 2, 6);
    const dom = M.valueDomain(all, true, count);
    ticks = M.niceTicks(dom[0], dom[1], count);
    scale = new M.LinearScale(dom[0], dom[1], plotL, plotL + plotW);
  }
  Object.assign(g, { plotL, plotT, plotW, plotH });
  const base = scale.mapClamped(0);
  g.base = base;

  const band = new M.BandScale(n, horizontal ? plotT : plotL, horizontal ? plotT + plotH : plotL + plotW, 0.2, 0.1);
  if (bar) {
    g.positions = band.centers();
    g.step = band.step;
  } else {
    g.positions = M.pointPositions(n, plotL, plotL + plotW);
    g.step = n > 1 ? plotW / (n - 1) : plotW;
  }

  g.grid = ticks.map((t) => {
    const p = scale.map(t);
    return horizontal ? `M${p} ${plotT} L${p} ${plotT + plotH}` : `M${plotL} ${p} L${plotL + plotW} ${p}`;
  }).join(' ');
  const labels = [];
  if (categoryAxis) {
    if (!horizontal) {
      const lw = catW + 8;
      const stepN = M.labelStep(n, bar ? plotW : plotW + g.step, lw);
      for (let i = 0; i < n; i += stepN) {
        const x = Math.max(0, Math.min(W - lw, g.positions[i] - lw / 2));
        labels.push({ text: catTexts[i], x, y: plotT + plotH + 8, w: lw, end: false });
      }
    } else {
      const stepN = M.labelStep(n, plotH, LABEL_H + 4);
      for (let i = 0; i < n; i += stepN) {
        labels.push({ text: catTexts[i], x: 0, y: g.positions[i] - LABEL_H / 2, w: Math.max(1, plotL - 8), end: true });
      }
    }
  }
  if (valueAxis) {
    if (!horizontal) {
      ticks.forEach((t) => labels.push({ text: M.chartCompact(t), x: 0, y: scale.map(t) - LABEL_H / 2, w: Math.max(1, plotL - 8), end: true }));
    } else {
      let tw = 0;
      ticks.forEach((t) => (tw = Math.max(tw, M.textWidth(M.chartCompact(t), FS) + 8)));
      const stepN = M.labelStep(ticks.length, plotW, tw);
      for (let i = 0; i < ticks.length; i += stepN) {
        const x = Math.max(0, Math.min(W - tw, scale.map(ticks[i]) - tw / 2));
        labels.push({ text: M.chartCompact(ticks[i]), x, y: plotT + plotH + 8, w: tw, end: false });
      }
    }
  }
  g.labels = labels;

  const m = keys.length;
  const radius = o.barRadius !== undefined && o.barRadius >= 0 ? o.barRadius : radiusMd;
  const curve = o.curve || 'monotone';
  const flat = rows.map(() => base);
  keys.forEach((key, s) => {
    const sg = { key, label: configLabel(series, key), color: configColor(series, key, s) };
    const upper = stacked ? st.upper[s] : vals[s];
    const ys = upper.map((v) => scale.map(v));
    sg.points = ys;
    if (kind === 'line') {
      sg.line = M.curvePath(g.positions, ys, curve);
    } else if (kind === 'area') {
      const bs = stacked ? st.lower[s].map((v) => scale.map(v)) : flat;
      sg.area = M.areaPath(g.positions, ys, bs, curve);
      sg.line = M.curvePath(g.positions, ys, curve);
    } else {
      const gap = stacked || m <= 1 ? 0 : Math.min(4, band.bandwidth * 0.1);
      const bw = stacked ? band.bandwidth : (band.bandwidth - gap * (m - 1)) / Math.max(1, m);
      const r = Math.max(0, Math.min(radius, bw / 2));
      const outer = !stacked || s === m - 1 ? r : 0;
      const inner = !stacked || s === 0 ? r : 0;
      const parts = [];
      for (let i = 0; i < n; i++) {
        const lower = stacked ? scale.map(st.lower[s][i]) : base;
        const p = ys[i];
        const off = band.start(i) + (stacked ? 0 : s * (bw + gap));
        // a negative value grows the other way: its "outer" end is the lower one
        const neg = (stacked ? st.upper[s][i] - st.lower[s][i] : vals[s][i]) < 0 && !stacked;
        if (!horizontal) {
          parts.push(neg ? M.roundRectPath(off, Math.min(p, lower), bw, Math.abs(lower - p), inner, inner, outer, outer) :
            M.roundRectPath(off, Math.min(p, lower), bw, Math.abs(lower - p), outer, outer, inner, inner));
        } else {
          parts.push(neg ? M.roundRectPath(Math.min(p, lower), off, Math.abs(p - lower), bw, outer, inner, inner, outer) :
            M.roundRectPath(Math.min(p, lower), off, Math.abs(p - lower), bw, inner, outer, outer, inner));
        }
      }
      sg.bars = parts.filter(Boolean).join(' ');
    }
    if (o.dots && kind !== 'bar') {
      sg.dots = g.positions.map((x, i) => [x, ys[i]]);
    }
    g.series.push(sg);
  });
  return g;
}

function cartesian(kind) {
  const Comp = defineComponent({
    name: `S${kind[0].toUpperCase()}${kind.slice(1)}Chart`,
    props: { n: { type: Object, required: true } },
    setup(props) {
      const { el, width, measured } = useWidth(480);
      const state = useChartState();
      const active = ref(-1);
      const pt = reactive({ x: 0, y: 0 });
      const { tip, size } = useTipSize();
      const uid = chartUid();
      return () => {
        const n = props.n;
        const o = n.props;
        const { series, rows } = chartData(n, false);
        const keys = series.map((s) => s.key).filter((k) => !state.isHidden(k));
        const W = width.value;
        const H = o.chartHeight > 0 ? o.chartHeight : (measured.value ? Math.max(160, Math.min(320, Math.round(W * 0.5625))) : 200);
        const indicator = enumName(o.indicator) ?? (kind === 'line' ? 'line' : 'dot');
        const tooltip = o.tooltip !== false;
        const g = cartesianGeo(kind, o, series, rows, keys, W, H, 8);
        const horizontal = kind === 'bar' && !!o.horizontal;
        const kids = [];
        if (rows.length === 0) {
          kids.push(h('div', { class: 'ark-chart-empty-text' }, String(o.emptyText ?? 'No data')));
        } else {
          const svg = [];
          if (o.grid !== false) {
            svg.push(h('path', { d: g.grid, class: 'ark-chart-grid' }));
          }
          const i = active.value;
          if (tooltip && i >= 0 && i < g.positions.length && kind === 'bar') {
            const c = g.positions[i];
            svg.push(horizontal ?
              h('rect', { x: g.plotL, y: c - g.step / 2, width: g.plotW, height: g.step, class: 'ark-chart-cursor-band' }) :
              h('rect', { x: c - g.step / 2, y: g.plotT, width: g.step, height: g.plotH, class: 'ark-chart-cursor-band' }));
          }
          const sk = dataKey(keys, rows, o.stacked, o.horizontal, o.curve, W > 0);
          const shapes = [];
          for (const s of g.series) {
            if (kind === 'line') {
              shapes.push(h('path', { d: s.line, class: 'ark-chart-line draw', pathLength: 1, stroke: s.color, 'stroke-width': o.lineWidth ?? 2 }));
            } else if (kind === 'area') {
              if (o.gradient) {
                const gid = `ark-grad-${uid}-${s.key}`;
                shapes.push(h('defs', h('linearGradient', { id: gid, x1: 0, y1: 0, x2: 0, y2: 1 }, [
                  h('stop', { offset: '5%', 'stop-color': s.color, 'stop-opacity': 0.8 }),
                  h('stop', { offset: '95%', 'stop-color': s.color, 'stop-opacity': 0.1 })
                ])));
                shapes.push(h('path', { d: s.area, fill: `url(#${gid})`, class: 'ark-chart-area' }));
              } else {
                shapes.push(h('path', { d: s.area, fill: s.color, 'fill-opacity': o.areaOpacity ?? 0.4, class: 'ark-chart-area' }));
              }
              shapes.push(h('path', { d: s.line, class: 'ark-chart-line', stroke: s.color, 'stroke-width': Math.max(1, (o.lineWidth ?? 2) / 2) }));
            } else {
              shapes.push(h('path', { d: s.bars, fill: s.color, class: 'ark-chart-bars' }));
            }
            if (s.dots) {
              shapes.push(h('g', { fill: s.color, class: 'ark-chart-dots' }, s.dots.map(([x, y]) => h('circle', { cx: x, cy: y, r: 3 }))));
            }
          }
          const enterCls = kind === 'bar' ? (horizontal ? 'enter-grow-x' : 'enter-grow-y') : (kind === 'area' ? 'enter-reveal' : 'enter-draw');
          svg.push(h('g', {
            key: sk, class: ['ark-chart-series', enterCls],
            style: { transformOrigin: horizontal ? `${g.base}px 0` : `0 ${g.base}px` }
          }, shapes));
          if (tooltip && i >= 0 && i < g.positions.length && kind !== 'bar') {
            const c = g.positions[i];
            svg.push(h('path', { d: `M${c} ${g.plotT} L${c} ${g.plotT + g.plotH}`, class: 'ark-chart-cursor-line' }));
            for (const s of g.series) {
              svg.push(h('circle', { cx: c, cy: s.points[i], r: 4, fill: s.color, class: 'ark-chart-active-dot' }));
            }
          }
          kids.push(h('svg', { class: 'ark-chart-svg', width: W, height: H, viewBox: `0 0 ${W} ${H}` }, svg));
          kids.push(...axisLabels(g.labels));
          if (tooltip && i >= 0 && i < rows.length) {
            const fv = fmtValue(o);
            let items = g.series.map((s) => ({ key: s.key, label: s.label, value: fv(value(rows[i], s.key)), color: s.color }));
            if (o.stacked) {
              items = items.reverse();
            }
            const c = g.positions[Math.max(0, Math.min(g.positions.length - 1, i))] ?? 0;
            const [tx, ty] = horizontal ? M.tooltipPlace(pt.x, c, size.w, size.h, W, H, 12) : M.tooltipPlace(c, pt.y, size.w, size.h, W, H, 12);
            kids.push(h('div', { ref: tip, class: 'ark-chart-tip-pos', style: { left: `${tx}px`, top: `${ty}px` } },
              tooltipCard(rows[i].label, items, indicator)));
          }
        }
        const box = h('div', {
          ref: el,
          class: 'ark-chart-box',
          style: { height: `${H}px` },
          role: 'img',
          'aria-label': `${kind} chart: ${series.map((s) => s.label).join(', ')}`,
          ...pointer((x, y) => {
            pt.x = x;
            pt.y = y;
            const idx = M.nearestIndex(g.positions, horizontal ? y : x);
            if (idx !== active.value) {
              active.value = idx;
              typeof o.onActiveChange === 'function' && o.onActiveChange(idx);
            }
          }, () => {
            if (active.value !== -1) {
              active.value = -1;
              typeof o.onActiveChange === 'function' && o.onActiveChange(-1);
            }
          })
        }, kids);
        return h('div', { class: 'ark-chart', style: n.style, ...n.events }, [
          box,
          o.legend ? legend(series.map((s, k) => ({ key: s.key, label: s.label, color: chartColor(s.color, k) })), state, W < 360) : null
        ]);
      };
    }
  });
  return (n) => h(Comp, { n });
}

// ------------------------------------------------------------------------------------------------ pie / donut

function pieChart(defaultInner) {
  const Comp = defineComponent({
    name: defaultInner > 0 ? 'SDonutChart' : 'SPieChart',
    props: { n: { type: Object, required: true } },
    setup(props) {
      const { el, width, measured } = useWidth(320);
      const state = useChartState();
      const active = ref(-1);
      const pt = reactive({ x: 0, y: 0 });
      const { tip, size } = useTipSize();
      const uid = chartUid();
      return () => {
        const n = props.n;
        const o = n.props;
        const { series, rows } = chartData(n, true);
        const valueKey = o.valueKey ?? 'value';
        const chartHeight = o.chartHeight ?? 250;
        const W = width.value;
        const D = measured.value ? Math.max(80, Math.min(chartHeight, W)) : chartHeight;
        const activeGrow = o.activeGrow !== false;
        const cx = W / 2;
        const cy = D / 2;
        const r1 = Math.max(4, D / 2 - (activeGrow ? GROW : 2));
        const r0 = r1 * Math.max(0, Math.min(0.95, o.innerRatio ?? defaultInner));
        const shown = [];
        rows.forEach((r, i) => {
          if (!state.isHidden(r.label)) {
            shown.push(i);
          }
        });
        const values = shown.map((i) => value(rows[i], valueKey));
        const arcs = M.pieArcs(values, 0, M.TAU, (o.padAngle ?? 0) * Math.PI / 180);
        const slices = shown.map((ri, j) => ({
          key: rows[ri].label, label: configLabel(series, rows[ri].label), color: configColor(series, rows[ri].label, ri),
          value: values[j], row: ri, a0: arcs[j].a0, a1: arcs[j].a1
        }));
        const kids = [];
        if (rows.length === 0) {
          kids.push(h('div', { class: 'ark-chart-empty-text' }, String(o.emptyText ?? 'No data')));
        } else {
          const paths = slices.map((s) => h('path', {
            d: M.arcPath(cx, cy, r0, r1 + (activeGrow && s.row === active.value ? GROW : 0), s.a0, s.a1, false),
            fill: s.color, class: 'ark-chart-slice'
          }));
          const mid = `ark-sweep-${uid}`;
          kids.push(h('svg', { class: 'ark-chart-svg', width: W, height: D, viewBox: `0 0 ${W} ${D}` }, [
            sweepMask(mid, cx, cy, r1 + GROW),
            h('g', { key: dataKey(slices.map((s) => [s.key, s.value]), W > 0), mask: `url(#${mid})` }, paths)
          ]));
          if (o.centerValue || o.centerLabel) {
            kids.push(h('div', { class: 'ark-chart-center', style: { width: `${W}px`, height: `${D}px` } }, [
              o.centerValue ? h('div', { class: 'ark-chart-center-value' }, String(o.centerValue)) : null,
              o.centerLabel ? h('div', { class: 'ark-chart-center-label' }, String(o.centerLabel)) : null
            ]));
          }
          const tipSlice = slices.find((s) => s.row === active.value);
          if (o.tooltip !== false && tipSlice) {
            const [tx, ty] = M.tooltipPlace(pt.x, pt.y, size.w, size.h, W, D, 12);
            kids.push(h('div', { ref: tip, class: 'ark-chart-tip-pos', style: { left: `${tx}px`, top: `${ty}px` } },
              tooltipCard('', [{ key: tipSlice.key, label: tipSlice.label, value: fmtValue(o)(tipSlice.value), color: tipSlice.color }],
                enumName(o.indicator) ?? 'dot')));
          }
        }
        const box = h('div', {
          ref: el, class: 'ark-chart-box', style: { height: `${D}px` }, role: 'img', 'aria-label': 'pie chart',
          ...pointer((x, y) => {
            pt.x = x;
            pt.y = y;
            const j = M.arcIndex(arcs, cx, cy, r0, r1, x, y, GROW);
            const idx = j >= 0 && j < slices.length ? slices[j].row : -1;
            if (idx !== active.value) {
              active.value = idx;
              typeof o.onActiveChange === 'function' && o.onActiveChange(idx);
            }
          }, () => {
            active.value = -1;
          })
        }, kids);
        return h('div', { class: 'ark-chart', style: n.style, ...n.events }, [
          box,
          o.legend ? legend(rows.map((r, i) => ({ key: r.label, label: configLabel(series, r.label), color: configColor(series, r.label, i) })), state, W < 360) : null
        ]);
      };
    }
  });
  return (n) => h(Comp, { n });
}

/** Mask that sweeps clockwise from 12 o'clock (pie / radial enter animation). */
function sweepMask(id, cx, cy, r) {
  const rr = r / 2 + 1;
  const c = 2 * Math.PI * rr;
  return h('defs', h('mask', { id }, h('circle', {
    cx, cy, r: rr, fill: 'none', stroke: '#fff', 'stroke-width': r + 2, class: 'ark-chart-sweep',
    style: { '--c': c, strokeDasharray: `${c} ${c}`, transform: `rotate(-90deg)`, transformOrigin: `${cx}px ${cy}px` }
  })));
}

// ------------------------------------------------------------------------------------------------ radial

const RadialComp = defineComponent({
  name: 'SRadialChart',
  props: { n: { type: Object, required: true } },
  setup(props) {
    const { el, width, measured } = useWidth(320);
    const state = useChartState();
    const active = ref(-1);
    const pt = reactive({ x: 0, y: 0 });
    const { tip, size } = useTipSize();
    const uid = chartUid();
    return () => {
      const n = props.n;
      const o = n.props;
      const { series, rows } = chartData(n, true);
      const valueKey = o.valueKey ?? 'value';
      const chartHeight = o.chartHeight ?? 250;
      const W = width.value;
      const D = measured.value ? Math.max(80, Math.min(chartHeight, W)) : chartHeight;
      const cx = W / 2;
      const cy = D / 2;
      const outer = Math.max(8, D / 2 - 4);
      const inner = outer * Math.max(0, Math.min(0.9, o.innerRatio ?? 0.3));
      const a0 = (o.startAngle ?? 0) * Math.PI / 180;
      const aEnd = (o.endAngle ?? 360) * Math.PI / 180;
      const shown = [];
      rows.forEach((r, i) => {
        if (!state.isHidden(r.label)) {
          shown.push(i);
        }
      });
      let max = o.maxValue ?? 0;
      if (!(max > 0)) {
        shown.forEach((i) => (max = Math.max(max, value(rows[i], valueKey))));
      }
      const m = Math.max(1, shown.length);
      const t = (outer - inner) / m;
      const gap = Math.min(o.ringGap ?? 4, t * 0.4);
      const round = o.rounded !== false;
      const rings = shown.map((ri, j) => {
        const v = value(rows[ri], valueKey);
        const r0 = inner + j * t + gap / 2;
        const frac = max > 0 ? Math.max(0, Math.min(1, v / max)) : 0;
        return {
          key: rows[ri].label, label: configLabel(series, rows[ri].label), color: configColor(series, rows[ri].label, ri),
          value: v, row: ri, r0, r1: r0 + t - gap, a1: a0 + (aEnd - a0) * frac
        };
      });
      const kids = [];
      if (rows.length === 0) {
        kids.push(h('div', { class: 'ark-chart-empty-text' }, String(o.emptyText ?? 'No data')));
      } else {
        const svg = [];
        if (o.track !== false) {
          svg.push(h('path', { d: rings.map((r) => M.arcPath(cx, cy, r.r0, r.r1, a0, aEnd, round)).join(' '), class: 'ark-chart-track' }));
        }
        const mid = `ark-rsweep-${uid}`;
        svg.push(sweepMask(mid, cx, cy, outer + 2));
        svg.push(h('g', { key: dataKey(rings.map((r) => [r.key, r.value]), W > 0), mask: `url(#${mid})` }, rings.map((r) => h('path', {
          d: M.arcPath(cx, cy, r.r0, r.r1, a0, r.a1, round), fill: r.color,
          'fill-opacity': active.value < 0 || r.row === active.value ? 1 : 0.6, class: 'ark-chart-slice'
        }))));
        kids.push(h('svg', { class: 'ark-chart-svg', width: W, height: D, viewBox: `0 0 ${W} ${D}` }, svg));
        if (o.centerValue || o.centerLabel) {
          kids.push(h('div', { class: 'ark-chart-center', style: { width: `${W}px`, height: `${D}px` } }, [
            o.centerValue ? h('div', { class: 'ark-chart-center-value xl' }, String(o.centerValue)) : null,
            o.centerLabel ? h('div', { class: 'ark-chart-center-label' }, String(o.centerLabel)) : null
          ]));
        }
        const ring = rings.find((r) => r.row === active.value);
        if (o.tooltip !== false && ring) {
          const [tx, ty] = M.tooltipPlace(pt.x, pt.y, size.w, size.h, W, D, 12);
          kids.push(h('div', { ref: tip, class: 'ark-chart-tip-pos', style: { left: `${tx}px`, top: `${ty}px` } },
            tooltipCard('', [{ key: ring.key, label: ring.label, value: fmtValue(o)(ring.value), color: ring.color }], enumName(o.indicator) ?? 'dot')));
        }
      }
      const box = h('div', {
        ref: el, class: 'ark-chart-box', style: { height: `${D}px` }, role: 'img', 'aria-label': 'radial chart',
        ...pointer((x, y) => {
          pt.x = x;
          pt.y = y;
          const j = M.ringIndex(rings.length, inner, outer, Math.hypot(x - cx, y - cy));
          active.value = j >= 0 ? rings[j].row : -1;
        }, () => {
          active.value = -1;
        })
      }, kids);
      return h('div', { class: 'ark-chart', style: n.style, ...n.events }, [
        box,
        o.legend ? legend(rows.map((r, i) => ({ key: r.label, label: configLabel(series, r.label), color: configColor(series, r.label, i) })), state, W < 360) : null
      ]);
    };
  }
});

// ------------------------------------------------------------------------------------------------ radar

const RadarComp = defineComponent({
  name: 'SRadarChart',
  props: { n: { type: Object, required: true } },
  setup(props) {
    const { el, width, measured } = useWidth(320);
    const state = useChartState();
    const active = ref(-1);
    const pt = reactive({ x: 0, y: 0 });
    const { tip, size } = useTipSize();
    return () => {
      const n = props.n;
      const o = n.props;
      const { series, rows } = chartData(n, false);
      const chartHeight = o.chartHeight ?? 250;
      const W = width.value;
      const H = measured.value ? Math.max(120, Math.min(chartHeight, W)) : chartHeight;
      const N = rows.length;
      const label = fmtLabel(o);
      const keys = series.map((s) => s.key).filter((k) => !state.isHidden(k));
      const kids = [];
      let cx = W / 2;
      let cy = H / 2;
      let radius = 0;
      if (N < 3) {
        kids.push(h('div', { class: 'ark-chart-empty-text' }, String(o.emptyText ?? 'No data')));
      } else {
        const texts = rows.map((r) => label(r.label));
        let maxW = 0;
        texts.forEach((t) => (maxW = Math.max(maxW, M.textWidth(t, FS))));
        const roomX = maxW + 8;
        const full = Math.min(W / 2, H / 2) - 4;
        const withLabels = Math.min(W / 2 - roomX, H / 2 - LABEL_H - 6);
        const showLabels = o.labels !== false && withLabels >= full * 0.55;
        radius = Math.max(8, showLabels ? withLabels : full);
        let max = 0;
        keys.forEach((key) => rows.forEach((r) => (max = Math.max(max, value(r, key)))));
        const dom = M.niceDomain(0, max, 4);
        const ticks = M.niceTicks(0, dom[1], 4).filter((t) => t > 0);
        const radii = ticks.map((t) => radius * t / (dom[1] > 0 ? dom[1] : 1));
        if (radii.length === 0) {
          radii.push(radius);
        }
        const svg = [h('path', { d: M.ringsPath(cx, cy, N, radii, enumName(o.gridShape) === 'circle'), class: 'ark-chart-grid solid' })];
        const shapes = [];
        const pts = {};
        keys.forEach((key, s) => {
          const color = configColor(series, key, s);
          const xs = [];
          const ys = [];
          rows.forEach((r, i) => {
            const rr = dom[1] > 0 ? radius * Math.max(0, value(r, key)) / dom[1] : 0;
            const p = M.polar(cx, cy, rr, M.TAU * i / N);
            xs.push(p[0]);
            ys.push(p[1]);
          });
          pts[key] = { xs, ys, color };
          const lw = o.lineWidth ?? 0;
          shapes.push(h('path', {
            d: M.polygonPath(xs, ys), fill: color, 'fill-opacity': o.fillAlpha ?? 0.6,
            stroke: lw > 0 ? color : 'none', 'stroke-width': lw, class: 'ark-chart-radar'
          }));
          if (o.dots) {
            shapes.push(h('g', { fill: color }, xs.map((x, i) => h('circle', { cx: x, cy: ys[i], r: 4 }))));
          }
        });
        svg.push(h('g', { key: dataKey(keys, rows, W > 0), class: 'ark-chart-series enter-scale', style: { transformOrigin: `${cx}px ${cy}px` } }, shapes));
        const i = active.value;
        if (o.tooltip !== false && i >= 0 && i < N) {
          const p = M.polar(cx, cy, radius, M.TAU * i / N);
          svg.push(h('path', { d: `M${cx} ${cy} L${p[0]} ${p[1]}`, class: 'ark-chart-cursor-line' }));
          for (const key of keys) {
            svg.push(h('circle', { cx: pts[key].xs[i], cy: pts[key].ys[i], r: 4, fill: pts[key].color, class: 'ark-chart-active-dot' }));
          }
        }
        kids.push(h('svg', { class: 'ark-chart-svg', width: W, height: H, viewBox: `0 0 ${W} ${H}` }, svg));
        if (showLabels) {
          kids.push(...texts.map((t, k) => {
            const p = M.polar(cx, cy, radius + 8, M.TAU * k / N);
            const w = M.textWidth(t, FS) + 4;
            const sn = Math.sin(M.TAU * k / N);
            const cs = Math.cos(M.TAU * k / N);
            const x = Math.abs(sn) < 0.2 ? p[0] - w / 2 : (sn > 0 ? p[0] : p[0] - w);
            const y = Math.abs(cs) < 0.2 ? p[1] - LABEL_H / 2 : (cs > 0 ? p[1] - LABEL_H : p[1]);
            return h('span', {
              class: 'ark-chart-axis-label',
              style: { left: `${Math.max(0, Math.min(W - w, x))}px`, top: `${Math.max(0, Math.min(H - LABEL_H, y))}px`, width: `${w}px` }
            }, t);
          }));
        }
        if (o.tooltip !== false && i >= 0 && i < N) {
          const fv = fmtValue(o);
          const items = keys.map((key) => ({ key, label: configLabel(series, key), value: fv(value(rows[i], key)), color: pts[key].color }));
          const [tx, ty] = M.tooltipPlace(pt.x, pt.y, size.w, size.h, W, H, 12);
          kids.push(h('div', { ref: tip, class: 'ark-chart-tip-pos', style: { left: `${tx}px`, top: `${ty}px` } },
            tooltipCard(rows[i].label, items, enumName(o.indicator) ?? 'dot')));
        }
      }
      const box = h('div', {
        ref: el, class: 'ark-chart-box', style: { height: `${H}px` }, role: 'img', 'aria-label': 'radar chart',
        ...pointer((x, y) => {
          pt.x = x;
          pt.y = y;
          const d = Math.hypot(x - cx, y - cy);
          active.value = N >= 3 && d <= radius + 24 ? M.spokeIndex(cx, cy, N, x, y) : -1;
        }, () => {
          active.value = -1;
        })
      }, kids);
      return h('div', { class: 'ark-chart', style: n.style, ...n.events }, [
        box,
        o.legend ? legend(series.map((s, k) => ({ key: s.key, label: s.label, color: chartColor(s.color, k) })), state, W < 360) : null
      ]);
    };
  }
});

// ------------------------------------------------------------------------------------------------ sparkline

const SparklineComp = defineComponent({
  name: 'SSparkline',
  props: { n: { type: Object, required: true } },
  setup(props) {
    const { el, width } = useWidth(120);
    return () => {
      const n = props.n;
      const o = n.props;
      const vals = (Array.isArray(o.values) ? o.values : []).map(Number);
      const W = width.value;
      const H = o.chartHeight ?? 32;
      const lw = o.lineWidth ?? 1.5;
      const color = chartColor(o.color ?? 'chart-1', 0);
      const kids = [];
      if (vals.length > 0) {
        const pad = Math.max(lw, o.endDot ? 3 : 0) + 1;
        let lo = Infinity;
        let hi = -Infinity;
        vals.forEach((v) => {
          if (isFinite(v)) {
            lo = Math.min(lo, v);
            hi = Math.max(hi, v);
          }
        });
        if (lo > hi) {
          lo = 0;
          hi = 1;
        }
        const scale = new M.LinearScale(lo, hi, H - pad, pad);
        const xs = M.pointPositions(vals.length, pad, W - pad);
        const ys = vals.map((v) => (isFinite(v) ? scale.map(v) : H - pad));
        const curve = o.curve ?? 'monotone';
        const g = [];
        if (o.filled !== false) {
          g.push(h('path', { d: M.areaPath(xs, ys, xs.map(() => H), curve), fill: color, 'fill-opacity': 0.15, class: 'ark-chart-area' }));
        }
        g.push(h('path', { d: M.curvePath(xs, ys, curve), class: 'ark-chart-line', stroke: color, 'stroke-width': lw }));
        if (o.endDot) {
          g.push(h('circle', { cx: xs[xs.length - 1], cy: ys[ys.length - 1], r: 2.5, fill: color }));
        }
        kids.push(h('svg', { class: 'ark-chart-svg', width: W, height: H, viewBox: `0 0 ${W} ${H}` },
          h('g', { key: dataKey(vals, W > 0), class: 'ark-chart-series enter-reveal' }, g)));
      }
      const fixedW = n.style?.width;
      return h('div', {
        ref: el, class: 'ark-sparkline', style: [{ width: fixedW ? undefined : '100%', minWidth: fixedW ? undefined : '80px', height: `${H}px` }, n.style], ...n.events
      }, kids);
    };
  }
});

// ------------------------------------------------------------------------------------------------ container

const ContainerComp = defineComponent({
  name: 'SChartContainer',
  props: { n: { type: Object, required: true } },
  setup(props) {
    const st = reactive({ hidden: [] });
    provide(CHART_KEY, st);
    const { el, width } = useWidth(480);
    const api = { isHidden: (k) => st.hidden.includes(k), toggle: (k) => { st.hidden = st.hidden.includes(k) ? st.hidden.filter((x) => x !== k) : [...st.hidden, k]; } };
    return () => {
      const n = props.n;
      const o = n.props;
      const series = seriesList(o.config) ?? seriesList(lookupConst(n, CONFIG_REFS[n.refs?.config])) ?? SAMPLE_CONFIG.series;
      const items = series.map((s, k) => ({ key: s.key, label: s.label, color: chartColor(s.color, k) }));
      const lg = o.legend && !o.empty ? legend(items, api, width.value < 360, o.legendToggle !== false) : null;
      const top = enumName(o.legendPlacement) === 'top';
      return h('div', { ref: el, class: 'ark-chart-container', style: [{ width: '100%' }, n.style], ...n.events }, [
        top ? lg : null,
        o.empty ? emptyBox(o.emptyText, o.emptyHeight ?? 200) : n.children(),
        top ? null : lg
      ]);
    };
  }
});

export const charts = {
  SLineChart: cartesian('line'),
  SAreaChart: cartesian('area'),
  SBarChart: cartesian('bar'),
  SPieChart: pieChart(0),
  SDonutChart: pieChart(0.6),
  SRadialChart: (n) => h(RadialComp, { n }),
  SRadarChart: (n) => h(RadarComp, { n }),
  SSparkline: (n) => h(SparklineComp, { n }),
  SChartContainer: (n) => h(ContainerComp, { n }),
  SChartEmpty: (n) => emptyBox(n.props.text, n.props.boxHeight ?? 200, n),
  SChartLegend: (n) => {
    const series = seriesList(n.props.config) ?? [];
    const keys = Array.isArray(n.props.keys) ? n.props.keys : series.map((s) => s.key);
    const noop = { isHidden: () => false, toggle() {} };
    return legend(keys.map((k, i) => ({ key: k, label: configLabel(series, k), color: configColor(series, k, i) })), noop, !!n.props.compact, false);
  },
  SChartTooltipCard: (n) => tooltipCard(String(n.props.title ?? ''), (n.props.items || []).map((it) => ({
    key: it.key ?? it.args?.[0], label: it.label ?? it.args?.[1], value: it.value ?? it.args?.[2], color: chartColor(it.color ?? it.args?.[3], 0)
  })), enumName(n.props.indicator) ?? 'dot')
};
