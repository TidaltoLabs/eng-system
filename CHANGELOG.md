---
title: tidalto-plugins 市场变更记录
type: changelog
status: active
updated: 2026-11-26
---

# CHANGELOG

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。各插件的细粒度变更历史维护在其各自目录下（如 [packages/eng-system/CHANGELOG.md](packages/eng-system/CHANGELOG.md)）。

---

## [Unreleased]

### 变更

- **仓库升级为多插件市场 `TidaltoLabs/tidalto-plugins`**（原 `TidaltoLabs/eng-system`）：
  - 手写源码统一迁入 `packages/<plugin>/`，构建产物统一输出到 `plugins/<plugin>/<host>/`
  - 市场清单（`.claude-plugin/marketplace.json`、`.agents/plugins/marketplace.json`、`marketplace.json`）顶层 `name` 统一改为 `tidalto-plugins`
  - `scripts/build.sh` 升级为多插件自动发现、全清单一致性校验与分宿主构建
  - 重写中英文根 `README.md` / `README_EN.md` 与 `AGENTS.md`

### 新增

- **`brand-kit-maker` 升级至 v0.1.2**：新增暖色调色卡扇形设计风格图标 `packages/brand-kit-maker/logos/`（`logo.svg` + 512/256/128 透明底 PNG），补齐 Claude Code / Codex 清单与 `.claude-plugin/marketplace.json` 的图标声明，并升级双语 README 头部
- **新插件 `brand-kit-maker` v0.1.1**（`packages/brand-kit-maker/`）：承接面向具备原生生图能力的 **Claude Code** 与 **Codex** 的品牌制作套件插件（含 `brand-kit` 技能、需求/交付参考、PowerShell 7 导出脚本、Cormorant Garamond 字体及 Ravn Kolchis 案例）
- `eng-system` 保持 **v0.3.4**（完整历史见 [packages/eng-system/CHANGELOG.md](packages/eng-system/CHANGELOG.md)），同步更新全部仓库链接与安装路径至 `TidaltoLabs/tidalto-plugins`
