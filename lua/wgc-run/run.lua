local file_path = require 'wgc-nvim-utils'.file_path
local utils = require 'wgc-nvim-utils'.utils
local api = vim.api

vim.cmd('highlight link WgcRunHeader Title')
vim.cmd('highlight link WgcRunSubHeader Function')

local M = {}
local current_job_id = nil

M.run_group = vim.api.nvim_create_augroup('WgcRun', {
  clear = true,
})

local constants = utils.table.protect {
  WINDOW_TITLE = 'WgcRun',
  WINDOW_WIDTH = 65,
  HEADER_SYM = '━',
  MARGIN = 1,
}

local function pad(l)
  return utils.string.pad(l, constants.MARGIN)
end

local function center(l)
  return utils.string.center(l, constants.WINDOW_WIDTH)
end

local function tbl_pad(t)
  return vim.tbl_map(pad, t)
end


local disp = nil

local function kill_job(f)
  if current_job_id and disp then
    vim.fn.jobstop(current_job_id)
    api.nvim_buf_set_lines(disp.buf, -1, -1, false, { pad(string.format("Killed Job [ id = %d ]", current_job_id)) })
    current_job_id = nil
  end
  if f then f() end
end

local function close_window()
  kill_job(function()
    disp = nil
    current_job_id = nil
    vim.cmd [[bwipeout]]
  end)
end

local function open_window(callback)
  if disp then
    if api.nvim_win_is_valid(disp.win) then
      api.nvim_win_close(disp.win, true)
    end
    disp = nil
  end
  disp = {}
  vim.cmd(('%svnew'):format(constants.WINDOW_WIDTH))
  disp.buf = api.nvim_get_current_buf()
  disp.win = api.nvim_get_current_win()

  vim.cmd('setlocal buftype=nofile bufhidden=wipe nobuflisted' ..
    ' nolist noswapfile nowrap nospell nonumber norelativenumber' ..
    ' nofoldenable signcolumn=no')

  local map = utils.make_mapper({
    buffer = disp.buf,
    silent = true,
    nowait = true,
  })

  map('n', 'q', close_window)
  map('n', '<esc>', close_window)
  map('n', '<C-c>', kill_job)

  local noops = { 'a', 'c', 'd', 'i', 'x', 'r', 'o', 'p', }
  for _, l in ipairs(noops) do
    map('', l, '')
    map('', string.upper(l), '')
  end

  api.nvim_buf_set_name(disp.buf, '[WgcRun]')
  api.nvim_buf_set_lines(disp.buf, 0, -1, false, {
    center(constants.WINDOW_TITLE),
    center('::: press [q] or <esc> to close (<C-c> to kill job) :::'),
    pad(string.rep(constants.HEADER_SYM, constants.WINDOW_WIDTH - 2 * constants.MARGIN)),
    '',
  })
  api.nvim_buf_add_highlight(disp.buf, -1, 'WgcRunHeader', 0, constants.MARGIN, -1)
  api.nvim_buf_add_highlight(disp.buf, -1, 'WgcRunSubHeader', 1, constants.MARGIN, -1)
  callback()
end

local function default_runner(name, cmd, opts)
  local header = tbl_pad({
    name .. ' output ...', ''
  })

  local footer = tbl_pad({
    '',
    '--' .. name .. ' Finished!--',
  })


  local default_handler = function(_, data)
    if data then
      data = vim.tbl_filter(utils.string.is_not_empty, data)
      if #data > 0 then
        data = tbl_pad(data)
        if disp then
          api.nvim_buf_set_lines(disp.buf, -1, -1, false, data)
        end
      end
    end
  end

  opts.on_stdout = default_handler
  opts.on_stderr = default_handler

  opts.on_exit = function()
    if disp then
      api.nvim_buf_set_lines(disp.buf, -1, -1, false, footer)
    end
    current_job_id = nil
  end

  return function()
    kill_job()
    if disp then
      api.nvim_buf_set_lines(disp.buf, -1, -1, false, header)
    end
    current_job_id = vim.fn.jobstart(cmd, opts)
    if disp then
      api.nvim_buf_set_lines(disp.buf, -1, -1, false, { pad(string.format("Started Job [ id = %d ]", current_job_id)) })
    end
  end
end

local function run_search_up(file, name, args, opts)
  local search_index, search_up
  local file_action = function(f) return tostring(f) end
  for i, v in ipairs(args) do
    if type(v) == 'table' then
      search_up = v.search_up
      search_index = i
      if v.file_action then
        file_action = v.file_action
      end
    end
  end

  file:search_up(file_path:new(search_up), vim.schedule_wrap(function(found_file)
    if found_file then
      found_file = file_action(found_file)
      args[search_index] = found_file
      open_window(default_runner(name, args, opts))
    else
      vim.notify_once(string.format('WgcRun: Failed to find file "%s" when running "search_up" run_command.', search_up),
        vim.log.levels.ERROR)
    end
  end))
end

local function run_args(_, name, args, opts)
  open_window(default_runner(name, args, opts))
end

M.run = function(info, runner)
  local file = file_path:new(info.file)
  local args = {}
  local f = run_args
  local val_type
  local ok = true

  local opts = {
    stdout_bufferd = false,
    cwd = nil,
  }

  if runner.wgc_run then
    opts.cwd = runner.wgc_run.cwd
    f(file, runner.name, runner.wgc_run.args, opts)
    return
  end

  for _, v in ipairs(runner.run_command) do
    val_type = type(v)
    if val_type == 'string' then
      table.insert(args, v)
    elseif val_type == 'table' then
      if v.search_up then
        table.insert(args, v)
        f = run_search_up
      else
        ok = false
        vim.notify_once(string.format('WgcRun: Unknown key in run_command. Expected "%s".', 'search_up'),
          vim.log.levels.ERROR)
        break
      end
    elseif val_type == 'function' then
      table.insert(args, v(info))
    else
      ok = false
      vim.notify_once(
        string.format('WgcRun: Unknown entry type in run_command. Expected "%s","%s" or "%s", found "%s"', 'string',
          'table', 'function', val_type), vim.log.levels.ERROR)
      break
    end
  end

  if ok then
    f(file, runner.name, args)
  end
end

return M
