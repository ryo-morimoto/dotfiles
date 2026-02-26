local function tmux_socket_name()
  local tmux = vim.env.TMUX
  if not tmux or tmux == "" then
    return "default"
  end

  local parts = vim.split(tmux, ",", { plain = true })
  if #parts == 0 or parts[1] == "" then
    return "default"
  end

  return parts[1]
end

local function set_slime_target(pane_id)
  local cfg = {
    socket_name = tmux_socket_name(),
    target_pane = pane_id,
  }

  vim.g.slime_target = "tmux"
  vim.g.slime_default_config = cfg
  vim.g.slime_dont_ask_default = 1
  vim.g.slime_bracketed_paste = 1
  vim.b.slime_config = cfg
end

local function list_agent_panes()
  local format = table.concat({
    "#{pane_id}",
    "#{window_name}",
    "#{pane_current_command}",
    "#{@git_wt_branch}",
    "#{pane_current_path}",
  }, "\t")

  local lines = vim.fn.systemlist({ "tmux", "list-panes", "-a", "-F", format })
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local panes = {}
  for _, line in ipairs(lines) do
    local parts = vim.split(line, "\t", { plain = true })
    local pane_id = parts[1] or ""
    local window_name = parts[2] or ""
    local command = parts[3] or ""
    local branch = parts[4] or ""
    local path = parts[5] or ""

    local is_agent = command == "claude" or command == "opencode" or command == "codex"
    if pane_id ~= "" and (is_agent or branch ~= "") then
      local label =
        string.format("%s  %s  [%s]  %s", pane_id, window_name, command, branch ~= "" and branch or path)
      table.insert(panes, {
        pane_id = pane_id,
        label = label,
      })
    end
  end

  return panes
end

local function attach_agent_pane()
  local panes = list_agent_panes()
  if not panes then
    vim.notify("tmux pane list failed", vim.log.levels.ERROR)
    return
  end

  if #panes == 0 then
    vim.notify("No agent pane found. Start one via `wtc`/`wto`/`wtx`.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(panes, {
    prompt = "Attach agent pane:",
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if not item then
      return
    end

    set_slime_target(item.pane_id)
    vim.notify("Agent pane attached: " .. item.pane_id, vim.log.levels.INFO)
  end)
end

local function send_prompt_input()
  vim.ui.input({ prompt = "Agent prompt> " }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end

    local ok, err = pcall(function()
      vim.fn["slime#send"](input .. "\r")
    end)
    if not ok then
      vim.notify("Prompt send failed: " .. tostring(err), vim.log.levels.ERROR)
    end
  end)
end

return {
  {
    "jpalardy/vim-slime",
    event = "VeryLazy",
    init = function()
      vim.g.slime_no_mappings = 1
      vim.g.slime_target = "tmux"
      vim.g.slime_bracketed_paste = 1
      vim.g.slime_dont_ask_default = 1
      vim.g.slime_default_config = {
        socket_name = tmux_socket_name(),
        target_pane = "{last}",
      }
    end,
    keys = {
      { "<leader>aa", attach_agent_pane, desc = "Agent attach pane" },
      { "<leader>ap", send_prompt_input, desc = "Agent prompt input" },
      { "<leader>ac", "<cmd>SlimeConfig<cr>", desc = "Agent config" },
      { "<leader>al", "<Plug>SlimeLineSend", mode = "n", remap = true, desc = "Agent send line" },
      { "<leader>as", "<Plug>SlimeParagraphSend", mode = "n", remap = true, desc = "Agent send paragraph" },
      { "<leader>as", "<Plug>SlimeRegionSend", mode = "x", remap = true, desc = "Agent send selection" },
    },
  },
}
