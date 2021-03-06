# Informal Semantics of the CFG IR

The **CFG** IR was introduced to provide a bridge between the first-order
**CPS** IR and the **LLVM** code generator.  This document gives an informal
description of the semantics of the **CFG** IR in terms of the abstract
machine model for **SML/NJ**.


## The CMachine

**SML/NJ**'s execution model is described by an abstract machine called
the **CMachine** (for *Continuation Machine*).  The state of the **CMachine**
is defined by registers, which can be divided into four groups.

### CMachine State Registers

The state registers are implicit in the **CFG** and are used to support
heap allocation and garbage collection.

* The allocation pointer specifies the next word in the nursery to allocated.

* The limit pointer points to an address a fixed distance below the end of
  the nursery.  The distance between the limit pointer and the end of the
  nursery is called the *allocation slop* and is used to make most heap-limit
  checks a simple pointer comparison.

* The store pointer points to a list of store records, which are used to
  track updates to older mutable objects that might create inter-generational
  references from older generations to younger ones.

### Global SML State Registers

The global **SML** registers are accessed via special instructions in the **CFG**.

* The exception-handler register holds the closure of the current exception
  handler.  For various reasons, this is represented as a *function* closure,
  instead of as a *continuation*.

* The var pointer register is a register that can be used to hold a pointer
  to thread-local storage.

### Parameter and Miscelleaneous Registers

The remaining registers are general-purpose registers that are used to
pass function arguments and for intermediate results.  The number of
registers available depends on the target hardware.  In the **CFG**
representation, the registers correspond to variables that have integer
or pointer type.  If there are more live variables than available
registers, the native code generator is responsible for register allocating and
spilling.  At function applications, however, we are guaranteed that the
number of arguments will be no greater than the number of registers.

The registers have names that reflect their role in the calling conventions,
but those names have no impact on the *CFG* IR.

### Floating-point registers

Finally, floating-point registers are used for floating-point function arguments
and intermediate results.  There are currently no callee-save floating-point
registers.

## The CFG IR

The **CFG** IR has two main types:

* Expressions (`exp`), which are trees that define computations.  These roughly
  correspond to the **MLRISC** `mltree` type and the **LLVM** `Value`
  type.

* Statements (`stm`), which are extended basic blocks with operations
  for allocation, updates, and control flow.

## The Semantics of CFG Statements

* `LET(e, (x, ty), stm)` evaluates the expression `e` and binds the result to `x`
  in the continuation `stm`.

* `ALLOC(p, args, x, stm)` allocates memory as specified by the allocation primop
  `p` and binds a pointer to the object to `x` in the continuation `stm`.  The
  allocation primops are

    * `SPECIAL` allocates a special object, which is an one-word object where
      additional information is stored in the object's length field.  The `args`
      list will have two values; the first is an untagged integer that is stored in
      the length field and the second is the contents of the object.

    * `RECORD{desc, mut}` allocates a record of ML values initialized to the
      results of evaluating `args` list.  The `desc` value is the object's descriptor
      and the `mut` flag is true if the object is mutable (*i.e.*, a `ref` cell).

    * `RAW_RECORD{desc, kind, sz}` allocates a record of raw numeric values of the
      specified kind and size in bits.  The `desc` value is the object's descriptor
      and the object is initialized to the results of evaluating the `args` list.

    * `RAW_ALLOC{desc, align, len}` allocates an uninitialized heap object of `len`
      bytes.  The descriptor is optional (and is not counted in the object's length).
      The `align` value is the alignment requirement for the object in bytes.

* `ARITH(p, args, (x, ty), stm)` performs integer arithmetic with overflow detection.

    * `IADD` -- integer addition

    * `ISUB` -- integer subtraction

    * `IMUL` -- integer multiplication

    * `IDIV` -- integer division (rounds toward zero).  Note that this operation
      should probably be moved to `PURE`, since we do explicit checks for
      division by zero and overflow before this operation.

    * `IREM` -- integer remainder (rounds toward zero).  Note that this operation
      should probably be moved to `PURE`, since we do explicit checks for
      division by zero and overflow before this operation.

* `SETTER(p, args, k)` updates memory as specified by the primop `p`.  The setter
  primops are

    * `UNBOXED_UPDATE` -- update an element of a polymorphic array, where the
      value to be stored is statically known to be a tagged value.  This
      operation takes as arguments the array's data object, the index, and the
      value to store.

    * `UPDATE` -- update an element of a polymorphic array, where the value
      to be stored may be a pointer.  This operation takes as arguments
      the array's data object, the index, and the value to store.  This
      operation allocates a store-list entry, in addition to doing the update.

    * `UNBOXED_ASSIGN` -- reference assignment, where the value being stored
      is statically known to be a tagged value.

    * `ASSIGN` -- reference assignment.  This operation allocates a
      store-list entry, in addition to doing the assignment.

    * `RAW_UPDATE (kind, sz)` -- spill-record update.  The second argument
      to this operator will be an integer index that is scaled by the element size to
      compute the address.  Note that this operation is also used to write ML values
      into a spill record, in which case the kind field is the native integer type
      (even though the values being written may be pointers).

    * `RAW_STORE (kind, int)` -- indexed store of raw numeric values, which is used
      to initialize data being passed to **C** functions.  There are three arguments,
      the base address, a byte offset, and the value to store. <br/>
      **NOTE:** unlike the `RAW_UPDATE` function, the index is **not** scaled when
      computing the store address.

    * `SET_HDLR` -- sets the exception-handler register

    * `SET_VAR` -- sets the var-pointer register

* `APPLY(f, args, tys)` makes the call `f (args)` using the standard calling
  convention for escaping functions.  The `tys` are the types of the arguments
  list.

* `THROW(k, args, tys)` makes the call `k (args)` using the standard calling
  convention for escaping continuations.  The `tys` are the types of the arguments
  list.

* `GOTO(lab, args, tys)` transfers control to the label `lab` with arguments
  `args` using the calling convention specified by `cc`.  The `tys` are the types
   of the arguments list.

* `SWITCH(arg, cases)` evaluates `arg` to an integer in the range
  `0..length(cases)-1` and then dispatches control to the specified case.

* `BRANCH(p, args, prob, kTrue, kFalse)` evaluates the `args` and then applies the
  conditional primop `p` to the argument results.  If the result is true, then the
  `kTrue` continuation is executed, otherwise the `kFalse` continuation is
  executed.  The `prob` field is an integer in the range `0..999`, representing
  the likelihood that the test will return true.  A probability value of `0`
  means that there is no prediction of the branch.
  The conditionl primops are:

    * `CMP{oper, signed, sz}` -- these define signed and unsigned integer comparisons
      of the specified number of bits (`sz` must be a power of 2).  The comparisons
      are the standard ones (`GT`, `GTE`, `LT`, `LTE`, `EQL`, `NEQ`).

    * `FCMP{oper, sz}` -- these define floating-point comparisons.

    * `FSGN sz` -- tests the sign bit of a floating-point argument and evaluates
      to `true` if it is set.

    * `PEQL` -- compares two pointer/tagged values for equality.

    * `PNEQ` -- compares two pointer/tagged values for inequality.

* `RCC{reentrant, linkage, proto, args, results, live, k}`

## The Semantics of CFG Expressions

CFG expressions are *pure* in that they do not allocate or modify memory,
or raise exceptions.

* `VAR{name}` evaluates the value bound to `name`

* `LABEL{name}` evaluates the address of the label `name`

* `NUM{iv, sz}` evaluates to an integer of `sz` bits.

* `LOOKER{oper, args}` evaluates the argument expressions and then applies the
  primop `oper` to the results.  The `looker` primops are

    * `DEREF` fetches the contents of the reference cell specified by the argument.

    * `SUBSCRIPT` -- polymorphic-array subscript; this operation works directly
      on the array's data object and does not do bounds checking.

    * `RAW_SUBSCRIPT{kind, sz}` -- packed numeric-array subscript, where `sz` is the
      size of the values and `kind` specifies either integer or floating-point
      values.  The operator takes as arguments the array's data object and an index,
      which is scaled to compute the address.  There is no bounds checking of
      the index.

    * `RAW_LOAD{kind, sz}` -- load a numeric value, where `sz` is the size of
      the value and `kind` specifies either integer or floating-point
      values.  This operator takes as arguments the base address of a heap
      object and a offset in bytes*.

    * `GET_HDLR` -- reads the exception-handler register, which contains a function
      closure that represents the current exception handler.

    * `GET_VAR` -- reads the "var" register, which implements a thread-local-storage
      mechanism.

* `PURE{oper, args}` evaluates the argument expressions and then applies the
  primop to the results.  The `pure` primops are further divided into classes:

    * `PURE_ARITH{oper, sz}` -- these are pure arithmetic operations on integer
      values of `sz` bits (`sz` must be a power of 2).  The pure arithmetic
      operators are:

          * `ADD` -- 2's complement addition

          * `SUB` -- 2's complement subtraction

          * `SMUL` -- 2's complement signed multiplication (note that signed
            and unsigned multiplication are the same operation, but are made
            distinct because **MLRISC** makes the distinction).

          * `SDIV` -- 2's complement signed division; we assume that zero divisors
            have been ruled out by explicit tests.  This operation rounds toward zero.

          * `SREM` -- 2's complement signed remainder; we assume that zero divisors
            have been ruled out by explicit tests.

          * `UMUL` -- 2's complement unsigned multiplication (note that signed
            and unsigned multiplication are the same operation, but are made
            distinct because **MLRISC** makes the distinction).

          * `UDIV` -- 2's complement unsigned division; we assume that zero divisors
            have been ruled out by explicit tests.

          * `UREM` -- 2's complement unsigned remainder; we assume that zero divisors
            have been ruled out by explicit tests.

          * `LSHIFT` -- left shift operation; the shift amount is guaranteed to be
            less than the word size.

          * `RSHIFT` -- arithmetic-right shift operation (*i.e.*, with sign-extension);
            the shift amount is guaranteed to be less than the word size.

          * `RSHIFTL` -- logical-right shift operation (*i.e.*, with zero-extension);
            the shift amount is guaranteed to be less than the word size.

          * `ORB` -- bit-wise logical or

          * `XORB` -- bit-wise logical-exclusive or

          * `ANDB` -- bit-wise logical and

          * `FADD` -- floating-point addition

          * `FSUB` -- floating-point subtraction

          * `FMUL` -- floating-point multiplication

          * `FDIV` -- floating-point division

          * `FNEG` -- floating-point negation

          * `FABS` -- floating-point absolute value

          * `FSQRT` -- floating-point square root

          * `FCOPYSIGN` -- floating-point copysign operation: returns its first argument with
            the sign set to the sign of its second argument.

          * `FLOAT_TO_BITS` -- bitcast a floating-point value to the equivalently sized
            word value.

          * `BITS_TO_FLOAT` -- bitcast a word value to the equivalently sized
            float-point value.

    * `EXTEND{signed, from, to}` -- extend a smaller integer representation
      (`from` bits) to a larger size (`to` bits); if `signed` is `true`, then
      the extension uses the sign bit, otherwise it uses zero to extend the value.

    * `TRUNC{from, to}` -- truncate a larger integer representation (`from` bits)
      to a smaller representation (`to` bits).

    * `INT_TO_REAL{from, to}` -- convert an integer value of size `from` bits to a
      floating-point value of size `to` bits.

    * `PURE_SUBSCRIPT` -- polymorphic-vector subscript; this operation works directly
      on the array's data object and does not do bounds checking.

    * `PURE_RAW_SUBSCRIPT{kind, sz}` -- packed numeric-vector subscript, where
      `sz` is the size of the values and `kind` specifies either integer or
      floating-point values.  This operation works directly on the array's data
      object and does not do bounds checking.

    * `RAW_SELECT{kind, sz, offset}` -- selects raw numeric values from raw
      records.  The `offset` is in bytes and should be a multiple of the
      value size.

* `SELECT{idx, arg}` extracts the `idx`th element from the record specified by
  `arg` (0-based).  The selected value should a valid SML value; *i.e.*,
  either a pointer or a tagged integer.

* `OFFSET{idx, arg}` extracts the `idx`th element from the record specified by
  `arg` (0-based).

