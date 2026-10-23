# Desktop 検証の台帳

対象: `desktop.md` v3。各制約について「主張 / 機械検査またはテストの結果 / 確認質問」を残す。
この台帳が最終成果物になる。段階ごとに追記する。

**結果の書き方:** `PASS` / `FAIL` / `未実施` / `代用で PASS` (VM などで確かめた。実機は未実施)。必ず実行したコマンドか、記録へのリンクを添える。

## 0. 段階の状態

| 段階 | 状態 | 終わる条件 | 機械検査 |
|---|---|---|---|
| 1. 制約を確定する | 完了 (2026-10-24 合意) | MUST の制約に【仮】が残っていない | `checks/no-provisional-must.sh` → OK (v3、MUST 18件)。壊した版 (v2) では FAIL (PERF-1 / REL-1 / MNT-1)。`checks/ids-preserved.sh v2 v3` → OK (77件が残り、N6 / PERF-5 / Q8 / Q9 を追加)。壊した版 (FUN-5 の行を削除) では FAIL |
| 2. 構成を提案する | 完了 (2026-10-24 合意) | すべての MUST 制約が、どれかの ADR に対応付いている | `checks/must-covered-by-adr.sh` → OK (MUST 18件)。壊した版 (ADR-0006 から SAF-1 を外す) では FAIL。ADR が存在しない ID を参照した版も FAIL |
| 3. 検証を設計する | 進行中 (D-V1 のモデルで出た設計の穴について確認待ち) | D-V1〜D-V4 それぞれに判断と理由があり、値するものが壊した版で失敗する | `verify/README.md` に判断を記録 (4つとも値する)。D-V1: 合意した図は 2026-10-24 にユーザーが承認。TLA+ のモデルでは、合意した図のままだと `NoWayBack` が破れる。提案 (a)〜(e) では `NoWayBack` と `UpdatesStayPossible` の両方が成り立つ。壊した版5つはすべて期待どおりに失敗する (`verify/run.sh` → exit 0) |
| 4. 機能テストを用意する | 未着手 | 6章の各項目がスクリプトになっている | 未作成 |
| 5. 構成を実装する | 未着手 | 4章の機能テストが通る | 未作成 |

## 1. 制約ごとの記録

主張は段階2 (2026-10-24) の ADR に沿って書いた。結果は段階3〜5で埋める。

| ID | 強さ | 主張 | 機械検査 / テストの結果 | 確認質問 |
|---|---|---|---|---|
| FUN-1 | MUST | ADR-0001: hazkey 以外は公式。hazkey は上流が勧める AUR、zen は Flathub | 未実施 → 機能テスト `drive/workspace` (段階4) | — |
| FUN-2 | MUST | ADR-0001/0004: mise と公式パッケージ | 未実施 | — |
| FUN-3 | MUST | ADR-0003: nvidia-open + nvidia-container-toolkit + 上流の llama.cpp CUDA 13 イメージ | 未実施 | — |
| FUN-4 | SHOULD | zen (Flathub)、ノートアプリ | 未実施 | — |
| FUN-5 | 廃止 | (欠番。Q7) | — | — |
| PERF-1 | MUST | ADR-0003: niri の VRAM プロファイル。常駐分 ≤ 0.5GB | 未実施 → `evidence/vram` | — |
| PERF-2 | SHOULD | ADR-0003 (部分): 未計測 | 未実施 | — |
| PERF-3 | SHOULD | ADR-0003 (部分): 未計測 | 未実施 | — |
| PERF-4 | MAY | — | 未実施 | — |
| PERF-5 | SHOULD | プロセスごとの VRAM の一覧 | 未実施 → `evidence/vram` | — |
| COMP-1 | MUST | ADR-0003 (部分): `--fit` で余白を残す | 未実施 | — |
| COMP-2 | MUST | ADR-0003: llama-server の OpenAI 互換 API | 未実施 | — |
| COMP-3 | SHOULD | Tailscale の MagicDNS (手段に依らない) | 未実施 | — |
| INT-1 | MUST | ADR-0004: GUI が書く層 (`dms/*.kdl`) は管理外。chezmoi は黙って上書きしない | 未実施 → D-V2、`drive/settings-live-reload` | — |
| INT-2 | MUST | ADR-0004: niri は include 先も即時に読み直す | 未実施 | — |
| INT-3 | SHOULD | ADR-0001: `decman --dry-run` + pacman の一覧 + `chezmoi status` | 未実施 → `doctor/undeclared-state` | — |
| REL-1 | MUST | ADR-0002 (部分): limine-snapper-sync でブートメニューから戻す | D-V1 (`verify/run.sh`): 今の ADR のままでは `NoWayBack` が破れる。提案 (a)〜(e) を足すと成り立つ (スナップショット12個までの範囲)。時間は未計測 → `drive/rollback-drill` | 2026-10-24 回答: 説明の破綻 (アプリが一方通行で設定を移す) を直す → ADR-0002 決定 7 (`@home` を指定パスだけ戻す) |
| REL-2 | SHOULD | ADR-0002: `@pkg` のキャッシュ / ALA、推論はダイジェスト | 未実施 | — |
| REL-3 | MUST | ADR-0003: 7章の約束 (ベストエフォート) | 未実施 | — |
| REL-4 | MUST | ADR-0004: git → Server、残りは restic → HDD | 未実施 → `doctor/desktop-only-data` | 2026-10-24 回答: ok |
| REL-5 | SHOULD | ADR-0002: HDD は `nofail` | 未実施 | — |
| SEC-1 | MUST | ADR-0003: tailscale0 だけ + nftables + ACL + API キー | 未実施 → D-V3、`drive/inference-reachability` | — |
| SEC-2 | MUST | ADR-0005: age + gitleaks | 未実施 → `doctor/secrets` | 2026-10-24 回答: 暗号化しない (顧客情報を置かない)。持ち出しには失効手順書 (`runbooks/credential-revocation.md`) で備える |
| SEC-3 | SHOULD | ADR-0001 (部分): AUR は許可リスト3件 | 未実施 | 2026-10-24 回答: ok |
| SEC-4 | SHOULD | — | 未実施 | — |
| MNT-1 | MUST | ADR-0001/0003 (部分): Arch + 推論は上流のコンテナ | 計測 2026-10-23: llama-cpp (extra) 8日、DMS 3日。過去180日の超過は cuda 1、ollama-cuda 1、llama-cpp 1 (`research/snapshots/`) | 2026-10-24 回答: 最新系列を追う → ADR-0001 決定 6 |
| MNT-2 | MUST | ADR-0001: decman の差分適用 | 未実施 → `drive/declare-apply` | — |
| MNT-3 | MUST | ADR-0001: decman と chezmoi を dotfiles の1か所に | 未実施 | — |
| MNT-4 | SHOULD | ADR-0001 (部分): informant + AUR 差分の確認 | 未実施 (週ごとに記録) | — |
| MNT-5 | SHOULD | ADR-0001 (部分): NVIDIA の VRAM 対策は長く残る | 未実施 | — |
| FLX-1 | MUST | ADR-0004: chezmoi + mise | 未実施 | — |
| FLX-2 | SHOULD | ADR-0001: decman の集合 | 未実施 | — |
| FLX-3 | SHOULD | ADR-0006 (部分): `install/bootstrap.sh` | 未実施 → `drive/install-from-zero` (VM で代用) | — |
| FLX-4 | MAY | — | 未実施 | — |
| SAF-1 | MUST | ADR-0006: 消去の入口1つ + by-id / シリアル番号 / 容量の検査 | 未実施 → D-V4 | — |
| SAF-2 | SHOULD | ADR-0003: `nvidia-smi -pl` | 未実施 | — |

## 2. 見直しトリガーの記録

| 日付 | トリガー | 内容 | 対応 |
|---|---|---|---|
| 2026-10-20 | P-2 (大きな破壊的変更) 1回目 | DMS 2.0.0 で上流が Dux Shell (duxlabs-dev/dux-shell) に改名。パッケージを作る側の手直しが要る。Arch では `dux-shell` 2.0.0 が extra-testing (2026-10-21) | 記録のみ。続けば P-2 を見直す |

## 3. Server への確認事項

7章の約束を変えたくなったときに、変更案をここに書く。Server 側のセッション (server.md 7章) への反映が要る。

| # | 日付 | 変更案 | 理由 (制約 ID) | 状態 |
|---|---|---|---|---|
| 1 | 2026-10-24 | 7章の約束に追記する案: Desktop の推論 API (TCP 8080) へ届いてよい相手を、Tailscale の ACL で「自分の端末と Server のノードのタグ」に限る。文面: `server-requests/0001-inference-acl.md` | SEC-1 | 2026-10-24 ユーザー承認。送付待ち (Server のセッションに届く経路が今は無い) |
