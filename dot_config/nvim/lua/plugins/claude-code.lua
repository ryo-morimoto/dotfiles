-- ~/.config/nvim/lua/plugins/claude-code.lua
return {
  "greggh/claude-code.nvim",
  cmd = { "ClaudeCode", "ClaudeCodeBuffer", "ClaudeCodeProject" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  opts = {
    api_key = os.getenv("ANTHROPIC_API_KEY"),
    model = "claude-3-5-sonnet-20241022",
    max_tokens = 8192,
    temperature = 0.1,
    auto_save = true,
    context = {
      include_git = true,
      include_buffer = true,
      include_project = true,
      max_files = 50,
    },
    keymaps = {
      ask = "<leader>ca",
      ask_buffer = "<leader>cb",
      ask_project = "<leader>cp",
      ask_selection = "<leader>cs",
      apply_suggestion = "<leader>cy",
      toggle_chat = "<leader>ct",
    },
    ui = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
      title = " Claude Code ",
    },
    log_level = "info",
  },
  config = function(_, opts)
    require("claude-code").setup(opts)

    -- Additional keymaps for seamless integration
    vim.keymap.set("n", "<leader>ca", ":ClaudeCode<CR>", { desc = "Ask Claude" })
    vim.keymap.set("n", "<leader>cb", ":ClaudeCodeBuffer<CR>", { desc = "Ask Claude about buffer" })
    vim.keymap.set("n", "<leader>cp", ":ClaudeCodeProject<CR>", { desc = "Ask Claude about project" })
    vim.keymap.set("v", "<leader>cs", ":ClaudeCodeSelection<CR>", { desc = "Ask Claude about selection" })
    vim.keymap.set("n", "<leader>cy", ":ClaudeCodeApply<CR>", { desc = "Apply Claude suggestion" })
    vim.keymap.set("n", "<leader>ct", ":ClaudeCodeToggle<CR>", { desc = "Toggle Claude chat" })
  end,
}
