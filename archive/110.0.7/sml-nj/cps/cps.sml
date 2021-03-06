(* Copyright 1996 by Bell Laboratories *)
(* cps.sml *)

structure CPS = struct

local structure PT = PrimTyc
      fun bug s = ErrorMsg.impossible ("CPS:" ^ s)
in

structure P = struct

    (* numkind includes kind and size *)
    datatype numkind = INT of int | UINT of int | FLOAT of int

    datatype arithop = + | - | * | / | ~ | abs
	             | lshift | rshift | rshiftl | andb | orb | xorb | notb

    datatype cmpop = > | >= | < | <= | eql | neq

    (* fcmpop conforms to the IEEE std 754 predicates. *)
    datatype fcmpop 
      = fEQ (* = *)  | fULG (* ?<> *) | fUN (* ? *)   | fLEG (* <=> *) 
      | fGT (* > *)  | fGE  (* >= *)  | fUGT (* ?> *) | fUGE (* ?>= *) 
      | fLT (* < *)  | fLE  (* <= *)  | fULT (* ?< *) | fULE (* ?<= *) 
      | fLG (* <> *) | fUE  (* ?= *)

    (* These are two-way branches dependent on pure inputs *)
    datatype branch
      = cmp of {oper: cmpop, kind: numkind}    (* numkind cannot be FLOAT *)
      | fcmp of {oper: fcmpop, size: int}
      | boxed | unboxed | peql | pneq
      | streq | strneq 
          (* streq(n,a,b) is defined only if strings a and b have
	     exactly the same length n>1 *)

  (* These all update the store *)
    datatype setter
      = numupdate of {kind: numkind}
      | unboxedupdate | boxedupdate | update
      | sethdlr | setvar | uselvar | setspecial
      | free | acclink | setpseudo | setmark

  (* These fetch from the store, never have functions as arguments. *)
    datatype looker
      = ! | subscript | numsubscript of {kind: numkind} | getspecial | deflvar
      | getrunvec | gethdlr | getvar | getpseudo

  (* These might raise exceptions, never have functions as arguments.*)
    datatype arith
      = arith of {oper: arithop, kind: numkind}
      | test of int * int
      | testu of int * int
      | round of {floor: bool, fromkind: numkind, tokind: numkind}

  (* These don't raise exceptions and don't access the store. *)
    datatype pure
      = pure_arith of {oper: arithop, kind: numkind}
      | pure_numsubscript of {kind: numkind}
      | length | objlength | makeref
      | extend of int * int | trunc of int * int | copy of int * int
      | real of {fromkind: numkind, tokind: numkind}
      | subscriptv
      | gettag | mkspecial | wrap | unwrap | cast | getcon | getexn
      | fwrap | funwrap | iwrap | iunwrap | i32wrap | i32unwrap

    local 
      fun ioper (op > : cmpop)  = (op <= : cmpop)
	| ioper op <= = op >
	| ioper op <  = op >= 
	| ioper op >= = op <
	| ioper eql   = neq 
	| ioper neq   = eql

      fun foper fEQ   = fULG
	| foper fULG  = fEQ
	| foper fGT   = fULE
	| foper fGE   = fULT
	| foper fLT   = fUGE
	| foper fLE   = fUGT
	| foper fLG   = fUE
	| foper fLEG  = fUN
	| foper fUGT  = fLE
	| foper fUGE  = fLT
	| foper fULT  = fGE
	| foper fULE  = fGT
	| foper fUE   = fLG
	| foper fUN   = fLEG
    in 
      fun opp boxed = unboxed 
	| opp unboxed = boxed
	| opp strneq = streq 
	| opp streq = strneq
	| opp peql = pneq 
	| opp pneq = peql
	| opp (cmp{oper,kind}) = cmp{oper=ioper oper,kind=kind}
	| opp (fcmp{oper,size}) = fcmp{oper=foper oper, size=size}
    end

    val iadd = arith{oper=op +,kind=INT 31}
    val isub = arith{oper=op -,kind=INT 31}
    val imul = arith{oper=op *,kind=INT 31}
    val idiv = arith{oper=op /,kind=INT 31}
    val ineg = arith{oper=op ~,kind=INT 31}

    val fadd = arith{oper=op +,kind=FLOAT 64}
    val fsub = arith{oper=op -,kind=FLOAT 64}
    val fmul = arith{oper=op *,kind=FLOAT 64}
    val fdiv = arith{oper=op /,kind=FLOAT 64}
    val fneg = arith{oper=op ~,kind=FLOAT 64}

    val ieql = cmp{oper=eql,kind=INT 31}
    val ineq = cmp{oper=neq,kind=INT 31}
    val igt = cmp{oper=op >,kind=INT 31}
    val ige = cmp{oper=op >=,kind=INT 31}
    val ile = cmp{oper=op <=,kind=INT 31}
    val ilt = cmp{oper=op <,kind=INT 31}
(*  val iltu = cmp{oper=ltu, kind=INT 31} 
    val igeu = cmp{oper=geu,kind=INT 31}
*)
    val feql =fcmp{oper=fEQ, size=64}
    val fneq =fcmp{oper=fLG, size=64}
    val fgt  =fcmp{oper=fGT, size=64}
    val fge  =fcmp{oper=fGE, size=64}
    val fle  =fcmp{oper=fLE, size=64}
    val flt  =fcmp{oper=fLT, size=64}

    fun arity op ~ = 1
      | arity _ = 2

end (* P *)

type lvar = Access.lvar

datatype value 
  = VAR of lvar
  | LABEL of lvar
  | INT of int
  | INT32 of Word32.word
  | REAL of string
  | STRING of string
  | OBJECT of Unsafe.Object.object
  | VOID

datatype accesspath 
  = OFFp of int 
  | SELp of int * accesspath

datatype fun_kind
  = CONT           (* continuation functions *)
  | KNOWN          (* general known functions *)
  | KNOWN_REC      (* known recursive functions *)
  | KNOWN_CHECK    (* known functions that need a heap limit check *)
  | KNOWN_TAIL     (* tail-recursive kernal *)
  | KNOWN_CONT     (* known continuation functions *)
  | ESCAPE         (* before the closure phase, any user function;
	              after the closure phase, escaping user function *)
  | NO_INLINE_INTO (* before the closure phase,
		      a user function inside of which no in-line expansions
		      should be performed; 
		      does not occur after the closure phase *)

datatype record_kind
  = RK_VECTOR
  | RK_RECORD
  | RK_SPILL
  | RK_ESCAPE
  | RK_EXN
  | RK_CONT
  | RK_FCONT
  | RK_KNOWN
  | RK_BLOCK
  | RK_FBLOCK
  | RK_I32BLOCK

datatype pkind = VPT | RPT of int | FPT of int
datatype cty = INTt | INT32t | PTRt of pkind
             | FUNt | FLTt | CNTt | DSPt

datatype cexp
  = RECORD of record_kind * (value * accesspath) list * lvar * cexp
  | SELECT of int * value * lvar * cty * cexp
  | OFFSET of int * value * lvar * cexp
  | APP of value * value list
  | FIX of function list * cexp
  | SWITCH of value * lvar * cexp list
  | BRANCH of P.branch * value list * lvar * cexp * cexp
  | SETTER of P.setter * value list * cexp
  | LOOKER of P.looker * value list * lvar * cty * cexp
  | ARITH of P.arith * value list * lvar * cty * cexp
  | PURE of P.pure * value list * lvar * cty * cexp
withtype function = fun_kind * lvar * lvar list * cty list * cexp

fun combinepaths(p,OFFp 0) = p
  | combinepaths(p,q) = 
    let val rec comb =
	fn (OFFp 0) => q
	 | (OFFp i) => (case q of
		          (OFFp j) => OFFp(i+j)
		        | (SELp(j,p)) => SELp(i+j,p))
	 | (SELp(i,p)) => SELp(i,comb p)
    in comb p
    end

fun lenp(OFFp _) = 0
  | lenp(SELp(_,p)) = 1 + lenp p

val BOGt = PTRt(VPT)  (* bogus pointer type whose length is unknown *)

local structure LK = LtyKernel
      val tc_real = LK.tc_inj (LK.TC_PRIM (PT.ptc_real))
      val lt_real = LK.lt_inj (LK.LT_TYC tc_real)
in

fun tcflt tc = if LK.tc_eq(tc, tc_real) then true else false
fun ltflt lt = if LK.lt_eq(lt, lt_real) then true else false

fun rtyc (f, ts) =
  let fun loop (a::r, b, len) = 
           if f a then loop(r, b, len+1) else loop(r, false, len+1)
        | loop ([], b, len) = if b then FPT len else RPT len  
   in loop(ts, true, 0)
  end

fun ctyc tc =
  (case LK.tc_out tc
    of LK.TC_PRIM pt =>
         (if pt = PT.ptc_int31 then INTt
          else if pt = PT.ptc_int32 then INT32t
               else if pt = PT.ptc_real then FLTt
                    else BOGt)
     | LK.TC_TUPLE ts => PTRt(rtyc(tcflt, ts))
     | LK.TC_ARROW _ => FUNt
     | LK.TC_CONT _ => CNTt
     | _ => BOGt)

fun ctype lt = 
  (case LK.lt_out lt
    of LK.LT_TYC tc => ctyc tc
     | LK.LT_STR ts => PTRt(rtyc(ltflt, ts))
     | LK.LT_FCT _ => FUNt
     | LK.LT_CNT _ => CNTt
     | LK.LT_PST _ => BOGt
     | _ => bug "unexpected lambda type in ctype")

end (* local ctype *)

end (* top-level local *)
end (* structure CPS *)

(*
 * $Log: cps.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:44  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/06/30 19:37:15  jhr
 *   Removed System structure; added Unsafe structure.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:30  george
 *   Version 109.24
 *
 *)
