(* types.sml
 *
 * COPYRIGHT (c) 2017 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *)

structure Types : TYPES =
struct

local structure A  = Access
      structure EP = EntPath
      structure IP = InvPath
      structure S  = Symbol
      structure ST = Stamps
in

type label = S.symbol

(* equality property indicators for polymorphically bound tyvars *)
type polysign = bool list

datatype eqprop = YES | NO | IND | OBJ | DATA | ABS | UNDEF

datatype litKind = INT | WORD | REAL | CHAR | STRING
(* currently only INT and WORD literal overloading are implemented *)

datatype openTvKind
  = META                          (* metavariables:
                                     depth = infinity for meta-args
                                     depth < infinity for lambda bound *)
  | FLEX of (label * ty) list     (* flex record variables *)

and ovldSource
  = OVAR of S.symbol * SourceMap.region   (* overloaded variable *)
  | OLIT of litKind * IntInf.int * SourceMap.region
     (* overloaded int or word literal *)
  (* in future, may need to add real, char, string literals as sources *)

and tvKind
  = INSTANTIATED of ty (* instantiation of an OPEN *)
  | OPEN of
     {depth: int, eq: bool, kind: openTvKind}
  | UBOUND of (* explicit type variables *)
     {depth: int, eq: bool, name: S.symbol}
  | OVLD of (* overloaded operator type scheme variable,
	     * representing one of a finite set of ground type options *)
     {sources: ovldSource list,   (* name of overloaded variable or literal value *)
      options: ty list} (* potential resolution types *)
  | LBOUND of {depth: int, eq: bool, index: int}
     (* FLINT-style de Bruijn index for notional "lambda"-bound type variables
      * associated with polymorphic bindings (including val bindings and
      * functor parameter bindings). The depth is depth of type lambda bindings,
      * (1-based), and the index is the index within a sequence of
      * type variables bound at a given binding site. LBOUNDs must carry
      * equality type information for signature matching because the OPENs
      * are turned into LBOUNDs before equality type information is matched. *)

and tycpath (* FLINT!!! *)
    = TP_VAR of
        { tdepth: DebIndex.depth,
	  num: int, kind: TKind.tkind }
    | TP_TYC of tycon
    | TP_FCT of tycpath list * tycpath list
    | TP_APP of tycpath * tycpath list
    | TP_SEL of tycpath * int

and tyckind
  = PRIMITIVE		          (* primitive tycons *)
  | DATATYPE of
     {index: int,
      stamps: ST.stamp vector,
      root : EP.entVar option,    (* the root field used by type spec only *)
      freetycs: tycon list,       (* tycs derived from functor params *)
      family : dtypeFamily,
      stripped : bool}            (* true if datatype has matched a simple type spec *)
  | ABSTRACT of tycon
  | FLEXTYC of tycpath            (* instantiated formal type constructor *)
  | FORMAL                        (* used only inside signatures *)
  | TEMP                          (* used only during datatype elaborations *)

and tycon
  = GENtyc of gtrec
  | DEFtyc of
      {stamp : ST.stamp,
       tyfun : tyfun,
       strict: bool list,
       path  : IP.path}
  | PATHtyc of                    (* used only inside signatures *)
      {arity : int,
       entPath : EP.entPath,
       path : IP.path}
  | RECORDtyc of label list
  | RECtyc of int                 (* used only in domain type of dconDesc *)
  | FREEtyc of int                (* used only in domain type of dconDesc *)
  | ERRORtyc                      (* for error recovery, and used as a dummy
                                     tycon in ElabMod.extractSig *)

and ty
  = VARty of tyvar
  | IBOUND of int
  | CONty of tycon * ty list
  | POLYty of {sign: polysign, tyfun: tyfun}
  | WILDCARDty
  | UNDEFty
  | MARKty of ty * SourceMap.region

and tyfun
  = TYFUN of {arity: int, body: ty}

withtype tyvar = tvKind ref

(* datacon description used in dtmember *)
and dconDesc =
    {name: S.symbol,
     rep: A.conrep,
     domain: ty option}

(* member of a family of (potentially) mutually recursive datatypes *)
and dtmember =
    {tycname: S.symbol,
     arity: int,
     eq: eqprop ref,
     lazyp: bool,
     dcons: dconDesc list,
     sign: A.consig}

and dtypeFamily =
  {mkey: ST.stamp,
   members: dtmember vector,
   properties: PropList.holder}

and stubinfo =
    {owner : PersStamps.persstamp,
     lib   : bool}

and gtrec =
    {stamp : ST.stamp,
     arity : int,
     eq    : eqprop ref,
     kind  : tyckind,
     path  : IP.path,
     stub  : stubinfo option}

fun mkTyvar(kind: tvKind) : tyvar = ref kind

fun copyTyvar(tv: tyvar) = ref(!tv)

val infinity = 10000000

datatype datacon (* data constructors *)
  = DATACON of
      {name   : S.symbol,
       typ    : ty,
       rep    : A.conrep,
       lazyp  : bool,    (* LAZY: constructor belongs to lazy datatype? *)
       const  : bool,     (* redundant, could be determined from typ *)
       sign   : A.consig} (* redundant, ditto *)

end (* local *)
end (* structure Types *)
