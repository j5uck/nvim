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

local fs = {}
fs.find = (function()
  local function find(regex, path)
    ---@diagnostic disable-next-line: param-type-mismatch
    local fd = vim.uv.fs_opendir(path, nil, 16384) -- 1 << 14

    local r = {}
    for _, t in ipairs(vim.iter(function() return vim.uv.fs_readdir(fd) end):totable()) do
      for _, e in ipairs(t) do
        if e.type == "directory" then
          vim.list_extend(r, find(regex, path .. "/" .. e.name))
        elseif vim.fn.match(e.name, regex) > -1 then
          table.insert(r, path .. "/" .. e.name)
        end
      end
    end
    vim.uv.fs_closedir(fd)

    return r
  end

  return function(regex, path)
    path = path or ""
    if vim.fn.isabsolutepath(path) == 1 then
      path = vim.fs.normalize(path)
    else
      path = vim.fs.normalize(vim.fn.getcwd() .. "/" .. path)
    end
    local pre = #path + 2

    return vim.tbl_map(function(e)
      return string.sub(e, pre)
    end, find(regex, path))
  end
end)()

local runner = { cwd = vim.fn.getcwd() }

function runner:cmd(cmd)
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

function runner:cd(dir)
  C.fprintf(stdout, "%s\n", T_GRAY .. ">>" .. T_RESET .. " cd " .. dir)
  if vim.fn.isabsolutepath(dir) == 1 then
    self.cwd = dir
  else
    self.cwd = vim.fs.normalize(self.cwd .. "/" .. dir)
  end
  if vim.fn.isdirectory(self.cwd) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return self
end
