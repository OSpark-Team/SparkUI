<script setup>
import { computed } from 'vue';
import { useData } from 'vitepress';
import { arkTheme, loadArkTheme } from '../previewer/store.js';
import PRESETS from '../../generated/presets.json';

loadArkTheme();
const { lang } = useData();
const zh = computed(() => lang.value.startsWith('zh'));
</script>

<template>
  <div class="ark-theme-picker">
    <label>
      <span>{{ zh ? '基础灰阶' : 'Base gray' }}</span>
      <select v-model="arkTheme.preset">
        <option v-for="p in PRESETS.presets" :key="p" :value="p">{{ p }}</option>
      </select>
    </label>
    <label>
      <span>{{ zh ? '强调色' : 'Accent' }}</span>
      <select v-model="arkTheme.accent">
        <option v-for="a in PRESETS.accents" :key="a" :value="a">{{ a === 'none' ? (zh ? '默认' : 'default') : a }}</option>
      </select>
    </label>
    <span class="ark-theme-picker-note">{{ zh ? '作用于本站所有预览' : 'Applies to every preview on the site' }}</span>
  </div>
</template>
