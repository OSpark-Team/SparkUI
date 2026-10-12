import DefaultTheme from 'vitepress/theme';
import ArkDemo from './components/ArkDemo.vue';
import ArkPreview from './components/ArkPreview.vue';
import ArkThemePicker from './components/ArkThemePicker.vue';
import '../generated/tokens.css';
import './previewer/preview.css';
import './previewer/blocks.css';
import './previewer/component-tokens.css';
import './style.css';

/** @type {import('vitepress').Theme} */
export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('ArkDemo', ArkDemo);
    app.component('ArkPreview', ArkPreview);
    app.component('ArkThemePicker', ArkThemePicker);
  }
};
