<script setup>
// Preview / Code tabs around one example, like the gallery's DemoBlock.
import { computed, ref } from 'vue';
import { useData, withBase } from 'vitepress';
import ArkPreview from './ArkPreview.vue';
import DEMO_STATE from '../../generated/demo-state.json';

const props = defineProps({
  /** encodeURIComponent(code) — produced by the markdown plugin */
  code: { type: String, required: true },
  /** gallery doc struct whose @Local state the snippet may reference (this.x) */
  state: { type: String, default: '' },
  left: { type: Boolean, default: false },
  /** encodeURIComponent(JSON) inline demo state from the fence info: ```arkts preview {"on":true} */
  data: { type: String, default: '' }
});

const { lang, isDark } = useData();
const zh = computed(() => lang.value.startsWith('zh'));
const source = computed(() => decodeURIComponent(props.code));
const demoState = computed(() => {
  let inline = {};
  try {
    inline = props.data ? JSON.parse(decodeURIComponent(props.data)) : {};
  } catch (e) {
    inline = {};
  }
  return { ...((props.state && DEMO_STATE[props.state]) || {}), ...inline };
});
const tab = ref('preview');
const forced = ref(null);
const dark = computed(() => (forced.value === null ? isDark.value : forced.value));
const copied = ref(false);

function toggleDark() {
  forced.value = !dark.value;
}

async function copy() {
  try {
    await navigator.clipboard.writeText(source.value);
    copied.value = true;
    setTimeout(() => (copied.value = false), 1500);
  } catch (e) {
    // clipboard unavailable
  }
}

const playground = computed(() => {
  const base = zh.value ? '/playground' : '/en/playground';
  return withBase(`${base}#code=${encodeURIComponent(source.value)}${props.state ? `&state=${props.state}` : ''}`);
});
</script>

<template>
  <div class="ark-demo">
    <div class="ark-demo-bar">
      <div class="ark-demo-tabs" role="tablist">
        <button :class="{ active: tab === 'preview' }" role="tab" @click="tab = 'preview'">{{ zh ? '预览' : 'Preview' }}</button>
        <button :class="{ active: tab === 'code' }" role="tab" @click="tab = 'code'">{{ zh ? '代码' : 'Code' }}</button>
      </div>
      <div class="ark-demo-actions">
        <a class="ark-demo-icon" :href="playground" :title="zh ? '在演练场中打开' : 'Open in playground'">
          <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h6v6" /><path d="M10 14 21 3" /><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" /></svg>
        </a>
        <button class="ark-demo-icon" :title="zh ? '切换预览明暗' : 'Toggle preview theme'" @click="toggleDark">
          <svg v-if="dark" viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" /></svg>
          <svg v-else viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" /></svg>
        </button>
        <button class="ark-demo-icon" :title="zh ? '复制代码' : 'Copy code'" @click="copy">
          <svg v-if="copied" viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5" /></svg>
          <svg v-else viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" /><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" /></svg>
        </button>
      </div>
    </div>
    <ClientOnly>
      <ArkPreview v-show="tab === 'preview'" :code="source" :state="demoState" :dark="dark" :left="left" />
    </ClientOnly>
    <div v-show="tab === 'code'" class="ark-demo-code">
      <slot name="code" />
    </div>
    <p v-show="tab === 'preview'" class="ark-demo-note">
      {{ zh ? '网页近似预览，真机效果以 HarmonyOS 渲染为准。' : 'Approximate web preview — the HarmonyOS rendering is the reference.' }}
    </p>
  </div>
</template>
