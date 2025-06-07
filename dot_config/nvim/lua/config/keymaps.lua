-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

-- AI協創ワークフロー
keymap("n", "<leader>ai", "", { desc = "+AI Tools" })

-- avante.nvim
keymap("n", "<leader>aia", ":AvanteAsk<CR>", { desc = "Avante Ask" })
keymap("n", "<leader>ait", ":AvanteToggle<CR>", { desc = "Avante Toggle" })
keymap("v", "<leader>aie", ":AvanteEdit<CR>", { desc = "Avante Edit" })

-- Claude Code
keymap("n", "<leader>cc", ":ClaudeCode<CR>", { desc = "Claude Code" })
keymap("n", "<leader>cb", ":ClaudeCodeBuffer<CR>", { desc = "Claude Code Buffer" })
keymap("n", "<leader>cp", ":ClaudeCodeProject<CR>", { desc = "Claude Code Project" })

-- MCP Hub
keymap("n", "<leader>cm", ":McpHub<CR>", { desc = "MCP Hub" })
keymap("n", "<leader>cn", ":McpHubNewChat<CR>", { desc = "MCP New Chat" })

-- ワークフロー統合コマンド
keymap("n", "<leader>aw", function()
  -- 1. avante.nvimでコード分析
  vim.cmd("AvanteAsk")
  -- 2. MCPで外部データ取得
  vim.schedule(function()
    vim.cmd("McpHub")
  end)
  -- 3. Claude Codeで実装
  vim.schedule(function()
    vim.cmd("ClaudeCodeProject")
  end)
end, { desc = "AI Workflow" })
