/**
 * Small SVG imitations of the SparkUI chart family. Snippets usually reference `config` / `rows` defined
 * elsewhere, so missing data falls back to the shadcn sample data the gallery uses.
 */
import { h } from 'vue';

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June'];
const SAMPLE = { desktop: [186, 305, 237, 73, 209, 214], mobile: [80, 200, 120, 190, 130, 140] };
const BROWSERS = [['chrome', 'Chrome', 275], ['safari', 'Safari', 200], ['firefox', 'Firefox', 187], ['edge', 'Edge', 173], ['other', 'Other', 90]];

function colorOf(c, i) {
  const v = c || `chart-${(i % 5) + 1}`;
  if (String(v).startsWith('var(') || String(v).startsWith('#') || String(v).startsWith('oklch')) {
    return v;
  }
  return `var(--${v})`;
}

/** SparkChartConfig → [{ key, label, color }] */
function seriesOf(config, multi) {
  const list = config?.series ?? config?.args?.[0];
  if (Array.isArray(list) && list.length) {
    return list.map((s, i) => ({
      key: s.key ?? s.args?.[0], label: s.label ?? s.args?.[1] ?? s.args?.[0], color: colorOf(s.color ?? s.args?.[2], i)
    }));
  }
  const base = [{ key: 'desktop', label: 'Desktop', color: 'var(--chart-1)' }];
  return multi ? [...base, { key: 'mobile', label: 'Mobile', color: 'var(--chart-2)' }] : base;
}

/** SparkChartRow[] → [{ label, values: {key: n} }] */
function rowsOf(data) {
  if (Array.isArray(data) && data.length) {
    return data.map((r) => ({ label: String(r.label ?? r.args?.[0] ?? ''), values: r.values ?? r.args?.[1] ?? {} }));
  }
  return MONTHS.map((m, i) => ({ label: m, values: { desktop: SAMPLE.desktop[i], mobile: SAMPLE.mobile[i] } }));
}

function legend(series) {
  return h('div', { class: 'ark-chart-legend' }, series.map((s) => h('span', [h('i', { style: { background: s.color } }), s.label])));
}

function frame(n, cls, kids) {
  return h('div', { class: ['ark-chart', cls], style: [{ width: '100%', minWidth: '260px' }, n.style] }, kids);
}

function smoothPath(pts) {
  if (pts.length < 2) {
    return '';
  }
  let d = `M${pts[0][0]},${pts[0][1]}`;
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1];
    const [x1, y1] = pts[i];
    const cx = (x0 + x1) / 2;
    d += ` C${cx},${y0} ${cx},${y1} ${x1},${y1}`;
  }
  return d;
}

function linePath(pts, curve) {
  if (curve === 'linear') {
    return pts.map((p, i) => `${i ? 'L' : 'M'}${p[0]},${p[1]}`).join(' ');
  }
  if (curve === 'step') {
    return pts.map((p, i) => (i ? `H${(pts[i - 1][0] + p[0]) / 2} V${p[1]} H${p[0]}` : `M${p[0]},${p[1]}`)).join(' ');
  }
  return smoothPath(pts);
}

export function cartesian(kind) {
  return (n) => {
    const o = n.props;
    const multi = !!(o.stacked || o.legend) || /devices/i.test(n.refs?.config || '');
    const series = seriesOf(o.config, multi);
    const rows = rowsOf(o.data);
    const W = 480;
    const H = o.chartHeight ?? 200;
    const padL = o.valueAxis ? 36 : 8;
    const padB = 22;
    const stacked = !!o.stacked;
    const totals = rows.map((r) => series.reduce((a, s) => a + Math.max(0, Number(r.values[s.key]) || 0), 0));
    const all = rows.flatMap((r) => series.map((s) => Number(r.values[s.key]) || 0));
    const max = Math.max(1, stacked ? Math.max(...totals) : Math.max(...all));
    const min = Math.min(0, ...all);
    const y = (v) => 8 + (H - padB - 8) * (1 - (v - min) / (max - min || 1));
    const band = (W - padL - 8) / rows.length;
    const xc = (i) => padL + band * i + band / 2;
    const kids = [];
    // grid
    for (let k = 0; k <= 4; k++) {
      const v = min + ((max - min) * k) / 4;
      kids.push(h('line', { x1: padL, x2: W - 8, y1: y(v), y2: y(v), stroke: 'var(--border)', 'stroke-dasharray': '3 3' }));
      if (o.valueAxis) {
        kids.push(h('text', { x: padL - 6, y: y(v) + 4, 'text-anchor': 'end', class: 'ark-chart-tick' }, String(Math.round(v))));
      }
    }
    rows.forEach((r, i) => {
      const label = typeof o.labelFormatter === 'function' ? o.labelFormatter(r.label) : r.label.slice(0, 3);
      kids.push(h('text', { x: xc(i), y: H - 6, 'text-anchor': 'middle', class: 'ark-chart-tick' }, String(label)));
    });
    if (kind === 'bar') {
      const groupW = band * 0.7;
      rows.forEach((r, i) => {
        let acc = 0;
        series.forEach((s, j) => {
          const v = Number(r.values[s.key]) || 0;
          const w = stacked ? groupW : groupW / series.length;
          const x = stacked ? xc(i) - groupW / 2 : xc(i) - groupW / 2 + j * w;
          const y0 = stacked ? y(acc) : y(Math.max(0, min));
          const y1 = stacked ? y(acc + v) : y(v);
          acc += v;
          kids.push(h('rect', {
            x: x + 1, y: Math.min(y0, y1), width: Math.max(1, w - 2), height: Math.abs(y0 - y1),
            rx: Math.min(o.barRadius ?? 4, w / 2), fill: v < 0 ? 'var(--destructive)' : s.color
          }));
        });
      });
    } else {
      const base = rows.map(() => 0);
      series.forEach((s) => {
        const pts = rows.map((r, i) => {
          const v = (Number(r.values[s.key]) || 0) + (stacked ? base[i] : 0);
          return [xc(i), y(v)];
        });
        const lower = rows.map((r, i) => [xc(i), y(stacked ? base[i] : Math.max(0, min))]);
        rows.forEach((r, i) => {
          base[i] += Number(r.values[s.key]) || 0;
        });
        const d = linePath(pts, o.curve);
        if (kind === 'area') {
          const back = linePath([...lower].reverse(), o.curve).replace(/^M/, 'L');
          kids.push(h('path', { d: `${d} ${back} Z`, fill: s.color, 'fill-opacity': o.gradient ? 0.25 : 0.4 }));
        }
        kids.push(h('path', { d, fill: 'none', stroke: s.color, 'stroke-width': 2 }));
        if (o.dots) {
          pts.forEach((p) => kids.push(h('circle', { cx: p[0], cy: p[1], r: 3.5, fill: s.color })));
        }
      });
    }
    return frame(n, 'cartesian', [
      h('svg', { viewBox: `0 0 ${W} ${H}`, width: '100%', preserveAspectRatio: 'none', style: { display: 'block', overflow: 'visible' } }, kids),
      o.legend || series.length > 1 ? legend(series) : null
    ]);
  };
}

function pieData(o) {
  const series = seriesOf(o.config, false);
  if (Array.isArray(o.data) && o.data.length) {
    const key = series[0]?.key;
    const rows = rowsOf(o.data);
    return rows.map((r, i) => ({ label: r.label, value: Number(r.values[key] ?? Object.values(r.values)[0]) || 0, color: `var(--chart-${(i % 5) + 1})` }));
  }
  return BROWSERS.map(([, label, v], i) => ({ label, value: v, color: `var(--chart-${(i % 5) + 1})` }));
}

export function pie(donut) {
  return (n) => {
    const o = n.props;
    const data = pieData(o);
    const total = data.reduce((a, d) => a + d.value, 0) || 1;
    const R = 80;
    const r = donut || o.innerRadius ? (o.innerRadius ?? 50) : 0;
    let a0 = -Math.PI / 2;
    const arcs = data.map((d) => {
      const a1 = a0 + (d.value / total) * Math.PI * 2;
      const large = a1 - a0 > Math.PI ? 1 : 0;
      const p = (rad, ang) => `${100 + rad * Math.cos(ang)},${100 + rad * Math.sin(ang)}`;
      const path = r ?
        `M${p(R, a0)} A${R},${R} 0 ${large} 1 ${p(R, a1)} L${p(r, a1)} A${r},${r} 0 ${large} 0 ${p(r, a0)} Z` :
        `M100,100 L${p(R, a0)} A${R},${R} 0 ${large} 1 ${p(R, a1)} Z`;
      a0 = a1;
      return h('path', { d: path, fill: d.color, stroke: 'var(--background)', 'stroke-width': 2 });
    });
    const center = donut && o.centerLabel !== undefined ? [
      h('text', { x: 100, y: 100, 'text-anchor': 'middle', class: 'ark-chart-center' }, String(o.centerValue ?? total)),
      h('text', { x: 100, y: 118, 'text-anchor': 'middle', class: 'ark-chart-tick' }, String(o.centerLabel))
    ] : [];
    return frame(n, 'pie', [
      h('svg', { viewBox: '0 0 200 200', width: 200, height: 200 }, [...arcs, ...center]),
      legend(data.map((d) => ({ label: d.label, color: d.color })))
    ]);
  };
}

export function radial(n) {
  const o = n.props;
  const data = pieData(o).slice(0, 5);
  const max = Math.max(...data.map((d) => d.value), 1);
  const rings = data.map((d, i) => {
    const r = 86 - i * 14;
    const c = 2 * Math.PI * r;
    return [
      h('circle', { cx: 100, cy: 100, r, fill: 'none', stroke: 'var(--muted)', 'stroke-width': 10 }),
      h('circle', { cx: 100, cy: 100, r, fill: 'none', stroke: d.color, 'stroke-width': 10, 'stroke-linecap': 'round',
        'stroke-dasharray': `${(d.value / max) * c * 0.75} ${c}`, transform: 'rotate(-90 100 100)' })
    ];
  });
  return frame(n, 'pie', [h('svg', { viewBox: '0 0 200 200', width: 200, height: 200 }, rings.flat()), legend(data)]);
}

export function radar(n) {
  const o = n.props;
  const series = seriesOf(o.config, !!o.legend || /devices/i.test(n.refs?.config || ''));
  const rows = rowsOf(o.data);
  const N = rows.length;
  const max = Math.max(1, ...rows.flatMap((r) => series.map((s) => Number(r.values[s.key]) || 0)));
  const pt = (i, f) => {
    const a = -Math.PI / 2 + (i / N) * Math.PI * 2;
    return [120 + 80 * f * Math.cos(a), 110 + 80 * f * Math.sin(a)];
  };
  const kids = [];
  for (let k = 1; k <= 4; k++) {
    const ring = rows.map((_, i) => pt(i, k / 4).join(',')).join(' ');
    kids.push(o.grid === 'circle' ?
      h('circle', { cx: 120, cy: 110, r: 20 * k, fill: 'none', stroke: 'var(--border)' }) :
      h('polygon', { points: ring, fill: 'none', stroke: 'var(--border)' }));
  }
  rows.forEach((r, i) => {
    const [x, y] = pt(i, 1.18);
    kids.push(h('text', { x, y: y + 4, 'text-anchor': 'middle', class: 'ark-chart-tick' }, r.label.slice(0, 3)));
  });
  series.forEach((s) => {
    const pts = rows.map((r, i) => pt(i, (Number(r.values[s.key]) || 0) / max).join(',')).join(' ');
    kids.push(h('polygon', { points: pts, fill: s.color, 'fill-opacity': 0.4, stroke: s.color, 'stroke-width': 1.5 }));
  });
  return frame(n, 'pie', [h('svg', { viewBox: '0 0 240 220', width: 240, height: 220 }, kids), series.length > 1 ? legend(series) : null]);
}

export function chartContainer(n) {
  const o = n.props;
  if (o.empty) {
    return h('div', { class: 'ark-chart ark-chart-empty', style: n.style }, String(o.emptyText ?? 'No data'));
  }
  return h('div', { class: 'ark-chart-container', style: [{ width: '100%' }, n.style] }, n.children());
}
