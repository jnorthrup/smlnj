(* Copyright 1989 by AT&T Bell Laboratories *)
structure IntStrMp : INTSTRMAP =
struct
  datatype 'a bucket = NIL | B of (int * string * 'a * 'a bucket)
  datatype 'a intstrmap =
    H of {table: 'a bucket array ref,elems: int ref,exn: exn,name: string option}
  fun bucketapp f =
      let fun loop NIL = ()
	    | loop(B(i,s,j,r)) = (f(i,s,j); loop r)
      in loop
      end
  fun namednew(name, size, exn) =
      H {table=ref(array(size,NIL)),elems=ref 0,exn=exn,name=SOME name}
  fun new(size, exn) =
      H {table=ref(array(size,NIL)),elems=ref 0,exn=exn,name=NONE}
  fun map (H{table,exn,...}) =
      let fun find(i,s,NIL) = raise exn
            | find(i,s,B(i',s',j,r)) = if i=i' andalso s=s' then j else find(i,s,r)
	  fun map' (i,s) = let val ref a = table
			   in find (i,s,a sub Bits.andb(i,(Array.length a)-1))
			   end
      in map'
      end
  fun rmv (H{table=ref a,elems,...}) (i,s) =
      let fun f(B(i',s',j,r)) =
	        if i=i' andalso s=s' then (dec elems; r) else B(i',s',j,f r)
	    | f x = x
	  val index = Bits.andb(i,(Array.length a)-1)
      in  update(a, index, f(a sub index))
      end
  fun app f (H{table=ref a,...}) =
      let fun zap 0 = ()
	    | zap n = let val m = n-1 in bucketapp f (a sub m); zap m end
      in  zap(Array.length a)
      end
  fun add (m as H{table as ref a, elems, name, ...}) (v as (i,s,j)) =
      let val size = Array.length a
       in if !elems <> size
	  then let val index = Bits.andb(i, size-1)
		   fun f(B(i',s',j',r)) =
		         if i=i' andalso s=s' then B(i,s,j,r) else B(i',s',j',f r)
		     | f x = (inc elems; B(i,s,j,x))
	       in update(a,index,f(a sub index))
	       end
	  else let val newsize = size+size
		   val newsize1 = newsize-1
		   val new = array(newsize,NIL)
		   fun bucket n =
		       let fun add'(a,b,B(i,s,j,r)) =
			       if Bits.andb(i,newsize1) = n
			       then add'(B(i,s,j,a),b,r)
			       else add'(a,B(i,s,j,b),r)
			     | add'(a,b,NIL) = 
			       (update(new,n,a);
				update(new,n+size,b);
				bucket(n+1))
		       in add'(NIL,NIL,a sub n)
		       end
	       in (case name of
		     NONE => ()
		   | SOME name =>
		     (print("\nIncreasing size of intmap " ^ name ^ " to: ");
		      print newsize; print "\n"; ()));
		  bucket 0 handle Subscript => ();
		  table := new;
		  add m v
	       end
      end
  fun intStrMapToList(H{table,...})=
      let val a = !table;
	  val last = Array.length a - 1
	  fun loop (0, NIL, acc) = acc
	  |   loop (n, B(i,s,j,r), acc) = loop(n, r, (i,s,j)::acc)
	  |   loop (n, NIL, acc) = loop(n-1, a sub (n-1), acc)
       in loop(last,a sub last,[])
      end
  fun transform (f:'a -> '2b) (H{table=ref a, elems=ref n, exn, name}) =
      let val newa = array(Array.length a,NIL)
	  fun mapbucket NIL = NIL
	    | mapbucket(B(i,s,x,b)) = B(i,s,f x,mapbucket b)
	  fun loop i = (update(newa,i,mapbucket(a sub i)); loop(i+1))
       in loop 0 handle Subscript => ();
	  H{table=ref newa, elems=ref n, exn=exn, name=name}
      end
end
