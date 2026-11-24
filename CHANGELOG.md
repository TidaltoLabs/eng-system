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

## [0.2.0] - 2026-11-24

### 新增

- **`eng-system`（总入口）**：阶段判断、接手导览、两条合法路径（骨架先行 / 调研先行）、轻量分档、执行闭环、发版、交接清单、交付汇报格式
- **`eng-architecture`**：架构规格协议——约束表（客观/工程分类 + 来源列）、`A<N>` 文档编号与 `C<N>` 约束编号分离、追加「校准」节而非重写、架构索引与依赖方向
- 模板 3 份：`architecture.md.tpl`、`review.md.tpl`、`gitignore.tpl`

### 修复（来自两轮技能审查）

- **`templates/milestone.md.tpl` 版本占位符错误**：`0.<NN>.z` → `0.<N>.z`。原写法会让 M01 产出 `v0.01.0`
- **`eng-audit` 角色冲突**：「不允许修改文件」与「阻断级全部修复」并存 → 拆为「阶段一审查（只报告）/ 阶段二修复（显式指令）」
- **`eng-audit` 产出物缺失**：报告落盘 `docs/reviews/R<N>-<slug>.md`；编号用 `R`，不再占用决策的 `D` 号
- **`eng-milestone` 缺产物路径与命名**：补 `docs/milestones/M<NN>-<slug>.md` 与 slug 规则、「先读 ROADMAP 取编号」
- **5 项「能否开工」门禁未进模板**：已落入 `milestone.md.tpl` §3.3
- **覆盖率数字四处重复**：统一为「以 `AGENTS.md` §五 为唯一权威」，其余不复述数字
- **覆盖率门禁在文档阶段无法判真伪**：改为按阶段分档，文档阶段标 `N/A`
- **测试分层自相矛盾**（四层 vs fixtures）：统一为「单元/集成/E2E/故障注入」，`fixtures/` 归为素材目录
- **`eng-decision` 与 `eng-research` 边界矛盾**：改为「调研写可引用的结论+证据，决策写取舍+代价」
- **设计公理双写**（README 与 AGENTS）：收敛到 AGENTS 为唯一权威
- **`eng-bootstrap` 只面向全新项目**：补三种入口（冷启动 / 调研先行 / 补建迁移），迁移补「编号占用预检」「移动而非复制」
- **「里程碑不得依赖其他里程碑」与工程常识相反**：改为「声明依赖 + 标注可并行批次」
- **触发词冲突**：`eng-research` 去掉「查一下」「技术选型」；`eng-decision` 改为「选型记录」
- **内部调研可被 4 行空话满足**：要求每行给出模块名/接口名/`C<NN>`/`D-xx`
- **验收记录被误判为反模式**：改为「填写时点说明」+ 补验收动作归属
- **`dist/` 陈旧副本已入库**：删除，并在自检中禁止其再次出现
- **构建产物可被直接编辑**：产物 README 顶部加「生成物勿手改」横幅，自检校验

### 变更

- 技能数 5 → 7；模板数 7 → 10
- 自检新增：清单一致性交叉校验（name/version/source 路径）、产物横幅、`dist/` 残留、模板清单完整性
- README 改为双路径 + 轻量分档 + 「每个技能可单独触发」声明

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
