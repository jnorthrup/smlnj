(* COPYRIGHT (c) 1996 Bell Laboratories *)
(* plambda.sig *)

signature PLAMBDA = sig

type tkind = LtyKernel.tkind
type tyc = LtyKernel.tyc
type lty = LtyKernel.lty
type lvar = LambdaVar.lvar

type dataconstr = Symbol.symbol * Access.conrep * lty

datatype con 
  = DATAcon of dataconstr
  | INTcon of int
  | INT32con of Int32.int
  | WORDcon of word
  | WORD32con of Word32.word
  | REALcon of string
  | STRINGcon of string
  | VLENcon of int 

datatype lexp
  = VAR of lvar
  | INT of int
  | INT32 of Int32.int
  | WORD of word
  | WORD32 of Word32.word
  | REAL of string
  | STRING of string
  | PRIM of PrimOp.primop * lty * tyc list
  | GENOP of dict * PrimOp.primop * lty * tyc list
 
  | FN of lvar * lty * lexp
  | FIX of lvar list * lty list * lexp list * lexp
  | APP of lexp * lexp
  | LET of lvar * lexp * lexp

  | TFN of tkind list * lexp
  | TAPP of lexp * tyc list

  | EXNF of lexp * lty                 
  | EXNC of lexp              
  | RAISE of lexp * lty 
  | HANDLE of lexp * lexp

  | CON of dataconstr * tyc list * lexp
  | DECON of dataconstr * tyc list * lexp
  | SWITCH of lexp * Access.consig * (con * lexp) list * lexp option

  | VECTOR of lexp list * tyc
  | RECORD of lexp list
  | SRECORD of lexp list    
  | SELECT of int * lexp

  | PACK of lty * tyc list * tyc list * lexp   
  | WRAP of tyc * bool * lexp
  | UNWRAP of tyc * bool * lexp

withtype dict = {default: lexp, table: (tyc list * lexp) list}

end (* signature PLAMBDA *)
