local SYSTEM_PROMPT =
  "You are a concise Neovim/Vim expert. Answer questions about Neovim usage, motions, commands, keybindings, and configuration. Be brief and practical. Use code blocks for commands. Respond in the same language as the question."

local function open_result(text, question)
  local lines = vim.split(text, "\n")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. question .. " ",
    title_pos = "center",
  })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
end

local function ask_nvim(question)
  vim.notify("Asking Haiku...", vim.log.levels.INFO)

  local chunks = {}
  vim.fn.jobstart({
    "claude", "-p",
    "--model", "claude-haiku-4-20250414",
    "--system-prompt", SYSTEM_PROMPT,
    question,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        table.insert(chunks, line)
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("AskVim: claude exited with code " .. code, vim.log.levels.ERROR)
          return
        end
        local text = table.concat(chunks, "\n"):gsub("\n+$", "")
        if text == "" then
          vim.notify("AskVim: empty response", vim.log.levels.WARN)
          return
        end
        open_result(text, question)
      end)
    end,
  })
end

vim.api.nvim_create_user_command("AskVim", function(opts)
  ask_nvim(opts.args)
end, { nargs = "+", desc = "Ask Haiku about Neovim usage" })

vim.keymap.set("n", "<leader>nv", function()
  vim.ui.input({ prompt = "AskVim> " }, function(input)
    if input and vim.trim(input) ~= "" then
      ask_nvim(input)
    end
  end)
end, { desc = "Ask AI about Neovim" })
