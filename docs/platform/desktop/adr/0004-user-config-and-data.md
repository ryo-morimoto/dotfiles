---
id: ADR-0004
status: proposed
satisfies: [INT-1, INT-2, FLX-1, REL-4]
partial: [FUN-2]
not_satisfied: []
---

# ADR-0004: ユーザー設定は chezmoi、開発ツールは mise。データは Desktop に置かない

日付: 2026-10-24。状態: 提案。

## 文脈

- dotfiles リポジトリはすでに、`$HOME` の配備を標準の chezmoi で行っている。source に実体を置いてコピーで配り、アプリが書き換えた live の変更は `chezmoi re-add` で回収する (`docs/agents/operating-principles.md`)。この運用は OS の管理手段に依存しない。
- INT-1 は「アプリが自分で書き換える設定 (GUI の設定画面) を書き込め、宣言と衝突しない」ことを求めている。niri と DMS では、次の2点がこれに関わる。
  - DMS の設定画面は `~/.config/niri/dms/*.kdl` や DMS の settings.json を書く。
  - niri は include したファイルも監視し、変更を即時に読み直す。
- decman の File はコピーで置き、次の実行で上書きする。したがって `$HOME` を decman で宣言すると INT-1 とぶつかる (facts-arch)。

## 決定

1. **`$HOME` の設定は chezmoi の source (`dot-config/chezmoi/`) に置く**。decman は `$HOME` を扱わない。ADR-0001 との境界は次のとおり。
   - decman: パッケージ、/etc、systemd のシステムユニット。
   - chezmoi: `$HOME` のファイルと、systemd のユーザーユニット。
2. **niri の設定は include で層に分ける** (付録 A.3 の共通部品)。読み込み順は DMS ベース → default-binds → local.kdl → `dms/*.kdl`。最後の `dms/*.kdl` は DMS の設定画面が書くので、そこが勝つ。
   - chezmoi が管理する: 前の3層。
   - chezmoi が管理しない: `dms/*.kdl`。機械が生成するファイルは管理に含めない、という既存の原則に従う。
3. **DMS の settings.json** は、GUI で変えた結果を `chezmoi re-add` で source に回収する。chezmoi は「最後に書いた後でアプリが変えた」ファイルを、上書きする前に確認する。
4. **開発ツールとエージェント CLI** は mise で入れる (`dot-config/chezmoi/dot_config/mise/`)。OS のパッケージに依存しないものは mise に置く。
5. **データ:**
   - 作業データは git リポジトリに置き、Server のコード置き場へ push する (7章の約束にある Server のサービス)。
   - git の外に残るユーザーデータは restic (extra) で HDD に毎日バックアップする。NVMe か HDD のどちらか1台が壊れても、データを失わない。
   - 機能テスト `doctor/desktop-only-data` が、push していないコミット、追跡していないファイル、バックアップの古さを一覧する。

## 満たす制約

| ID | どう満たすか | 根拠 |
|---|---|---|
| INT-1 | GUI が書くファイルは管理外の層 (`dms/*.kdl`) に置き、宣言の層と分ける。chezmoi はアプリが書き換えたファイルを黙って上書きしない | niri docs/wiki/Configuration:-Include.md、dotfiles の運用原則 |
| INT-2 | niri は include 先も監視して即時に読み直す。chezmoi はコピーで置くので、`chezmoi apply` の直後に反映される。再構築も再起動も要らない | niri docs/wiki/Configuration:-Introduction.md |
| FLX-1 | chezmoi の source と mise の設定は OS の管理手段から独立している。OS を替えても、そのまま持ち越せる | — |
| REL-4 | 作業データは git → Server、残りは restic → HDD に置く。一覧の機能テストで、Desktop にしか無いデータを検出する | — |

## 満たせない制約と妥協

| ID | 満たせない部分 | 妥協の理由と手当て |
|---|---|---|
| FUN-2 (部分) | エージェント CLI の中には、mise で入れられず、上流のインストーラしか無いものがある (未調査) | 上流のインストーラで入れたものは、宣言外の状態として INT-3 の一覧に出す。1か月以上使うものだけを宣言に昇格する (既存の運用原則) |

## トレードオフ

- **得るもの:** 今の dotfiles の運用をほぼそのまま使える。OS を替えても `$HOME` が持ち越せる。
- **失うもの:**
  - `chezmoi re-add` を忘れると、GUI で変えた設定が source に戻らない。そのため INT-3 の一覧に `chezmoi status` の差分を含める。
  - HDD へのバックアップは同じ筐体の中なので、筐体ごとの損失 (火災、盗難) には効かない。

## 切り替えトリガー

| 条件 | 切り替え先 |
|---|---|
| DMS が設定の書き込み先を変える (2.0 で `DankMaterialShell` から `dms` へ移った前例がある) | include の層を付け直す。D-V2 を検証し直す |
| Server にバックアップの受け口ができる | 台帳の「Server への確認事項」に書き、7章の約束に足す案を出す |

## 検証

- D-V2: niri の読み込み順を全列挙し、`DmsUiWriteAlwaysWins` を検査する (段階3)。
- 機能テスト `drive/settings-live-reload`: DMS の設定画面での変更と、chezmoi の source の変更が、それぞれ再起動なしで反映されることを確かめる (段階4)。
