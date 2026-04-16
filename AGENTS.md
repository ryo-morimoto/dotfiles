# Goal Design & Intent Modeling

このファイルは、dotfiles リポジトリでエージェントが実装判断するときの運用基準を定義する。

## ディレクトリ構造

```text
.
|-- flake.nix
|-- flake.lock
|-- hosts/
|   `-- ryobox/
|       |-- default.nix
|       `-- hardware-configuration.nix
|-- home/
|   |-- default.nix
|   |-- agents/default.nix
|   |-- knowledge/default.nix
|   `-- <domain>/default.nix
|-- packages/
|   `-- *.nix
|-- config/
|   `-- <tool>/...
|-- secrets/
|   |-- secrets.nix
|   `-- *.age
|-- tools/
|   `-- <tool>/...
|-- skills/
|   `-- <skill>/...
|-- docs/
|   `-- plans/
`-- .github/workflows/
```

- `flake.nix` / `flake.lock`: 依存と出力定義の唯一の入口
- `hosts/`: ホスト固有の NixOS 構成（`hardware-configuration.nix` は自動生成扱い）
- `home/`: Home Manager のユーザー環境定義（`default.nix` は集約、関心ごとは `home/<domain>/default.nix` へ分割）
- `skills/`: repo ローカルの skill 定義と reference 資産
- `packages/`: ローカル package 定義（overlay で公開）
- `config/`: アプリ設定（Out-of-store symlink の実体）
- `secrets/`: agenix 管理の暗号化シークレット
- `tools/`: 補助ツール
- `docs/plans/`: 設計メモ・実装計画

## 管理・拡張ルール

- 宣言的構成を優先し、設定は Nix か `config/` 配下で一元管理する
- 既存責務を崩さない（host は `hosts/`、user は `home/`、package は `packages/`）
- 新規 package は `packages/<name>.nix` を追加し、`flake.nix` の overlay に必ず登録する
- 新規アプリ設定は `config/<app>/` に追加し、`home/default.nix` から参照する
- 新規シークレットは平文で置かず `secrets/*.age` + `secrets/secrets.nix` で管理する
- 生成物やホストローカル状態は原則コミットしない（必要なら `.gitignore` で吸収）
- 変更は小さく分割し、Conventional Commits を基本とする

## ゴールを受け取ったとき

ゴールを受け取ったら、実装前に以下の5項目が揃っているか確認せよ。
揃っていない項目があれば、実装を始める前に選択肢を提示して埋めよ。

```text
目的:         なぜこれを解くのか・なぜ今なのか
解かないこと: 今回スコープ外にするもの
制約:         技術・時間・既存システムとの整合性
最低限:       目的達成に不可欠な要素のみ
検証基準:     WHEN [条件] THEN [期待動作] の形式で書けること
```

**検証基準が書けない = 探索フェーズ未完了。** 実装せず、まず選択肢を出せ。

検証基準は最低1つ書く。

```text
例1) WHEN flake.nix を更新したとき THEN `nix flake check` が成功する
例2) WHEN home/default.nix に package を追加したとき THEN `nixfmt` 後に構文エラーがない
```

## HitLを挟む判断基準

以下のときだけ確認を求めよ。それ以外は自律実行せよ。

- インターフェース・スキーマ・API境界を新設・変更するとき（コントラクト確定）
- 後述の「未確定ドメイン（U）」に触れる実装をするとき
- 明示されたゴールと選好ログ（L）が矛盾しているとき

## 選好ログ（L）と未確定ドメイン（U）の扱い

このファイルまたはプロジェクトの `CLAUDE.md` に以下のセクションがあれば従え。

```text
## 選好ログ（L）
- [ドメイン]: [確定した選好]

## 未確定ドメイン（U）
- [まだ選好が定まっていない領域]
```

**Uに触れたとき:** 実装前に必ずプローブを投げよ。

## 選好ログ（L）

- [進め方]: 破壊的変更・契約変更以外は自律実行し、開始点が明示されている依頼では着手前確認を挟まない
- [dotfiles品質]: `.nix` 編集後は `nixfmt`、flake 変更時は `nix flake check` で検証する
- [構成方針]: Nix Flakes + Home Manager の宣言的構成を維持する
- [Python実行環境]: `python3` は system-wide ではなく Home Manager のユーザー環境に追加する
- [コミット運用]: Conventional Commits を基本に、小さめの差分を高頻度で積む
- [依存更新運用]: `chore: update flake.lock` を定期実行し、依存更新を継続する
- [Playwright運用]: Chromium-only は `PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers.override { withFirefox = false; withWebkit = false; }}` を標準にし、`playwright install*` を使わない
- [OpenCode運用]: `compound-engineering` は Home Manager activation で自動適用する
- [OpenCode権限運用]: OpenCode には managed permission policy を注入しない。CLI の dedicated bypass flag がないため、Home Manager の `settings.permission = "allow"` を既定にする
- [エージェント共有定義]: multi-agent に配布する shared skill/plugin 定義は `home/agents/default.nix` に集約し、`home/agents/<agent>.nix` はそれを消費する構成を優先する
- [エージェント設定変換]: shared policy data は `home/agents/default.nix` に集約し、Claude/Codex/OpenCode など各ツール固有フォーマットへの変換は消費側 module/host で行う
- [エージェントMCP定義]: MCP server 定義は `home/agents/default.nix` に置き、`policy.nix` には混ぜない
- [Home Manager module構成]: 関連設定は一箇所で確認できる粒度で `home/<domain>/default.nix` に集約し、`home/default.nix` は import の集約に寄せる。過剰な submodule 分割は避ける
- [tmux構成]: tmux 設定は `home/tmux/default.nix` の Home Manager module として管理し、status・binding・plugin 設定を同ファイル内で見通し良く保つ
- [git worktree配置]: repo 内の `worktrees/` は持たず、各 worktree は `{project-parent}/{project}-wt/<name>` に配置して repo 隣接で管理する
- [デスクトップ構成]: Niri + DankMaterialShell を継続し、置き換え済みの旧 desktop stack は repo に残さない
- [ローカルWebツール運用]: `agent-browser` はブラウザ操作・観測、`portless` は stable な local URL と worktree 分離に使い分ける
- [Codex運用]: alias 追加より skill 化を優先するが、CLI option だけで足りる既定挙動は shell alias で付与してよい。`~/.codex/config.toml` は Codex 自身が更新できる mutable file を維持し、Home Manager では activation でデフォルトを書き込む。`--full-auto` は `on-request` のため既定にせず、Codex は `approval_policy = "never"` + `sandbox_mode = "workspace-write"` + workspace-write network access を標準にする
- [Claude Code承認運用]: Claude Code の `--dangerously-skip-permissions` は wrapper ではなく shell alias で付与する。sandbox は `settings.json` で常時有効化し、`failIfUnavailable = true` と `allowUnsandboxedCommands = false` を既定にする。Linux では `sandbox-runtime` の seccomp asset を `.claude/vendor/seccomp/<arch>/` に配布して `sandbox.seccomp.{bpfPath,applyPath}` を明示する
- [Claude Codeモデル運用]: Claude Code の既定モデルは公式 docs の Claude API alias に合わせ、Opus 4.7 は `claude-opus-4-7` を使う
- [Claude Code Codex連携]: Claude Code から Codex を使う入口は OpenAI の `codex-plugin-cc` marketplace を Home Manager で登録し、`codex@openai-codex` を既定で有効化する
- [Claude Code plugin運用]: `semgrep@claude-plugins-official` は `semgrep mcp` hook を自動実行するため既定では無効化し、必要時だけ一時的に有効化する
- [ローカルSAST運用]: `semgrep` CLI は Home Manager に常設せず、必要時だけ一時導入または個別環境で使う
- [Claude Code配布元]: `pkgs.claude-code` に問題があるときは `ryoppippi/nix-claude-code` overlay を優先し、Home Manager の `programs.claude-code.package` 差し替え口で設定を維持する
- [Neovim Markdown閲覧]: 日本語 Markdown では spell を無効化せず、`spelllang=en,cjk` で英単語チェックを残す
- [repo-doctor運用]: shared CI/local command は `just`、Git hooks は `prek`、SAST は `Semgrep`、dependency age gate は 7 日、GitHub Actions は full SHA pin、主要チェックは local-first で CI は同一チェックの再確認、directory structure は `tree --gitignore` と言語/アプリ特性/規模適合または明示ルールで評価し、living documentation は oldest-5 と関連コードの対応、orphan doc/code の有無で鮮度を確認する
- [エージェント自動化]: フォーマット・静的解析・リリースノート生成など機械的に処理できる作業は LLM ではなく script / CI に委譲する
- [エージェントレビュー]: impact / correctness / ops / cleanup など観点を固定したレビューを Codex の主要用途として優先する

## 未確定ドメイン（U）

- 既定ブラウザの方向性（Firefox 基準の維持 / Zen への移行）

## 直近100件のコミットログ分析（2026-01-20〜2026-02-25）

- 種別内訳: `feat 41` / `chore 36` / `refactor 7` / `fix 6` / `docs 4` / `style 3` / `revert 1` / 非Conventional 1件
- `chore: update flake.lock` が22件（flake関連合計28件）で、依存更新を高頻度で継続
- デスクトップ環境・テーマ関連（`niri`/`waybar`/`DMS`/`wallust`/`theme` など）が22件
- エージェント運用関連（`agent`/`claude`/`opencode`）が12件
- 傾向: 小さめの差分を高頻度で積み、依存更新と開発体験改善を並行して進める

## メンテナンスワークフロー

1. ゴール受領時に 5項目（目的/解かないこと/制約/最低限/検証基準）を確定する
2. 差分設計を行い、責務境界に沿って変更先ディレクトリを決める
3. 実装する（小さな差分で段階的に進める）
4. 検証する
   - WHEN `.nix` を編集した THEN `nixfmt` を実行
   - WHEN `flake.nix` / `flake.lock` を編集した THEN `nix flake check` を実行
5. 記録を更新する
   - `選好ログ（L）` を更新
   - 解決済み項目を `未確定ドメイン（U）` から削除
   - 必要なら `未確定ドメイン（U）` に新規論点を追加
6. コミットする（Conventional Commits + 1コミット1意図を原則）

## プローブのルール

プローブは直感を引き出す形式にせよ。分析を強制するな。

```text
OK:  「AとBどちらが好みですか？（理由不要）」
OK:  「このネーミング、違和感ありますか？(y/n)」
NG:  「この実装についてどう思いますか？」
NG:  「AとBのどちらが要件を満たしていますか？」
```

一度に聞くプローブは1つ。理由は求めるな。

## セッション終了プロトコル（MUST）

タスク完了後、必ず以下を実行せよ。

1. このセッションで選好に関わる判断をした箇所を特定する
2. `選好ログ（L）` の該当ドメインを更新する
3. `未確定ドメイン（U）` から解決済みの項目を削除する
4. 必要なら `未確定ドメイン（U）` に新しい論点を追加する

## Build / Lint / Test Commands

This is a Nix Flakes-based dotfiles repository. All commands use `nix` (prefer `nix --profile` or flakes).

### Format and Lint

```bash
# Format all .nix files
nixfmt .

# Lint/validate flake (includes parsing and evaluation)
nix flake check

# Dry-run build NixOS configuration
nix build .#nixosConfigurations.ryobox.config.system.build.toplevel --dry-run
```

### Build and Test

```bash
# Build full NixOS configuration
sudo nixos-rebuild switch --flake .

# Build a single package (defined in packages/*.nix)
nix build .#showboat

# Enter development shell if available
nix develop

# Evaluate a Nix expression
nix eval .#nixosConfigurations.ryobox.config.home-manager.users.ryo-morimoto.programs.starship.enable
```

### Single Test / Evaluation

```bash
# Evaluate a specific attribute
nix eval .#nixosConfigurations.ryobox.config.system.build.toplevel

# Check a specific package
# Test a single module (requires evaluation)
nix eval .#nixosConfigurations.ryobox.config.home-manager.users.ryo-morimoto
```

## Browser Automation / Local URLs

### `agent-browser`

- ブラウザを実際に開いて操作・観測するときに使う。クリック、入力、snapshot、screenshot、PDF、console/errors 確認、CDP 接続は `agent-browser` の責務
- AI/agent の標準フローは `open` → `snapshot -i` → `@ref` で操作 → 必要に応じて `wait` / `get` / `screenshot`
- 認証状態や既存 Chrome を再利用したいときは `--profile` / `--session-name` / `--auto-connect` / `--cdp` を使う
- 人間がブラウザの状態を見ながら進めたいときだけ `dashboard` や `stream` を使う
- local URL の命名や port 管理は担当しない。URL を安定させたいだけなら `portless` を使う

### `portless`

- dev server を raw な `localhost:<port>` ではなく stable な `https://<name>.localhost` で公開したいときに使う
- `portless run <cmd>` は project 名から URL を推論し、git worktree では branch/worktree prefix を付けて URL 衝突を避ける
- 複数アプリや API を同時に立ち上げるときは `portless <name> <cmd>` や `portless alias <name> <port>` を使って名前付きで管理する
- HTTPS + HTTP/2 をデフォルトで有効化したい、cookie/storage を app ごとに分離したい、port 番号の記憶や衝突を避けたいときに向いている
- ブラウザ操作はしない。UI 操作やレンダリング確認は `agent-browser` と組み合わせる

### 併用ルール

- browser automation が目的なら、先に `portless` で安定 URL を作り、その URL を `agent-browser open <url>` に渡す
- 例: `portless run next dev` で `https://myapp.localhost` を立て、`agent-browser open https://myapp.localhost` で操作する
- repo 内の他ツールが CDP 付き Chrome を起動済みなら、URL 管理は `portless`、ブラウザ接続は `agent-browser --cdp ...` で分担する
- `agent-browser` 単独で十分なのは「既存 URL に対する操作・確認」が主目的のとき
- `portless` 単独で十分なのは「開発 URL を固定したい」「worktree ごとに URL を分けたい」「cross-service URL を名前で解決したい」とき

## Code Style Guidelines

This repository uses Nix (nixpkgs/lib, Home Manager modules) as the primary configuration language.

### Formatting

- Use `nixfmt` for all `.nix` files (non-negotiable)
- 2-space indentation
- Maximum line length: 120 characters (nixfmt default)
- Sort imports alphabetically within attribute sets
- Use `lib.mkIf`, `lib.mkEnableOption`, `lib.mkOption` from `lib` for conditionals

### Imports and Dependencies

```nix
# Preferred: explicit function arguments
{ lib, config, pkgs, ... }:

# Group imports: stdlib first, then external, then local
{
  lib,
  fetchFromGitHub,
  buildGoModule,
  myLocalPackage,
}:
```

### Naming Conventions

- **Variables**: `snake_case` (e.g., `enableTiling`, `my_package`)
- **Functions**: `camelCase` (e.g., `mkIf`, `mkEnableOption`)
- **Options**: `camelCase` (e.g., `programs.zsh.enable`)
- **Packages**: `kebab-case` (e.g., `cursor-agent`, `showboat`)
- **Files**: `kebab-case.nix` for packages, `default.nix` for modules

### Types and Assertions

- Always define `meta` with `description`, `license`, `platforms` for packages
- Use Home Manager's type system (`types.bool`, `types.str`, `types.path`)
- Add assertions for invalid parameter combinations:
  ```nix
  lib.mkIf (cfg.enable && cfg.disable) (lib.warn "矛盾した設定" null)
  ```

### Error Handling

- Use `lib.warn` for non-fatal issues
- Use `lib.trivial.warn` for deprecation warnings
- Avoid `throw` in pure configurations; use assertions instead
- For runtime errors, prefer `lib.optional` or `lib.optionalString` over conditionals

### Nixpkgs Lib Usage

```nix
# Common patterns
lib.mkEnableOption "myfeature" // { default = true; }
lib.mkIf cfg.enable (pkgs.writeShellScriptBin "myscript" '')
  # script content
'')

# String interpolation with pkgs
lib.mkOption {
  default = "${pkgs.python3}/bin/python";
  description = "Python interpreter path";
}
```

### Code Organization

- One package per file in `packages/<name>.nix`
- Host-specific config in `hosts/<hostname>/`
- Home Manager user config in `home/` with imports
- Keep `flake.nix` minimal; delegate to modules
- Secret management via `secrets/*.age` with agenix

### Git Commit Style

- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `style:`
- Prefer small, focused commits (1 commit = 1 concern)
- Update `flake.lock` with `chore: update flake.lock`
- Example: `feat(niri): add workspace keybindings`

## Grepika (CLI)

Token-efficient なコード検索ツール。BM25 + trigram + ripgrep の3バックエンドスコア合算でランキング付き検索結果を返す。MCP ではなく CLI として使う。

### セットアップ

プロジェクトに入ったら最初にインデックスを構築する:

```bash
grepika --root $(pwd) index
```

フルリビルド:

```bash
grepika --root $(pwd) index --force
```

### コマンドリファレンス

`--root <path>` はグローバルオプション。**サブコマンドの前**に置くこと。

```bash
# ランキング付き検索（BM25 + trigram + grep 合算）
grepika --root . search "authentication" -l 20

# 検索モード指定: combined(default) / fts(自然言語向き) / grep(正確パターン)
grepika --root . search "error handling" -m fts

# シンボル参照一覧（definition/import/usage 分類付き）
grepika --root . refs "localOverlay"

# ファイル構造抽出（関数/クラス/構造体）
grepika --root . outline src/main.rs

# ディレクトリツリー
grepika --root . toc

# ファイル内容取得
grepika --root . get src/main.rs

# 指定行の周辺コンテキスト
grepika --root . context src/main.rs 42

# インデックス統計
grepika --root . stats

# ファイル間差分
grepika --root . diff a.rs b.rs
```

### スキル: コードベース学習 (`/learn-codebase` 相当)

```bash
grepika --root . stats          # 言語・ファイル数・規模
grepika --root . toc            # ディレクトリ構造
grepika --root . search "main entry point"  # エントリーポイント特定
grepika --root . outline <key-file>         # 主要ファイルの構造
grepika --root . get <key-file>             # 重要コード断片
```

→ 統計、ディレクトリ構造と役割、主要モジュール一覧、エントリーポイント、推奨リーディング順序を出力する。

### スキル: バグ調査 (`/investigate` 相当)

```bash
grepika --root . search "<error message>"   # エラーメッセージ検索
grepika --root . context <path> <line>       # マッチ周辺確認
grepika --root . refs <function>             # 呼び出しチェーン追跡
grepika --root . outline <path>              # 関連ファイル構造
```

→ エラー発生箇所 (file:line)、呼び出しチェーン、エラーハンドリング、修正案を出力する。

### スキル: 変更影響分析 (`/impact` 相当)

```bash
grepika --root . refs <symbol>              # 直接参照を全件取得
grepika --root . search "<related pattern>" # 類似パターン検索
grepika --root . outline <impacted-file>    # 影響ファイル構造
grepika --root . search "test.*<symbol>"    # テストカバレッジ確認
```

→ 直接影響、間接影響、テストカバレッジ、リスク評価 (Low/Medium/High)、安全なリファクタリング手順を出力する。

### スキル: シンボル使用箇所分析 (`/find-usages` 相当)

```bash
grepika --root . refs <symbol>              # 全参照取得
grepika --root . context <path> <line>      # 重要な使用箇所のコンテキスト
grepika --root . refs <caller>              # 呼び出し元をさらに追跡（最大3階層）
grepika --root . outline <path>             # 多参照ファイルの構造
```

→ 定義箇所 (file:line + シグネチャ)、使用サマリ (カテゴリ別件数)、呼び出し階層 (ツリー形式)、リファクタリング注意点を出力する。

### 既知の制限

- **シンボル分類は正規表現ベース。** `refs` の definition/import/usage 分類は行頭パターンマッチ。以下で誤分類する:
  - Go: `func` キーワード未対応（全て Usage 扱い）
  - Rust: `async fn`, `pub(crate) fn`, `impl` 未対応
  - TS/JS: `export function/class/type/interface`, アロー関数, クラスメソッド未対応
  - Python: `async def` 未対応
- **コメント・文字列のフィルタなし。** コメント内の `import` も Import として分類される
- **Import alias 未解決。** `import { A as B }` で `B` から `A` に辿れない
- **依存チェーンの自動追従は不可能。** 手動で refs → context → refs を繰り返す必要がある

→ 正確なシンボル解決が必要な場合は LSP を使うこと。grepika はランキング付き高速検索として併用する。
