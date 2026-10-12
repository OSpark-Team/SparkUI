// Generate the previewer's theme CSS from library/src/main/ets/theme/presets/Presets.ets by running the
// preset builders through the docs' own ArkTS interpreter (so the web tokens can never drift).
import fs from 'node:fs';
import path from 'node:path';
import { parseProgram } from '../../.vitepress/theme/previewer/parser.js';
import { Interpreter, Scope } from '../../.vitepress/theme/previewer/interp.js';

/** Loads Presets.ets and returns { presets: {name: css}, accents: {name: css}, presetNames, accentNames }. */
export function loadPresets(libraryRoot) {
  const file = path.join(libraryRoot, 'src/main/ets/theme/presets/Presets.ets');
  const program = parseProgram(fs.readFileSync(file, 'utf8'));
  const globals = {
    GrayScale: (s50, s100, s200, s400, s500, s800, s900, s950) => ({ s50, s100, s200, s400, s500, s800, s900, s950 }),
    AccentScale: (light, lightFg, dark, darkFg, ring) => ({ light, lightFg, dark, darkFg, ring })
  };
  const interp = new Interpreter({}, globals);
  const scope = new Scope();
  interp.exec(program.body.filter((s) => s.type === 'var' || (s.type === 'block' && s.transparent)), scope);
  const presetCss = scope.lookup('presetCss').value;
  const accentCss = scope.lookup('accentCss').value;
  const presetNames = scope.lookup('SPARK_PRESETS').value;
  const accentNames = scope.lookup('SPARK_ACCENTS').value;
  if (typeof presetCss !== 'function' || !Array.isArray(presetNames)) {
    throw new Error('Could not evaluate Presets.ets');
  }
  const presets = {};
  for (const n of presetNames) {
    presets[n] = presetCss(n);
  }
  const accents = {};
  for (const n of accentNames) {
    accents[n] = accentCss(n);
  }
  return { presets, accents, presetNames, accentNames };
}

/** Parse `:root { --a: b; } .dark { ... }` into { root: [[k, v]], dark: [[k, v]] }. */
function blocks(css) {
  const out = { root: [], dark: [] };
  const re = /(:root|\.dark)\s*\{([^}]*)\}/g;
  let m;
  while ((m = re.exec(css))) {
    const key = m[1] === ':root' ? 'root' : 'dark';
    for (const decl of m[2].split(';')) {
      const i = decl.indexOf(':');
      if (i > 0) {
        out[key].push([decl.slice(0, i).trim(), decl.slice(i + 1).trim()]);
      }
    }
  }
  return out;
}

function rule(selector, decls) {
  if (decls.length === 0) {
    return '';
  }
  return `${selector} {\n${decls.map(([k, v]) => `  ${k}: ${v};`).join('\n')}\n}\n`;
}

/** CSS for the previewer: `.ark-theme.ark-preset-<name>` and `.ark-theme.ark-accent-<name>`, `.dark` variants. */
export function previewerCss({ presets, accents }) {
  let css = '/* AUTO-GENERATED from library/src/main/ets/theme/presets/Presets.ets — do not edit. */\n';
  for (const [name, src] of Object.entries(presets)) {
    const b = blocks(src);
    css += rule(`.ark-theme.ark-preset-${name}`, b.root);
    css += rule(`.ark-theme.ark-preset-${name}.dark`, b.dark);
  }
  for (const [name, src] of Object.entries(accents)) {
    const b = blocks(src);
    css += rule(`.ark-theme.ark-accent-${name}`, b.root);
    css += rule(`.ark-theme.ark-accent-${name}.dark`, b.dark);
  }
  return css;
}
