local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[ int fprintf(void *, const char *, ...); ]]

local stdout, stderr = (function()
  if vim.fn.has("win32") == 1 then
    ffi.cdef[[ void * __acrt_iob_func(unsigned); ]]
    return C.__acrt_iob_func(1), C.__acrt_iob_func(2)
  else
    ffi.cdef[[ void *stdout, *stderr; ]]
    return C.stdout, C.stderr
  end
end)()

local T_GRAY  = "\x1b[1;30m"
local T_RESET = "\x1b[0m"

local R = {}

function R:cmd(cmd)
  C.fprintf(stdout, "%s\n", T_GRAY .. ">>" .. T_RESET .. " "  .. table.concat(cmd, " "))

  local job = vim.fn.jobstart(cmd, { cwd = self.cwd, on_stdout = function(_, strings, _)
    if #strings == 1 then return end
    C.fprintf(stdout, "%s", table.concat(strings, "\n"))
  end, on_stderr = function(_, strings, _)
    if #strings == 1 then return end
    C.fprintf(stderr, "%s", table.concat(strings, "\n"))
  end })

  return vim.fn.jobwait{job}[1] == 0 and self or os.exit(1)
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

return {
  new = function()
    return setmetatable({ cwd = vim.fn.getcwd() }, { __index = R })
  end
}
