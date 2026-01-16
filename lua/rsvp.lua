-- main module file
local module = require("rsvp.module")

---@class Config
---@field border string Border style
---@field width number Window width
---@field height number Window height
---@field wpm number Words per minute
---@field show_progress boolean Show progress bar
local config = {
  border = vim.opt.winborder:get() or "none",
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
