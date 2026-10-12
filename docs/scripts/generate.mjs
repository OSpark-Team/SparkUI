// Generates the data and component pages of the docs site from the SparkUI sources (read-only):
//
//   gallery/src/main/ets/shell/Nav.ets       → sidebar groups and page ids
//   gallery/src/main/ets/pages/Index.ets     → page id → doc struct
//   gallery/src/main/ets/docs/*.ets          → headings, leads, DemoBlock code strings, demo state
//   library/src/main/ets/**/*.ets            → API tables (@Param / @Event / @BuilderParam)
//   library/Index.ets                        → which structs are public
//   library/.../presets/Presets.ets          → previewer theme CSS
//   library/.../icons/LucideIcons.ets        → previewer icons
//
// Outputs (all git-ignored): .vitepress/generated/*, components/*.md (zh) and en/components/*.md.
// Run with `npm run docs:gen`; the VitePress config also runs it on start-up.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractApi } from './lib/extract-api.mjs';
import { extractDemos } from './lib/extract-demos.mjs';
import { loadPresets, previewerCss } from './lib/gen-tokens.mjs';
import { parseProgram } from '../.vitepress/theme/previewer/parser.js';
import { Interpreter, Scope } from '../.vitepress/theme/previewer/interp.js';
import { PAGE_EXTRA_STRUCTS, GUIDE_PAGE_IDS, LOCALES } from './lib/pages-config.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const DOCS = path.resolve(here, '..');
const REPO = path.resolve(DOCS, '..');
const LIB = path.join(REPO, 'library');
const GALLERY = path.join(REPO, 'gallery/src/main/ets');
const OUT = path.join(DOCS, '.vitepress/generated');

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  if (fs.existsSync(file) && fs.readFileSync(file, 'utf8') === content) {
    return; // keep mtimes stable so the dev server does not reload needlessly
  }
  fs.writeFileSync(file, content);
}

// ------------------------------------------------------------------------------------------------ sources

function readNav() {
  const program = parseProgram(fs.readFileSync(path.join(GALLERY, 'shell/Nav.ets'), 'utf8'));
  // new <Any>NavGroup(title, items) / new <Any>NavItem(id, title, icon): class names may change
  const scope = new Scope();
  new Interpreter({}, {}).exec(program.body.filter((s) => s.type === 'var' && s.name === 'NAV'), scope);
  const raw = scope.lookup('NAV').value;
  const nav = Array.isArray(raw) ? raw.map((g) => ({
    title: g.args?.[0] ?? g.title,
    items: (g.args?.[1] ?? g.items ?? []).map((it) => ({
      id: it.args?.[0] ?? it.id, title: it.args?.[1] ?? it.title, icon: it.args?.[2] ?? it.icon
    }))
  })) : undefined;
  if (!Array.isArray(nav)) {
    throw new Error('Could not read NAV from gallery/src/main/ets/shell/Nav.ets');
  }
  return nav;
}

/** `if (this.page === 'x') { XDoc() } else if …` in struct DocContent → { x: 'XDoc' } */
function readPageMap() {
  const program = parseProgram(fs.readFileSync(path.join(GALLERY, 'pages/Index.ets'), 'utf8'));
  const map = {};
  let fallback = null;
  const visit = (stmts) => {
    for (const st of stmts || []) {
      if (st.type !== 'if') {
        continue;
      }
      const t = st.test;
      const call = st.then.find((s) => s.type === 'expr')?.expr;
      if (t && t.type === 'bin' && t.right.type === 'lit' && call?.type === 'call' && call.callee.type === 'ident') {
        map[t.right.value] = call.callee.name;
      }
      if (st.otherwise && st.otherwise.length === 1 && st.otherwise[0].type === 'if') {
        visit(st.otherwise);
      } else if (st.otherwise) {
        const c = st.otherwise.find((s) => s.type === 'expr')?.expr;
        if (c?.type === 'call' && c.callee.type === 'ident') {
          fallback = c.callee.name;
        }
      }
    }
  };
  for (const st of program.body) {
    if (st.type === 'struct' && st.name === 'DocContent') {
      visit(st.members.find((m) => m.type === 'method' && m.name === 'build')?.body);
    }
  }
  if (fallback && map.intro === undefined) {
    map.intro = fallback;
  }
  return map;
}

function readPublicNames() {
  const src = fs.readFileSync(path.join(LIB, 'Index.ets'), 'utf8');
  const names = new Set();
  const re = /export\s*\{([^}]*)\}/g;
  let m;
  while ((m = re.exec(src))) {
    for (const n of m[1].split(',')) {
      const name = n.trim().split(/\s+as\s+/).pop();
      if (name) {
        names.add(name);
      }
    }
  }
  return names;
}

function readIcons() {
  const src = fs.readFileSync(path.join(LIB, 'src/main/ets/icons/LucideIcons.ets'), 'utf8');
  const icons = {};
  const re = /\['([\w-]+)',\s*i\(\[([^\]]*)\]\)\]/g;
  let m;
  while ((m = re.exec(src))) {
    icons[m[1]] = [...m[2].matchAll(/'([^']*)'/g)].map((x) => x[1]);
  }
  return icons;
}

// ------------------------------------------------------------------------------------------------ helpers

function esc(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/\{\{/g, '&#123;&#123;');
}

/** Inline markdown-ish → HTML for API descriptions: `code` only. */
function inline(s) {
  return esc(s).replace(/`([^`]+)`/g, '<code>$1</code>');
}

/** Escape text for a markdown paragraph (keeps `code`, neutralises Vue mustaches and stray HTML). */
function mdText(s) {
  return String(s ?? '')
    .replace(/</g, '&lt;')
    .replace(/\{\{/g, '&#123;&#123;')
    .replace(/\|/g, '\\|');
}

function fence(code, lang, info = '') {
  const ticks = code.includes('```') ? '````' : '```';
  return `${ticks}${lang}${info ? ' ' + info : ''}\n${code.replace(/\s+$/, '')}\n${ticks}\n`;
}

function t(dict, s) {
  if (s === undefined || s === null || s === '') {
    return s;
  }
  return dict[s] ?? s;
}

// ------------------------------------------------------------------------------------------------ API tables

function apiTables(structNames, api, L) {
  let md = '';
  for (const name of structNames) {
    const s = api.structs[name];
    if (!s) {
      continue;
    }
    md += `### ${name}\n\n`;
    if (s.description) {
      md += `${mdText(s.description)}\n\n`;
    }
    const props = s.props.filter((p) => p.kind === 'prop');
    const events = s.props.filter((p) => p.kind === 'event' && !p.name.startsWith('$'));
    const binds = s.props.filter((p) => p.kind === 'event' && p.name.startsWith('$')).map((p) => p.name.slice(1));
    const slots = s.props.filter((p) => p.kind === 'slot');
    if (props.length) {
      md += table(L.api.props, props, api, L, binds);
    }
    if (events.length) {
      md += table(L.api.events, events, api, L, []);
    }
    if (slots.length) {
      const list = slots.map((p) => p.name === 'content' ? L.api.childrenSlot : `<code>${esc(p.name)}</code>`);
      md += `<p class="api-slots"><strong>${L.api.slots}</strong>: ${list.join(', ')}</p>\n\n`;
    }
    if (!props.length && !events.length && !slots.length) {
      md += `<p class="api-slots">${L.api.none}</p>\n\n`;
    }
  }
  return md;
}

function typeCell(type, api) {
  const parts = [];
  parts.push(`<code>${esc(type)}</code>`);
  const names = new Set((type.match(/\b[A-Z]\w+\b/g) || []).filter((n) => api.aliases[n]));
  for (const n of names) {
    const v = api.aliases[n];
    if (v.length < 160 && /['"0-9]/.test(v)) {
      parts.push(`<div class="api-alias">${esc(n)} = <code>${esc(v)}</code></div>`);
    }
  }
  return parts.join('');
}

function table(title, rows, api, L, binds) {
  let html = `<div class="api-table" v-pre>\n<table>\n<thead><tr><th>${title}</th><th>${L.api.type}</th>` +
    `<th>${L.api.default}</th><th>${L.api.description}</th></tr></thead>\n<tbody>\n`;
  for (const p of rows) {
    const flags = [];
    if (p.required) {
      flags.push(`<span class="api-flag">${L.api.required}</span>`);
    }
    if (binds.includes(p.name)) {
      flags.push(`<span class="api-flag" title="${esc(L.api.bindTitle)}">!!</span>`);
    }
    const def = p.default && p.default.length < 80 ? `<code>${esc(p.default)}</code>` : (p.default ? '<code>…</code>' : '—');
    html += `<tr><td><code>${esc(p.name)}</code>${flags.join('')}</td><td>${typeCell(p.type, api)}</td>` +
      `<td>${def}</td><td>${inline(p.description) || ''}</td></tr>\n`;
  }
  html += '</tbody>\n</table>\n</div>\n\n';
  return html;
}

// ------------------------------------------------------------------------------------------------ pages

function structsForPage(id, api, publicNames) {
  const extra = PAGE_EXTRA_STRUCTS[id];
  if (extra) {
    return extra.filter((n) => api.structs[n] && publicNames.has(n));
  }
  const dirs = [`components/${id}`, `blocks/${id}`];
  return Object.values(api.structs)
    .filter((s) => dirs.includes(s.dir) && publicNames.has(s.name))
    .map((s) => s.name);
}

function pageMarkdown({ id, title, group, docName, doc, structs, api, L, dict }) {
  const lines = [];
  const headers = doc ? doc.blocks.filter((b) => b.kind === 'header') : [];
  const single = headers.length <= 1;
  const lead = single && headers[0] ? t(dict, headers[0].lead) : '';
  const titleText = L.code === 'zh' && dict[title] ? `${title} ${dict[title]}` : title;
  lines.push('---');
  lines.push(`title: ${JSON.stringify(titleText)}`);
  if (lead) {
    lines.push(`description: ${JSON.stringify(lead)}`);
  }
  lines.push('---');
  lines.push('');
  lines.push(`<!-- AUTO-GENERATED by docs/scripts/generate.mjs from gallery/src/main/ets/docs/${doc ? doc.file : '?'}` +
    ` (${docName ?? 'no doc'}) and the library sources. Do not edit: change the gallery / library instead. -->`);
  lines.push('');
  lines.push(`# ${titleText}`);
  lines.push('');
  if (lead) {
    lines.push(`<p class="doc-lead">${mdText(lead)}</p>`);
    lines.push('');
  }
  const h2 = single ? '##' : '###';
  for (const b of doc ? doc.blocks : []) {
    switch (b.kind) {
      case 'header':
        if (!single) {
          lines.push(`## ${t(dict, b.title)}`);
          lines.push('');
          if (b.lead) {
            lines.push(`<p class="doc-lead">${mdText(t(dict, b.lead))}</p>`);
            lines.push('');
          }
        }
        break;
      case 'section':
        lines.push(`${h2} ${t(dict, b.title)}`);
        lines.push('');
        if (b.description) {
          lines.push(mdText(t(dict, b.description)));
          lines.push('');
        }
        break;
      case 'caption':
        lines.push(`<p class="doc-caption">${mdText(t(dict, b.text))}</p>`);
        lines.push('');
        break;
      case 'demo':
        lines.push(fence(b.code, 'arkts', `preview state=${docName}${b.centered ? '' : ' left'}`));
        break;
      case 'code':
        lines.push(fence(b.code, b.language === 'text' ? 'txt' : b.language, b.title ? `[${b.title}]` : ''));
        break;
      default:
        break;
    }
  }
  if (structs.length) {
    lines.push(`## ${L.api.title}`);
    lines.push('');
    lines.push(`<p class="doc-caption">${L.api.note}</p>`);
    lines.push('');
    lines.push(apiTables(structs, api, L));
  }
  return lines.join('\n');
}

function overviewMarkdown(groups, L, dict) {
  let md = `---\ntitle: ${JSON.stringify(L.overview.title)}\n---\n\n` +
    `<script setup>\nimport { withBase } from 'vitepress';\n</script>\n\n# ${L.overview.title}\n\n` +
    `<p class="doc-lead">${L.overview.lead}</p>\n\n`;
  for (const g of groups) {
    md += `## ${t(dict, g.title)}\n\n<div class="overview-grid">\n`;
    for (const it of g.items) {
      const zh = L.code === 'zh' && dict[it.title] ? `<span>${esc(dict[it.title])}</span>` : '';
      md += `<a class="overview-card" :href="withBase('${L.prefix}components/${it.id}')"><strong>${esc(it.title)}</strong>${zh}</a>\n`;
    }
    md += '</div>\n\n';
  }
  return md;
}

export function generate({ quiet = false } = {}) {
  const started = Date.now();
  const api = extractApi(LIB);
  const publicNames = readPublicNames();
  const demos = extractDemos(path.join(GALLERY, 'docs'));
  const nav = readNav();
  const pageMap = readPageMap();
  const presets = loadPresets(LIB);
  const dictZh = JSON.parse(fs.readFileSync(path.join(DOCS, '.vitepress/i18n/zh.json'), 'utf8'));

  // data for the theme
  write(path.join(OUT, 'tokens.css'), previewerCss(presets));
  const icons = readIcons();
  const iconCount = Object.keys(icons).length;
  write(path.join(OUT, 'icons.json'), JSON.stringify(icons));
  const state = {};
  for (const [k, d] of Object.entries(demos.docs)) {
    state[k] = Object.keys(d.consts).length ? { ...d.state, __consts: d.consts } : d.state;
  }
  write(path.join(OUT, 'demo-state.json'), JSON.stringify(state));
  write(path.join(OUT, 'presets.json'), JSON.stringify({ presets: presets.presetNames, accents: presets.accentNames }));

  // component pages + sidebar
  const groups = nav
    .map((g) => ({ title: g.title, items: g.items.filter((it) => !GUIDE_PAGE_IDS.includes(it.id)) }))
    .filter((g) => g.items.length > 0);
  const sidebar = {};
  const missing = new Set();
  let pages = 0;
  for (const L of LOCALES) {
    const dict = L.code === 'zh' ? dictZh : {};
    const dir = path.join(DOCS, L.dir, 'components');
    fs.mkdirSync(dir, { recursive: true });
    const keep = new Set(['index.md']);
    for (const g of groups) {
      for (const it of g.items) {
        const docName = pageMap[it.id];
        const doc = docName ? demos.docs[docName] : undefined;
        const structs = structsForPage(it.id, api, publicNames);
        let md = pageMarkdown({ id: it.id, title: it.title, group: g.title, docName, doc, structs, api, L, dict });
        if (it.id === 'icons') {
          // the gallery computes the icon count at runtime (this.all.length)
          md = md.replace(/…(?= (个 )?lucide)/g, String(iconCount));
        }
        write(path.join(dir, `${it.id}.md`), md);
        keep.add(`${it.id}.md`);
        pages++;
        if (L.code === 'zh') {
          for (const s of [it.title, g.title, ...(doc ? doc.blocks.flatMap((b) => [b.title, b.lead, b.description, b.text]) : [])]) {
            if (s && !dictZh[s]) {
              missing.add(s);
            }
          }
        }
      }
    }
    write(path.join(dir, 'index.md'), overviewMarkdown(groups, L, dict));
    // drop pages whose nav entry disappeared
    for (const f of fs.readdirSync(dir)) {
      if (f.endsWith('.md') && !keep.has(f)) {
        fs.unlinkSync(path.join(dir, f));
      }
    }
    sidebar[L.code] = groups.map((g) => ({
      text: t(dict, g.title),
      collapsed: false,
      items: g.items.map((it) => ({
        text: L.code === 'zh' && dict[it.title] ? `${it.title} ${dict[it.title]}` : it.title,
        link: `${L.prefix}components/${it.id}`
      }))
    }));
  }
  write(path.join(OUT, 'sidebar.json'), JSON.stringify(sidebar, null, 1));
  write(path.join(OUT, 'api.json'), JSON.stringify(api, null, 1));
  write(path.join(OUT, 'missing-zh.json'), JSON.stringify([...missing], null, 1));
  if (!quiet) {
    const warn = [...api.errors, ...demos.errors];
    console.log(`[sparkui-docs] ${pages} component pages, ${Object.keys(api.structs).length} structs, ` +
      `${Object.keys(demos.docs).length} gallery docs, ${missing.size} untranslated strings` +
      `${warn.length ? `, ${warn.length} parse warnings` : ''} (${Date.now() - started} ms)`);
    for (const w of warn) {
      console.log(`  warning: ${w}`);
    }
  }
  return { pages, missing: [...missing] };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  generate();
}
