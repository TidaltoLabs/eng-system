#!/usr/bin/env bash
# eng-audit · 机械五项粗筛（可选辅助脚本；无脚本环境按 SKILL.md §三 手工执行）
#
# 用法:   mechanical-check.sh [扫描根目录]     # 默认当前目录
# 覆盖:   ① 悬空双链（剔除围栏代码块与行内码后比对文件名）
#         ② 编号一致性（D-<N> 对 ROADMAP 索引、C<N> 对架构文档、文件前缀断号/重复）
#         ③ frontmatter 必填（docs/**/*.md 的 title/type/updated）
#         ④ 路径引用存在性（docs/... 形式；无法区分计划引用，标注人工确认）
#         ⑤ 版本映射行提取（AGENTS/ROADMAP，供人工比对——此项无法自动判定）
# 退出码: 2 用法错误；1 有疑似问题；0 干净
#
# 已知局限（粗筛性质，详见 eng-audit §八）:
#   文件名含空格的文档跳过；行内码剔除为近似；[[同名文件]] 歧义需人工判断
set -euo pipefail

ROOT="${1:-.}"
[ -d "$ROOT" ] || { echo "目录不存在: $ROOT" >&2; exit 2; }

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
add() { printf '%s\n' "$*" >> "$TMP"; }

# 文档清单（排除参考快照、隐藏目录、含空格路径）
DOC_FILES=$(find "$ROOT" -name '*.md' -not -path '*/_refs/*' -not -path '*/.git/*' | grep -v ' ' | sort || true)

# 剔除围栏代码块，输出 "文件:行号:内容"
clean_lines() { awk '/^```/{f=!f;next} !f{print FILENAME ":" FNR ":" $0}' $DOC_FILES; }

echo "== 1/5 悬空双链 =="
TARGETS=$(clean_lines | sed -E 's/^[^:]*:[0-9]+://; s/`[^`]*`//g' \
  | grep -oE '\[\[[^]]+\]\]' | sed -E 's/^\[\[//; s/\]\]$//; s/[|#].*//' \
  | sed '/^$/d' | sort -u || true)
while IFS= read -r t; do
  [ -z "$t" ] && continue
  case "$t" in
    */*) [ -f "$ROOT/$t.md" ] || [ -f "$ROOT/$t" ] || add "[双链] [[<$t>]] 按路径未找到" ;;
    *)   [ -n "$(find "$ROOT" -name "$t.md" -not -path '*/_refs/*' -not -path '*/.git/*' | head -n1)" ] \
           || add "[双链] [[<$t>]] 无同名文件" ;;
  esac
done <<TARGETS_EOF
$TARGETS
TARGETS_EOF

echo "== 2/5 编号一致性 =="
# D-<N>：权威 = ROADMAP.md 决策索引
if [ -f "$ROOT/ROADMAP.md" ]; then
  AUTH=$(grep -ohE '\bD-[0-9]+\b' "$ROOT/ROADMAP.md" | sort -u || true)
  USED=$(clean_lines | sed -E 's/^[^:]*:[0-9]+://; s/`[^`]*`//g' | grep -ohE '\bD-[0-9]+\b' | sort -u || true)
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    printf '%s\n' "$AUTH" | grep -qxF "$n" || add "[编号] <$n> 被文档引用，但 ROADMAP 决策索引未定义"
  done <<USED_EOF
$USED
USED_EOF
fi
# C<N>：权威 = docs/architecture/
if [ -d "$ROOT/docs/architecture" ]; then
  AUTH=$(grep -rohE '\bC[0-9]+\b' "$ROOT/docs/architecture" | sort -u || true)
  USED=$(clean_lines | sed -E 's/^[^:]*:[0-9]+://; s/`[^`]*`//g' | grep -ohE '\bC[0-9]+\b' | sort -u || true)
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    printf '%s\n' "$AUTH" | grep -qxF "$n" || add "[编号] <$n> 被引用，但 docs/architecture/ 未定义该约束"
  done <<USED_EOF
$USED
USED_EOF
fi
# 文件前缀断号/重复（D/A/R 不补零，M/NN 补零，统一去前导零按数值比）
check_files() { # $1=标签 $2=目录 $3=文件名正则 $4=号提取sed
  [ -d "$2" ] || { echo "  $1: 目录不存在，跳过"; return 0; }
  nums=$(ls "$2" 2>/dev/null | grep -E "^$3" | sed -E "$4" | sort -n || true)
  [ -z "$nums" ] && { echo "  $1: 无编号文件"; return 0; }
  dup=$(printf '%s\n' "$nums" | uniq -d || true)
  [ -n "$dup" ] && add "[编号] $1 重复编号: $(printf '%s ' $dup)"
  gaps=$(printf '%s\n' "$nums" | awk 'NR>1 && $1>p+1 {printf "%s-%s ", p+1, $1-1} {p=$1}')
  [ -n "$gaps" ] && add "[编号] $1 断号（有意保留请忽略）: $gaps"
  echo "  $1: 已用 $(printf '%s ' $nums)"
}
check_files "decisions/D<N>"   "$ROOT/docs/decisions"    'D[0-9]+-.*\.md$' 's/^D0*([0-9]+)-.*/\1/'
check_files "reviews/R<N>"     "$ROOT/docs/reviews"      'R[0-9]+-.*\.md$' 's/^R0*([0-9]+)-.*/\1/'
check_files "milestones/M<NN>" "$ROOT/docs/milestones"   'M[0-9]+-.*\.md$' 's/^M0*([0-9]+)-.*/\1/'
check_files "research/NN"      "$ROOT/docs/research"     '[0-9]+-.*\.md$'  's/^0*([0-9]+)-.*/\1/'

echo "== 3/5 frontmatter 必填（docs/**）=="
if [ -d "$ROOT/docs" ]; then
  find "$ROOT/docs" -name '*.md' | sort | while IFS= read -r f; do
    [ "$(head -n1 "$f")" = "---" ] || { add "[frontmatter] <$f> 缺 frontmatter"; continue; }
    block=$(sed -n '2,/^---$/p' "$f" | head -30)
    for field in title type updated; do
      printf '%s\n' "$block" | grep -qE "^$field:" || add "[frontmatter] <$f> 缺 $field"
    done
  done
fi

echo "== 4/5 路径引用存在性 =="
# 不剔行内码（路径常写在反引号里），仅剔围栏代码块
PATHS=$(clean_lines | sed -E 's/^[^:]*:[0-9]+://' \
  | grep -oE 'docs/[A-Za-z0-9_/-]+\.(md|png|svg|jpg)' | sed 's/[.,)]$//' | sort -u || true)
while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ -e "$ROOT/$p" ] || add "[路径] <$p> 不存在（计划引用请人工确认编号未占用）"
done <<PATHS_EOF
$PATHS
PATHS_EOF

echo "== 5/5 版本映射行（此项必须人工比对）=="
for f in "$ROOT/AGENTS.md" "$ROOT/ROADMAP.md"; do
  [ -f "$f" ] || continue
  echo "  --- ${f#"$ROOT"/} ---"
  grep -nE 'M[0-9]{2}|0\.[0-9]+\.[x0-9z]' "$f" | head -n 12 | sed 's/^/  /' || true
done

COUNT=$(grep -c . "$TMP" || true)
if [ "$COUNT" -gt 0 ]; then
  echo
  echo "== 疑似问题 $COUNT 条（粗筛，必须人工复核）=="
  cat "$TMP"
  exit 1
fi
echo
echo "粗筛干净。注意：版本映射一致性（第 5 项）与 [[同名文件]] 歧义仍需按 eng-audit 正文人工判定。"
