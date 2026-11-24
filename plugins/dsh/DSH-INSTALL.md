# DSH（DeepSeek Harness）安装说明

> **状态：v0.1.0 只提供「零安装」路径，不提供可安装插件包。**
> 原因见下，这是有意为之，不是遗漏。

---

## 为什么没有 dsh 插件包

DSH 的插件是 **Cordis 插件**（TypeScript 模块，导出 `apply(ctx)`），可分发单位是 npm bundle：

```
package.json  →  dsh.bundle.patch: ./cordis.patch.yml
cordis.patch.yml  →  insert 一条插件行
index.ts  →  导出 name 与 apply(ctx)
```

它的 `package.json.dsh` **没有 `skills` 字段**——技能必须由 provider 代码注册后才会被发现。也就是说：

- 不是「把 skills/ 放进包里就能被识别」
- 必须写一个真正可用的 Cordis provider，并验证 `ctx.skills.registerProvider(...)` 的调用方式

在 DSH 仍是 developer preview（官方明示会有破坏性变更）的情况下，发布未经实测的 provider 代码，比不发布更糟。

---

## 可用路径：零安装

DSH 原生支持 Agent Skills 格式，扫描根包括：

| 优先级 | 来源 | 路径 |
|---|---|---|
| 100 | project-dsh | `<项目根>/.dsh/skills` |
| 200 | project-agents | `<项目根>/.agents/skills` |
| 400 | user-dsh | `~/.dsh/skills` |
| 500 | user-agents | `~/.agents/skills` |

所以直接复制即可：

```bash
# 用户级（所有项目可用）
mkdir -p ~/.agents/skills
cp -R plugins/dsh/skills/* ~/.agents/skills/

# 或项目级
mkdir -p .agents/skills
cp -R plugins/dsh/skills/* .agents/skills/
```

> 同一份目录同时被 **Codex / Cursor / Copilot / Gemini CLI / DSH** 读取，这也是推荐路径。

---

## 注意事项

1. **技能目录必须扁平**：`skills/<name>/SKILL.md`，DSH 不递归嵌套。
2. **frontmatter 方言**：DSH 用 `whenToUse`（camelCase），Claude 用 `when_to_use`。本仓库的技能只写 `name` + `description`，两边都兼容。
3. **不要依赖宿主根变量**：DSH 不在 SKILL.md 正文里展开 `${PLUGIN_ROOT}`，技能内资源请用相对路径。

---

## 后续计划

若 DSH 提供稳定的 skill provider API，本仓库会补一个薄壳 bundle：

- `package.json` 声明 `dsh.bundle.patch`
- `cordis.patch.yml` 插入插件行
- `index.ts` 用 `import.meta.url` 定位包内 `skills/` 并注册

届时技能正文仍来自本仓库的 `skills/`，不产生第二份内容。
