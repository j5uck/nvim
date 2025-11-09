local ffi = require("ffi")

local IS_WINDOWS = vim.fn.has("win32") == 1

local M = {}

M.flags = {
  warn_missing_lsp = true,
  warn_missing_module = true,
}

local WRAP = vim.schedule_wrap
local I, W, E = vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR

M.notify = {}
M.notify.info  = WRAP(function(s) vim.notify(s, I) end)
M.notify.warn  = WRAP(function(s) vim.notify(s, W) end)
M.notify.error = WRAP(function(s) vim.notify(s, E) end)
M.notify_once = {}
M.notify_once.info  = WRAP(function(s) vim.notify_once(s, I) end)
M.notify_once.warn  = WRAP(function(s) vim.notify_once(s, W) end)
M.notify_once.error = WRAP(function(s) vim.notify_once(s, E) end)

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
    M.notify_once.warn("Module '" .. name .. "' not found")
  end
end

M.prequire_wrap = function(name, fn)
  return function() return M.prequire(name, fn) end
end

M.random = {}

local CHARS = vim.split("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "")
M.random.string = function(len)
  local buffer = ffi.new("char [?]", len)
  ffi.copy(buffer, vim.uv.random(len), len)

  for i = 0, len - 1, 1 do
    ffi.copy(buffer+i, CHARS[buffer[i] % #CHARS + 1], 1)
  end
  return ffi.string(buffer, len)
end

M.random.int = function()
  local buffer = ffi.new("int32_t [1]")
  ffi.copy(buffer, vim.uv.random(4), 4)
  return buffer[0]
end

M.random.uint = function()
  local buffer = ffi.new("uint32_t [1]")
  ffi.copy(buffer, vim.uv.random(4), 4)
  return buffer[0]
end

M.fs = {}

M.fs.mktmp = (function()
  local d = not IS_WINDOWS and
    (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/tmp." or
    string.gsub(vim.fs.dirname(vim.env.APPDATA) .. "/Local/Temp/tmp.", "/", "\\")

  return function()
    local r = d .. M.random.string(10)
    vim.fn.mkdir(r, "p")
    return r
  end
end)()

M.fs.mkdir = function(dir)
  local s, _ = pcall(vim.fn.mkdir, dir, "p")
  return not s
end

M.fs.mkfile = function(file, content, flags)
  flags = flags or ""
  if vim.fn.match(flags, "p") then M.fs.mkdir(vim.fs.dirname(file)) end
  local s, _ = pcall(vim.fn.writefile, content or {}, file, flags)
  return not s
end

M.fs.mklink = IS_WINDOWS and function(_, _)
  error("Unsupported platform")
end or
 function(target, link_name)
  local o = vim.system{ vim.fn.exepath("ln"), "--symbolic", target, link_name }:wait()
  return o.code ~= 0
end

M.fs.copy = IS_WINDOWS and function(src, dest)
  local o = vim.system{ vim.fn.exepath("powershell"), "Copy-Item", "-recurse", src, "-destination", dest }:wait()
  return o.code ~= 0
end or function(src, dest)
  local o = vim.system{ vim.fn.exepath("cp"), "--recursive", src, dest }:wait()
  return o.code ~= 0
end

M.fs.move = function(src, dest)
  local s, _ = pcall(vim.fn.rename, src, dest)
  return s and s ~= 0 or true
end

M.fs.remove = function(src)
  local s, _ = pcall(vim.fn.delete, src, "rf")
  return s and s ~= 0 or true
end

M.fs.readfile = function(file, type)
  local s, lines = pcall(vim.fn.readfile, file, type)
  return s and lines or nil
end

M.fs.basename = vim.fs.basename

M.fs.dirname = IS_WINDOWS and function(file)
  local r = vim.fs.dirname(file)
  r = string.gsub(r, "/", "\\")
  return r
end or vim.fs.dirname

local window = {}

function window:show()
  if vim.api.nvim_win_is_valid(self.win) then return end

  if not vim.api.nvim_buf_is_valid(self.buf) then
    self.buf = vim.api.nvim_create_buf(false, true)
  end

  self.win = vim.api.nvim_open_win(self.buf, self.focus, vim.tbl_extend("force",{
    relative = "editor",
    style = "minimal",
    border = self.border,
    zindex = self.zindex,
    hide = false,
    focusable = self.focus,
  }, self.size()))

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
  self.border = conf.border or "rounded"
  self.size = conf.size or function() return {
    width = DEFAULT_WIDTH,
    height = DEFAULT_HEIGHT,
    col = math.floor((vim.o.columns - DEFAULT_WIDTH) / 2) - 1,
    row = math.floor((vim.o.lines - DEFAULT_HEIGHT) / 2) - 1
  } end

  self.on_show = { conf.on_show }
  self.on_resize = { conf.on_resize }
  table.insert(self.on_resize, function(_)
    local s = self.size()
    s.relative = "editor"
    vim.api.nvim_win_set_config(self.win, s)
  end)

  self.buf = -1
  self.win = -1
  self.ns = vim.api.nvim_create_namespace("")

  if conf.hl then
    self.on_colorscheme = { function(_)
      for k, v in pairs(conf.hl()) do
        vim.api.nvim_set_hl(self.ns, k, v)
      end
    end }

    table.insert(self.on_show, function()
      vim.api.nvim_win_set_hl_ns(self.win, self.ns)
      for _, fn in ipairs(self.on_colorscheme) do fn(self) end
    end)

    vim.api.nvim_create_autocmd("ColorScheme", { callback = function()
      for _, fn in ipairs(self.on_colorscheme) do fn(self) end
    end})
  end

  vim.api.nvim_create_autocmd("VimResized", { callback = function()
    if not vim.api.nvim_win_is_valid(self.win) then return end
    for _, fn in ipairs(self.on_resize) do fn(self) end
  end})

  return self
end

M.window = function(conf) return setmetatable(new(conf), { __index = window }) end

return M
