(* importer.sml    608567950   46    20    100444  17742     `*)
(* Importer: Isolation of Mads' original code from Interact() into a separate
   functor. Numerous extensions, Make system, etc. etc. (NICK) *)

functor Importer(structure FilePaths: FILEPATHS
		 val fileExtension: string
		 structure ModuleComp: MODULE_COMPILER
		    sharing ModuleComp.Lambda = Lambda
		        and ModuleComp.Absyn = BareAbsyn
		        and type ModuleComp.lvar = Access.lvar
		 val statPrinter: Env.statModule -> string
			(* Make this a fn _ => "" for no effect. *)
		): IMPORTER =
   struct
      val BIN_VERSION = System.version ^ " - LAMBDA v0 " ^ fileExtension^ "\n"
		(* This is stored as the first line of the
		   binary file. Be sure to increment it whenever the structure
		   of any of the stored data objects changes. It cannot
		    contain any \n characters, except at the end where
		    one is required.  *)

      val gcmessages = System.Control.Runtime.gcmessages 
		(* The message "Major collection... abandoned" is
		   annoying me, so I'm hosing it.  *)

      val DEBUG = false
      val debug = 
	if DEBUG then fn str => output std_out ("<" ^ str ^ ">\n")
	else fn _ => ()

      val TRACE_IO = false
      val open_in =
	if TRACE_IO then
	  fn name => (debug("open_in \\" ^ name ^ "\\"); open_in name)
	else
	  open_in

      val open_out =
	if TRACE_IO then
	  fn name => (debug("open_out \\" ^ name ^ "\\"); open_out name)
	else
	  open_out

      type statModule = Env.statModule
      type LambDynModule = ModuleComp.LambDynModule
      type CodeDynModule = ModuleComp.CodeDynModule
      type lvar = Access.lvar

      type BinFormat =
	         {statModule: statModule,
		  dynModule: CodeDynModule,
		  imports: string list
		 }

      val blastRead: instream -> BinFormat =
	System.Unsafe.blast_read
      val blastWrite: (outstream * BinFormat) -> unit =
	System.Unsafe.blast_write

      val blastWrite =			(* Silent version. *)
	fn (stream, obj) =>
	  let
	    val oldmsgs = !gcmessages
	    val _ = (gcmessages := 0)
	  in
	    blastWrite(stream, obj);
	    gcmessages := oldmsgs
	  end

      exception Import of string
			  	(* A single exception for any failure to
				   import (barring compiler bugs). compileModule
				   requires a protective coating so that it
				   doesn't leave the global static environment
				   in a funny state. *)

      datatype ToplevelFns =
         TOPLEVEL_FNS of {bind: lvar * System.Unsafe.object -> unit,
			  lookup: lvar -> System.Unsafe.object,
			  parse: unit -> BareAbsyn.dec,
			  getvars: BareAbsyn.dec -> lvar list,
			  opt: Lambda.lexp -> Lambda.lexp
			 }

      fun spaces n = spaces'(n, "")
      and spaces'(0, result) = print result
	| spaces'(n, result) = spaces'(n-1, result ^ " ")

      (* Feedback messages. If anybody's interested, files which may
         cause failures, or may cause nested reads, are done as:

		[reading fred.sml]
		[closing fred.sml]

	 Ones which shouldn't (eg. reading from a binary) produce:

		[reading fred.bin... done]
       *)

      fun reading(file, indent) =
	(spaces indent; print("[reading " ^ file ^ "]\n"))
      fun reading1(file, indent) =
	(spaces indent; print("[reading " ^ file ^ "... "); flush_out std_out)
      fun writing(file, indent) =
	(spaces indent; print("[writing " ^ file ^ "]\n"))
      fun writing1(file, indent) =
	(spaces indent;	print("[writing " ^ file ^ "... "); flush_out std_out)
      fun closing(file, indent) =
	(spaces indent; print("[closing " ^ file ^ "]\n"))
      fun done() = print "done]\n"

      fun fail(msg, verdict) =
         (print("import: " ^ msg ^ "\n"); raise Import verdict)

     (* impliedPath: derived from FilePaths.impliedPath, but catches
        ImpliedPath if a "~"-filename fails to translate. *)

      fun impliedPath(oldPath, oldName) =
	FilePaths.impliedPath(oldPath, oldName)
	handle FilePaths.ImpliedPath =>
	  fail("couldn't translate path in: " ^ oldName, "open")

      fun all pred list =
	fold (fn (this, res) => pred this andalso res) list true

      fun addAndExecModule(statModule as Env.STATmodule{table, ...},
			   compDynModule,
			   TOPLEVEL_FNS{bind, lookup, ...}):unit =
	  let val newlvars =
		 Env.importModule statModule 
		  (*adds the static bindings of the module to the *)
		  (*static environment*)

	      val Nick_result =
		 ModuleComp.executeDynModule compDynModule lookup
		 handle exn =>	(* Local handle for module execution (NICK). *)
		    fail("execution of module raised exception "
			  ^ System.exn_name exn
			  ^ "\n\t(static bindings of module take no effect)\n",
			 "uncaught exception"
			)

	      fun bindlvars (i,v::r) = (bind(v,Nick_result sub i);
					bindlvars (i+1,r))
		| bindlvars (_,nil) = ()
	   in  
	      bindlvars(0,newlvars);		(* add new runtime bindings *)
	      Env.commit();			(* accept static bindings *)
	      PrintDec.printBindingTbl table
	   end
	   handle	(* Exceptions other than ones raised through
			   module execution. *)
	        Interrupt => raise Interrupt
	      | exn => ErrorMsg.impossible(
		          "addAndExecModule: exn (" ^ System.exn_name exn ^ ")??"
		       )


     (* New code (NICK) - I store the static information (StatModule) and
        dynamic information (CodeDynModule) in one object, so that I can blast
	out the entire thing as a single object into a file. Foo.sml now gets
	compiled into Foo.vax/Foo.m68/..., which contains
	both. The object stored in the file is a pair: the first element is a
	"version number" for the data structures, the second is whatever needs
	storing (currently a record of {statModule, dynModule, imports}).
	If this version number changes, I have to recompile. *)

      fun tryOpenIn filename: instream option =
         SOME(open_in filename) handle Io _ => NONE

      fun createBinary(indent, filename,
	  	       statModule: statModule,
		       codeDynModule: CodeDynModule,
		       imports: string list
		      ): unit =
         let
	    val fullName = filename ^ ".bin"
	    val outstream =
	       (open_out fullName
		handle Io _ => fail("couldn't open " ^ fullName ^ " for output",
				    "open"
				   )
	       )
	    val _ = writing1(fullName, indent)
	    val binary = {statModule=statModule,
			  dynModule=codeDynModule,
			  imports=imports
			 }
	 in
           output outstream BIN_VERSION;
	   blastWrite(outstream, binary);
	   close_out outstream;
	   done()
	 end

      fun createTextual(indent, filename, statModule): unit =
        let
	  val outputText = statPrinter statModule
	in
	  case outputText
	    of "" => ()		(* Do NOTHING if the print function is a dummy *)
	     | _ =>
	         let
		   val fullName = filename ^ ".lstat"
		   val os = open_out fullName
			    handle Io _ =>
			      fail("couldn't open " ^ fullName ^ " for output",
				    "open"
				   )
		   val _ = writing1(fullName, indent)
		 in
		   output os outputText;
		   close_out os;
		   done()
		 end
        end

     (* We must do a syntactic check that the source declarations in a module
        are just functor and signature declarations (or sequences thereof),
	otherwise the renaming routines will fall over later. Importer is the
	place to do it, where we still have a fighting chance of a putting
	out a decent diagnostic message. We don't allow IMPORT - that should
	have been dealt	with earlier. *)

      local
         open BareAbsyn
      in
         fun kosherModuleDecl dec =
	    case dec
	      of FCTdec _ => true
	       | SIGdec _ => true
	       | SEQdec decs =>			(* ALL must be kosher. *)
		   all kosherModuleDecl decs
	       | _ => false
      end

      fun badModuleDecl() =
         ErrorMsg.condemn "expecting SIGNATURE/FUNCTOR/IMPORT"
         
     (* getModule: "parents" is a depth-first list of filenames used for
        a circularity check. "indent" is for cosmetic purposes. *)

      fun getModule(parents, indent, path, name, pervasives, toplevelFns)
	  : statModule*CodeDynModule =
	let
	  val {validName, newPath} = impliedPath(path, name)
	  val _ = debug("getModule(name=" ^ name ^ ")")
	in
	  if all (fn x => x<>validName) parents then
	    getModule'(validName :: parents, indent, newPath, pervasives,
		       {filename=validName,
			smlStream=tryOpenIn(validName ^ ".sml"),
			binStream=tryOpenIn(validName ^ ".bin")
		       },
		       toplevelFns
		      )
	  else				(* self-reference *)
	    fail("self-referential import of " ^ validName, "open")
	end

      and getModule'(parents, indent, path, pervasives,
		     {filename, smlStream, binStream},
		     toplevelFns
		    ): statModule*CodeDynModule =
         case (smlStream, binStream)
	   of (SOME source, NONE) =>		(* Source only: Compile! *)
	         let
		    val _ = debug(filename ^ ": source only")
		    val fullName = filename ^ ".sml"
		    val _ = reading(fullName, indent)
		    val _ = Lex.pushSource(source, fullName)

		    val (statModule, codeDynModule, imports) =
		       compileModule(parents, indent, path,
				     pervasives, toplevelFns
				    )
		       handle exn =>
		          (closing(fullName, indent);
			   close_in source;
			   Lex.popSource();
			   raise exn
			  )
                 in
		   closing(fullName, indent);
		   close_in source;
		   Lex.popSource();
		   createBinary(indent, filename,
				statModule, codeDynModule, imports
			       )
		     handle Import _ => ();
		   createTextual(indent, filename, statModule)
		     handle Import _ => ();
			(* What the hell: make failed writes nonfatal... *)
		   (statModule, codeDynModule)
		 end

	    | (SOME source, SOME binary) =>
                let
		  val srcTime = mtime source
		  val binTime = mtime binary
		  val _ = debug(filename ^ ": src dated " ^ makestring srcTime
				         ^ ", bin dated " ^ makestring binTime
			       )
		in				(* binary out of date? *)
		  if srcTime >= binTime then	(* (">=" for safety) *)
		    (spaces indent;
		     print("[" ^ filename ^ ".bin is out of date;\
			   \ recompiling]\n");
		     close_in binary;
		     getModule'(parents, indent, path, pervasives,
				{filename=filename,
				 smlStream=smlStream, binStream=NONE
				},
				toplevelFns
			       )
		    )
		  else			(* bin is newer: what about the
					   things imported, though? *)
		    let
		      val _ = debug(filename ^ ": checking imports")
		      val fullName = filename ^ ".bin"
		      val _ = reading1(fullName, indent)
		      val binVersion = input_line binary
		    in
		      if (binVersion <> BIN_VERSION) then
			(print "]\n";
			 spaces indent;
			 print("[" ^ fullName ^ " is the wrong format;\
			       \ recompiling]\n"
			      );
			 closing(fullName, indent);
			 close_in binary;
			 getModule'(parents, indent, path, pervasives,
				    {filename=filename,
				     smlStream=smlStream, binStream=NONE
				    },
				    toplevelFns
				   )
			)
		      else
			let val binStuff = blastRead binary
			  val {statModule, dynModule, imports, ...} = binStuff
			  fun allOk imports =
			    all (uptodate (path, binTime)) imports
			    handle exn => (print "]\n";
					   closing(fullName, indent);
					   close_in binary;
					   close_in source;
					   raise exn
					  )
			in
			  if not(allOk imports) then
			    (print "]\n";
			     spaces indent;
			     print("[import(s) of " ^ filename
				   ^ " are out of date; recompiling]\n"
				   );

			     closing(fullName, indent);
			     close_in binary;
			     getModule'(parents, indent, path, pervasives,
					{filename=filename,
					 smlStream=smlStream, binStream=NONE
					},
					toplevelFns
				       )
			    )
			  else		(* All OK: use the binary. *)
			    (debug(filename ^ ": all up to date");
			     close_in source;
			     close_in binary;
			     done();
			     (statModule, dynModule)
			    )
			end
		    end
		end

	    | (NONE, SOME binary) =>
	         let
		   val _ = debug(filename ^ ": binary only")
		   val fullName = filename ^ ".bin"
		   val _ = reading1(fullName, indent)
		   val binVersion = input_line binary
		 in
		    if binVersion = BIN_VERSION then
		       (close_in binary;
			done();
		        case blastRead binary
			  of {statModule, dynModule, ...} =>
			       (statModule, dynModule)
		       )
		    else
		      (print "]\n";	(* Outstanding message... *)
		       spaces indent;
		       print("[" ^ fullName ^ " is the wrong format;\
			     \ recompiling]\n"
			    );
		        closing(fullName, indent);
			close_in binary;
			case tryOpenIn(filename ^ ".sml")
			  of SOME source =>
				getModule'(parents, indent, path, pervasives,
					   {filename=filename,
					    smlStream=SOME source,
					    binStream=NONE
					   },
					   toplevelFns
					  )
			   | NONE =>
				fail(fullName ^ " is out of date, and I can't\
				     \ open " ^ filename ^ ".sml",
				     "open"
				    )
		       )
		 end

	    | (NONE, NONE) =>
		 fail("cannot open " ^ filename ^ ".sml", "open")

     (* uptodate should be memo'd sometime, since it's quite expensive. *)

      and uptodate (path, myBinTime) name =
	let
	  val {newPath, validName} = impliedPath(path, name)
	  val _ = debug("uptodate(quotedName=" ^ name
			^ ", validName=" ^ name ^ ")?"
		       )
	  val trySml = tryOpenIn(validName ^ ".sml")
	  val tryBin = tryOpenIn(validName ^ ".bin")
	in
	  case (trySml, tryBin)
	    of (SOME source, SOME binary) =>
		 let
		   val srcTime = mtime source
		   val binTime = mtime binary
		   val _ = debug("uptodate(" ^ validName ^ "):\
			       \ src time = " ^ makestring srcTime
				 ^ ", bin time = " ^ makestring binTime
				)
		 in
		   if srcTime >= binTime	(* binary out of date *)
		      orelse binTime >= myBinTime then
					(* Some other branch of the Make
					   task compiled this under me...? *)
		     (close_in source; close_in binary; false)
		   else			(* source is older; check imports *)
		     let
		       val _ = close_in source
		       val fullName = validName ^ ".bin"
		       val binVersion = input_line binary
		     in
		       if binVersion <> BIN_VERSION then
			 (close_in binary; false)
				(* can't trust "imports" : chicken out *)
		       else
			 case blastRead binary before close_in binary
			   of {imports, ...} =>
			     all (uptodate (newPath, myBinTime)) imports
		     end
		 end

	     | (SOME source, NONE) =>	(* No bin: force recompile *)
		  (close_in source; false)

	     | (NONE, SOME binary) =>
		  (close_in binary; true) (* No source: trust for now... *)

	     | (NONE, NONE) =>
		  fail("cannot find source or binary\
		     \ of required module " ^ validName,
		       "open"
		      )
	end

      and compileModule(parents, indent, path, pervasives,
	  		toplevelFns as TOPLEVEL_FNS{parse, getvars, opt, ...}
		       ): statModule * CodeDynModule * string list =
        let val frominfo = Basics.currentInfo()

            fun loop(dynModule, lvars, imports)
	        : LambDynModule * lvar list * string list =
	       (case (Lex.toplevel := true; parse())
		  of BareAbsyn.IMPORTdec names => 
                       let
		         fun loop'([], dynMod, lvars, imports) =
			       (dynMod, lvars, imports)
                           | loop'(name::rest, dynMod, lvars, imports)=
                               let
				 val {newPath, ...} =
				   impliedPath(path, name)

				 val (stat, codeDyn) =
				   getModule(parents, indent+2,
					     newPath, name,
					     pervasives, toplevelFns
					    )

                                 val newLvars = Env.importModule stat

				 val lambDyn =
				   ModuleComp.abstractDynModule(
				     codeDyn, newLvars
				   )

                                 val dynMod' =
                                   ModuleComp.importDynModule(lambDyn, dynMod)
                               in
                                 loop'(rest, dynMod',
				       lvars @ newLvars,
				       name :: imports
				      )
                               end
                       in
			 loop(loop'(names, dynModule, lvars, imports))
		       end

                   | absyn => (* normal program *)
		        if kosherModuleDecl absyn then
			  let
			    val newLvars = getvars absyn
			    val newMod =
			      ModuleComp.addDeclaration(
				absyn, newLvars, dynModule
			      )
			      handle ModuleComp.AddDeclaration =>
			        fail("error during translate", "translate")
			  in
			    loop(newMod, lvars @ newLvars, imports)
			  end
                        else
		           badModuleDecl()
		) handle Parse.Eof => (dynModule, lvars, imports)
		       | Import x  => raise Import x
					(* Resignal nested Import probs. *)
		       | Io x =>
			   raise Import("unexpected: Io(" ^ x ^ ")")
                       | exn =>
			   raise Import("compile-time exception: "
					^ System.exn_name exn
				       )

	    val savedEnv = Env.current()
	    val _ = Env.resetEnv pervasives

            val (lambDynModule, lvars, imports) =
	       loop(ModuleComp.emptyDynModule, [], [])
	       handle exn => (Env.resetEnv savedEnv; raise exn)

            val toinfo = Basics.currentInfo()

            val statModule=
	       Env.STATmodule{table=Env.popModule(pervasives,savedEnv),
		              from=frominfo, to=toinfo,
                              lvars=lvars
			     }

	    val dynModule =
	       ModuleComp.compileDynModule opt lambDynModule
	       handle ModuleComp.CompileDynModule =>
		 fail("code generation failed", "codegen")
         in
            (statModule, dynModule, imports)
         end

      fun getAndExecModule(filename, pervasives, toplevelFns): unit = 
         let
	   val (stat, dyn) =
	     getModule([], 0, FilePaths.defaultPath, filename,
		       pervasives, toplevelFns
		      )
	 in
	    addAndExecModule(stat, dyn, toplevelFns)
	 end
   end;
