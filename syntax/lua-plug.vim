if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "lua-plug"

syn match Normal /^\/\d* / conceal oneline

syn match Boolean /^+/ oneline
syn match Type /\(^+ \)\@<=.*:/ oneline
syn match Comment /^\~.*/ oneline
syn match Special /^-/ oneline
syn match PlugSyncDone /\(^- \)\@<=.*:/ oneline
syn match Error /^x.*:/ oneline
