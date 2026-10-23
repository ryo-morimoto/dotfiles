# ADR (手段の決定)

各 ADR の先頭に、機械検査用のメタデータを置く。

```yaml
---
id: ADR-000N
status: proposed | accepted | superseded
satisfies: [ID, ...]      # この決定で満たす制約
partial: [ID, ...]        # 一部だけ満たす。本文の「満たせない制約と妥協」に理由を書く
not_satisfied: [ID, ...]  # 満たせない。同上
---
```

`checks/must-covered-by-adr.sh` は、`desktop.md` の MUST の制約が、どれかの ADR の `satisfies` か `partial` に入っていることを確かめる。

| ADR | 決定 | 状態 |
|---|---|---|
| [0001](0001-os-base-and-declaration.md) | OS は Arch Linux、システムの宣言は decman | 提案 |
| [0002](0002-update-and-rollback.md) | 更新と巻き戻しは btrfs + snapper + Limine + limine-snapper-sync | 提案 |
| [0003](0003-inference-runtime.md) | 推論は上流の llama.cpp コンテナ。Tailscale の内側だけに出す | 提案 |
| [0004](0004-user-config-and-data.md) | ユーザー設定は chezmoi、開発ツールは mise。データは Desktop に置かない | 提案 |
| [0005](0005-secrets.md) | 秘密情報は age で暗号化して git に置く | 提案 |
| [0006](0006-disk-and-install.md) | ディスクは by-id で指定し、検査を通してからインストールする | 提案 |
| [0007](0007-secure-boot.md) | Secure Boot は無効にする | 提案 (確認待ち) |
