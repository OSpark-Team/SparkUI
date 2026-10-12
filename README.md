<div align="center">

# SparkUI

**精致、由 Token 驱动的 HarmonyOS ArkTS 组件库，对齐 shadcn/ui · shadcn-vue**

[![CI](https://github.com/OSpark-Team/SparkUI/actions/workflows/ci.yml/badge.svg)](https://github.com/OSpark-Team/SparkUI/actions/workflows/ci.yml)
[![ohpm](https://img.shields.io/badge/ohpm-%40ospark%2Fsparkui-blue)](https://ohpm.openharmony.cn/#/cn/detail/@ospark%2Fsparkui)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[文档](https://ospark-team.github.io/SparkUI/) · [English docs](https://ospark-team.github.io/SparkUI/en/) · [更新日志](CHANGELOG.md)

</div>

## 安装

```bash
ohpm install @ospark/sparkui
```

要求 HarmonyOS API 22（6.0.2）及以上，Stage 模型，ArkTS 状态管理 V2。用法见 [library/README-cn.md](library/README-cn.md)。

## 仓库结构

| 目录 | 内容 |
|---|---|
| `library/` | HAR 包 `@ospark/sparkui`（组件、主题、布局、浮层、动效） |
| `gallery/` | Gallery 应用：组件展示、主题编辑、布局检查 |
| `docs/` | VitePress 中英文档站（含 ArkTS → Web 预览器），`docs/design/` 为设计决策与组件规范 |
| `tools/` | 生成脚本（图标、Token）与本地开发、测试脚本 |

## 开发

1. 用 DevEco Studio 打开工程，复制 `build-profile.example.json5` 为 `build-profile.json5`，并在 File > Project Structure > Signing Configs 中自动签名。签名配置只保存在本地，不要提交到仓库。
2. 构建：`devecocli build`；单元测试：`bash tools/unit-test.sh`。
3. 文档站：`cd docs && npm install && npm run docs:dev`。

贡献组件前请阅读 [docs/design/component-guide.md](docs/design/component-guide.md)。

## 发布

在 `library/oh-package.json5` 和 `library/CHANGELOG.md` 中更新版本号后，推送 tag `v<版本号>`（例如 `v1.0.0-rc`），[Release 工作流](.github/workflows/release.yml) 会依次构建 HAR、发布到 ohpm 并创建 GitHub Release。所需 Secrets 见工作流文件头部的说明。

## 许可证

[MIT](LICENSE) © OSpark Team
