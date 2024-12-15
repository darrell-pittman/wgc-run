local utils = require('wgc-nvim-utils').utils
local file_path = require('wgc-nvim-utils').file_path
local run = require('wgc-run.run')

local M = {}

local run_group = vim.api.nvim_create_augroup('WgcRun', {
  clear = true,
})

local function file_exists_test(file, exists_list, cb)
  local ok = true
  local function search()
    if exists_list and #exists_list > 0 then
      local f = exists_list[1]
      file:search_up(file_path:new(f), vim.schedule_wrap(function(found)
        ok = ok and found
        if ok then
          exists_list = vim.list_slice(exists_list, 2, #exists_list)
          search()
        else
          cb(false)
        end
      end))
    else
      cb(ok)
    end
  end
  search()
end

local function run_tests_ok(file, run_tests, cb)
  local val_type
  local ok = true
  local exists_list = {}
  for key, val in pairs(run_tests) do
    val_type = type(val)
    if key == 'exe_exists' then
      if val_type == 'string' then
        ok = ok and (vim.fn.executable(val) == 1)
      elseif val_type == 'table' then
        for _, v in ipairs(val) do
          ok = ok and (vim.fn.executable(v) == 1)
          if not ok then break end
        end
      end
    elseif key == 'file_exists' then
      if val_type == 'string' then
        table.insert(exists_list, val)
      elseif val_type == 'table' then
        exists_list = utils.table.append(exists_list, val)
      end
    end
    if not ok then break end
  end

  if ok and #exists_list > 0 then
    file_exists_test(file, exists_list, cb)
  else
    cb(ok)
  end
end

local function create_run_command(info, runner)
  local file = file_path:new(info.file)
  run_tests_ok(file, runner.run_tests, function(ok)
    if ok then
      local map = utils.make_mapper({ buffer = info.buf, silent = true })
      map('n', '<leader>rr', ':WgcRun<cr>')

      vim.api.nvim_buf_create_user_command(info.buf, 'WgcRun', function()
          run.run(file, runner)
        end,
        {})
    end
  end)
end

M.create_command = function(runner)
  vim.api.nvim_create_autocmd('BufEnter', {
    group = run_group,
    pattern = runner.autopat,
    callback = function(info)
      create_run_command(info, runner)
    end
  })
end

return M
