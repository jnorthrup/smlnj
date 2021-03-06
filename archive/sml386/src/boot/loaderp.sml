(* Copyright 1989 by AT&T Bell Laboratories *)
signature Startup =
 sig 
     val core : System.Unsafe.object
     val initial : System.Unsafe.object
     val math : System.Unsafe.object
     val name : string
 end

functor Loader ( S : Startup ) : sig end =
struct

 open Ref List String IO General System System.Unsafe
 val boot : string ->
	    unit ->
	    ((object list -> (object * ByteArray.bytearray array)) * string list)
	  = System.Unsafe.boot

 val dict : (string*object) list ref = 
	ref [("Initial",S.initial),("Core",S.core),("Math",S.math)]

 val _ = pstruct := {core=S.core,math=S.math,initial=S.initial}

 exception Notfound_Loader

 fun lookup s =
    let fun f ((s1,stru)::r) = if s=s1 then stru else f r
	  | f nil = raise Notfound_Loader
     in f (!dict)
    end

 fun enter pair = dict := pair::(!dict)

 fun readfile s =
	let val stream = open_in s
	    val file = input(stream,(can_input stream))
	in  close_in stream;
	    System.Unsafe.flush_cache file;
	    file
	end

 fun getmo s =
    let fun f (s'::t::x) = if s=s' then t else f x
	  | f _ = readfile s
     in f System.Unsafe.Assembly.datalist
    end

 val say = outputc std_out

 fun getstruct s =
	lookup s handle Notfound_Loader =>
	    let val _ = (say "[Loading "; say s; say "]\n")
		val g = getmo ("mo/" ^ s ^ ".mo");
	        val (exec,sl) = boot g ()
	        val saver = ref exec  (* save a pointer for the garbage
					 collector *)
	        val structs = map getstruct sl
	        val _ = (say "[Executing "; say s; say "]\n")
	        val (str,profile) = exec structs
	    in  enter (s,str);
		System.Control.ProfileInternals.add profile;
	        saver := !saver;    (* trickery for the g.c. *)
		str
	    end

fun c_function s = 
    let exception C_function_not_found of string
        fun f (System.Unsafe.Assembly.FUNC(p,t,rest)) =
		if stringequal(s,t) then p
		else if stringequal(t,"xxxx") then raise (C_function_not_found s)
		else f rest
        val cfun = f System.Unsafe.Assembly.external
     in fn x => System.Unsafe.Assembly.A.callc(cfun,x)
    end

 val setg : 'a -> unit = c_function "setg"

 val counts = array(1000,0)
 val _ = setg counts

 val _ = (getstruct S.name; System.cleanup())
	    (* this is the global exception handler of the sml system *)
	    handle Io s =>
		     (say "uncaught Io exception (Loader): ";
		      say s;
		      say "\n";
		      System.cleanup())
		 | exn =>
		     (say "uncaught exception (Loader): ";
		      say (exn_name exn);
		      say "\n";
		      System.cleanup())

 fun f i = (print (counts sub i); f(i+1))
 val _ = f 0 handle Subscript => ()

end (* functor Loader *)


