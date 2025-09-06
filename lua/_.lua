local M = {}

M.flags = {
  warn_missing_lsp = true,
  warn_missing_module = true,
}

local WRAP = vim.schedule_wrap
local I, W, E = vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR

M.notify = {}
M.notify.info  = WRAP(function(...) vim.notify(string.format(...), I) end)
M.notify.warn  = WRAP(function(...) vim.notify(string.format(...), W) end)
M.notify.error = WRAP(function(...) vim.notify(string.format(...), E) end)
M.notify_once = {}
M.notify_once.info  = WRAP(function(...) vim.notify_once(string.format(...), I) end)
M.notify_once.warn  = WRAP(function(...) vim.notify_once(string.format(...), W) end)
M.notify_once.error = WRAP(function(...) vim.notify_once(string.format(...), E) end)

M.log = function(...)
  local sb = {}
  local len = select("#", ...)
  for i = 1, len, 1 do
    local e = select(i, ...)
    table.insert(sb, vim.inspect(e))
  end
  vim.schedule_wrap(vim.notify)(table.concat(sb, "\n"), W)
end

M.prequire = function(name, fn)
  local status, plugin = pcall(require, name)

  if status then return fn(plugin) end

  if M.flags.warn_missing_module then
    M.notify_once.warn("Module '%s' not found", name)
  end
end

M.prequire_wrap = function(name, fn)
  return function() return M.prequire(name, fn) end
end

local window = {}

function window:show()
  if vim.api.nvim_win_is_valid(self.win) then
    return
  end

  if not vim.api.nvim_buf_is_valid(self.buf) then
    self.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[self.buf].bufhidden  = "hide"
    vim.bo[self.buf].buftype    = "nofile"
    vim.bo[self.buf].buflisted  = false
    vim.bo[self.buf].swapfile   = false
    vim.bo[self.buf].undolevels = -1
  end

  self.win = vim.api.nvim_open_win(self.buf, self.focus, vim.tbl_extend("force",{
    relative = "editor",
    style = "minimal",
    border = self.border,
    zindex = self.zindex,
    hide = false,
    focusable = self.focusable,
    noautocmd = self.noautocmd
  }, self.size()))

  if self.focus then
    vim.api.nvim_create_autocmd("WinLeave", {
      callback = function() self:hide() end,
      once = true
    })
  end

  vim.api.nvim_buf_call(self.buf, function()
    for _, fn in ipairs(self.on_show) do fn(self) end
  end)
end

function window:hide()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
    self.win = -1
  end
end

function window:toggle()
  if vim.api.nvim_win_is_valid(self.win) then
    self:hide()
  else
    self:show()
  end
end

local DEFAULT_WIDTH = 16 * 4
local DEFAULT_HEIGHT = 9 * 2

local function new(conf)
  local self = {}

  self.zindex = conf.zindex or 25
  self.focus = not not conf.focus
  self.focusable = conf.focusable
  self.noautocmd = conf.noautocmd
  self.border = conf.border or "rounded"
  self.size = conf.size or function() return {
    width = DEFAULT_WIDTH,
    height = DEFAULT_HEIGHT,
    col = math.floor((vim.o.columns - DEFAULT_WIDTH) / 2) - 1,
    row = math.floor((vim.o.lines - DEFAULT_HEIGHT) / 2) - 1
  } end

  self.on_show = { conf.on_show }
  self.on_resize = { function()
    if not vim.api.nvim_win_is_valid(self.win) then return end
    local _ = self.size()
    _.relative = "editor"
    vim.api.nvim_win_set_config(self.win, _)
  end }

  self.buf = -1
  self.win = -1
  self.ns = vim.api.nvim_create_namespace("")

  if conf.hl then
    self.on_colorscheme = { function()
      for k, v in pairs(conf.hl()) do
        vim.api.nvim_set_hl(self.ns, k, v)
      end
    end }

    table.insert(self.on_show, function()
      vim.api.nvim_win_set_hl_ns(self.win, self.ns)
      for _, fn in ipairs(self.on_colorscheme) do fn() end
    end)

    vim.api.nvim_create_autocmd("ColorScheme", { callback = function()
      for _, fn in ipairs(self.on_colorscheme) do fn() end
    end})
  end

  vim.api.nvim_create_autocmd("VimResized", { callback = function()
    for _, fn in ipairs(self.on_resize) do fn() end
  end})

  return self
end

M.window = {}
function M.window:new(conf) return setmetatable(new(conf), { __index = window }) end

return M
