# SparkUI

精致、由 Token 驱动的 HarmonyOS ArkTS 组件库，对齐 [shadcn/ui](https://ui.shadcn.com) / shadcn-vue。

- 90+ 组件：按钮、表单、浮层、菜单、数据表格、日历、日期与时间选择、图表、Toast……
- 布局块：AppShell、Sidebar、顶栏、窗口标题栏（自由多窗 / PC）、列表-详情、辅助面板
- 主题系统：直接粘贴 shadcn / tweakcn 主题 CSS；支持亮暗模式、实时切换、状态色（`--success` / `--warning` / `--info`），以及组件级 Token（`--card-background`、`--button-radius`……）
- 无感断点的响应式：组件根据实际拿到的空间自动适配
- 可配置动效（像 CSS transition 一样，可按组件单独设置），提供页面与内容切换动画
- 状态管理 V2，API 22+

## 安装

```bash
ohpm install @ospark/sparkui
```

## 使用

```ts
import { SparkProvider, SButton, SCard, SCardHeader, SCardTitle, SCardContent } from '@ospark/sparkui';

@Entry
@ComponentV2
struct Index {
  build() {
    SparkProvider() {
      SCard() {
        SCardHeader() { SCardTitle({ text: '你好，SparkUI' }) }
        SCardContent() {
          SButton({ text: '开始使用' }).onClick(() => console.info('clicked'))
        }
      }
    }
  }
}
```

### 主题

```ts
import { SparkUI } from '@ospark/sparkui';

SparkUI.themes.usePreset('zinc');            // 基础灰
SparkUI.themes.useAccent('blue');            // 强调色
SparkUI.themes.setMode('dark');              // 'light' | 'dark' | 'system'
SparkUI.themes.loadString(cssFromTweakcn);   // 任意 shadcn / tweakcn 导出的主题
SparkUI.themes.setVariable('--card-border-width', '0');   // 组件 Token
```

## 环境要求

- HarmonyOS API 22（6.0.2）及以上，Stage 模型，ArkTS 状态管理 V2

## 链接

- 文档与在线预览：https://ospark-team.github.io/SparkUI/
- 源码：https://github.com/OSpark-Team/SparkUI
- 更新日志：[CHANGELOG.md](CHANGELOG.md)

## 许可证

[MIT](LICENSE) © OSpark Team
