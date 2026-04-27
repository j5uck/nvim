if vim.loader then vim.loader.enable() end

if not pcall(vim.cmd.pwd, { mods = { silent = true }}) then
  vim.cmd.cd{vim.env.HOME or vim.env.USERPROFILE, mods = { silent = true }}
end

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1

vim.schedule(vim.cmd.clearjumps)

if vim.fn.exists("#FileExplorer") == 1 then
  vim.api.nvim_del_augroup_by_name("FileExplorer")
end

vim.g.loaded_rrhelper = 1
vim.g.did_install_default_menus = 1

-- vim.g.loaded_node_provider = 0 -- for coc
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- TODO: Send patch???
for _, line in ipairs(vim.opt.runtimepath:get()) do
  if vim.fn.match(line, "[\\/]nvim[\\/]runtime$") > -1 then
    local magic = vim.split("^$()%.[]*+-?", "")

    local p = string.gsub(line, ".", function(c)
      for _, e in ipairs(magic) do
        if e == c then return "%" .. c end
      end
      return c
    end) .. "/doc/.*%.txt"

    if vim.fn.has("win32") == 1 then
      p = string.gsub(p, "\\+", "/")
    end

    vim.filetype.add{ pattern = { [p] = "help" } }
    break
  end
end

vim.go.shortmess = "AacCFIoOqstT"

vim.cmd[[set nocompatible]]

vim.cmd[[filetype plugin indent on]]

vim.g.did_load_filetypes = 1

pcall(function()
  vim.opt.guicursor = { "a:ver25", "n-v:block", "o-r-cr:hor20" }
  vim.opt.guicursor = { "a:ver25", "n-v-t:block", "o-r-cr:hor20" }
end)

vim.opt.mouse = { n = true, v = true, i = true }

vim.cmd[[silent! set maxsearchcount=0]]

vim.opt.laststatus = 3

vim.opt.termguicolors = true

vim.opt.cursorline = false

vim.opt.number = false
vim.opt.relativenumber = false

-- vim.opt.cmdheight = 0

vim.opt.signcolumn = "no"

vim.opt.swapfile = false
vim.opt.writebackup = false
vim.opt.backup = false

vim.opt.undofile = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.mousemodel = "extend"

vim.opt.scrolloff = 6
vim.opt.sidescrolloff = 12

vim.opt.helplang = "en,es"
-- vim.opt.langmap = {}

vim.opt.fillchars = { eob = " " }

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- vim.cmd[[silent! set encoding=utf-8]]
-- vim.cmd[[silent! set fileencoding=utf-8]]
-- vim.cmd[[silent! set fileformat=unix]]

vim.opt.ttyfast = true

vim.opt.modelines = 0

vim.opt.wrap = false

vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.virtualedit = "block"

vim.g.c_syntax_for_h = 1

-- vim.g.comment_strings = 1

---@diagnostic disable-next-line:deprecated 
(vim.lsp.log.set_level or vim.lsp.set_log_level)(vim.log.levels.OFF)

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "man" },
  callback = function() vim.wo.spell = false end
})

-- vim.treesitter.language.register("tsx", { "tsx" })
-- vim.filetype.add({
--   extension = {
--     tsx = "javascriptreact",
--   },
-- })

-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "typescript" },
--   callback = vim.schedule_wrap(function(ev)
--     vim.bo[ev.buf].filetype = "javascript"
--   end)
-- })

-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "typescriptreact" },
--   callback = vim.schedule_wrap(function(ev)
--     vim.bo[ev.buf].filetype = "javascriptreact"
--     vim.treesitter.get_parser(ev.buf, "jsx", {})
--   end)
-- })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "svelte" },
  callback = vim.schedule_wrap(function(ev)
    vim.bo[ev.buf].syntax = "html"
  end)
})

local iskeyword = "@,48-57,_,-,192-255"
vim.go.iskeyword = iskeyword
vim.bo.iskeyword = iskeyword

vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev) vim.bo[ev.buf].iskeyword = iskeyword end
})

local REGISTERS = vim.split("@0123456789-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ*/", "")
vim.schedule(function()
  for _, r in ipairs(REGISTERS) do
    vim.fn.setreg(r, "")
  end
end)

if vim.g.nvy then
  vim.opt.guifont = { "FiraCode Nerd Font Mono:h12" }
end

local promisify_wrap, fs, list, notify, window = (function()
  local _ = require("_")
  return _.promisify_wrap, _.fs, _.list, _.notify, _.window
end)()

local loc = promisify_wrap(function(promise)
  local sb = {}
  local config = vim.fn.stdpath("config") .. "/"
  local total = 0

  local function loc(s)
    for _, e in ipairs(fs.ls(config .. s):await():unwrap()) do
      if e.name == ".git" then
      elseif e.type == "directory" then
        loc(s .. e.name .. "/")
      elseif vim.endswith(e.name, ".vim") or vim.endswith(e.name, ".lua") then
        local n = #fs.readfile(config .. s .. e.name):await():unwrap()
        total = total + n
        list.insert(sb, string.format("%4d", n) .. " :: " .. s .. e.name)
      end
    end
  end

  loc("")

  list.insert(sb, "")
  list.insert(sb, string.format("%4d", total) .. " :: total")

  notify.warn(list.concat(sb, "\n"))

  return promise:resolve()
end)

vim.api.nvim_create_user_command("LOC", function() loc() end, {})

local term_ns = vim.api.nvim_create_namespace("")
vim.api.nvim_set_hl(term_ns, "Normal", { fg = "#FFFFFF", bg = "#000000" })

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  callback = vim.schedule_wrap(function(e)
    pcall(function()
      local win = vim.api.nvim_get_current_win()

      if vim.fn.match(vim.api.nvim_buf_get_name(e.buf), "^term://") == 0 then
        vim.api.nvim_win_set_hl_ns(win, term_ns)
      elseif vim.api.nvim_get_hl_ns({ winid = win }) == term_ns then
        vim.api.nvim_win_set_hl_ns(win, 0)
      end
    end)
  end)
})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.cursorline = false
    vim.api.nvim_win_set_hl_ns(0, term_ns)

    local buffer = vim.api.nvim_get_current_buf();
    vim.wo.wrap = true

    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = buffer,
      callback = function()
        pcall(function()
          vim.wo.wrap = false

          local w = vim.api.nvim_get_current_win()

          local scrolloff = vim.wo[w].scrolloff
          local sidescrolloff = vim.wo[w].sidescrolloff
          vim.wo[w].scrolloff = 0
          vim.wo[w].sidescrolloff = 0

          vim.schedule(function()
            pcall(function()
              vim.wo[w].scrolloff = scrolloff
              vim.wo[w].sidescrolloff = sidescrolloff
            end)
          end)
        end)
      end
    })

    vim.api.nvim_create_autocmd("BufEnter", {
      buffer = buffer,
      callback = function()
        vim.wo.wrap = true
      end
    })
  end
})

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = vim.schedule_wrap(function()
    for i = 0, 16, 1 do vim.g["terminal_color_"..i] = nil end
  end)
})

vim.api.nvim_create_autocmd("TermClose", {
  callback = vim.schedule_wrap(function(ev)
    pcall(vim.api.nvim_buf_delete, ev.buf, {})
  end)
})

-- patch for :source
vim.api.nvim_create_autocmd("BufFilePost", {
  pattern = { "man://*" },
  callback = vim.schedule_wrap(function(ev)
    if vim.bo[ev.buf].filetype ~= "man" then
      vim.api.nvim_buf_call(ev.buf, vim.cmd.e)
    end
  end)
})

local rec = window{
  on_show = function(self)
    vim.bo.bufhidden  = "hide"
    vim.bo.buftype    = "nofile"
    vim.bo.buflisted  = false
    vim.bo.swapfile   = false
    vim.bo.undolevels = -1

    vim.wo.scrolloff = 0
    vim.wo.sidescrolloff = 0

    local r = string.upper(vim.fn.reg_recording())
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, { " REC @" .. r })
  end,
  hl = function() return { Normal = { link = "ErrorMsg" }} end,
  size = function() return {
    col = vim.o.columns-11,
    row = 1,
    width = 9,
    height = 1,
  } end,
  focus = false,
  border = "none",
}

vim.api.nvim_create_autocmd("RecordingEnter", { callback = function() rec:show() end })
vim.api.nvim_create_autocmd("RecordingLeave", { callback = function() rec:hide() end })

require("undotree")
require("explorer")
require("plugins")
require("mapping")
