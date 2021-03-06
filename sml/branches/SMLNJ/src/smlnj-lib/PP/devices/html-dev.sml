(* html-device.sml
 *
 * COPYRIGHT (c) 1997 Bell Labs, Lucent Technologies.
 *
 * A pretty printing device that uses HTML markup to control layout.
 *)

structure HTMLDev : sig

    include PP_DEVICE

  (* combine two styles into one *)
    val combineStyle : (style * style) -> style

  (* unstyled text *)
    val styleNONE : style

  (* standard HTML text styles *)
    val styleTT : style
    val styleI : style
    val styleB : style
    val styleU : style
    val styleSTRIKE : style
    val styleEM : style
    val styleSTRONG : style
    val styleDFN : style
    val styleCODE : style
    val styleSAMP : style
    val styleKBD : style
    val styleVAR : style
    val styleCITE : style

  (* color text (using FONT element) *)
    val color : string -> style

  (* hyper-text links and anchors *)
    val link : string -> style
    val anchor : string -> style

    val openDev : {wid : int, textWid : int option} -> device
    val done : device -> HTML.text

  end = struct

    datatype style
      = NOEMPH
      | TT | I | B | U | STRIKE | EM
      | STRONG | DFN | CODE | SAMP | KBD
      | VAR | CITE
      | COLOR of string
      | LINK of string
      | ANCHOR of string
      | STYS of style list

    datatype device = DEV of {
	lineWid : int,
	textWid : int option,
	emphStk	: (HTML.text list * style) list ref,
	txt : HTML.text list ref
      }

  (* return the current emphasis *)
    fun curEmph (DEV{emphStk, ...}) = (case !emphStk
	   of [] => NOEMPH
	    | ((_, em)::r) => em
	  (* end case *))

  (* add PCDATA to the text list *)
    fun pcdata (DEV{txt, ...}, s) = txt := HTML.PCDATA s :: !txt

  (* replace the sequence of PCDATA elements at the head of the
   * txt list with its concatenation.
   *)
    fun concatTxt (DEV{txt, ...}) = let
	  fun f ([], []) = []
	    | f (HTML.PCDATA s :: r, l) = f (r, s::l)
	    | f (r, l) = HTML.PCDATA(String.concat l) :: r
	  in
	    f (!txt, [])
	  end

  (* are two styles the same? *)
    fun sameStyle (s1 : style, s2) = (s1 = s2)

    fun wrapStyle (sty, [], tl') = tl'
      | wrapStyle (sty, tl, tl') = let
	  fun wrap (NOEMPH, t) = t
	    | wrap (TT, t) = HTML.TT t
	    | wrap (I, t) = HTML.I t
	    | wrap (B, t) = HTML.B t
	    | wrap (U, t) = HTML.U t
	    | wrap (STRIKE, t) = HTML.STRIKE t
	    | wrap (EM, t) = HTML.EM t
	    | wrap (STRONG, t) = HTML.STRONG t
	    | wrap (DFN, t) = HTML.DFN t
	    | wrap (CODE, t) = HTML.CODE t
	    | wrap (SAMP, t) = HTML.SAMP t
	    | wrap (KBD, t) = HTML.KBD t
	    | wrap (VAR, t) = HTML.VAR t
	    | wrap (CITE, t) = HTML.CITE t
	    | wrap (COLOR c, t) = HTML.FONT{color=SOME c, size=NONE, content=t}
	    | wrap (LINK s, t) = HTML.A{
		  name = NONE, href = SOME s,
		  rel = NONE, rev = NONE, title = NONE,
		  content = t
		}
	    | wrap (ANCHOR s, t) = HTML.A{
		  name = SOME s, href = NONE,
		  rel = NONE, rev = NONE, title = NONE,
		  content = t
		}
	    | wrap (STYS l, t) = List.foldr wrap t l
	  val t = (case tl of [t] => t | _ => HTML.TextList(List.rev tl))
	  in
	    wrap(sty, t) :: tl'
	  end

  (* push/pop a style from the devices style stack.  A pop on an
   * empty style stack is a nop.
   *)
    fun pushStyle (dev as DEV{emphStk, txt, ...}, sty) = (
	  emphStk := (concatTxt dev, sty) :: !emphStk;
	  txt := [])
    fun popStyle (dev as DEV{emphStk, txt, ...}) = let
	  val (tl, sty)::r = !emphStk
	  in
	    txt := wrapStyle (sty, concatTxt dev, tl);
	    emphStk := r
	  end
 
  (* the default style for the device (this is the current style,
   * if the style stack is empty).
   *)
    fun defaultStyle _ = NOEMPH

  (* maximum printing depth (in terms of boxes) *)
    fun depth _ = NONE
  (* the width of the device *)
    fun lineWidth (DEV{lineWid, ...}) = SOME lineWid
  (* the suggested maximum width of text on a line *)
    fun textWidth (DEV{textWid, ...}) = textWid

  (* output some number of spaces to the device *)
    fun space (dev, n) =
	  pcdata(dev, concat(List.tabulate (n, fn _ => "&nbsp;")))

  (* output a new-line to the device *)
    fun newline (dev as DEV{txt, ...}) =
	  txt := HTML.BR{clear=NONE} :: (concatTxt dev)

  (* output a string/character in the current style to the device *)
    val string = pcdata
    fun char (dev, c) = pcdata(dev, str c)

  (* flush is a nop for us *)
    fun flush _ = ()

    fun combineStyle (NOEMPH, sty) = sty
      | combineStyle (sty, NOEMPH) = sty
      | combineStyle (STYS l1, STYS l2) = STYS(l1 @ l2)
      | combineStyle (sty, STYS l) = STYS(sty::l)
      | combineStyle (sty1, sty2) = STYS[sty1, sty2]

    val styleNONE = NOEMPH
    val styleTT = TT
    val styleI = I
    val styleB = B
    val styleU = U
    val styleSTRIKE = STRIKE
    val styleEM = EM
    val styleSTRONG = STRONG
    val styleDFN = DFN
    val styleCODE = CODE
    val styleSAMP = SAMP
    val styleKBD = KBD
    val styleVAR = VAR
    val styleCITE = CITE
    val color = COLOR
    val link = LINK
    val anchor = ANCHOR

    fun openDev {wid, textWid} = DEV{
	    txt = ref [],
	    emphStk = ref [],
	    lineWid = wid,
	    textWid = textWid
	  }

    fun done (dev as DEV{emphStk = ref [], txt, ...}) = (case (concatTxt dev)
	   of [t] => (txt := []; t)
	    | l => (txt := []; HTML.TextList(List.rev l))
	  (* end case *))
      | done _ = raise Fail "device is not done yet"

  end; (* HTMLDev *)

