---@class CustomModule
local M = {}

M.my_first_function = function(user_opts, config)
  -- Create a new unlisted, scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local ui = vim.api.nvim_list_uis()[1]
  local width, height = 60, 20
  local border = (user_opts and user_opts.border)
    or (config and config.winborder)
    or (vim.opt.winborder and vim.opt.winborder:get())
    or "solid"
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = border,
  }
  vim.api.nvim_open_win(buf, true, opts)
end

return M
