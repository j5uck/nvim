local List, notify, promisify_wrap, fs, sh, String = (function()
  local _ = require("_")
  return _.List, _.notify, _.promisify_wrap, _.fs, _.sh, _.String
end)()

local log = require("_").log

local function sqlite(db, sql)
  local js =
    "import * as sqlite from \"bun:sqlite\";" ..
    "const db = new sqlite.Database(" .. vim.json.encode(db) .. ");" ..
    "console.log(JSON.stringify(db.prepare(" .. vim.json.encode(sql) .. ").all()));"

  local r = sh({ "bun", "-e", js }):await()
  r:unwrap()
  return vim.json.decode(r.stdout)
end

local fn_BufReadCmd = promisify_wrap(function(promise, file)
  local header = fs.readfile(file, { size = 16, raw = true }):await():unwrap()

  if header ~= "SQLite format 3\0" then
    notify.error("Unsupported SQLite file format")
    return promise:resolve()
  end

  local query = sqlite(file, "SELECT name FROM sqlite_master WHERE type = \"table\"")
  log(List.sort(List.map(function(e) return e.name end, query)))
  -- log(sqlite(file, "SELECT name FROM sqlite_master WHERE type = \"table\""))

  promise:resolve()
end)

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "*.db", "*.db3", "*.sqlite", "*.sqlite3" },
  nested = true,
  callback = function(ev)
    if vim.fn.has("win32") == 1 then
      vim.cmd.e("sqlite://" .. String.substitute(ev.file, "\\\\", "/") .. "//")
    else
      vim.cmd.e("sqlite:/" .. ev.file .. "//")
    end
  end
})

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "sqlite://*" },
  callback = function(ev)
    if not fs.exepath("bun") then
      return notify.error("Bun not found")
    end

    if vim.bo[ev.buf].filetype == "lua-sqlite" then return end

    vim.bo[ev.buf].filetype = "lua-sqlite"

    local file = String.split(ev.file, "//")[2]
    fn_BufReadCmd(vim.fn.has("win32") == 1 and file or ("/" .. file))
  end
})
