// Debug helper: `node scripts/render-demo.mjs <DocName> [index] [--snippet]` prints the SSR HTML of one gallery demo
// (rendered from its real demo body like the site; --snippet renders the reader-facing code string instead).
import { registerHooks } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

registerHooks({
  load(url, context, nextLoad) {
    if (url.endsWith('.json')) {
      return { format: 'module', source: `export default ${fs.readFileSync(fileURLToPath(url), 'utf8')};`, shortCircuit: true };
    }
    return nextLoad(url, context);
  }
});

const here = path.dirname(fileURLToPath(import.meta.url));
const { extractDemos, demoState, demoBundle, bundleJson } = await import('./lib/extract-demos.mjs');
const { libraryClassSources } = await import('./lib/class-sources.mjs');
const { createSSRApp, h, ref } = await import('vue');
const { renderToString } = await import('vue/server-renderer');
const { compile, createRuntime, renderStatements, bundleAnalysis } = await import('../.vitepress/theme/previewer/runtime.js');
const { createRegistry } = await import('../.vitepress/theme/previewer/components.js');

const snippet = process.argv.includes('--snippet');
const [docName, index = '0'] = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const { docs, modules } = extractDemos(path.resolve(here, '../../gallery/src/main/ets/docs'),
  { classes: libraryClassSources(path.resolve(here, '../../library')) });
const doc = docs[docName];
if (!doc) {
  console.log(`unknown doc; available: ${Object.keys(docs).join(', ')}`);
  process.exit(1);
}
const demos = doc.blocks.filter((b) => b.kind === 'demo');
const b = demos[Number(index)];
const consts = demoState(doc);
const bundle = snippet ? null : demoBundle(doc, modules);
const real = bundle ? bundleAnalysis(JSON.parse(bundleJson(bundle)), Number(index)) : null;
const rt = createRuntime(real || compile(b.code), consts, { toast() {} });
const app = createSSRApp({ render: () => h('div', renderStatements(rt.analysis.ui, rt.root.child(), rt, createRegistry())) });
app.provide('arkThemeClass', ref('ark-theme'));
console.log(await renderToString(app));
