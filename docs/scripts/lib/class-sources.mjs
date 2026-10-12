// Class bodies of the library (read-only), so the previewer can construct `new SparkChartSeries(...)`,
// `new SparkShellNavItem(...)` … as plain objects (see .vitepress/theme/previewer/classes.js).
import fs from 'node:fs';
import path from 'node:path';
import { classSources } from '../../.vitepress/theme/previewer/classes.js';

function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      walk(p, out);
    } else if (e.name.endsWith('.ets') || e.name.endsWith('.ts')) {
      out.push(p);
    }
  }
  return out;
}

/** { ClassName: body } for every class under library/src/main/ets (first definition wins). */
export function libraryClassSources(libraryRoot) {
  const out = {};
  for (const file of walk(path.join(libraryRoot, 'src/main/ets'), [])) {
    for (const [name, body] of Object.entries(classSources(fs.readFileSync(file, 'utf8')))) {
      if (!(name in out)) {
        out[name] = body;
      }
    }
  }
  return out;
}
