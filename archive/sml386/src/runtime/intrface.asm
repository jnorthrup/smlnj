;*************************************************************************
; Copyright (c) 1991 by:   Department of Computer Science
;			   The Technical University of Denmark
;			   DK-2800 Lyngby
;
;
; 19 Dec. 1991	      Yngvi Skaalum Guttesen	  
;
; This file contains the code (restoreregs) to perform the context-switch
; from USE16 code (the runtime system) to USE32 code (the ML code).

    TITLE   USE16/USE32 interface

    PAGE    90,132

    .386p
    .387

    .XLIST

include tags.inc

DWP     EQU <dword ptr>
tmp     EQU <eax>

    .LIST

_RUNCODE segment para use32 public 'CODE'

    EXTRN   _enterUse32       : FAR
    EXTRN   Use32Stack        : DWORD

_RUNCODE ends

_DATA   segment word public use16 'DATA'

    EXTRN   _wsUse32Data    : WORD  ; the data and code selectors
    EXTRN   _wsUse32Code    : WORD  ; for the USE32 ML-heap
    
    off_enterUse32	DW ?	    ; the offset and segment addr. for
    seg_enterUse32	DW ?	    ; the USE32 entry rutine.

    dwUse16Stackpointer DD ?

_DATA   ends

_TEXT	segment word public use16 'CODE'

    assume cs:_TEXT, ds:_DATA

PUBLIC _restoreregs

_restoreregs PROC NEAR

    assume  ds:_DATA, es:nothing, fs:nothing, gs:nothing

    push    di      ; save the C-compilers registers
    push    si
    push    bp
    push    ds

    mov     ax, ds
    mov     gs, ax

    mov     ax, _wsUse32Data	  ; load the USE32 selectors
    mov     bx, _wsUse32Code

    mov     seg_enterUse32, bx		; load the addr. of the USE32
    mov     ebx, offset _enterUse32	; entry rutine (enterUse32).
    mov     off_enterUse32, bx

    mov     dwUse16StackPointer, esp    ; save the Use16 stack pointer


    mov     ss, ax                      ; setup the new use32 stack
    mov     esp, OFFSET Use32Stack

    assume  ss:_RUNCODE

    mov     ds, ax                      ; ds = ML HEAP
    mov     es, ax                      ; es = ML HEAP

    call    DWORD PTR gs:off_enterUse32

    mov     ax, gs			; restore the segment registers
    mov     es, ax
    mov     ds, ax

    mov     ss, ax                      ; restore the Use16 stack
    mov     esp, dwUse16StackPointer

    assume  ss:_DATA

    pop     ds      ; restore the C-compilers registers
    pop     bp
    pop     si
    pop     di

    ret 	    ; return to the runtime system (run_ml)

_restoreregs ENDP

_TEXT ENDS

END
