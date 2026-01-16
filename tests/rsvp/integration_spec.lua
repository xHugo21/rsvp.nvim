local rsvp = require("rsvp")
local ui = require("rsvp.ui")

describe("rsvp integration", function()
  before_each(function()
    rsvp.setup({
      width = 60,
      height = 10,
      wpm = 300,
      show_progress = true,
    })

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one two three four five" })
  end)

  after_each(function()
    -- Close any windows that might have been left open
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_name(buf):match("rsvp") or vim.bo[buf].buftype == "nofile" then
        -- This is a bit aggressive but helps in tests
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end)

  it("starts RSVP and renders the first word", function()
    rsvp.rsvp()

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- First word "one" should be present
    local found = false
    for _, line in ipairs(lines) do
      if line:match("one") then
        found = true
      end
    end
    assert.is_true(found)

    -- Help line should show Play
    assert.truthy(lines[#lines]:match("Play"))
  end)

  it("toggles play/pause via keymap", function()
    rsvp.rsvp()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)

    -- Trigger <Space> keymap
    local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
    local space_map = nil
    for _, map in ipairs(keymaps) do
      if map.lhs == " " then
        space_map = map
        break
      end
    end

    assert.is_not_nil(space_map)

    if space_map.callback then
      space_map.callback()
    end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.truthy(lines[#lines]:match("Pause"))

    -- Toggle back
    if space_map.callback then
      space_map.callback()
    end
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.truthy(lines[#lines]:match("Play"))
  end)

  it("adjusts WPM via keymaps", function()
    rsvp.rsvp()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)

    local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
    local k_map, j_map
    for _, map in ipairs(keymaps) do
      if map.lhs == "k" then
        k_map = map
      end
      if map.lhs == "j" then
        j_map = map
      end
    end

    -- Initial WPM 300
    assert.truthy(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]:match("WPM: 300"))

    if k_map.callback then
      k_map.callback()
    end -- +50
    assert.truthy(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]:match("WPM: 350"))

    if j_map.callback then
      j_map.callback()
    end -- -50
    assert.truthy(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]:match("WPM: 300"))
  end)

  it("resets progress via keymap", function()
    rsvp.rsvp()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)

    -- We can't easily wait for the timer in tests without mocking or waiting
    -- but we can trigger play, then reset
    local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
    local space_map, r_map
    for _, map in ipairs(keymaps) do
      if map.lhs == " " then
        space_map = map
      end
      if map.lhs == "r" then
        r_map = map
      end
    end

    if space_map.callback then
      space_map.callback()
    end -- Start playing
    -- State should now be at word 2 or further if timer fired (but timer is async)

    if r_map.callback then
      r_map.callback()
    end -- Reset

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.truthy(lines[1]:match("1/5")) -- Back to first word
    assert.truthy(lines[#lines]:match("Play")) -- Back to paused
  end)

  it("loads words from a file when passed as argument", function()
    local tmp_file = os.tmpname()
    local f = io.open(tmp_file, "w")
    if f then
      f:write("word1 word2 word3")
      f:close()
    end

    -- Simulate :Rsvp <tmp_file>
    rsvp.rsvp({ fargs = { tmp_file } })

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Check if word1 is rendered
    local found = false
    for _, line in ipairs(lines) do
      if line:match("word1") then
        found = true
      end
    end
    assert.is_true(found)

    -- Check progress text
    assert.truthy(lines[1]:match("1/3"))

    vim.api.nvim_win_close(win, true)
    os.remove(tmp_file)
  end)
end)
