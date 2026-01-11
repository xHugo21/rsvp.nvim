---@class CustomModule
local M = {}

local ORP_HL_GROUP = "RsvpORP"

---@class RsvpState
---@field buf number
---@field ns number Namespace for extmarks
---@field words string[]
---@field config table
---@field current_word number
---@field wpm number
---@field running boolean
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
  local status_text = string.format("[%s] WPM:%d", status, state.wpm)
  local status_padding = width - #status_text
  if status_padding < 0 then
    status_padding = 0
  end
  table.insert(display_lines, string.rep(" ", status_padding) .. status_text)

  local y_padding = math.floor((height - 5) / 2)
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

  local remaining = height - #display_lines - 1
  for _ = 1, remaining do
    table.insert(display_lines, "")
  end

  local help = "<Space>:Play/Pause | j/k:WPM | r:Reset | q:Quit"
  local help_padding = math.floor((width - #help) / 2)
  if help_padding < 0 then
    help_padding = 0
  end
  table.insert(display_lines, string.rep(" ", help_padding) .. help)

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, display_lines)

  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)

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

  if vim.fn.hlexists(ORP_HL_GROUP) == 0 then
    vim.api.nvim_set_hl(0, ORP_HL_GROUP, { link = "@keyword", default = true })
  end

  state = {
    buf = buf,
    ns = ns,
    words = words,
    config = config,
    current_word = 1,
    wpm = config.wpm,
    running = false,
    timer = nil,
  }

  render_word(words[1])
end

return M
