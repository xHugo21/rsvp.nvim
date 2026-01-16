local utils = require("rsvp.utils")

describe("rsvp.utils", function()
  describe("ORP calculation", function()
    local test_cases = {
      { word = "a", expected = 1 },
      { word = "to", expected = 2 },
      { word = "the", expected = 2 },
      { word = "word", expected = 2 },
      { word = "hello", expected = 2 },
      { word = "reading", expected = 3 },
      { word = "algorithm", expected = 3 },
      { word = "highlight", expected = 3 },
      { word = "internationalization", expected = 6 },
    }

    for _, case in ipairs(test_cases) do
      it("calculates correct ORP for '" .. case.word .. "'", function()
        assert.are.equal(case.expected, utils.calculate_orp(#case.word))
      end)
    end
  end)

  describe("word extraction", function()
    it("extracts words from buffer correctly", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local lines = { "Hello world", "this is a   test", "  spaced  " }
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      -- We need to temporarily set the current buffer to 'buf' for get_words_from_buffer to work
      -- OR we should probably change get_words_from_buffer to accept a buffer handle
      -- Actually, get_words_from_buffer currently uses 0 (current buffer)
      local old_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_current_buf(buf)
      
      local words = utils.get_words_from_buffer()
      assert.are.same({ "Hello", "world", "this", "is", "a", "test", "spaced" }, words)
      
      vim.api.nvim_set_current_buf(old_buf)
    end)
  end)

  describe("progress bar building", function()
    it("builds empty progress bar", function()
      local bar, filled = utils.build_progress_bar(10, 1, 10)
      assert.are.equal("░░░░░░░░░░", bar)
      assert.are.equal(0, filled)
    end)

    it("builds full progress bar", function()
      local bar, filled = utils.build_progress_bar(10, 11, 10)
      assert.are.equal("██████████", bar)
      assert.are.equal(10, filled)
    end)

    it("builds partial progress bar", function()
      local bar, filled = utils.build_progress_bar(10, 6, 10)
      -- (6-1)/10 = 0.5
      assert.are.equal("█████░░░░░", bar)
      assert.are.equal(5, filled)
    end)
    
    it("handles 0 total words gracefully", function()
        -- (1-1)/0 is NaN in some envs, but Lua math.max handles it or we have math.min(1, max(0, ...))
        local bar, filled = utils.build_progress_bar(10, 1, 0)
        assert.are.equal("░░░░░░░░░░", bar)
        assert.are.equal(0, filled)
    end)
  end)
end)
