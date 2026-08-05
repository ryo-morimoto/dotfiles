---
name: dotfiles-deploy
description: dotfiles の $HOME 配備(chezmoi)を追加・変更・検証する。config の編集と apply、新規ファイルの add、tool が書き換えた live 設定の re-add、chezmoi diff/status の運用を扱う。
---

# dotfiles deploy (chezmoi)

この repo の `$HOME` 配備は標準的な chezmoi 運用に従う。source dir は
`dot-config/chezmoi/`(`~/.config/chezmoi/chezmoi.toml` の `sourceDir` は
Home Manager が生成)。Home Manager は chezmoi package の導入と activation
での `chezmoi apply --force` 実行だけを担い、配備内容は持たない。

独自 wrapper・独自 script はない。chezmoi の標準コマンドをそのまま使う。

## 基本操作

```bash
chezmoi diff              # live と source の差分(無出力 = 収束)
chezmoi status            # 差分があるファイルの一覧
chezmoi apply --force     # source -> live へ反映
chezmoi re-add            # live -> source へ回収(管理済みファイルのみ)
chezmoi add <target>      # 新しいファイルを管理下に追加
chezmoi edit --apply <target>  # source を編集して即反映
chezmoi cat <target>      # 適用される内容の確認(template の render 結果)
chezmoi managed           # 管理対象一覧
```

source ファイルを直接編集した場合は `chezmoi apply --force` で反映する。
live 側だけを編集した変更は次の apply で消えるので、残したいものは先に
`chezmoi re-add` で source に回収して commit する。

## Source 内の命名規約(chezmoi 標準)

`dot_` = `.`、`private_` = 0600/0700、`.tmpl` = template。
例: `dot_config/nvim/init.lua` → `~/.config/nvim/init.lua`、
`private_dot_claude/private_settings.json` → `~/.claude/settings.json`。

## この repo の template エントリ(2 つだけ)

1. **共有 agent 指示** `.chezmoitemplates/AGENTS.md`
   `~/.claude/CLAUDE.md` と `~/.codex/AGENTS.md` の 2 target へ同一内容を
   配備するための named template。編集後は `chezmoi apply --force`。
2. **Codex config** `private_dot_codex/modify_private_config.toml`
   stable base(`.chezmoitemplates/codex/config.toml`)を live
   `~/.codex/config.toml` へ base 優先 deep merge する modify template。
   live にしかないキー(`[projects]` の trust、hook state、生成 ID 等)は
   保持される。Codex 設定の変更は base を編集して apply。
   **base に tool-owned dynamic state や絶対 repo/worktree/temp path を
   入れない**(自動検査はない。diff review で止める)。

## Tool が書き換えるファイル(drift は正常、re-add で回収)

以下はユーザー操作起点で tool が live を更新するため `chezmoi status` に
差分が出る。内容を review して意図したものなら `chezmoi re-add` で回収して
commit する。**更新操作(plugin 更新、mise install、承認操作)をしたら
re-add まで済ませる**。re-add 前に rebuild すると tracked の古い内容へ
巻き戻るので注意。

- `~/.claude/settings.json`(Claude Code の設定変更)
- `~/.config/nvim/lazy-lock.json`(lazy.nvim の plugin 更新)
- `~/.config/mise/mise.lock`(mise install)
- `~/.config/worktrunk/approvals.toml*`(worktrunk の承認操作)
- `~/.apm/*.{yml,json}`(apm 操作)

## 管理対象外(意図的)

**machine-generated なファイルは chezmoi 管理に含めない**(rebuild の
`apply --force` が tool の出力を巻き戻すため)。上記 lock 系は
reproducibility 入力として例外的に管理する。

- DMS dynamic theming の出力: `~/.config/ghostty/colors`、
  `~/.config/ghostty/themes/dankcolors`、`~/.config/nvim/colors/dms.lua`、
  `~/.config/nvim/lua/lualine/themes/dms.lua`(live-only。DMS が再生成する。
  fresh machine では最初のテーマ適用まで存在しない)
- `~/.config/niri/config.kdl`: Home Manager(niri-flake)生成。nix 側を編集する。
- `~/.config/niri/dms/`: DankMaterialShell 所有の動的ファイル。
- `dot-config/config/knowledge/know/`: Claude Code marketplace が repo 内
  path を直接参照するもので、$HOME へは配備しない。
- `~/.codex/auth.json`、session transcript、cache 類の tool-owned state。

## 検証

配備定義や template を変更したら `chezmoi diff` で意図した差分だけかを
確認してから `chezmoi apply --force`。TOML/JSON/YAML の構文は commit 時に
prek の OSS hook(check-toml / check-json / check-yaml)が検査する。
rebuild(`nixos-rebuild switch`)でも activation が apply を実行するため、
手動 apply を忘れても rebuild で収束する。
