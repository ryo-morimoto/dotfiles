# functional/ (段階4: 機能テスト)

手順は project-local skill `.claude/skills/verify-desktop/` にある (SKILL.md と features/)。このフォルダには、その skill が使うスクリプトを置く。

| ファイル | 役目 |
|---|---|
| `dv` | Launch / Doctor / Drive / Evidence / Cleanup の入口 |
| `gen_nft.py` | 推論 API の nftables の規則を、`verify/d-v3/designs/design.json` から作る (本番と代わりの環境で共通) |
| `vram.sh` | VRAM の計測 |
| `undeclared.sh`、`known-undeclared.txt` | 宣言されていない状態の一覧 |
| `standin/broken-*.nft` | 代わりの環境で、検査が効いていることを確かめるための壊した規則 |

## 段階5との名前の約束

`dv` は、段階5で作る構成が次の名前を使うことを前提にしている。名前を変えるときは、`dv` と features/ も一緒に直す。

| もの | 名前 |
|---|---|
| 推論のサービス | `llama-server.service` (Quadlet が作るシステムのユニット) |
| 推論の API キー | `/etc/llama/api-keys` (ADR-0005 で age から復号する。権限 0600) |
| 推論の nftables のテーブル | `inet desktop_inference` (`gen_nft.py` の出力をそのまま入れる) |
| 押し出しを止めるフック | `/etc/pacman.d/hooks/00-desktop-guard-eviction.hook` |
| 動いた印 | snapper の userdata `desktop_good=yes` (と `important=yes`) |
| 復元のラッパー | `desktop-restore` |
| snapper の設定 | `root` と `home` |
| decman が置いたファイルの一覧 | `/var/lib/decman/managed-files` (decman の実際の保存場所に合わせて段階5で確かめる) |

## これまでの実行

| 日付 | 環境 | feature | 結果 | 証拠 |
|---|---|---|---|---|
| 2026-10-24 | 代わりの環境 (Ubuntu 24.04 のコンテナ。network namespace、nftables 1.0.9、iproute2 6.1.0) | inference | 代用で PASS 4、skip 1 (`deny-other-tailnet`: ACL が無い) | 作業場所の一時フォルダ (このリポジトリには入れていない。要約は台帳) |
| 2026-10-24 | 同上。`DV_STANDIN_NFT=standin/broken-daddr.nft` | inference | 期待どおり `deny-lan-to-ts-ip` が fail。weak host model を実物のカーネルで確かめた (D-V3 のモデルの突き合わせ) | 同上 |
| 2026-10-24 | 同上。`DV_STANDIN_NFT=standin/broken-none.nft` | inference | 期待どおり `deny-lan-to-ts-ip` が fail | 同上 |

代わりの環境が行ったが実機では行わない準備 (実機で確かめるまで未検証のもの):

- network namespace を3つ作り、veth で LAN と tailscale0 を模した (実機では、本物の NIC と Tailscale の TUN)。
- LAN の端末側に、Tailscale のアドレス宛ての経路を足した (実機では、LAN の端末で人が足す。features/inference.md)。
- llama-server の代わりに `python3 -m http.server` を Tailscale のアドレスで待ち受けさせた (実機では、Quadlet の llama-server。API キーと OpenAI 互換は代わりの環境では見ていない)。
- Tailscale の ACL は無い (実機では、Server 側に依頼した ACL が要る)。
