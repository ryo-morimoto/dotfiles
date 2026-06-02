# Tooling

この文書は dotfiles repo で使う補助ツールの参照情報をまとめる。

## Browser Automation / Local URLs

### `agent-browser`

- ブラウザを実際に開いて操作・観測するときに使う。
- クリック、入力、snapshot、screenshot、PDF、console/errors 確認、CDP 接続は `agent-browser` の責務。
- 標準フローは `open` -> `snapshot -i` -> `@ref` で操作 -> 必要に応じて `wait` / `get` / `screenshot`。
- 認証状態や既存 Chrome を再利用したいときは `--profile` / `--session-name` / `--auto-connect` / `--cdp` を使う。
- local URL の命名や port 管理は担当しない。URL を安定させたいだけなら `portless` を使う。

### `portless`

- dev server を raw な `localhost:<port>` ではなく stable な `https://<name>.localhost` で公開したいときに使う。
- `portless run <cmd>` は project 名から URL を推論し、git worktree では branch/worktree prefix を付けて URL 衝突を避ける。
- 複数アプリや API を同時に立ち上げるときは `portless <name> <cmd>` や `portless alias <name> <port>` を使う。
- HTTPS + HTTP/2、app ごとの cookie/storage 分離、port 衝突回避に向いている。
- ブラウザ操作はしない。UI 操作や rendering 確認は `agent-browser` と組み合わせる。

### Combined Use

- Browser automation が目的なら、先に `portless` で安定 URL を作り、その URL を `agent-browser open <url>` に渡す。
- 例: `portless run next dev` -> `agent-browser open https://myapp.localhost`
- `agent-browser` 単独で十分なのは、既存 URL に対する操作・確認が主目的のとき。
- `portless` 単独で十分なのは、開発 URL を固定したいときや worktree ごとに URL を分けたいとき。

## Grepika CLI

Grepika は BM25 + trigram + ripgrep の3バックエンドスコア合算でランキング付き検索結果を返す検索 CLI。

プロジェクトに入ったら最初に index を構築する。

```bash
grepika --root "$(pwd)" index
```

フルリビルド:

```bash
grepika --root . index --force
```

`--root <path>` はグローバルオプションなので、サブコマンドの前に置く。

```bash
# ランキング付き検索
grepika --root . search "authentication" -l 20

# 検索モード指定: combined(default) / fts / grep
grepika --root . search "error handling" -m fts

# シンボル参照一覧
grepika --root . refs "home.packages"

# ファイル構造抽出
grepika --root . outline src/main.rs

# ディレクトリツリー
grepika --root . toc

# ファイル内容取得
grepika --root . get src/main.rs

# 指定行の周辺 context
grepika --root . context src/main.rs 42

# index stats
grepika --root . stats
```

### Common Flows

Codebase learning:

```bash
grepika --root . stats
grepika --root . toc
grepika --root . search "main entry point"
grepika --root . outline <key-file>
grepika --root . get <key-file>
```

Bug investigation:

```bash
grepika --root . search "<error message>"
grepika --root . context <path> <line>
grepika --root . refs <function>
grepika --root . outline <path>
```

Impact analysis:

```bash
grepika --root . refs <symbol>
grepika --root . search "<related pattern>"
grepika --root . outline <impacted-file>
grepika --root . search "test.*<symbol>"
```

### Known Limits

- Symbol classification is regex-based and can misclassify definitions/imports/usages.
- Comments and strings are not filtered.
- Import aliases are not resolved.
- Dependency chains are not followed automatically.
- Use LSP when exact symbol resolution matters.
