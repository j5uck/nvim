
if vim.loader then vim.loader.enable() end

if not pcall(vim.cmd.pwd, { mods = { silent = true }}) then
  vim.cmd.cd{vim.env.HOME or vim.env.USERPROFILE, mods = { silent = true }}
end

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

if vim.fn.exists("#FileExplorer") == 1 then
  vim.api.nvim_del_augroup_by_name("FileExplorer")
end

if vim.fn.has("win32") == 1 then
  -- for WINDOWS --
  vim.cmd("set shell=" .. vim.fn.exepath("powershell"))
  -- vim.cmd[[set shell=C:/Users/user/stuff/bin/busybox.exe\ bash]]
  vim.cmd[[set shellxquote=]]
  vim.cmd[[set shellcmdflag=-c]]
-- elseif vim.fn.has('mac') == 1 then
--   -- for MAC --
--   vim.cmd("set shell=/bin/bash")
-- else
--   -- for POSIX --
--   vim.cmd("set shell=/bin/bash")
end

-- NO sourcing of $VIMRUNTIME/plugin/rrhelper.vim --
vim.g.loaded_rrhelper = 1

-- NO sourcing GUI stuff --
vim.g.did_install_default_menus = 1

-- vim.g.loaded_node_provider = 0 -- for coc
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

local p = (vim.fn.has("win32") == 0) and
  "/usr/share/nvim/runtime/doc/.*" or
  "C:\\Program Files\\Neovim\\share\\nvim\\runtime\\doc\\.*"
vim.filetype.add{ pattern = { [p] = { "help" } } }

vim.cmd[[set shortmess+=AacCIqs]]

vim.cmd[[set nocompatible]]

vim.cmd[[filetype plugin indent on]]

vim.g.did_load_filetypes = 1

vim.opt.guicursor = { "a:ver25", "n-v-t:block", "o-r-cr:hor20" }

vim.opt.mouse = { a = true }

vim.schedule(vim.cmd.clearjumps)

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

-- vim.opt.iskeyword:append("_")
-- vim.opt.iskeyword:append("-")

vim.opt.fillchars = { eob = " " }

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- vim.cmd[[silent! set encoding=utf-8]]
-- vim.cmd[[silent! set fileencoding=utf-8]]
-- vim.cmd[[silent! set fileformat=unix]]

vim.opt.expandtab = true

vim.opt.autoindent = true
vim.opt.smartindent = true

vim.opt.ttyfast = true

vim.opt.modelines = 0

vim.opt.wrap = false

vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

vim.opt.virtualedit = "block"

vim.g.c_syntax_for_h = 1

-- vim.g.comment_strings = 1

vim.lsp.set_log_level(vim.log.levels.OFF)

-- tranparency --
-- vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
-- vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
-- vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })

-- ------------------------- x ------------------------- --

if vim.g.nvy then
  vim.opt.guifont = { "FiraCode Nerd Font Mono:h12" }
end

require("undotree")
require("explorer")
require("plugins")
require("mapping")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "man",
  callback = function() vim.wo.spell = false end
})

local term_ns = vim.api.nvim_create_namespace("")
vim.api.nvim_set_hl(term_ns, "Normal", { fg = "#ffffff", bg = "#000000" })

vim.api.nvim_create_autocmd("TermEnter", {
  callback = vim.schedule_wrap(function()
   vim.api.nvim_win_set_hl_ns(0, term_ns)
  end)
})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(ev) vim.api.nvim_buf_call(ev.buf, function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.cursorline = false
  end) end
})

vim.api.nvim_create_autocmd("ColorScheme", { callback = vim.schedule_wrap(function()
  for i = 0, 16, 1 do vim.g["terminal_color_"..i] = nil end
end)})

vim.api.nvim_create_autocmd("TermClose", {
  callback = vim.schedule_wrap(function(ev)
    if not vim.api.nvim_buf_is_valid(ev.buf) then return end
    pcall(vim.api.nvim_buf_delete, ev.buf, {})
  end)
})

local rec = require("_").window:new{
  on_show = function(self)
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, {
      " REC @" .. string.upper(vim.fn.reg_recording())
    })
  end,
  hl = function() return { Normal = { link = "ErrorMsg" }} end,
  size = function() return {
    col = vim.o.columns-11,
    row = 1,
    width = 9,
    height = 1,
  } end,
  focus = false,
  focusable = false,
  border = "none",
}

vim.api.nvim_create_autocmd("RecordingEnter", { callback = function() rec:show() end })
vim.api.nvim_create_autocmd("RecordingLeave", { callback = function() rec:hide() end })

