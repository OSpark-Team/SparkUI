/**
 * Vector icon definition in a 24×24 viewBox (lucide geometry). Each entry of `paths` is an SVG path
 * string normalised to absolute commands (see tools/gen-icons.mjs).
 */
export class SparkIconData {
  paths: string[];
  /** filled glyph instead of a stroked outline */
  filled: boolean;

  constructor(paths: string[], filled?: boolean) {
    this.paths = paths;
    this.filled = filled === true;
  }
}

const PARAMS: Map<string, number> = new Map<string, number>([
  ['M', 2], ['L', 2], ['T', 2], ['H', 1], ['V', 1], ['C', 6], ['S', 4], ['Q', 4], ['A', 7], ['Z', 0]
]);

/**
 * Scale SVG path data by `k`. ArkUI `Path.commands()` takes px units (verified on device: a viewPort in vp
 * renders 1/density size), so icons are scaled from their 24-unit box to the target px size.
 * Works for absolute and relative commands; arc rotation and flags are left untouched.
 */
export function scalePathCommands(d: string, k: number): string {
  const tokens = d.match(/[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?/g);
  if (tokens === null) {
    return '';
  }
  let out = '';
  let cmd = 'M';
  let index = 0;
  for (const tok of tokens) {
    if (/^[A-Za-z]$/.test(tok)) {
      cmd = tok;
      index = 0;
      out += tok;
      continue;
    }
    const upper = cmd.toUpperCase();
    const count = PARAMS.get(upper) ?? 2;
    const pos = count > 0 ? index % count : 0;
    const keep = upper === 'A' && (pos === 2 || pos === 3 || pos === 4);
    const v = parseFloat(tok);
    out += ' ' + (keep ? tok : String(Math.round(v * k * 1000) / 1000));
    index++;
  }
  return out.trim();
}
