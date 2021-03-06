(* unsafe.sml
 *
 * Copyright (c) 1997 Bell Labs, Lucent Technologies.
 *
 * Unsafe operations on ML values.
 *)

structure Unsafe :> UNSAFE =
  struct

    structure CInterface = CInterface
    structure Object = Object
    structure Poll = Poll

    structure Vector =
      struct
	val sub = InlineT.PolyVector.sub
	val create = Core.Assembly.A.create_v
      end
    structure Array =
      struct
	val sub = InlineT.PolyArray.sub
	val update = InlineT.PolyArray.update
	val create = Core.Assembly.A.array
      end

    structure CharVector =
      struct
	type vector = CharVector.vector
	type elem = CharVector.elem
	val sub = InlineT.CharVector.sub
	val update = InlineT.CharVector.update
	val create = Core.Assembly.A.create_s
      end
    structure CharArray =
      struct
	type array = CharArray.array
	type elem = CharArray.elem
	val sub = InlineT.CharArray.sub
	val update = InlineT.CharArray.update
	val create : int -> array = InlineT.cast Core.Assembly.A.create_b
      end

    structure Word8Vector =
      struct
	type vector = Word8Vector.vector
	type elem = Word8Vector.elem
	val sub = InlineT.Word8Vector.sub
	val update = InlineT.Word8Vector.update
	val create : int -> vector = InlineT.cast Core.Assembly.A.create_s
      end
    structure Word8Array =
      struct
	type array = Word8Array.array
	type elem = Word8Array.elem
	val sub = InlineT.Word8Array.sub
	val update = InlineT.Word8Array.update
	val create = Core.Assembly.A.create_b
      end

(** once we have flat real vectors, we can include this substructure
    structure Real64Vector =
      struct
	type vector = Real64Vector.vector
	type elem = Real64Vector.elem
	val sub : (vector * int) -> elem
	val update : (vector * int * elem) -> unit
	val create : int -> vector
      end
**)
    structure Real64Array =
      struct
	type array = Real64Array.array
	type elem = Real64Array.elem
	val sub = InlineT.Real64Array.sub
	val update = InlineT.Real64Array.update
	val create = Core.Assembly.A.create_r
      end

    val getVar = InlineT.getvar
    val setVar = InlineT.setvar

    val getHdlr = InlineT.gethdlr
    val setHdlr = InlineT.sethdlr

    val getPseudo = InlineT.getpseudo
    val setPseudo = InlineT.setpseudo

    val blastRead : Word8Vector.vector -> 'a =
	(fn x => CInterface.c_function "SMLNJ-RunT" "blastIn" x)
    val blastWrite : 'a -> Word8Vector.vector =
	(fn x => CInterface.c_function "SMLNJ-RunT" "blastOut" x)

    val boxed = InlineT.boxed

    val cast = InlineT.cast

    val pStruct : Object.object ref = InlineT.cast Assembly.pstruct

    val topLevelCont = ref(Isolate.isolate (fn () => ()))

    val sigHandler = Assembly.sighandler

  end;

