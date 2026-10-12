import { h } from 'vue';
import ICONS from '../../generated/icons.json';

/** Lucide icon from the library's own LucideIcons.ets path data (24×24, stroke-based). */
export function icon(name, size = 16, colorValue, strokeWidth = 2, extra = {}) {
  const paths = ICONS[name];
  const s = typeof size === 'number' ? size : parseFloat(size) || 16;
  if (!paths) {
    return h('span', {
      class: 'ark-icon-missing',
      style: { width: `${s}px`, height: `${s}px` },
      title: name ? `icon '${name}'` : undefined,
      ...extra
    });
  }
  return h('svg', {
    class: 'ark-icon',
    width: s,
    height: s,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: colorValue || 'currentColor',
    'stroke-width': strokeWidth,
    'stroke-linecap': 'round',
    'stroke-linejoin': 'round',
    'aria-hidden': 'true',
    ...extra
  }, paths.map((d) => h('path', { d })));
}

export function hasIcon(name) {
  return !!ICONS[name];
}

export const ICON_NAMES = Object.keys(ICONS);
