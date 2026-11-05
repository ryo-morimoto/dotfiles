# 引き継ぎ: Desktop の設計 → 検証 → 機能テスト

作成: 2026-10-23。Server は別のセッションで扱う。**Server の内部構成には依存しない。**

## 1. ここまでに決まったこと

- **`desktop.md` (v2):** 目的、成立条件、制約、優先順位、未確定事項、検証方法、Server との約束。手段は付録にある。
  - 制約は3区分: G 所与 / P 選好 / Q 品質要求。Q は ISO/IEC 25010:2023 の9特性で網羅している。
  - 未確定事項 Q1〜Q7 への回答を待っている。
- **方針:** 本文に手段を書かない。手段は付録と ADR に置き、制約 ID で採点する。手段を替えるときは付録と ADR だけを書き換える。
- **事実:**
  - ハード: i7-7700K、RAM 16GB (スロット2つ空き)、RTX 3060 Ti 8GB、1080p144 x2、JIS キーボード、NVMe 1TB と HDD 2TB (どちらも全消去してよい)、UEFI。Secure Boot は今は有効。
  - 今の環境: dotfiles (https://github.com/ryo-morimoto/dotfiles) を NixOS + Home Manager + chezmoi + mise で運用している。この構成を守る前提は無い。
- **調査済みの候補** (付録 A):
  - A: Fedora bootc
  - B: Arch + decman (暫定の選択)
  - C: NixOS の組み直し
  - 手段を決める分かれ目は Q1 (戻れることと鮮度のどちらを上に置くか)。
- **廃止したもの:** 以前に作った NixOS の構成一式。制約より前に作ったもので、制約に反していた。使わない。

## 2. Server との約束 (desktop.md 7章)

- **Desktop が出すもの:** 推論 API (OpenAI 互換)。tailnet 内の認証された相手だけに出す。可用性はベストエフォート。
- **Desktop が使うもの:** Server のサービス。ノードではなく名前で届く。
- この約束を変えるときは、Server 側のセッション (server.md 7章) にも反映が要る。変更点は台帳に「Server への確認事項」として残す。

## 3. 検証の対象候補

| # | 対象 | 守る制約 | 性質の例 | 道具 |
|---|---|---|---|---|
| D-V1 | 更新と巻き戻し (更新 → 失敗 → 直前の状態へ) | REL-1, REL-2, MNT-1 | `AlwaysAWorkingStateReachable` | statechart → TLA+。形式化に値するかをまず判断する |
| D-V2 | niri 設定の読み込み順 (DMS ベース → default-binds → local → `dms/*.kdl`) | INT-1 | `DmsUiWriteAlwaysWins` | 全列挙 (有限で決定的) |
| D-V3 | 推論 API の公開範囲 (ファイアウォール + Tailscale ACL) | SEC-1 | `InferenceOnlyFromAllowedPeers` | Z3 か全列挙で設定を検査し、実機テストでも確かめる |
| D-V4 | ディスクの指定 (消去対象の取り違え) | SAF-1 | `WipeTargetsOnlyDeclaredIds` | 設定の静的検査 |

- **中心は機能テスト:** desktop.md 6章 (鮮度の記録、巻き戻し訓練、VRAM の計測、公開範囲、ゼロからの再現時間、宣言外の状態の一覧) を、実行できるスクリプトにする。
- **性能 (PERF-\*) は形式化に向かない。** 計測で扱う。

## 4. 参照する手順書

- **mizchi playbook:** https://gist.github.com/mizchi/db7817e6fc077d567c41cd9d41bb1c53 。道具の選び方、broken-variant (壊した版で失敗することの確認)、台帳、やめ時。
- **pstack の skill** (Cursor 向けなので、出力先 `.cursor/skills/` は `.claude/skills/` に読み替える):
  - create-formal-verification-skill
  - create-verification-skill
  - statechart
  - URL は https://github.com/cursor/plugins/tree/main/pstack/skills/ 以下。
