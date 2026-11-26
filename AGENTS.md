---
title: tidalto-plugins 贡献者规约
type: agents-guide
status: active
updated: 2026-11-26
applies_to: 本仓库
---

# AGENTS.md · tidalto-plugins 贡献者规约

> 本仓库是**多插件市场仓库**，不是应用项目。因此只保留与插件及技能质量相关的约束。

---

## 一、内容与适配分离

每个插件在 `packages/<plugin>/` 下独立维护；根 `plugins/<plugin>/<host>/` 全部为构建产物，禁止手改。

| 目录 | 只放什么 | **不放**什么 |
|---|---|---|
| `packages/<plugin>/skills/` | SKILL.md（规则、判据、反模式）+ 可选 `scripts/` / `references/` | 平台特有的清单、版本号 |
| `packages/<plugin>/templates/` | 脚手架模板（如 `*.tpl` / 配置模板） | 与平台相关的字段 |
| `packages/<plugin>/adapters/<host>/` | 各平台的清单与适配薄壳（`plugin.json`、DSH bundle 等） | 任何技能正文或模板 |
| `plugins/<plugin>/<host>/` | 由 `./scripts/build.sh` 生成的可安装产物 | 手写源码 |

**判据**：修改一个技能的表述，应该只改 `packages/<plugin>/skills/` 下的一个文件并重跑 `./scripts/build.sh`；若需要同步改 `adapters/`，说明内容漏到了适配层。

---

## 二、技能写作规范

### 2.1 frontmatter

```yaml
---
name: <kebab-case，与目录名一致>
description: <清晰描述 + 适用场景 + 触发词 / 负向边界>
---
```

`description` 必须让 Agent 在未读正文时就能准确判断「何时触发、何时不触发」，否则自动触发会漏触或误触。

### 2.2 正文要求（工程流程类技能）

| 必须有 | 为什么 |
|---|---|
| 一句话说明「这个技能解决什么问题」 | 决定读者要不要往下读 |
| **可判真伪的判据**（能/不能、合格/不合格） | 否则技能退化成建议 |
| **反模式表**（错法 + 后果 + 正确做法） | 防止踩已知坑 |
| **自检清单**（可勾选） | 让执行者能自查 |

### 2.3 禁止

- ❌ 只写「应该注意 X」而不给判据
- ❌ 写「最佳实践」这类无法验证的表述
- ❌ 拷贝具体项目的结论（那是项目资产，不是体系）
- ❌ 引入与内容无关的营销语气
- ❌ 直接编辑 `plugins/` 下的构建产物

---

## 三、跨平台与多宿主约定

| 要求 | 说明 |
|---|---|
| SKILL.md 只用 YAML frontmatter + Markdown | 不使用平台特有语法 |
| 包内资源用相对路径（如 `../../templates/`） | 并在技能内注明「以技能目录上两级为插件根；宿主提供根路径变量时优先使用」 |
| **按宿主能力声明适配** | 并非所有插件都要全宿主适配——如依赖宿主生图能力的插件只声明对应宿主的 `adapters/<host>/` 与市场条目，并在 README 明示适用范围与运行环境前提 |
| 流程类技能的辅助脚本保持可选 | 通用流程技能（如 `eng-system`）在无脚本环境必须完整可用、正文含等价人工手法、脚本只用 POSIX 工具且无网络访问；明确声明为本地导出工具的插件（如 `brand-kit-maker`）须在 README 标明运行时前提 |

---

## 四、变更与版本

每个插件在 `packages/<plugin>/VERSION` 独立维护版本号：

- 技能或模板的**行为变化**（判据变了、门禁变了）→ minor 版本 +1
- 仅文字修正 / 描述优化 / 资源补充 → patch +1
- 新增技能 → minor +1，并同步插件 README
- 新增插件 → 新建 `packages/<plugin>/`，补齐目标宿主 `adapters/` 与对应根市场清单，并同步根 `README.md` / `README_EN.md`
- 破坏兼容 → major +1，并在对应 CHANGELOG 写迁移方式
- **不打仓库级 git tag**：多插件共享同一仓库，仓库级 `vX.Y.Z` tag 无对应语义；各插件版本仅以 `packages/<plugin>/VERSION`、各宿主清单中的 `version` 字段与对应 `CHANGELOG.md` 为唯一依据，直接提交推送 `main` 即可

---

## 五、自检

```
[ ] 每个 SKILL.md 的 name 为 kebab-case 且与目录名一致
[ ] 每个 SKILL.md 的 description 明确触发时机与边界
[ ] 未在 adapters/ 中出现技能正文或模板
[ ] 每个插件的 VERSION、各 adapter plugin.json 与根市场清单版本一致
[ ] 运行 ./scripts/build.sh 全量通过（含 agy plugin validate --strict）
[ ] 根 README.md / README_EN.md 插件目录与实际 packages/ 一致
```
