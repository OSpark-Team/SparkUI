// Smoke test for the web previewer: server-renders every gallery demo and reports parse errors, render
// errors and the components that fall back to placeholders. `npm run test:previewer [-- --verbose]`
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
const { extractDemos } = await import('./lib/extract-demos.mjs');
const { createSSRApp, h, ref } = await import('vue');
const { renderToString } = await import('vue/server-renderer');
const { compile, createRuntime, renderStatements } = await import('../.vitepress/theme/previewer/runtime.js');
const { createRegistry } = await import('../.vitepress/theme/previewer/components.js');

const verbose = process.argv.includes('--verbose');
const { docs } = extractDemos(path.resolve(here, '../../gallery/src/main/ets/docs'));
const registry = createRegistry();
const placeholders = new Map();
let total = 0;
let failed = 0;
let parseErrors = 0;

for (const [docName, doc] of Object.entries(docs)) {
  for (const b of doc.blocks) {
    if (b.kind !== 'demo') {
      continue;
    }
    total++;
    const analysis = compile(b.code);
    parseErrors += analysis.errors.length;
    const rt = createRuntime(analysis, doc.state, { toast() {} });
    const app = createSSRApp({ render: () => h('div', renderStatements(rt.analysis.ui, rt.root.child(), rt, registry)) });
    app.provide('arkThemeClass', ref('ark-theme'));
    let html = '';
    try {
      html = await renderToString(app);
    } catch (e) {
      failed++;
      console.log(`✗ ${docName}: ${e.message}`);
      continue;
    }
    const errs = [...html.matchAll(/class="ark-error"[^>]*>([^<]*)/g)].map((m) => m[1]);
    if (errs.length) {
      failed++;
      console.log(`✗ ${docName}: ${errs.join(' | ')}`);
    }
    for (const m of html.matchAll(/ark-unknown-label">([^<]*)/g)) {
      placeholders.set(m[1], (placeholders.get(m[1]) || 0) + 1);
    }
    if (verbose) {
      console.log(`· ${docName}: ${html.length} chars`);
    }
  }
}

console.log(`\n${total} demos rendered, ${failed} with errors, ${parseErrors} parse errors`);
const sorted = [...placeholders.entries()].sort((a, b) => b[1] - a[1]);
console.log(`placeholders (${sorted.length}): ${sorted.map(([k, v]) => `${k}×${v}`).join(', ')}`);
process.exitCode = failed ? 1 : 0;
