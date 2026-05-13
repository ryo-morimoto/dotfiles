# Setup And Maintenance

この文書は dotfiles repo の source-of-truth、メンテナンス手順、検証コマンドをまとめる。

## Project Shape

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

- `flake.nix` / `flake.lock`: 依存と出力定義の入口。
- `hosts/`: ホスト固有の NixOS 構成。`hardware-configuration.nix` は自動生成扱い。
- `home/`: Home Manager のユーザー環境定義。関連設定は `home/<domain>/default.nix` に集約する。
- `packages/`: ローカル package 定義。新規 package は `flake.nix` の overlay に登録する。
- `config/`: アプリ設定の source。Out-of-store symlink の実体。
- `secrets/`: agenix 管理の暗号化シークレット。
- `tools/`: 補助ツール。
- `docs/plans/`: 設計メモ・実装計画。

## Source Of Truth

- 宣言的構成を優先し、設定は Nix か `config/` 配下で一元管理する。
- Home Manager / activation の出力先は直接編集しない。対応する `home/<domain>/*.nix` か `config/<app>/` を更新する。
- 出力先か source か判別できないときは `readlink` で symlink target を確認してから編集する。
- 既存責務を崩さない。host は `hosts/`、user は `home/`、package は `packages/`。
- 新規アプリ設定は `config/<app>/` に追加し、Home Manager から参照する。
- 新規シークレットは平文で置かず、`secrets/*.age` と `secrets/secrets.nix` で管理する。
- 生成物や host-local state は原則コミットしない。必要なら `.gitignore` で吸収する。

## Goal Handling

ゴールを受け取ったら、既知 context から以下を満たす。

```text
目的:         なぜこれを解くのか・なぜ今なのか
解かないこと: 今回スコープ外にするもの
制約:         技術・時間・既存システムとの整合性
最低限:       目的達成に不可欠な要素のみ
検証基準:     WHEN [条件] THEN [期待動作]
```

検証基準が書けない場合は探索フェーズ未完了として、実装前に選択肢を出す。

HitL は次の場合だけ挟む。

- interface / schema / API 境界を新設・変更するとき。
- `docs/agents/operating-principles.md` の未確定ドメインに触れる実装をするとき。
- 明示されたゴールと既存の運用原則が矛盾するとき。

## Maintenance Workflow

1. ゴールの目的・スコープ・制約・最低限・検証基準を確定する。
2. 責務境界に沿って変更先ディレクトリを決める。
3. 小さな差分で実装する。
4. 必要な検証を実行する。
5. 再利用可能な運用原則が確定した場合だけ `docs/agents/operating-principles.md` を更新する。
6. commit する場合は Conventional Commits を使い、1 commit = 1 concern を基本にする。

## Build / Lint / Test Commands

```bash
# Format all .nix files
nixfmt .

# Lint/validate flake
nix flake check

# Dry-run build NixOS configuration
nix build .#nixosConfigurations.ryobox.config.system.build.toplevel --dry-run

# Build full NixOS configuration
sudo nixos-rebuild switch --flake .

# Build a single package
nix build .#showboat

# Enter development shell if available
nix develop

# Evaluate a specific attribute
nix eval .#nixosConfigurations.ryobox.config.system.build.toplevel
```

## Verification Rules

- `.nix` を編集したら `nixfmt` を実行する。
- `flake.nix` / `flake.lock` を編集したら `nix flake check` を実行する。
- Markdown-only 変更では `git diff --check -- <paths>` で空白エラーを確認する。
- 検証できなかった場合は、未検証の範囲と理由を明記する。
