#!/usr/bin/env bash
# 「制約 ID は変えない。足すときは新しい ID を振る」を機械検査する。
# 使い方: checks/ids-preserved.sh <旧版.md> <新版.md>
#   旧版にあって新版に無い ID があれば exit 1。新版で増えた ID は表示だけする。
set -euo pipefail
old="$1"; new="$2"
ids() {
  grep -oE '^\| \*{0,2}(O[0-9]+|N[0-9]+|S[0-9]+|G-[A-Z]+-[0-9]+|P-[0-9]+|[A-Z]{3,4}-[0-9]+|Q[0-9]+)\*{0,2}( \(|  ?\|)' "$1" \
    | grep -oE '(O[0-9]+|N[0-9]+|S[0-9]+|G-[A-Z]+-[0-9]+|P-[0-9]+|[A-Z]{3,4}-[0-9]+|Q[0-9]+)' | sort -u
}
missing=$(comm -23 <(ids "$old") <(ids "$new"))
added=$(comm -13 <(ids "$old") <(ids "$new"))
[[ -n "$added" ]] && echo "追加された ID: $(echo $added)"
if [[ -n "$missing" ]]; then
  echo "FAIL: 消えた ID: $(echo $missing)"
  exit 1
fi
echo "OK: 旧版の ID $(ids "$old" | wc -l) 件はすべて新版に残っている"
