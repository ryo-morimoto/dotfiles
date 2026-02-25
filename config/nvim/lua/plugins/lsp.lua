return {
  "hrsh7th/cmp-nvim-lsp",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
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

    -- LSP keymaps (set on LspAttach)
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
      callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        local bufnr = ev.buf

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
        if client and client.supports_method("textDocument/inlayHint") then
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end
      end,
    })

    -- Capabilities (for completion)
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- Default config for all LSP servers
    vim.lsp.config("*", {
      capabilities = capabilities,
    })

    -- LSP servers configuration (installed via Nix)
    vim.lsp.config("ts_ls", {})

    vim.lsp.config("html", {})

    vim.lsp.config("cssls", {})

    vim.lsp.config("jsonls", {})

    vim.lsp.config("pyright", {})

    vim.lsp.config("rust_analyzer", {
      settings = {
        ["rust-analyzer"] = {
          checkOnSave = {
            command = "clippy",
          },
        },
      },
    })

    vim.lsp.config("gopls", {
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
          },
          staticcheck = true,
        },
      },
    })

    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          workspace = {
            checkThirdParty = false,
            library = vim.api.nvim_get_runtime_file("", true),
          },
          diagnostics = {
            globals = { "vim", "api", "fn", "cmd", "loop", "uv" },
          },
          telemetry = { enable = false },
        },
      },
    })

    vim.lsp.config("nixd", {
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
    })

    vim.lsp.config("moonbit-lsp", {
      cmd = { "moonbit-lsp" },
      filetypes = { "moonbit" },
      root_markers = {
        "moon.mod.json",
        ".git",
      },
    })

    vim.lsp.config("tailwindcss", {})

    -- Enable all configured servers
    vim.lsp.enable({
      "ts_ls",
      "html",
      "cssls",
      "jsonls",
      "pyright",
      "rust_analyzer",
      "gopls",
      "lua_ls",
      "nixd",
      "moonbit-lsp",
      "tailwindcss",
    })
  end,
}
