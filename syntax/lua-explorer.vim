if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "lua-explorer"

syn match Error /%./ oneline
syn match Error /%$/ oneline
syn match Error /%=>/ oneline

if !has("win32")
  syn match Special /%[nprs]/ oneline
  syn match Comment / %=> / oneline
endif

syn match WarningMsg /^\/\d*/ conceal oneline
syn match WarningMsg /%D / conceal oneline
