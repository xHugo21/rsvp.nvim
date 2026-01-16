---@class CustomModule
local M = {}

local ORP_HL_GROUP = "RsvpORP"
local HELP_HL_GROUP = "RsvpBold"
local PLAYING_HL_GROUP = "RsvpPlaying"
local PROGRESS_HL_GROUP = "RsvpProgress"

---@class RsvpState
---@field buf number
---@field ns number Namespace for extmarks
---@field words string[]
---@field config table
---@field current_word number
---@field wpm number
---@field running boolean
---@field show_progress boolean
---@field timer uv.uv_timer_t|nil

---@type RsvpState|nil
local state = nil

---@return string[]
M.get_words_from_buffer = function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local words = {}
  for _, line in ipairs(lines) do
    for word in line:gmatch("%S+") do
      table.insert(words, word)
    end
  end
  return words
end

---@param word_len number
---@return number
M.calculate_orp = function(word_len)
  local orp_index = math.floor((word_len + 2) / 4) + 1
  if orp_index > word_len then
    orp_index = math.max(1, word_len)
  end
  return orp_index
end

---@param bar_width number
---@param current number
---@param total number
---@return string, number The progress bar string and filled char count
local function build_progress_bar(bar_width, current, total)
  local progress = math.min(1, math.max(0, (current - 1) / total))
  local filled = math.floor(progress * bar_width)
  local empty = bar_width - filled
  return string.rep("█", filled) .. string.rep("░", empty), filled
end

local function render_word(word)
  if not state or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local width = state.config.width
  local height = state.config.height
  local word_len = #word

  local orp_index = M.calculate_orp(word_len)

  local display_lines = {}

  local status = state.running and "PLAYING" or "PAUSED"
  local progress_text = string.format("%d/%d", state.current_word, #state.words)
  local status_text = string.format("[%s] WPM: %d", status, state.wpm)
  local status_padding = width - #status_text - #progress_text
  if status_padding < 0 then
    status_padding = 0
  end
  table.insert(display_lines, progress_text .. string.rep(" ", status_padding) .. status_text)

  local y_padding = math.floor((height - (state.show_progress and 6 or 5)) / 2)
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

  local top_guide = string.rep(" ", guide_padding)
    .. string.rep("─", left_len)
    .. "┬"
    .. string.rep("─", right_len)
  table.insert(display_lines, top_guide)

  local x_padding = pivot_col - orp_index + 1
  if x_padding < 0 then
    x_padding = 0
  end
  local word_line = string.rep(" ", x_padding) .. word
  table.insert(display_lines, word_line)

  local word_line_index = #display_lines - 1 -- 0-based line index for extmarks

  local bottom_guide = string.rep(" ", guide_padding)
    .. string.rep("─", left_len)
    .. "┴"
    .. string.rep("─", right_len)
  table.insert(display_lines, bottom_guide)

  -- Progress bar and Help line
  local filled_len = 0
  local progress_bar_line_idx = -1
  local progress_bar_filled_start = 0

  local bottom_fixed_lines = state.show_progress and 2 or 1
  local remaining = height - #display_lines - bottom_fixed_lines
  for _ = 1, remaining do
    table.insert(display_lines, "")
  end

  if state.show_progress then
    local bar_width = width - 2
    local bar
    bar, filled_len = build_progress_bar(bar_width, state.current_word, #state.words)
    local bar_padding = math.floor((width - bar_width) / 2)
    table.insert(display_lines, string.rep(" ", bar_padding) .. bar)
    progress_bar_line_idx = #display_lines - 1
    progress_bar_filled_start = bar_padding
  end

  local help = "<Space>: Play/Pause | j/k: WPM | p: Toggle Progress | r: Reset | q: Quit"
  local help_padding = math.floor((width - #help) / 2)
  if help_padding < 0 then
    help_padding = 0
  end
  table.insert(display_lines, string.rep(" ", help_padding) .. help)

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, display_lines)

  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)

  -- Highlight status line
  local status_line = display_lines[1]
  if state.running then
    local s, e = status_line:find("PLAYING", 1, true)
    if s then
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, 0, s - 1, {
        end_col = e,
        hl_group = PLAYING_HL_GROUP,
      })
    end
  end
  local s_wpm, e_wpm = status_line:find("WPM", 1, true)
  if s_wpm then
    vim.api.nvim_buf_set_extmark(state.buf, state.ns, 0, s_wpm - 1, {
      end_col = e_wpm,
      hl_group = HELP_HL_GROUP,
    })
  end

  -- Highlight progress bar filled portion
  if filled_len > 0 then
    vim.api.nvim_buf_set_extmark(state.buf, state.ns, progress_bar_line_idx, progress_bar_filled_start, {
      end_col = progress_bar_filled_start + (filled_len * 3), -- █ is 3 bytes
      hl_group = PROGRESS_HL_GROUP,
    })
  end

  -- Highlight help line
  local help_line_idx = #display_lines - 1
  local help_line = display_lines[#display_lines]
  local help_keys = { "<Space>", "j/k", "p", "r", "q" }
  for _, key in ipairs(help_keys) do
    local s, e = help_line:find(key, 1, true)
    if s then
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, help_line_idx, s - 1, {
        end_col = e,
        hl_group = HELP_HL_GROUP,
      })
    end
  end

  if word_len > 0 then
    local orp_col = x_padding + orp_index - 1 -- 0-based column
    vim.api.nvim_buf_set_extmark(state.buf, state.ns, word_line_index, orp_col, {
      end_col = orp_col + 1,
      hl_group = ORP_HL_GROUP,
    })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
end

local function stop_timer()
  local s = state
  if s and s.timer then
    local timer = s.timer
    if timer then
      timer:stop()
      timer:close()
    end
    s.timer = nil
  end
end

local function start_timer()
  if not state then
    return
  end

  stop_timer()

  local delay = math.floor(60000 / state.wpm)
  local timer = vim.uv.new_timer()
  if not timer then
    vim.notify("Failed to create RSVP timer", vim.log.levels.ERROR)
    return
  end

  state.timer = timer

  timer:start(
    delay,
    delay,
    vim.schedule_wrap(function()
      if not state or not vim.api.nvim_buf_is_valid(state.buf) then
        stop_timer()
        return
      end

      if state.current_word > #state.words then
        stop_timer()
        state.running = false
        render_word("[END]")
        return
      end

      render_word(state.words[state.current_word])
      state.current_word = state.current_word + 1
    end)
  )
end

local function toggle_play()
  if not state then
    return
  end

  if state.running then
    state.running = false
    stop_timer()
    render_word(state.words[math.max(1, state.current_word - 1)] or "[END]")
  else
    if state.current_word > #state.words then
      state.current_word = 1
    end
    state.running = true
    start_timer()
    render_word(state.words[state.current_word] or "[END]")
  end
end

local function toggle_progress()
  if not state then
    return
  end
  state.show_progress = not state.show_progress
  render_word(state.words[math.max(1, state.current_word - 1)] or state.words[1] or "")
end

local function adjust_wpm(delta)
  if not state then
    return
  end

  state.wpm = math.max(50, state.wpm + delta)

  if state.running then
    start_timer()
  end

  local word = state.words[math.max(1, state.current_word - 1)] or state.words[1] or ""
  render_word(word)
end

local function reset()
  if not state then
    return
  end

  stop_timer()
  state.current_word = 1
  state.running = false
  render_word(state.words[1] or "")
end

local function cleanup()
  stop_timer()
  state = nil
end

local function create_floating_window(config)
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
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Keymaps
  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", "q", function()
    cleanup()
    vim.api.nvim_win_close(win, true)
  end, opts)

  vim.keymap.set("n", "<Space>", toggle_play, opts)
  vim.keymap.set("n", "j", function()
    adjust_wpm(-50)
  end, opts)
  vim.keymap.set("n", "k", function()
    adjust_wpm(50)
  end, opts)
  vim.keymap.set("n", "p", toggle_progress, opts)
  vim.keymap.set("n", "r", reset, opts)

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = cleanup,
    once = true,
  })

  return buf
end

M.start_rsvp = function(config)
  local words = M.get_words_from_buffer()
  if #words == 0 then
    vim.notify("Can't RSVP on empty buffer", vim.log.levels.WARN)
    return
  end

  local buf = create_floating_window(config)

  local ns = vim.api.nvim_create_namespace("rsvp_orp")

  vim.api.nvim_set_hl(0, HELP_HL_GROUP, { link = "@keyword", default = true })
  vim.api.nvim_set_hl(0, PLAYING_HL_GROUP, { link = "@keyword", bold = true, default = true })
  vim.api.nvim_set_hl(0, PROGRESS_HL_GROUP, { link = "@keyword", default = true })

  if vim.fn.hlexists(ORP_HL_GROUP) == 0 then
    vim.api.nvim_set_hl(0, ORP_HL_GROUP, { link = "@keyword", bold = true, default = true })
  end

  state = {
    buf = buf,
    ns = ns,
    words = words,
    config = config,
    current_word = 1,
    wpm = config.wpm,
    running = false,
    show_progress = config.show_progress,
    timer = nil,
  }

  render_word(words[1])
end

return M
