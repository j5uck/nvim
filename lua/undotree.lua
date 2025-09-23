local M = {}

M.new = function()
  local r
  vim.api.nvim_win_call(0, function()
    vim.cmd[[noautocmd silent topleft vertical 25 split undotree://]]

    r = vim.api.nvim_get_current_win()
    vim.cmd("let t:undotree.w.undo = " .. r)

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
  end)
  return r
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

M.update = function()
  local skip = vim.b.is_undotree or
    (not vim.api.nvim_win_is_valid(vim.t.undotree.w.undo)) or
    vim.api.nvim_win_get_config(0).zindex

  if skip then return end

  local changes = true
  local buf = vim.api.nvim_get_current_buf()
  local t_undotree = vim.t.undotree

  if vim.bo.modifiable and #vim.bo.buftype == 0 then
    local new, old = vim.fn.undotree(), t_undotree.rawtree

    if vim.t.undotree.b.target == buf and old.seq_last == new.seq_last then
      changes = old.seq_cur   ~= new.seq_cur or  -- current index
                old.seq_last  ~= new.seq_last or -- max index
                old.save_last ~= new.save_last   -- last save (index save)
    end

    t_undotree.rawtree = new
  else
    t_undotree.rawtree = {
      entries   = {},
      save_cur  = 0,
      save_last = 0,
      seq_cur   = 0,
      seq_last  = 0,
      synced    = 1,
      time_cur  = 0
    }
  end

  if changes then
    t_undotree.b.target = buf
    t_undotree.seq_last = t_undotree.rawtree.seq_last
    t_undotree.seq_cur = -1
    t_undotree.seq_curhead = -1
    t_undotree.seq_newhead = -1
    t_undotree.seq_saved = vim.empty_dict()
    t_undotree.tree = { seq = 0, p = {}, time =  0 }

    vim.t.undotree = t_undotree
    vim.cmd[[
      function! s:parseNode(in,out) abort
        " type(in) == type([]) && type(out) == type({})
        if empty(a:in) "empty
          return
        endif
        let curnode = a:out
        for i in a:in
          if has_key(i,'alt')
            call s:parseNode(i.alt,curnode)
          endif
          let newnode = { 'seq': i.seq, 'p': [], 'time': i.time }
          if has_key(i,'newhead')
            let t:undotree.seq_newhead = i.seq
          endif
          if has_key(i,'curhead')
            let t:undotree.seq_curhead = i.seq
            let t:undotree.seq_cur = curnode.seq
          endif
          if has_key(i,'save')
            let t:undotree.seq_saved[i.save] = i.seq
          endif
          call extend(curnode.p,[newnode])
          let curnode = newnode
        endfor
      endfunction

      call s:parseNode(t:undotree.rawtree.entries, t:undotree.tree)
    ]]
    t_undotree = vim.t.undotree

    t_undotree.seq_cur = t_undotree.rawtree.seq_cur
    t_undotree.save_last = t_undotree.rawtree.save_last

    if #t_undotree.rawtree.entries == 0 then
      t_undotree.seq_cur = 0
    end

    vim.t.undotree = t_undotree

    M.render()
  else
    vim.t.undotree = t_undotree
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
      vim.api.nvim_win_set_cursor(0, { #u.asciitree - u.seq2index[tostring(u.seq_cur)], 0 })
    end
  end)
end

-- Example --

-- 6 8  7
-- |/   |
-- 2    4
--  \   |
--   1  3  5
--    \ | /
--      0

-- Tree sieve, p:fork, x:none --

-- x         8
-- 8x        | 7
-- 87         \ \
-- x87       6 | |
-- 687       |/ /
-- p7x       | | 5
-- p75       | 4 |
-- p45       | 3 |
-- p35       | |/
-- pp        2 |
-- 2p        1 |
-- 1p        |/
-- p         0
-- 0

M.render = function()
  vim.t.gettime = M.gettime
  vim.cmd[[
    let tree = t:undotree.tree
    let slots = [tree]
    let out = []
    let outmeta = []
    let seq2index = {}
    let TYPE_E = type({})
    let TYPE_P = type([])
    let TYPE_X = type('x')
    while slots != []
      "find next node
      let foundx = 0 " 1 if x element is found.
      let index = 0 " Next element to be print.

      " Find x element first.
      for i in range(len(slots))
        if type(slots[i]) == TYPE_X
          let foundx = 1
          let index = i
          break
        endif
      endfor

      " Then, find the element with minimum seq.
      let minseq = t:undotree.seq_last + 1
      let minnode = {}
      if foundx == 0
        for i in range(len(slots))
          if type(slots[i]) == TYPE_E
            if slots[i].seq < minseq
              let minseq = slots[i].seq
              let index = i
              let minnode = slots[i]
              continue
            endif
          endif
          if type(slots[i]) == TYPE_P
            for j in slots[i]
              if j.seq < minseq
                let minseq = j.seq
                let index = i
                let minnode = j
                continue
              endif
            endfor
          endif
        endfor
      endif

      " output.
      let newline = " "
      let newmeta = {}
      let node = slots[index]
      if type(node) == TYPE_X
        let newmeta = { 'seq': -1, 'p': [], 'time': -1 } "invalid node.
        if index+1 != len(slots) " not the last one, append '\'
          for i in range(len(slots))
            if i < index
              let newline = newline.'| '
            endif
            if i > index
              let newline = newline.' \'
            endif
          endfor
        endif
        call remove(slots,index)
      endif
      if type(node) == TYPE_E
        let newmeta = node
        let seq2index[node.seq]=len(out)
        for i in range(len(slots))
          if index == i
            let newline = newline.'* '
          else
            let newline = newline.'| '
          endif
        endfor
        let newline = newline.'   '.(node.seq).'    ('.t:gettime(node.time).')'
        " update the printed slot to its child.
        if empty(node.p)
          let slots[index] = 'x'
        endif
        if len(node.p) == 1 "only one child.
          let slots[index] = node.p[0]
        endif
        if len(node.p) > 1 "insert p node
          let slots[index] = node.p
        endif
        let node.p = [] "cut reference.
      endif
      if type(node) == TYPE_P
        let newmeta = { 'seq': -1, 'p': [], 'time': -1 } "invalid node.
        for k in range(len(slots))
          if k < index
            let newline = newline."| "
          endif
          if k == index
            let newline = newline."|/ "
          endif
          if k > index
            let newline = newline."/ "
          endif
        endfor
        call remove(slots,index)
        if len(node) == 2
          if node[0].seq > node[1].seq
            call insert(slots,node[1],index)
            call insert(slots,node[0],index)
          else
            call insert(slots,node[0],index)
            call insert(slots,node[1],index)
          endif
        endif
        " split P to E+P if elements in p > 2
        if len(node) > 2
          call remove(node,index(node,minnode))
          call insert(slots,minnode,index)
          call insert(slots,node,index)
        endif
      endif
      unlet node
      if newline != " "
        let newline = substitute(newline,'\s*$','','g') "remove trailing space.
        call add(out,newline)
        call add(outmeta,newmeta)
      endif
    endwhile

    let t:undotree.asciitree = out
    " let t:undotree.asciitree = reverse(out)
    let t:undotree.asciimeta = reverse(outmeta)

    " let totallen = len(out)
    " for i in keys(seq2index)
    "   let seq2index[i] = totallen - 1 - seq2index[i]
    " endfor
    let t:undotree.seq2index = seq2index
  ]]
end

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
  vim.t.undotree = {
    w = { undo = -1, target = -1 },
    b = { undo = -1, target = -1 },

    asciimeta   = {},               -- meta data behind ascii tree.
    asciitree   = {},               -- output data.
    rawtree     = vim.empty_dict(), -- data passed from undotree()
    save_last   = -1,
    seq2index   = vim.empty_dict(), -- table used to convert seq to index.
    seq_cur     = -1,
    seq_curhead = -1,
    seq_last    = -1,
    seq_newhead = -1,
    seq_saved   = vim.empty_dict(), -- { saved value -> seq } pair
    tree        = vim.empty_dict(), -- data converted to internal format.
  }
end

fn_TabNew()
vim.api.nvim_create_autocmd("TabNew", { callback = fn_TabNew })

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "undotree://*",
  callback = function()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, w in ipairs(wins) do
      local is_undotree = vim.b[vim.api.nvim_win_get_buf(w)].is_undotree or
        vim.api.nvim_win_get_config(w).zindex
      if not is_undotree then return end
    end
    for _, id in ipairs(wins) do
      local status, msg = pcall(vim.api.nvim_win_call, id, vim.cmd.q)
      if not status then
        msg = string.gsub(vim.fn.split(msg, "\n")[1], "Error executing lua: (.*)", "%1")
        require("_").notify.error(msg)
      end
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
