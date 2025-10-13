if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "undotree"

syn match Question   ' \zs\*\ze '       " Node
syn match Statement  '\zs\*\ze.*>\d\+<' " NodeCurrent
syn match Function   '(.*)$'            " TimeStamp
syn match Constant   '[\|\/\\]'         " Branch

syn match Comment    ' \zs\d\+\ze '     " Seq
syn match Statement  '>\d\+<'           " Current
syn match Type       '{\d\+}'           " Next
syn match Identifier '\[\d\+]'          " Head
syn match WarningMsg ' \zss\ze '        " SavedSmall
syn match MatchParen ' \zsS\ze '        " SavedBig
