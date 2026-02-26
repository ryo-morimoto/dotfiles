return {
  -- Formatter
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>lf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        javascript = { "oxfmt" },
        typescript = { "oxfmt" },
        javascriptreact = { "oxfmt" },
        typescriptreact = { "oxfmt" },
        css = { "oxfmt" },
        html = { "oxfmt" },
        json = { "oxfmt" },
        yaml = { "oxfmt" },
        markdown = { "oxfmt" },
        python = { "black" },
        go = { "gofumpt" },
        lua = { "stylua" },
        nix = { "nixfmt" },
        rust = { "rustfmt" },
        moonbit = { "moonfmt" },
      },
      format_on_save = function(bufnr)
        -- Disable for certain filetypes
        local ignore_filetypes = { "sql", "java" }
        if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
          return
        end
        return {
          timeout_ms = 500,
          lsp_fallback = true,
        }
      end,
      notify_on_error = true,
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
  },

  -- Linter
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        python = { "ruff" },
      }

      -- Auto lint on save and insert leave
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
        callback = function()
          -- Only lint if the linter is available
          local ft = vim.bo.filetype
          local linters = lint.linters_by_ft[ft] or {}
          for _, linter in ipairs(linters) do
            if vim.fn.executable(linter) == 1 then
              lint.try_lint()
              return
            end
          end
        end,
      })
    end,
  },
}
