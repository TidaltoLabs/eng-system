# DSH（DeepSeek Harness）安装说明

> `plugins/dsh/` 现在是**标准 DSH bundle**（Cordis 插件包），由 `scripts/build.sh` 从
> `skills/` + `templates/` + `adapters/dsh/bundle/` 生成。两条安装路径都可用。

---

## 方式一：bundle 安装（推荐）

bundle 是自包含 npm 包：技能、模板、provider 薄壳（`index.js`）、清单三件套
（`package.json` + `cordis.patch.yml`）都在包内。安装后技能注册为 bundled
provider，`SKILL.md` 里的 `../../templates/` 相对引用在包内解析——**模板零拷贝**。

```bash
# 从本地构建产物安装（把路径换成你的仓库位置）
dsh plugin --profile web add /path/to/eng-system/plugins/dsh

# 从 GitHub 安装（pnpm 语法：commit/分支 + path 子目录；市场收录后会自动生成锁定 commit 的命令）
dsh plugin --profile web add "git+https://github.com/TidaltoLabs/eng-system.git#main&path:plugins/dsh"
```

安装验证：

```bash
dsh plugin --profile web list                 # 应看到 eng-system-dsh
dsh --profile web --dump-config               # 组合树应包含 eng-system 插件条目
```

> 版本策略与官方一致：bundle 版本号跟随仓库根 `VERSION`，内容变化必须升 SemVer，
> 已发布版本不可复用（市场按精确版本 + commit SHA 锁定安装）。

## 方式二：零安装（不装插件）

适合只想用技能、不装 Cordis 插件的场景。DSH 原生扫描 Agent Skills 目录：

| 优先级 | 来源 | 路径 |
|---|---|---|
| 100 | project-dsh | `<项目根>/.dsh/skills` |
| 200 | project-agents | `<项目根>/.agents/skills` |
| 400 | user-dsh | `~/.dsh/skills` |
| 500 | user-agents | `~/.agents/skills` |

```bash
# 用户级（所有项目可用）
mkdir -p ~/.agents/skills
cp -R plugins/dsh/skills/* ~/.agents/skills/

# 模板必须放到技能目录的上两级，否则 ../../templates 解析失败
mkdir -p ~/.agents/templates
cp -R plugins/dsh/templates/* ~/.agents/templates/

# 或项目级
mkdir -p .agents/skills .agents/templates
cp -R plugins/dsh/skills/* .agents/skills/
cp -R plugins/dsh/templates/* .agents/templates/
```

> 同一份 `~/.agents/skills/` 同时被 **Codex / Cursor / Copilot / Gemini CLI / DSH** 读取。

---

## 注意事项

1. **技能目录必须扁平**：`skills/<name>/SKILL.md`，DSH 不递归嵌套。
2. **frontmatter 方言**：DSH 用 `whenToUse`（camelCase），Claude 用 `when_to_use`。本仓库的技能只写 `name` + `description`，两边都兼容；bundle 的 provider 会把 `whenToUse` 透传给宿主。
3. **不要依赖宿主根变量**：DSH 不在 SKILL.md 正文里展开 `${PLUGIN_ROOT}`，技能内资源请用相对路径（bundle 内由 resourceBase 解析，零安装由目录约定解析）。
4. **DSH 仍是 developer preview**：provider 只依赖官方公开的 `dsh-skill` 注册 API（`ctx.skills.registerProvider` + `BUNDLED_SKILL_RANK`），并在本机 0.2.1-rc.5 上实测；后续版本若破坏 API，只需改 `adapters/dsh/bundle/index.js` 一个文件。
