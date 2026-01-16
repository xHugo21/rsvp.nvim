local M = {}

M.HL_GROUPS = {
  ORP = "RsvpORP",
  HELP = "RsvpBold",
  PLAYING = "RsvpPlaying",
  PROGRESS = "RsvpProgress",
}

local function setup_highlights()
  vim.api.nvim_set_hl(0, M.HL_GROUPS.HELP, { link = "@keyword", default = true })
  vim.api.nvim_set_hl(0, M.HL_GROUPS.PLAYING, { link = "@keyword", bold = true, default = true })
  vim.api.nvim_set_hl(0, M.HL_GROUPS.PROGRESS, { link = "@keyword", default = true })
  if vim.fn.hlexists(M.HL_GROUPS.ORP) == 0 then
    vim.api.nvim_set_hl(0, M.HL_GROUPS.ORP, { link = "@keyword", bold = true, default = true })
  end
end

---@param config table
---@return number buffer, number window
M.create_window = function(config)
  setup_highlights()
  local buf = vim.api.nvim_create_buf(false, true)
  local ui_list = vim.api.nvim_list_uis()
  local ui = #ui_list > 0 and ui_list[1] or config

  local win_opts = {
    relative = "editor",
    width = config.width,
    height = config.height,
    row = math.floor((ui.height - config.height) / 2),
    col = math.floor((ui.width - config.width) / 2),
    style = "minimal",
    border = config.border,
  }
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  return buf, win
end

---@param parent_win number
---@param config table
M.show_help_popup = function(parent_win, config)
  local help_text = {
    " RSVP.nvim Keybindings",
    " ─────────────────────",
    " <Space> : Play / Pause",
    " j       : Decrease WPM (-50)",
    " k       : Increase WPM (+50)",
    " p       : Toggle Progress Bar",
    " r       : Reset to start",
    " q       : Close RSVP",
    " ?       : Show this help",
    " ─────────────────────",
    " Press any key to close",
  }

  local width = 30
  local height = #help_text

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_text)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local win_opts = {
    relative = "win",
    win = parent_win,
    width = width,
    height = height,
    row = math.floor((config.height - height) / 2),
    col = math.floor((config.width - width) / 2),
    style = "minimal",
    border = config.border,
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  local close_keys = { "q", "<Esc>", "<CR>", "<Space>", "?" }
  for _, key in ipairs(close_keys) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, silent = true })
  end

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
    once = true,
  })
end

---@param data table
M.render = function(data)
  if not data.buf or not vim.api.nvim_buf_is_valid(data.buf) then
    return
  end

  local utils = require("rsvp.utils")
  local width = data.config.width
  local height = data.config.height
  local word = data.word
  local word_len = #word

  local orp_index = utils.calculate_orp(word_len)
  local display_lines = {}

  local status = data.running and "PLAYING" or "PAUSED"
  local progress_text = string.format("%d/%d", data.current_word, data.total_words)
  local status_text = string.format("[%s] WPM: %d", status, data.wpm)
  local status_padding = width - #status_text - #progress_text
  if status_padding < 0 then
    status_padding = 0
  end
  table.insert(display_lines, progress_text .. string.rep(" ", status_padding) .. status_text)

  local y_padding = math.floor((height - (data.show_progress and 6 or 5)) / 2)
  for _ = 1, y_padding do
    table.insert(display_lines, "")
  end

  local pivot_col = math.floor(width / 2)
  local left_len = 6
  local right_len = 7
  local guide_padding = pivot_col - left_len
  if guide_padding < 0 then
    guide_padding = 0
  end

  table.insert(
    display_lines,
    string.rep(" ", guide_padding) .. string.rep("─", left_len) .. "┬" .. string.rep("─", right_len)
  )

  local x_padding = pivot_col - orp_index + 1
  if x_padding < 0 then
    x_padding = 0
  end
  table.insert(display_lines, string.rep(" ", x_padding) .. word)
  local word_line_index = #display_lines - 1

  table.insert(
    display_lines,
    string.rep(" ", guide_padding) .. string.rep("─", left_len) .. "┴" .. string.rep("─", right_len)
  )

  local bottom_fixed_lines = data.show_progress and 2 or 1
  local remaining = height - #display_lines - bottom_fixed_lines
  for _ = 1, remaining do
    table.insert(display_lines, "")
  end

  local filled_len = 0
  local progress_bar_line_idx = -1
  local progress_bar_filled_start = 0

  if data.show_progress then
    local bar_width = width - 2
    local bar
    bar, filled_len = utils.build_progress_bar(bar_width, data.current_word, data.total_words)
    local bar_padding = math.floor((width - bar_width) / 2)
    table.insert(display_lines, string.rep(" ", bar_padding) .. bar)
    progress_bar_line_idx = #display_lines - 1
    progress_bar_filled_start = bar_padding
  end

  local play_pause_label = data.running and "Pause" or "Play"
  local help = string.format("<Space>: %s | q: Quit | ?: Help", play_pause_label)
  local help_padding = math.floor((width - #help) / 2)
  table.insert(display_lines, string.rep(" ", math.max(0, help_padding)) .. help)

  vim.api.nvim_set_option_value("modifiable", true, { buf = data.buf })
  vim.api.nvim_buf_set_lines(data.buf, 0, -1, false, display_lines)
  vim.api.nvim_buf_clear_namespace(data.buf, data.ns, 0, -1)

  -- Highlights
  local status_line = display_lines[1]
  if data.running then
    local s, e = status_line:find("PLAYING", 1, true)
    if s then
      vim.api.nvim_buf_set_extmark(data.buf, data.ns, 0, s - 1, { end_col = e, hl_group = M.HL_GROUPS.PLAYING })
    end
  end
  local s_wpm, e_wpm = status_line:find("WPM", 1, true)
  if s_wpm then
    vim.api.nvim_buf_set_extmark(data.buf, data.ns, 0, s_wpm - 1, { end_col = e_wpm, hl_group = M.HL_GROUPS.HELP })
  end

  if filled_len > 0 then
    vim.api.nvim_buf_set_extmark(data.buf, data.ns, progress_bar_line_idx, progress_bar_filled_start, {
      end_col = progress_bar_filled_start + (filled_len * 3),
      hl_group = M.HL_GROUPS.PROGRESS,
    })
  end

  local help_line_idx = #display_lines - 1
  local help_line = display_lines[#display_lines]
  for _, key in ipairs({ "<Space>", "q", "?" }) do
    local s, e = help_line:find(key, 1, true)
    if s then
      vim.api.nvim_buf_set_extmark(
        data.buf,
        data.ns,
        help_line_idx,
        s - 1,
        { end_col = e, hl_group = M.HL_GROUPS.HELP }
      )
    end
  end

  if word_len > 0 then
    local orp_col = x_padding + orp_index - 1
    vim.api.nvim_buf_set_extmark(data.buf, data.ns, word_line_index, orp_col, {
      end_col = orp_col + 1,
      hl_group = M.HL_GROUPS.ORP,
    })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = data.buf })
end

return M
