# Server への依頼 0001: 推論 API に届く相手を Tailscale の ACL で絞る

日付: 2026-10-24。送り元: Desktop のセッション (desktop.md 7章、台帳「Server への確認事項」#1)。状態: 送付待ち。

## 依頼

desktop.md 7章の「Desktop → Server: 推論 API」の約束に、次の一文を足したい。

> Desktop の推論 API (TCP 8080) に届いてよい相手は、Tailscale の ACL で「自分の端末」と「Server のノード」に限る。

Tailscale の ACL は tailnet 全体の設定なので、Desktop だけでは決められない。ACL を管理している側 (Server のセッション) で、次のことをお願いしたい。

1. Desktop のノードにタグ `tag:desktop` を付けられるようにする (`tagOwners`)。
2. 次の grant を入れる。

   ```json
   {
     "src": ["autogroup:member", "tag:server"],
     "dst": ["tag:desktop"],
     "ip":  ["tcp:8080"]
   }
   ```

   - `tag:server` は Server のノードに付いているタグの名前に置き換える。Desktop 側は名前だけを知っていればよい。
   - `autogroup:member` は tailnet の利用者 (自分の端末) を指す。
3. ほかの grant や ACL が `tag:desktop` の 8080 を広く開けていないこと (例: `"src": ["*"], "dst": ["*"]` の全許可) を確かめる。

## 理由

- SEC-1 (MUST): 推論 API には認証された相手 (自分の端末と Server のノード) からだけ届く。LAN 全体やインターネットには出さない。
- Desktop 側では、tailscale0 だけで待ち受けること、nftables、API キーで守る (ADR-0003)。ACL はそれに重ねる層で、tailnet の中の許可していない端末から届かないことを保証する。

## Desktop 側での確かめ方

- D-V3 (形式検証): Desktop の待ち受けアドレスと nftables の設定から、許可していない送り元のどれからも届かないことを全列挙で検査する。ACL は「上の grant だけが `tag:desktop:8080` を開ける」という前提として扱う。
- 機能テスト `drive/inference-reachability`: 許可した端末からは届き、tailnet の許可していない端末と LAN の端末からは届かないことを実機で確かめる。

## Server の内部構成への依存

なし。Desktop が知る必要があるのは、Server のノードのタグの名前だけである。
