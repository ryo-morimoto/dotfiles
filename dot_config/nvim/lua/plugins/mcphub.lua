-- ~/.config/nvim/lua/plugins/mcphub.lua
return {
  "ravitemer/mcphub.nvim",
  lazy = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "stevearc/dressing.nvim",
  },
  opts = {
    mcp = {
      servers = {
        filesystem = {
          command = "npx",
          args = { "@modelcontextprotocol/server-filesystem", "/path/to/your/project" },
          env = {},
        },
        brave_search = {
          command = "npx",
          args = { "@modelcontextprotocol/server-brave-search" },
          env = {
            BRAVE_API_KEY = os.getenv("BRAVE_API_KEY"),
          },
        },
        postgres = {
          command = "npx",
          args = { "@modelcontextprotocol/server-postgres" },
          env = {
            POSTGRES_CONNECTION_STRING = os.getenv("POSTGRES_CONNECTION_STRING"),
          },
        },
        github = {
          command = "npx",
          args = { "@modelcontextprotocol/server-github" },
          env = {
            GITHUB_PERSONAL_ACCESS_TOKEN = os.getenv("GITHUB_PERSONAL_ACCESS_TOKEN"),
          },
        },
      },
    },
    claude = {
      api_key = os.getenv("ANTHROPIC_API_KEY"),
      model = "claude-3-5-sonnet-20241022",
      max_tokens = 8192,
      temperature = 0.1,
    },
    ui = {
      width = 80,
      height = 24,
      border = "rounded",
    },
    keymaps = {
      toggle = "<leader>cm",
      send = "<CR>",
      new_chat = "<leader>cn",
      select_server = "<leader>cs",
      attach_file = "<leader>cf",
    },
  },
  config = function(_, opts)
    require("mcphub").setup(opts)

    -- Custom keymaps
    vim.keymap.set("n", "<leader>cm", ":McpHub<CR>", { desc = "Open McpHub" })
    vim.keymap.set("n", "<leader>cn", ":McpHubNewChat<CR>", { desc = "New MCP Chat" })
    vim.keymap.set("n", "<leader>cs", ":McpHubSelectServer<CR>", { desc = "Select MCP Server" })
  end,
}
