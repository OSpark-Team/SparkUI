<script setup>
// Renders an ArkTS UI snippet as an approximate live web preview.
import { computed, provide, ref, shallowRef, watch, h, defineComponent, onErrorCaptured } from 'vue';
import { useData } from 'vitepress';
import { compile, createRuntime, renderStatements } from '../previewer/runtime.js';
import { createRegistry } from '../previewer/components.js';
import { arkTheme, loadArkTheme } from '../previewer/store.js';

const props = defineProps({
  code: { type: String, required: true },
  state: { type: Object, default: () => ({}) },
  /** null = follow the site's dark mode */
  dark: { type: Boolean, default: null },
  left: { type: Boolean, default: false },
  /** precompiled analysis (the gallery's real demo body, runtime.bundleAnalysis); overrides `code` for rendering */
  analysis: { type: Object, default: null }
});

const { isDark } = useData();
loadArkTheme();

const registry = createRegistry();
const toasts = ref([]);
let toastId = 0;
const services = {
  toast(message, opts = {}) {
    const id = ++toastId;
    const o = opts && typeof opts === 'object' ? opts : {};
    toasts.value.push({ id, title: String(message ?? ''), description: o.description, variant: o.variant || '' });
    setTimeout(() => {
      toasts.value = toasts.value.filter((t) => t.id !== id);
    }, Math.min(Number(o.duration) || 4000, 10000));
  }
};

const analysis = computed(() => props.analysis || compile(props.code));
const runtime = shallowRef(null);
const failure = ref('');
watch([analysis, () => props.state], () => {
  failure.value = '';
  try {
    runtime.value = createRuntime(analysis.value, props.state, services);
  } catch (e) {
    runtime.value = null;
    failure.value = String(e && e.message || e);
  }
}, { immediate: true });

const vars = computed(() => runtime.value?.themeVars);
const dark = computed(() => {
  const base = props.dark === null ? isDark.value : props.dark;
  const v = vars.value;
  const chosen = v && v.mode ? v.mode === 'dark' : base;
  return v && v.flip ? !chosen : chosen;
});
/** theme variables the snippet set (SparkUI.themes.setVariable / loadString), on top of the preset classes */
const themeStyle = computed(() => {
  const v = vars.value;
  return v ? { ...v.root, ...(dark.value ? v.dark : {}) } : {};
});
const themeClass = computed(() => [
  'ark-theme', `ark-preset-${arkTheme.preset}`, arkTheme.accent !== 'none' ? `ark-accent-${arkTheme.accent}` : '',
  dark.value ? 'dark' : ''
].filter(Boolean).join(' '));
provide('arkThemeClass', themeClass);
provide('arkThemeStyle', themeStyle);

const Tree = defineComponent({
  name: 'ArkTree',
  setup() {
    const err = ref('');
    onErrorCaptured((e) => {
      err.value = String(e && e.message || e);
      return false;
    });
    return () => {
      if (err.value) {
        return h('div', { class: 'ark-error' }, `⚠ ${err.value}`);
      }
      const rt = runtime.value;
      if (!rt) {
        return h('div', { class: 'ark-error' }, failure.value || 'Preview unavailable');
      }
      const nodes = renderStatements(rt.analysis.ui, rt.root.child(), rt, registry);
      if (nodes.length === 0) {
        return h('div', { class: 'ark-empty-preview' }, 'No visual output — see the code.');
      }
      return nodes;
    };
  }
});

const errors = computed(() => analysis.value.errors);
defineExpose({ errors });
</script>

<template>
  <div :class="themeClass" :style="themeStyle" class="ark-preview">
    <div class="ark-stage" :class="{ left }">
      <Tree :key="code" />
      <div v-if="toasts.length" class="ark-toasts">
        <div v-for="t in toasts" :key="t.id" class="ark-toast" :class="t.variant">
          <div class="ark-toast-title">{{ t.title }}</div>
          <div v-if="t.description" class="ark-toast-description">{{ t.description }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style>
.ark-empty-preview {
  font-size: 13px;
  color: var(--muted-foreground);
}
</style>
