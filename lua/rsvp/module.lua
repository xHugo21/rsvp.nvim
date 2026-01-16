local utils = require("rsvp.utils")
local ui = require("rsvp.ui")

---@class CustomModule
local M = {}

---@class RsvpState
---@field buf number
---@field win number
---@field ns number
---@field words string[]
---@field config table
---@field current_word number
---@field wpm number
---@field running boolean
---@field show_progress boolean
---@field timer uv.uv_timer_t|nil

---@type RsvpState|nil
local state = nil

local function render_word(word)
  if not state then
    return
  end
  ui.render({
    buf = state.buf,
    win = state.win,
    ns = state.ns,
    config = state.config,
    word = word,
    current_word = state.current_word,
    total_words = #state.words,
    wpm = state.wpm,
    running = state.running,
    show_progress = state.show_progress,
  })
end

local function stop_timer()
  if state and state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
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
  render_word(state.words[math.max(1, state.current_word - 1)] or state.words[1] or "")
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

---@param config table
---@param filename string?
M.start_rsvp = function(config, filename)
  local words
  if filename and filename ~= "" then
    words = utils.get_words_from_file(filename)
    if #words == 0 then
      vim.notify("Can't RSVP on empty or invalid file: " .. filename, vim.log.levels.WARN)
      return
    end
  else
    words = utils.get_words_from_buffer()
  end

  if #words == 0 then
    vim.notify("Can't RSVP on empty buffer", vim.log.levels.WARN)
    return
  end

  local buf, win = ui.create_window(config)
  local ns = vim.api.nvim_create_namespace("rsvp_orp")

  state = {
    buf = buf,
    win = win,
    ns = ns,
    words = words,
    config = config,
    current_word = 1,
    wpm = config.wpm,
    running = false,
    show_progress = config.show_progress,
    timer = nil,
  }

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
  vim.keymap.set("n", "?", function()
    ui.show_help_popup(win, config)
  end, opts)

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = cleanup,
    once = true,
  })

  render_word(words[1])
end

-- Re-export for testing compatibility if needed
M.calculate_orp = utils.calculate_orp
M.get_words_from_buffer = utils.get_words_from_buffer

return M
