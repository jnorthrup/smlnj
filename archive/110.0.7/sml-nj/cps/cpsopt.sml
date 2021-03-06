(* Copyright 1989 by AT&T Bell Laboratories 
 *
 *)
(* cpsopt.sml *)

functor CPSopt(MachSpec: MACH_SPEC) : CPSOPT = struct
 
structure CG = Control.CG
structure Eta = Eta
structure Contract = Contract(MachSpec)
structure Expand = Expand(MachSpec)
structure EtaSplit = EtaSplit(MachSpec)
structure Flatten = Flatten(MachSpec)
structure Uncurry = Uncurry(MachSpec)

fun reduce (function, table, _, afterClosure) = 
(* NOTE: The third argument to reduce is currently ignored.
   It used to be used for reopening closures. *)
let

val debug = !CG.debugcps (* false *)
fun debugprint s = if debug then Control.Print.say(s) else ()
fun debugflush() = if debug then Control.Print.flush() else ()
val clicked = ref 0
fun click (s:string) = (debugprint s; clicked := !clicked+1)

val cpssize = ref 0

fun contract last f = 
  let val f' = (clicked := 0;
		Contract.contract{function=f,table=table,click=click,
				  last=last,size=cpssize})
  in  app debugprint ["Contract stats: CPS Size = ", Int.toString (!cpssize),
		      " , clicks = ", Int.toString (!clicked), "\n"];
      f'
  end

(* dropargs are turned off in first_contract to ban unsafe eta reduction *)
fun first_contract f =  
  let val dpargs = !CG.dropargs
      val f' = (clicked := 0; CG.dropargs := false;
		Contract.contract{function=f,table=table,click=click,
				  last=false,size=cpssize})
  in  app debugprint ["Contract stats: CPS Size = ", Int.toString (!cpssize),
		      " , clicks = ", Int.toString (!clicked), "\n"];
      CG.dropargs := dpargs;
      f'
  end

(* in the last contract phase, certain contractions are prohibited *)
fun last_contract f = 
  let val f' = (clicked := 0;
		Contract.contract{function=f,table=table,click=click,
				  last=true,size=cpssize})
  in  app debugprint ["Contract stats: CPS Size = ", Int.toString (!cpssize),
		      " , clicks = ", Int.toString (!clicked), "\n"];
      f'
  end

fun expand(f,n,unroll) =
  (clicked := 0;
   if not(!CG.betaexpand) then f else
   let val f' = Expand.expand{function=f,click=click,bodysize=n,
			      afterClosure=afterClosure,table=table,
			      unroll=unroll,do_headers=true}
   in  app debugprint["Expand stats: clicks = ", Int.toString (!clicked), "\n"];
       f'
   end)

fun flatten f =
  (clicked := 0;
   if not(!CG.flattenargs) then f else
   let val f' = Flatten.flatten{function=f,table=table,click=click}
   in  app debugprint["Flatten stats: clicks = ", Int.toString (!clicked), "\n"];
       f'
   end)

fun unroll_contract(f,n) =
  let val f' = expand(f,n,true)
      val c = !clicked
  in  if c>0 then (c,contract true f')
      else (c,f')
  end

fun expand_flatten_contract(f,n) =
  let val f1 = expand(f,n,false)
      val c1 = !clicked
      val f2 = flatten f1
      val c2 = !clicked
      val c = c1+c2
  in  if c>0 then (c,contract false f2)
      else (c,f2)
  end

fun eta f =
  (clicked := 0;
   if not(!CG.eta) then f else
   let val f' = Eta.eta{function=f,click=click}
   in  app debugprint["Eta stats: clicks = ", Int.toString (!clicked), "\n"];
       f'
   end)

fun uncurry f = if afterClosure then f else 
  (clicked := 0;
   if not(!CG.uncurry) then f else
   let val f' = Uncurry.etasplit{function=f,table=table,click=click}
   in  app debugprint["Uncurry stats: clicks = ", Int.toString (!clicked), "\n"];
       f'
   end)

fun etasplit f =
  (clicked := 0;
   if not(!CG.etasplit) then f else
   let val f' = EtaSplit.etasplit{function=f,table=table,click=click}
   in  app debugprint["Etasplit stats: clicks = ",
		      Int.toString (!clicked), "\n"];
       f'
   end)


fun lambdaprop x = x
       (* if !CG.lambdaprop then (debugprint "\nLambdaprop:"; CfUse.hoist x)
       	                    else x *) 

val bodysize = !CG.bodysize
val rounds = !CG.rounds
val reducemore = !CG.reducemore

(* 
 * Note the parameter k starts at rounds..0 
 *)
fun linear_decrease k = (bodysize * k) div rounds
(*** NOT USED ***
fun double_linear k = (bodysize*2*k div rounds) - bodysize
fun cosine_decrease k = 
       Real.trunc(real bodysize * (Math.cos(1.5708*(1.0 - real k / real rounds))))
***)


(* This function is just hacked up and should be tuned someday *)
fun cycle(0,true,func) = func
  | cycle(0,false,func) = unroll func
  | cycle(k,unrolled,func) = 
       let val func = lambdaprop func
           val (c,func) =
	       if !CG.betaexpand orelse !CG.flattenargs
		   then expand_flatten_contract(func,linear_decrease k)
	       else (0,func)
       in  if c * 1000 <= !cpssize * reducemore
	   then if unrolled then func
                            else unroll func
	   else cycle(k-1, unrolled, func)
       end

and unroll func =
       let val (c,func') = unroll_contract(func,bodysize)
       in  if c>0 then cycle(rounds,true,func')
	   else func'
       end

in  (if rounds < 0 then (function,table)
     else (let val function1 = first_contract function
               val function2 = eta function1
               val function3 = uncurry function2
               val function4 = etasplit function3
               val function5 = cycle(rounds, not(!CG.unroll), function4)
               val function6 = eta function5 (* ZSH added this new phase *)
               val function7 = last_contract function6
            in (function7, table)
           end))
    before (debugprint "\n"; debugflush())

end (* fun reduce *)

end (* functor CPSopt *)

(*
 * $Log: cpsopt.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:44  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/08/22 18:34:56  george
 *   Add a new eta reduction phase in the end of the cps optimization. -- zsh
 *
 * Revision 1.1.1.1  1997/01/14  01:38:30  george
 *   Version 109.24
 *
 *)
