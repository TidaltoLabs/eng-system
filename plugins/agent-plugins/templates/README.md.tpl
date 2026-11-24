---
title: <PROJECT> — <一句话定位>
type: project-readme
status: active
updated: <YYYY-MM-DD>
related:
  - "[[AGENTS]]"
  - "[[ROADMAP]]"
  - "[[CHANGELOG]]"
---

# <PROJECT>

> <一句话说明它是什么、解决什么问题。>

## 一句话定位

<给谁用、用到什么规模、明确不做什么。>

## 设计公理

1. **<公理一>** — <解释>
2. **<公理二>** — <解释>
3. **<公理三>** — <解释>

---

## 从哪读起

| 你想做什么 | 读这个 |
|---|---|
| 了解项目规则（**必读**） | [[AGENTS]] |
| 看当前进度与版本号 | [[ROADMAP]] |
| 看变更历史 | [[CHANGELOG]] |
| 理解系统设计 | `docs/architecture/` |
| 看某个里程碑要做什么 | `docs/milestones/` |
| 查调研依据 | `docs/research/` |
| 查某个决定为什么这么定 | `docs/decisions/` |

---

## 目录结构

```
<PROJECT>/
├── README.md
├── AGENTS.md
├── ROADMAP.md
├── CHANGELOG.md
├── docs/
│   ├── architecture/
│   ├── research/
│   ├── milestones/
│   └── decisions/
└── _refs/               # 外部参考源码快照（gitignore）
```

---

## 设计要点（一屏速览）

| 维度 | 决定 |
|---|---|
| 语言 | <语言> |
| 核心 | <核心机制一句话> |
| 存储 | <方案> |
| 部署 | <形态> |

---

## 当前阶段

<当前在做哪个里程碑；或「调研阶段已完成，进入里程碑开发」。>

> 开工前请确认：当前里程碑的**前置调研已落盘**（见 [[AGENTS]] §四）。这是硬门禁。
