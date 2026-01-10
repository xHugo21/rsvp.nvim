---@class CustomModule
local M = {}

M.open_floating_window = function(config)
  -- Create a new unlisted, scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local ui = vim.api.nvim_list_uis()[1]

  local opts = {
    relative = "editor",
    width = config.width,
    height = config.height,
    row = math.floor((ui.height - config.height) / 2),
    col = math.floor((ui.width - config.width) / 2),
    style = "minimal",
    border = config.border,
  }
  vim.api.nvim_open_win(buf, true, opts)

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })

  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
end

return M
