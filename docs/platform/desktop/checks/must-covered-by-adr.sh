#!/usr/bin/env bash
# 段階2の終わる条件「すべての MUST 制約が、どれかの ADR に対応付いている」を機械検査する。
# 使い方: checks/must-covered-by-adr.sh [desktop.md] [adr ディレクトリ]
#   - desktop.md の表から強さが MUST の ID を集める。
#   - adr/*.md の先頭 YAML の satisfies / partial / not_satisfied を集める。
#   - MUST の ID が satisfies か partial のどれにも無ければ FAIL。
#   - ADR に desktop.md に無い ID が書かれていれば FAIL (書き間違いの検出)。
#   - not_satisfied に入っている MUST は一覧に出す (FAIL ではない。妥協の理由は ADR 本文に書く)。
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
doc="${1:-$here/desktop.md}"
adr_dir="${2:-$here/adr}"

must=$(grep -oE '^\| [A-Z]{3,4}-[0-9]+ \| MUST \|' "$doc" | awk '{print $2}' | sort -u)
all_ids=$(grep -oE '^\| \*{0,2}[A-Z][A-Z-]*-?[0-9]+\*{0,2} \|' "$doc" | grep -oE '[A-Z][A-Z-]*-?[0-9]+' | sort -u)

field() {  # field <key> : 全 ADR の front matter から ID を取り出す
  for f in "$adr_dir"/[0-9]*.md; do
    awk -v k="$1" 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} $1==k":" {print}' "$f"
  done | grep -oE '[A-Z][A-Z-]*-?[0-9]+' | sort -u || true
}
covered=$(cat <(field satisfies) <(field partial) | sort -u)
notsat=$(field not_satisfied)
mentioned=$(cat <(field satisfies) <(field partial) <(field not_satisfied) | sort -u)

rc=0
missing=$(comm -23 <(echo "$must") <(echo "$covered"))
if [[ -n "$missing" ]]; then
  echo "FAIL: ADR に対応付いていない MUST: $(echo $missing)"
  rc=1
fi
unknown=$(comm -23 <(echo "$mentioned") <(echo "$all_ids"))
if [[ -n "$unknown" ]]; then
  echo "FAIL: desktop.md に無い ID を ADR が参照している: $(echo $unknown)"
  rc=1
fi
ns_must=$(comm -12 <(echo "$must") <(echo "$notsat"))
[[ -n "$ns_must" ]] && echo "注意: not_satisfied に入っている MUST: $(echo $ns_must)"

if [[ $rc -eq 0 ]]; then
  echo "OK: MUST $(echo "$must" | wc -l) 件はすべて ADR に対応付いている"
  for id in $must; do
    printf '  %-7s' "$id"
    for f in "$adr_dir"/[0-9]*.md; do
      n=$(basename "$f" | cut -c1-4)
      awk -v id="$id" 'NR>1 && $0=="---" {exit} ($1=="satisfies:" || $1=="partial:") && index($0, id) {split($1,a,":"); printf " ADR-%s(%s)", n, a[1]}' n="$n" "$f"
    done
    echo
  done
fi
exit $rc
