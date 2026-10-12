<script setup>
// Paste ArkTS UI code, see the approximate web rendering.
import { computed, onMounted, ref, watch } from 'vue';
import { useData } from 'vitepress';
import ArkPreview from './ArkPreview.vue';
import ArkThemePicker from './ArkThemePicker.vue';
import DEMO_STATE from '../../generated/demo-state.json';
import { compile } from '../previewer/runtime.js';

const SAMPLE = `SCard() {
  SCardHeader() {
    SCardTitle({ text: 'Notifications' })
    SCardDescription({ text: 'You have 3 unread messages.' })
  }
  SCardContent() {
    Column({ space: 12 }) {
      SSwitch({ label: 'Push notifications', checked: this.push!! })
      Text(this.push ? 'Push is on' : 'Push is off')
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.mutedForeground)
      STabs({ defaultValue: 'all' }) {
        STabsList() {
          STabsTrigger({ value: 'all', text: 'All' })
          STabsTrigger({ value: 'unread', text: 'Unread' })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
  }
  SCardFooter() {
    SButton({ text: 'Mark all as read', icon: 'check', block: true })
      .onClick(() => { this.push = !this.push })
  }
}`;

const { lang } = useData();
const zh = computed(() => lang.value.startsWith('zh'));
const code = ref(SAMPLE);
const stateName = ref('');
const debounced = ref(SAMPLE);
let timer = 0;
watch(code, (v) => {
  clearTimeout(timer);
  timer = setTimeout(() => (debounced.value = v), 250);
});

onMounted(() => {
  const m = /code=([^&]*)/.exec(window.location.hash);
  if (m) {
    try {
      code.value = decodeURIComponent(m[1]);
      debounced.value = code.value;
    } catch (e) {
      // keep sample
    }
  }
  const s = /state=([\w$]+)/.exec(window.location.hash);
  if (s) {
    stateName.value = s[1];
  }
});

const state = computed(() => (stateName.value && DEMO_STATE[stateName.value]) || {});
const errors = computed(() => compile(debounced.value).errors);
</script>

<template>
  <div class="ark-playground">
    <ArkThemePicker />
    <div class="ark-playground-grid">
      <div class="ark-playground-editor">
        <div class="ark-playground-label">ArkTS</div>
        <textarea v-model="code" spellcheck="false" autocapitalize="off" autocomplete="off" />
        <div v-if="errors.length" class="ark-playground-errors">
          <div v-for="(e, i) in errors" :key="i">⚠ {{ e.message }} @{{ e.pos }}</div>
        </div>
      </div>
      <div class="ark-playground-output">
        <div class="ark-playground-label">{{ zh ? '网页预览（近似）' : 'Web preview (approximate)' }}</div>
        <ClientOnly>
          <ArkPreview :code="debounced" :state="state" />
        </ClientOnly>
      </div>
    </div>
  </div>
</template>
