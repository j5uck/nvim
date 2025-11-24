local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
  void *stdout, *stderr;
  int fprintf(void *, const char *, ...);
]]

local T_GRAY  = "\x1b[1;30m"
local T_RESET = "\x1b[0m"

local R = {}

function R:cmd(cmd)
  C.fprintf(C.stdout, "%s\n", T_GRAY .. ">>" .. T_RESET .. " "  .. table.concat(cmd, " "))

  local job = vim.fn.jobstart(cmd, { cwd = self.cwd, on_stdout = function(_, strings, _)
    if #strings == 1 then return end
    C.fprintf(C.stdout, "%s", table.concat(strings, "\n"))
  end, on_stderr = function(_, strings, _)
    if #strings == 1 then return end
    C.fprintf(C.stderr, "%s", table.concat(strings, "\n"))
  end })

  local r = vim.fn.jobwait{job}[1]
  if r == 0 then
    return self
  else
    os.exit(r)
  end
end

function R:cd(dir)
  C.fprintf(C.stdout, "%s\n", T_GRAY .. ">>" .. T_RESET .. " cd " .. dir)
  if vim.fn.isabsolutepath(dir) == 1 then
    self.cwd = dir
  else
    self.cwd = vim.fs.normalize(self.cwd .. "/" .. dir)
  end
  return self
end

local M = {}

function M:new()
  return setmetatable({
    cwd = vim.fn.getcwd()
  }, { __index = R } )
end

return M
