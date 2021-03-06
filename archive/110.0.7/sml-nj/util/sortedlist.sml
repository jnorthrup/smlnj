(* Copyright 1989 by AT&T Bell Laboratories *)
structure SortedList =
struct

fun enter(new:int,l) =
  let fun f [] = [new]
	| f (l as h::t) = if new<h then new::l else if new>h then h::f t else l
  in  f l
  end

fun uniq l =
    let fun loop([],acc) = acc
	  | loop(a::r,acc) = loop(r,enter(a,acc))
    in loop(l,[])
    end

fun merge(a,[]) = a
  | merge([],a) = a
  | merge(l as (i:int)::a, m as j::b) = 
      if j<i then j::merge(l,b) else i::merge(a,if i<j then m else b)

local fun loop (a::b::rest) = loop(merge(a,b)::loop rest)
        | loop l = l
in fun foldmerge l = hd(loop l) handle Hd => []
end

fun remove(x as (xl:int)::xr, y as yl::yr) =
    if xl>yl then yl::remove(x,yr) else remove(xr,if xl<yl then y else yr)
  | remove(_,y) = y

fun rmv (x : int,l) =
    let fun loop nil = nil
	  | loop (a::b) = if x=a then b else a::loop b
    in loop l
    end

fun member l (e:int) =
  let fun f [] = false
	| f (h::t) = if h<e then f t else e=h
  in  f l
  end

fun intersect(nil,_) = nil
  | intersect(_,nil) = nil
  | intersect(l as (a:int)::b,r as c::d) =
	if a=c then a::intersect(b,d)
	else if a<c then intersect(b,r)
	else intersect(l,d)

fun difference(nil,_) = nil
  | difference(l,nil) = l
  | difference(l as (a:int)::b,r as c::d) =
	if a=c then difference(b,d)
	else if a<c then a::difference(b,r)
	else difference(l,d)	
end

(*
 * $Log: sortedlist.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:49  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:49  george
 *   Version 109.24
 *
 *)
