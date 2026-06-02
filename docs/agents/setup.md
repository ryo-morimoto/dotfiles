# Setup And Maintenance

この文書は dotfiles repo の source-of-truth、メンテナンス手順、検証コマンドをまとめる。

## Project Shape

```text
.
|-- nix-config/
|   |-- flake.nix
|   |-- flake.lock
|   |-- hosts/
|   |-- home/
|   |-- packages/
|   `-- secrets/
|-- dot-config/
|   |-- config/
|   `-- agents/
|-- tools/
|   `-- <tool>/...
|-- skills/
|   `-- <skill>/...
|-- docs/
|   `-- plans/
`-- .github/workflows/
```

- `nix-config/`: Nix flake、NixOS modules、Home Manager baseline、nixpkgs/community package wiring、agenix secrets。
- `dot-config/config/`: Home Manager から `~/.config` に symlink する mutable app config。
- `dot-config/agents/`: AI tool runtime notes と reviewed examples。Nix は live Codex、Claude、APM、MCP、skill、hook config を生成しない。
- `tools/`: 補助ツール。
- `docs/plans/`: 設計メモ・実装計画。

## Source Of Truth

- 再現したい基盤は `nix-config/`、運用しながら変える設定は `dot-config/` に置く。
- Home Manager / activation の出力先は直接編集しない。対応する `nix-config/home/<domain>/*.nix` か `dot-config/config/<app>/` を更新する。
- 出力先か source か判別できないときは `readlink` で symlink target を確認してから編集する。
- 既存責務を崩さない。host は `nix-config/hosts/`、user は `nix-config/home/`、Nix 外の experimental tool は `dot-config/config/mise/`。
- 新規アプリ設定は `dot-config/config/<app>/` に追加し、Home Manager から参照する。
- 新規シークレットは平文で置かず、`nix-config/secrets/*.age` と `nix-config/secrets/secrets.nix` で管理する。
- AI tool runtime config、MCP、skills、hooks、plugins は原則 Nix で生成しない。
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
fd -e nix . nix-config -x nixfmt {}

# Lint/validate flake
nix flake check ./nix-config

# Dry-run build NixOS configuration
nix build ./nix-config#nixosConfigurations.ryobox.config.system.build.toplevel --dry-run

# Build full NixOS configuration
sudo nixos-rebuild switch --flake ./nix-config#ryobox

# Enter development shell if available
nix develop ./nix-config

# Evaluate a specific attribute
nix eval ./nix-config#nixosConfigurations.ryobox.config.system.build.toplevel
```

## Verification Rules

- `.nix` を編集したら `nixfmt` を実行する。
- `nix-config/flake.nix` / `nix-config/flake.lock` を編集したら `nix flake check ./nix-config` を実行する。
- Markdown-only 変更では `git diff --check -- <paths>` で空白エラーを確認する。
- 検証できなかった場合は、未検証の範囲と理由を明記する。
