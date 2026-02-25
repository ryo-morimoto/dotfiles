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
|   `-- default.nix
|-- packages/
|   `-- *.nix
|-- config/
|   `-- <tool>/...
|-- secrets/
|   |-- secrets.nix
|   `-- *.age
|-- tools/
|   `-- <tool>/...
|-- scripts/
|   `-- ...
|-- docs/
|   `-- plans/
`-- .github/workflows/
```

- `flake.nix` / `flake.lock`: 依存と出力定義の唯一の入口
- `hosts/`: ホスト固有の NixOS 構成（`hardware-configuration.nix` は自動生成扱い）
- `home/`: Home Manager のユーザー環境定義
- `packages/`: ローカル package 定義（overlay で公開）
- `config/`: アプリ設定（Out-of-store symlink の実体）
- `secrets/`: agenix 管理の暗号化シークレット
- `tools/` / `scripts/`: 補助ツールと運用スクリプト
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

- [進め方]: 破壊的変更・契約変更以外は自律実行する
- [dotfiles品質]: `.nix` 編集後は `nixfmt`、flake 変更時は `nix flake check` で検証する
- [構成方針]: Nix Flakes + Home Manager の宣言的構成を維持する
- [コミット運用]: Conventional Commits を基本に、小さめの差分を高頻度で積む
- [依存更新運用]: `chore: update flake.lock` を定期実行し、依存更新を継続する

## 未確定ドメイン（U）

- デスクトップ環境の方向性（Niri + waybar 継続 / DMS 導入）
- 既定ブラウザの方向性（Firefox 基準の維持 / Zen への移行）

## 直近100件のコミットログ分析（2026-01-20〜2026-02-25）

- 種別内訳: `feat 41` / `chore 36` / `refactor 7` / `fix 6` / `docs 4` / `style 3` / `revert 1` / 非Conventional 1件
- `chore: update flake.lock` が22件（flake関連合計28件）で、依存更新を高頻度で継続
- デスクトップ環境・テーマ関連（`niri`/`waybar`/`DMS`/`wallust`/`theme` など）が22件
- エージェント運用関連（`agent`/`claude`/`opencode`/`entire`/`tmuxcc`）が12件
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
