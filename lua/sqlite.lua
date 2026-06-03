local List, notify, promisify_wrap, fs, sh, String = (function()
  local _ = require("_")
  return _.List, _.notify, _.promisify_wrap, _.fs, _.sh, _.String
end)()

local log = require("_").log

local M = {}

vim.filetype.add{ pattern = { ["sqlite://.*"] = { "lua-sqlite", { priority = 10 } } } }

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

  local target_table = path[1]
  if not target_table then
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(buffer, 0, -1, true, List.sort(List.map(function(e)
      return e.name
    end, query)))
    vim.bo[buffer].modifiable = false

    return promise:resolve()
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

    local _, file, path = unpack(String.split(ev.file, "//"))
    if vim.fn.has("win32") == 1 then
      file = String.slice(file, 1, 1) .. ":\\" .. String.substitute(String.slice(file, 3), "/",  "\\")
    else
      file = "/" .. file
    end

    fn_BufReadCmd{
      buffer = ev.buf,
      file = file,
      path = #path == 0 and {} or String.split(path, "/")
    }
  end
})

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "*.db", "*.db3", "*.sqlite", "*.sqlite3" },
  nested = true,
  callback = function(ev)
    local p = fs.getabsolutepath(ev.file)
    if vim.fn.has("win32") == 1 then
      p = String.slice(p, 1, 1) .. "/" .. String.slice(p, 4)
      p = String.substitute(p, "\\\\", "/")
      vim.cmd.e("sqlite://" .. p .. "//")
    else
      vim.cmd.e("sqlite:/" .. p .. "//")
    end
    vim.schedule(function()
      vim.bo[ev.buf].modified = false
      vim.bo[ev.buf].modifiable = false
    end)
  end
})

M.select = function()
  assert(vim.bo.filetype == "lua-sqlite")
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
  if not line then return end

  log(line)
  -- local entry = M.parse(line)
end

local icons = {
  db =      "󰆼",
  table =   "",
  view =    "",
}

local _icons = {
  db =               "󰆼",
  buffers =          "",
  saved_queries =    "",
  schemas =          "",
  schema =           "󰙅",
  tables =           "󰓱",
  table =            "",
  saved_query =      "",
  new_query =        "󰓰",
  tables =           "󰓫",
  buffers =          "",
  add_connection =   "󰆺",
  connection_ok =    "✓",
  connection_error = "✗",
}

--[[--
-- " " "󰀬 " "󱨏 " "󰟢 "
-- "󱘥 " "󱘦 " "󱘧 " "󱘨 "
-- " " " " "󱕵 "
-- https://www.nerdfonts.com/cheat-sheet
--]]--

return {
  select = M.select
}
