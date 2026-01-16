local ui = require("rsvp.ui")

describe("rsvp.ui", function()
  local config = {
    width = 60,
    height = 10,
    border = "single",
  }

  describe("create_window", function()
    it("creates a valid buffer and window", function()
      -- Mocking uis if necessary, but nvim --headless might have one or we can stub it
      -- For now let's try direct call
      local buf, win = ui.create_window(config)
      
      assert.is_true(vim.api.nvim_buf_is_valid(buf))
      assert.is_true(vim.api.nvim_win_is_valid(win))
      
      assert.are.equal(config.width, vim.api.nvim_win_get_width(win))
      assert.are.equal(config.height, vim.api.nvim_win_get_height(win))
      
      vim.api.nvim_win_close(win, true)
    end)
  end)

  describe("render", function()
    it("renders the word and UI elements correctly", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local ns = vim.api.nvim_create_namespace("test_rsvp")
      
      local data = {
        buf = buf,
        ns = ns,
        config = config,
        word = "Hello",
        current_word = 1,
        total_words = 10,
        wpm = 300,
        running = false,
        show_progress = true,
      }
      
      ui.render(data)
      
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      
      -- Line 1: Progress and status
      -- format: progress_text .. space .. status_text
      assert.truthy(lines[1]:match("1/10"))
      assert.truthy(lines[1]:match("%[PAUSED%]"))
      assert.truthy(lines[1]:match("WPM: 300"))
      
      -- Check if word is rendered
      local found_word = false
      for _, line in ipairs(lines) do
        if line:match("Hello") then
          found_word = true
          break
        end
      end
      assert.is_true(found_word)
      
      -- Check help line (last line)
      local last_line = lines[#lines]
      assert.truthy(last_line:match("<Space>: Play"))
      
      -- Check dynamic play/pause label
      data.running = true
      ui.render(data)
      lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      last_line = lines[#lines]
      assert.truthy(last_line:match("<Space>: Pause"))
      assert.truthy(lines[1]:match("%[PLAYING%]"))
    end)
    
    it("hides progress bar when show_progress is false", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local ns = vim.api.nvim_create_namespace("test_rsvp")
      
      local data = {
        buf = buf,
        ns = ns,
        config = config,
        word = "Hello",
        current_word = 1,
        total_words = 10,
        wpm = 300,
        running = false,
        show_progress = false,
      }
      
      ui.render(data)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      
      -- Verify no progress bar characters (█ or ░)
      for _, line in ipairs(lines) do
        assert.is_nil(line:match("█"))
        assert.is_nil(line:match("░"))
      end
    end)
  end)

  describe("help popup", function()
    it("opens help popup window", function()
        local buf, win = ui.create_window(config)
        
        ui.show_help_popup(win, config)
        
        -- Check if a new window was opened
        local wins = vim.api.nvim_list_wins()
        -- One is the initial, one is the RSVP win, one is the help win
        -- But Plenary might have its own windows. Let's just check if count increased or use a more robust way.
        -- Actually, ui.show_help_popup creates a window relative to 'win'
        
        local found_help = false
        for _, w in ipairs(vim.api.nvim_list_wins()) do
            local b = vim.api.nvim_win_get_buf(w)
            local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
            for _, line in ipairs(lines) do
                if line:match("RSVP.nvim Keybindings") then
                    found_help = true
                    break
                end
            end
        end
        assert.is_true(found_help)
        
        vim.api.nvim_win_close(win, true)
    end)
  end)
end)
