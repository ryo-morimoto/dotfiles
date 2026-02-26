# Primeagen-like Coding Agent x Neovim Workflow

このドキュメントは、今の dotfiles に実装済みの構成に合わせた
**Neovim + tmux + git-wt + coding agent 運用手順**です。

目的はシンプルです。

- Neovim をレビューと指示返しのハブにする
- task ごとに worktree を分離して衝突を減らす
- `claude` / `opencode` / `codex` を並列で回す

---

## 1. いま有効な統合内容

### 1.1 Worktree / tmux 側

- `git-wt` を導入済み（`home/default.nix`）
- `wt.basedir = ../{gitroot}-wt`
- `git wt` 作成時 hook: `scripts/git-wt/on-create.sh`
- `git wt` 削除時 hook: `scripts/git-wt/on-delete.sh`
- エイリアス:
  - `wt`: `git wt`
  - `wtd`: `git wt -d`
  - `wtc`: `GIT_WT_AGENT=claude git wt`
  - `wto`: `GIT_WT_AGENT=opencode git wt`
  - `wtx`: `GIT_WT_AGENT=codex git wt`

### 1.2 Neovim 側

- `vim-slime` を追加済み: `config/nvim/lua/plugins/agent.lua`
- `which-key` に Agent グループ追加済み（`<leader>a`）
- 送信先 pane 選択 UI あり（tmux pane 一覧から attach）

---

## 2. 初回反映（まだなら）

`home/default.nix` の変更を反映して、`git-wt` と alias を有効化する。

```bash
home-manager switch --flake .#ryo-morimoto
```

`git wt` が使えることを確認:

```bash
git wt
```

---

## 3. 最短スタート手順

## 3.1 main をレビュー専用で開く

```bash
cd ~/ghq/github.com/ryo-morimoto/dotfiles
tmux new-session -A -s dotfiles
nvim
```

## 3.2 task を1本起動

```bash
wtc nvim-agent-keymaps
```

これで自動実行されること:

- `../dotfiles-wt` 配下に worktree を作成（または既存へ移動）
- branch は `git wt` に渡した名前で作成/選択される（固定プレフィックスなし）
- tmux window を `repo:branch` 名で作成/選択
- `GIT_WT_AGENT` が指定されていれば agent を自動起動

agent 切り替え例:

```bash
wto fix-lsp
wtx docs-refresh
```

branch 名を明示したい例:

```bash
wtc feat/nvim-agent-keymaps
wtc chore/update-agent-doc
```

---

## 4. Neovim から agent に投げる操作

`<leader>` は `Space`。

- `<leader>aa`: 送信先 pane を選択して attach
- `<leader>as` (visual): 選択範囲を送信
- `<leader>as` (normal): 現在段落を送信
- `<leader>al`: 現在行を送信
- `<leader>ap`: プロンプト入力をそのまま送信
- `<leader>ac`: `:SlimeConfig` を開いて手動設定

実運用の最短:

1. `wtc` / `wto` / `wtx` で task 起動
2. Neovim で `<leader>aa` して対象 pane を選択
3. 差分レビューしながら `<leader>as` or `<leader>ap` で指示返し

---

## 5. レビュー操作（現行設定）

### 5.1 Git 差分レビュー

- `]c` / `[c`: hunk 前後移動
- `<leader>gp`: hunk preview
- `<leader>gs`: hunk stage
- `<leader>gr`: hunk reset
- `<leader>gg`: LazyGit

### 5.2 補助操作

- `[d` / `]d`: 診断移動
- `<leader>d`: 診断詳細
- `<Tab>` / `<S-Tab>`: バッファ切替
- `<C-\\>`: terminal トグル

---

## 6. 1日の運用ループ

1. main でレビュー専用 Neovim を開く
2. task ごとに `wtc` / `wto` / `wtx` で並列起動
3. Neovim で差分確認 -> `<leader>aa` で pane attach
4. `<leader>as` / `<leader>ap` で修正指示
5. task 側でテスト・コミット
6. `wtd <task>` で worktree 削除（delete hook で tmux window も掃除）

---

## 7. 統合手順（task 完了後）

task 側:

```bash
git fetch origin
git rebase origin/main
prek run --all-files
```

main 側:

```bash
git checkout main
git pull --ff-only
git merge --ff-only <branch>
```

片付け:

```bash
wtd <task>
```

---

## 8. hook の動作仕様

## 8.1 `on-create.sh`

- tmux 内でのみ動作
- 作成/切替した worktree に対応する tmux window を作成 or 再利用
- window に以下のメタを保存
  - `@git_wt_path`
  - `@git_wt_branch`
- `GIT_WT_AGENT` が `claude|opencode|codex` のとき、新規 window なら agent を自動起動

## 8.2 `on-delete.sh`

- 削除対象 worktree と紐づく tmux window をクリーンアップ
- 現在アクティブな window は安全のため kill しない
- 現在 window が対象なら「手動で閉じてね」という警告を出す

---

## 9. よくある詰まり方

- `wtc` が見つからない
  - `home-manager switch` 後にシェルを開き直す
  - 一時的には `GIT_WT_AGENT=claude git wt <task>` を使う

- `No agent pane found` が出る
  - tmux 外で Neovim を開いていないか確認
  - `wtc/wto/wtx` で pane を起動してから `<leader>aa`

- 送信先が違う pane になった
  - `<leader>aa` で再attach
  - もしくは `<leader>ac` で `SlimeConfig`

- `wtd` 後に window が残る
  - 現在表示中 window は delete hook が kill しない仕様
  - 手動で `tmux kill-window` する

---

## 10. いま未導入の拡張（必要なら次）

このドキュメントは「現行構成」に合わせているため、以下は未導入です。

- `diffview.nvim`
- `git-worktree.nvim`
- `vim-tmux-navigator`

必要になったら追加し、同じドキュメントを更新する。
