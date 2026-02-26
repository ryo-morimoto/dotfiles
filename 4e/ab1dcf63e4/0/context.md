# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Markdown 編集体験改善計画

## Context

Neovim での Markdown 編集・レビュー体験を向上させる。現状は conform.nvim + prettierd/prettier での保存時フォーマットと markdown-preview.nvim のみ。リスト継続・連番振り直し・テーブル整形・wrap 制御が不足している。

## 変更内容

### 1. oxfmt パッケージ追加 + prettierd 置換

**`home/default.nix`**
- `prettierd` → `oxfmt` に置換（Formatt...

### Prompt 2

commit this

