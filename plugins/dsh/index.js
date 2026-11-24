/**
 * eng-system 的 DeepSeek Harness bundle。
 *
 * 把包内 `skills/` 下的七个工程体系技能注册为一个 bundled skill provider：
 * 技能清单在运行时从各 SKILL.md 的 frontmatter 解析而来（name / description），
 * 代码里不硬编码技能清单——内容仍只有一份。
 *
 * 结构约定（由 scripts/build.sh 保证）：
 *   <包根>/skills/<name>/SKILL.md   技能正文
 *   <包根>/templates/               脚手架模板（SKILL.md 内 ../../templates/ 引用由此解析）
 *
 * @module eng-system-dsh
 */
import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { BUNDLED_SKILL_RANK } from "@deepseek-ai/dsh-skill";

/** Cordis 插件名，必须与 cordis.patch.yml 的 insert.id 一致。 */
export const name = "eng-system";

/** 声明依赖宿主的 skills 服务（apply 里调用 ctx.skills.registerProvider）。 */
export const inject = ["skills"];

/** provider 标识，出现在每个技能元数据的 provider 字段里。 */
const PROVIDER_NAME = "eng-system";

/** 包内技能目录（构建产物：<包根>/skills/）。 */
const SKILLS_DIR_URL = new URL("./skills/", import.meta.url);

/**
 * 解析 SKILL.md 头部 frontmatter。
 *
 * 本仓库的 frontmatter 每个字段都是单行（name / description / 可选 whenToUse），
 * 因此用逐行正则即可，不引入 YAML 依赖。
 *
 * @param {string} text - SKILL.md 全文
 * @returns {Record<string, string>} 解析出的字段；无 frontmatter 时为空对象
 */
function parseFrontmatter(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
  const fields = {};
  if (!match) return fields;
  for (const line of match[1].split(/\r?\n/)) {
    const pair = /^([\w-]+):\s*(.+)$/.exec(line);
    if (pair) fields[pair[1]] = pair[2].trim().replace(/^['"]|['"]$/g, "");
  }
  return fields;
}

/** 候选清单缓存：技能目录随包发布、运行期不变，扫一次即可。 */
let candidatesCache;

/**
 * 扫描包内 skills/，构造全部技能的候选元数据。
 *
 * @returns {Promise<Array<object>>} 候选数组（含 locator 与 per-skill resourceBase）
 */
async function listCandidates() {
  candidatesCache ??= (async () => {
    const entries = await readdir(SKILLS_DIR_URL, { withFileTypes: true });
    const candidates = [];
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const locator = new URL(`./${entry.name}/SKILL.md`, SKILLS_DIR_URL);
      const frontmatter = parseFrontmatter(await readFile(locator, "utf8"));
      // 缺 name/description 的目录不成技能（自检会拦，这里兜底跳过）
      if (!frontmatter.name || !frontmatter.description) continue;
      candidates.push({
        name: frontmatter.name,
        description: frontmatter.description,
        ...(frontmatter.whenToUse ? { whenToUse: frontmatter.whenToUse } : {}),
        invocation: { modelInvocable: true, userInvocable: true },
        provider: PROVIDER_NAME,
        source: "bundled",
        // per-skill 目录作为资源基：<技能目录>/../../templates/ 即包内 templates/
        resourceBase: {
          kind: "directory",
          path: fileURLToPath(new URL(`./${entry.name}/`, SKILLS_DIR_URL)),
        },
        rank: BUNDLED_SKILL_RANK,
        locator,
      });
    }
    return candidates;
  })();
  return candidatesCache;
}

/** bundled skill provider：list 出候选，get 读正文。 */
const provider = {
  name: PROVIDER_NAME,
  list: listCandidates,
  /**
   * 返回一个技能的完整定义（含 SKILL.md 正文）。
   *
   * @param {{ name?: string }} candidate - list() 给出的候选
   * @returns {Promise<object>} 技能定义；未知技能抛错
   */
  async get(candidate) {
    const candidates = await listCandidates();
    const known = candidates.find((item) => item.name === candidate?.name);
    if (!known) throw new Error(`eng-system: 未知技能 ${candidate?.name ?? "(空)"}`);
    return {
      name: known.name,
      description: known.description,
      ...(known.whenToUse ? { whenToUse: known.whenToUse } : {}),
      invocation: known.invocation,
      provider: known.provider,
      source: known.source,
      resourceBase: known.resourceBase,
      content: await readFile(known.locator, "utf8"),
    };
  },
};

/** 在 ctx.skills 上注册 bundled provider。 */
export function apply(ctx) {
  ctx.skills.registerProvider(() => provider);
}
