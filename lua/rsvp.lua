-- main module file
local module = require("rsvp.module")

---@class Config
---@field border string Border style
---@field width number Window width
---@field height number Window height
local config = {
  border = vim.opt.winborder:get() or "solid",
  width = 60,
  height = 20,
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

M.hello = function(opts)
  local final_opts = vim.tbl_deep_extend("force", M.config, opts or {})
  return module.open_rsvp_window(final_opts)
end

return M
