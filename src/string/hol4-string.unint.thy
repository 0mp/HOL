name: hol-string-unint
version: 1.0
description: HOL string theories (before re-interpretation)
author: HOL developers <hol-developers@lists.sourceforge.net>
license: MIT
main {
  import: string
  import: string-num
  import: ascii-numbers
}
string {
  article: "string.ot.art"
}
string-num {
  import: string
  article: "string_num.ot.art"
}
ascii-numbers {
  import: string
  article: "ASCIInumbers.ot.art"
}
