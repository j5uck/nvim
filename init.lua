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
      return vim.list_contains(magic, c) and ("%" .. c) or c
    end) .. "/doc/.*%.txt"

    if vim.fn.has("win32") == 1 then
      p = string.gsub(p, "\\+", "/")
    end

    vim.filetype.add{ pattern = { [p] = "help" } }
    break
  end
end

vim.cmd[[set shortmess+=AacCIqs]]

vim.cmd[[set nocompatible]]

vim.cmd[[filetype plugin indent on]]

vim.g.did_load_filetypes = 1

vim.opt.guicursor = { "a:ver25", "n-v-t:block", "o-r-cr:hor20" }

vim.opt.mouse = { n = true, v = true }

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

vim.lsp.set_log_level(vim.log.levels.OFF)

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "man" },
  callback = function() vim.wo.spell = false end
})

local iskeyword = "@,48-57,_,-,192-255"
vim.go.iskeyword = iskeyword
vim.bo.iskeyword = iskeyword

vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev) vim.bo[ev.buf].iskeyword = iskeyword end
})

if vim.g.nvy then
  vim.opt.guifont = { "FiraCode Nerd Font Mono:h12" }
end

require("undotree")
require("explorer")
require("plugins")
require("mapping")

local fs, notify, window = (function()
  local _ = require("_")
  return _.fs, _.notify, _.window
end)()

vim.api.nvim_create_user_command("TabToSpaces", function()
  vim.cmd("%s/\\t/" .. string.rep(" ", vim.o.tabstop) .. "/g")
  vim.opt.autoindent = true
  vim.opt.expandtab = true
  vim.opt.smartindent = true
end, {})

vim.api.nvim_create_user_command("LOC", function()
  local sb = {}
  local config = vim.fn.stdpath("config") .. "/"
  local total = 0

  local function loc(s)
    for _, d in ipairs(vim.fn.sort(vim.fn.globpath(config .. s, "*", 1, true), "i")) do
      local name = vim.fs.basename(d)
      if vim.fn.isdirectory(d) == 1 then
        loc(s .. name .. "/")
      else
        local n = #fs.readfile(d)
        total = total + n
        table.insert(sb, string.format("%4d", n) .. " :: " .. s .. name)
      end
    end
  end

  loc("")

  table.insert(sb, "")
  table.insert(sb, string.format("%4d", total) .. " :: total")

  notify.warn(table.concat(sb, "\n"))
end, {})

local term_ns = vim.api.nvim_create_namespace("")
vim.api.nvim_set_hl(term_ns, "Normal", { fg = "#FFFFFF", bg = "#000000" })

vim.api.nvim_create_autocmd("WinEnter", {
  callback = vim.schedule_wrap(function()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.fn.match(vim.api.nvim_buf_get_name(buf), "^term://") == 0 then
      vim.api.nvim_win_set_hl_ns(win, term_ns)
    elseif vim.api.nvim_get_hl_ns({ winid = win }) == term_ns then
      vim.api.nvim_win_set_hl_ns(win, 0)
    end
  end)
})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.cursorline = false
    vim.api.nvim_win_set_hl_ns(0, term_ns)
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

local rec = window{
  on_show = function(self)
    vim.bo.bufhidden  = "hide"
    vim.bo.buftype    = "nofile"
    vim.bo.buflisted  = false
    vim.bo.swapfile   = false
    vim.bo.undolevels = -1

    vim.wo.scrolloff = 0
    vim.wo.sidescrolloff = 0

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
  border = "none",
}

vim.api.nvim_create_autocmd("RecordingEnter", { callback = function() rec:show() end })
vim.api.nvim_create_autocmd("RecordingLeave", { callback = function() rec:hide() end })
