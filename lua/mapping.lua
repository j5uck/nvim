
local notify, notify_once, flags, window, prequire = (function()
  local _ = require("_")
  return _.notify, _.notify_once, _.flags, _.window, _.prequire
end)()
local explorer = require("explorer")

vim.g.mapleader = " "

local function map(mode, lhs, rhs, opts)
  opts = vim.tbl_extend("force", { noremap = true, silent = true }, opts or {})

  for _, l in ipairs(type(lhs) == "string" and { lhs } or lhs) do
    vim.keymap.set(mode, l, rhs, opts)
  end
end

map("n", { "<leader>", "<leader>f", "<CR>", "<leader><s-q>", "&" }, "<Nop>", { desc = "do nothing" })
map({ "n", "i", "v" }, { "<MiddleMouse>", "<2-MiddleMouse>", "<3-MiddleMouse>", "<4-MiddleMouse>" }, "<Nop>", { desc = "do nothing" })

map("i", { "<c-Space>" }, "<esc>", { desc = "escape" })
map({"i", "t"}, "<M-o>", "<c-\\><c-n>", { desc = "escape" })

map("n", "U", "<C-r>", { desc = "redo" })

map("n", "<leader>T", "<cmd>tabnew<CR>", { desc = "[t]erminal" })

map({"i", "c"}, "<c-a>", "<Home>", { desc = "go to line start" })
map({"i", "c"}, "<c-e>", "<End>",  { desc = "go to line end" })

map("n", "<", "V<",  { desc = "tab" })
map("n", ">", "V>",  { desc = "un-tab" })
map("v", "<", "<gv", { desc = "tab" })
map("v", ">", ">gv", { desc = "un-tab" })

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
map({"n", "v"}, "<leader>P", "\"+P", { desc = "[p]aste from \"+" })

map("n", "<leader>w", "<cmd>w<CR>", { desc = "[w]rite" })
map("n", "<leader>x", "<cmd>x<CR>", { desc = "write & e[x]it" })

map("n", "<leader>q", "<cmd>q<CR>",  { desc = "[q]uit" })
map("n", "<leader>Q", "<cmd>q!<CR>", { desc = "forced [Q]uit" })

map("n", "<leader>s", "<cmd>%lua<CR>", { desc = "[s]ource" })
map("v", "<leader>s", ":lua<CR>",      { desc = "[s]ource" })

map("n", "<leader>o", "o<esc>0\"_D", { desc = "create new line" })
map("n", "<leader>O", "O<esc>0\"_D", { desc = "create new line" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf" },
  callback = function()
    map("n", "<CR>", "<cmd>.cc<CR>", { buffer = true, desc = "go to error" })
  end
})

vim.fn.setreg("q", "")
map("n", "Q", "qq", { desc = "record macro on [q] register" })
map("n", ",", "@q", { desc = "do [q] macro" })
map("v", ",", "<cmd>norm @q<CR>", { desc = "do [q] macro" })

map("n", "<leader>t", [[<cmd>exe "terminal" | startinsert<CR>]], { desc = "[t]erminal" })

map("n", "<leader>a", function()
  notify.info("%s", vim.fn.expand("%:p"))
end, { desc = "show buffer path" })

map("n", "<leader>A", function()
  local b = vim.fn.expand("%:p")
  notify.info("%s", b)
  vim.fn.setreg("\"", b)
  vim.fn.setreg("+", b)
end, { desc = "copy buffer path" })

map("n", "<c-h>", "<c-o>", { desc = "jump to previous location" })
map("n", "<c-l>", "<c-i>", { desc = "jump to next location" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help" },
  callback = function()
    map("n", "<CR>", "<c-]>", { buffer = true, desc = "go to tag" })
  end
})

map("n", "<leader>l", ":lua require(\"_\").log()<left>", { silent = false, desc = "open [l]ua cmd" })
map("n", "<leader>0", "<cmd>only<CR> ", { desc = "[0]nly" })

map("n", "<leader>W", function()
  vim.opt_local.wrap = not vim.o.wrap
  notify.warn(vim.o.wrap and ":set wrap" or ":set nowrap")
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

map("n", "<leader>E", explorer.open, { desc = "open file tre[e]"})
map("n", "<leader>e", explorer.resume, { desc = "resume file tre[e]"})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua-explorer" },
  callback = function()
    map("n", "<esc>", "<cmd>q<CR>", { buffer = true })

    map("n", "<2-LeftMouse>", explorer.select, { buffer = true })
    map("n", "<CR>", explorer.select, { buffer = true })

    map("n", "<c-h>", explorer.go_back, { buffer = true })
    map("n", "<c-l>", explorer.go_next, { buffer = true })
    map("n", "<c-k>", explorer.go_up, { buffer = true })

    map("n", "<M-h>", explorer.go_back, { buffer = true })
    map("n", "<M-j>", "<Nop>", { buffer = true })
    map("n", "<M-k>", explorer.go_up, { buffer = true })
    map("n", "<M-l>", explorer.go_next, { buffer = true })

    map("n", "<leader>A", function()
      local s = explorer.buf_get_name()
      notify.info("%s", s)
      vim.fn.setreg([["]], s)
      vim.fn.setreg([[+]], s)
    end, { buffer = true })
  end
})

local fw = window:new{
  on_show = vim.schedule_wrap(function(ev)
    vim.cmd[[norm! 0]]
    local n = vim.api.nvim_buf_get_name(ev.buf)
    if vim.fn.match(n, "^term://.*") == -1 then
      vim.cmd.term()
    end
    vim.cmd.clearjumps()
    vim.cmd.startinsert()
  end),
  size = function()
    local width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
    local height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))
    local col = math.ceil(vim.o.columns - width) * 0.5 - 1
    local row = math.ceil(vim.o.lines - height) * 0.5 - 1

    return {
      col    = col,
      row    = row,
      width  = width,
      height = height
    }
  end,
  hl = function() return {
    Normal = {},
    Insert = {},
    FloatBorder = {}
  } end,
  focus = true,
  focusable = true,
  border = "rounded",
}

map({"n", "v", "t"}, "<c-Space>", function() fw:toggle() end, { desc = "toggle floating terminal" })

map("n", "<leader>ic", function()
  vim.cmd.cd{vim.fn.stdpath("config"), mods = { silent = true }}
  vim.cmd[[silent! Telescope find_files]]
end, { desc = "go to config" })

map("n", "<leader>ip", function()
  vim.cmd.cd{vim.fn.stdpath("data") .. "/plug", mods = { silent = true }}
  explorer.open()
end, { desc = "go to plug config" })

do
  local status, lualine = pcall(require, "lualine")
  if not status then
    lualine = { hide = function(_) end, refresh = function(_) end }
  end

  local toggle = false
  map("n", "<leader>z", function()
    toggle = not toggle
    if toggle then
      vim.cmd.IBLDisable{ mods = { silent = true }}
      lualine.hide()
      lualine.refresh{ force = true }
    else
      vim.cmd.IBLEnable{ mods = { silent = true }}
      lualine.hide{ unhide = true }
      lualine.refresh{ force = true }
    end
  end, { desc = "zen mode" })
end

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
  callback = function()
    map("n", { "<CR>", "2-LeftMouse" }, undotree.select, { buffer = true, desc = "Select state" })
    map("n", "u", undotree.undo, { buffer = true, desc = "Undo" })
    map("n", { "U", "<c-r>" }, undotree.redo, { buffer = true, desc = "Redo" })
  end
})

-- WINDOWS --

prequire("windows", function()
  local m = "<cmd>silent! exe 'WindowsEqualize' | silent! WindowsMaximize<CR>"
  map("n", "<leader>M", m, { desc = "[M]aximize buffer window" })
  map("n", "<leader>N", "<cmd>silent! WindowsEqualize<CR>", { desc = "equalize buffer window" })
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

  map({"n","v"}, "<leader>*", tb.grep_string, { desc = "search selected string [telescope]" })

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

  map("i", "<cr>",
    [[coc#pum#visible() && coc#expandableOrJumpable() ? coc#pum#confirm() : "<cr>"]],
    { expr = true, desc = "coc select suggestion" })

  map("n", "<c-k>", "<cmd>call CocAction('diagnosticPrevious')<cr>", { desc = "coc previous error" })
  map("n", "<c-j>", "<cmd>call CocAction('diagnosticNext')<cr>",     { desc = "coc next error" })

  map("n", "<leader>gd", "<Plug>(coc-definition)",      { desc = "coc go definition" })
  map("n", "<leader>gy", "<Plug>(coc-type-definition)", { desc = "coc go type definition" })
  map("n", "<leader>gi", "<Plug>(coc-implementation)",  { desc = "coc go implementation" })
  map("n", "<leader>gr", "<Plug>(coc-references)",      { desc = "coc go references" })

  -- Remap for rename current word --
  map("n", "<leader>r", "<Plug>(coc-rename)", { desc = "coc rename" })

else
  if flags.warn_missing_module then
    notify_once.warn("Module 'coc' not found")
  end
end

