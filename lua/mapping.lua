local notify, notify_once, flags, fs, prequire, window = (function()
  local _ = require("_")
  return _.notify, _.notify_once, _.flags, _.fs, _.prequire, _.window
end)()
local explorer = require("explorer")

local W = {}

vim.g.mapleader = " "

local function map(mode, lhs, rhs, opts)
  opts = vim.tbl_extend("force", { noremap = true, silent = true }, opts or {})

  for _, l in ipairs(type(lhs) == "string" and { lhs } or lhs) do
    vim.keymap.set(mode, l, rhs, opts)
  end
end

local nope = {
  { "n", { "&", "<CR>", "<c-c>", "<leader>", "<leader><s-q>", "<leader>f", "<leader>s" } },
  { "v", { "<leader>s" } },
  { { "n", "i", "v" }, { "<c-z>", "<MiddleMouse>", "<2-MiddleMouse>", "<3-MiddleMouse>", "<4-MiddleMouse>" } }
}

for _, v in ipairs(nope) do map(v[1], v[2], "<Nop>", { desc = "do nothing" }) end

map("i", { "<c-Space>" }, "<esc>", { desc = "escape" })
map({"i", "t"}, "<M-o>", "<c-\\><c-n>", { desc = "escape" })

map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "move up" })
map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "move down" })

map("n", "U", "<C-r>", { desc = "redo" })

map("n", "<leader>T", "<cmd>tabnew<CR>", { desc = "[t]erminal" })

map({"i", "c"}, "<c-a>", "<Home>", { desc = "go to line start" })
map({"i", "c"}, "<c-e>", "<End>",  { desc = "go to line end" })

map("n", "<", "V<",  { desc = "tab" })
map("n", ">", "V>",  { desc = "un-tab" })
map("v", "<", "<gv", { desc = "tab" })
map("v", ">", ">gv", { desc = "un-tab" })

map("v", "<c-a>", "<c-a>gv", { desc = "increase" })
map("v", "<c-x>", "<c-x>gv", { desc = "decrease" })

map("i", "<tab>",   "<tab>", { desc = "tab" })
map("i", "<s-tab>", "<c-h>", { desc = "un-tab" })
map("i", "<cr>",    "<cr>",  { desc = "enter" })

map("n", "<M-h>", "<c-w>h", { desc = "move to split [h] left" })
map("n", "<M-j>", "<c-w>j", { desc = "move to split [j] down" })
map("n", "<M-k>", "<c-w>k", { desc = "move to split [k] up" })
map("n", "<M-l>", "<c-w>l", { desc = "move to split [l] right" })

map("n", "<s-h>", "<cmd>vsplit<cr>",            { desc = "split [S]plit [h] left" })
map("n", "<s-j>", "<cmd>belowright split<CR>",  { desc = "split [S]plit [j] down" })
map("n", "<s-k>", "<cmd>split<CR>",             { desc = "split [S]plit [k] up" })
map("n", "<s-l>", "<cmd>belowright vsplit<CR>", { desc = "split [S]plit [l] right" })

map("n", "<leader><s-h>", "<cmd>vnew<cr>",            { desc = "empty [S]plit [h] left" })
map("n", "<leader><s-j>", "<cmd>belowright new<CR>",  { desc = "empty [S]plit [j] down" })
map("n", "<leader><s-k>", "<cmd>new<CR>",             { desc = "empty [S]plit [k] up" })
map("n", "<leader><s-l>", "<cmd>belowright vnew<CR>", { desc = "empty [S]plit [l] right" })

map("x", { "<leader>I", "<leader>A" }, "xgvI", { desc = "replace block" })

map({"n", "v"}, "<leader>y", "\"+y", { desc = "[y]ank to \"+" })

map({"n", "v"}, "<leader>p", "\"+p", { desc = "[p]aste from \"+" })
map({"n", "v"}, "<leader>P", "\"+P", { desc = "[P]aste from \"+" })

map({"n", "v"}, "<leader>dd", "\"+dd", { desc = "[d]elete and copy to \"+" })
map({"n", "v"}, "<leader>D",  "\"+D",  { desc = "[D]elete and copy to \"+" })

map("n", "<leader>w", "<cmd>w<CR>", { desc = "[w]rite" })
map("n", "<leader>x", "<cmd>x<CR>", { desc = "write & e[x]it" })

map("n", "<leader>q", "<cmd>q<CR>",  { desc = "[q]uit" })
map("n", "<leader>Q", "<cmd>q!<CR>", { desc = "forced [q]uit" })

map("n", "<leader>o", "o<esc>0\"_D", { desc = "create new line" })
map("n", "<leader>O", "O<esc>0\"_D", { desc = "create new line" })

map("n", "<leader>gf", function()
  local p = vim.api.nvim_buf_get_name(0)
  if p == "" then return end
  vim.cmd.edit(vim.fn.fnameescape(fs.dirname(p)))
end, { desc = "open file parent folder" })

map("n", "<leader>S", function()
  vim.cmd("%s/\\t/" .. string.rep(" ", vim.o.tabstop) .. "/g")
  vim.opt.autoindent = true
  vim.opt.expandtab = true
  vim.opt.smartindent = true
end, { desc = "tab to [S]paces" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function(ev)
    map("n", "<leader>s", "<cmd>%lua<CR>", { buffer = ev.buf, desc = "[s]ource" })
    map("v", "<leader>s", ":lua<CR>",      { buffer = ev.buf, desc = "[s]ource" })
  end
})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(ev)
    map("n", "<M-o>", "<Nop>", { buffer = ev.buf })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf" },
  callback = function(ev)
    map("n", "<CR>", "<cmd>.cc<CR>", { buffer = ev.buf, desc = "go to error" })
  end
})

vim.fn.setreg("q", "")
map("n", "Q", "qq", { desc = "record macro on [q] register" })
map("n", ",", "@q", { desc = "do [q] macro" })
map("v", ",", "<cmd>norm @q<CR>", { desc = "do [q] macro" })

map("n", "<leader>t", [[<cmd>exe "terminal" | startinsert<CR>]], { desc = "[t]erminal" })

map("n", "<leader>a", function()
  notify.info(vim.fn.expand("%:p"))
end, { desc = "show buffer path" })

map("n", "<leader>A", function()
  local b = vim.fn.expand("%:p")
  notify.info(b)
  vim.fn.setreg("\"", b)
  vim.fn.setreg("+", b)
end, { desc = "copy buffer path" })

map("n", "<c-h>", "<c-o>", { desc = "jump to previous location" })
map("n", "<c-l>", "<c-i>", { desc = "jump to next location" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help" },
  callback = function(ev)
    map("n", "<CR>", "<c-]>", { buffer = ev.buf, desc = "go to tag" })
  end
})

map("n", "<leader>l", ":lua require(\"_\").log()<left>", { silent = false, desc = "open [l]ua cmd" })
map("n", "<leader>0", "<cmd>only<CR> ", { desc = "[0]nly" })

map("n", "<leader>W", function()
  local o = not vim.wo.wrap
  vim.wo.wrap = o
  vim.wo.linebreak = o
  notify.warn(o and ":set wrap" or ":set nowrap")
end, { desc = "toggle [W]rap" })

map("n", "<leader>n", function()
  if vim.wo.number then
    vim.wo.number = false
    vim.wo.signcolumn = "no"
  else
    vim.wo.number = true
    vim.wo.signcolumn = "number"
  end
end, { desc = "toggle [n]umber" })

map("n", "<leader>m", "<cmd>nohlsearch<CR>", { desc = "[m]ute search" })

map("n", "<leader>E", explorer.open, { desc = "open file tre[e]" })
map("n", "<leader>e", explorer.resume, { desc = "resume file tre[e]" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua-explorer" },
  callback = function(ev)
    map("n", "<s-k>", "<Nop>", { buffer = ev.buf })
    map("n", "<s-j>", "<Nop>", { buffer = ev.buf })

    map("n", "<esc>", "<cmd>q<CR>", { buffer = ev.buf })

    map("n", "<2-LeftMouse>", explorer.select, { buffer = ev.buf })
    map("n", "<CR>", explorer.select, { buffer = ev.buf })

    map("n", "<c-h>", explorer.go_back, { buffer = ev.buf })
    map("n", "<c-l>", explorer.go_next, { buffer = ev.buf })
    map("n", "<c-k>", explorer.go_up, { buffer = ev.buf })

    map("n", "<M-h>", explorer.go_back, { buffer = ev.buf })
    map("n", "<M-j>", "<Nop>", { buffer = ev.buf })
    map("n", "<M-k>", explorer.go_up, { buffer = ev.buf })
    map("n", "<M-l>", explorer.go_next, { buffer = ev.buf })

    map("n", "<leader>c", function()
      local s = explorer.buf_get_name()
      notify.info(s)
      vim.cmd.cd(s)
    end, { buffer = ev.buf })

    map("n", "<leader>A", function()
      local s = explorer.buf_get_name()
      notify.info(s)
      vim.fn.setreg([["]], s)
      vim.fn.setreg([[+]], s)
    end, { buffer = ev.buf })
  end
})

local term_buffers = { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }
local term_buffers_i = 1
local term_buffers_flag = false
local term_maximized_flag = false
W.term = window{
  on_show = function(self)
    pcall(function()
      vim.api.nvim_win_set_buf(self.win, term_buffers[term_buffers_i])
      self.buf = term_buffers[term_buffers_i]
    end)

    if term_buffers_flag or term_buffers_i > 1 then
      term_buffers_flag = true
      vim.api.nvim_win_set_config(0, { title = " [" .. term_buffers_i .. "] ", title_pos = "center" })
    end

    if term_buffers[term_buffers_i] ~= vim.api.nvim_get_current_buf() then
      if vim.fn.has("win32") == 1 then
        local shell = vim.go.shell
        vim.go.shell = "powershell"
        vim.cmd.term()
        vim.go.shell = shell
      else
        vim.cmd.term()
      end
      self.buf = vim.api.nvim_get_current_buf()
      term_buffers[term_buffers_i] = self.buf
      vim.api.nvim_win_set_buf(self.win, self.buf)
    end

    vim.bo.bufhidden  = "hide"
    vim.bo.buflisted  = false
    vim.bo.swapfile   = false
    vim.bo.undolevels = -1

    vim.wo.wrap = true

    -- vim.cmd[[silent! norm! 0]]
    vim.cmd.clearjumps()
    vim.cmd[[silent! startinsert]]

    local function go_wrap(i)
      return function()
        term_buffers_i = i
        for _, fn in ipairs(self.on_show) do fn(self) end
      end
    end

    for i=1, 9, 1 do
      map({ "n", "t" }, "<M-" .. i .. ">", go_wrap(i), { buffer = self.buf })
    end
    map({ "n", "t" }, "<M-0>", go_wrap(10), { buffer = self.buf })

    map("n", "<leader>t", function()
      term_maximized_flag = not term_maximized_flag
      for _, fn in ipairs(self.on_resize) do fn(self) end
    end, { buffer = self.buf, desc = "Toggle [t]erminal size" })

    vim.api.nvim_create_autocmd("WinLeave", {
      callback = function() self:hide() end,
      once = true
    })
  end,
  size = function()
    local width = term_maximized_flag and vim.o.columns or
        math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
    local height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))

    return {
      col = math.ceil(vim.o.columns - width) * 0.5 - 1,
      row = math.ceil(vim.o.lines - height) * 0.5 - 1,
      width  = width,
      height = height
    }
  end,
  focus = true,
  border = "rounded",
}

map({"n", "v", "t"}, "<c-Space>", function() W.term:toggle() end, { desc = "toggle floating terminal" })

map("n", "<leader>ic", function()
  vim.cmd.cd{vim.fn.stdpath("config"), mods = { silent = true }}
  vim.cmd[[silent! Telescope find_files]]
end, { desc = "go to config" })

map("n", "<leader>ip", function()
  vim.cmd.cd{vim.fn.stdpath("data") .. "/plug", mods = { silent = true }}
  explorer.open()
end, { desc = "go to plug config" })

local zen_toggle = (function()
  local toggled = false

  local status, lualine = pcall(require, "lualine")
  if not status then
    lualine = { hide = function(_) end, refresh = function(_) end }
  end

  return function()
    toggled = not toggled
    if toggled then
      vim.cmd.IBLDisable{ mods = { silent = true }}
      lualine.hide()
      lualine.refresh{ force = true }
    else
      vim.cmd.IBLEnable{ mods = { silent = true }}
      lualine.hide{ unhide = true }
      lualine.refresh{ force = true }
    end
  end
end)()
map("n", "<leader>z", zen_toggle, { desc = "zen mode" })

-- Notify --
prequire("notify", function(n)
  map("n", "<leader>m", function()
    n.dismiss()
    vim.cmd.nohlsearch()
  end, { desc = "[m]ute search & messages/notifications" })
end)

-- UNDOTREE --

local undotree = require("undotree")
map("n", "<leader>u", undotree.toggle, { desc = "toggle [u]ndo tree" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "undotree",
  callback = function(ev)
    map("n", { "<CR>", "<2-LeftMouse>" }, undotree.select, { buffer = ev.buf, desc = "Select state" })
    map("n", "u", undotree.undo, { buffer = ev.buf, desc = "Undo" })
    map("n", { "U", "<c-r>" }, undotree.redo, { buffer = ev.buf, desc = "Redo" })
  end
})

-- WINDOWS --

prequire("windows", function()
  local function norm_0()
    local w = vim.api.nvim_get_current_win()
    for _, id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if id == w then goto continue end
      vim.api.nvim_win_call(id, function() vim.cmd.norm(0) end)
      ::continue::
    end
  end

  map("n", "<leader>M", function()
    norm_0()
    vim.cmd[[silent! WindowsEqualize]]
    vim.cmd[[silent! WindowsMaximize]]
  end, { desc = "[M]aximize buffer window" })

  map("n", "<leader>N", function()
    norm_0()
    vim.cmd[[silent! WindowsEqualize]]
  end, { desc = "equalize buffer window" })
end)

-- TELESCOPE --

prequire("telescope", function()
  local tb = require("telescope.builtin")

  local function man_pages() tb.man_pages{ sections = { "ALL" } } end
  map("n", "<leader>fm", man_pages,      { desc = "[f]ind [m]an pages [telescope]" })

  map("n", "<leader>ft", tb.builtin,     { desc = "[f]ind [t]elescope builtin [telescope]" })
  map("n", "<leader>fr", tb.resume,      { desc = "[f]ind [r]esumed search [telescope]" })
  map("n", "<leader>ff", tb.find_files,  { desc = "[f]ind [f]iles [telescope]" })
  map("n", "<leader>fg", tb.live_grep,   { desc = "[f]ind with [g]rep [telescope]" })
  map("n", "<leader>fs", tb.grep_string, { desc = "[f]ind with grep [s]tring [telescope]" })
  map("n", "<leader>fb", tb.buffers,     { desc = "[f]ind [b]uffer [telescope]" })
  map("n", "<leader>fd", tb.diagnostics, { desc = "[f]ind [d]iagnostics [telescope]" })
  map("n", "<leader>fh", tb.help_tags,   { desc = "[f]ind [h]elp [telescope]" })
  map("n", "<leader>fk", tb.keymaps,     { desc = "[f]ind [k]eymaps [telescope]" })

  map({ "n", "v" }, "<leader>*", tb.grep_string, { desc = "search selected string [telescope]" })

  map("n", "<leader>gd", tb.lsp_definitions,      { desc = "[g]o to [d]efinition [telescope]" })
  map("n", "<leader>gt", tb.lsp_type_definitions, { desc = "[g]o to [t]ype definition [telescope]" })
  map("n", "<leader>gi", tb.lsp_implementations,  { desc = "[g]o to [i]mplementation [telescope]" })
  map("n", "<leader>gr", tb.lsp_references,       { desc = "[g]o to [r]eferences [telescope]" })
  map("n", "<leader>gs", tb.lsp_document_symbols, { desc = "[g]o to document [s]ymbols [telescope]" })

  local function colorscheme()
    local cc = vim.fn.getcompletion("", "color")
    tb.colorscheme{
      previewer = false,
      enable_preview = true,
      layout_config = {
        width = function(_, max_w)
          local len = 0
          for _, cs in ipairs(cc) do
            if #cs > len then len = #cs end
          end
          local r = math.min(math.floor(0.75 * max_w), math.max(24, len + 6))
          return r + r % 2
        end,
        height = function(_, _, max_h)
          return math.min(math.floor(0.9 * max_h), #cc + 5)
        end
      }
    }
  end

  map("n", "<leader>fc", colorscheme, { desc = "[f]ind [c]colorscheme with telescope" })

  local function current_buffer_fuzzy_find()
    tb.current_buffer_fuzzy_find{
      previewer = false,
      layout_config = {
        prompt_position = "bottom"
      }
    }
  end

  map("n", "<leader>/", current_buffer_fuzzy_find, { desc = "[f]ind on current buffer with telescope" })

  local tm_i = require("telescope.mappings").default_mappings.i
  tm_i["<Esc>"] = tm_i["<C-c>"]  -- esc --
  tm_i["<M-k>"] = tm_i["<Up>"]   -- up --
  tm_i["<M-j>"] = tm_i["<Down>"] -- down --
  tm_i["<C-j>"] = tm_i["<C-d>"]  -- preview up --
  tm_i["<C-k>"] = tm_i["<C-u>"]  -- preview down --

  local function tm_i_new(kb, callback, name)
    local k = { name }
    tm_i[kb] = k
    setmetatable(k, getmetatable(tm_i["<C-c>"]))
    k["_func"][name] = callback
  end
  tm_i_new("<C-v>", function() vim.api.nvim_input("<C-r>+") end, "paste")

  prequire("noice", function()
    map("n", "<leader>fn", "<cmd>NoiceTelescope<cr>", { desc = "[f]ind noice [n]otification with telescope" })
  end)
end)

-- COMMENT --

prequire("Comment", function()
  local function cnorm()
    if vim.api.nvim_get_vvar("count") == 0 then
      return "<Plug>(comment_toggle_linewise_current)"
    else
      return "<Plug>(comment_toggle_linewise_count)"
    end
  end
  map("n", "<leader>c", cnorm, { expr = true, desc = "toggle [c]omments" })
  map("x", "<leader>c", "<Plug>(comment_toggle_linewise_visual)", { desc = "toggle [c]omments" })
end)

-- COC --

if pcall(vim.fn["coc#pum#visible"]) then
  map("i", "<tab>",   [[coc#pum#visible() ? coc#pum#next(1) : "<tab>"]], { expr = true, desc = "coc next suggestion" })
  map("i", "<s-tab>", [[coc#pum#visible() ? coc#pum#prev(1) : "<c-h>"]], { expr = true, desc = "coc previous suggestion" })
  -- map("i", "<M-n>", [[coc#pum#visible() ? coc#pum#next(1) : ""]], { expr = true, desc = "coc next suggestion" })
  -- map("i", "<M-N>", [[coc#pum#visible() ? coc#pum#prev(1) : ""]], { expr = true, desc = "coc previous suggestion" })

  -- map("i", "<Down>", [[coc#pum#visible() ? coc#pum#next(1) : "<Down>"]], { expr = true, desc = "coc next suggestion" })
  -- map("i", "<Up>",   [[coc#pum#visible() ? coc#pum#prev(1) : "<Up>"]],   { expr = true, desc = "coc previous suggestion" })

  -- TODO: coc#expandableOrJumpable()
  map("i", "<cr>", [[coc#pum#visible() ? coc#pum#confirm() : "<cr>"]], { expr = true, desc = "coc select suggestion" })
  -- map("i", "<tab>", [[coc#pum#visible() ? coc#pum#confirm() : "<tab>"]], { expr = true, desc = "coc select suggestion" })

  map("n", "<c-k>", "<cmd>call CocAction('diagnosticPrevious')<cr>", { desc = "coc previous error" })
  map("n", "<c-j>", "<cmd>call CocAction('diagnosticNext')<cr>",     { desc = "coc next error" })

  map("n", "<leader>ga", "<Plug>(coc-codeaction)",      { desc = "coc [g]o [c]ode action" })
  map("n", "<leader>gd", "<Plug>(coc-definition)",      { desc = "coc [g]o [d]efinition" })
  map("n", "<leader>gy", "<Plug>(coc-type-definition)", { desc = "coc [g]o t[y]pe definition" })
  map("n", "<leader>gi", "<Plug>(coc-implementation)",  { desc = "coc [g]o [i]mplementation" })
  map("n", "<leader>gr", "<Plug>(coc-references)",      { desc = "coc [g]o [r]eferences" })

  -- Remap for rename current word --
  map("n", "<leader>r", "<Plug>(coc-rename)", { desc = "coc rename" })
else
  if flags.warn_missing_module then
    notify_once.warn("Module 'coc' not found")
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "coc-marketplace" },
  callback = function(ev)
    local coc = require("coc")

    map("n", "q", "<cmd>q<CR>", { buffer = ev.buf })
    map("n", "<esc>", "<cmd>q<CR>", { buffer = ev.buf })

    map({ "n", "v" }, "<tab>", coc.marketplace.option.toggle, { buffer = ev.buf })
    map("n", "<CR>", coc.marketplace.run, { buffer = ev.buf })
  end
})

local LANGS_ORDER = {
  "NEW",
  "C",
  "NPM",
  "Java",
  "Kotlin",
  -- "C#", -- TODO
  "Lua"
}

LANGS = require("langs")

local select = function()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local lang = LANGS[string.lower(LANGS_ORDER[lnum])]
  vim.cmd.q()

  local dir = fs.mktmp()
  for name, content in pairs(lang.code) do
    local f = dir .. "/" .. name
    fs.mkfile(f, content, "p")
    if (vim.fn.has("win32") == 0) and (vim.fn.match(content[1], "^#!") == 0) then
      vim.system({ "chmod", "a+x", f }, { cwd = dir }):wait()
    end
  end
  for _, file in ipairs(lang.init) do
    vim.cmd.e(vim.fn.fnameescape(dir .. "/" .. file))
    vim.cmd[[belowright vsplit]]
  end
  vim.cmd.q()
  vim.cmd.cd(dir)
end

W.langs = window{
  on_show = function(self)
    vim.bo.bufhidden  = "hide"
    vim.bo.buftype    = "nofile"
    vim.bo.buflisted  = false
    vim.bo.swapfile   = false
    vim.bo.undolevels = -1

    vim.wo.scrolloff = 0
    vim.wo.sidescrolloff = 0

    vim.api.nvim_win_set_config(0, { title = " NEW ", title_pos = "center" })

    if vim.b.is_menu_loaded then return end
    vim.b.is_menu_loaded = true

    local NS = vim.api.nvim_create_namespace("")
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = 0,
      callback = function()
        local y, x = unpack(vim.api.nvim_win_get_cursor(0))
        x = math.max(x, vim.fn.match(vim.api.nvim_get_current_line(), "^ [^ ]* \\+\\zs[^ ]"))
        vim.api.nvim_win_set_cursor(0, { y, x })
      end
    })

    map("n", { "A", "I", "D", "R", "a", "i", "d", "r" }, "<Nop>", { buffer = self.buf })

    map("n", { "q", "<esc>" }, vim.cmd.q, { buffer = self.buf, desc = "quit" })
    map("n", "<CR>",  select, { buffer = self.buf, desc = "select" })

    vim.bo.modifiable = true

    for i, l in ipairs(LANGS_ORDER) do
      local lang = string.lower(l)
      local icon = LANGS[lang].icon
      vim.api.nvim_buf_set_lines(0, i-1, i-1, true, { " " .. icon .. "  " .. l })

      vim.api.nvim_buf_set_extmark(0, NS, i-1, 1, {
        end_col = #icon + 2,
        hl_group = LANGS[lang].hl,
        strict = false,
      })
    end

    vim.cmd[[norm! G"_ddgg]]
    vim.bo.modifiable = false

    vim.api.nvim_create_autocmd("WinLeave", {
      callback = function() self:hide() end,
      once = true
    })
  end,
  size = function()
    local width = 16
    local height = math.min(vim.o.lines - 10, #LANGS_ORDER)

    return {
      col    = math.ceil(vim.o.columns - width) * 0.5 - 1,
      row    = math.ceil(vim.o.lines - height) * 0.5 - 1,
      width  = width,
      height = height
    }
  end,
  focus = true,
  border = "rounded",
}

map("n", "<leader>ii", function() W.langs:show() end, { desc = "create example file" })