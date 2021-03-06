functor MDPP(AstUtil : MD_AST_UTIL) : MD_PP =
struct

   structure Ast = AstUtil.Ast

   open PP Ast MDError
   infix ++

   fun error msg = MDError.error("error while processing "^msg)

   val comma = !! ", "
   val semi = !! "; "
   val cons = !! "::"
   val list = seq(!! "[",comma,!! "]")
   val tuple = seq(!! "(",comma,!! ")")
   val record = seq(!! "{",comma,!! "}")
   val bars = seq(settab,nl' 45 ++ tab' ~2 ++ ! "|" ++ tab,unindent)
   val ands = seq(settab,tab' ~4 ++ ! "and" ++ tab,unindent)

   fun isAlpha "" = true
     | isAlpha s  = Char.isAlpha(String.sub(s,0))

   fun isMLSym #"'" = false
     | isMLSym #"_" = false
     | isMLSym #"." = false
     | isMLSym c    = Char.isPunct c

   fun isComplex s = 
   let fun loop(~1, alpha, sym) = alpha andalso sym
         | loop(i, alpha, sym) =
           let val c = String.sub(s,i)
           in  loop(i-1, alpha orelse Char.isAlphaNum c,
                         sym   orelse isMLSym c)
           end
   in  loop(String.size s - 1, false, false) end
             

   fun encodeChar c = if isMLSym c then "_"^Int.toString(Char.ord c)
                      else Char.toString c

   fun encodeName s = String.translate encodeChar s

   fun name id = if isComplex id then encodeName id else id

   fun ident(IDENT([],id)) = if isSym id then !"op" ++ ! id 
                             else if isAlpha id then !(name id)
                             else sp ++ !id
     | ident(IDENT(p,id)) = seq(nop,!! ".",nop) (rev (map ! (name id::p)))

   and exp(WORDexp w) = word w
     | exp(INTexp i) = int i
     | exp(STRINGexp s) = string s
     | exp(CHARexp c) = char c
     | exp(BOOLexp b) = bool b
     | exp(IDexp id) = ident id
     | exp(CONSexp(id,e)) = ident id ++ sp ++ exp' e
     | exp(LISTexp(es,NONE)) = if length es >= 10 then longlistexp es 
                               else list (map appexp es)
     | exp(LISTexp([],SOME e)) = exp e
     | exp(LISTexp(es,SOME e)) = seq(nop,cons,cons) (map exp es) ++ exp e
     | exp(TUPLEexp [e]) = exp e
     | exp(TUPLEexp es) = tuple (map appexp es)
     | exp(RECORDexp es) = record(map labexp es)
     | exp(SEQexp []) = ! "()"
     | exp(SEQexp [e]) = exp e
     | exp(SEQexp es) = nl ++ tab ++ seq(! "(",semi++nl++tab,! ")") 
                          (map appexp es)
     | exp(APPexp(e as IDexp(IDENT([],f)),e' as TUPLEexp[x,y])) = 
         if isSym f then
            paren(exp x ++ sp ++ ! f ++ sp ++ exp y)
         else
            paren(exp e ++ !! " " ++ exp e')
     | exp(APPexp(f,x)) = paren(appexp f ++ !! " " ++ exp x)
     | exp(IFexp(x,y,z)) = paren(line(! "if" ++ sp ++ exp x) ++ 
                           block(line(! "then" ++ sp ++ exp y) ++
                                 tab ++ ! "else" ++ sp ++ exp z))
     | exp(RAISEexp e) = ! "raise" ++ exp e
     | exp(HANDLEexp(e,c)) = exp e ++ ! "handle" ++ sp ++ clauses c
     | exp(CASEexp(e,c)) = nl ++ tab ++ group ("(",")")
          (nl ++ tab ++ ! "case" ++ sp ++ appexp e ++ sp ++ ! "of" ++ nl ++ tab
          ++ block(clauses c))
     | exp(LAMBDAexp c) = group ("(",")") (! "fn" ++ sp ++ clauses c)
     | exp(LETexp(d,e)) = line(! "let") ++ block(decls d) ++
                          line(! "in" ++ sp ++ expseq e) ++ line(! "end")
     | exp(TYPEDexp(e,t)) = paren(exp e ++ sp ++ !!":" ++ sp ++ ty t)
     | exp(MARKexp(_,e)) = exp e
     | exp(LOCexp(id,e,region)) = locexp(id,e,region)
     | exp(BITSLICEexp(e,slices)) = 
         select(fn "code" => exp(AstUtil.BITSLICE(e,slices))
                 | "pretty"   => exp e ++ sp ++ ! "at"  ++
                     list(map (fn (i,j) => int i ++ !! ".." ++ int j) slices)
                 | mode => (error mode; nop)
               )
     | exp(TYPEexp t) = ty t
     | exp(ASMexp a) = (error "PP.ASMexp"; nop)
     | exp(RTLexp r) =
         select(fn "pretty" => rtl r
                 | mode => (error mode; nop)
               )

   and rtl r = seq(!"[[",sp,!"]]") (map rtlterm r)

   and rtlterm(LITrtl s) = string s
     | rtlterm(IDrtl x)  = ! x
 
   and longlistexp es =
         select(fn "pretty" => prettylonglistexp es
                 | "code" => codelonglistexp es)

   and prettylonglistexp es =
          nl ++ tab ++ seq(! "[",comma++nl++tab,! "]") (map appexp es)
   and codelonglistexp es =
          nl ++
          line(!"let infix $$ fun x $$ y = y::x") ++
          line(!"in  nil") ++
          block(concat(map (fn e => line(!"$$" ++ appexp e)) (rev es))) ++
          line(!"end")
       
   and appexp(APPexp(e as IDexp(IDENT([],f)),e' as TUPLEexp[x,y])) = 
         if isSym f then exp x ++ sp ++ ! f ++ sp ++ exp y
         else exp e ++ !! " " ++ exp e'
     | appexp(APPexp(f,x)) = (appexp f ++ !! " " ++ exp x)
     | appexp(SEQexp[e])   = appexp e
     | appexp(TUPLEexp[e]) = appexp e
     | appexp e = exp e

   and exp' NONE = nop
     | exp'(SOME e) = exp e

   and isSym "+" = true
     | isSym "-" = true
     | isSym "*" = true
     | isSym "mod" = true
     | isSym "div" = true
     | isSym "=" = true
     | isSym "<>" = true
     | isSym "<" = true
     | isSym ">" = true
     | isSym ">=" = true
     | isSym "<=" = true
     | isSym "<<" = true
     | isSym ">>" = true
     | isSym "~>>" = true
     | isSym "||" = true
     | isSym "&&" = true
     | isSym "^" = true
     | isSym ":=" = true
     | isSym "::" = true
     | isSym "@" = true
     | isSym "andalso" = true
     | isSym "orelse" = true
     | isSym _ = false

   and locexp(id,e,region) = 
          select(fn "pretty" => 
                  !!"$" ++ ! id ++ !!"[" ++ exp e ++ 
                    (case region of
                      SOME r => ! ":" ++ ! r
                    | NONE => nop
                    ) ++
                  !!"]"
                  | "code" => paren(exp e ++ ! "+" ++ !("offset"^id))
                  | mode => (error mode; nop)
                )

   and decl(DATATYPEdecl(dbs,tbs)) = datatypedecl(dbs,tbs)
     | decl(FUNdecl(fbs)) = fundecl fbs
     | decl(RTLdecl(p,e,_)) = 
	   line(! "rtl " ++ pat p ++ ! "=" ++ exp e)
     | decl(VALdecl(vbs)) = valdecl vbs
     | decl(VALSIGdecl(ids,ty)) = valsig("val",ids,ty)
     | decl(RTLSIGdecl(ids,ty)) = valsig("rtl",ids,ty)
     | decl(TYPESIGdecl(id,tvs)) = typesig(id,tvs)
     | decl(LOCALdecl(d1,d2)) = 
           line(! "local") ++ block(decls d1) ++ line(! "in") ++
           block(decls d2) ++ line(! "end")
     | decl(SEQdecl ds) = decls ds
     | decl($ ds) = concat(map line (map !! ds))
     | decl(STRUCTUREdecl(id,[],se)) = 
           line(! "structure" ++ ! id ++ ! "=" ++ sexp se)
     | decl(STRUCTURESIGdecl(id,se)) = 
           line(! "structure" ++ ! id ++ ! ":" ++ sigexp se)
     | decl(STRUCTUREdecl(id,ds,se)) = 
           line(! "functor" ++ ! id ++ paren(decls ds) ++ ! "=" ++ sexp se)
     | decl(OPENdecl ids) = 
           line(! "open" ++ seq(nop,sp,nop)(map ident ids))
     | decl(MARKdecl(l,d)) = 
        nl++ !(SourceMap.directive l) ++nl ++ decl d 
     | decl(INFIXdecl(i,ids)) = line(! "infix" ++ int i ++ concat(map ! ids))
     | decl(INFIXRdecl(i,ids)) = line(! "infixr" ++ int i ++ concat(map ! ids))
     | decl(NONFIXdecl ids) = line(! "nonfix" ++ concat(map ! ids))
     | decl _ = nop

   and sigexp(IDsig id) = ident id
     | sigexp(WHEREsig(se,x,s)) = 
	sigexp se ++ !"where" ++ ident x ++ !! "=" ++ sexp s
     | sigexp(WHERETYPEsig(se,x,t)) = 
	sigexp se ++ !"where type" ++ ident x ++ !! "=" ++ ty t

   and sexp (IDsexp id) = ident id
     | sexp (APPsexp(a,DECLsexp ds)) = ident a ++ nl ++ 
                             block(line(group("(",")") (decls ds)))
     | sexp (APPsexp(a,IDsexp id)) = ident a ++ paren(ident id)
     | sexp (APPsexp(a,b)) = ident a ++ nl ++ paren(sexp b)
     | sexp (DECLsexp ds) = line(!"struct") ++ block(decls ds) ++ line(!"end")

   and decls ds = concat (map decl ds)

   and valsig (keyword,[],t) = nop
     | valsig (keyword,id::ids,t) = 
          line(! keyword ++ ! id ++ ! ":" ++ sp ++ ty t) ++ 
          valsig(keyword,ids,t)

   and typesig (id,tvs) = line(! "type" ++ tyvars tvs ++ ! id) 

   and expseq es = block(seq(nop,semi++nl++tab,nop) (map appexp es))

   and labexp(id,e) = ! id ++ !! "=" ++ appexp e

   and ty(IDty id) = ident id
     | ty(TYVARty tv) = tyvar tv
     | ty(APPty(id,[t])) = ty t ++ ident id
     | ty(APPty(id,tys)) = tuple(map ty tys) ++ sp ++ ident id
     | ty(FUNty(x,y)) = ty x ++ !! " -> " ++ pty y
     | ty(TUPLEty []) = ! "unit"
     | ty(TUPLEty [t]) = ty t
     | ty(TUPLEty tys) = seq(!! "(",!! " * ",!! ")") (map pty tys)
     | ty(RECORDty labtys) = record(map labty labtys)
     | ty(CELLty id) = 
           select( fn "pretty" => !!"$" ++ !id 
                    | "code" => ! "int"
                    | mode => (error mode; nop)
                 )
     | ty(VARty(TYPEkind,i,_,ref NONE)) = !("'X"^Int.toString i)
     | ty(VARty(INTkind,i,_,ref NONE)) = 
           select (fn "pretty" => !("#X"^Int.toString i)
                    | "code"   => !("T"^Int.toString i))
     | ty(VARty(_,_,_,ref(SOME t))) = ty t
     | ty(POLYty(vars,t)) = ty t
     | ty(INTVARty i) = select (fn "pretty" => !!"#" ++ int i
                                 | "code" => int i) 
     | ty(LAMBDAty(vars,t)) = !!"\\" ++ tuple(map ty vars) ++ !!"." ++ ty t 

   and pty(t as FUNty _) = paren(ty t)
     | pty(t as TUPLEty _) = paren(ty t)
     | pty t = ty t

   and labty (id,t) = ! id ++ !! ":" ++ ty t ++ nl' 70

   and pat(IDpat id)   = if isSym id then !"op" ++ !id else !(name id)
     | pat(WILDpat)    = ! "_"
     | pat(ASpat(id,p)) = !id ++ !"as" ++ sp ++ pat p
     | pat(INTpat i)   = int i
     | pat(WORDpat w)  = word w
     | pat(STRINGpat s)= string s
     | pat(BOOLpat b)  = bool b
     | pat(CHARpat c) = char c
     | pat(LISTpat(ps,NONE)) = list(map pat ps)
     | pat(LISTpat([],SOME p)) = pat p 
     | pat(LISTpat(ps,SOME p)) = seq(nop,cons,cons) (map pat ps) ++ pat p
     | pat(TUPLEpat [p]) = pat p
     | pat(TUPLEpat ps) = tuple(map pat ps)
     | pat(RECORDpat(lps,flex)) = 
           record(map labpat lps @ (if flex then [! "..."] else []))
     | pat(CONSpat(id,NONE)) = ident id 
     | pat(ORpat [p]) = pat p
     | pat(ORpat ps) = 
          if length ps > 10 
          then nl ++ tab ++ seq(! "(",! "|"++nl++tab,! ")") (map pat ps)
          else seq(!! "(", ! "|", !! ")") (map pat ps)
     | pat(CONSpat(id,SOME p)) = ident id ++ ppat p

   and ppat(p as CONSpat _) = paren(pat p)
     | ppat p = pat p

   and pats ps = concat(map pat ps)

   and ppats ps = concat(map (fn p => ppat p ++ sp) ps)

   and labpat(id,p as IDpat id') = 
         if id = id' then  ! id
         else ! id ++ !! "=" ++ pat p
     | labpat(id,p) = ! id ++ !! "=" ++ pat p

   and funbind(FUNbind(id,c)) = bars (map (funclause id) c)

   and funclause id (CLAUSE(ps,e)) = 
        line(!(name id) ++ sp ++ ppats ps ++ sp ++ ! "=" 
             ++ sp ++ appexp e)

   and clause (CLAUSE([p],e)) = 
        line(settab ++ pat p ++ sp ++ ! "=>" ++ sp ++ appexp e ++ unindent)
     | clause (CLAUSE(ps,e)) = 
        line(settab ++ ppats ps ++ sp ++ ! "=>" ++ sp ++ appexp e ++ unindent)

   and clauses c = block(bars (map clause c))

   and fundecl [] = nop
     | fundecl fbs = (* nl ++ *) tab ++ ! "fun" ++ sp ++ settab ++ 
                     ands (map funbind fbs) ++ unindent

   and valbind (VALbind(p,e)) = 
         line(settab ++ pat p ++ sp ++ ! "=" ++ sp ++ appexp e ++ unindent)

   and valdecl [] = nop
     | valdecl vbs = tab ++ ! "val" ++ sp ++ block(ands (map valbind vbs))
 
   and datatypebind(DATATYPEbind{id,tyvars=ts,cbs,...}) =
       line(tyvars ts ++ ! id ++ ! "=") ++ 
       tab' ~6 ++ bars (map consbind cbs)

   and consbind(CONSbind{id,ty=NONE,...}) = line(! id)
     | consbind(CONSbind{id,ty=SOME t,...}) = line(! id ++ ! "of" ++ sp ++ ty t)

   and typebind(TYPEbind(id,ts,t)) =
       line (tyvars ts ++ !id ++ ! "=" ++ sp ++ ty t)

   and tyvars []  = nop
     | tyvars [t] = tyvar t
     | tyvars tvs = tuple(map tyvar tvs)

   and tyvar (VARtv tv) = ! tv
     | tyvar (INTtv tv) = sp ++ !! "#" ++ ! tv

   and range(x,y) = paren(int x ++ comma ++ int y)

   and datatypedecl([],t) = tab ++ ! "type" ++ block(ands (map typebind t))
     | datatypedecl(d,t) =
       tab ++ ! "datatype" ++
       block(ands(map datatypebind d)) ++
       (case t of
           [] => nop
        |  _  => tab ++ ! "withtype" ++ block(ands (map typebind t))
       )

end
