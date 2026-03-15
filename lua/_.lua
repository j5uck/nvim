local ffi = require("ffi")
local C = ffi.C

local D = {}
D.TMP = vim.fn.has("win32") == 0 and
  (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/tmp." or
  string.gsub(vim.fs.dirname(vim.env.APPDATA) .. "/Local/Temp/tmp.", "/", "\\")

local M = {}

M.flags = {
  error_promise = false,
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

  if status then return fn and fn(plugin) end

  if M.flags.warn_missing_module then
    M.notify_once.warn("Module '" .. name .. "' not found")
  end
end

M.prequire_wrap = function(name, fn)
  return function() return M.prequire(name, fn) end
end

M.pcall_wrap = function(fn)
  return function(...)
    return pcall(fn, ...)
  end
end

M.promisify = function(fn, ...)
  local promise = {}

  promise.traceback = {
    init = debug.traceback("", 2)
  }
  promise.awaiting = {}
  promise.await = vim.schedule_wrap(function(_fn)
    if promise.code then
      _fn(promise)
    else
      table.insert(promise.awaiting, function() _fn(promise) end)
    end
  end)
  promise.unwrap = function()
    if promise.code ~= 0 then
      error(promise.message)
    end
    return unpack(promise.r)
  end

  promise.resolve = vim.schedule_wrap(function(...)
    promise.code = 0
    promise.r = { ... }
    for _, _fn in ipairs(promise.awaiting) do _fn() end
  end)

  promise.reject = function(message)
    local traceback = debug.traceback("")
    vim.schedule(function()
      promise.code = promise.code or 1
      promise.message = message and message or "Promise rejected"
      if M.flags.error_promise then
        M.notify.error(promise.message .. traceback)
      end
      for _, _fn in ipairs(promise.awaiting) do _fn() end
    end)
  end

  fn(promise, ...)

  return promise
end

M.promisify_wrap = function(fn)
  return function(...)
    return M.promisify(fn, ...)
  end
end

M.async = M.promisify_wrap(function(promise, fn, ...)
  promise.coroutine = coroutine.create(function(...)
    local status, result = pcall(fn, promise, ...)

    if not status then
      return promise.reject(result)
    end

    promise.schedule()

    if promise.code then return end
    M.notify.warn("Promise not resolved" .. promise.traceback.init)
    return promise.resolve()
  end)

  promise.yield = coroutine.yield
  promise.resume = function(...) coroutine.resume(promise.coroutine, ...) end

  promise.schedule = function()
    vim.schedule(promise.resume)
    promise.yield()
  end

  promise.sleep = function(timeout)
    if type(timeout) ~= "number" then
      error("Invalid timeout")
    end
    vim.defer_fn(promise.resume, timeout)
    promise.yield()
  end

  vim.schedule_wrap(coroutine.resume)(promise.coroutine, ...)
end)

M.async_wrap = function(fn)
  return function(...)
    return M.async(fn, ...)
  end
end

M.await = function(promise)
  local co = coroutine.running()
  if not co then
    error("\"await\" can only be used inside an \"async\" function")
  end

  vim.schedule(function()
    if promise.code then
      coroutine.resume(co)
    else
      table.insert(promise.awaiting, function()
        coroutine.resume(co)
      end)
    end
  end)

  coroutine.yield()

  return promise
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

M.fs.mktmp = M.promisify_wrap(function(promise)
  while true do
    local r = D.TMP .. M.random.string(10)
    if vim.fn.isdirectory(r) == 0 then
      vim.fn.mkdir(r, "p")
      return promise.resolve(r)
    end
  end
end)

M.fs.mkdir = M.promisify_wrap(function(promise, dir)
  local status, result = pcall(vim.fn.mkdir, dir, "p")
  if status then
    return promise.resolve()
  else
    return promise.reject(result)
  end
end)

M.fs.mkfile = M.promisify_wrap(function(promise, file, content, flags)
  flags = flags or ""
  M.await(M.fs.mkdir(M.fs.dirname(file))).unwrap()
  local status, result = pcall(vim.fn.writefile, content or {}, file, flags)
  if status then
    return promise.resolve()
  else
    return promise.reject(result)
  end
end)

M.fs.mklink = M.promisify_wrap(vim.fn.has("win32") == 1 and function(_, _, _)
  error("Unsupported platform")
end or function(promise, target, link_name)
  local o = vim.system{ vim.fn.exepath("ln"), "--symbolic", target, link_name }:wait()
  if o.code == 0 then
    return promise.resolve()
  else
    return promise.reject()
  end
end)

M.fs.copy = M.promisify_wrap(vim.fn.has("win32") == 1 and function(promise, src, dest)
  local p = M.await(M.sh{ vim.fn.exepath("powershell"), "Copy-Item", "-recurse", src, "-destination", dest })
  if p.code == 0 then
    return promise.resolve()
  else
    return promise.reject()
  end
end or function(promise, src, dest)
  local p = M.await(M.sh{ vim.fn.exepath("cp"), "--recursive", src, dest })
  if p.code == 0 then
    return promise.resolve()
  else
    return promise.reject()
  end
end)

M.fs.move = M.promisify_wrap(function(promise, src, dest)
  local status, result = pcall(vim.fn.rename, src, dest)
  if status then
    return promise.resolve()
  else
    return promise.reject(result)
  end
end)

M.fs.remove = M.promisify_wrap(function(promise, src)
  -- local status, result = pcall(vim.fs.rm, src, { recursive = true, force = true })
  local status, result = pcall(vim.fn.delete, src, "rf")
  if status then
    return promise.resolve()
  else
    return promise.reject(result)
  end
end)

M.fs.readfile = M.promisify_wrap(function(promise, file, type)
  local status, result = pcall(vim.fn.readfile, file, type)
  if status then
    return promise.resolve(result)
  else
    return promise.reject(result)
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

M.fs.ls = M.promisify_wrap(function(promise, path)
  local C_BUFFER_SIZE = 8192
  local C_BUFFER = ffi.new("char [?]", C_BUFFER_SIZE)

  ---@diagnostic disable-next-line: param-type-mismatch
  local fd, message, _ = vim.uv.fs_opendir(vim.fs.normalize(path), nil, 16384)
  if not fd then
    promise.message = message
    return promise.reject()
  end

  local content = vim.uv.fs_readdir(fd) or {}
  for _, t in ipairs(vim.iter(function() return vim.uv.fs_readdir(fd) end):totable()) do
    vim.list_extend(content, t)
  end
  vim.uv.fs_closedir(fd)

  if vim.fn.has("win32") == 1 then
    content = vim.tbl_filter(function(e) return e.type ~= "link" end, content)
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

  table.sort(content, function(a, b)
    if a.is_directory ~= b.is_directory then return a.is_directory end

    local fa, fb = string.sub(a.name, 1, 1) == ".", string.sub(b.name, 1, 1) == "."
    if fa ~= fb then return fb end

    local c = vim.stricmp(a.name, b.name)
    return c == 0 and a.name < b.name or c == -1
  end)

  return promise.resolve(content)
end)

M.fs.find = M.promisify_wrap((function()
  local function find(regex, path)
    ---@diagnostic disable-next-line: param-type-mismatch
    local fd = vim.uv.fs_opendir(path, nil, 16384)

    local content = vim.uv.fs_readdir(fd) or {}
    for _, t in ipairs(vim.iter(function() return vim.uv.fs_readdir(fd) end):totable()) do
      vim.list_extend(content, t)
    end
    vim.uv.fs_closedir(fd)

    local r = {}

    for _, e in ipairs(content) do
      if e.type == "directory" then
        vim.list_extend(r, find(regex, path .. "/" .. e.name))
      elseif vim.fn.match(e.name, regex) > -1 then
        table.insert(r, path .. "/" .. e.name)
      end
    end

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

    return promise.resolve(vim.tbl_map(function(e)
      return string.sub(e, pre)
    end, find(regex, path)))
  end
end)())

M.sh = M.promisify_wrap(function(promise, cmd, opts)
  local job_opts = {}
  opts = opts or {}
  job_opts.clear_env = true
  job_opts.cwd = opts.cwd
  job_opts.detach = opts.detach
  job_opts.timeout = opts.timeout

  if not string.find(cmd[1], (vim.fn.has("win32") == 1) and "[\\/]" or "/") then
    cmd[1] = vim.fn.exepath(cmd[1])
  end

  if opts.stdout then
    job_opts.on_stdout = function(_, strings, _)
      opts.stdout(strings)
    end
  end
  if opts.stderr then
    job_opts.on_stderr = function(_, strings, _)
      opts.stderr(strings)
    end
  end

  if opts.stdout or opts.stderr then
    job_opts.on_exit = function(_, code, _)
      if code == 0 then
        return promise.resolve()
      else
        promise.code = code
        return promise.reject()
      end
    end

    vim.fn.jobstart(cmd, job_opts)
  else
    vim.system(cmd, job_opts, function(o)
      promise.stdout = o.stdout
      promise.stderr = o.stderr
      if o.code == 0 then
        return promise.resolve()
      else
        promise.code = o.code
        return promise.reject(o.stderr)
      end
    end)
  end
end)

-- M.sh_chained = function(cmd_fns, opts)
--   local promise = {}
--   for _, cmd_fn in ipairs(cmd_fns) do
--     promise = M.await(M.sh(cmd_fn(promise), opts))
--   end
-- end

local GIT_OPTIONS = { text = true, clear_env = true, timeout = (3 * 60 * 1000) }
M.git = {}
-- M.git._clone = function(opts)
--   M.await(M.sh({ "git", "clone", "--shallow-submodules", "--depth=1", "--progress", "--", opts.url, opts.cwd }))
-- end

M.git.clone = M.promisify_wrap(function(promise, o)
  local cmd = { "git", "clone", "--shallow-submodules", "--depth=1", "--progress", "--", o.url, o.cwd }
  vim.system(cmd, GIT_OPTIONS, function(r)
    if r.code == 0 then
      return promise.resolve()
    else
      promise.code = r.code
      return promise.reject(r.stderr)
    end
  end)
end)

M.git.fetch = M.promisify_wrap(function(promise, o)
  local cmds = {}
  local function t(cmd) table.insert(cmds, cmd) end

  if o.commit then
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

  local options = vim.tbl_extend("keep", GIT_OPTIONS, { cwd = o.cwd })
  local function run(r, i)
    if r.code ~= 0 then
      promise.code = r.code
      return promise.reject(r.stderr)
    end

    local cmd = cmds[i]
    if not cmd then
      return promise.resolve()
    end

    vim.system(cmd(r), options, function(rr) run(rr, i+1) end)
  end
  run({ code = 0 }, 1)
end)

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
