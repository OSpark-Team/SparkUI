import { reactive, watch } from 'vue';

/** Previewer theme shared by every demo on the page: base gray preset + accent (persisted per browser). */
export const arkTheme = reactive({ preset: 'neutral', accent: 'none' });

let loaded = false;

export function loadArkTheme() {
  if (loaded || typeof window === 'undefined') {
    return;
  }
  loaded = true;
  try {
    const saved = JSON.parse(window.localStorage.getItem('sparkui-preview-theme') || '{}');
    if (typeof saved.preset === 'string') {
      arkTheme.preset = saved.preset;
    }
    if (typeof saved.accent === 'string') {
      arkTheme.accent = saved.accent;
    }
  } catch (e) {
    // storage unavailable: keep defaults
  }
  watch(arkTheme, (v) => {
    try {
      window.localStorage.setItem('sparkui-preview-theme', JSON.stringify(v));
    } catch (e) {
      // ignore
    }
  });
}
