-- main module file
local module = require("rsvp.module")

---Get the border style from winborder option (0.11+) or fallback to "none"
---@return string|table
local function get_default_border()
  local ok, winborder = pcall(function()
    return vim.opt.winborder:get()
  end)
  if ok and winborder and winborder ~= "" and (type(winborder) ~= "table" or #winborder > 0) then
    return winborder
  end
  return "none"
end

---@class Config
---@field border string|table Border style
---@field width number Window width
---@field height number Window height
---@field wpm number Words per minute
---@field show_progress boolean Show progress bar
local config = {
  border = get_default_border(),
  width = 60,
  height = 20,
  wpm = 300,
  show_progress = true,
}

---@class MyModule
local M = {}

---@type Config
M.config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.rsvp = function(opts)
  local filename = nil
  if opts and opts.fargs and #opts.fargs > 0 then
    filename = opts.fargs[1]
  end
  local final_opts = vim.tbl_deep_extend("force", M.config, opts or {})
  return module.start_rsvp(final_opts, filename)
end

return M
