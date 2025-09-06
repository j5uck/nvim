if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "lua-explorer"

syn match Error /%./ oneline
syn match Error /%$/ oneline
syn match Error /%=>/ oneline

syn match Special /%[nprs]/ oneline
syn match Comment / %=> / oneline

syn match LEId /^\/\d*/ conceal oneline
syn match LEDelimiter /%D / conceal oneline


hi def link LEId WarningMsg
hi def link LEDelimiter WarningMsg
