local ffi = require("ffi")
local C = ffi.C

local Dictionary = {}
local flags = {}
local fs = {}
local git = {}
local List = {}
local notify = {}
local notify_once = {}
local open = {}
local random = {}
local String = {}

local Promise = {}
local RingBuffer = {}
local Window = {}

-- ------------------------- x ------------------------- --

flags.warn_missing_lsp = true
flags.warn_missing_module = true

-- ------------------------- x ------------------------- --

local ENV_BUFFER_SIZE = math.pow(2, 15)
local env = setmetatable({}, {
  __index = function(_, key)
    return vim.uv.os_getenv(key, ENV_BUFFER_SIZE)
  end,
  __newindex = function(_, key, value)
    return vim.uv.os_setenv(key, value)
  end,
})

-- ------------------------- x ------------------------- --

String.format = string.format
String.startswith = function(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end
String.endswith = function(s, suffix)
  return string.sub(s, #s - #suffix + 1, #s) == suffix
end
String.match = function(s, pattern)
  local i = vim.fn.match(s, pattern)
  return i > -1 and (i + 1) or nil
end
String.slice = string.sub
String.split = vim.split
String.substitute = function(s, pattern, sub)
  assert(type(s) == "string", "s: expected string, got " .. type(s))
  local _sub = type(sub) == "function" and function(e)
    if not e then
      return ""
    elseif type("table") then
      return sub(e[1])
    elseif type("string") then
      return sub(e)
    else
      assert(false, "Unexpected type")
    end
  end or sub
  return vim.fn.substitute(s, pattern, _sub, "g")
end
String.upper = string.upper
String.lower = string.lower
String.rep = string.rep
String.reverse = string.reverse

List.contains = vim.tbl_contains
List.join = table.concat
List.sort = function(l, s)
  if s == nil then
    return vim.fn.sort(l, "i")
  elseif type(s) == "function" then
    local r = List.clone(l)
    table.sort(r, s)
    return r
  else
    assert(false, "Sorter must be a function or nil")
  end
end
List.reverse = vim.fn.reverse
List.map = function(fn, l)
  l = List.clone(l)
  local len = 0
  local keys = vim.tbl_keys(l)

  for i = #keys, 1, -1 do
    if type(keys[i]) == "number" then
      len = keys[i]
      break
    end
  end

  for i = 1, len, 1 do
    l[i] = fn(l[i])
  end

  return l
end
List.filter = vim.tbl_filter
List.uniq = function(l)
  local r = {}
  local d = {}
  for _, e in ipairs(l) do
    if not d[e] then
      d[e] = true
      List.insert(r, e)
    end
  end
  return r
end
List.fill = function(l, value, n)
  if type(value) == "table" then
    for i = 1, n, 1 do
      l[i] = vim.deepcopy(value)
    end
  else
    for i = 1, n, 1 do
      l[i] = value
    end
  end
  return l
end
List.slice = vim.list_slice
List.clone = function(t) return vim.list_slice(t, 1, #t) end
List.insert = function(l, ...)
  table.insert(l, ...)
  return l
end
List.push = function(l, e)
  table.insert(l, e)
  return l
end
List.remove = table.remove
List.pop = function(l)
  local r = l[#l]
  l[#l] = nil
  return r
end
List.merge = function(...)
  local r = ({...})[1]
  for _, t in ipairs{...}, {...}, 1 do
    vim.list_extend(r, t)
  end
  return r
end

Dictionary.isempty = vim.tbl_isempty
Dictionary.clone = function(d)
  local r = {}
  for _, k in ipairs(vim.tbl_keys(d)) do
    r[k] = d[k]
  end
  return r
end
Dictionary.deep_clone = vim.deepcopy
Dictionary.keys = vim.tbl_keys
Dictionary.merge = function(...) return vim.tbl_extend("force", ...) end
Dictionary.deep_merge = function(...) return vim.tbl_deep_extend("force", ...) end

-- ------------------------- x ------------------------- --

function RingBuffer:push(value)
  self[self.index] = value
  self.index = self.index % self.capacity + 1
  if self.size < self.capacity then
    self.size = self.size + 1
  end
  return self
end

function RingBuffer:pop()
  if self.size <= 0 then return nil end
  local index = (self.index + self.capacity - 2) % self.capacity + 1
  local r = self[index]
  self.index = index
  self.size = self.size - 1
  return r
end

function RingBuffer:peek()
  if self.size <= 0 then return nil end
  return self[(self.index + self.capacity - 2) % self.capacity + 1]
end

function RingBuffer:totable()
  local start = (self.index - self.size + self.capacity - 1) % self.capacity + 1
  local index = self.index - 1
  if start > index then
    local r = {}

    local count = 1
    for i = index, 1, -1 do
      r[count] = self[i]
      count = count + 1
    end
    for i = self.capacity, start, -1 do
      r[count] = self[i]
      count = count + 1
    end

    return r
  else
    local r = {}
    local count = 1
    for i = index, start, -1 do
      r[count] = self[i]
      count = count + 1
    end
    return r
  end
end

function RingBuffer:fill(value)
  for i = 1, self.capacity, 1 do
    self[i] = value
  end
  self.index = 1
  self.size = self.capacity
  return self
end

function RingBuffer:clear()
  for i = 1, self.capacity, 1 do
    self[i] = nil
  end
  self.index = 1
  self.size = 0
  return self
end

local RingBuffer_constructor = function(capacity)
  assert(type(capacity) == "number", "Capacity must be a number")

  local self = { capacity = capacity }

  self.capacity = capacity
  self.size = 0
  self.index = 1

  return setmetatable(self, { __index = RingBuffer })
end

-- ------------------------- x ------------------------- --

local I, W, E = vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR

notify.info  = vim.schedule_wrap(function(s) vim.notify(s, I) end)
notify.warn  = vim.schedule_wrap(function(s) vim.notify(s, W) end)
notify.error = vim.schedule_wrap(function(s) vim.notify(s, E) end)

notify_once.info  = vim.schedule_wrap(function(s) vim.notify_once(s, I) end)
notify_once.warn  = vim.schedule_wrap(function(s) vim.notify_once(s, W) end)
notify_once.error = vim.schedule_wrap(function(s) vim.notify_once(s, E) end)

local log = function(...)
  local sb = {}
  local len = select("#", ...)
  for i = 1, len, 1 do
    local e = select(i, ...)
    List.insert(sb, vim.inspect(e))
  end
  vim.schedule_wrap(vim.notify)(List.join(sb, "\n"), W)
end

-- ------------------------- x ------------------------- --

local prequire = function(name, fn)
  local status, plugin = pcall(require, name)

  if status then return fn and fn(plugin) end

  if flags.warn_missing_module then
    notify_once.warn("Module '" .. name .. "' not found")
  end
end

local prequire_wrap = function(name, fn)
  return function() return prequire(name, fn) end
end

-- ------------------------- x ------------------------- --

function Promise:resolve(...)
  if not (self.code == nil) then
    return notify.warn("Promise already finished!")
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
      notify.error(self.message)
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
      List.insert(self.awaiting, function()
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
      List.insert(self.awaiting, function() fn(self) end)
    else
      fn(self)
    end
  end)
end

local promisify = function(fn, ...)
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

local promisify_wrap = function(fn)
  return function(...)
    return promisify(fn, ...)
  end
end

-- ------------------------- x ------------------------- --

local term = (vim.fn.has("win32") == 1) and function()
  local shell = vim.go.shell
  local shellxquote = vim.go.shellxquote
  local shellcmdflag = vim.go.shellcmdflag

  local bb = fs.exepath("busybox")
  if bb then
    vim.go.shell = "\"" .. bb .. "\" env \"HOME=" .. env.USERPROFILE .. "\" bash"
    vim.go.shellxquote = ""
    vim.go.shellcmdflag = "-c"
  else
    local ps = fs.exepath("powershell")
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

local sh = promisify_wrap(function(promise, cmd, opts)
  opts = opts or {}
  local text = opts.text
  opts.text = nil

  if vim.fn.isabsolutepath(cmd[1]) then
    -- already normalized
  elseif String.match(cmd[1], (vim.fn.has("win32") == 1) and "[\\\\/]" or "/") then
    return promise:reject("Relative paths are not allowed")
  else
    cmd[1] = fs.exepath(cmd[1])
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

  vim.system(cmd, opts, function(out)
    if (vim.fn.has("win32") == 1) and text then
      promise.stdout = string.gsub(out.stdout or "", "\r\n", "\n")
      promise.stderr = string.gsub(out.stderr or "", "\r\n", "\n")
    else
      promise.stdout = out.stdout or ""
      promise.stderr = out.stderr or ""
    end
    if out.code == 0 then
      return promise:resolve()
    else
      return promise:reject{ code = out.code, message = out.stderr }
    end
  end)
end)

-- ------------------------- x ------------------------- --

local CHARS = String.split("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "")
random.string = function(len)
  local buffer = ffi.new("char [?]", len)
  ffi.copy(buffer, vim.uv.random(len), len)

  for i = 0, len - 1, 1 do
    ffi.copy(buffer+i, CHARS[buffer[i] % #CHARS + 1], 1)
  end
  return ffi.string(buffer, len)
end

random.int = function()
  local buffer = ffi.new("int32_t [1]")
  ffi.copy(buffer, vim.uv.random(4), 4)
  return buffer[0]
end

random.uint = function()
  local buffer = ffi.new("uint32_t [1]")
  ffi.copy(buffer, vim.uv.random(4), 4)
  return buffer[0]
end

-- ------------------------- x ------------------------- --

local TMP_DIR = vim.fn.has("win32") == 0 and
  (env.XDG_RUNTIME_DIR or "/tmp") .. "/tmp." or
  string.gsub(vim.fs.dirname(env.APPDATA) .. "/Local/Temp/tmp.", "/", "\\")

fs.mktmp = promisify_wrap(function(promise)
  while true do
    local r = TMP_DIR .. random.string(10)
    if vim.fn.isdirectory(r) == 0 then
      vim.fn.mkdir(r, "p")
      return promise:resolve(r)
    end
  end
end)

fs.mkdir = promisify_wrap(function(promise, dir)
  local status, result = pcall(vim.fn.mkdir, dir, "p")
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

fs.mkfile = promisify_wrap(function(promise, file, content, opts)
  -- TODO: opts as object
  opts = opts or ""
  fs.mkdir(fs.dirname(file)):await():unwrap()
  local status, result = pcall(vim.fn.writefile, content or {}, file, opts)
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

fs.mklink = promisify_wrap(vim.fn.has("win32") == 1 and function(_, _, _)
  assert(false, "Unsupported platform")
end or function(promise, target, link_name)
  sh{ "ln", "--symbolic", target, link_name }:await():unwrap()
  return promise:resolve()
end)

fs.copy = promisify_wrap(vim.fn.has("win32") == 1 and function(promise, src, dest)
  sh{ "powershell", "Copy-Item", "-recurse", src, "-destination", dest }:await():unwrap()
  return promise:resolve()
end or function(promise, src, dest)
  sh{ "cp", "--recursive", src, dest }:await():unwrap()
  return promise:resolve()
end)

fs.move = promisify_wrap(function(promise, src, dest)
  local status, result = pcall(vim.fn.rename, src, dest)
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

fs.remove = promisify_wrap(function(promise, src)
  -- local status, result = pcall(vim.fs.rm, src, { recursive = true, force = true })
  local status, result = pcall(vim.fn.delete, src, "rf")
  if status then
    return promise:resolve()
  else
    return promise:reject(result)
  end
end)

fs.readfile = promisify_wrap(function(promise, file, opts)
  opts = opts or {}
  local status, result = pcall(vim.fn.readblob, file, opts.offset or 0, opts.size or -1)
  if status then
    if opts.raw then
      return promise:resolve(result)
    else
      return promise:resolve(String.split(result, "\r?\n"))
    end
  else
    return promise:reject(result)
  end
end)

fs.basename = vim.fs.basename

fs.dirname = vim.fn.has("win32") == 1 and function(file)
  local r = vim.fs.dirname(file)
  r = string.gsub(r, "/", "\\")
  return r
end or vim.fs.dirname

fs.relpath = function(base, target)
  return vim.fs.relpath(base, target, {})
end

fs.exepath = (vim.fn.has("win32") == 1) and function(exe)
  ---@diagnostic disable-next-line: missing-parameter, param-type-mismatch
  local ext = String.split(env.PATHEXT, ";")
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, p in ipairs(String.split(env.PATH, ";")) do
    p = string.gsub(vim.fs.normalize(p .. "\\" .. exe), "\\", "/")
    if vim.uv.fs_access(p, "RX") then return p end
    for _, e in ipairs(ext) do
      local pe = p .. e
      if vim.uv.fs_access(pe, "RX") then return pe end
    end
  end
end or function(bin)
  for _, p in ipairs(String.split(env.PATH, ":")) do
    p = vim.fs.normalize(p .. "/" .. bin)
    if vim.uv.fs_access(p, "RX") then return p end
  end
end

fs.ls = promisify_wrap(function(promise, path)
  local C_BUFFER_SIZE = 8192
  local C_BUFFER = ffi.new("char [?]", C_BUFFER_SIZE)

  ---@diagnostic disable-next-line: param-type-mismatch
  local fd, message, _ = vim.uv.fs_opendir(vim.fs.normalize(path), nil, 16384) -- 1 << 14
  if not fd then
    return promise:reject{ message = message }
  end

  local content = vim.uv.fs_readdir(fd) or {}
  for _, t in ipairs(vim.iter(function() return vim.uv.fs_readdir(fd) end):totable()) do
    List.merge(content, t)
  end
  vim.uv.fs_closedir(fd)

  if vim.fn.has("win32") == 1 then
    content = List.filter(function(e) return e.type ~= "link" end, content)
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

  return promise:resolve(List.sort(content, function(a, b)
    if a.is_directory ~= b.is_directory then return a.is_directory end

    local fa, fb = string.sub(a.name, 1, 1) == ".", string.sub(b.name, 1, 1) == "."
    if fa ~= fb then return fb end

    local c = vim.stricmp(a.name, b.name)
    return (c == 0) and (a.name < b.name) or (c == -1)
  end))
end)

fs.find = promisify_wrap((function()
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
          List.merge(r, f)
        elseif vim.fn.match(e.name, regex) > -1 then
          List.insert(r, path .. "/" .. e.name)
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

    return promise:resolve(List.map(function(e)
      return string.sub(e, pre)
    end, f))
  end
end)())

-- ------------------------- x ------------------------- --

open.browser = (vim.fn.has("win32") == 1) and function(url)
  return vim.uv.spawn(fs.exepath("rundll32"), { args = { "url.dll,FileProtocolHandler", url }, detached = true })
end or ((vim.fn.has("mac") == 1) and function(url)
  return vim.uv.spawn("open", { args = { url }, detached = true })
end or function(url)
  return vim.uv.spawn("xdg-open", { args = { url }, detached = true })
end)

open.explorer = (vim.fn.has("win32") == 1) and function(path)
  vim.uv.spawn(fs.exepath("explorer"), { args = { path }, detached = true })
end or ((vim.fn.has("mac") == 1) and function(path)
  vim.uv.spawn(fs.exepath("open"), { args = { path }, detached = true })
end or function(path)
  for _, e in ipairs{ "xdg-open", "thunar", "dolphin", "nautilus" } do
    local ep = fs.exepath(e)
    if ep then
      return vim.uv.spawn(ep, { args = { path }, detached = true })
    end
  end
end)

-- ------------------------- x ------------------------- --

local GIT_DEFAULT_BRANCH = "master"
local GIT_INIT_COMMIT = "init"
local GIT_OPTIONS = { text = true, clear_env = true, timeout = (3 * 60 * 1000) }

git.init = promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end

  local go = Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })
  local ls = fs.ls(o.cwd):await():unwrap()

  if #List.filter(function(e) return e.name == ".git" and e.is_directory end, ls) == 1 then
    git.config(o):await():unwrap()
    notify.warn("Repository already inited")
    return promise:resolve()
  end

  sh({ "git", "init", "-b", GIT_DEFAULT_BRANCH }, go):await():unwrap()
  git.config(o):await():unwrap()

  if #ls > 0 then
    sh({ "git", "add", "-A" }, go):await():unwrap()
    sh({ "git", "commit", "-m", GIT_INIT_COMMIT }, go):await():unwrap()
  end

  return promise:resolve()
end)

git.clone = promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end

  fs.mkdir(o.cwd):await():unwrap()
  local cmd = o.shallow and
    { "git", "clone", "--shallow-submodules", "--depth=1", "--progress", "--", o.url, o.cwd } or
    { "git", "clone", "--shallow-submodules", "--progress", "--", o.url, o.cwd }
  sh(cmd, Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })):await():unwrap()
  return promise:resolve()
end)

git.fetch = promisify_wrap(function(promise, o)
  if not o then o = {} end
  local go = Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd or "." })

  sh({ "git", "status" }, go):await():unwrap()

  if not o.shallow then
    sh({ "git", "fetch", "--all" }, go):await():unwrap()
  elseif o.commit then
    sh({ "git", "fetch", "origin", "--depth=1", "--progress", o.commit }, go):await():unwrap()
    sh({ "git", "reset", "--hard", o.commit }, go):await():unwrap()
  elseif o.tag then
    sh({ "git", "fetch", "origin", "--depth=1", "--progress", "--no-tags", "refs/tags/".. o.tag ..":refs/tags/".. o.tag }, go):await():unwrap()
    local r = sh({ "git", "tag", "--list", o.tag, "--sort", "-version:refname" }, go):await()
    r:unwrap()
    sh({ "git", "checkout", "tags/" .. String.split(r.stdout, "[\r\n]+")[1] }, go):await():unwrap()
  elseif o.branch then
    sh({ "git", "fetch", "origin", "--depth=1", "--progress", "+refs/heads/".. o.branch ..":refs/remotes/origin/".. o.branch }, go):await():unwrap()
    sh({ "git", "checkout", "origin/"..o.branch }, go):await():unwrap()
  else
    sh({ "git", "fetch", "origin", "--depth=1", "--progress" }, go):await():unwrap()
    local r = sh({ "git", "ls-remote", "--symref", "origin", "HEAD" }, go):await()
    r:unwrap()
    sh({ "git", "switch", ({string.gsub(String.split(r.stdout, "[ \t]")[2], ".+/(.+)$", "%1")})[1] }, go):await():unwrap()
  end

  return promise:resolve()
end)

git.config = promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end
  sh({ "git", "status" }, Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })):await():unwrap()

  local go = Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })
  o.cwd = nil

  for _, k in ipairs(Dictionary.keys(o)) do
    assert(List.contains({ "name", "email", "url" }, k), "Unknown option \"" .. k .. "\n")
  end

  if o.name then
    sh({ "git", "config", "--local", "user.name", o.name }, go):await():unwrap()
  end

  if o.email then
    sh({ "git", "config", "--local", "user.email", o.email }, go):await():unwrap()
  end

  if o.url then
    sh({ "git", "config", "--local", "remote.origin.url", o.url }, go):await():unwrap()
  end

  return promise:resolve()
end)

-- ------------------------- x ------------------------- --

function Window:show()
  if vim.api.nvim_win_is_valid(self.win) then return end

  if not vim.api.nvim_buf_is_valid(self.buf) then
    self.buf = vim.api.nvim_create_buf(false, true)
  end

  self.win = vim.api.nvim_open_win(self.buf, self.focus, Dictionary.merge({
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

local Window_constructor = function(conf)
  assert(conf.size, "Size is missing!")

  local self = {}

  self.zindex = conf.zindex or 25
  self.focus = not not conf.focus
  self.border = conf.border or "rounded"
  self.size = conf.size
  self.on_show = { conf.on_show }
  self.on_resize = { conf.on_resize }
  List.insert(self.on_resize, function(_)
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

    List.insert(self.on_show, function()
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

return {
  Dictionary = Dictionary,
  env = env,
  flags = flags,
  fs = fs,
  git = git,
  List = List,
  log = log,
  notify = notify,
  notify_once = notify_once,
  open = open,
  prequire = prequire,
  prequire_wrap = prequire_wrap,
  promisify = promisify,
  promisify_wrap = promisify_wrap,
  random = random,
  RingBuffer = RingBuffer_constructor,
  sh = sh,
  String = String,
  term = term,
  Window = Window_constructor,
}
