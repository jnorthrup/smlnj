(* prof-env.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature PROF_ENV =
  sig
    val prof: TellEnv.env -> string 
    val replace: {
	    get: unit -> SCEnv.Env.environment,
	    set: SCEnv.Env.environment -> unit
	  } -> unit
  end

functor ProfEnv (Interact: INTERACT) : PROF_ENV =
struct

  structure T = TellEnv

  fun prof (e0 : T.env) =
   let val accum = ref (nil: string list)
       fun say x = accum := x :: !accum
       val indentlev = ref 0
       val spaces = "                                            "
       fun nl () = (
	      say "\n";
	      say(substring(spaces,0,Int.min(size spaces, !indentlev))))

       fun indent f x = (indentlev := !indentlev + 1;
			 f x;
			 indentlev := !indentlev - 1)
		   
  
       fun any_in_env e = List.exists any_in_binding (T.components e)
       and any_in_binding(_,b) =
            case (T.strBind b, T.valBind b)
             of (SOME str, _) => any_in_env str
              | (_, SOME v) => any_in_ty v
	      | _ => false
       and any_in_ty ty = case T.funTy ty of SOME _ => true | NONE => false

       fun pr_env (e: T.env) = app pr_binding (T.components e)

       and pr_binding(sym: T.symbol, b: T.binding) =
           case (T.strBind b, T.valBind b)
            of (SOME str, _) => pr_str(sym,str)
             | (_, SOME v) => pr_val(sym,v)
             | _ => ()

       and pr_str(sym: T.symbol, e: T.env) =
         if any_in_env e 
	  then 
           (say "structure "; say (T.name sym); 
	    say " ="; nl(); say "struct open "; say (T.name sym);
            indent (fn () => (nl(); pr_env e)) ();
	    say "end;"; nl())
          else ()

       and pr_val(sym: T.symbol, ty: T.ty) =
        let fun curried(funid,argid,ty) =
             case T.funTy ty
              of NONE => (say "op "; say funid; say " "; say argid)
               | SOME(_,ty') => (say "let val op f = op "; say funid;
				 say " "; say argid; 
				 indent (fn()=> (nl(); say "in fn x => ";
						 curried("f","x",ty');
						 nl(); say "end")) ())
         in case T.funTy ty
            of SOME(_,ty') => (say "val op "; say (T.name sym); say " = fn x => ";
			       curried(T.name sym,"x",ty'); nl())
             | _ => ()
        end

    in pr_env e0;
       concat(rev (!accum))
   end

  fun replace {get,set} = 
   let val e0 = get ()
       val s = prof (SCEnv.Env.staticPart e0)
       val e1 = Interact.evalStream(TextIO.openString s, e0)
    in set (SCEnv.Env.concatEnv(e1,e0))
   end


end;

(*
 * $Log: prof-env.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:47  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:44  george
 *   Version 109.24
 *
 *)
