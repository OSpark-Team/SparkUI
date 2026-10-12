import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, type DefaultTheme } from 'vitepress';
// @ts-ignore — plain ESM build script
import { generate } from '../scripts/generate.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

// Component pages, API data, previewer tokens & icons are generated from the ArkTS sources on start-up.
generate({ quiet: true });
const sidebarData = JSON.parse(fs.readFileSync(path.join(here, 'generated/sidebar.json'), 'utf8'));

/**
 * Base path. GitHub project pages are served from /<repo>/, so CI sets DOCS_BASE=/SparkUI/
 * (see .github/workflows/docs.yml). Locally it defaults to '/'.
 */
const base = (process.env.DOCS_BASE || '/').replace(/\/?$/, '/');

function guideSidebar(zh: boolean): DefaultTheme.SidebarItem[] {
  const p = zh ? '/guide/' : '/en/guide/';
  return [
    {
      text: zh ? '开始' : 'Getting Started',
      items: [
        { text: zh ? '介绍' : 'Introduction', link: p },
        { text: zh ? '安装与使用' : 'Installation', link: `${p}installation` },
        { text: zh ? '主题' : 'Theming', link: `${p}theming` },
        { text: zh ? '动效' : 'Motion', link: `${p}motion` },
        { text: zh ? '响应式布局' : 'Responsive Layout', link: `${p}responsive` },
        { text: zh ? '自适应上下文' : 'Adaptive Context', link: `${p}adaptive` },
        { text: zh ? '浮层' : 'Overlays', link: `${p}overlays` },
        { text: zh ? '网页预览器' : 'Web Previewer', link: `${p}previewer` }
      ]
    }
  ];
}

function componentSidebar(zh: boolean): DefaultTheme.SidebarItem[] {
  return [
    { text: zh ? '组件总览' : 'Overview', link: zh ? '/components/' : '/en/components/' },
    ...(sidebarData[zh ? 'zh' : 'en'] as DefaultTheme.SidebarItem[])
  ];
}

function sidebar(zh: boolean): DefaultTheme.Sidebar {
  const p = zh ? '/' : '/en/';
  return {
    [`${p}guide/`]: guideSidebar(zh),
    [`${p}components/`]: componentSidebar(zh),
    [`${p}playground`]: [...guideSidebar(zh), ...componentSidebar(zh)]
  };
}

function nav(zh: boolean): DefaultTheme.NavItem[] {
  const p = zh ? '/' : '/en/';
  return [
    { text: zh ? '指南' : 'Guide', link: `${p}guide/`, activeMatch: `^${p}guide/` },
    { text: zh ? '组件' : 'Components', link: `${p}components/`, activeMatch: `^${p}components/` },
    { text: zh ? '演练场' : 'Playground', link: `${p}playground` }
  ];
}

/** ```arkts preview state=XDoc [left]``` → <ArkDemo> with the shiki-highlighted code in its #code slot. */
function arkDemoPlugin(md: any) {
  const fence = md.renderer.rules.fence;
  md.renderer.rules.fence = (tokens: any[], idx: number, options: any, env: any, self: any) => {
    const token = tokens[idx];
    const info: string = token.info || '';
    const m = /^(arkts|ets|ts|typescript)\s+preview\b(.*)$/.exec(info.trim());
    if (!m) {
      return fence(tokens, idx, options, env, self);
    }
    const rest = m[2];
    const state = /state=([\w$]+)/.exec(rest)?.[1] ?? '';
    const left = /\bleft\b/.test(rest);
    // optional inline demo state: ```arkts preview {"on": true}
    const json = /(\{.*\})/.exec(rest)?.[1];
    token.info = m[1];
    const html = fence(tokens, idx, options, env, self);
    token.info = info;
    const code = encodeURIComponent(token.content);
    return `<ArkDemo code="${code}" state="${state}"${json ? ` data="${encodeURIComponent(json)}"` : ''}${left ? ' left' : ''}><template #code>${html}</template></ArkDemo>\n`;
  };
}

export default defineConfig({
  base,
  title: 'SparkUI',
  description: 'Refined, token-driven ArkTS component library for HarmonyOS — the shadcn-vue experience, native to ArkUI.',
  cleanUrls: true,
  lastUpdated: false,
  // internal design notes and build data live next to the site but are not published
  srcExclude: ['design/**', 'iterations/**', 'review/**', 'screenshots/**', 'scripts/**', 'README.md', '**/node_modules/**'],
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}logo.svg` }]],
  markdown: {
    languageAlias: { arkts: 'ts', ets: 'ts' },
    config: (md) => {
      md.use(arkDemoPlugin);
    }
  },
  locales: {
    root: {
      label: '简体中文',
      lang: 'zh-CN',
      themeConfig: {
        nav: nav(true),
        sidebar: sidebar(true),
        outline: { level: [2, 3], label: '本页目录' },
        docFooter: { prev: '上一页', next: '下一页' },
        darkModeSwitchLabel: '外观',
        sidebarMenuLabel: '菜单',
        returnToTopLabel: '回到顶部',
        langMenuLabel: '语言',
        footer: { message: 'MIT Licensed', copyright: 'SparkUI · 示例预览为网页近似渲染' }
      }
    },
    en: {
      label: 'English',
      lang: 'en-US',
      link: '/en/',
      themeConfig: {
        nav: nav(false),
        sidebar: sidebar(false),
        outline: { level: [2, 3] },
        footer: { message: 'MIT Licensed', copyright: 'SparkUI · previews are approximate web renderings' }
      }
    }
  },
  themeConfig: {
    logo: '/logo.svg',
    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: { buttonText: '搜索文档', buttonAriaLabel: '搜索文档' },
              modal: {
                noResultsText: '无法找到相关结果',
                resetButtonTitle: '清除查询条件',
                footer: { selectText: '选择', navigateText: '切换', closeText: '关闭' }
              }
            }
          }
        }
      }
    }
  }
});
