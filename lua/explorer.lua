local notify, fs, random, window = (function()
  local _ = require("_")
  return _.notify, _.fs, _.random, _.window
end)()

local ffi = require("ffi")
local C = ffi.C

if vim.fn.has("win32") == 1 then
  ffi.cdef[[
    // DWORD GetLogicalDriveStrings(DWORD, LPWSTR);
    int32_t GetLogicalDriveStringsA(int32_t, char *);
  ]]
else
  ffi.cdef[[
    size_t readlink(const char *restrict, char *restrict, size_t);
    int stat(const char *restrict, void *restrict);
  ]]
end

local C_BUFFER_SIZE = 8192
local C_BUFFER = ffi.new("char [?]", C_BUFFER_SIZE)
local BUFFERS = {}
local BUFFERS_BY_PATH = {}
local PATHS = {}
local NS = vim.api.nvim_create_namespace("")

vim.filetype.add{ pattern = { ["file://.*"] = { "lua-explorer", { priority = 10 } } } }

local w = window{
  on_show = function(self)
    vim.api.nvim_create_autocmd("WinLeave", {
      callback = function() self:hide() end,
      once = true
    })
  end,
  size = function()
    local width = math.min(vim.o.columns - 8, math.min(80, vim.o.columns))
    local height = vim.o.lines - 8

    return {
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2) - 1,
      row = math.floor((vim.o.lines - height) / 2) - 1
    }
  end,
  border = "rounded",
  focus = true,
}

local getcwd = (vim.fn.has("win32") == 1) and function()
  local r = string.gsub(vim.fn.getcwd() .. "\\", "\\+", "/")
  return r
end or function()
  local r = string.gsub(vim.fn.getcwd() .. "/", "/+", "/")
  return r
end

local M = {}

local ESCAPE_CHARACTER = vim.fn.has("win32") == 1 and {
  { "\\", "/"  },
  { "\n", "%n" },
  { "\r", "%r" },
  { "%",  "%%" }
} or {
  { "\\", "%s" },
  { "\n", "%n" },
  { "\r", "%r" },
  { "%",  "%%" }
}

local ENCODE_TABLE, DECODE_TABLE = {}, {}
for _, c in ipairs(ESCAPE_CHARACTER) do
  ENCODE_TABLE[c[1]] = c[2]
  DECODE_TABLE[c[2]] = c[1]
end

M.encode = function(s)
  local r = string.gsub(s, "[\\\n\r%%]", function(c) return ENCODE_TABLE[c] end)
  return r
end

M.decode = (vim.fn.has("win32") == 1) and function(s)
  return vim.fn.substitute(s, [[\(%.\|/\)]], function(c)
    return DECODE_TABLE[c[1]]
  end, "g")
end or function(s)
  local r = string.gsub(s, "%%.", function(c) return DECODE_TABLE[c] end)
  return r
end

local PREFIX = vim.fn.has("win32") == 1 and "file://" or "file:/"
local PATTERN = "file://*"

M.URL_to_path = function(url) return M.decode(string.sub(url, #PREFIX + 1)) end
M.path_to_URL = function(p) return M.encode(PREFIX .. p) end

local parse__is_dir = (vim.fn.has("win32") == 1) and function(str)
  return vim.endswith(str, "\\")
end or function(str)
  return vim.endswith(str, "/")
end

M.parse = function(line)
  local r = {}
  local left, right

  left, right = line:match("^/(%d+).+%%0 (.+)$")
  if left then
    left = tonumber(left)
    if left ~= 0 then
      r.id = left
    end
    line = right
  else
    if string.match(line, "%%0") then return nil end
  end

  left, right = line:match("^(.+) %%=> (.+)$")
  if left then
    r.name = M.decode(left)
    r.link = M.decode(right)
  else
    if string.match(line, "%%=>") then return nil end
    if line == "" then return nil end
    r.name = M.decode(line)
  end

  if parse__is_dir(r.name) then
    r.is_directory = true
    r.name = string.sub(r.name, 1, #r.name - 1)
  else
    r.is_directory = false
  end

  return r
end

-- TODO: remove pcalls
local _go = vim.fn.has("win32") == 1 and function(dir)
  M.dir = string.gsub(dir, "/", "\\")
  w:show()
  pcall(vim.cmd.edit, { vim.fn.fnameescape(M.path_to_URL(dir)) })
end or function(dir)
  M.dir = dir
  w:show()
  pcall(vim.cmd.edit, { vim.fn.fnameescape(M.path_to_URL(dir)) })
end

M.go = function(d)
  M.go = _go
  _go(d or getcwd())
end

local select__is_root = (vim.fn.has("win32") == 1) and function(str)
  return string.match(str, "^%w:\\$")
end or function(str)
  return str == "/"
end

M.select = function()
  local lnum = vim.api.nvim_win_get_cursor(w.win)[1]
  local line = vim.api.nvim_buf_get_lines(w.buf, lnum - 1, lnum, true)[1]
  if not line then return end

  local entry = M.parse(line)
  if not entry then return end

  local link = entry.link and (vim.fn.isabsolutepath(entry.link) == 1 and entry.link or (M.dir .. entry.link))
  local url = link or (M.dir .. entry.name)

  if entry.is_directory then
    local dest = vim.fs.normalize(url)
    if select__is_root(dest) then
      M.go(dest)
    else
      M.go(dest.."/")
    end
    return
  end

  w:hide()
  pcall(vim.cmd.edit, { vim.fn.fnameescape(vim.fs.normalize(url)) })
end

vim.api.nvim_create_autocmd("BufHidden", {
  pattern = PATTERN,
  nested = true,
  callback = vim.schedule_wrap(function()
    if vim.api.nvim_win_is_valid(w.win) then return end
    local bufs = vim.tbl_filter(vim.api.nvim_buf_is_loaded, vim.tbl_map(function(b)
      return b[1]
    end, BUFFERS))

    for _, id in ipairs(bufs) do
      if vim.bo[id].modified then return end
    end

    for _, id in ipairs(bufs) do
      pcall(vim.api.nvim_buf_delete, id, { force = true })
    end

    BUFFERS = {}
    BUFFERS_BY_PATH = {}
    PATHS = {}
  end)
})

local function ls(dir)
  ---@diagnostic disable-next-line: param-type-mismatch
  local fd = vim.uv.fs_opendir(vim.fs.normalize(dir), nil, 16384)

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

    e.link = ffi.string(C_BUFFER, C.readlink(dir..e.name, C_BUFFER, C_BUFFER_SIZE))
    local link_full = vim.fs.normalize(vim.fn.isabsolutepath(e.link) == 1 and e.link or (dir .. "/" .. e.link))

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

  return content
end

local HL = {
  DIRECTORY   = "Directory",
  FILE        = "Normal",
  HIDDEN      = "Comment",
  -- LINK        = "Special", -- "Function",  "DiagnosticOk"
  LINK_ORPHAN = "DiagnosticError",
  SOCKET      = "Keyword"
}

local function fn_BufReadCmd()
  local status, devicons = pcall(require, "nvim-web-devicons")
  if not status then devicons = nil end

  vim.bo.bufhidden  = "hide"
  vim.bo.buflisted  = false
  vim.bo.buftype    = "acwrite"
  vim.bo.filetype   = "lua-explorer"
  vim.bo.modifiable = true
  vim.bo.swapfile   = false
  vim.bo.syntax     = "lua-explorer"
  vim.bo.undolevels = -1

  vim.wo.concealcursor  = "nvic"
  vim.wo.conceallevel   = 3
  vim.wo.cursorcolumn   = false
  vim.wo.cursorline     = false
  vim.wo.foldcolumn     = "0"
  vim.wo.list           = false
  vim.wo.number         = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn     = "no"
  vim.wo.spell          = false
  vim.wo.wrap           = false

  local list, is_modifiable

  if #M.dir == 0 and (vim.fn.has("win32") == 1) then
    list = vim.tbl_map(function(name)
      return {
        is_directory = true,
        name = string.sub(name, 1, #name - 1),
        type = "directory"
      }
    end, vim.split(ffi.string(C_BUFFER, C.GetLogicalDriveStringsA(C_BUFFER_SIZE, C_BUFFER)), "\0", { trimempty = true }))

    is_modifiable = false
  else
    list = ls(M.dir)

    local ft = vim.fn.getftype(M.dir)
    if #ft == 0 then return true end
    if ft ~= "dir" then return false end
    is_modifiable = not not vim.uv.fs_access(M.dir, "W")
  end

  local hls = {}
  local text = {}
  for i, e in ipairs(list) do
    local _i = i - 1
    local line = {}
    local line_len = 0
    local function add(txt, hl)
      if hl then
        table.insert(hls, {
          line = _i,
          col_start = line_len,
          end_col = line_len + #txt,
          group = hl
        })
      end
      line_len = line_len + #txt + 1
      table.insert(line, txt)
    end

    table.insert(PATHS, M.dir .. e.name)
    add(("/%016d"):format(#PATHS))
    e.id = #PATHS

    local is_link = e.type == "link"

    if e.is_directory then
      add(" ", HL.DIRECTORY)
    elseif devicons then
      local icon, icon_hl = devicons.get_icon(vim.fs.normalize(e.name))
      if not icon and is_link then
        local t = vim.split(e.link, "/", { trimempty=true })
        icon, icon_hl = devicons.get_icon(t[#t])
      end
      add(icon and (icon.." ") or " ", icon_hl)
    else
      add(" ")
    end

    add("%0")

    local name = e.name .. (e.is_directory and "/" or "")
    add(M.encode(name), (vim.startswith(e.name, ".") and HL.HIDDEN) or (e.is_directory and HL.DIRECTORY) or nil)

    if is_link then
      add("%=>", HL.HIDDEN)
      add(e.link, e.link_exists and HL.HIDDEN or HL.LINK_ORPHAN)
    end

    table.insert(text, table.concat(line, " "))
  end

  vim.api.nvim_buf_set_lines(w.buf, 0, -1, false, text)

  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(w.buf, NS, hl.line, hl.col_start, {
      end_col = hl.end_col,
      hl_group = hl.group,
      strict = false,
    })
  end

  vim.bo.undolevels = vim.api.nvim_get_option_value("undolevels", { scope = "global" })
  vim.bo.modifiable = is_modifiable
  vim.bo.modified   = false

  if not is_modifiable then return end

  local list_directory = {}

  for _, e in ipairs(list) do
    list_directory[e.name] = e
  end

  BUFFERS[#BUFFERS][2] = list_directory
  vim.cmd.clearjumps()
end

local function fn_BufWriteCmd__parse_buffers()
  local ENTRY_BUFFER

  local is_entry_dupped = (vim.fn.has("win32") == 1 or vim.fn.has("mac") == 1) and function(name)
    name = string.lower(name)
    if ENTRY_BUFFER[name] then return true end
    ENTRY_BUFFER[name] = true
    return false
  end or function(name)
    if ENTRY_BUFFER[name] then return true end
    ENTRY_BUFFER[name] = true
    return false
  end

  local error = false
  local r = {}

  for _, b in ipairs(BUFFERS) do
    local id = b[1]
    if not vim.api.nvim_buf_is_loaded(id) then
      goto continue
    elseif not vim.bo[id].modified then
      goto continue
    end

    local string_builder = {}
    ENTRY_BUFFER = {}

    local buffer_ls = vim.tbl_filter(function(v)
      return v ~= ""
    end, vim.api.nvim_buf_get_lines(id, 0, -1, true))

    buffer_ls = vim.tbl_map(function(f)
      local t = M.parse(f)
      if not t or string.match(t.name, "/") then
        table.insert(string_builder, "  PARSING ERROR:\n    >> " .. f)
        error = true
      elseif is_entry_dupped(t.name) then
        table.insert(string_builder, "  ENTRY ALREADY EXISTS:\n    >> " .. f)
        error = true
      else
        return t
      end
    end, buffer_ls)

    if error then
      if #string_builder > 0 then
        notify.error(vim.api.nvim_buf_get_name(id) .. "\n" .. table.concat(string_builder, "\n"))
      end
      goto continue
    end

    local p = M.URL_to_path(vim.api.nvim_buf_get_name(id))
    table.insert(r, { string.sub(p, 1, #p - 1), buffer_ls, b[2] })

    ::continue::
  end

  return error, r
end

local function fn_BufWriteCmd()
  local slash = vim.fn.has("win32") == 1 and "\\" or "/"
  local TASK_FILES = {} -- { { copy, remove, gone } ... }
  local TASKS = {}

  local TASK = {
    MKMDIR = 1, -- fn( dest )
    MKFILE = 2, -- fn( dest )
    MKLINK = 3, -- fn( dest, link )
    COPY   = 4, -- fn( src, dest )
    REMOVE = 5  -- fn( src )
  }

  local function APPENT_TASK(args)
    if args[1] == TASK.COPY then
      if not TASK_FILES[args[2]] then
        TASK_FILES[args[2]] = { copy = 1 }
      else
        TASK_FILES[args[2]].copy = TASK_FILES[args[2]].copy + 1
      end
      table.insert(TASKS, args)
    elseif args[1] == TASK.REMOVE then
      if not TASK_FILES[args[2]] then
        TASK_FILES[args[2]] = { copy = 0 }
      end
      TASK_FILES[args[2]].remove = true
      table.insert(TASKS, args)
    else
      table.insert(TASKS, args)
    end
  end

  local error, buffers_ls = fn_BufWriteCmd__parse_buffers()
  if error then return end

  for _, b in ipairs(buffers_ls) do
    -- b => { name, new_info, old_info }
    local buffer_name, cached_info = b[1], vim.tbl_extend("force", {}, b[3])

    for _, entry in ipairs(b[2]) do
      local entry_path = PATHS[entry.id]
      local cached_entry = (entry.id and BUFFERS_BY_PATH[fs.dirname(entry_path)][2][fs.basename(entry_path)]) or {}
      local to_continue =
          cached_entry.id == entry.id and
          cached_entry.name == entry.name and
          cached_entry.link == entry.link and
          (entry.link or (cached_entry.is_directory == entry.is_directory)) and
          fs.dirname(entry_path) == buffer_name

      -- no changes --
      if to_continue then
        cached_info[entry.name] = nil
        local src = PATHS[entry.id]
        if not TASK_FILES[src] then
          TASK_FILES[src] = { copy = 1 }
        else
          TASK_FILES[src].copy = TASK_FILES[src].copy + 1
        end
        goto continue
      end

      local full_path = buffer_name .. slash .. entry.name
      if not entry.id then
        if entry.link then
          if vim.fn.isabsolutepath(entry.link) then
            APPENT_TASK{ TASK.MKLINK, entry.link, full_path }
          else
            APPENT_TASK{ TASK.MKLINK, buffer_name .. slash .. entry.link, full_path }
          end
        elseif entry.is_directory then
          APPENT_TASK{ TASK.MKMDIR, full_path }
        else
          APPENT_TASK{ TASK.MKFILE, full_path }
        end
        goto continue
      end

      -- if entry.id --
      local src_buffer = BUFFERS_BY_PATH[fs.dirname(PATHS[entry.id])]
      local src_file = fs.basename(PATHS[entry.id])
      if entry.link then
        if src_buffer[2][src_file].link == entry.link then
          APPENT_TASK{ TASK.COPY, PATHS[entry.id], full_path }
        else
          APPENT_TASK{ TASK.REMOVE, PATHS[entry.id] }
          if vim.fn.isabsolutepath(entry.link) then
            APPENT_TASK{ TASK.MKLINK, entry.link, full_path }
          else
            APPENT_TASK{ TASK.MKLINK, buffer_name .. slash .. entry.link, full_path }
          end
        end
      elseif entry.is_directory then
        if cached_entry.is_directory then
          APPENT_TASK{ TASK.COPY, PATHS[entry.id], full_path }
        else
          APPENT_TASK{ TASK.REMOVE, PATHS[entry.id] }
          APPENT_TASK{ TASK.MKMDIR, full_path }
        end
      else
        if not cached_entry.is_directory and not cached_entry.link then
          APPENT_TASK{ TASK.COPY, PATHS[entry.id], full_path }
        else
          APPENT_TASK{ TASK.REMOVE, PATHS[entry.id] }
          APPENT_TASK{ TASK.MKFILE, full_path }
        end
      end
      ::continue::
    end
    for k, _ in pairs(cached_info) do
      APPENT_TASK{ TASK.REMOVE, buffer_name .. slash .. k }
    end
  end

  local undodir = vim.fs.normalize(vim.o.undodir)
  local last_move = {}

  for _, t in ipairs(TASKS) do
    if t[1] == TASK.REMOVE then
      local tf = TASK_FILES[t[2]]
      if tf.copy == 0 and not tf.gone then
        fs.remove(t[2])
        tf.gone = true
        if vim.fn.isdirectory(t[2]) == 1 then
          local dir = string.sub(vim.fn.undofile(t[2]), #undodir + 2)
          for _, f in ipairs(vim.fn.globpath(undodir, dir .. "*", 1, true, 1)) do
            fs.remove(f)
          end
        else
          fs.remove(vim.fn.undofile(t[2]))
        end
      end
    else
      local dest = t[#t]
      if vim.uv.fs_stat(dest) then
        local tmp_path = dest .. ".tmp_" .. random.string(10) .. ".bak"
        t[#t] = tmp_path
        table.insert(last_move, { tmp_path, dest })
      end
      if t[1] == TASK.MKMDIR then
        fs.mkdir(t[2])
      elseif t[1] == TASK.MKFILE then
        fs.mkfile(t[2])
      elseif t[1] == TASK.MKLINK then
        fs.mklink(t[2], t[3])
      elseif t[1] == TASK.COPY then
        local tf = TASK_FILES[t[2]]
        tf.copy = tf.copy - 1
        if tf.remove and tf.copy == 0 then
          fs.move(t[2], t[3])
          tf.gone = true
        else
          fs.copy(t[2], t[3])
        end
        local action = tf.gone and fs.move or fs.copy
        if vim.fn.isdirectory(t[3]) == 1 then
          local src_dir = string.sub(vim.fn.undofile(t[2]), #undodir + 2)
          local trim_len = #undodir + 2 + #src_dir
          for _, f in ipairs(vim.fn.globpath(undodir, src_dir .. "*", 1, true, 1)) do
            action(f, vim.fn.undofile(t[3]) .. string.sub(f, trim_len))
          end
        else
          local src_undo = vim.fn.undofile(t[2])
          if vim.uv.fs_stat(src_undo) then
            action(src_undo, vim.fn.undofile(t[3]))
          end
        end
      end
    end
  end

  for _, lm in ipairs(last_move) do
    fs.move(lm[1], lm[2])
    if vim.fn.isdirectory(lm[2]) == 1 then
      local src_dir = string.sub(vim.fn.undofile(lm[1]), #undodir + 2)
      local trim_len = #undodir + 2 + #src_dir
      for _, f in ipairs(vim.fn.globpath(undodir, src_dir .. "*", 1, true, 1)) do
        fs.move(f, vim.fn.undofile(lm[2]) .. string.sub(f, trim_len))
      end
    else
      local src_undo = vim.fn.undofile(lm[1])
      if vim.uv.fs_stat(src_undo) then
        fs.move(src_undo, vim.fn.undofile(lm[2]))
      end
    end
  end

  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, b)
  vim.bo[b].filetype = "lua-explorer"

  for _, id in ipairs(BUFFERS) do
    pcall(vim.api.nvim_buf_delete, id[1], { force = true })
  end

  BUFFERS = {}
  BUFFERS_BY_PATH = {}
  PATHS = {}

  M.history.skip = true
  vim.schedule_wrap(M.go)(M.dir)
end

vim.api.nvim_create_autocmd("BufWriteCmd", {
  pattern = PATTERN,
  callback = fn_BufWriteCmd
})

vim.api.nvim_create_autocmd({ "CursorMovedI", "CursorMoved", "ModeChanged" }, {
  pattern = PATTERN,
  callback = function(ev)
    local y, x = unpack(vim.api.nvim_win_get_cursor(0))
    local padding = vim.fn.match(vim.api.nvim_buf_get_lines(ev.buf, y - 1, y, true)[1] or "","%0\\zs\\C") + 1

    if x < padding then
      vim.api.nvim_win_set_cursor(0, { y, padding })
    end
  end
})

local insert_buffer = vim.fn.has("win32") == 1 and function(id)
  local b = { id, nil }
  table.insert(BUFFERS, b)
  if (#M.dir == 0) or string.match(M.dir,"^%w:\\$") then
    BUFFERS_BY_PATH[M.dir] = b
  else
    BUFFERS_BY_PATH[string.sub(M.dir, 1, #M.dir -1)] = b
  end
end or function(id)
  local b = { id, nil }
  table.insert(BUFFERS, b)
  if M.dir == "/" then
    BUFFERS_BY_PATH[M.dir] = b
  else
    BUFFERS_BY_PATH[string.sub(M.dir, 1, #M.dir -1)] = b
  end
end

M.is_timeout = false
M.history = { CAPACITY = 16, size = 0, index = 0, offset = 0, list = {}, skip = false }

vim.api.nvim_create_autocmd({ "BufEnter", "BufReadCmd" }, {
  pattern = PATTERN,
  callback = vim.schedule_wrap(function(ev)
    if M.is_timeout then
      return
    else
      M.is_timeout = true
      vim.schedule(function() M.is_timeout = false end)
    end

    if not vim.api.nvim_win_is_valid(w.win) then
      -- when :e file://...
      if vim.bo[ev.buf].filetype ~= "lua-explorer" then
        vim.cmd[[exe "norm \<c-o>"]]
        if ev.file == vim.api.nvim_buf_get_name(0) then
          vim.api.nvim_buf_set_name(0, "")
        end
        M.go(M.URL_to_path(ev.file))
      -- when nvim is closing and there is buffers with changes
      else
        vim.cmd.clearjumps()
        local win = vim.api.nvim_get_current_win()
        w:show()
        vim.api.nvim_win_set_buf(w.win, ev.buf)
        vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(false, true))
      end

      return
    end

    w.buf = ev.buf

    local isParsedBuffer = ev.event == "BufEnter"
    if not isParsedBuffer then insert_buffer(ev.buf) end

    vim.api.nvim_win_set_config(w.win, {
      title = " " .. vim.fn.fnamemodify(M.encode(M.dir), ":~") .. " ",
      title_pos = "center"
    })

    local h = M.history
    if h.skip or (M.dir == h.list[h.index]) then
      -- do nothing --
    else
      if h.index == h.CAPACITY then
        h.offset = (h.offset + 1) % h.CAPACITY
      end
      h.size = math.min(h.CAPACITY, h.index+1)
      h.index = h.size
      h.list[(h.index-1 + h.offset) % h.CAPACITY + 1] = M.dir
    end
    h.skip = false

    if not isParsedBuffer then
      local s, m = pcall(vim.api.nvim_buf_call, ev.buf, fn_BufReadCmd)
      if not s then notify.error(m) end
    end
  end)
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = (vim.fn.has("win32") == 0) and "/*" or "[A-Z]:/*",
  callback = vim.schedule_wrap(function(ev)
    if vim.fn.isdirectory(ev.file) == 0 then return end
    vim.cmd[[exe "norm \<c-o>"]]
    if ev.file == vim.api.nvim_buf_get_name(0) then
      vim.api.nvim_buf_set_name(0, "")
    end
    local slash = vim.fn.has("win32") == 1 and "\\" or "/"
    M.go(string.sub(ev.file, -1) == slash and ev.file or (ev.file .. slash))
  end)
})

return {
  open = function() M.go(getcwd()) end,
  resume = function() M.go(M.dir) end,
  select = M.select,

  open_on_explorer = vim.fn.has("win32") == 1 and function()
    vim.uv.spawn(vim.fn.exepath[[explorer]], { args = { M.dir }, detached = true })
  end or (vim.fn.has("mac") == 1 and function()
    -- TODO: test it
    vim.uv.spawn(vim.fn.exepath[[open]], { args = { M.dir }, detached = true })
  end or function()
    for _, e in ipairs{ "thunar", "dolphin", "nautilus" } do
      local ep =  vim.fn.exepath(e)
      if string.len(ep) > 0 then
        return vim.uv.spawn(ep, { args = { M.dir }, detached = true })
      end
    end
    notify.error("Explorer not found")
  end),

  buf_get_name = function()
    return M.URL_to_path(vim.api.nvim_buf_get_name(0))
  end,

  go_up = vim.fn.has("win32") == 1 and function()
    if (#M.dir == 0) or string.match(M.dir,"^%w:\\$") then
      M.go("")
    else
      local p = string.gsub(vim.fs.normalize(M.dir .. "..") .. "/", "/+", "/")
      M.go(p)
    end
  end or function()
    local d = vim.fs.normalize(M.dir .. "..")
    M.go(d == "/" and d or (d .. "/"))
  end,

  go_back = function()
    local h = M.history
    if h.index == 1 then return end
    h.skip = true
    h.index = h.index-1
    M.go(h.list[(h.index-1 + h.offset) % h.CAPACITY + 1])
  end,

  go_next = function()
    local h = M.history
    if h.size == h.index then return end
    h.skip = true
    h.index = h.index+1
    M.go(h.list[(h.index-1 + h.offset) % h.CAPACITY + 1])
  end
}

