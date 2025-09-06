if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "coc-nvim"

syn match Label /^Install finished$/ oneline
syn match Label /^Update finished$/ oneline
syn match Label /^- ✓.*/ oneline
syn match Error /^- ✗.*/ oneline
