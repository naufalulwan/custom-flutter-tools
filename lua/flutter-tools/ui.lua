---@enum
local M = {}

---Post a message to UI so the user knows something has occurred.
---@param msg string | string[]
---@param level integer
---@param opts {timeout: number, once: boolean}?
M.notify = function(msg, level, opts)
  opts = opts or {}
  local color = "Normal" -- Default color if no log level is found
  if level == "ERROR" then
    color = "Error"
  elseif level == "WARNING" then
    color = "WarningMsg"
  elseif level == "INFO" then
    color = "Directory"
  elseif level == "DEBUG" then
    color = "Comment"
  end

  -- Send colored output to the Neovim message area
  vim.api.nvim_out_write(
    string.format(
      "\27[38;5;%dm%s\27[0m\n",
      vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(color)), "fg"),
      msg
    )
  )

  -- Use Neovim's internal notify function
  vim.notify(msg, level, opts)
end

---@param opts table
---@param on_open fun(buf: integer, win: integer, job_id)
---@return nil
function M.open_win(opts, on_open)
  local win_opts = {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines - 2,
    col = 0,
    row = 0,
    style = "minimal",
  }

  local buf = vim.api.nvim_create_buf(false, true) -- Create a new buffer
  vim.api.nvim_buf_set_name(buf, opts.filename) -- Set the name of the buffer

  -- Apply filetype
  vim.bo[buf].filetype = opts.filetype or "log"

  -- Open the window
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Apply any custom window options
  if opts.open_cmd then vim.cmd(opts.open_cmd) end

  if on_open then
    -- Ensure `on_open` is called with the correct parameters
    on_open(buf, win, opts.job_id)
  end

  -- Focus window if required
  if opts.focus_on_open then vim.api.nvim_set_current_win(win) end
end

return M
