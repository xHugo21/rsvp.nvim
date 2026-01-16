local M = {}

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

---@param file_path string
---@return string[]
M.get_words_from_file = function(file_path)
  local f = io.open(file_path, "r")
  if not f then
    return {}
  end
  local content = f:read("*all")
  f:close()
  local words = {}
  for word in content:gmatch("%S+") do
    table.insert(words, word)
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
M.build_progress_bar = function(bar_width, current, total)
  if total <= 0 then
    return string.rep("░", bar_width), 0
  end
  local progress = math.min(1, math.max(0, (current - 1) / total))
  local filled = math.floor(progress * bar_width)
  local empty = bar_width - filled
  return string.rep("█", filled) .. string.rep("░", empty), filled
end

return M
