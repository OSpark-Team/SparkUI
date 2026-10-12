import DefaultTheme from 'vitepress/theme';
import ArkDemo from './components/ArkDemo.vue';
import ArkPreview from './components/ArkPreview.vue';
import ArkPlayground from './components/ArkPlayground.vue';
import ArkThemePicker from './components/ArkThemePicker.vue';
import '../generated/tokens.css';
import './previewer/preview.css';
import './style.css';

/** @type {import('vitepress').Theme} */
export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('ArkDemo', ArkDemo);
    app.component('ArkPreview', ArkPreview);
    app.component('ArkPlayground', ArkPlayground);
    app.component('ArkThemePicker', ArkThemePicker);
  }
};
