#!/usr/bin/env bash
# 宣言されていない状態の一覧 (INT-3 / MNT-3)。出力が空か、known-undeclared.txt に載っているものだけなら exit 0。
#   - decman --dry-run が出す変更 (宣言に無いパッケージ、宣言と違うファイル、ユニット)
#   - pacman が管理するファイルのうち、変更された設定ファイル (pacman -Qii の MODIFIED)
#   - /etc にあって、どのパッケージにも属さず、decman も置いていないファイル
#   - chezmoi status の差分 (source と live の違い。GUI が書いたものを re-add し忘れていないか)
#   - Flatpak のうち宣言に無いもの (decman の Flatpak 管理に載っていないもの)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
known="$here/known-undeclared.txt"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

{
  sudo decman --dry-run 2>&1 | sed -n 's/^/decman: /p'
  pacman -Qii 2>/dev/null | awk '/^MODIFIED/ {print "modified: " $2}'
  comm -23 <(sudo find /etc -xdev -type f 2>/dev/null | sort) \
           <( (pacman -Qlq; sudo cat /var/lib/decman/managed-files 2>/dev/null) | sort -u) | sed 's/^/unowned: /'
  chezmoi status 2>/dev/null | sed 's/^/chezmoi: /'
} >"$tmp"

if [[ -f "$known" ]]; then
  grep -v -F -x -f <(grep -v '^#' "$known" | sed '/^$/d') "$tmp" || true
else
  cat "$tmp"
fi | tee /dev/stderr | { ! grep -q .; }
