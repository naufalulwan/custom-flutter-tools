local lazy = require("flutter-tools.lazy")
local ui = lazy.require("flutter-tools.ui") ---@module "flutter-tools.ui"
local utils = lazy.require("flutter-tools.utils") ---@module "flutter-tools.utils"
local config = lazy.require("flutter-tools.config") ---@module "flutter-tools.config"
local log_highlighting = lazy.require("mtdl9/vim-log-highlighting")

local api = vim.api

local M = {
  --@type integer
  buf = nil,
  --@type integer
  win = nil,
}

M.filename = "flutter_dev_log"

--- check if the buffer exists if does and we
--- lost track of it's buffer number re-assign it
local function exists()
  local is_valid = utils.buf_valid(M.buf, M.filename)
  if is_valid and not M.buf then M.buf = vim.fn.bufnr(M.filename) end
  return is_valid
end

local function close_dev_log()
  M.buf = nil
  M.win = nil
end

local function create(config)
  local opts = {
    filename = M.filename,
    open_cmd = config.open_cmd,
    filetype = "log",
    focus_on_open = config.focus_on_open,
  }
  ui.open_win(opts, function(buf, win)
    if not buf then
      ui.notify("Failed to open the dev log as the buffer could not be found", ui.ERROR)
      return
    end
    M.buf = buf
    M.win = win
    api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      callback = close_dev_log,
    })
  end)
end

function M.get_content()
  if M.buf then return api.nvim_buf_get_lines(M.buf, 0, -1, false) end
end

local function highlight_log(data) log_highlighting.highlight(data) end

---Open a log showing the output from a command
---in this case flutter run
---@param data string
function M.log(data)
  local opts = config.dev_log
  if opts.enabled then
    if not exists() then create(opts) end
    if opts.filter and not opts.filter(data) then return end

    highlight_log(data)
    vim.api.nvim_buf_set_lines(M.buf, -1, -1, false, { data })
  end
end

function M.clear()
  if M.buf and api.nvim_buf_is_valid(M.buf) then
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, {}) -- Clear buffer content
  end
end

M.toggle = function()
  local wins = vim.api.nvim_list_wins()
  for _, id in pairs(wins) do
    local bufnr = vim.api.nvim_win_get_buf(id)
    if vim.api.nvim_buf_get_name(bufnr):match(".*/([^/]+)$") == M.filename then
      return vim.api.nvim_win_close(id, true)
    end
  end
  create(config.dev_log)
end

return M
