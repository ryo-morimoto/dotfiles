return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec" },
  keys = {
    { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Float terminal" },
    { "<leader>th", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "Horizontal terminal" },
    { "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", desc = "Vertical terminal" },
  },
  opts = {
    size = function(term)
      if term.direction == "horizontal" then
        return 15
      elseif term.direction == "vertical" then
        return vim.o.columns * 0.4
      end
    end,
    open_mapping = [[<C-\>]],
    hide_numbers = true,
    shade_filetypes = {},
    shade_terminals = true,
    shading_factor = 2,
    start_in_insert = true,
    insert_mappings = true,
    terminal_mappings = true,
    persist_size = true,
    persist_mode = true,
    direction = "float",
    close_on_exit = true,
    shell = vim.o.shell,
    float_opts = {
      border = "curved",
      winblend = 0,
    },
    winbar = {
      enabled = false,
    },
  },
  config = function(_, opts)
    require("toggleterm").setup(opts)

    -- Terminal mode keymaps
    function _G.set_terminal_keymaps()
      local topts = { buffer = 0 }
      vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], topts)
      vim.keymap.set("t", "jk", [[<C-\><C-n>]], topts)
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], topts)
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], topts)
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], topts)
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], topts)
    end

    vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
  end,
}
