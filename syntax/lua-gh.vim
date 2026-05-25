if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "lua-gh"

syn match Function /^ \[ \]\@=..\+/ oneline
syn match String /^ \[✓\]\@=..\+/ oneline
