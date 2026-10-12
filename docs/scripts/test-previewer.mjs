// Smoke test for the web previewer: server-renders every gallery demo and reports parse errors, render
// errors, the components that fall back to placeholders, the demos shown as code only (CODE_ONLY, skipped), how many demos render from the gallery's real demo
// body (vs the reader-facing snippet as fallback), and the demos whose output is nearly empty.
// `npm run test:previewer [-- --verbose] [-- --snippets]` (--snippets: also render every reader snippet).
import { registerHooks } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// let `import X from './file.json'` work like it does under Vite
registerHooks({
  load(url, context, nextLoad) {
    if (url.endsWith('.json')) {
      return { format: 'module', source: `export default ${fs.readFileSync(fileURLToPath(url), 'utf8')};`, shortCircuit: true };
    }
    return nextLoad(url, context);
  }
});

const here = path.dirname(fileURLToPath(import.meta.url));
const { generate } = await import('./generate.mjs');
generate({ quiet: true });
const { extractDemos, demoState, demoBundle, bundleJson } = await import('./lib/extract-demos.mjs');
const { libraryClassSources } = await import('./lib/class-sources.mjs');
const { createSSRApp, h, ref } = await import('vue');
const { renderToString } = await import('vue/server-renderer');
const { compile, createRuntime, renderStatements, bundleAnalysis } = await import('../.vitepress/theme/previewer/runtime.js');
const { createRegistry } = await import('../.vitepress/theme/previewer/components.js');
const { CODE_ONLY, isCodeOnly } = await import('./lib/pages-config.mjs');

const verbose = process.argv.includes('--verbose');
const snippets = process.argv.includes('--snippets');
/** "nearly empty": fewer than MIN_TEXT visible text characters AND fewer than MIN_NODES element nodes */
const MIN_TEXT = 4;
const MIN_NODES = 6;
/**
 * Demos that are legitimately (nearly) empty in a static render, with the reason. Key: `<Doc>#<index>`.
 * Keep this list short and justified.
 */
const JUSTIFIED = {
  'SkeletonDoc#0': 'skeleton shapes only (no text by design)',
  'SkeletonDoc#1': 'skeleton shapes only (no text by design)',
  'SkeletonDoc#2': 'skeleton shapes only (no text by design)'
};

const { docs, modules } = extractDemos(path.resolve(here, '../../gallery/src/main/ets/docs'),
  { classes: libraryClassSources(path.resolve(here, '../../library')) });
const registry = createRegistry();
const placeholders = new Map();
let total = 0;
let failed = 0;
let parseErrors = 0;
let fromBody = 0;
const fallbacks = [];
const empty = [];
const justified = [];
const snippetEmpty = [];
/** demos the docs show as code only (no preview): not rendered here */
const codeOnly = [];
const warnings = new Set();

async function render(analysis, state) {
  const rt = createRuntime(analysis, state, { toast() {} });
  const app = createSSRApp({ render: () => h('div', renderStatements(rt.analysis.ui, rt.root.child(), rt, registry)) });
  app.provide('arkThemeClass', ref('ark-theme'));
  app.config.warnHandler = (msg) => warnings.add(msg);
  return renderToString(app);
}

function measure(html) {
  const body = html.replace(/<!--[\s\S]*?-->/g, '');
  // visible text: text nodes plus input placeholders / values
  const attrs = [...body.matchAll(/\s(?:placeholder|value)="([^"]*)"/g)].map((m) => m[1]).join('');
  const text = (body.replace(/<[^>]*>/g, '') + attrs).replace(/&[a-z#0-9]+;/g, 'x').replace(/\s+/g, '');
  const nodes = (body.match(/<[a-zA-Z]/g) || []).length - 1; // minus the wrapper div
  return { text: text.length, nodes };
}

for (const [docName, doc] of Object.entries(docs)) {
  // same data as the site: the bundle goes through JSON (generated/demo-bodies/<Doc>.json)
  const bundleSrc = demoBundle(doc, modules);
  const bundle = bundleSrc ? JSON.parse(bundleJson(bundleSrc)) : null;
  let index = -1;
  for (const b of doc.blocks) {
    if (b.kind !== 'demo') {
      continue;
    }
    index++;
    const id = `${docName}#${index}`;
    if (isCodeOnly(docName, index)) {
      codeOnly.push(id);
      continue;
    }
    total++;
    // same initial state as the site (generate.mjs → demo-state.json): @Local values + the page's constants
    const state = demoState(doc);
    const real = bundle ? bundleAnalysis(bundle, index) : null;
    const analysis = real || compile(b.code);
    if (real) {
      fromBody++;
    } else {
      fallbacks.push(id);
    }
    parseErrors += analysis.errors.length;
    let html = '';
    try {
      html = await render(analysis, state);
    } catch (e) {
      failed++;
      console.log(`✗ ${id}: ${e.message}`);
      continue;
    }
    const errs = [...html.matchAll(/class="ark-error"[^>]*>([^<]*)/g)].map((m) => m[1]);
    if (errs.length) {
      failed++;
      console.log(`✗ ${id}: ${errs.join(' | ')}`);
    }
    for (const m of html.matchAll(/ark-unknown-label">([^<]*)/g)) {
      placeholders.set(m[1], (placeholders.get(m[1]) || 0) + 1);
    }
    const { text, nodes } = measure(html);
    if (text < MIN_TEXT && nodes < MIN_NODES) {
      (JUSTIFIED[id] ? justified : empty).push(`${id} (${text} chars, ${nodes} nodes)${JUSTIFIED[id] ? ` — ${JUSTIFIED[id]}` : ''}`);
    }
    let cmp = '';
    if (snippets && real) {
      try {
        const s = measure(await render(compile(b.code), state));
        cmp = ` (snippet: ${s.text} chars, ${s.nodes} nodes)`;
        if (s.text < MIN_TEXT && s.nodes < MIN_NODES) {
          snippetEmpty.push(id);
        }
      } catch (e) {
        cmp = ` (snippet: ${e.message})`;
      }
    }
    if (verbose) {
      console.log(`· ${id} [${real ? 'body' : 'snippet'}]: ${text} chars, ${nodes} nodes${cmp}`);
    }
  }
}

console.log(`\n${total} demos rendered, ${failed} with errors, ${parseErrors} parse errors`);
console.log(`${fromBody} from the gallery's real demo body, ${fallbacks.length} from the reader snippet (fallback)` +
  `${fallbacks.length ? `: ${fallbacks.join(', ')}` : ''}`);
console.log(`nearly empty (< ${MIN_TEXT} text chars and < ${MIN_NODES} elements): ${empty.length}` +
  `${empty.length ? `\n  ${empty.join('\n  ')}` : ''}`);
if (snippets) {
  console.log(`reader snippets that would render nearly empty: ${snippetEmpty.length}` +
    `${snippetEmpty.length ? `: ${snippetEmpty.join(', ')}` : ''}`);
}
if (justified.length) {
  console.log(`justified nearly-empty demos: ${justified.length}\n  ${justified.join('\n  ')}`);
}
const reasons = [...new Set(codeOnly.map((id) => id.split('#')[0]))].map((d) => `${d}: ${CODE_ONLY[d].reason}`);
console.log(`code-only demos (not previewed, skipped): ${codeOnly.length}` +
  `${codeOnly.length ? `: ${codeOnly.join(', ')}\n  ${reasons.join('\n  ')}` : ''}`);
if (warnings.size) {
  console.log(`Vue warnings (${warnings.size}):\n  ${[...warnings].slice(0, 20).join('\n  ')}`);
}
const sorted = [...placeholders.entries()].sort((a, b) => b[1] - a[1]);
console.log(`placeholders (${sorted.length}): ${sorted.map(([k, v]) => `${k}×${v}`).join(', ')}`);
process.exitCode = failed || empty.length ? 1 : 0;
