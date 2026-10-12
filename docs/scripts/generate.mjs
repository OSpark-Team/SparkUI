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
import { extractDemos, demoState, demoBundle, bundleJson } from './lib/extract-demos.mjs';
import { libraryClassSources } from './lib/class-sources.mjs';
import { loadPresets, previewerCss } from './lib/gen-tokens.mjs';
import { parseProgram } from '../.vitepress/theme/previewer/parser.js';
import { Interpreter, Scope } from '../.vitepress/theme/previewer/interp.js';
import { PAGE_EXTRA_STRUCTS, GUIDE_PAGE_IDS, LOCALES, CODE_ONLY, isCodeOnly } from './lib/pages-config.mjs';

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

/** `dictApi` maps English API descriptions to their translation (zh only; en passes {}). */
function apiTables(structNames, api, L, dictApi) {
  let md = '';
  for (const name of structNames) {
    const s = api.structs[name];
    if (!s) {
      continue;
    }
    md += `### ${name}\n\n`;
    if (s.description) {
      md += `${mdText(t(dictApi, s.description))}\n\n`;
    }
    const props = s.props.filter((p) => p.kind === 'prop');
    const events = s.props.filter((p) => p.kind === 'event' && !p.name.startsWith('$'));
    const binds = s.props.filter((p) => p.kind === 'event' && p.name.startsWith('$')).map((p) => p.name.slice(1));
    const slots = s.props.filter((p) => p.kind === 'slot');
    if (props.length) {
      md += table(L.api.props, props, api, L, binds, dictApi);
    }
    if (events.length) {
      md += table(L.api.events, events, api, L, [], dictApi);
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

function table(title, rows, api, L, binds, dictApi) {
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
      `<td>${def}</td><td>${inline(t(dictApi, p.description)) || ''}</td></tr>\n`;
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

/**
 * Page layout (every component page, zh and en):
 *
 *   # Title                        (gallery nav title, + zh name)
 *   lead                           (the DocHeader lead; pages with several DocHeaders join their leads)
 *   [code-only note]               (CODE_ONLY pages)
 *   ## Usage | ## <section> …      (demos in gallery order; a demo before the first section gets "Usage")
 *   ## <sub-header> / ### …        (pages with several DocHeaders: one ## per header, sections at ###)
 *   ## API / ### <Struct>          (API tables)
 */
function pageMarkdown({ id, title, group, docName, doc, structs, api, L, dict, dictApi, hasBundle }) {
  const lines = [];
  const headers = doc ? doc.blocks.filter((b) => b.kind === 'header') : [];
  const single = headers.length <= 1;
  const lead = headers.map((hd) => t(dict, hd.lead)).filter(Boolean).join(L.code === 'zh' ? '' : ' ');
  const titleText = L.code === 'zh' && dict[title] ? `${title} ${dict[title]}` : title;
  const codeOnly = docName ? CODE_ONLY[docName] : undefined;
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
  if (codeOnly && codeOnly[L.code]) {
    lines.push(`<p class="doc-note">${mdText(codeOnly[L.code])}</p>`);
    lines.push('');
  }
  const h2 = single ? '##' : '###';
  let demoIndex = -1;
  // a demo / code block / caption right under the page title gets a "Usage" heading so every example sits
  // under a heading (pages with several DocHeaders already have one ## per header)
  let underHeading = !single;
  for (const b of doc ? doc.blocks : []) {
    if (b.kind === 'demo') {
      demoIndex++;
    }
    if (!underHeading && ['demo', 'code', 'caption'].includes(b.kind)) {
      lines.push(`## ${L.usage}`);
      lines.push('');
      underHeading = true;
    }
    switch (b.kind) {
      case 'header':
        if (!single) {
          lines.push(`## ${t(dict, b.title)}`);
          lines.push('');
        }
        break;
      case 'section':
        underHeading = true;
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
        if (isCodeOnly(docName, demoIndex)) {
          // code only: a plain highlighted block (VitePress adds the copy button), no web preview
          lines.push(fence(b.code, 'arkts'));
          break;
        }
        // body=N: the preview renders the gallery's real demo body N (generated/demo-bodies/<doc>.json), the
        // Code tab shows the reader-facing snippet
        lines.push(fence(b.code, 'arkts', `preview state=${docName}${hasBundle && b.body ? ` body=${demoIndex}` : ''}` +
          `${b.centered ? '' : ' left'}`));
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
    lines.push(apiTables(structs, api, L, dictApi));
  }
  return lines.join('\n');
}

/**
 * Structure audit of one generated page (see pageMarkdown for the layout every page should follow): exactly one
 * h1, a lead, no skipped heading levels, no duplicate headings under the same parent, no empty sections, every
 * example under a heading and the API section last.
 */
function auditPage(md) {
  const issues = [];
  const body = md.replace(/^---[\s\S]*?\n---\n/, '');
  const items = [];
  let fenceOpen = null;
  for (const line of body.split('\n')) {
    const f = /^(`{3,})/.exec(line);
    if (f) {
      if (!fenceOpen) {
        fenceOpen = f[1];
        items.push({ kind: 'example' });
      } else if (line.trim() === fenceOpen) {
        fenceOpen = null;
      }
      continue;
    }
    if (fenceOpen) {
      continue;
    }
    const m = /^(#{1,6}) (.*)$/.exec(line);
    if (m) {
      items.push({ kind: 'heading', level: m[1].length, text: m[2].trim() });
    } else if (line.startsWith('<p class="doc-lead"')) {
      items.push({ kind: 'lead' });
    } else if (line.trim() && !line.startsWith('<!--')) {
      items.push({ kind: 'content' });
    }
  }
  const heads = items.filter((x) => x.kind === 'heading');
  if (heads.filter((x) => x.level === 1).length !== 1 || items[0]?.level !== 1) {
    issues.push('page must start with exactly one h1');
  }
  if (items[1]?.kind !== 'lead') {
    issues.push('missing lead under the title');
  }
  const seen = new Map();
  const parents = [];
  let prevLevel = 1;
  let apiSeen = false;
  items.forEach((x, i) => {
    if (x.kind === 'example' && !items.slice(0, i).some((y) => y.kind === 'heading' && y.level > 1)) {
      issues.push('example before the first section heading');
    }
    if (x.kind !== 'heading') {
      return;
    }
    if (x.level > prevLevel + 1) {
      issues.push(`heading level jumps to h${x.level}: "${x.text}"`);
    }
    prevLevel = x.level;
    parents.length = x.level;
    const key = `${parents.slice(1, x.level).join('/')}/${x.level}:${x.text}`;
    parents[x.level] = x.text;
    if (seen.has(key)) {
      issues.push(`duplicate heading "${x.text}"`);
    }
    seen.set(key, true);
    if (x.level === 2 && x.text === 'API') {
      apiSeen = true;
    } else if (x.level === 2 && apiSeen) {
      issues.push(`section "${x.text}" after the API section`);
    }
    const next = items.slice(i + 1).find((y) => y.kind !== 'heading' || y.level <= x.level);
    const nextIdx = next ? items.indexOf(next) : items.length;
    const hasChildHeading = items.slice(i + 1, nextIdx).some((y) => y.kind === 'heading');
    if (x.level > 1 && !hasChildHeading && (!next || next.kind === 'heading')) {
      issues.push(`empty section "${x.text}"`);
    }
  });
  return [...new Set(issues)];
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

/** Library classes the demo snippets construct (`new X(`), plus the classes those construct. */
function usedClasses(classes, demos) {
  const out = {};
  const queue = [];
  const scan = (code) => {
    for (const m of code.matchAll(/\bnew\s+(\w+)\s*[(<]/g)) {
      if (classes[m[1]] && !(m[1] in out)) {
        out[m[1]] = classes[m[1]];
        queue.push(m[1]);
      }
    }
  };
  for (const d of Object.values(demos.docs)) {
    for (const b of d.blocks) {
      if (b.code) {
        scan(b.code);
      }
    }
  }
  // the real demo bodies construct classes too
  for (const src of demos.sources || []) {
    scan(src);
  }
  while (queue.length) {
    scan(classes[queue.pop()]);
  }
  return out;
}

export function generate({ quiet = false } = {}) {
  const started = Date.now();
  const api = extractApi(LIB);
  const publicNames = readPublicNames();
  const classes = libraryClassSources(LIB);
  const demos = extractDemos(path.join(GALLERY, 'docs'), { classes });
  const nav = readNav();
  const pageMap = readPageMap();
  const presets = loadPresets(LIB);
  const dictZh = JSON.parse(fs.readFileSync(path.join(DOCS, '.vitepress/i18n/zh.json'), 'utf8'));
  const dictApiZh = JSON.parse(fs.readFileSync(path.join(DOCS, '.vitepress/i18n/api-zh.json'), 'utf8'));

  // data for the theme
  write(path.join(OUT, 'tokens.css'), previewerCss(presets));
  const icons = readIcons();
  const iconCount = Object.keys(icons).length;
  write(path.join(OUT, 'icons.json'), JSON.stringify(icons));
  const state = {};
  for (const [k, d] of Object.entries(demos.docs)) {
    state[k] = demoState(d);
  }
  write(path.join(OUT, 'demo-state.json'), JSON.stringify(state));
  // real demo bodies (+ the helper structs / constants they use), one lazily loaded file per gallery doc
  const bundles = new Set();
  const bodyDir = path.join(OUT, 'demo-bodies');
  fs.mkdirSync(bodyDir, { recursive: true });
  for (const [k, d] of Object.entries(demos.docs)) {
    if (CODE_ONLY[k]?.demos === 'all') {
      continue; // nothing on the page is previewed
    }
    const bundle = demoBundle(d, demos.modules);
    if (bundle) {
      write(path.join(bodyDir, `${k}.json`), bundleJson(bundle));
      bundles.add(k);
    }
  }
  for (const f of fs.readdirSync(bodyDir)) {
    if (!bundles.has(f.replace(/.json$/, ''))) {
      fs.unlinkSync(path.join(bodyDir, f));
    }
  }
  write(path.join(OUT, 'classes.json'), JSON.stringify(usedClasses(classes, demos)));
  write(path.join(OUT, 'presets.json'), JSON.stringify({ presets: presets.presetNames, accents: presets.accentNames }));

  // component pages + sidebar
  const groups = nav
    .map((g) => ({ title: g.title, items: g.items.filter((it) => !GUIDE_PAGE_IDS.includes(it.id)) }))
    .filter((g) => g.items.length > 0);
  const sidebar = {};
  const missing = new Set();
  const audit = [];
  let pages = 0;
  for (const L of LOCALES) {
    const dict = L.code === 'zh' ? dictZh : {};
    const dictApi = L.code === 'zh' ? dictApiZh : {};
    const dir = path.join(DOCS, L.dir, 'components');
    fs.mkdirSync(dir, { recursive: true });
    const keep = new Set(['index.md']);
    for (const g of groups) {
      for (const it of g.items) {
        const docName = pageMap[it.id];
        const doc = docName ? demos.docs[docName] : undefined;
        const structs = structsForPage(it.id, api, publicNames);
        let md = pageMarkdown({ id: it.id, title: it.title, group: g.title, docName, doc, structs, api, L, dict, dictApi,
          hasBundle: bundles.has(docName) });
        if (it.id === 'icons') {
          // the gallery computes the icon count at runtime (this.all.length)
          md = md.replace(/…(?= (个 )?lucide)/g, String(iconCount));
        }
        for (const w of auditPage(md)) {
          audit.push(`${L.code}/${it.id}: ${w}`);
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
          // API descriptions (struct + prop docs) need a translation in api-zh.json
          for (const n of structs) {
            const st = api.structs[n];
            for (const s of [st.description, ...st.props.map((p) => p.description)]) {
              if (s && !dictApiZh[s]) {
                missing.add(s);
              }
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
    console.log(`[sparkui-docs] page structure audit: ${audit.length ? `${audit.length} issue(s)` : 'ok'}`);
    for (const w of audit) {
      console.log(`  audit: ${w}`);
    }
  }
  return { pages, missing: [...missing], audit };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  generate();
}
