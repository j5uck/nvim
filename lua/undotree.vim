function! undotree#set(a)
  let s:gettime = a:a.gettime
  let s:log     = a:a.log
endfunction

"=================================================
" undotree panel class.
" extended from panel.
"

" {rawtree}
"     |
"     | ConvertInput()               {seq2index}--> [seq1:index1]
"     v                                             [seq2:index2] ---+
"  {tree}                                               ...          |
"     |                                    [asciimeta]               |
"     | Render()                                |                    |
"     v                                         v                    |
" [asciitree] --> [" * | SEQ DDMMYY "] <==> [node1{seq,time,..}]     |
"                 [" |/             "]      [node2{seq,time,..}] <---+
"                         ...                       ...


let s:undotree = {}

function! undotree#undotreeDeepcopy()
  return deepcopy(s:undotree)
endfunction

function! s:undotree._parseNode(in,out) abort
  " type(in) == type([]) && type(out) == type({})
  if empty(a:in) "empty
    return
  endif
  let curnode = a:out
  for i in a:in
    if has_key(i,'alt')
      call self._parseNode(i.alt,curnode)
    endif
    let newnode = { 'seq': i.seq, 'p': [], 'time': i.time }
    if has_key(i,'newhead')
      let self.seq_newhead = i.seq
    endif
    if has_key(i,'curhead')
      let self.seq_curhead = i.seq
      let self.seq_cur = curnode.seq
    endif
    if has_key(i,'save')
      let self.seq_saved[i.save] = i.seq
    endif
    call extend(curnode.p,[newnode])
    let curnode = newnode
  endfor
endfunction

function! s:undotree.ConvertInput() abort
  let self.seq_cur = -1
  let self.seq_curhead = -1
  let self.seq_newhead = -1
  let self.seq_saved = {}

  let self.tree = { 'seq': 0, 'p': [], 'time': 0 }

  call self._parseNode(self.rawtree.entries,self.tree)

  let self.seq_cur   = self.rawtree.seq_cur
  let self.save_last = self.rawtree.save_last

  " undo history is cleared
  if empty(self.rawtree.entries)
    let self.seq_cur = 0
  endif
endfunction

"
" Example:
" 6 8  7
" |/   |
" 2    4
"  \   |
"   1  3  5
"    \ | /
"      0

" Tree sieve, p:fork, x:none
"
" x         8
" 8x        | 7
" 87         \ \
" x87       6 | |
" 687       |/ /
" p7x       | | 5
" p75       | 4 |
" p45       | 3 |
" p35       | |/
" pp        2 |
" 2p        1 |
" 1p        |/
" p         0
" 0

" Convert self.tree -> self.asciitree
function! s:undotree.Render() abort
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
    let minseq = 99999999
    let minnode = {}
    if foundx == 0
      "assume undo level isn't more than this... of course
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
      let newline = newline.'   '.(node.seq).'    '.
                \'('.s:gettime(node.time).')'
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
endfunction
