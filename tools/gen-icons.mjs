// Generates library/src/main/ets/icons/LucideIcons.ets from lucide-static's icon-nodes.json.
//
//   npm pack lucide-static@1.54.0 && tar -xzf lucide-static-1.54.0.tgz
//   node tools/gen-icons.mjs <path-to>/package/icon-nodes.json
//
// Every SVG element (path/circle/rect/line/ellipse/polyline/polygon) is converted to a path string with
// absolute commands only (ArkUI Path support for relative commands is undocumented), numbers rounded to
// 3 decimals. The icon list lives in tools/icons.txt (one lucide name per line, '#' comments).
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const nodesPath = process.argv[2];
if (!nodesPath) {
  console.error('usage: node tools/gen-icons.mjs <icon-nodes.json>');
  process.exit(1);
}
const nodes = JSON.parse(readFileSync(nodesPath, 'utf8'));
const wanted = readFileSync(join(root, 'tools/icons.txt'), 'utf8')
  .split(/\r?\n/).map((l) => l.replace(/#.*/, '').trim()).filter(Boolean);
const version = JSON.parse(readFileSync(join(dirname(nodesPath), 'package.json'), 'utf8')).version;

const r = (n) => {
  const v = Math.round(n * 1000) / 1000;
  return Object.is(v, -0) ? '0' : String(v);
};

// ---- path normalisation: relative → absolute, shorthand kept (H/V/S/T are absolute variants) ----
const ARGS = { M: 2, L: 2, T: 2, H: 1, V: 1, C: 6, S: 4, Q: 4, A: 7, Z: 0 };

// Arc flags may be written without separators ("a1 1 0 01 2 2"); split them out.
function tokenizeArcAware(d) {
  const toks = [];
  let cmd = '';
  let idx = 0;
  const re = /([MmLlHhVvCcSsQqTtAaZz])|([-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?)/g;
  let m;
  while ((m = re.exec(d)) !== null) {
    if (m[1]) {
      cmd = m[1];
      idx = 0;
      toks.push(cmd);
      continue;
    }
    let s = m[2];
    if ((cmd === 'a' || cmd === 'A')) {
      const pos = idx % 7;
      if ((pos === 3 || pos === 4) && s.length > 1 && /^[01]/.test(s)) {
        // flag glued to the next number
        toks.push(Number(s[0]));
        idx++;
        re.lastIndex = m.index + 1;
        continue;
      }
    }
    toks.push(Number(s));
    idx++;
  }
  return toks;
}

function absolutize(d) {
  const t = tokenizeArcAware(d);
  let i = 0;
  let cx = 0, cy = 0, sx = 0, sy = 0;
  let out = '';
  let cmd = '';
  while (i < t.length) {
    if (typeof t[i] === 'string') {
      cmd = t[i++];
    } else if (cmd === 'M') {
      cmd = 'L';
    } else if (cmd === 'm') {
      cmd = 'l';
    }
    const up = cmd.toUpperCase();
    const rel = cmd !== up;
    const n = ARGS[up];
    if (up === 'Z') {
      out += 'Z';
      cx = sx;
      cy = sy;
      continue;
    }
    const a = t.slice(i, i + n);
    i += n;
    if (a.length < n || a.some((v) => typeof v !== 'number')) {
      throw new Error(`bad path data near "${cmd}" in ${d}`);
    }
    switch (up) {
      case 'M':
      case 'L':
      case 'T': {
        const x = rel ? cx + a[0] : a[0];
        const y = rel ? cy + a[1] : a[1];
        out += `${up}${r(x)} ${r(y)}`;
        cx = x;
        cy = y;
        if (up === 'M') {
          sx = x;
          sy = y;
        }
        break;
      }
      case 'H': {
        const x = rel ? cx + a[0] : a[0];
        out += `H${r(x)}`;
        cx = x;
        break;
      }
      case 'V': {
        const y = rel ? cy + a[0] : a[0];
        out += `V${r(y)}`;
        cy = y;
        break;
      }
      case 'C': {
        const p = a.map((v, k) => (rel ? v + (k % 2 === 0 ? cx : cy) : v));
        out += `C${p.map(r).join(' ')}`;
        cx = p[4];
        cy = p[5];
        break;
      }
      case 'S':
      case 'Q': {
        const p = a.map((v, k) => (rel ? v + (k % 2 === 0 ? cx : cy) : v));
        out += `${up}${p.map(r).join(' ')}`;
        cx = p[2];
        cy = p[3];
        break;
      }
      case 'A': {
        const x = rel ? cx + a[5] : a[5];
        const y = rel ? cy + a[6] : a[6];
        out += `A${r(a[0])} ${r(a[1])} ${r(a[2])} ${a[3] ? 1 : 0} ${a[4] ? 1 : 0} ${r(x)} ${r(y)}`;
        cx = x;
        cy = y;
        break;
      }
    }
  }
  return out;
}

const num = (v, def = 0) => (v === undefined ? def : Number(v));

// Four 90° arcs: a full circle written as two exact 180° arcs is numerically ambiguous (the arc centre
// solution degenerates) and some renderers then draw only one half after scaling.
function circle(cx, cy, rx, ry) {
  const a = (x, y) => `A${r(rx)} ${r(ry)} 0 0 0 ${r(x)} ${r(y)}`;
  return `M${r(cx - rx)} ${r(cy)}` + a(cx, cy + ry) + a(cx + rx, cy) + a(cx, cy - ry) + a(cx - rx, cy) + 'Z';
}

function rect(a) {
  const x = num(a.x), y = num(a.y), w = num(a.width), h = num(a.height);
  let rx = a.rx !== undefined ? num(a.rx) : (a.ry !== undefined ? num(a.ry) : 0);
  let ry = a.ry !== undefined ? num(a.ry) : rx;
  rx = Math.min(rx, w / 2);
  ry = Math.min(ry, h / 2);
  if (rx === 0 || ry === 0) {
    return `M${r(x)} ${r(y)}H${r(x + w)}V${r(y + h)}H${r(x)}Z`;
  }
  return `M${r(x + rx)} ${r(y)}H${r(x + w - rx)}A${r(rx)} ${r(ry)} 0 0 1 ${r(x + w)} ${r(y + ry)}` +
    `V${r(y + h - ry)}A${r(rx)} ${r(ry)} 0 0 1 ${r(x + w - rx)} ${r(y + h)}H${r(x + rx)}` +
    `A${r(rx)} ${r(ry)} 0 0 1 ${r(x)} ${r(y + h - ry)}V${r(y + ry)}A${r(rx)} ${r(ry)} 0 0 1 ${r(x + rx)} ${r(y)}Z`;
}

function points(p, close) {
  const n = p.trim().split(/[\s,]+/).map(Number);
  let s = '';
  for (let k = 0; k + 1 < n.length; k += 2) {
    s += `${k === 0 ? 'M' : 'L'}${r(n[k])} ${r(n[k + 1])}`;
  }
  return close ? s + 'Z' : s;
}

function elementToPath([tag, a]) {
  switch (tag) {
    case 'path':
      return absolutize(a.d);
    case 'circle':
      return circle(num(a.cx), num(a.cy), num(a.r), num(a.r));
    case 'ellipse':
      return circle(num(a.cx), num(a.cy), num(a.rx), num(a.ry));
    case 'rect':
      return rect(a);
    case 'line':
      return `M${r(num(a.x1))} ${r(num(a.y1))}L${r(num(a.x2))} ${r(num(a.y2))}`;
    case 'polyline':
      return points(a.points, false);
    case 'polygon':
      return points(a.points, true);
    default:
      throw new Error(`unsupported element ${tag}`);
  }
}

const missing = [];
const entries = [];
for (const name of [...new Set(wanted)].sort()) {
  const n = nodes[name];
  if (!n) {
    missing.push(name);
    continue;
  }
  const paths = n.map(elementToPath);
  entries.push(`  ['${name}', i([${paths.map((p) => `'${p}'`).join(', ')}])],`);
}
if (missing.length) {
  console.error(`unknown lucide icons: ${missing.join(', ')}`);
  process.exit(1);
}

const out = `// AUTO-GENERATED by tools/gen-icons.mjs from lucide-static v${version} — do not edit by hand.
// Lucide icons, ISC licence (https://lucide.dev/license). Absolute path commands in a 24×24 box.
import { SparkIconData } from './SparkIconData';

function i(paths: string[]): SparkIconData {
  return new SparkIconData(paths);
}

export const LUCIDE_ICONS: Map<string, SparkIconData> = new Map<string, SparkIconData>([
${entries.join('\n')}
]);
`;
writeFileSync(join(root, 'library/src/main/ets/icons/LucideIcons.ets'), out);
console.log(`generated ${entries.length} icons (${Math.round(out.length / 1024)} KB)`);
