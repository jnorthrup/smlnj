(* envref.sml
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 *)

signature ENVREF = 
sig
  type staticEnv = StaticEnv.staticEnv
  type SCstaticEnv = SCStaticEnv.staticEnv
  type environment = Environment.environment
  type SCenvironment = SCEnv.Env.environment

  type senvref = {get: unit -> staticEnv, set: staticEnv -> unit}
  type envref = {get: unit -> environment, set: environment -> unit}
  type SCenvref = {get: unit -> SCenvironment, set: SCenvironment -> unit}

  val core: senvref
  val topLevel : envref (* interactive top level env *)
  val pervasive : SCenvref (* pervasive environment *)
  val unSC : SCenvref -> envref
  val unSCenv : SCenvironment -> environment
  val unSCstaticEnv : SCstaticEnv -> staticEnv
  val combined : unit -> environment
end

structure EnvRef : ENVREF =
struct
  type staticEnv = StaticEnv.staticEnv
  type SCstaticEnv = SCEnv.Env.staticEnv
  type environment = Environment.environment
  type SCenvironment = SCEnv.Env.environment
  type envref = {get: unit -> environment, set: environment -> unit}
  type SCenvref = {get: unit -> SCenvironment, set: SCenvironment -> unit}
  type senvref = {get: unit->StaticEnv.staticEnv, set: StaticEnv.staticEnv->unit}

  fun mkEnvRef a = 
    let val r = ref a
     in {get=(fn()=> !r),set=(fn x=> r:=x)}
    end

  val core = mkEnvRef StaticEnv.empty 
  val topLevel = mkEnvRef Environment.emptyEnv
  val pervasive = mkEnvRef SCEnv.Env.emptyEnv

  (* set disabled, since it is not expected to be used *)
  fun unSC ({get,set}: SCenvref) : envref = 
      {get = SCEnv.unSC o get,
       set = (fn _ => raise Fail "EnvRef.unSC") (* set o SCEnv.SC *)}

  val unSCenv : SCenvironment -> environment = SCEnv.unSC
  val unSCstaticEnv : SCstaticEnv -> staticEnv = SCStaticEnv.unSC

  fun combined () = 
      Environment.layerEnv(#get topLevel (), SCEnv.unSC(#get pervasive ()))

end



(*
 * $Log: envref.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:43  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/08/02 02:10:16  dbm
 *   New top level using Environment.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:28  george
 *   Version 109.24
 *
 *)
