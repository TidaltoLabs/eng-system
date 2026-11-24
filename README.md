---
title: eng-system · 工程体系技能组
type: project-readme
status: active
updated: 2026-11-24
related:
  - "[[AGENTS]]"
  - "[[CHANGELOG]]"
---

# eng-system

一套可跨项目复用的**工程文档体系**技能组：把「骨架 / 里程碑 / 调研 / 决策 / 审查」五件事固化下来。

> 它不是项目管理模板，而是**流程约束**——解决的是"文档写了但没人守"的问题。

---

## 为什么需要它

项目文档通常死于三件事：

1. **没有门禁**——「调研做完再开工」只是口号，实际是边写边改
2. **结论会漂**——同一件事在五份文档里有五种说法，没人知道哪个是最新
3. **历史会丢**——决策只存在对话里，上下文一压缩就没了

这五个技能分别对应这三个死法。

---

## 技能清单

| 技能 | 解决什么 | 核心产物 |
|---|---|---|
| `eng-bootstrap` | 项目起步时一次性钉死能力边界、版本节奏、验收门禁 | 五个顶层文件 + docs 四目录 |
| `eng-milestone` | 里程碑怎么切、什么算能开工、什么算通过 | 九段结构 + 覆盖率门禁 |
| `eng-research` | 调研怎么写才算合格（而非资料汇编） | 四档标注 + 五类谬误检查 |
| `eng-decision` | 决策怎么记、何时该独立成文、推翻后怎么留痕 | 六段结构 + superseded 机制 |
| `eng-audit` | 文档变多后的一致性校对 | 机械五项 + 逻辑四项 + 分级 |

**推荐使用顺序**：`bootstrap` → `milestone` →（每个里程碑前）`research` →（做取舍时）`decision` →（开工前/冻结前）`audit`。

---

## 目录结构

```
eng-system/
├── README.md
├── AGENTS.md            # 贡献者规约
├── CHANGELOG.md
├── LICENSE              # MIT
├── VERSION              # 版本号单一来源
├── skills/              # 唯一手写内容源（Agent Skills 格式）
│   ├── eng-bootstrap/SKILL.md
│   ├── eng-milestone/SKILL.md
│   ├── eng-research/SKILL.md
│   ├── eng-decision/SKILL.md
│   └── eng-audit/SKILL.md
├── templates/           # 被技能引用的脚手架模板
├── adapters/            # 各平台清单（只放清单，不放内容）
│   ├── agent-plugins/plugin.json
│   ├── claude/.claude-plugin/plugin.json
│   ├── zcode/.zcode-plugin/plugin.json
│   └── dsh/README.md
├── plugins/             # 构建产物（入库，供市场清单指向）
│   ├── agent-plugins/   # Codex / Cursor / Copilot
│   ├── claude/
│   ├── zcode/
│   └── dsh/             # 零安装载荷
├── .claude-plugin/marketplace.json    # Claude 市场清单
├── .agents/plugins/marketplace.json   # Codex 市场清单
└── scripts/build.sh     # 生成 plugins/ + 自检
```

```

**设计原则：内容只有一份（`skills/` + `templates/`），适配层只放清单。**

---

## 作为市场源安装

本仓库既是**插件市场**（marketplace），也是**插件内容**。各工具只需识别仓库地址。

| 工具 | 市场清单 | 安装方式 |
|---|---|---|
| **Claude Code** | `.claude-plugin/marketplace.json` | `claude plugin marketplace add TidaltoLabs/eng-system` → `claude plugin install eng-system@eng-system`（会话内用 `/plugin ...` 同样可用） |
| **Codex CLI** | `.agents/plugins/marketplace.json` | `codex plugin marketplace add TidaltoLabs/eng-system` → `codex plugin add eng-system@eng-system` |
| **ZCode** | 根 `marketplace.json`（同时兼容 `.claude-plugin/marketplace.json`） | 插件市场 → 添加 → 添加插件市场 → 填 `TidaltoLabs/eng-system`（**仅 UI 入口，无 CLI**） |
| **Cursor / Copilot** | 同 Codex（Agent Plugins 1.0） | 插件面板添加本仓库 |
| **DSH** | 无官方市场 | 零安装：`cp -R plugins/dsh/skills/* ~/.agents/skills/`；社区市场见 `adapters/dsh/README.md` |

> 三条清单各自指向对应宿主目录：Claude → `plugins/claude/`，Codex/Cursor/Copilot → `plugins/agent-plugins/`，ZCode → `plugins/zcode/`。

### 零安装（不装插件）

适合只想用技能、不想装插件的场景：

```bash
# 技能
mkdir -p ~/.agents/skills
cp -R plugins/dsh/skills/* ~/.agents/skills/

# 模板必须放到技能目录的上两级，否则 ../../templates 解析失败
mkdir -p ~/.agents/templates
cp -R templates/* ~/.agents/templates/
```

> 同一份 `~/.agents/skills/` 会被 **Codex / Cursor / Copilot / Gemini CLI / DSH** 读取。

### 为什么按宿主分目录

`plugins/` 下每个宿主一个完整插件根，而不是共用一份。原因：若同一目录同时存在根 `plugin.json` 与 `.claude-plugin/plugin.json`，Codex/Copilot 会把根清单当 Agent Plugins 解释，忽略 Claude 专属组件。

内容仍然只有一份——`plugins/` 全部由 `scripts/build.sh` 从 `skills/` + `templates/` 生成。

---

## 设计取舍

| 取舍 | 原因 |
|---|---|
| 模板外置而非内联 | 模板体积大、会随项目演进；外置便于单点修改。代价：依赖相对路径可解析 |
| 五个技能而非一个大技能 | 触发场景差异大；合并会导致 description 模糊、自动触发失准 |
| 不绑定具体语言/框架 | 这套约束与语言无关，绑定会限制复用 |
| 不含具体项目的结论文档 | 那是项目专属资产，不属于体系 |

---

## 这套体系从哪来

提炼自一个真实项目从零到"可开工"的全过程：9 轮调研、3 份架构规格、7 个里程碑、2 份决策记录、一次全库校对（发现 6 个阻断级 + 19 个建议级问题）。

技能里那些"反模式"和"实际踩过的坑"，都是真踩过的，不是想象中的。
