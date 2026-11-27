<div align="center">

<img src="logos/logo-256.png" alt="brand-kit-maker logo" width="112" height="112" />

# 品牌制作套件（brand-kit-maker）

**从品牌需求与设计讨论出发，定稿 Logo、配色、文案与字体，并导出完整站点品牌套件**

[![Version](https://img.shields.io/badge/version-v0.1.2-D94E3B)](https://github.com/TidaltoLabs/tidalto-plugins/blob/main/packages/brand-kit-maker/VERSION)
[![Hosts](https://img.shields.io/badge/hosts-Claude_Code_%7C_Codex-23887C)](#典型用法)
[![License: MIT](https://img.shields.io/badge/license-MIT-64748B)](LICENSE)

简体中文 · [English](README_EN.md)

</div>

---

把品牌需求、Logo 设计、颜色、文案和字体讨论整理成一份定稿配置，再生成可归档和使用的站点素材。

| 目录 | 内容 |
|---|---|
| [skills](skills/brand-kit/SKILL.md) | 对话评审与定稿流程 |
| [templates](templates/README.md) | 需求、讨论记录和配置模板 |
| [scripts](scripts/README.md) | 预览与品牌套件导出 |
| [examples](examples/README.md) | Ravn Kolchis 的底稿、样张和可复现的定稿配置 |
| [assets](assets/README.md) | 默认字体及其授权 |
| `logos/` | 插件图标（`logo.svg` 与 512/256/128 透明底 PNG） |

## 典型用法

在启用本地插件的 Codex 会话中提出品牌需求，或提供已有 Logo 并说明需要讨论哪些部分。跟随设计样张确认 Logo、配色、文案、字体和最终组合。也可以直接使用 PowerShell 7 在 Windows 本地运行导出。

```powershell
pwsh -File ./scripts/export-brand-kit.ps1 -ConfigPath ./examples/ravn-kolchis/brand.json -OutputDir ./rk-preview -PreviewOnly
pwsh -File ./scripts/export-brand-kit.ps1 -ConfigPath ./examples/ravn-kolchis/brand.json -OutputDir ./rk-delivery -DiscussionPath process/README.md
```

示例预览展示历史定稿。重新导出沿用其配色、文案、布局和画布尺寸，文字位置与紧裁结果可能略有差异。
