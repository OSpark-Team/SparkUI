// Extract component APIs (@Param / @Event / @BuilderParam) from library/src/main/ets/**/*.ets.
// Read-only use of the library sources.
import fs from 'node:fs';
import path from 'node:path';
import { parseProgram } from '../../.vitepress/theme/previewer/parser.js';

function listEts(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      out.push(...listEts(p));
    } else if (e.name.endsWith('.ets')) {
      out.push(p);
    }
  }
  return out.sort();
}

/** Clean a JSDoc body: strip leading `*`, keep the prose before the first code fence. */
export function cleanDoc(doc, { full = false } = {}) {
  if (!doc) {
    return '';
  }
  const lines = doc.split('\n').map((l) => l.replace(/^\s*\*\s?/, '').replace(/\s+$/, ''));
  const text = lines.join('\n').trim();
  if (full) {
    return text;
  }
  return text.replace(/```[\s\S]*?(```|$)/g, '').replace(/\n{3,}/g, '\n\n').trim();
}

/** Code examples (``` fences) of a JSDoc block. */
function docExamples(doc) {
  const text = cleanDoc(doc, { full: true });
  const out = [];
  const re = /```[a-z]*\n([\s\S]*?)```/g;
  let m;
  while ((m = re.exec(text))) {
    out.push(m[1].replace(/\s+$/, ''));
  }
  return out;
}

export function extractApi(libraryRoot) {
  const etsRoot = path.join(libraryRoot, 'src', 'main', 'ets');
  const structs = {};
  const aliases = {};
  const errors = [];
  for (const file of listEts(etsRoot)) {
    const src = fs.readFileSync(file, 'utf8');
    const rel = path.relative(etsRoot, file).replace(/\\/g, '/');
    const re = /export\s+type\s+(\w+)\s*=\s*([^;]+);/g;
    let m;
    while ((m = re.exec(src))) {
      aliases[m[1]] = m[2].replace(/\s+/g, ' ').trim();
    }
    if (!/struct\s+\w+/.test(src)) {
      continue;
    }
    const program = parseProgram(src);
    for (const st of program.body) {
      if (st.type === 'error') {
        errors.push(`${rel}: ${st.message} @${st.pos}`);
      }
      if (st.type !== 'struct' || !st.exported) {
        continue;
      }
      const props = [];
      for (const mem of st.members) {
        if (mem.type !== 'field') {
          continue;
        }
        const names = mem.decorators.map((d) => d.name);
        let kind = null;
        if (names.includes('Event')) {
          kind = 'event';
        } else if (names.includes('BuilderParam')) {
          kind = 'slot';
        } else if (names.includes('Param')) {
          kind = 'prop';
        }
        if (!kind) {
          continue;
        }
        props.push({
          name: mem.name,
          kind,
          type: mem.typeSrc,
          default: mem.initSrc,
          required: names.includes('Require'),
          once: names.includes('Once'),
          description: cleanDoc(mem.doc).replace(/\n+/g, ' ')
        });
      }
      structs[st.name] = {
        name: st.name,
        file: rel,
        dir: rel.split('/').slice(0, -1).join('/'),
        description: cleanDoc(st.doc),
        examples: docExamples(st.doc),
        props
      };
    }
  }
  return { structs, aliases, errors };
}
