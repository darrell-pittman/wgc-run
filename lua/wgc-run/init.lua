local utils = require('wgc-nvim-utils').utils
local command = require('wgc-run.command')

local M = {}
local _opts = {}

M.setup = function(opts)
  _opts = utils.table.merge(_opts, opts)
  local runners = _opts.runners
  for idx = 1, #runners do
    command.create_command(runners[idx], _opts.buffer_keymaps)
  end
end

return M
