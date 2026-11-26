#!/usr/bin/env bash
# eng-research · 旧结论残留扫描（可选辅助脚本；无脚本环境按 SKILL.md §六 判据手工 grep）
#
# 用法:   keyword-residue.sh <关键词1> [关键词2…]
# 场景:   结论被推翻、走完 §六 fan-out 清单后的复核判据：
#         「全库搜索旧结论的关键词，应该只在修订记录/历史留痕里出现」
# 行为:   全库搜 *.md，剔除围栏代码块；命中行含 修订/superseded/已被/取代/对前序
#         视为留痕行，不计入残留
# 注意:   旧调研正文保留旧结论是「合法的层次差异」（见 eng-audit §六）——
#         命中 docs/research/ 旧报告正文时，人工判定即可，不要机械当 bug 改
# 退出码: 2 用法错误；1 有疑似残留；0 干净
set -euo pipefail
[ $# -ge 1 ] || { echo "用法: $0 <关键词1> [关键词2…]" >&2; exit 2; }

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

for kw in "$@"; do
  find . -name '*.md' -not -path '*/_refs/*' -not -path '*/.git/*' | sort | while IFS= read -r f; do
    awk -v kw="$kw" '
      /^```/ { fence = !fence; next }
      !fence && index($0, kw) && $0 !~ /修订|superseded|已被|取代|对前序/ {
        print FILENAME ":" FNR ": " $0
      }' "$f"
  done >> "$OUT"
done

sort -u "$OUT" -o "$OUT"
COUNT=$(grep -c . "$OUT" || true)
if [ "$COUNT" -gt 0 ]; then
  echo "疑似残留 $COUNT 处（人工判定：docs/research/ 旧报告正文与修订表属合法留痕，其余才是残留）："
  cat "$OUT"
  exit 1
fi
echo "干净：关键词只出现在留痕行，或全库无命中。"
