return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    local lspconfig = require("lspconfig")
    local cmp_nvim_lsp = require("cmp_nvim_lsp")

    -- Diagnostic config
    vim.diagnostic.config({
      virtual_text = {
        prefix = "●",
        spacing = 4,
      },
      signs = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = {
        border = "rounded",
        source = "always",
      },
    })

    -- Diagnostic signs
    local signs = { Error = " ", Warn = " ", Hint = "󰌵 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
    end

    -- LSP keymaps (set on attach)
    local on_attach = function(client, bufnr)
      local map = function(keys, func, desc)
        vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
      end

      map("gd", vim.lsp.buf.definition, "Go to definition")
      map("gD", vim.lsp.buf.declaration, "Go to declaration")
      map("gr", vim.lsp.buf.references, "Go to references")
      map("gi", vim.lsp.buf.implementation, "Go to implementation")
      map("K", vim.lsp.buf.hover, "Hover documentation")
      map("<leader>lr", vim.lsp.buf.rename, "Rename symbol")
      map("<leader>la", vim.lsp.buf.code_action, "Code action")
      map("<leader>ld", "<cmd>FzfLua diagnostics_document<cr>", "Document diagnostics")
      map("<leader>lD", "<cmd>FzfLua diagnostics_workspace<cr>", "Workspace diagnostics")
      map("<leader>ls", "<cmd>FzfLua lsp_document_symbols<cr>", "Document symbols")
      map("<leader>lS", "<cmd>FzfLua lsp_workspace_symbols<cr>", "Workspace symbols")

      -- Inlay hints (Neovim 0.10+)
      if client.supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end
    end

    -- Capabilities (for completion)
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- LSP servers configuration (installed via Nix)
    local servers = {
      -- TypeScript/JavaScript
      ts_ls = {},

      -- HTML/CSS/JSON (from vscode-langservers-extracted)
      html = {},
      cssls = {},
      jsonls = {},

      -- Python
      pyright = {},

      -- Rust
      rust_analyzer = {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = {
              command = "clippy",
            },
          },
        },
      },

      -- Go
      gopls = {
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
            },
            staticcheck = true,
          },
        },
      },

      -- Lua
      lua_ls = {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              library = vim.api.nvim_get_runtime_file("", true),
            },
            diagnostics = {
              globals = { "vim" },
            },
            telemetry = { enable = false },
          },
        },
      },

      -- Nix
      nixd = {
        settings = {
          nixd = {
            nixpkgs = {
              expr = "import <nixpkgs> { }",
            },
            formatting = {
              command = { "nixfmt" },
            },
          },
        },
      },

      -- Tailwind CSS
      tailwindcss = {},
    }

    -- Setup all servers
    for server, config in pairs(servers) do
      config.on_attach = on_attach
      config.capabilities = capabilities
      lspconfig[server].setup(config)
    end
  end,
}
