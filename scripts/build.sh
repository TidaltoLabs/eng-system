#!/usr/bin/env bash
# eng-system 构建脚本
#
# 用法：
#   ./scripts/build.sh          从 skills/ + templates/ 生成 plugins/<host>/ 产物
#   ./scripts/build.sh check    仅做内容自检（不生成产物）
#
# 设计原则
#   内容只有一份：skills/ 与 templates/ 是唯一手写源。
#   适配层只放清单：adapters/ 下每个平台一个目录，只含清单文件。
#   产物入库：plugins/ 下是生成结果，供各市场清单（.claude-plugin/、.agents/plugins/）指向。
#
# 为什么按宿主分目录而不是共用一份：
#   若同一目录同时存在根 plugin.json 与 .claude-plugin/plugin.json，
#   Codex/Copilot 会优先把根清单当 Agent Plugins 解释，忽略 Claude 专属组件。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/plugins"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

# ---------- 自检 ----------
check() {
  local fail=0

  echo "== 技能 =="
  for d in "$ROOT"/skills/*/; do
    local name skill fm fmname
    name="$(basename "$d")"
    skill="$d/SKILL.md"
    if [[ ! -f "$skill" ]]; then
      red "  缺少 SKILL.md：$name"; fail=1; continue
    fi
    fm="$(sed -n '/^---$/,/^---$/p' "$skill" | head -20)"
    grep -q '^name:' <<<"$fm"        || { red "  ${name}：frontmatter 缺 name"; fail=1; }
    grep -q '^description:' <<<"$fm" || { red "  ${name}：frontmatter 缺 description"; fail=1; }
    fmname="$(grep '^name:' <<<"$fm" | head -1 | sed 's/^name:[[:space:]]*//')"
    if [[ "$fmname" != "$name" ]]; then
      red "  ${name}：frontmatter name ($fmname) 与目录名不一致"; fail=1
    fi
    # Agent Skills 规范：kebab-case
    if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      red "  ${name}：非 kebab-case"; fail=1
    fi
    if (( ${#name} > 64 )); then red "  ${name}：超过 64 字符"; fail=1; fi
    local desc
    desc="$(grep '^description:' <<<"$fm" | head -1)"
    if (( ${#desc} > 600 )); then yellow "  ${name}：description 偏长（DSH 目录默认截断 500）"; fi
    grep -q '反模式' "$skill" || yellow "  ${name}：无「反模式」节（建议补）"
    grep -qE '自检|检查清单' "$skill" || yellow "  ${name}：无自检清单（建议补）"
    green "  通过：$name"
  done

  echo "== 模板 =="
  for t in AGENTS.md.tpl ROADMAP.md.tpl CHANGELOG.md.tpl README.md.tpl milestone.md.tpl research.md.tpl decision.md.tpl architecture.md.tpl review.md.tpl gitignore.tpl; do
    [[ -f "$ROOT/templates/$t" ]] || { red "  缺少 templates/$t"; fail=1; }
  done

  echo "== 占位符残留 =="
  if grep -rInE '\b(TODO|FIXME|XXX)\b' "$ROOT/templates" "$ROOT/skills" 2>/dev/null; then
    red "  发现 TODO/FIXME/XXX 残留"; fail=1
  else
    green "  无残留"
  fi

  echo "== 适配层洁净度 =="
  if find "$ROOT/adapters" \( -name 'SKILL.md' -o -name '*.tpl' \) | grep -q .; then
    red "  适配层出现技能或模板（内容应只在 skills/ 与 templates/）"; fail=1
  else
    green "  适配层干净"
  fi

  echo "== 市场清单 =="
  for f in "$ROOT/.claude-plugin/marketplace.json" "$ROOT/.agents/plugins/marketplace.json" "$ROOT/marketplace.json"; do
    if [[ -f "$f" ]]; then
      if python3 -I -c "import json;json.load(open('$f'))" 2>/dev/null; then
        green "  JSON 合法：${f#$ROOT/}"
      else
        red "  JSON 非法：${f#$ROOT/}"; fail=1
      fi
    else
      yellow "  缺少：${f#$ROOT/}"
    fi
  done

  echo "== 上架准备度 =="
  # 官方市场（zai-org/zcode-plugins）要求：双语 README 与双语描述
  if [[ -f "$ROOT/README_EN.md" ]]; then
    green "  README_EN.md 存在（产物双语源齐备）"
  else
    red "  缺少 README_EN.md（产物 README.md 的英文源）"; fail=1
  fi
  python3 -I - "$ROOT" <<'I18NEOF'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
d = json.loads((root/"marketplace.json").read_text())
bad = False
for pl in d.get("plugins", []) or []:
    i18n = pl.get("description_i18n") or {}
    if not str(i18n.get("en") or "").strip() or not str(i18n.get("zh-CN") or "").strip():
        print(f"  [fail] 市场条目 {pl.get('name')} 缺少 description_i18n（en/zh-CN）"); bad = True
if not bad:
    print("  description_i18n（en + zh-CN）齐备")
sys.exit(1 if bad else 0)
I18NEOF
  [[ $? -eq 0 ]] || fail=1

  echo "== DSH bundle =="
  for f in adapters/dsh/bundle/package.json adapters/dsh/bundle/cordis.patch.yml adapters/dsh/bundle/index.js; do
    [[ -f "$ROOT/$f" ]] || { red "  缺少 $f"; fail=1; }
  done
  if [[ -f "$ROOT/adapters/dsh/bundle/package.json" ]]; then
    bver="$(python3 -I -c "import json;print(json.load(open('$ROOT/adapters/dsh/bundle/package.json'))['version'])")"
    if [[ "$bver" != "$VERSION" ]]; then
      red "  bundle version=$bver != VERSION=$VERSION（源文件必须与 VERSION 同步）"; fail=1
    else
      green "  bundle 版本与 VERSION 一致"
    fi
  fi

  echo "== 清单一致性 =="
  # 所有清单里的 name 必须一致；version 策略：Claude 适配器不得含 version（钉死会阻断
  # commit SHA 更新追踪），其余插件清单的 version 必须等于 VERSION
  python3 -I - "$ROOT" "$VERSION" <<'PYEOF'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1]); ver = sys.argv[2]
files = [
    root/"adapters/agent-plugins/plugin.json",
    root/"adapters/claude/.claude-plugin/plugin.json",
    root/"adapters/zcode/.zcode-plugin/plugin.json",
    root/".claude-plugin/marketplace.json",
    root/".agents/plugins/marketplace.json",
    root/"marketplace.json",
]
names = set(); bad = False
for f in files:
    if not f.exists():
        print(f"  [warn] 缺少 {f.relative_to(root)}"); continue
    d = json.loads(f.read_text())
    n = d.get("name")
    if n: names.add(n)
    # Claude 适配器不写 version：让 Claude Code 按 commit SHA 追踪更新
    if f == root/"adapters/claude/.claude-plugin/plugin.json":
        if "version" in d:
            print(f"  [fail] {f.relative_to(root)} 含 version 字段——会钉死插件版本、阻断 HEAD 更新追踪，请删除"); bad = True
    # 其余插件清单的 version 必须与 VERSION 一致
    elif f.name == "plugin.json" and d.get("version") != ver:
        print(f"  [fail] {f.relative_to(root)} version={d.get('version')} != {ver}"); bad = True
    # 市场条目必须指向存在的目录，且版本一致
    for pl in d.get("plugins", []) or []:
        src = pl.get("source")
        path = None
        if isinstance(src, str): path = src
        elif isinstance(src, dict): path = src.get("path")
        if path:
            tgt = (root/path).resolve()
            if not tgt.exists():
                print(f"  [fail] {f.relative_to(root)} -> {path} 不存在"); bad = True
        if pl.get("version") and pl["version"] != ver:
            print(f"  [fail] {f.relative_to(root)} 条目 version={pl['version']} != {ver}"); bad = True
if len(names) != 1:
    print(f"  [fail] 清单 name 不一致: {names}"); bad = True
if not bad:
    print(f"  name={names.pop()} 一致；version 策略通过（Claude 侧无 version，其余 ={ver}）；所有 source 路径存在")
sys.exit(1 if bad else 0)
PYEOF
  [[ $? -eq 0 ]] || fail=1

  echo "== 构建产物标识 =="
  if [[ -d "$ROOT/plugins" ]]; then
    local missing=0
    for d in "$ROOT"/plugins/*/; do
      if ! head -1 "$d/README.md" 2>/dev/null | grep -q 'build artifact' \
         || ! head -1 "$d/README_CN.md" 2>/dev/null | grep -q '本目录是构建产物'; then
        # 旧产物：build 会重写，属提示而非错误
        yellow "  待补齐横幅（下次 build 自动修复）：${d#$ROOT/}"; missing=1
      fi
    done
    [[ $missing -eq 0 ]] && green "  全部带横幅（双语）"
  else
    yellow "  plugins/ 尚未生成（首次运行 build 时创建）"
  fi

  echo "== 陈旧产物 =="
  if [[ -d "$ROOT/dist" ]]; then
    red "  dist/ 已废弃（市场清单指向 plugins/），请删除"
    fail=1
  else
    green "  无 dist/ 残留"
  fi

  echo "== 技能目录不得嵌套 =="
  if find "$ROOT/skills" -mindepth 3 -name 'SKILL.md' | grep -q .; then
    red "  发现嵌套 SKILL.md（DSH 与 Agent Plugins 均不递归）"; fail=1
  else
    green "  扁平结构"
  fi

  if [[ $fail -ne 0 ]]; then echo; red "自检未通过"; exit 1; fi
  echo; green "自检通过"
}

# ---------- 构建 ----------
stage() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$ROOT/skills"    "$dest/skills"
  cp -R "$ROOT/templates" "$dest/templates"
  # 产物 README 顶部加横幅，防止有人直接改构建产物
  # 双语：README.md（英文，官方市场惯例的默认语言）+ README_CN.md（中文）
  {
    echo "> ⚠️ **This directory is a build artifact** (generated by \`scripts/build.sh\` from \`skills/\` + \`templates/\`)."
    echo "> Do not edit directly; change the source files and rebuild instead."
    echo
    cat "$ROOT/README_EN.md"
  } > "$dest/README.md"
  {
    echo "> ⚠️ **本目录是构建产物**（由 \`scripts/build.sh\` 从 \`skills/\` + \`templates/\` 生成）。"
    echo "> 请勿直接修改；改动请改源文件后重新构建。"
    echo
    cat "$ROOT/README.md"
  } > "$dest/README_CN.md"
  cp    "$ROOT/LICENSE"   "$dest/LICENSE"
}

inject_version() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if grep -q '"version"' "$f"; then
    sed -i.bak -E "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$VERSION\"/" "$f"
    rm -f "$f.bak"
  fi
}

build() {
  rm -rf "$OUT"
  echo "== 构建 eng-system v$VERSION =="

  # Agent Plugins（Codex / Cursor / Copilot 共用）
  local d="$OUT/agent-plugins"
  stage "$d"
  cp "$ROOT/adapters/agent-plugins/plugin.json" "$d/plugin.json"
  inject_version "$d/plugin.json"
  green "  plugins/agent-plugins/"

  # Claude Code
  d="$OUT/claude"
  stage "$d"
  mkdir -p "$d/.claude-plugin"
  cp "$ROOT/adapters/claude/.claude-plugin/plugin.json" "$d/.claude-plugin/plugin.json"
  inject_version "$d/.claude-plugin/plugin.json"
  green "  plugins/claude/"

  # ZCode
  d="$OUT/zcode"
  stage "$d"
  mkdir -p "$d/.zcode-plugin"
  cp "$ROOT/adapters/zcode/.zcode-plugin/plugin.json" "$d/.zcode-plugin/plugin.json"
  inject_version "$d/.zcode-plugin/plugin.json"
  green "  plugins/zcode/"

  # DSH：可安装 bundle（技能 + templates + provider 薄壳）+ 零安装说明
  d="$OUT/dsh"
  stage "$d"
  cp "$ROOT/adapters/dsh/README.md" "$d/DSH-INSTALL.md"
  # bundle 三件套：package.json / cordis.patch.yml / index.js（源在 adapters/dsh/bundle/）
  cp "$ROOT/adapters/dsh/bundle/package.json"     "$d/package.json"
  cp "$ROOT/adapters/dsh/bundle/cordis.patch.yml" "$d/cordis.patch.yml"
  cp "$ROOT/adapters/dsh/bundle/index.js"         "$d/index.js"
  inject_version "$d/package.json"
  green "  plugins/dsh/（bundle + 零安装载荷）"

  echo
  echo "产物："
  find "$OUT" -maxdepth 2 -not -path "$OUT" | sort | sed 's|^|  |'
}

case "${1:-build}" in
  check) check ;;
  build) check; echo; build ;;
  *) red "未知参数：$1（可用：build | check）"; exit 2 ;;
esac
