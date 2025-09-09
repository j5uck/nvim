local log, notify = (function()
  local _ = require("_")
  return _.log, _.notify
end)()

vim.cmd.source{ vim.fn.stdpath("config") .. "/lua/undotree.vim" }

local M = {}

M.new = function()
  return vim.api.nvim_win_call(0, function()
    vim.cmd[[noautocmd silent topleft vertical 25 split undotree://]]

    vim.cmd("let t:undotree.w.undo = " .. vim.api.nvim_get_current_win())

    vim.bo.bufhidden  = "delete"
    vim.bo.buflisted  = false
    vim.bo.buftype    = "nowrite"
    vim.bo.filetype   = "undotree"
    vim.bo.modifiable = false
    vim.bo.swapfile   = false
    vim.bo.syntax     = "undotree"
    vim.bo.undolevels = -1

    vim.wo.cursorcolumn   = false
    vim.wo.cursorline     = true
    vim.wo.foldcolumn     = "0"
    vim.wo.list           = false
    vim.wo.number         = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn     = "no"
    vim.wo.spell          = false
    vim.wo.winfixwidth    = true
    vim.wo.wrap           = false

    vim.b.is_undotree = true

    vim.cmd.clearjumps()

    return vim.t.undotree.w.undo
  end)
end

M.toggle = function()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local undotree_wins = vim.tbl_filter(function(w)
    return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "undotree"
  end, wins)

  if #undotree_wins == 0 then
    local w = M.new()
    vim.cmd("let t:undotree.b.target = -1") -- force update
    vim.api.nvim_win_call(0, M.update)
    vim.api.nvim_set_current_win(w)
  else
    if vim.o.filetype == "undotree" then
      for _, w in ipairs(wins) do
        if vim.api.nvim_win_get_buf(w) == vim.t.undotree.b.target then
          vim.api.nvim_set_current_win(w)
          break
        end
      end
    end
    for _, w in ipairs(undotree_wins) do
      vim.api.nvim_win_call(w, vim.cmd.q)
    end
  end
end

M.gettime = function(time)
  if time == 0 then
    return "Orig"
  end
  local sec = vim.fn.localtime() - time
  if sec < 60 then
    return sec .. " s"
  elseif sec < 3600 then
    return math.floor(sec/60) .. " m"
  elseif sec < 86400 then -- 3600*24
    return math.floor(sec/3600) .. " h"
  else
    return math.floor(sec/86400) .. " d"
  end
end

local EMPTY_UNDOTREE = {
  entries = {},
  save_cur = 0,
  save_last = 0,
  seq_cur = 0,
  seq_last = 0,
  synced = 1,
  time_cur = 0
}

M.update = function()
  local skip = vim.b.is_undotree or
    (not vim.api.nvim_win_is_valid(vim.t.undotree.w.undo)) or
    vim.api.nvim_win_get_config(0).zindex

  if skip then return end

  local reuse_buf = false
  local buf = vim.api.nvim_get_current_buf()

  if vim.bo.modifiable and #vim.bo.buftype == 0 then
    vim.cmd[[let t:undotree._rawtree = undotree()]]
    local new, old = vim.t.undotree.rawtree, vim.t.undotree._rawtree

    if vim.t.undotree.b.target == buf and old.seq_last == new.seq_last then
      vim.cmd[[let t:undotree.rawtree = t:undotree._rawtree]]
      vim.cmd[[call t:undotree.ConvertInput()]]
      reuse_buf = old.seq_cur ~= new.seq_cur or old.save_last ~= new.save_last
    end

    vim.cmd[[let t:undotree.rawtree = t:undotree._rawtree]]
  else
    vim.cmd[[
      let t:undotree.rawtree = {
          \'seq_last':0,
          \'entries':[],
          \'time_cur':0,
          \'save_last':0,
          \'synced':1,
          \'save_cur':0,
          \'seq_cur':0
        \}
    ]]
  end

  if not reuse_buf then
    vim.cmd("let t:undotree.b.target = " .. buf)
    vim.cmd[[
      let t:undotree.seq_last = t:undotree.rawtree.seq_last
      let t:undotree.seq_cur = -1
      let t:undotree.seq_curhead = -1
      let t:undotree.seq_newhead = -1
      call t:undotree.ConvertInput() "update all.
    ]]

    M.render()
  end

  vim.api.nvim_win_call(vim.t.undotree.w.undo, function()
    vim.bo.modifiable = true

    local u = vim.t.undotree
    local text = u.asciitree

    for _, v in pairs(u.seq_saved) do
      local i = u.seq2index[tostring(v)] + 1
      text[i] = vim.fn.substitute(text[i], "\\zs \\ze (","s","")
    end

    if #vim.tbl_keys(u.seq_saved) > 0 then
      local _i = u.seq_saved[tostring(u.save_last)]
      if _i then
        local i = u.seq2index[tostring(_i)] + 1
        text[i] = vim.fn.substitute(text[i], "s","S","")
      else
        text[1] = vim.fn.substitute(text[1], "\\zs \\ze (","S","")
      end
    end

    if u.seq_cur ~= -1 then
      local i = u.seq2index[tostring(u.seq_cur)] + 1
      text[i] = vim.fn.substitute(text[i], "\\zs \\(\\d\\+\\) \\ze [sS ] ", ">\\1<", "")
    end

    if u.seq_curhead ~= -1 then
      local i = u.seq2index[tostring(u.seq_curhead)] + 1
      text[i] = vim.fn.substitute(text[i], "\\zs \\(\\d\\+\\) \\ze [sS ] ", "{\\1}", "")
    end

    if u.seq_newhead ~= -1 then
      local i = u.seq2index[tostring(u.seq_newhead)] + 1
      text[i] = vim.fn.substitute(text[i], "\\zs \\(\\d\\+\\) \\ze [sS ] ", "[\\1]", "")
    end

    vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.fn.reverse(text))
    vim.bo.modifiable = false

    if u.seq_cur ~= -1 then
      vim.cmd("silent normal! " .. #u.asciitree - u.seq2index[tostring(u.seq_cur)] .. "G")
    end
  end)

  vim.cmd[[silent! unlet t:undotree._rawtree]]
end

M.render = function()
  vim.cmd[[call t:undotree.Render()]]
end

vim.fn["undotree#set"]{
  log = log,
  gettime = M.gettime
}

vim.api.nvim_create_autocmd("BufNew", { callback = vim.schedule_wrap(function(ev)
  if not vim.api.nvim_buf_is_valid(ev.buf) then return end
  if vim.bo[ev.buf].filetype ~= "undotree" then return end

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = ev.buf,
    callback = function()
      vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], 0 })
    end
  })
end) })

local function fn_TabNew()
  vim.cmd[[
    let t:undotree = undotree#undotreeDeepcopy()

    let t:undotree.w = { "undo": -1, "target": -1 }
    let t:undotree.b = { "undo": -1, "target": -1 }

    let t:undotree.rawtree = {}  "data passed from undotree()
    let t:undotree.tree = {}     "data converted to internal format.
    let t:undotree.seq_last = -1
    let t:undotree.save_last = -1

    " seqs
    let t:undotree.seq_cur = -1
    let t:undotree.seq_curhead = -1
    let t:undotree.seq_newhead = -1
    let t:undotree.seq_saved = {} "{saved value -> seq} pair

    let t:undotree.asciitree = []     "output data.
    let t:undotree.asciimeta = []     "meta data behind ascii tree.
    let t:undotree.seq2index = {}     "table used to convert seq to index.
  ]]
end

fn_TabNew()
vim.api.nvim_create_autocmd("TabNew", { callback = fn_TabNew })

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "undotree://*",
  callback = function()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, w in ipairs(wins) do
      local _ = vim.b[vim.api.nvim_win_get_buf(w)].is_undotree or
        vim.api.nvim_win_get_config(w).zindex
      if not _ then return end
    end
    for _, id in ipairs(wins) do
      local status, msg = pcall(vim.api.nvim_win_call, id, vim.cmd.q)
      if not status then
        msg = string.gsub(vim.fn.split(msg, "\n")[1], "Error executing lua: (.*)", "%1")
        notify.error(msg) end
    end
  end
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "CursorMoved", "InsertLeave" }, {
  callback = function() vim.api.nvim_win_call(0, M.update) end
})

vim.api.nvim_create_autocmd("CursorMoved", {
  pattern = "undotree://",
  callback = function()
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], 0 })
  end
})

local function do_cmd_wrap(cmd)
  return function()
    vim.api.nvim_buf_call(vim.t.undotree.b.target, function()
      vim.cmd("silent exe '" .. cmd .. "' | silent normal! zv")
      M.update()
    end)
  end
end

return {
  toggle = M.toggle,
  undo = do_cmd_wrap("undo"),
  redo = do_cmd_wrap("redo"),
  prev = do_cmd_wrap("earlier"),
  next = do_cmd_wrap("later"),
  prev_save = do_cmd_wrap("earlier 1f"),
  next_save = do_cmd_wrap("later 1f"),
  select = function()
    do_cmd_wrap("undo " .. vim.t.undotree.asciimeta[vim.fn.line(".")].seq)()
  end
}
