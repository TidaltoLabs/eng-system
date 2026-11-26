#!/usr/bin/env bash
# tidalto-plugins 多插件构建脚本
#
# 用法：
#   ./scripts/build.sh          从 packages/<plugin>/ 生成 plugins/<plugin>/<host>/ 产物
#   ./scripts/build.sh check    仅做内容与清单自检（不生成产物）
#
# 设计原则
#   内容只有一份：每个插件的手写源都在 packages/<plugin>/ 下。
#   适配层只放清单：packages/<plugin>/adapters/<host>/ 只含清单与薄适配壳。
#   产物入库：plugins/<plugin>/<host>/ 是生成结果，供根市场清单指向。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGS="$ROOT/packages"
OUT="$ROOT/plugins"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

# ---------- 自检 ----------
check() {
  local fail=0

  echo "== 插件与技能 =="
  for pkg_dir in "$PKGS"/*/; do
    local pkg ver
    pkg="$(basename "$pkg_dir")"
    if [[ ! -f "$pkg_dir/VERSION" ]]; then
      red "  $pkg：缺少 VERSION"; fail=1; continue
    fi
    ver="$(tr -d '[:space:]' < "$pkg_dir/VERSION")"
    echo "  [$pkg v$ver]"

    # 技能校验
    if [[ ! -d "$pkg_dir/skills" ]]; then
      red "    缺少 skills/ 目录"; fail=1
    else
      if find "$pkg_dir/skills" -mindepth 3 -name 'SKILL.md' | grep -q .; then
        red "    发现嵌套 SKILL.md（技能目录不得嵌套）"; fail=1
      fi
      for d in "$pkg_dir"/skills/*/; do
        local name skill fm fmname desc
        name="$(basename "$d")"
        skill="$d/SKILL.md"
        if [[ ! -f "$skill" ]]; then
          red "    缺少 SKILL.md：$name"; fail=1; continue
        fi
        fm="$(sed -n '/^---$/,/^---$/p' "$skill" | head -20)"
        grep -q '^name:' <<<"$fm"        || { red "    ${name}：frontmatter 缺 name"; fail=1; }
        grep -q '^description:' <<<"$fm" || { red "    ${name}：frontmatter 缺 description"; fail=1; }
        fmname="$(grep '^name:' <<<"$fm" | head -1 | sed 's/^name:[[:space:]]*//')"
        if [[ "$fmname" != "$name" ]]; then
          red "    ${name}：frontmatter name ($fmname) 与目录名不一致"; fail=1
        fi
        if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
          red "    ${name}：非 kebab-case"; fail=1
        fi
        if (( ${#name} > 64 )); then red "    ${name}：超过 64 字符"; fail=1; fi
        desc="$(grep '^description:' <<<"$fm" | head -1)"
        if (( ${#desc} > 600 )); then yellow "    ${name}：description 偏长（DSH 目录默认截断 500）"; fi
        green "    通过：$name"
      done
    fi

    # 适配层洁净度
    if [[ -d "$pkg_dir/adapters" ]] && find "$pkg_dir/adapters" \( -name 'SKILL.md' -o -name '*.tpl' \) | grep -q .; then
      red "    适配层出现技能或模板（内容应只放插件源目录）"; fail=1
    else
      green "    适配层干净"
    fi

    # 双语 README 源检查
    if [[ ! -f "$pkg_dir/README.md" ]]; then
      red "    缺少 README.md"; fail=1
    fi
    if [[ ! -f "$pkg_dir/README_EN.md" ]]; then
      yellow "    缺少 README_EN.md（产物 README.md 将复用 README.md）"
    fi

    # 占位符残留（仅检查手写技能与 .tpl 模板）
    if grep -rInE '\b(TODO|FIXME|XXX)\b' "$pkg_dir/skills" 2>/dev/null; then
      red "    skills/ 发现 TODO/FIXME/XXX 残留"; fail=1
    fi
    if [[ -d "$pkg_dir/templates" ]] && grep -rInE --include='*.tpl' '\b(TODO|FIXME|XXX)\b' "$pkg_dir/templates" 2>/dev/null; then
      red "    templates/*.tpl 发现 TODO/FIXME/XXX 残留"; fail=1
    fi

    # eng-system 专属模板清单检查
    if [[ "$pkg" == "eng-system" ]]; then
      for t in AGENTS.md.tpl ROADMAP.md.tpl CHANGELOG.md.tpl README.md.tpl milestone.md.tpl research.md.tpl decision.md.tpl architecture.md.tpl review.md.tpl gitignore.tpl research-index.md.tpl milestones-index.md.tpl architecture-index.md.tpl; do
        [[ -f "$pkg_dir/templates/$t" ]] || { red "    缺少 templates/$t"; fail=1; }
      done
    fi

    # DSH bundle 检查（若该插件声明了 dsh 适配）
    if [[ -d "$pkg_dir/adapters/dsh/bundle" ]]; then
      for f in package.json cordis.patch.yml index.js; do
        [[ -f "$pkg_dir/adapters/dsh/bundle/$f" ]] || { red "    缺少 adapters/dsh/bundle/$f"; fail=1; }
      done
      if [[ -f "$pkg_dir/adapters/dsh/bundle/package.json" ]]; then
        local bver
        bver="$(python3 -I -c "import json;print(json.load(open('$pkg_dir/adapters/dsh/bundle/package.json'))['version'])")"
        if [[ "$bver" != "$ver" ]]; then
          red "    DSH bundle version=$bver != VERSION=$ver"; fail=1
        else
          green "    DSH bundle 版本与 VERSION 一致"
        fi
      fi
    fi
  done

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

  echo "== 清单一致性 =="
  python3 -I - "$ROOT" <<'PYEOF'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
pkgs = {}
bad = False

for pkg_dir in sorted((root/"packages").iterdir()):
    if not pkg_dir.is_dir():
        continue
    name = pkg_dir.name
    ver = (pkg_dir/"VERSION").read_text().strip()
    pkgs[name] = ver
    # 校验插件各 adapter manifest
    for mf in sorted((pkg_dir/"adapters").rglob("plugin.json")):
        d = json.loads(mf.read_text())
        if d.get("name") != name:
            print(f"  [fail] {mf.relative_to(root)} name={d.get('name')} != {name}"); bad = True
        if d.get("version") != ver:
            print(f"  [fail] {mf.relative_to(root)} version={d.get('version')} != {ver}"); bad = True

# 校验三份市场清单
mp_files = [
    root/".claude-plugin/marketplace.json",
    root/".agents/plugins/marketplace.json",
    root/"marketplace.json",
]
mp_names = set()
for mf in mp_files:
    if not mf.exists():
        print(f"  [warn] 缺少 {mf.relative_to(root)}"); continue
    d = json.loads(mf.read_text())
    if d.get("name"):
        mp_names.add(d["name"])
    for pl in d.get("plugins", []) or []:
        pn = pl.get("name")
        if pn not in pkgs:
            print(f"  [fail] {mf.relative_to(root)} 引用未知插件 {pn}"); bad = True
            continue
        if pl.get("version") != pkgs[pn]:
            print(f"  [fail] {mf.relative_to(root)} 条目 {pn} version={pl.get('version')} != {pkgs[pn]}"); bad = True
        if mf == root/"marketplace.json":
            i18n = pl.get("description_i18n") or {}
            if not str(i18n.get("en") or "").strip() or not str(i18n.get("zh-CN") or "").strip():
                print(f"  [fail] marketplace.json 条目 {pn} 缺少 description_i18n（en/zh-CN）"); bad = True

if len(mp_names) != 1:
    print(f"  [fail] 市场清单顶层 name 不一致: {mp_names}"); bad = True

if not bad:
    summary = ", ".join(f"{k}={v}" for k, v in pkgs.items())
    print(f"  市场名={mp_names.pop()} 一致；插件版本全部一致（{summary}）")
sys.exit(1 if bad else 0)
PYEOF
  [[ $? -eq 0 ]] || fail=1

  echo "== 陈旧产物 =="
  if [[ -d "$ROOT/dist" ]]; then
    red "  dist/ 已废弃（市场清单指向 plugins/），请删除"
    fail=1
  else
    green "  无 dist/ 残留"
  fi

  if [[ $fail -ne 0 ]]; then echo; red "自检未通过"; exit 1; fi
  echo; green "自检通过"
}

# ---------- 构建辅助 ----------
stage_plugin() {
  local pkg_dir="$1"
  local dest="$2"
  local pkg
  pkg="$(basename "$pkg_dir")"

  mkdir -p "$dest"
  for sub in skills templates logos scripts assets examples; do
    if [[ -d "$pkg_dir/$sub" ]]; then
      cp -R "$pkg_dir/$sub" "$dest/$sub"
    fi
  done
  find "$dest" -name '.DS_Store' -delete

  # 产物 README 顶部加横幅，防止有人直接改构建产物
  local en_src="$pkg_dir/README_EN.md"
  [[ -f "$en_src" ]] || en_src="$pkg_dir/README.md"
  {
    echo "> ⚠️ **This directory is a build artifact** (generated by \`scripts/build.sh\` from \`packages/$pkg/\`)."
    echo "> Do not edit directly; change the source files and rebuild instead."
    echo
    cat "$en_src"
  } > "$dest/README.md"

  if [[ -f "$pkg_dir/README_EN.md" && -f "$pkg_dir/README.md" ]]; then
    {
      echo "> ⚠️ **本目录是构建产物**（由 \`scripts/build.sh\` 从 \`packages/$pkg/\` 生成）。"
      echo "> 请勿直接修改；改动请改源文件后重新构建。"
      echo
      cat "$pkg_dir/README.md"
    } > "$dest/README_CN.md"
  fi

  if [[ -f "$pkg_dir/LICENSE" ]]; then
    cp "$pkg_dir/LICENSE" "$dest/LICENSE"
  elif [[ -f "$ROOT/LICENSE" ]]; then
    cp "$ROOT/LICENSE" "$dest/LICENSE"
  fi
}

inject_version() {
  local f="$1"
  local ver="$2"
  [[ -f "$f" ]] || return 0
  if grep -q '"version"' "$f"; then
    sed -i.bak -E "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$ver\"/" "$f"
    rm -f "$f.bak"
  fi
}

verify_marketplace_sources() {
  echo "== 校验市场清单指向的构建产物 =="
  python3 -I - "$ROOT" <<'PYEOF'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
bad = False
for mf in [
    root/".claude-plugin/marketplace.json",
    root/".agents/plugins/marketplace.json",
    root/"marketplace.json",
]:
    if not mf.exists():
        continue
    d = json.loads(mf.read_text())
    for pl in d.get("plugins", []) or []:
        src = pl.get("source")
        path = src if isinstance(src, str) else (src.get("path") if isinstance(src, dict) else None)
        if path:
            tgt = (root/path).resolve()
            if not tgt.exists():
                print(f"  [fail] {mf.relative_to(root)} -> {path} 不存在"); bad = True
if not bad:
    print("  所有市场清单 source 产物路径存在")
sys.exit(1 if bad else 0)
PYEOF
}

build() {
  rm -rf "$OUT"
  echo "== 构建 tidalto-plugins =="

  for pkg_dir in "$PKGS"/*/; do
    local pkg ver adapters
    pkg="$(basename "$pkg_dir")"
    ver="$(tr -d '[:space:]' < "$pkg_dir/VERSION")"
    adapters="$pkg_dir/adapters"
    echo "[$pkg v$ver]"

    # Agent Plugins（Codex / Cursor / Copilot 共用）
    if [[ -f "$adapters/agent-plugins/plugin.json" ]]; then
      local d="$OUT/$pkg/agent-plugins"
      stage_plugin "$pkg_dir" "$d"
      cp "$adapters/agent-plugins/plugin.json" "$d/plugin.json"
      inject_version "$d/plugin.json" "$ver"
      if [[ -f "$adapters/agent-plugins/.codex-plugin/plugin.json" ]]; then
        mkdir -p "$d/.codex-plugin"
        cp "$adapters/agent-plugins/.codex-plugin/plugin.json" "$d/.codex-plugin/plugin.json"
        inject_version "$d/.codex-plugin/plugin.json" "$ver"
      fi
      green "  plugins/$pkg/agent-plugins/"
    fi

    # Antigravity（Google Antigravity App / CLI / IDE）
    if [[ -f "$adapters/antigravity/plugin.json" ]]; then
      local d="$OUT/$pkg/antigravity"
      stage_plugin "$pkg_dir" "$d"
      cp "$adapters/antigravity/plugin.json" "$d/plugin.json"
      inject_version "$d/plugin.json" "$ver"
      green "  plugins/$pkg/antigravity/"
      if command -v agy >/dev/null 2>&1; then
        agy plugin validate --strict "$d" >/dev/null
        green "    agy plugin validate --strict 通过"
      fi
    fi

    # Claude Code
    if [[ -f "$adapters/claude/.claude-plugin/plugin.json" ]]; then
      local d="$OUT/$pkg/claude"
      stage_plugin "$pkg_dir" "$d"
      mkdir -p "$d/.claude-plugin"
      cp "$adapters/claude/.claude-plugin/plugin.json" "$d/.claude-plugin/plugin.json"
      inject_version "$d/.claude-plugin/plugin.json" "$ver"
      green "  plugins/$pkg/claude/"
    fi

    # ZCode
    if [[ -f "$adapters/zcode/.zcode-plugin/plugin.json" ]]; then
      local d="$OUT/$pkg/zcode"
      stage_plugin "$pkg_dir" "$d"
      mkdir -p "$d/.zcode-plugin"
      cp "$adapters/zcode/.zcode-plugin/plugin.json" "$d/.zcode-plugin/plugin.json"
      inject_version "$d/.zcode-plugin/plugin.json" "$ver"
      green "  plugins/$pkg/zcode/"
    fi

    # DSH
    if [[ -d "$adapters/dsh/bundle" ]]; then
      local d="$OUT/$pkg/dsh"
      stage_plugin "$pkg_dir" "$d"
      [[ -f "$adapters/dsh/README.md" ]] && cp "$adapters/dsh/README.md" "$d/DSH-INSTALL.md"
      cp "$adapters/dsh/bundle/package.json"     "$d/package.json"
      cp "$adapters/dsh/bundle/cordis.patch.yml" "$d/cordis.patch.yml"
      cp "$adapters/dsh/bundle/index.js"         "$d/index.js"
      inject_version "$d/package.json" "$ver"
      green "  plugins/$pkg/dsh/（bundle + 零安装载荷）"
    fi
  done

  echo
  verify_marketplace_sources
  echo
  echo "产物："
  find "$OUT" -maxdepth 3 -mindepth 2 | sort | sed 's|^|  |'
}

case "${1:-build}" in
  check) check ;;
  build) check; echo; build ;;
  *) red "未知参数：$1（可用：build | check）"; exit 2 ;;
esac
