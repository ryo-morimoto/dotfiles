# Fix Lua "Undefined global `vim`" Diagnostics

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Neovim外部のLua Language Server（エディタ、CI等）で `vim` グローバル未定義の警告を解消する

**Architecture:** `config/nvim/.luarc.json` を追加し、lua_lsがNeovim外から実行されても `vim` グローバルとNeovimランタイムライブラリを認識できるようにする。既存の `lsp.lua` 内のlua_ls設定はNeovim内部用としてそのまま維持する。

**Tech Stack:** Lua Language Server, `.luarc.json`

---

### Task 1: `.luarc.json` を追加

**Files:**
- Create: `config/nvim/.luarc.json`

**Step 1: `.luarc.json` を作成**

```json
{
  "runtime.version": "LuaJIT",
  "diagnostics.globals": ["vim"],
  "workspace.checkThirdParty": false
}
```

設計判断:
- `workspace.library` にNeovimランタイムパスを指定しない。パスは環境依存（NixOS等）のため、ポータブルにならない。`globals: ["vim"]` で警告は解消される
- `checkThirdParty: false` はlsp.lua側の設定と一致させる
- `runtime.version: "LuaJIT"` はNeovimが使用するLuaランタイムに合わせる

**Step 2: 診断が消えることを確認**

エディタで `config/nvim/lua/config/options.lua` を開き、`vim` に対する `undefined-global` 警告が消えていることを確認する。

**Step 3: コミット**

```bash
git add config/nvim/.luarc.json
git commit -m "chore: add .luarc.json to suppress vim undefined-global warnings"
```
