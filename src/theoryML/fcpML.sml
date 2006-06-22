open numML

exception IndexUndefined

datatype holtype = Tyvar of string
                 | Tyop of string * holtype list

datatype ('a, 'b) cart = n2w_itself of num * holtype

type 'a itself = holtype

val lookup_dimindex = ref (fn (a: holtype) => (raise IndexUndefined):num)
fun dimindex a = !lookup_dimindex a
