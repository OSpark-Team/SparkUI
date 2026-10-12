/**
 * Component tokens (ADR D13) on the web: the preview CSS reads `var(--<component>-<property>, <recipe>)`
 * (component-tokens.css), so theme-level tokens (SparkUI.themes.setVariable / loadString in a snippet) apply
 * through the cascade, and a per-instance `tokens: { … }` object becomes inline custom properties on the
 * component's root — the same instance → theme token → recipe order as SparkTokenReader.
 */
import { color } from './runtime.js';
import { isEnumProxy } from './interp.js';

/** properties whose values are unitless numbers (everything else numeric is a length in vp = px) */
const NUMBER_PROPS = new Set(['font-weight', 'pressed-scale', 'menu-pressed-opacity']);

export function kebab(name) {
  return String(name).replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
}

function cssValue(prop, v) {
  if (v === undefined || v === null || isEnumProxy(v)) {
    return undefined;
  }
  if (typeof v === 'number') {
    return NUMBER_PROPS.has(prop) ? String(v) : `${v}px`;
  }
  if (typeof v === 'boolean') {
    return v ? '1' : '0';
  }
  if (typeof v === 'object') {
    return undefined;
  }
  const s = String(v).trim();
  if (/^-?[\d.]+(vp|fp|px)?$/.test(s) && !NUMBER_PROPS.has(prop)) {
    return `${parseFloat(s)}px`;
  }
  return color(s) ?? s;
}

/**
 * Instance tokens → inline custom properties. `variant` also sets the variant-qualified name
 * (`--button-outline-background`), because the CSS of a non-default variant reads that one.
 * @returns {Record<string, string>} style object (empty when there are no tokens)
 */
export function tokenVars(component, tokens, variant) {
  const out = {};
  if (!tokens || typeof tokens !== 'object' || Array.isArray(tokens) || isEnumProxy(tokens)) {
    return out;
  }
  for (const [k, v] of Object.entries(tokens)) {
    const prop = kebab(k);
    const val = cssValue(prop, v);
    if (val === undefined) {
      continue;
    }
    out[`--${component}-${prop}`] = val;
    if (variant && variant !== 'default') {
      out[`--${component}-${variant}-${prop}`] = val;
    }
  }
  return out;
}
