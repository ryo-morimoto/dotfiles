#!/usr/bin/env bash
# 段階1の終わる条件「MUST の制約に【仮】が残っていない」を機械検査する。
# 使い方: checks/no-provisional-must.sh [desktop.md]
#   既定は このスクリプトの1つ上の desktop.md。
#   表の行のうち、セルに MUST を持ち、かつ「【仮」を含む行を列挙し、1件でもあれば exit 1。
#   壊した版の確認: git show <v2 の commit>:docs/platform/desktop/desktop.md > /tmp/v2.md && checks/no-provisional-must.sh /tmp/v2.md  # → exit 1
set -euo pipefail

doc="${1:-$(dirname "$0")/../desktop.md}"

hits=$(awk -F'|' '
  /^\|/ {
    must = 0
    for (i = 2; i < NF; i++) {
      cell = $i; gsub(/^[ \t]+|[ \t]+$/, "", cell)
      if (cell == "MUST") must = 1
    }
    if (must && index($0, "【仮") > 0) printf "%d: %s\n", NR, $0
  }
' "$doc")

must_count=$(grep -cE '^\|[^|]+\| MUST \|' "$doc" || true)

if [[ -n "$hits" ]]; then
  echo "FAIL: MUST の行に【仮】が残っている ($doc)"
  echo "$hits"
  exit 1
fi
echo "OK: MUST の行 ${must_count} 件に【仮】は無い ($doc)"
