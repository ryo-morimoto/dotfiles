return {
  {
    "vim-jp/vimdoc-ja",
    event = { "CmdlineEnter", "VeryLazy" },
    config = function()
      -- 日本語ヘルプを最優先に設定
      vim.opt.helplang = "ja"
      -- 日本語がない場合は英語にフォールバック
      -- vim.opt.helplang = "ja,en"
    end,
  },
}
