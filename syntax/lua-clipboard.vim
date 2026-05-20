if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "lua-clipboard"

syn match LuaClipboardText /^.*$/ oneline

syn match Error /%./ oneline
syn match Error /%$/ oneline
syn match Special /%[%nr]/ oneline
