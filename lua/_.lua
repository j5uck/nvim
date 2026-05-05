local ffi = require("ffi")
local C = ffi.C

local D = {}
D.TMP = vim.fn.has("win32") == 0 and
  (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/tmp." or
  string.gsub(vim.fs.dirname(vim.env.APPDATA) .. "/Local/Temp/tmp.", "/", "\\")

local M = {}

M.flags = {
  warn_missing_lsp = true,
  warn_missing_module = true,
}

-- ------------------------- x ------------------------- --

M.list = {}
M.list.contains = vim.tbl_contains
M.list.join = table.concat
M.list.sort = function(l, s)
  if s == nil then
    return vim.fn.sort(l, "i")
  elseif type(s) == "function" then
    local r = M.list.clone(l)
    table.sort(r, s)
    return r
  else
    assert(false, "Sorter must be a function or nil")
  end
end
M.list.reverse = vim.fn.reverse
M.list.map = vim.tbl_map
M.list.filter = vim.tbl_filter
M.list.uniq = function(l)
  local r = {}
  local d = {}
  for _, e in ipairs(l) do
    if not d[e] then
      d[e] = true
      M.list.insert(r, e)
    end
  end
  return r
end
M.list.remove = table.remove
M.list.slice = vim.list_slice
M.list.clone = function(t) return vim.list_slice(t, 1, #t) end
M.list.insert = function(l, ...)
  table.insert(l, ...)
  return l
end
M.list.merge = function(...)
  local r = ({...})[1]
  for _, t in ipairs{...}, {...}, 1 do
    vim.list_extend(r, t)
  end
  return r
end

M.dictionary = {}
M.dictionary.isempty = vim.tbl_isempty
M.dictionary.clone = function(d)
  local r = {}
  for _, k in ipairs(vim.tbl_keys(d)) do
    r[k] = d[k]
  end
  return r
end
M.dictionary.deep_clone = vim.deepcopy
M.dictionary.keys = vim.tbl_keys
M.dictionary.merge = function(...) return vim.tbl_extend("force", ...) end
M.dictionary.deep_merge = function(...) return vim.tbl_deep_extend("force", ...) end

-- ------------------------- x ------------------------- --

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
    M.list.insert(sb, vim.inspect(e))
  end
  vim.schedule_wrap(vim.notify)(M.list.join(sb, "\n"), W)
end

-- ------------------------- x ------------------------- --

M.prequire = function(name, fn)
  local status, plugin = pcall(require, name)

  if status then return fn and fn(plugin) end

  if M.flags.warn_missing_module then
    M.notify_once.warn("Module '" .. name .. "' not found")
  end
end

M.prequire_wrap = function(name, fn)
  return function() return M.prequire(name, fn) end
end

-- ------------------------- x ------------------------- --

local Promise = {}

function Promise:resolve(...)
  if not (self.code == nil) then
    return M.notify.warn("Promise already finished!")
  end

  self.code = 0
  self.result = { ... }

  vim.schedule(function()
    for _, fn in ipairs(self.awaiting) do fn() end
  end)
end

function Promise:reject(reason)
  local DEFAULT_CODE = 1
  local DEFAULT_MESSAGE = "Promise rejected!"

  vim.schedule(function()
    if reason == nil then
      self.code = DEFAULT_CODE
      self.message = DEFAULT_MESSAGE
    elseif type(reason) == "string" then
      self.code = DEFAULT_CODE
      self.message = reason
    elseif type(reason) == "table" then
      self.code = reason.code or DEFAULT_CODE
      self.message = reason.message or DEFAULT_MESSAGE
    else
      assert(false, "Expected table, string or nil, got " .. type(reason))
    end

    if self.parent_coroutine and coroutine.status(self.parent_coroutine) ~= "dead" then
    else
      M.notify.error(self.message)
    end

    for _, fn in ipairs(self.awaiting) do fn() end

    if coroutine.status(self.coroutine) == "running" then
      self:yield()
    end
  end)
end

function Promise:resume(...)
  assert(self.code == nil, "Promise already finished!")
  coroutine.resume(self.coroutine, ...)
end

function Promise:yield()
  assert(coroutine.running() == self.coroutine, "Yielding the wrong Promise!")
  assert(self.code == nil, "Promise already finished!")
  coroutine.yield()
end

function Promise:schedule()
  vim.schedule(function() self:resume() end)
  self:yield()
end

function Promise:await()
  local co = coroutine.running()
  assert(co, "\"await\" can only be used inside another Promise")

  vim.schedule(function()
    if self.code == nil then
      M.list.insert(self.awaiting, function()
        coroutine.resume(co)
      end)
    else
      coroutine.resume(co)
    end
  end)

  coroutine.yield()

  return self
end

function Promise:unwrap()
  assert(self.code ~= nil, "Promise still running!")
  if self.code ~= 0 then
    assert(false,  debug.traceback("", 2).. "\n" .. self.message)
  end
  return unpack(self.result)
end

function Promise:sleep(milliseconds)
  assert(coroutine.running() == self.coroutine, "Sleeping the wrong Promise!")
  assert(type(milliseconds) == "number", "Timeout must be a number")

  vim.defer_fn(function()
    if self.code == nil then
      self:resume()
    end
  end, milliseconds)

  self:yield()
end

function Promise:finally(fn)
  vim.schedule(function()
    if self.code == nil then
      M.list.insert(self.awaiting, function() fn(self) end)
    else
      fn(self)
    end
  end)
end

M.promisify = function(fn, ...)
  local self = {}
  setmetatable(self, { __index = Promise })

  self.awaiting = {}

  self.trace = {}
  self.trace.init = debug.traceback("", 2)
  self.parent_coroutine = coroutine.running()

  self.coroutine = coroutine.create(function(...)
    local status, result = pcall(fn, self, ...)

    if not status then
      return self:reject(result)
    end
  end)

  vim.schedule_wrap(coroutine.resume)(self.coroutine, ...)

  return self
end

M.promisify_wrap = function(fn)
  return function(...)
    return M.promisify(fn, ...)
  end
end

-- ------------------------- x ------------------------- --

M.term = (vim.fn.has("win32") == 1) and function()
  local shell = vim.go.shell
  local shellxquote = vim.go.shellxquote
  local shellcmdflag = vim.go.shellcmdflag

  local bb = M.fs.exepath("busybox")
  if bb then
    vim.go.shell = "\"" .. bb .. "\" env \"HOME=" .. vim.env.USERPROFILE .. "\" bash"
    vim.go.shellxquote = ""
    vim.go.shellcmdflag = "-c"
  else
    local ps = M.fs.exepath("powershell")
    if ps then
      vim.go.shell = ps
    end
  end

  pcall(function()
    vim.cmd.term()
    vim.cmd[[silent! startinsert]]
  end)

  vim.go.shell = shell
  vim.go.shellxquote = shellxquote
  vim.go.shellcmdflag = shellcmdflag
end or function()
  vim.cmd.term()
  vim.cmd[[silent! startinsert]]
end

-- ------------------------- x ------------------------- --

M.sh = M.promisify_wrap(function(promise, cmd, opts)
  opts = opts or {}
  local text = opts.text
  opts.text = nil

  if not string.find(cmd[1], (vim.fn.has("win32") == 1) and "[\\/]" or "/") then
    cmd[1] = M.fs.exepath(cmd[1])
  end

  if opts.stdout then
    local stdout = opts.stdout
    opts.stdout = (vim.fn.has("win32") == 1) and function(_, data)
      if data then
        return stdout(text and string.gsub(data, "\r\n", "\n") or data)
      end
    end or function(_, data)
      if data then return stdout(data) end
    end
  end
  if opts.stderr then
    local stderr = opts.stderr
    opts.stderr = (vim.fn.has("win32") == 1) and function(_, data)
      if data then
        return stderr(text and string.gsub(data, "\r\n", "\n") or data)
      end
    end or function(_, data)
      if data then return stderr(data) end
    end
  end

  vim.system(cmd, opts, function(o)
    if (vim.fn.has("win32") == 1) and text then
      promise.stdout = string.gsub(o.stdout or "", "\r\n", "\n")
      promise.stderr = string.gsub(o.stderr or "", "\r\n", "\n")
    else
      promise.stdout = o.stdout or ""
      promise.stderr = o.stderr or ""
    end
    if o.code == 0 then
      return promise:resolve()
    else
      return promise:reject{ code = o.code }
    end
  end)
end)

-- ------------------------- x ------------------------- --

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

-- ------------------------- x ------------------------- --

M.fs = {}

M.fs.mktmp = M.promisify_wrap(function(promise)
  while true do
    local r = D.TMP .. M.random.string(10)
    if vim.fn.isdirectory(r) == 0 then
      vim.fn.mkdir(r, "p")
      return promise:resolve(r)
    end
  end
end)

M.fs.mkdir = M.promisify_wrap(function(promise, dir)
  local status, result = pcall(vim.fn.mkdir, dir, "p")
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

M.fs.mkfile = M.promisify_wrap(function(promise, file, content, flags)
  flags = flags or ""
  M.fs.mkdir(M.fs.dirname(file)):await():unwrap()
  local status, result = pcall(vim.fn.writefile, content or {}, file, flags)
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

M.fs.mklink = M.promisify_wrap(vim.fn.has("win32") == 1 and function(_, _, _)
  assert(false, "Unsupported platform")
end or function(promise, target, link_name)
  M.sh{ "ln", "--symbolic", target, link_name }:await():unwrap()
  return promise:resolve()
end)

M.fs.copy = M.promisify_wrap(vim.fn.has("win32") == 1 and function(promise, src, dest)
  M.sh{ "powershell", "Copy-Item", "-recurse", src, "-destination", dest }:await():unwrap()
  return promise:resolve()
end or function(promise, src, dest)
  M.sh{ "cp", "--recursive", src, dest }:await():unwrap()
  return promise:resolve()
end)

M.fs.move = M.promisify_wrap(function(promise, src, dest)
  local status, result = pcall(vim.fn.rename, src, dest)
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

M.fs.remove = M.promisify_wrap(function(promise, src)
  -- local status, result = pcall(vim.fs.rm, src, { recursive = true, force = true })
  local status, result = pcall(vim.fn.delete, src, "rf")
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

M.fs.readfile = M.promisify_wrap(function(promise, file, type)
  local status, result = pcall(vim.fn.readfile, file, type)
  if status then
    return promise:resolve(result)
  else
    return promise:reject(result)
  end
end)

M.fs.basename = vim.fs.basename

M.fs.dirname = vim.fn.has("win32") == 1 and function(file)
  local r = vim.fs.dirname(file)
  r = string.gsub(r, "/", "\\")
  return r
end or vim.fs.dirname

M.fs.relpath = function(base, target)
  return vim.fs.relpath(base, target, {})
end

M.fs.exepath = (vim.fn.has("win32") == 1) and function(exe)
  local ext = vim.split(vim.env.PATHEXT, ";")
  for _, p in ipairs(vim.split(vim.env.PATH, ";")) do
    p = string.gsub(vim.fs.normalize(p .. "\\" .. exe), "\\", "/")
    if vim.uv.fs_access(p, "RX") then return p end
    for _, e in ipairs(ext) do
      local pe = p .. e
      if vim.uv.fs_access(pe, "RX") then return pe end
    end
  end
end or function(bin)
  for _, p in ipairs(vim.split(vim.env.PATH, ":")) do
    p = vim.fs.normalize(p .. "/" .. bin)
    if vim.uv.fs_access(p, "RX") then return p end
  end
end

M.fs.ls = M.promisify_wrap(function(promise, path)
  local C_BUFFER_SIZE = 8192
  local C_BUFFER = ffi.new("char [?]", C_BUFFER_SIZE)

  ---@diagnostic disable-next-line: param-type-mismatch
  local fd, message, _ = vim.uv.fs_opendir(vim.fs.normalize(path), nil, 16384) -- 1 << 14
  if not fd then
    return promise:reject{ message = message }
  end

  local content = vim.uv.fs_readdir(fd) or {}
  for _, t in ipairs(vim.iter(function() return vim.uv.fs_readdir(fd) end):totable()) do
    M.list.merge(content, t)
  end
  vim.uv.fs_closedir(fd)

  if vim.fn.has("win32") == 1 then
    content = M.list.filter(function(e) return e.type ~= "link" end, content)
  end

  for _, e in ipairs(content) do
    e.is_directory = e.type == "directory"
    if e.is_directory or (e.type ~= "link") then goto continue end

    e.link = ffi.string(C_BUFFER, C.readlink(path..e.name, C_BUFFER, C_BUFFER_SIZE))
    local link_full = vim.fs.normalize(vim.fn.isabsolutepath(e.link) == 1 and e.link or (path .. "/" .. e.link))

    e.link_exists = C.stat(link_full, C_BUFFER) == 0
    e.is_directory = e.link_exists and vim.fn.isdirectory(link_full) == 1

    ::continue::
  end

  return promise:resolve(M.list.sort(content, function(a, b)
    if a.is_directory ~= b.is_directory then return a.is_directory end

    local fa, fb = string.sub(a.name, 1, 1) == ".", string.sub(b.name, 1, 1) == "."
    if fa ~= fb then return fb end

    local c = vim.stricmp(a.name, b.name)
    return (c == 0) and (a.name < b.name) or (c == -1)
  end))
end)

M.fs.find = M.promisify_wrap((function()
  local function find(promise, regex, path)
    ---@diagnostic disable-next-line: param-type-mismatch
    local fd, message, _ = vim.uv.fs_opendir(path, nil, 16384) -- 1 << 14
    if not fd then
      promise:reject{ message = message }
      return nil
    end

    local r = {}
    for _, t in ipairs(vim.iter(function() return vim.uv.fs_readdir(fd) end):totable()) do
      for _, e in ipairs(t) do
        if e.type == "directory" then
          local f = find(promise, regex, path .. "/" .. e.name)
          if not f then return nil end
          M.list.merge(r, f)
        elseif vim.fn.match(e.name, regex) > -1 then
          M.list.insert(r, path .. "/" .. e.name)
        end
      end
    end
    vim.uv.fs_closedir(fd)

    return r
  end

  return function(promise, regex, path)
    path = path or ""
    if vim.fn.isabsolutepath(path) == 1 then
      path = vim.fs.normalize(path)
    else
      path = vim.fs.normalize(vim.fn.getcwd() .. "/" .. path)
    end
    local pre = #path + 2

    local f = find(promise, regex, path)
    if not f then return nil end

    return promise:resolve(M.list.map(function(e)
      return string.sub(e, pre)
    end, f))
  end
end)())

-- ------------------------- x ------------------------- --

M.open = {}

M.open.browser = (vim.fn.has("win32") == 1) and function(url)
  return vim.uv.spawn(M.fs.exepath("rundll32"), { args = { "url.dll,FileProtocolHandler", url }, detached = true })
end or ((vim.fn.has("mac") == 1) and function(url)
  return vim.uv.spawn("open", { args = { url }, detached = true })
end or function(url)
  return vim.uv.spawn("xdg-open", { args = { url }, detached = true })
end)

M.open.explorer = (vim.fn.has("win32") == 1) and function(path)
  vim.uv.spawn(M.fs.exepath("explorer"), { args = { path }, detached = true })
end or ((vim.fn.has("mac") == 1) and function(path)
  vim.uv.spawn(M.fs.exepath("open"), { args = { path }, detached = true })
end or function(path)
  for _, e in ipairs{ "xdg-open", "thunar", "dolphin", "nautilus" } do
    local ep = M.fs.exepath(e)
    if ep then
      return vim.uv.spawn(ep, { args = { path }, detached = true })
    end
  end
end)

-- ------------------------- x ------------------------- --

local GIT_DEFAULT_BRANCH = "master"
local GIT_INIT_COMMIT = "init"
local GIT_OPTIONS = { text = true, clear_env = true, timeout = (3 * 60 * 1000) }

M.git = {}

M.git.init = M.promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end

  local go = M.dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })
  local ls = M.fs.ls(o.cwd):await():unwrap()

  if #M.list.filter(function(e) return e.name == ".git" and e.is_directory end, ls) == 1 then
    M.git.config(o):await():unwrap()
    M.notify.warn("Repository already inited")
    return promise:resolve()
  end

  M.sh({ "git", "init", "-b", GIT_DEFAULT_BRANCH }, go):await():unwrap()
  M.git.config(o):await():unwrap()

  if #ls > 0 then
    M.sh({ "git", "add", "-A" }, go):await():unwrap()
    M.sh({ "git", "commit", "-m", GIT_INIT_COMMIT }, go):await():unwrap()
  end

  return promise:resolve()
end)

M.git.clone = M.promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end

  M.fs.mkdir(o.cwd):await():unwrap()
  local cmd = o.shallow and
    { "git", "clone", "--shallow-submodules", "--depth=1", "--progress", "--", o.url, o.cwd } or
    { "git", "clone", "--shallow-submodules", "--progress", "--", o.url, o.cwd }
  M.sh(cmd, M.dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })):await():unwrap()
  return promise:resolve()
end)

M.git.fetch = M.promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end
  M.sh({ "git", "status" }, M.dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })):await():unwrap()

  local cmds = {}
  local function t(cmd) M.list.insert(cmds, cmd) end

  if not o.shallow then
    t(function(_) return { "git", "fetch", "--all" } end)
  elseif o.commit then
    t(function(_) return { "git", "fetch", "origin", "--depth=1", "--progress", o.commit } end)
    t(function(_) return { "git", "reset", "--hard", o.commit } end)
  elseif o.tag then
    t(function(_) return { "git", "fetch", "origin", "--depth=1", "--progress", "--no-tags", "refs/tags/".. o.tag ..":refs/tags/".. o.tag } end)
    t(function(_) return { "git", "tag", "--list", o.tag, "--sort", "-version:refname" } end)
    t(function(r) return { "git", "checkout", "tags/" .. vim.split(r.stdout, "[\r\n]+")[1] } end)
  elseif o.branch then
    t(function(_) return { "git", "fetch", "origin", "--depth=1", "--progress", "+refs/heads/".. o.branch ..":refs/remotes/origin/".. o.branch } end)
    t(function(_) return { "git", "checkout", "origin/"..o.branch } end)
  else
    t(function(_) return { "git", "fetch", "origin", "--depth=1", "--progress" } end)
    t(function(_) return { "git", "ls-remote", "--symref", "origin", "HEAD" } end)
    t(function(r) return { "git", "switch", ({string.gsub(vim.split(r.stdout, "[ \t]")[2], ".+/(.+)$", "%1")})[1] } end)
  end

  if vim.fn.filereadable(o.cwd .. "/.gitmodules") == 1 then
    t(function(_) return { "git", "submodule", "update", "--init", "--recursive", "--depth=1", "--jobs=16" } end)
  end

  local options = M.dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })
  local function run(r, i)
    if r.code ~= 0 then
      return promise:reject{ code = r.code, message = r.stderr }
    end

    local cmd = cmds[i]
    if not cmd then
      return promise:resolve()
    end

    vim.system(cmd(r), options, function(rr) run(rr, i+1) end)
  end
  run({ code = 0 }, 1)
end)

M.git.config = M.promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end
  M.sh({ "git", "status" }, M.dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })):await():unwrap()

  local go = M.dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })

  if o.name then
    M.sh({ "git", "config", "--local", "user.name", o.name }, go):await():unwrap()
  end

  if o.email then
    M.sh({ "git", "config", "--local", "user.email", o.email }, go):await():unwrap()
  end

  if o.url then
    M.sh({ "git", "config", "--local", "remote.origin.url", o.url }, go):await():unwrap()
  end

  return promise:resolve()
end)

-- ------------------------- x ------------------------- --

local Window = {}

function Window:show()
  if vim.api.nvim_win_is_valid(self.win) then return end

  if not vim.api.nvim_buf_is_valid(self.buf) then
    self.buf = vim.api.nvim_create_buf(false, true)
  end

  self.win = vim.api.nvim_open_win(self.buf, self.focus, M.dictionary.merge({
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

function Window:hide()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
    self.win = -1
  end
end

function Window:toggle()
  if vim.api.nvim_win_is_valid(self.win) then
    self:hide()
  else
    self:show()
  end
end

M.window = function(conf)
  assert(conf.size, "Size is missing!")

  local self = {}

  self.zindex = conf.zindex or 25
  self.focus = not not conf.focus
  self.border = conf.border or "rounded"
  self.size = conf.size
  self.on_show = { conf.on_show }
  self.on_resize = { conf.on_resize }
  M.list.insert(self.on_resize, function(_)
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

    M.list.insert(self.on_show, function()
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

  return setmetatable(self, { __index = Window })
end

-- ------------------------- x ------------------------- --

return M
