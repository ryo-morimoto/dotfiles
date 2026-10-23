#!/usr/bin/env bash
# origin/main の overlays にある `Temporary(NixOS/nixpkgs#N)` override のうち、修正 PR が
# nixos-unstable channel に到着済みのものを列挙する。lock 更新 PR は手動マージなので、
# lock ではなく channel を基準にし、削除 PR 側で nixpkgs を channel へ上げる。
# NIXPKGS_PENDING_REF で overlay を読む ref を変えられる(テスト用)。
# exit 0: 削除可能な override がある / 1: ない(または削除 PR が既に open)/ 2: 判定失敗
# Orca automation の --precheck から呼ばれる。
set -euo pipefail

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$repo"

ref=${NIXPKGS_PENDING_REF:-origin/main}
git fetch --quiet origin main || exit 2
overlay=$(git show "$ref":nix-config/overlays/default.nix) || exit 2
channel_rev=$(curl -fsSL https://channels.nixos.org/nixos-unstable/git-revision) || exit 2

mapfile -t prs < <(grep -oE 'Temporary\(NixOS/nixpkgs#[0-9]+\)' <<<"$overlay" | grep -oE '[0-9]+' | sort -u)
if [ "${#prs[@]}" -eq 0 ]; then
	echo "no temporary overrides"
	exit 1
fi

if [ -n "$(gh pr list --state open --search 'head:nixpkgs-pending/' --json number -q '.[].number')" ]; then
	echo "cleanup PR already open"
	exit 1
fi

landed=0
for pr in "${prs[@]}"; do
	merge=$(gh pr view "$pr" -R NixOS/nixpkgs --json mergeCommit -q '.mergeCommit.oid // empty') || exit 2
	if [ -z "$merge" ]; then
		echo "pending #$pr (not merged)"
		continue
	fi
	status=$(gh api "repos/NixOS/nixpkgs/compare/$merge...$channel_rev" -q .status) || exit 2
	case "$status" in
	ahead | identical)
		echo "landed #$pr"
		landed=1
		;;
	*) echo "pending #$pr (not in nixos-unstable ${channel_rev:0:12})" ;;
	esac
done

[ "$landed" -eq 1 ]
