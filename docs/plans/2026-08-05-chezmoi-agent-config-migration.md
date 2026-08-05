---
title: "refactor: Migrate all non-Nix config deployment to pure chezmoi"
type: refactor
status: implemented
date: 2026-08-05
---

# pure chezmoi による dotfiles 配備への完全移行

## Problem frame

`2026-08-02-agent-runtime-config-management.md` で導入した
`tools/claude-config-sync` / `tools/codex-config-sync` は要件を満たしていたが、
tool ごとに bash script を書き下ろす方式で、agent tool が増えるたびに
merge・validation・atomic replace の再実装とメンテが必要だった。

また `$HOME` への配備手段が Home Manager の `mkOutOfStoreSymlink`、
`home.file`、activation script の 3 系統に分散していた。

中間案として「実体を `dot-config/config/` に残し chezmoi の `symlink_` shim で
配備する」構成を検討・実装したが、repo 独自の運用(shim 規約、
`dotfilesRoot` data 注入、絶対 path include)が残るため、最終的に標準の
chezmoi 運用へ寄せた。

## Goal

- `nix-config` 以外の全 config 配備を pure な標準 chezmoi 運用に一本化する。
- 独自 wrapper・独自 script・独自規約をゼロにする。使うのは chezmoi の
  標準コマンド(`diff` / `status` / `apply` / `add` / `re-add` / `edit` /
  `cat` / `managed`)だけ。
- Codex live config の tool-owned dynamic state を merge 後も保持する。
- 検査は OSS 提供の hook だけで構成する。
- agent がメンテできるよう workflow を skill として文書化する。

## 採用した設計

### 標準 chezmoi(copy 配備 + re-add 回収)

- source dir は `dot-config/chezmoi/`。配備される config の**実体**を
  chezmoi 標準の命名規約(`dot_` / `private_` / `.tmpl`)で置く。
- 配備は chezmoi 既定の copy。source 編集後は `chezmoi apply`、
  tool が live を書き換えたら review して `chezmoi re-add` で回収する
  (lazy-lock.json、mise.lock、worktrunk approvals、Claude settings、
  apm files が該当)。
- **machine-generated なファイルは管理しない**。activation の
  `apply --force` が rebuild ごとに tracked の古い内容で live を巻き戻す
  hazard があるため(反証レビューで検出)、ユーザー操作なしで tool が
  再生成する DMS theme 出力(ghostty colors / dankcolors、nvim dms.lua、
  lualine dms.lua)は source と Git から除外し live-only とした。
  lock 系は reproducibility 入力として例外的に管理し、更新操作後に
  re-add する運用とする。
- template は 2 つだけ。
  1. `.chezmoitemplates/AGENTS.md`: `~/.claude/CLAUDE.md` と
     `~/.codex/AGENTS.md` の 2 target へ同一内容を配備する共有 template。
  2. `private_dot_codex/modify_private_config.toml`:
     `chezmoi:modify-template` マーカー形式の modify template。
     `.chezmoitemplates/codex/config.toml`(stable base)を live へ
     base 優先 deep merge し、live-only キー(project trust、hook state、
     生成 ID)を保持する。
- Claude settings は素の `private_settings.json`(copy)。template では
  ないため `chezmoi re-add` が標準の pull 経路として機能する。

### Home Manager の責務

package 導入(`pkgs.chezmoi`)、`~/.config/chezmoi/chezmoi.toml` の生成
(`sourceDir` 1 行のみ、data 注入なし)、activation での
`chezmoi apply --force` 実行のみ。

### Probe で確認した chezmoi 挙動(v2.70.5)

- modify template は `.tmpl` 拡張子なし + `chezmoi:modify-template` マーカーで
  動く(`modify_*.tmpl` は「script を生成する template」なので不可)。
- sprig `merge` は第一引数優先の deep merge。base 優先・live-only 保持を確認。
- live 不在時は空 stdin から base のみで bootstrap される。
- base が invalid TOML なら apply が fail し live は変更されない。

### 検査(self-maintained rule ゼロ)

- 構文: `pre-commit/pre-commit-hooks` の `check-toml` / `check-json` /
  `check-yaml`(prek から remote repo hook として実行、動作確認済み。
  JSONC の `nvim/dot_luarc.json` は exclude)。
- secret: 既存 gitleaks(default rules)。
- private path / dynamic table: 自動検査なし。diff review に任せる
  (per-key denylist はキー空間追従のメンテ負債になるため意図的に廃止)。
- state 混在ファイル向け専用 OSS `chezmoi_modify_manager` は INI 限定のため
  不採用。INI 系 config の tool が増えたら第一候補。

### 配備対象外(意図的)

- `dot-config/config/knowledge/know/`: Claude Code marketplace が repo 内 path を
  直接参照するため配備しない。`dot-config/config/` はこの種の
  「repo 内 path を直接参照させる content」置き場として残る。
- `dot-config/config/niri/dms/`: live は DankMaterialShell 所有の動的ファイル。
  repo 側は参考スナップショット(既に diverge)。
- DMS dynamic theming の出力(`~/.config/ghostty/colors`、
  `~/.config/ghostty/themes/dankcolors`、`~/.config/nvim/colors/dms.lua`、
  `~/.config/nvim/lua/lualine/themes/dms.lua`): live-only。DMS が再生成する。
  fresh machine では最初のテーマ適用まで存在しない gap を許容する。
- `~/.config/niri/config.kdl`: Home Manager(niri-flake)生成。

## 検証結果

- Codex merge parity: `chezmoi cat` と `yq` 直接 merge の出力が
  canonical JSON で一致。
- Claude settings / CLAUDE.md: `chezmoi cat` と tracked source が byte 一致。
- `chezmoi apply --force` 実施済み。全 target が実体ファイル化し、
  nvim headless 起動・claude JSON・codex TOML・zsh custom の動作確認 pass。
- `nix flake check` / dry-run build / prek hook(pass・fail 系)確認済み。

## 旧構成から失われたもの(許容済み)

- 「repo 実体への dir symlink 越しに tool が書き込むと即 Git に現れる」挙動。
  pure 運用では tool は live に書き、`chezmoi status` で drift として可視化 →
  `chezmoi re-add` で回収する(標準 chezmoi の流儀)。
- 編集の即時反映(symlink 時代)。source 編集後は `chezmoi apply` が必要。
  rebuild 時の activation でも収束する。
- `*.pre-dotfiles` 自動 backup と activation 時の content boundary 検査
  (Git + `chezmoi diff` + OSS hook + diff review に置換)。

## 関連文書

- workflow: `.claude/skills/dotfiles-deploy/SKILL.md`
- source-of-truth 境界: `docs/agents/setup.md`
- 確定原則: `docs/agents/operating-principles.md`(Concrete Decisions)
