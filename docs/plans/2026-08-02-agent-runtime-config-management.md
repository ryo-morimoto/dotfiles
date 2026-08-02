---
title: "feat: Manage Claude Code and Codex stable runtime config"
type: feat
status: implemented
date: 2026-08-02
---

# Agent runtime config management implementation plan

## Problem frame

Claude Code の `~/.claude/settings.json` と Codex の
`~/.codex/config.toml` に OpenTelemetry 設定を追加したが、現在は live
ファイルだけが source of truth であり、rebuild 後の再現性がない。

Claude Code の設定は現在の内容をファイル単位で追跡できる。一方、Codex の
`config.toml` には再現したい安定設定と、非公開リポジトリを含み得る project
trust、hook state、generated app ID などの host-local state が混在する。そのため
Codex の live TOML 全体を Git 管理対象へ直接 symlink してはならない。

## Goal

`dot-config` を安定設定の source of truth にし、次を同時に満たす。

- Claude Code の `settings.json` 全体を Git 管理し、CLI からの設定変更を明示的に pull できる。
- Codex の安定設定を Git 管理し、rebuild 時に live config へ反映する。
- Codex が追加する project trust と tool-owned state を live config に保持する。
- 非公開リポジトリ名、worktree、一時パス、credential を tracked file に入れない。
- Nix は設定内容を生成せず、mutable config の配置と同期だけを担当する。

## Non-goals

- `~/.codex/auth.json`、session transcript、cache、plugin payload を管理しない。
- Codex の project trust をホスト間で同期しない。
- Claude Code の tool-installed plugin、skill、MCP runtime state を管理しない。
- agent telemetry stack 自体や dashboard を変更しない。
- secret を平文の JSON/TOML に導入しない。必要になった場合は agenix を使う。

## Constraints

- `dot-config/config/` は mutable app config の置き場所とする。
- live `~/.codex/config.toml` は Codex が更新できる通常ファイルのままにする。
- live `~/.claude/settings.json` は Claude Code が更新できなければならない。
- activation は既存ファイルを無言で破棄しない。
- `.nix` 変更後は `nixfmt`、flake 全体は `nix flake check ./nix-config`
  で検証する。
- 作業開始時に既存の unrelated change
  `dot-config/config/nvim/colors/dms.lua` を変更・stage しない。

## Target architecture

```text
dot-config/config/claude/settings.json
             |
             | activation push / reviewed manual pull
             v
~/.claude/settings.json                    writable copy

dot-config/config/codex/config.toml       stable tracked base
             |
             | Home Manager activation: live * base
             v
~/.codex/config.toml                      writable mixed config
             +-- project trust            live only
             +-- hook/tool state           live only
             `-- generated IDs             live only
```

Codex のマージでは既存 live config を左辺、tracked base を右辺に置き、base を
優先する。

```bash
yq eval-all -p=toml -o=toml \
  'select(fileIndex == 0) * select(fileIndex == 1)' \
  "$live_config" "$base_config"
```

これにより base で宣言した値は rebuild 時に復元され、base に存在しない動的
テーブルは live に残る。マージ結果は一時ファイルで構文検証してから atomic に
置き換える。

## Managed boundaries

### Claude Code: tracked as a whole file

現在の `settings.json` 全体を初期 source とする。少なくとも次を含む。

- model、effort、editor/TUI、worktree preference
- permission/sandbox に関する明示設定
- hooks と enabled plugins
- OpenTelemetry 環境変数

credential、token、非公開 endpoint が将来追加された場合は tracked file に置かず、
agenix または process environment に分離する。

### Codex: tracked stable base

tracked base に含める。

- `model`、`review_model`、`model_reasoning_effort`
- `personality`、`service_tier`
- `approval_policy`、`sandbox_mode`
- `[features]`
- `[otel]`
- ユーザーが明示的に選んだ固定 app/MCP/hook 設定

tracked base に含めない。

- `[projects.*]`
- `[hooks.state.*]`
- 自動生成された `[apps.asdk_app_*]`
- tool が取得・更新する `[marketplaces.*]`
- `[notice]`
- `[tui.model_availability_nux]`
- absolute repository/worktree/temp path を key または value に持つ設定

`[apps]` や `[hooks]` はテーブル全体で禁止せず、stable base に明示した固定キーだけを
管理する。未知のキーは live 側に残す。

## File changes

| Path | Change |
| --- | --- |
| `dot-config/config/claude/settings.json` | 現在の live 設定から作る tracked source |
| `dot-config/config/codex/config.toml` | 動的 table を除外した tracked stable base |
| `tools/claude-config-sync/claude-config-sync` | JSON の検査、push/pull、backup、atomic replace を行う script |
| `tools/claude-config-sync/tests/test-claude-config-sync.sh` | push、pull、drift、private path の regression test |
| `tools/codex-config-sync/codex-config-sync` | TOML の検査、backup、merge、atomic replace を行う script |
| `tools/codex-config-sync/tests/test-codex-config-sync.sh` | bootstrap、merge、failure の regression test |
| `nix-config/home/default.nix` | Claude の link と Codex sync の activation wiring |
| `dot-config/agents/README.md` | 新しい source-of-truth 境界と運用方法を記載 |
| `dot-config/agents/telemetry/README.md` | live-only という古い説明を新しい境界へ更新 |
| `docs/agents/setup.md` | agent runtime config の例外を source-of-truth rules に反映 |
| `docs/agents/operating-principles.md` | 確定した stable-base/live-state 分離原則へ更新 |

## Implementation units

### U1. Mutable-link behavior probe

**Purpose:** Claude Code が direct symlink 経由で設定を書き換えた後も、link と tracked
source が維持されることを先に確認する。

1. 一時ディレクトリに source と direct symlink を作る。
2. Claude Code と同じ atomic-write 形状で設定を書き換える小さな probe を行う。
3. 実機で `/effort` など無害な設定変更を一度行う。
4. `readlink` が tracked source を指し続け、変更が tracked source に現れることを確認する。

symlink 自体が通常ファイルに置換される場合は、U3 を direct link 方式から
`jessfraz` 型の writable-copy + explicit sync 方式へ切り替える。この probe が
通るまで Claude の link activation を確定しない。

**Result:** generic atomic replace probe で symlink が通常ファイルへ置換され、tracked
source は更新されなかった。実装は writable-copy + explicit pull/push を採用した。

### U2. Create sanitized tracked sources

1. `~/.claude/settings.json` を `dot-config/config/claude/settings.json` へコピーする。
2. `~/.codex/config.toml` から stable key だけを新しい base TOML へ手動で抽出する。
3. base に dynamic table がないことを structural check で確認する。
4. `gitleaks detect --no-banner --source .` と path-pattern scan を行う。
5. diff を目視し、credential、private endpoint、非公開 repository/worktree/temp path が
   ないことを確認してから stage する。

Codex の現在の full live config を intermediate file として repo 内に保存しない。

### U3. Wire Claude Code settings

`nix-config/home/default.nix` の activation に Claude 用 entry を追加する。

- `writeBoundary` 後に `~/.claude` を作成する。
- target が source と同一内容なら no-op にする。
- 内容が異なる場合は target を `~/.claude/settings.json.pre-dotfiles` に backup し、
  tracked source を writable live file へ atomic copy する。
- repository source が存在しない、または JSON が不正な場合は target を変更せず
  activation を失敗させる。
- `claude-config-check`、`claude-config-pull`、`claude-config-push` alias を提供する。

Claude Code の atomic replace で symlink が壊れるため、Home Manager symlink は使わない。
CLI で live settings を変更した場合は、内容を review してから
`claude-config-pull` で tracked source へ反映する。

### U4. Implement Codex merge tool

`tools/codex-config-sync/codex-config-sync` は次の interface とする。

```text
codex-config-sync --base PATH --live PATH [--check] [--dry-run]
```

- `--check`: base の parse、安全境界、live との差分有無だけを検査する。
- `--dry-run`: merged TOML を stdout に出し、書き換えない。
- default: merge 後の TOML を一時ファイルへ出力し、再 parse 後に live を置換する。
- live がなければ base から新規作成する。
- live があれば同じ directory に直前 backup を一つ作る。
- merge/parse が失敗した場合は live を変更せず non-zero で終了する。
- base に forbidden dynamic path があれば non-zero で終了する。
- log には TOML value、project path、table key を出さず、結果と file path だけを出す。

forbidden path の最低限は `projects`、`hooks.state`、`marketplaces`、`notice`、
`tui.model_availability_nux`、`apps.asdk_app_*` とする。

### U5. Add Codex activation wiring

`nix-config/home/default.nix` に `writeBoundary` 後の activation entry を追加し、tracked
base と live config を U4 の script で同期する。

- `pkgs.yq-go` と `pkgs.coreutils` を明示した PATH で実行する。
- `~/.codex` を事前に作成する。
- merge failure は warning に落とさず activation failure とし、壊れた設定で rebuild を
  成功扱いにしない。
- activation は idempotent にし、二回目に semantic diff がなければ live を置換しない。
- live は symlink にしない。

### U6. Update source-of-truth documentation

既存の「両 live file が source of truth」という説明を次に置き換える。

- Claude Code: tracked `dot-config/config/claude/settings.json` が source of truth。
- Codex stable config: tracked `dot-config/config/codex/config.toml` が source of truth。
- Codex dynamic state: live `~/.codex/config.toml` が source of truth。
- Nix は内容を生成せず、link と merge の lifecycle だけを管理する。

telemetry README の設定例は tracked source の編集箇所を指すように更新する。

### U7. Validate and commit

1. Shell script の regression test を実行する。
2. `shellcheck tools/codex-config-sync/codex-config-sync` を実行する。
3. changed Nix file に `nixfmt` を実行する。
4. `nix flake check ./nix-config` を実行する。
5. `gitleaks detect --no-banner --source .` を実行する。
6. `git diff --check` を実行する。
7. `git diff --name-only` で unrelated Neovim change が stage 対象外であることを確認する。
8. rebuild 後の acceptance scenarios を実機確認する。

commit は WIP observability commit とは分け、例えば次の一 concern にする。

```text
feat(agents): manage stable Claude and Codex config
```

## Regression test matrix

| Scenario | Expected result |
| --- | --- |
| live Codex config がない | base から valid TOML が作られる |
| live に project trust がある | merge 後も key/value が保持される |
| live と base に同じ stable key がある | base の値が採用される |
| live に未知の tool state がある | merge 後も保持される |
| base に `[projects]` がある | 書き換えず non-zero になる |
| base に generated app ID がある | 書き換えず non-zero になる |
| base または live が invalid TOML | live を変更せず non-zero になる |
| semantic diff がない | live file の mtime/inode を不必要に変えない |
| Claude target に未管理の異なる内容がある | backup 後に writable copy が更新される |
| Claude が設定を書き換える | check が drift を検出し、pull 後に tracked diff が出る |

## Acceptance criteria

- **WHEN** clean checkout から Home Manager activation を実行する、**THEN** Claude と
  Codex の OTel 安定設定が live config に存在する。
- **WHEN** Codex が private project の trust entry を追加して再度 rebuild する、**THEN**
  その entry は live config に残り、Git diff には現れない。
- **WHEN** tracked Codex base の model または OTel endpoint を変更して rebuild する、
  **THEN** live config の該当値だけが tracked base の値になる。
- **WHEN** Claude Code が `settings.json` を更新して `claude-config-pull` を実行する、
  **THEN** gitleaks と private path check 後に変更が tracked source に現れる。
- **WHEN** tracked config に credential または forbidden dynamic table が入る、**THEN**
  validation が失敗し、live config を上書きしない。
- **WHEN** `git status --short` を確認する、**THEN** private project path 由来の変更はなく、
  unrelated Neovim change はそのまま保持される。

## Rollout and rollback

### Rollout

1. U1 の probe 結果に従って writable-copy 方式を選ぶ。
2. sanitized source と merge test を先に commit candidate にする。
3. activation wiring を追加して `nix flake check` を通す。
4. `home-manager switch` または NixOS rebuild を実行する。
5. Claude の link、Codex の stable value、Codex dynamic state の三点を確認する。

### Rollback

- Claude は `~/.claude/settings.json.pre-dotfiles` を通常ファイルへ戻す。
- Codex は sync が作った直前 backup を `~/.codex/config.toml` へ戻す。
- Home Manager activation entry を外しても live Codex config は通常ファイルとして残る。
- telemetry stack は config management と独立しているため、rollback で停止・削除しない。

## Decision record

公開 dotfiles で見られた全体 symlink、writable copy、live-only、host-local source の
各方式から、Claude は全体追跡 + writable-copy、Codex は stable-base/live-state 分離を採用する。
これにより `dot-config` の再現性と tool-owned mutable state を両立し、現在確認された
private-looking project path を repository から排除する。
