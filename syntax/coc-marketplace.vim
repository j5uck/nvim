if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "coc-marketplace"

" [ ] => no installed
" [✓] => installed
" [✗] => to remove
" [~] => to install

syn match Underlined /\(^\[.\] \)\@<=[^ ]\+/ oneline
syn match Function   /\(^\[ \] \)\@<=[^ ]\+/ oneline
syn match String     /\(^\[✓\] \)\@<=[^ ]\+/ oneline
syn match Error      /\(^\[✗\] \)\@<=[^ ]\+/ oneline
syn match Boolean   /\(^\[\~\] \)\@<=[^ ]\+/ oneline

syn match String  /\(^\[\)\@<=✓/  oneline
syn match Error   /\(^\[\)\@<=✗/  oneline
syn match Boolean /\(^\[\)\@<=\~/ oneline

syn match Boolean /^\[/ oneline
syn match Boolean /\(^\[.\)\@<=\]/ oneline
syn match Comment /\(^\[.\] [^ ]\+[ ]\+\)\@<=.*/ oneline
