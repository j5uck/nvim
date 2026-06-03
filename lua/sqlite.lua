local List, notify, promisify_wrap, fs, sh, String = (function()
  local _ = require("_")
  return _.List, _.notify, _.promisify_wrap, _.fs, _.sh, _.String
end)()

local log = require("_").log

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
  local window = o.window
  local buffer = o.buffer

  local header = fs.readfile(file, { size = 16, raw = true }):await():unwrap()

  if header ~= "SQLite format 3\0" then
    notify.error("Unsupported SQLite file format")
    return promise:resolve()
  end

  -- local query = sqlite(file, "SELECT name FROM sqlite_master WHERE type = \"table\"")
  -- local query = sqlite(file, "SELECT name, type FROM sqlite_master")
  local query = sqlite(file, "SELECT * FROM sqlite_master")
  log(List.sort(List.map(function(e) return e end, query)))
  -- log(sqlite(file, "SELECT name FROM sqlite_master WHERE type = \"table\""))

  -- sqlite(file, "CREATE VIEW a AS SELECT * FROM sqlite_master")

  promise:resolve()
end)

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = { "sqlite://*" },
  callback = function(ev)
    -- log(ev)
  end
})

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "sqlite://*" },
  callback = function(ev)
    -- log(ev)
    vim.bo[ev.buf].filetype = "lua-sqlite"

    local _, file, path = unpack(String.split(ev.file, "//"))
    if vim.fn.has("win32") == 1 then
      file = String.slice(file, 1, 1) .. ":\\" .. String.slice(file, 3)
      file = String.substitute(file, "/",  "\\")
    else
      file = "/" .. file
    end
    log(file)

    -- fn_BufReadCmd{
    --   buffer = ev.buf,
    --   window = vim.api.nvim_get_current_win(),
    --   file = file,
    --   path = #path == 0 and String.split(path, "/") or {}
    -- }
  end
})

-- TODO: fix known error
--  doesnt load when ":e foo.sqlite" for 2º time

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "*.db", "*.db3", "*.sqlite", "*.sqlite3" },
  nested = true,
  callback = function(ev)
    local p = fs.getabsolutepath(ev.file)
    if vim.fn.has("win32") == 1 then
      p = String.slice(p, 1, 1) .. "/" .. String.slice(p, 4)
      p = String.substitute(p, "\\\\", "/")
    end
    vim.cmd.e("sqlite:/" .. p .. "//")
    vim.schedule(function()
      vim.bo[ev.buf].modified = false
      vim.bo[ev.buf].modifiable = false
    end)
  end
})
