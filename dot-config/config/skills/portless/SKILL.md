---
name: portless
description: Run local dev servers on stable named HTTPS URLs (https://<name>.localhost) instead of raw localhost ports. Use when starting a dev server, when port conflicts or hardcoded port numbers appear, when multiple apps/APIs must run side by side, or when a stable local URL is needed for browser automation or worktrees.
---

# portless

dev server を raw な `localhost:<port>` ではなく stable な
`https://<name>.localhost` で公開する。HTTPS + HTTP/2、app ごとの
cookie/storage 分離、port 衝突回避が目的。proxy は初回実行時に自動起動する。

## 基本

```bash
portless run <cmd>              # project 名から URL を推論して起動
                                # 例: portless run next dev -> https://<project>.localhost
                                # git worktree 内 -> https://<worktree>.<project>.localhost
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
- URL が開けない・certificate error のときは `portless doctor`。
- ブラウザ操作が目的なら、この URL を agent-browser に渡す
  (`agent-browser` skill を参照)。
