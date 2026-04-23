if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "undotree"

syn match Question   / \zs\*\ze / oneline       " Node
syn match Statement  /\zs\*\ze.*>\d\+</ oneline " NodeCurrent
syn match Function   /(.*)$/ oneline            " TimeStamp
syn match Constant   /[\|\/\\]/ oneline         " Branch

syn match Comment    / \zs\d\+\ze / oneline     " Seq
syn match Statement  />\d\+</ oneline           " Current
syn match Type       /{\d\+}/ oneline           " Next
syn match Identifier /\[\d\+]/ oneline          " Head
syn match WarningMsg / \zss\ze / oneline        " SavedSmall
syn match MatchParen / \zsS\ze / oneline        " SavedBig
