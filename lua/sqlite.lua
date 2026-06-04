local List, notify, promisify_wrap, fs, sh, String = (function()
  local _ = require("_")
  return _.List, _.notify, _.promisify_wrap, _.fs, _.sh, _.String
end)()

local log = require("_").log

local NS = vim.api.nvim_create_namespace("")
local M = {}

vim.filetype.add{ pattern = { ["sqlite://.*"] = { "lua-sqlite", { priority = 10 } } } }

M.path = {}
M.path.encode = function(file, ...)
  local p = fs.getabsolutepath(file)
  if vim.fn.has("win32") == 1 then
    p = String.slice(p, 1, 1) .. "/" .. String.slice(p, 4)
    p = String.substitute(p, "\\\\", "/")
    return "sqlite://" .. p .. "//" .. List.join({ ... }, "/")
  else
    return "sqlite:/" .. p .. "//" .. List.join({ ... }, "/")
  end
end

M.path.decode = function(path)
  local r = {}
  local e = String.split(path, "//")

  if vim.fn.has("win32") == 1 then
    r.file = String.slice(e[2], 1, 1) .. ":\\" .. String.substitute(String.slice(e[2], 3), "/",  "\\")
  else
    r.file = "/" .. e[2]
  end

  r.path = String.split(e[3], "/", { trimempty = true })

  return r
end

---@param db string
---@param sql string
---@return table
local function sqlite(db, sql)
  local js =
    "import * as sqlite from \"bun:sqlite\";" ..
    "const db = new sqlite.Database(" .. vim.json.encode(db) .. ");" ..
    "console.log(JSON.stringify(db.prepare(" .. vim.json.encode(sql) .. ").all()));"

  local r = sh({ "bun", "-e", js }):await()
  r:unwrap()
  return vim.json.decode(r.stdout)
end

local fn_BufReadCmd = promisify_wrap(function(promise, o)
  local file = o.file
  local buffer = o.buffer
  local path = o.path

  local header = fs.readfile(file, { size = 16, raw = true }):await():unwrap()

  if header ~= "SQLite format 3\0" then
    notify.error("Unsupported SQLite file format")
    return promise:resolve()
  end

  local query = sqlite(file, "SELECT * FROM sqlite_master")

  -- log(query)
  local target_table = path[1]
  if #path == 0 then
    query = List.sort(query, function(a, b)
      local c = String.compare(a.name, b.name)
      return (c == 0) and (a.name < b.name) or (c == -1)
    end)

    vim.bo[buffer].modifiable = true
    for i=1, #query, 1 do
      local e = query[i]
      local icon, hl
      if e.type == "table" then
        icon = " " hl = "Function"
      elseif e.type == "view" then
        icon = " " hl = "String"
      else
        assert(false)
      end

      vim.api.nvim_buf_set_lines(buffer, i-1, i-1, true, { " " .. icon .. " " .. e.name })
      vim.api.nvim_buf_set_extmark(0, NS, i-1, 1, {
        end_col = #icon + 1,
        hl_group = hl,
        strict = false,
      })
    end
    vim.cmd[[norm! G"_ddgg]]
    vim.bo[buffer].modifiable = false

    vim.api.nvim_create_autocmd({ "CursorMovedI", "CursorMoved", "ModeChanged" }, {
      buffer = buffer,
      callback = function(ev)
        local y, x = unpack(vim.api.nvim_win_get_cursor(0))
        local padding = String.match(vim.api.nvim_buf_get_lines(ev.buf, y - 1, y, true)[1], " [^ ]\\+ \\zs \\ze[^ ]")

        if padding and x < padding then
          vim.api.nvim_win_set_cursor(0, { y, padding })
        end
      end
    })

    return promise:resolve()
  elseif #path == 1 then
    local schema = sqlite(file, "PRAGMA table_info(" .. path[1] .. ")")
    local columns_width = {}
    for i=1, #schema, 1 do
    end
    vim.api.nvim_buf_set_lines(buffer, i-1, i-1, true, { " " .. icon .. " " .. e.name })

    -- log()
    log(unpack(sqlite(file, "SELECT * FROM " .. path[1] .. " LIMIT 1")))
  else
    assert(false, "TODO")
  end

  -- local tables = {}
  -- local views = {}
  -- for _, e in ipairs(db_content) do
  --   -- if e.type = 
  -- end

  promise:resolve()
end)

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "sqlite://*" },
  callback = function(ev)
    vim.bo[ev.buf].bufhidden  = "delete"
    vim.bo[ev.buf].buflisted  = false
    vim.bo[ev.buf].buftype    = "nofile"
    vim.bo[ev.buf].filetype   = "lua-sqlite"
    vim.bo[ev.buf].modifiable = false
    vim.bo[ev.buf].swapfile   = false
    vim.bo[ev.buf].undolevels = -1

    local d = M.path.decode(ev.file)
    d.buffer = ev.buf
    fn_BufReadCmd(d)
  end
})

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "*.db", "*.db3", "*.sqlite", "*.sqlite3" },
  nested = true,
  callback = function(ev)
    vim.cmd.e(M.path.encode(ev.file))
    vim.schedule(function()
      vim.bo[ev.buf].modified = false
      vim.bo[ev.buf].modifiable = false
    end)
  end
})

M.select = promisify_wrap(function(promise)
  assert(vim.bo.filetype == "lua-sqlite")
  local _ = M.path.decode(vim.api.nvim_buf_get_name(0))
  local file = _.file
  local path = _.path

  if #path == 0 then
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
    ---@diagnostic disable-next-line: param-type-mismatch
    local selection = String.slice(line, String.match(line, "^ \\+[^ ]\\+ \\+\\zs"))
    vim.cmd.e(vim.api.nvim_buf_get_name(0) .. selection .. "/")
    return promise:resolve()
  elseif #path == 1 then
    log("TODO")
    return promise:resolve()
  else
    return promise:resolve()
  end
end)

-- local icons = {
--   db =      "󰆼",
--   table =   "",
--   view =    "",
-- }

-- local _icons = {
--   db =               "󰆼",
--   buffers =          "",
--   saved_queries =    "",
--   schemas =          "",
--   schema =           "󰙅",
--   tables =           "󰓱",
--   table =            "",
--   saved_query =      "",
--   new_query =        "󰓰",
--   tables =           "󰓫",
--   buffers =          "",
--   add_connection =   "󰆺",
--   connection_ok =    "✓",
--   connection_error = "✗",
-- }

--[[

-- "N " "S " "B " "0  "
-- " " "󰀬 " "󱨏 " "󰟢 "

-- "󱘥 " "󱘦 " "󱘧 " "󱘨 "
-- " " " " "󱕵 "
-- https://www.nerdfonts.com/cheat-sheet

CursorMoved
CursorMovedI
ModeChanged
WinScrolled

--]]

return {
  select = function() M.select() end
}
