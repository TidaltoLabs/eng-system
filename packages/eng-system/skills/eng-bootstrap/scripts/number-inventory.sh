#!/usr/bin/env bash
# eng-bootstrap · 编号占用预检（可选辅助脚本；入口 C §5.1「最容易出错的一步」）
#
# 用法:   number-inventory.sh [docs 目录]    # 默认 docs
# 输出:   D<N>/A<N>/R<N>/M<NN>/NN 文件编号与 D-<N>/C<N> 引用号的占用清单、
#         重复、断号与下一个可用号。分配新编号前必跑，避免撞号
# 编号规则: D<A><R> 不补零；M<NN> 与调研 NN 补零两位（eng-decision §二 / eng-milestone §一）
# 退出码: 2 用法/目录错误；0 正常（有重复/断号也属正常输出，迁移前必须清零）
set -euo pipefail
DOCS="${1:-docs}"
[ -d "$DOCS" ] || { echo "未找到 $DOCS 目录: $DOCS" >&2; exit 2; }

scan_files() { # $1=标题 $2=目录 $3=文件名正则 $4=号提取sed $5=下一号printf格式
  printf '\n== %s ==\n' "$1"
  [ -d "$2" ] || { echo "  （$2 不存在，跳过）"; return 0; }
  nums=$(ls "$2" 2>/dev/null | grep -E "^$3" | sed -E "$4" | sort -n || true)
  if [ -z "$nums" ]; then echo "  （无编号文件，从 1 起）"; return 0; fi
  dup=$(printf '%s\n' "$nums" | uniq -d || true)
  gaps=$(printf '%s\n' "$nums" | awk 'NR>1 && $1>p+1 {printf "%s-%s ", p+1, $1-1} {p=$1}')
  max=$(printf '%s\n' "$nums" | tail -n 1)
  echo "  占用: $(printf '%s ' $nums)"
  [ -n "$dup" ]  && echo "  ⚠ 重复: $dup"
  [ -n "$gaps" ] && echo "  ⚠ 断号（迁移时确认是否有意保留）: $gaps"
  echo "  下一个可用: $(printf "$5" "$((max + 1))")"
}

scan_files "决策文件 D<N>（docs/decisions/）"    "$DOCS/decisions"    'D[0-9]+-.*\.md$' 's/^D0*([0-9]+)-.*/\1/' 'D%s'
scan_files "架构文件 A<N>（docs/architecture/）" "$DOCS/architecture" 'A[0-9]+-.*\.md$' 's/^A0*([0-9]+)-.*/\1/' 'A%s'
scan_files "审查记录 R<N>（docs/reviews/）"      "$DOCS/reviews"      'R[0-9]+-.*\.md$' 's/^R0*([0-9]+)-.*/\1/' 'R%s'
scan_files "里程碑 M<NN>（docs/milestones/）"    "$DOCS/milestones"   'M[0-9]+-.*\.md$' 's/^M0*([0-9]+)-.*/\1/' 'M%02d'
scan_files "调研 NN（docs/research/）"           "$DOCS/research"     '[0-9]+-.*\.md$'  's/^0*([0-9]+)-.*/\1/'  '%02d'

printf '\n== 决策索引 D-<N>（ROADMAP.md） ==\n'
ROADMAP="$(dirname "$DOCS")/ROADMAP.md"
if [ -f "$ROADMAP" ]; then
  d=$(grep -ohE '\bD-[0-9]+\b' "$ROADMAP" | sed -E 's/^D-0*//' | sort -n -u || true)
  if [ -n "$d" ]; then
    echo "  占用: $(printf 'D-%s ' $d)"
    echo "  下一个可用: D-$(( $(printf '%s\n' $d | tail -n 1) + 1 ))"
  else
    echo "  （ROADMAP 中无 D-<N> 条目）"
  fi
else
  echo "  （未找到 $ROADMAP，跳过）"
fi

printf '\n== 架构约束 C<N>（docs/architecture/ 出现过的号） ==\n'
if [ -d "$DOCS/architecture" ]; then
  c=$(grep -rohE '\bC[0-9]+\b' "$DOCS/architecture" | sed 's/^C0*//' | sort -n -u || true)
  if [ -n "$c" ]; then
    echo "  占用: $(printf 'C%s ' $c)"
    echo "  下一个可用: C$(( $(printf '%s\n' $c | tail -n 1) + 1 ))"
    echo "  ⚠ C 号语义不得改变（eng-architecture §二）；分配前确认新号未被占用"
  else
    echo "  （无 C 号）"
  fi
else
  echo "  （无 architecture 目录，跳过）"
fi
