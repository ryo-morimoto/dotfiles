# Neovim Configuration Design - Complete Specification

## Overview

カスタムNeovim設定を自分で構築する。初心者向けに使いやすく、複数言語での開発に対応。

## Complete Decision Summary

### 基本設定

| Item | Decision | Reason |
|------|----------|--------|
| 用途 | 一般的なコーディング（複数言語） | TypeScript, Python, Rust, Go, Nix等 |
| アプローチ | 自分で構築 | 完全に理解・制御できる |
| 設定管理 | Lua直接管理 | `config/nvim/`にLua設定、mkOutOfStoreSymlink |
| プラグインマネージャー | lazy.nvim | 現在の主流、高速、設定がシンプル |
| リーダーキー | Space | 押しやすく、which-keyと相性良い |

### エディタ設定

| Item | Decision | Reason |
|------|----------|--------|
| タブ幅 | 2スペース | コンパクト、Web系・Lua・Nixに合う |
| 行番号 | 相対行番号 | 5j, 10kなどの移動が楽 |
| カーソル行 | ハイライト有効 | 現在位置がわかりやすい |
| マウス | 有効 | 初心者に優しい |
| スクロール | スムーズ | 見た目が良い |
| クリップボード | システム (+) | 他アプリとコピペ共有 |
| バックアップ | 無効 | ディレクトリをクリーンに |
| スワップ | 無効 | .swpファイル不要 |
| Undo永続化 | 有効 | ファイルを閉じてもundo可能 |

### UI設定

| Item | Decision | Reason |
|------|----------|--------|
| カラースキーム | Catppuccin Mocha | 他ツールと統一 |
| キーマップ表示 | which-key.nvim | 初心者向け |
| ステータスライン | lualine.nvim | 軽量でカスタマイズしやすい |
| タブバー | bufferline.nvim | ブラウザ風タブ体験 |
| スタートページ | alpha-nvim | ダッシュボード表示 |
| ファイルツリー | neo-tree.nvim (左サイドバー) | VSCode風の配置 |
| ターミナル | toggleterm.nvim (フローティング) | エディタと分離 |

### LSP設定

| Item | Decision | Reason |
|------|----------|--------|
| 対応言語 | 全部入り | Web, システム, スクリプト系すべて |
| Nix LSP | nixd | 新しく機能豊富、Flakes対応 |
| LSP管理 | Nix (system) | 宣言的、Mason不使用 |
| 補完エンジン | blink.cmp | Rust製で高速、設定シンプル |
| スニペット | friendly-snippets | 各言語のスニペット集 |
| フォーマッター | conform.nvim | 保存時自動実行 |
| リンター | nvim-lint | conform.nvimと組み合わせ |
| 診断表示 | 仮想テキスト | エラー行末尾に薄く表示 |
| フォーマット失敗 | 警告表示 | ユーザーに通知 |

### キーバインド設定

| Item | Decision | Reason |
|------|----------|--------|
| ウィンドウ移動 | Ctrl+hjkl | ホームポジションから楽 |
| バッファ切り替え | Tab/S-Tab | ブラウザ風 |
| ESC代替 | jk (Insert mode) | ホームポジションから即座に戻れる |

### その他

| Item | Decision | Reason |
|------|----------|--------|
| Git統合 | フル (gitsigns + lazygit) | 効率的なワークフロー |
| セッション | auto-session | 自動保存・復元 |
| コメント | Comment.nvim | gcc/gcでトグル |
| ハイライト | Treesitter | 高精度な構文ハイライト |
| 起動速度 | 重視 (遅延読み込み) | lazy.nvimで最適化 |

### 不採用項目

| Item | Reason |
|------|--------|
| AI補完 | 不要 |
| インデントガイド | シンプルに保つ |
| デバッグ(DAP) | 外部ツールで対応 |
| Mason | Nixで管理するため不要 |

---

## Plugin List

### Core
- **lazy.nvim** - プラグインマネージャー

### LSP & Completion
- **nvim-lspconfig** - LSP設定
- **blink.cmp** - 補完エンジン
- **friendly-snippets** - スニペット集
- **conform.nvim** - フォーマッター
- **nvim-lint** - リンター

### Editor
- **nvim-treesitter** - 構文ハイライト
- **Comment.nvim** - コメントトグル
- **which-key.nvim** - キーマップヘルプ
- **auto-session** - セッション管理
- **toggleterm.nvim** - ターミナル統合

### Navigation
- **fzf-lua** - ファジーファインダー
- **neo-tree.nvim** - ファイルツリー

### UI
- **catppuccin/nvim** - カラースキーム
- **lualine.nvim** - ステータスライン
- **bufferline.nvim** - バッファタブ
- **alpha-nvim** - スタートページ

### Git
- **gitsigns.nvim** - 差分マーカー、blame
- **lazygit.nvim** - lazygit統合

### Dependencies
- **nvim-web-devicons** - アイコン
- **plenary.nvim** - 共通ライブラリ
- **nui.nvim** - UI コンポーネント

---

## Nix Packages Required

```nix
# home/default.nix の home.packages に追加

# Editor
neovim

# Git
lazygit

# LSP Servers
nodePackages.typescript-language-server  # TypeScript/JavaScript
nodePackages.vscode-langservers-extracted  # HTML, CSS, JSON
nodePackages.eslint  # ESLint
pyright  # Python
rust-analyzer  # Rust
gopls  # Go
lua-language-server  # Lua
nixd  # Nix
tailwindcss-language-server  # Tailwind CSS

# Formatters
prettierd  # JS/TS/HTML/CSS/JSON
black  # Python
rustfmt  # Rust (usually comes with rust)
gofumpt  # Go
stylua  # Lua
nixfmt-rfc-style  # Nix

# Linters (optional, some via LSP)
eslint_d  # ESLint daemon
ruff  # Python linter

# Tools
fzf  # fzf-lua dependency
ripgrep  # grep for fzf-lua
fd  # find for fzf-lua
```

---

## Directory Structure

```
config/nvim/
├── init.lua                    # エントリポイント
├── lazy-lock.json              # プラグインバージョンロック
└── lua/
    ├── config/
    │   ├── lazy.lua            # lazy.nvim bootstrap
    │   ├── options.lua         # Vim options
    │   ├── keymaps.lua         # グローバルキーマップ
    │   └── autocmds.lua        # 自動コマンド
    └── plugins/
        ├── colorscheme.lua     # catppuccin
        ├── lsp.lua             # lspconfig (Mason不使用)
        ├── completion.lua      # blink.cmp + snippets
        ├── format.lua          # conform + nvim-lint
        ├── treesitter.lua      # treesitter
        ├── editor.lua          # comment, which-key, auto-session
        ├── navigation.lua      # fzf-lua, neo-tree
        ├── ui.lua              # lualine, bufferline, alpha
        ├── git.lua             # gitsigns, lazygit
        └── terminal.lua        # toggleterm
```

---

## Options Specification

```lua
-- lua/config/options.lua

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Tabs & Indentation
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Appearance
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- Behavior
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.wrap = false

-- Files
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("data") .. "/undo"

-- Performance
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Smooth scroll (Neovim 0.10+)
vim.opt.smoothscroll = true
```

---

## Key Mappings Specification

```lua
-- lua/config/keymaps.lua

local map = vim.keymap.set

-- Leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ESC alternative
map("i", "jk", "<ESC>", { desc = "Exit insert mode" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Buffer navigation
map("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Clear search highlight
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Save
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
```

### Plugin Keymaps

| Key | Action | Plugin |
|-----|--------|--------|
| `<leader>ff` | Find files | fzf-lua |
| `<leader>fg` | Live grep | fzf-lua |
| `<leader>fb` | Buffers | fzf-lua |
| `<leader>fr` | Recent files | fzf-lua |
| `<leader>fh` | Help tags | fzf-lua |
| `<leader>e` | Toggle file tree | neo-tree |
| `<leader>gg` | Open Lazygit | lazygit.nvim |
| `<leader>gd` | Diff this | gitsigns |
| `<leader>gb` | Blame line | gitsigns |
| `<leader>gp` | Preview hunk | gitsigns |
| `<leader>lr` | Rename symbol | LSP |
| `<leader>la` | Code action | LSP |
| `<leader>ld` | Diagnostics list | LSP |
| `<leader>lf` | Format file | conform |
| `gd` | Go to definition | LSP |
| `gr` | Go to references | LSP |
| `gi` | Go to implementation | LSP |
| `K` | Hover documentation | LSP |
| `gcc` | Toggle line comment | Comment.nvim |
| `gc` | Toggle comment (visual) | Comment.nvim |
| `<C-\>` | Toggle terminal | toggleterm |

---

## Home Manager Integration

```nix
# home/default.nix

{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Editor
    neovim

    # Git
    lazygit

    # LSP Servers
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    pyright
    rust-analyzer
    gopls
    lua-language-server
    nixd
    tailwindcss-language-server

    # Formatters
    prettierd
    black
    gofumpt
    stylua
    nixfmt-rfc-style

    # Linters
    eslint_d

    # Tools for fzf-lua
    fzf
    ripgrep
    fd
  ];

  # Neovim config symlink
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/ghq/github.com/ryo-morimoto/dotfiles/config/nvim";
}
```

---

## Implementation Steps

### Phase 1: Foundation
1. `config/nvim/` ディレクトリ構造を作成
2. `init.lua` - エントリポイント
3. `lua/config/lazy.lua` - lazy.nvim bootstrap
4. `lua/config/options.lua` - 基本設定
5. `lua/config/keymaps.lua` - 基本キーマップ

### Phase 2: Visual
6. `lua/plugins/colorscheme.lua` - Catppuccin
7. `lua/plugins/treesitter.lua` - 構文ハイライト
8. `lua/plugins/ui.lua` - lualine, bufferline, alpha

### Phase 3: Development
9. `lua/plugins/lsp.lua` - LSP設定 (Nixでインストール済みサーバー使用)
10. `lua/plugins/completion.lua` - blink.cmp + snippets
11. `lua/plugins/format.lua` - conform + nvim-lint

### Phase 4: Navigation & Tools
12. `lua/plugins/navigation.lua` - fzf-lua, neo-tree
13. `lua/plugins/git.lua` - gitsigns, lazygit
14. `lua/plugins/terminal.lua` - toggleterm
15. `lua/plugins/editor.lua` - comment, which-key, auto-session

### Phase 5: Integration
16. `home/default.nix` を更新 (パッケージ追加、symlink設定)
17. `sudo nixos-rebuild switch --flake .#ryobox`
18. 動作確認・調整

---

## Testing Checklist

- [ ] Neovimが正常に起動する
- [ ] Catppuccin Mochaテーマが適用される
- [ ] which-keyでキーマップが表示される
- [ ] fzf-luaでファイル検索ができる
- [ ] neo-treeでファイルツリーが開く
- [ ] 各言語でLSP補完が動作する
  - [ ] TypeScript
  - [ ] Python
  - [ ] Rust
  - [ ] Go
  - [ ] Lua
  - [ ] Nix
- [ ] 保存時に自動フォーマットされる
- [ ] gitsignsで差分が表示される
- [ ] lazygitが起動する
- [ ] toggletermでターミナルが開く
- [ ] セッションが保存・復元される
