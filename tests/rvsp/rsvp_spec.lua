local rsvp = require("rsvp")
local module = require("rsvp.module")

describe("rsvp", function()
  before_each(function()
    -- Reset config before each test
    rsvp.setup({
      border = "none",
      width = 60,
      height = 20,
      wpm = 300,
    })
  end)

  describe("setup", function()
    it("merges custom configuration", function()
      rsvp.setup({ wpm = 500, width = 80 })
      assert.are.equal(500, rsvp.config.wpm)
      assert.are.equal(80, rsvp.config.width)
      assert.are.equal("none", rsvp.config.border)
    end)
  end)

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
        assert.are.equal(case.expected, module.calculate_orp(#case.word))
      end)
    end
  end)

  describe("word extraction", function()
    it("extracts words from buffer correctly", function()
      local lines = { "Hello world", "this is a   test", "  spaced  " }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

      local words = module.get_words_from_buffer()
      assert.are.same({ "Hello", "world", "this", "is", "a", "test", "spaced" }, words)
    end)
  end)
end)
