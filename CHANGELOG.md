---
title: 变更记录
type: changelog
status: active
updated: 2026-11-24
---

# CHANGELOG

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

---

## [Unreleased]

## [0.1.0] - 2026-11-24

### 新增

- 五个工程体系技能：
  - `eng-bootstrap`：工程骨架引导（能力边界 / 版本节奏 / 验收门禁）
  - `eng-milestone`：里程碑规划与验收（九段结构 / 前置调研硬门禁 / 覆盖率三档）
  - `eng-research`：调研协议（四档标注 / 五类谬误 / 多轮修订留痕）
  - `eng-decision`：决策记录（六段结构 / superseded 机制 / 编号约定）
  - `eng-audit`：一致性审查（机械五项 / 逻辑四项 / 分级 / 冻结流程）
- 七份脚手架模板：`AGENTS` / `ROADMAP` / `CHANGELOG` / `README` / `milestone` / `research` / `decision`
- ZCode 与 Claude Code 插件清单
- `scripts/build.sh`：从单一内容源生成各平台可安装产物

### 说明

- 内容与适配分离：`skills/` + `templates/` 是唯一内容源，`adapters/` 只放清单
- 模板以 `../../templates/` 相对路径引用；宿主提供根路径变量时优先使用
