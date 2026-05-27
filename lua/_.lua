local ffi = require("ffi")
local C = ffi.C

local M = {}

M.flags = {
  warn_missing_lsp = true,
  warn_missing_module = true,
}

-- ------------------------- x ------------------------- --

M.String = {}
M.String.format = string.format
M.String.startswith = function(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end
M.String.endswith = function(s, suffix)
  return string.sub(s, #s - #suffix + 1, #s) == suffix
end
M.String.match = function(s, pattern)
  local i = vim.fn.match(s, pattern)
  return i > -1 and (i + 1) or nil
end
M.String.slice = string.sub
M.String.split = vim.split
M.String.substitute = function(s, pattern, sub)
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
M.String.upper = string.upper
M.String.lower = string.lower
M.String.rep = string.rep
M.String.reverse = string.reverse

M.List = {}
M.List.contains = vim.tbl_contains
M.List.join = table.concat
M.List.sort = function(l, s)
  if s == nil then
    return vim.fn.sort(l, "i")
  elseif type(s) == "function" then
    local r = M.List.clone(l)
    table.sort(r, s)
    return r
  else
    assert(false, "Sorter must be a function or nil")
  end
end
M.List.reverse = vim.fn.reverse
M.List.map = function(fn, l)
  l = M.List.clone(l)
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
M.List.filter = vim.tbl_filter
M.List.uniq = function(l)
  local r = {}
  local d = {}
  for _, e in ipairs(l) do
    if not d[e] then
      d[e] = true
      M.List.insert(r, e)
    end
  end
  return r
end
M.List.fill = function(l, value, n)
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
M.List.slice = vim.list_slice
M.List.clone = function(t) return vim.list_slice(t, 1, #t) end
M.List.insert = function(l, ...)
  table.insert(l, ...)
  return l
end
M.List.push = function(l, e)
  table.insert(l, e)
  return l
end
M.List.remove = table.remove
M.List.pop = function(l)
  local r = l[#l]
  l[#l] = nil
  return r
end
M.List.merge = function(...)
  local r = ({...})[1]
  for _, t in ipairs{...}, {...}, 1 do
    vim.list_extend(r, t)
  end
  return r
end

M.Dictionary = {}
M.Dictionary.isempty = vim.tbl_isempty
M.Dictionary.clone = function(d)
  local r = {}
  for _, k in ipairs(vim.tbl_keys(d)) do
    r[k] = d[k]
  end
  return r
end
M.Dictionary.deep_clone = vim.deepcopy
M.Dictionary.keys = vim.tbl_keys
M.Dictionary.merge = function(...) return vim.tbl_extend("force", ...) end
M.Dictionary.deep_merge = function(...) return vim.tbl_deep_extend("force", ...) end

-- ------------------------- x ------------------------- --

local RingBuffer = {}

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

M.RingBuffer = function(capacity)
  assert(type(capacity) == "number", "Capacity must be a number")

  local self = { capacity = capacity }

  self.capacity = capacity
  self.size = 0
  self.index = 1

  return setmetatable(self, { __index = RingBuffer })
end

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
    M.List.insert(sb, vim.inspect(e))
  end
  vim.schedule_wrap(vim.notify)(M.List.join(sb, "\n"), W)
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
      M.List.insert(self.awaiting, function()
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
      M.List.insert(self.awaiting, function() fn(self) end)
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

M.once = function(fn)
  local done = false
  return function(...)
    if done then return end
    done = true
    return fn(...)
  end
end

-- ------------------------- x ------------------------- --

M.parse = {}

M.parse.table_to_env = function(o)
  local function sort(a, b)
    local c = vim.stricmp(a[1], b[1])
    return (c == 0) and (a[1] < b[1]) or (c == -1)
  end

  local r = {}
  for k, v in pairs(o) do
    assert(type(k) == "string", "Only dictionaries are allowed")
    assert(type(v) ~= "table", "Tables are not supported")
    M.List.insert(r, { k, vim.json.encode(v) })
  end

  return M.List.map(function(v)
    return v[1] .. "=" .. v[2]
  end, M.List.sort(r, sort))
end

-- local empty_dict_tostring = getmetatable(vim.empty_dict()).__tostring

-- local function table_to_json(o)
--   local r = {}
--
--   local keys = M.List.filter(function(v)
--     return type(v) == "string"
--   end, M.Dictionary.keys(o))
--
--   assert(not (#keys > 0 and #o > 0), "Table must be list or dictionary")
--
--   if #keys > 0 then
--     M.List.insert(r, "{")
--     for _, key in ipairs(M.List.sort(keys)) do
--       M.List.insert(r, vim.json.encode(key))
--       local v = o[key]
--       if type(v) == "table" then
--         M.List.merge(r, table_to_json_tokens(v))
--       else
--         M.List.insert(r, vim.json.encode(v))
--       end
--     end
--     M.List.insert(r, "}")
--   elseif #o > 0 then
--     M.List.insert(r, "[")
--
--     M.List.map(function(e)
--       return 
--     end, M.List.slice(o, 2, #o - 1))
--
--     for i = 1, #o, 1 do
--       local v = o[i]
--       if type(v) == "table" then
--         M.List.merge(r, table_to_json_tokens(v))
--       else
--         M.List.insert(r, vim.json.encode(v))
--       end
--     end
--     M.List.insert(r, "]")
--   elseif getmetatable(o).__tostring == empty_dict_tostring then
--     M.List.insert(r, "{")
--     M.List.insert(r, "}")
--   else
--     M.List.insert(r, "[")
--     M.List.insert(r, "]")
--   end
--
--   return r
-- end

-- local function tokens_to_json(l, i)
--   local r = {}
--
--   if l[i] == "{" then
--     M.List.insert(r, "{")
--
--     while l[i] and l[i] ~= "}" do
--       if l[i] == "{" or l[i] == "[" then
--       else
--         -- M.List.insert(r, "  " .. )
--       end
--     end
--
--     M.List.insert(r, "}")
--   elseif l[i] == "[" then
--     M.List.insert(r, "[")
--
--     while l[i] and l[i] ~= "}" do
--       if l[i] == "{" or l[i] == "[" then
--       else
--         -- M.List.insert(r, "  " .. )
--       end
--     end
--
--     M.List.insert(r, "]")
--   else
--     assert(false, "Unexpected token \"" .. l[i] .. "\n")
--   end
--
--   return r
-- end

-- M.parse.table_to_json = function(o)
--   -- local tokens = table_to_json_tokens(o)
--   -- local r, _ = tokens_to_json(tokens, 0)
--   -- return r
--   return table_to_json(o)
-- end

local function table_to_toml(o, title)
  local primitives = {}
  local objects = {}

  for k, v in pairs(o) do
    assert(type(k) == "string", "Only dictionaries are allowed")
    if type(v) == "table" then
      M.List.merge(objects, table_to_toml(v, title .. k .. "."))
    else
      M.List.insert(primitives, { k, vim.json.encode(v) })
    end
  end

  return M.List.merge({ { title, primitives } }, objects)
end

M.parse.table_to_toml = function(o)
  local function sort(a, b)
    local c = vim.stricmp(a[1], b[1])
    return (c == 0) and (a[1] < b[1]) or (c == -1)
  end

  local parsed = M.List.sort(table_to_toml(o, ""), sort)
  local r = {}
  for _, section in ipairs(parsed) do
    local section_name = section[1]
    local section_value = M.List.sort(section[2], sort)

    if #section_name > 0 then
      M.List.insert(r, "[" .. string.sub(section_name, 1, #section_name - 1) .. "]")
    end

    for _, item in ipairs(section_value) do
      local key = item[1]
      local value = item[2]
      M.List.insert(r, key .. " = " .. value)
    end
    M.List.insert(r, "")
  end

  M.List.remove(r, #r)
  return r
end

-- ------------------------- x ------------------------- --

M.term = (vim.fn.has("win32") == 1) and function()
  local shell = vim.go.shell
  local shellxquote = vim.go.shellxquote
  local shellcmdflag = vim.go.shellcmdflag

  local bb = M.fs.exepath("busybox")
  if bb then
    vim.go.shell = "\"" .. bb .. "\" env \"HOME=" .. M.env.USERPROFILE .. "\" bash"
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

  if vim.fn.isabsolutepath(cmd[1]) then
    -- already normalized
  elseif M.String.match(cmd[1], (vim.fn.has("win32") == 1) and "[\\\\/]" or "/") then
    return promise:reject("Relative paths are not allowed")
  else
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

M.random = {}

local CHARS = M.String.split("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "")
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

local ENV_BUFFER_SIZE = math.pow(2, 15)
M.env = setmetatable({}, {
  __index = function(_, key)
    return vim.uv.os_getenv(key, ENV_BUFFER_SIZE)
  end,
  __newindex = function(_, key, value)
    return vim.uv.os_setenv(key, value)
  end,
})

-- ------------------------- x ------------------------- --

M.fs = {}

local TMP_DIR = vim.fn.has("win32") == 0 and
  (M.env.XDG_RUNTIME_DIR or "/tmp") .. "/tmp." or
  string.gsub(vim.fs.dirname(M.env.APPDATA) .. "/Local/Temp/tmp.", "/", "\\")

M.fs.mktmp = M.promisify_wrap(function(promise)
  while true do
    local r = TMP_DIR .. M.random.string(10)
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

M.fs.readfile = M.promisify_wrap(function(promise, file, opts)
  opts = opts or {}
  local status, result = pcall(vim.fn.readblob, file, opts.offset or 0, opts.size or -1)
  if status then
    if opts.raw then
      return promise:resolve(result)
    else
      return promise:resolve(M.String.split(result, "\r?\n"))
    end
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
  ---@diagnostic disable-next-line: missing-parameter, param-type-mismatch
  local ext = M.String.split(M.env.PATHEXT, ";")
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, p in ipairs(M.String.split(M.env.PATH, ";")) do
    p = string.gsub(vim.fs.normalize(p .. "\\" .. exe), "\\", "/")
    if vim.uv.fs_access(p, "RX") then return p end
    for _, e in ipairs(ext) do
      local pe = p .. e
      if vim.uv.fs_access(pe, "RX") then return pe end
    end
  end
end or function(bin)
  for _, p in ipairs(M.String.split(M.env.PATH, ":")) do
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
    M.List.merge(content, t)
  end
  vim.uv.fs_closedir(fd)

  if vim.fn.has("win32") == 1 then
    content = M.List.filter(function(e) return e.type ~= "link" end, content)
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

  return promise:resolve(M.List.sort(content, function(a, b)
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
          M.List.merge(r, f)
        elseif vim.fn.match(e.name, regex) > -1 then
          M.List.insert(r, path .. "/" .. e.name)
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

    return promise:resolve(M.List.map(function(e)
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

  local go = M.Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })
  local ls = M.fs.ls(o.cwd):await():unwrap()

  if #M.List.filter(function(e) return e.name == ".git" and e.is_directory end, ls) == 1 then
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
  M.sh(cmd, M.Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })):await():unwrap()
  return promise:resolve()
end)

M.git.fetch = M.promisify_wrap(function(promise, o)
  if not o then o = {} end
  local go = M.Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd or "." })

  M.sh({ "git", "status" }, go):await():unwrap()

  if not o.shallow then
    M.sh({ "git", "fetch", "--all" }, go):await():unwrap()
  elseif o.commit then
    M.sh({ "git", "fetch", "origin", "--depth=1", "--progress", o.commit }, go):await():unwrap()
    M.sh({ "git", "reset", "--hard", o.commit }, go):await():unwrap()
  elseif o.tag then
    M.sh({ "git", "fetch", "origin", "--depth=1", "--progress", "--no-tags", "refs/tags/".. o.tag ..":refs/tags/".. o.tag }, go):await():unwrap()
    local r = M.sh({ "git", "tag", "--list", o.tag, "--sort", "-version:refname" }, go):await()
    r:unwrap()
    M.sh({ "git", "checkout", "tags/" .. M.String.split(r.stdout, "[\r\n]+")[1] }, go):await():unwrap()
  elseif o.branch then
    M.sh({ "git", "fetch", "origin", "--depth=1", "--progress", "+refs/heads/".. o.branch ..":refs/remotes/origin/".. o.branch }, go):await():unwrap()
    M.sh({ "git", "checkout", "origin/"..o.branch }, go):await():unwrap()
  else
    M.sh({ "git", "fetch", "origin", "--depth=1", "--progress" }, go):await():unwrap()
    local r = M.sh({ "git", "ls-remote", "--symref", "origin", "HEAD" }, go):await()
    r:unwrap()
    M.sh({ "git", "switch", ({string.gsub(M.String.split(r.stdout, "[ \t]")[2], ".+/(.+)$", "%1")})[1] }, go):await():unwrap()
  end

  return promise:resolve()
end)

M.git.config = M.promisify_wrap(function(promise, o)
  if not o then o = {} end
  if not o.cwd then o.cwd = "." end
  M.sh({ "git", "status" }, M.Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })):await():unwrap()

  local go = M.Dictionary.merge(GIT_OPTIONS, { cwd = o.cwd })
  o.cwd = nil

  for _, k in ipairs(M.Dictionary.keys(o)) do
    assert(M.List.contains({ "name", "email", "url" }, k), "Unknown option \"" .. k .. "\n")
  end

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

  self.win = vim.api.nvim_open_win(self.buf, self.focus, M.Dictionary.merge({
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

M.Window = function(conf)
  assert(conf.size, "Size is missing!")

  local self = {}

  self.zindex = conf.zindex or 25
  self.focus = not not conf.focus
  self.border = conf.border or "rounded"
  self.size = conf.size
  self.on_show = { conf.on_show }
  self.on_resize = { conf.on_resize }
  M.List.insert(self.on_resize, function(_)
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

    M.List.insert(self.on_show, function()
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
