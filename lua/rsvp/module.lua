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

  vim.api.nvim_set_option_value("readonly", true, { buf = buf })

  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
  return buf
end

local function print_words(buf, words, config)
  local current_word = 1
  local delay = 60000 / config.wpm
  local timer = vim.loop.new_timer()

  timer:start(
    0,
    delay,
    vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(buf) or current_word > #words then
        timer:stop()
        timer:close()
        return
      end

      local word = words[current_word]
      local display_lines = {}
      local y_padding = math.floor((config.height - 1) / 2)
      for _ = 1, y_padding do
        table.insert(display_lines, "")
      end
      local x_padding = math.floor((config.width - #word) / 2)
      local rsvp_line = string.rep(" ", x_padding) .. word
      table.insert(display_lines, rsvp_line)

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)

      current_word = current_word + 1
    end)
  )
end

M.start_rsvp = function(config)
  local words = get_words_from_buffer()
  if #words == 0 then -- TODO: Vim notify the user
    vim.notify("Can't rsvp on empty buffer")
    return
  end

  local buf = create_floating_window(config)

  print_words(buf, words, config)
end

return M
