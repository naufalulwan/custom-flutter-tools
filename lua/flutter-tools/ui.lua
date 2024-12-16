local utils = require("flutter-tools.utils")
local fmt = string.format

---@enum EntryType
local entry_type = {
  CODE_ACTION = 1,
  DEVICE = 2,
}

---@generic T
---@alias SelectionEntry {text: string, type: EntryType, data: T}

---@enum
local M = {
  ERROR = vim.log.levels.ERROR,
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  TRACE = vim.log.levels.TRACE,
  WARN = vim.log.levels.WARN,
}

local log_levels = {
  ERROR = { level = vim.log.levels.ERROR, color = "Error" },
  WARN = { level = vim.log.levels.WARN, color = "WarningMsg" },
  INFO = { level = vim.log.levels.INFO, color = "Normal" },
  DEBUG = { level = vim.log.levels.DEBUG, color = "Comment" },
  TRACE = { level = vim.log.levels.TRACE, color = "Directory" },
}

local api = vim.api
local namespace_id = api.nvim_create_namespace("flutter_tools_popups")
M.entry_type = entry_type

function M.clear_highlights(buf_id, ns_id, line_start, line_end)
  line_start = line_start or 0
  line_end = line_end or -1
  api.nvim_buf_clear_namespace(buf_id, ns_id, line_start, line_end)
end

--- @param buf_id number
--- @param lines table[]
--- @param ns_id integer?
function M.add_highlights(buf_id, lines, ns_id)
  if not buf_id then return end
  ns_id = ns_id or namespace_id
  if not lines then return end
  for _, line in ipairs(lines) do
    api.nvim_buf_add_highlight(
      buf_id,
      ns_id,
      line.highlight,
      line.line_number,
      line.column_start,
      line.column_end
    )
  end
end

--- check if there is a single non empty line
--- in the list of lines
--- @param lines table
local function invalid_lines(lines)
  for _, line in pairs(lines) do
    if line ~= "" then return false end
  end
  return true
end

---Post a message to UI so the user knows something has occurred.
---@param msg string | string[]
---@param level integer
---@param opts {timeout: number, once: boolean}?
M.notify = function(msg, level, opts)
  opts = opts or {}
  -- Tentukan warna sesuai dengan level log
  local color = log_levels[level] and log_levels[level].color or "Normal"

  -- Menulis output menggunakan format ANSI dengan nomor warna
  local color_code = {
    Error = 1, -- Red
    WarningMsg = 3, -- Yellow
    Normal = 7, -- White
    Comment = 8, -- Grey
    Directory = 4, -- Blue
  }

  -- Gunakan nomor warna ANSI, jika tidak ada, default ke Normal (putih)
  local color_number = color_code[color] or color_code.Normal

  -- Menampilkan pesan dengan warna yang sesuai
  vim.api.nvim_out_write(string.format("\27[38;5;%dm%s\27[0m\n", color_number, msg))

  vim.notify(msg, level, opts)
end

---@param opts table
---@param on_confirm function
M.input = function(opts, on_confirm) vim.ui.input(opts, on_confirm) end

--- @param items SelectionEntry[]
--- @param title string
--- @param on_select fun(item: SelectionEntry)
local function get_telescope_picker_config(items, title, on_select)
  local ok = pcall(require, "telescope")
  if not ok then return end

  local filtered = vim.tbl_filter(function(value) return value.data ~= nil end, items) --[[@as SelectionEntry[]]

  return require("flutter-tools.menu").get_config(
    vim.tbl_map(function(item)
      local data = item.data
      if item.type == entry_type.CODE_ACTION then
        return {
          id = data.title,
          label = data.title,
          command = function() on_select(data) end,
        }
      elseif item.type == entry_type.DEVICE then
        return {
          id = data.id,
          label = data.name,
          hint = data.platform,
          command = function() on_select(data) end,
        }
      end
    end, filtered),
    { title = title }
  )
end

M.select = function(opts, on_select) vim.ui.select(opts, on_select) end

---@alias PopupOpts {title:string, lines: SelectionEntry[], on_select: fun(item: SelectionEntry)}
---@param opts PopupOpts
-- function M.select(opts)
-- assert(opts ~= nil, "An options table must be passed to popup create!")
-- local title, lines, on_select = opts.title, opts.lines, opts.on_select
-- if not lines or #lines < 1 or invalid_lines(lines) then return end
--
-- vim.ui.select(lines, {
--   prompt = title,
--   kind = "flutter-tools",
--   format_item = function(item) return item.text end,
--   -- custom key for dressing.nvim
--   telescope = get_telescope_picker_config(lines, title, on_select),
-- }, function(item)
--   if not item then return end
--   on_select(item.data)
-- end)
-- end

---Create a split window
---@param opts table
---@param on_open fun(buf: integer, win: integer)
---@return nil
-- function M.open_win(opts, on_open)
--   local open_cmd = opts.open_cmd or "botright 30vnew"
--   local name = opts.filename or "__Flutter_Tools_Unknown__"
--   open_cmd = fmt("%s %s", open_cmd, name)
--
--   vim.cmd(open_cmd)
--   local win = api.nvim_get_current_win()
--   local buf = api.nvim_get_current_buf()
--   vim.bo[buf].filetype = opts.filetype
--   vim.bo[buf].swapfile = false
--   vim.bo[buf].buftype = "nofile"
--   if on_open then on_open(buf, win) end
--   if not opts.focus_on_open then
--     -- Switch back to the previous window
--     vim.cmd("wincmd p")
--   end
-- end

---Create a split window
---@param opts table
---@param on_open fun(buf: integer, win: integer, job_id)
---@return nil
function M.open_win(opts, on_open)
  local open_cmd = opts.open_cmd or "botright 30vsplit"
  local name = opts.filename or "__Flutter_Tools_Terminal__"

  vim.cmd(fmt("%s | enew", open_cmd))

  local win = api.nvim_get_current_win()
  local buf = api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(buf) then
    M.notify("Failed to create a valid buffer", M.ERROR)
    return
  end

  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].modified = false

  local job_id = vim.fn.termopen(opts.shell, {
    on_exit = function(_, code)
      if code ~= 0 then M.notify("Terminal exited with code " .. code, M.ERROR) end
    end,
  })

  if not job_id then
    M.notify("Failed to open terminal buffer", M.ERROR)
    return
  end

  vim.bo[buf].filetype = opts.filetype and tostring(opts.filetype) or "log"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = "terminal"
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  if on_open then on_open(buf, win, job_id) end

  if not opts.focus_on_open then vim.cmd("wincmd p") end
end

return M
