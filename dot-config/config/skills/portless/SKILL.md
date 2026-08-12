---
name: portless
description: Run local dev servers on stable named HTTPS URLs (https://<name>.p.ryobox.xyz) via the system portless service. Use when starting a dev server, when port conflicts or hardcoded port numbers appear, when multiple apps/APIs must run side by side, or when a stable local URL is needed for browser automation or worktrees.
---

# portless

dev server を raw な `localhost:<port>` ではなく stable な named HTTPS URL で
公開する。HTTPS + HTTP/2、app ごとの cookie/storage 分離、port 衝突回避が目的。

## この環境の構成(重要)

**portless は NixOS の systemd サービス(`portless.service`)として443で常駐している。**
CLI デフォルト(`~/.portless` + `.localhost`)とは設定が別系統なので、
**必ずサービス側の環境変数を合わせて実行する**こと:

```bash
PORTLESS_STATE_DIR=/var/lib/portless \
PORTLESS_TLD=p.ryobox.xyz \
PORTLESS_PORT=443 \
PORTLESS_FLAT_WORKTREE=1 \
PORTLESS_HTTPS=1 \
portless run pnpm dev
```

- TLD は `p.ryobox.xyz`(wildcard 証明書 `*.p.ryobox.xyz`、DNS は Tailscale IP へ解決)
- `PORTLESS_FLAT_WORKTREE=1` により worktree はフラット命名:
  `https://<branch-prefix>-<project>.p.ryobox.xyz`
  (例: `stone-removal-contract-attribute-bookoff-app.p.ryobox.xyz`)
- routes の正本は `/var/lib/portless/routes.json`

### やってはいけないこと

- **素の `portless run` / `portless proxy start` を実行しない。**
  デフォルト state dir (`~/.portless`) を見て2つ目の proxy を立てようとし、
  443 は使用中のため別 port で壊れた TLS になる。443 の証明書が
  `*.p.ryobox.xyz` なのは「他者による占有」ではなく portless サービス自身。
- `portless proxy stop` をデフォルト env で叩いてもサービスは止まらない
  (別 state dir)。サービスの再起動は `systemctl restart portless.service`。

## 基本コマンド

環境変数(上記)を付けたうえで:

```bash
portless run <cmd>              # project 名から URL を推論して起動
portless <name> <cmd>           # app 名を明示して起動(複数アプリ併走時)
portless get <name>             # 稼働中 service の URL を取得(cross-service 参照用)
portless alias <name> <port>    # 既存 port への static route(Docker 等)
portless alias --remove <name>  # static route の削除
portless list                   # 稼働中 route の一覧
portless doctor                 # proxy / routes / DNS / CA trust の診断
```

## 使い分け

- dev server を起動するときは基本 `portless run` を通す。URL が安定し、
  worktree ごとに衝突しない。
- 自分で起動しない既存 server(Docker 等)には `alias` で route だけ張る。
- URL が開けない・certificate error のときはまず「デフォルト env で
  実行していないか」を疑い、次に `portless doctor`(サービス側 env 付き)。
- sandbox 内から自分で疎通確認するときは DNS が Tailscale IP を返すため、
  `curl --resolve <host>:443:127.0.0.1` で 127.0.0.1 に向ける。
- ブラウザ操作が目的なら、この URL を agent-browser に渡す
  (`agent-browser` skill を参照)。
