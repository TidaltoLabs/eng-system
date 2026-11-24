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

### 新增

- **可选机械化脚本**（`skills/<name>/scripts/`，bash + POSIX 工具，零网络依赖；正文均含等价人工手法）：
  - `eng-audit/scripts/mechanical-check.sh`：机械五项粗筛（悬空双链 / 编号一致性 / frontmatter / 路径引用 / 版本映射行提取），剔除代码块误报，输出 `文件:行号`
  - `eng-research/scripts/keyword-residue.sh`：推翻回写后的旧结论残留扫描（自动排除留痕行）
  - `eng-bootstrap/scripts/number-inventory.sh`：编号占用预检（D/A/R/M/NN 空间的占用、断号与下一个可用号）
- **3 份目录索引模板**：`research-index` / `milestones-index` / `architecture-index`（模板数 10 → 13），对应三个技能强制要求的索引文件
- **`eng-system`**：新增 mermaid 体系全景图（主路径 + 回路 + 产物引用链）与「子技能调用倾向」表（优先时机 / 输入 / 产物）

### 变更

- **7 个 SKILL.md 全量精炼重写**（1365 → 1201 行）：说明性文字压缩为判据与表格；触发词与调用边界重写（如 `eng-research`「验证」→「能力验证」、`eng-milestone`「验收」→「里程碑验收」、`eng-system` 补「该用哪个技能」「工程体系」）
- **AGENTS.md 修正案**：脚本从「禁止」改为「可选辅助 + 门禁」——技能在无脚本环境必须完整可用、正文含等价人工手法、只用 POSIX 工具
- `milestone.md.tpl` §6.1 去掉硬编码覆盖率「≥80%」（数字唯一权威在 AGENTS）；`research.md.tpl` 章节顺序对齐正文（修订在前、待确认在后）
- `eng-audit` §八 机械检查示例编号泛化，硬编码的旧项目编号示例移除

- **DSH bundle（`eng-system-dsh`）**：`plugins/dsh/` 从「仅零安装载荷」升级为可安装的 Cordis 插件包。provider 薄壳（`adapters/dsh/bundle/index.js`）运行时扫描包内 `skills/*/SKILL.md` 的 frontmatter，注册为 bundled skill provider（`ctx.skills.registerProvider`，rank = `BUNDLED_SKILL_RANK`）；代码不硬编码技能清单，内容仍只有一份。bundle 自带 `templates/`，`../../templates/` 相对引用在包内解析，安装后模板零拷贝
- `scripts/build.sh`：`plugins/dsh/` 构建追加 bundle 三件套（package.json / cordis.patch.yml / index.js）拷贝与版本注入；自检新增 DSH bundle 门禁（三件套齐备、源版本与 VERSION 一致）

### 变更

- DSH 安装从单一零安装路径变为双路径：bundle 安装（`dsh plugin --profile web add <plugins/dsh>`）或零安装（维持原样）
- `adapters/dsh/README.md` 重写：bundle 安装与验证命令、零安装路径、provider 维护边界（DSH 破坏性变更只需改一个文件）
- 实测记录（本机 0.2.1-rc.5）：profile 安装成功、`--dump-config` 确认补丁生效、headless 启动无插件错误、provider `list/get` 沙箱单测通过（7 技能元数据与正文完整）

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
