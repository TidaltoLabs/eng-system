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
  for t in AGENTS ROADMAP CHANGELOG README milestone research decision; do
    [[ -f "$ROOT/templates/$t.md.tpl" ]] || { red "  缺少 templates/$t.md.tpl"; fail=1; }
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
  for f in "$ROOT/.claude-plugin/marketplace.json" "$ROOT/.agents/plugins/marketplace.json"; do
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
  cp    "$ROOT/README.md" "$dest/README.md"
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

  # DSH：零安装载荷（技能目录 + 安装说明）。DSH 插件需 TS provider，v0.1 不提供假实现。
  d="$OUT/dsh"
  stage "$d"
  cp "$ROOT/adapters/dsh/README.md" "$d/DSH-INSTALL.md"
  green "  plugins/dsh/（零安装载荷）"

  echo
  echo "产物："
  find "$OUT" -maxdepth 2 -not -path "$OUT" | sort | sed 's|^|  |'
}

case "${1:-build}" in
  check) check ;;
  build) check; echo; build ;;
  *) red "未知参数：$1（可用：build | check）"; exit 2 ;;
esac
