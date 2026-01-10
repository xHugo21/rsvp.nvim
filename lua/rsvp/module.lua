---@class CustomModule
local M = {}

local get_words_from_buffer = function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local words = {}
  for _, line in ipairs(lines) do
    for word in line:gmatch("%S+") do
      table.insert(words, word)
    end
  end
  return words
end

local create_floating_window = function(config)
  local buf = vim.api.nvim_create_buf(false, true)
  local ui = vim.api.nvim_list_uis()[1]

  local win_opts = {
    relative = "editor",
    width = config.width,
    height = config.height,
    row = math.floor((ui.height - config.height) / 2),
    col = math.floor((ui.width - config.width) / 2),
    style = "minimal",
    border = config.border,
  }
  vim.api.nvim_open_win(buf, true, win_opts)

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })

  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
end

M.open_rsvp_window = function(config)
  local words = get_words_from_buffer()
  if #words == 0 then -- TODO: Maybe vim notify the user
    return
  end

  create_floating_window(config)
end

return M
