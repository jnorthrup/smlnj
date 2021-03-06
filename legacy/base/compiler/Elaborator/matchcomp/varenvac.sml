(* varenvac.sml *)

(* environments mapping vars to vars. 
 * Used for repacement of source variables by svars (administrative
 * match compiler variables) in right-hand-sides of matches.
 *)

structure VarEnvAC =
struct

local
  structure A = Access
  structure LV = LambdaVar
  structure M = LV.Map
  structure V = VarCon
  open MCTypes
in

(* varenvAC is an alist with key V.var *)
type varenvAC = (V.var * V.var) list

val empty : varenvAC = nil

(* bind : V.var * V.var * varenvAC -> varenvAC *)
fun bind (var, svar, venv: varenvAC) = (var,svar) :: venv

(* look : varenvAC * V.var -> V.var option *)
fun look (varenvAC, var) =
    (case var
      of V.VALvar{access = A.LVAR lvar, ...} =>
	 let val lvar = V.varToLvar var
	     fun loop nil = NONE
	       | loop ((var0,svar0)::rest) = 
		 if LV.same (V.varToLvar var0, lvar) then SOME svar0
		 else loop rest
	 in loop varenvAC
	 end
       | _ => NONE)

(* append : varenvAC * varenvAC -> varenvAC *)
(* "domains" of the two environments will be disjoint *)
fun append (venv1: varenvAC, venv2: varenvAC) = venv1 @ venv2

(* range : varenvAC -> V.var list *)
fun range (venv: varenvAC) = map #2 venv

end (* local *)
end (* structure VarEnvAC *)
