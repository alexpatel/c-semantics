module C-CONVERSION-SYNTAX
     imports C-DYNAMIC-SORTS
     imports C-TYPING-SORTS

     // interpret the result of arithmetic as in 6.5.4
     syntax KItem ::= arithInterpret(UType, NumValue) [function]
     syntax KItem ::= arithInterpretHold(UType, NumValue)
     // as described in 6.3 // totype, fromvalue
     // change it to function in order
     // to solve anywhere rule
     syntax KItem ::= cast(UType, RValue) [function]
     //Might not need this if we have anywhere rule
     syntax KItem ::= castHold(UType, RValue)
endmodule

module C-CONVERSION
     imports C-CONVERSION-SYNTAX
     imports INT
     imports FLOAT
     imports SYMLOC-SYNTAX
     imports C-ALIGNMENT-SYNTAX
     imports C-BITS-SYNTAX
     imports C-BITSIZE-SYNTAX
     imports C-COMMON-EXPR-EVAL-SYNTAX
     imports C-DYNAMIC-SYNTAX
     imports C-ERROR-SYNTAX
     imports C-SETTINGS-SYNTAX
     imports C-TYPING-SYNTAX

     rule arithInterpret(T:IntegerUType, N:Int) => tv(N, T)
          requires (min(T) <=Int N)
               andBool (max(T) >=Int N)
     rule arithInterpret(T::UType, unknown(I:Int)) => makeUnknown(arithInterpret(T, I))
     rule arithInterpret(T::UType, trap) => trap(T)
     rule arithInterpret(T:FloatUType, F:Float) => tv(roundCFloat(T, F), T)
          requires fmin(T) <=Float F andBool fmax(T) >=Float F
     rule arithInterpret(T:FloatUType, F:Float) => arithInterpretHold(T, F)
          requires notBool (fmin(T) <=Float F andBool fmax(T) >=Float F)

     rule (.K => UNDEF("CCV12", "Floating-point overflow."))
          ~> arithInterpretHold(T:FloatUType, F:Float)
          requires notBool (fmin(T) <=Float F andBool fmax(T) >=Float F)

     // unsigned arithmetic isn't supposed to overflow
     rule arithInterpret(T:UnsignedIntegerUType, N:Int) => tv(N modInt (max(T) +Int 1), T)
          requires ((N >Int max(T)) orBool (N <Int min(T))) andBool notBool hasLint
     rule arithInterpret(T:SignedIntegerUType, I:Int) => arithInterpretHold(T, I)
          requires notBool ((min(T) <=Int I) andBool (max(T) >=Int I))

     rule (.K => UNDEF("CCV1", "Signed integer overflow."))
          ~> arithInterpretHold(T:SignedIntegerUType, I:Int)
          requires notBool ((min(T) <=Int I) andBool (max(T) >=Int I))
          [structural]

     rule cast(T'::UType, tv(V:CValue, T::UType)) => tv(V, cast(T', T))
          requires T' ==Type T andBool notBool isPointerUType(T')

     /*@ \fromStandard{\source[n1570]{\para{6.3.1.2}{1}}}{
     When any scalar value is converted to \cinline{_Bool}, the result is 0 if
     the value compares equal to 0; otherwise, the result is 1.
     }*/
     rule cast(ut(Mods::Set, bool), tv(I:Int, T:IntegerUType))
          => #if I ==Int 0
               #then tv(0, cast(ut(Mods, bool), T))
               #else tv(1, cast(ut(Mods, bool), T)) #fi

     rule cast(ut(Mods::Set, bool), tv(F:Float, T:FloatUType))
          => #if F ==Float zeroCFloat(T)
               #then tv(0, cast(ut(Mods, bool), T))
               #else tv(1, cast(ut(Mods, bool), T)) #fi

     rule cast(ut(Mods::Set, bool), tv(V:SymLoc, T:PointerUType))
          => #if V ==K NullPointer
               #then tv(0, cast(ut(Mods, bool), T))
               #else tv(1, cast(ut(Mods, bool), T)) #fi

     /*@ \fromStandard{\source[n1570]{\para{6.3.1.3}{1}}}{
     When a value with integer type is converted to another integer type other
     than \cinline{_Bool}, if the value can be represented by the new type, it
     is unchanged.
     }*/
     rule cast(T':IntegerUType, tv(V:Int, T:IntegerUType))
          => tv(V, cast(T', T))
          requires notBool isBoolUType(T')
               andBool inRange(V, T')

     rule cast(T':IntegerUType, tv(encodedValue(L:SymLoc, N::Int, M::Int), T:IntegerUType))
          => tv(encodedValue(L, N, M), T')
          requires notBool isBoolUType(T')
               andBool M -Int N <=Int bitSizeofType(T')

     /*@ \fromStandard{\source[n1570]{\para{6.3.1.3}{2}}}{
     Otherwise, if the new type is unsigned, the value is converted by
     repeatedly adding or subtracting one more than the maximum value that can
     be represented in the new type until the value is in the range of the new
     type.
     }*/
     rule cast(T':UnsignedIntegerUType, tv(I:Int, T:IntegerUType))
          => cast(T', tv(I +Int max(T') +Int 1, T))
          requires (I <Int min(T')) andBool notBool hasLint

     rule cast(T':UnsignedIntegerUType, tv(I:Int, T:IntegerUType))
          => tv(I %Int (max(T') +Int 1), cast(T', T))
          requires (I >Int max(T')) andBool notBool hasLint

     /*@ \fromStandard{\source[n1570]{\para{6.3.1.3}{3}}}{
     Otherwise, the new type is signed and the value cannot be represented in
     it; either the result is implementation-defined or an
     implementation-defined signal is raised.
     }*/
     // choice
     // rule cast(T':BitfieldUType, tv(I:Int, T:IntegerUType))
     //      => cast(T', tv(I %Int (2 ^Int absInt(bitSizeofType(T'))), T))
     //      requires (absInt(I) >Int (2 ^Int absInt(bitSizeofType(T'))))
     //           andBool isSignedIntegerType(innerType(T'))
     //      [structural]
     // rule cast(ut(Mods:Set, signed-char), tv(I:Int, T:IntegerUType))
     //      => cast(ut(Mods, signed-char),
     //           tv(I %Int (2 ^Int absInt(bitSizeofType(ut(Mods, signed-char)))), T))
     //      requires (absInt(I) >Int (2 ^Int absInt(bitSizeofType(ut(Mods, signed-char)))))
     //      [structural]
     // rule cast(ut(Mods:Set, short-int), tv(I:Int, T:IntegerUType))
     //      => cast(ut(Mods, short-int),
     //           tv(I %Int (2 ^Int absInt(bitSizeofType(ut(Mods, short-int)))), T))
     //      requires (absInt(I) >Int (2 ^Int absInt(bitSizeofType(ut(Mods, short-int)))))
     //      [structural]
     // rule cast(ut(Mods:Set, int), tv(I:Int, T:IntegerUType))
     //      => cast(ut(Mods, int),
     //           tv(I %Int (2 ^Int absInt(bitSizeofType(ut(Mods, int)))), T))
     //      requires (absInt(I) >Int (2 ^Int absInt(bitSizeofType(ut(Mods, int)))))
     //      [structural]
     // rule cast(ut(Mods:Set, long-int), tv(I:Int, T:IntegerType))
     //      => cast(ut(Mods, long-int),
     //           tv(I %Int (2 ^Int absInt(bitSizeofType(ut(Mods, long-int)))), T))
     //      requires (absInt(I) >Int (2 ^Int absInt(bitSizeofType(ut(Mods, long-int)))))
     //      [structural]
     // rule cast(ut(Mods:Set, long-long-int), tv(I:Int, T:IntegerUType))
     //      => cast(ut(Mods, long-long-int),
     //           tv(I %Int (2 ^Int absInt(bitSizeofType(ut(Mods, long-long-int)))), T))
     //      requires (absInt(I) >Int (2 ^Int absInt(bitSizeofType(ut(Mods, long-long-int)))))
     //      [structural]
     // rule cast(T':SignedIntegerUType, tv(I:Int, T:IntegerUType))
     //      => tv(I +Int (2 ^Int absInt(bitSizeofType(T'))), T')
     //      requires (I <Int min(T'))
     //           andBool (absInt(I) <=Int (2 ^Int absInt(bitSizeofType(T'))))
     //           andBool notBool isBoolUType (T')
     //      [structural]
     // rule cast(T':SignedIntegerUType, tv(I:Int, T:IntegerUType))
     //      => tv(I -Int (2 ^Int absInt(bitSizeofType(T'))), T')
     //      requires (I >Int max(T'))
     //           andBool (absInt(I) <=Int (2 ^Int absInt(bitSizeofType(T'))))
     //           andBool notBool isBoolUType (T')
     //      [structural]

     rule cast(T':SignedIntegerUType, tv(I:Int, T:IntegerUType))
          => castHold(T', tv(I:Int, T))
          requires notBool inRange(I, T')

     rule (.K => IMPL("CCV2",
               "Conversion to signed integer outside the range that can be represented."))
          ~> castHold(T':SignedIntegerUType, tv(I:Int, _:IntegerUType))
          requires notBool inRange(I, T')
          [structural]

     rule cast(T'::UType, tv(unknown(I:Int), T::UType))
          => makeUnknown(cast(T', tv(I, T)))
          requires notBool isPointerUType(T')

     /*@ \fromStandard{\source[n1570]{\para{6.3.1.4}{1}}}{
     When a finite value of real floating type is converted to an integer type
     other than \cinline{_Bool}, the fractional part is discarded (i.e., the
     value is truncated toward zero). If the value of the integral part cannot
     be represented by the integer type, the behavior is undefined.
     }*/
     rule cast(T':IntegerUType, tv(V:Float, T:FloatUType))
          => tv(Float2Int(V), cast(T', T))
          requires inRange(Float2Int(V), T')
               andBool notBool isBoolUType (T')

     rule cast(T':IntegerUType, tv(V:Float, T:FloatUType))
          => castHold(T', tv(V:Float, T))
          requires notBool inRange(Float2Int(V), T')

     rule (.K => UNDEF("CCV3",
               "Conversion to integer from float outside the range that can be represented."))
          ~> castHold(T':IntegerUType, tv(V:Float, _:FloatUType))
          requires notBool inRange(Float2Int(V), T')
          [structural]

     /*@ \fromStandard{\source[n1570]{\para{6.3.1.4}{2}}}{
     When a value of integer type is converted to a real floating type, if the
     value being converted can be represented exactly in the new type, it is
     unchanged. If the value being converted is in the range of values that can
     be represented but cannot be represented exactly, the result is either the
     nearest higher or nearest lower representable value, chosen in an
     implementation-defined manner. If the value being converted is outside the
     range of values that can be represented, the behavior is undefined.
     Results of some implicit conversions may be represented in greater range
     and precision than that required by the new type (see 6.3.1.8 and
     6.8.6.4).
     }*/
     rule cast(T':FloatUType, tv(V:Int, T:IntegerUType))
          => tv(Int2Float(V, typePrecision(T'), typeExponent(T')), cast(T', T))
          requires inRange(Int2Float(V, maxFloatPrecision, maxFloatExponent), T')

     //TODO(traiansf): Shouldn't here be an undef rule for too large integers, too?

     /*@ \fromStandard{\source[n1570]{\para{6.3.1.5}{2}}}{
     When a value of real floating type is converted to a real floating type,
     if the value being converted can be represented exactly in the new type,
     it is unchanged. If the value being converted is in the range of values
     that can be represented but cannot be represented exactly, the result is
     either the nearest higher or nearest lower representable value, chosen in
     an implementation-defined manner. If the value being converted is outside
     the range of values that can be represented, the behavior is undefined.
     Results of some implicit conversions may be represented in greater range
     and precision than that required by the new type (see 6.3.1.8 and
     6.8.6.4).
     }*/
     rule cast(T':FloatUType, tv(V:Float, T:FloatUType))
          => tv(roundCFloat(T', V), cast(T', T))
          requires inRange(V, T')

     rule cast(T':FloatUType, tv(V:Float, T:FloatUType))
          => castHold(T', tv(V:Float, T))
          requires notBool inRange(V, T')

     rule (.K => UNDEF("CCV4",
               "Floating-point value outside the range of values that can be represented after conversion."))
          ~> castHold(T':FloatUType, tv(V:Float, _:FloatUType))
          requires notBool inRange(V, T')
          [structural]


     /*@ \fromStandard{\source[n1570]{\para{6.3.2.2}{1}}}{
     The (nonexistent) value of a void expression (an expression that has type
     \cinline{void}) shall not be used in any way, and implicit or explicit
     conversions (except to \cinline{void}) shall not be applied to such an
     expression. If an expression of any other type is evaluated as a void
     expression, its value or designator is discarded. (A void expression is
     evaluated for its side effects.)
     }*/
     rule cast(ut(_, void), V:RValue) => voidVal
          requires notBool isHold(V)

     rule cast(ut(_, T::SimpleUType), emptyValue) => castHold(utype(T), emptyValue)
          requires T =/=K void
     rule cast(ut(_, T::SimpleUType), voidVal) => castHold(utype(T), voidVal)
          requires (T =/=K void)

     rule (.K => UNDEF("CCV5", "Casting empty value to type other than void."))
          ~> castHold(ut(_, T::SimpleUType), emptyValue)
          requires T =/=K void
          [structural]
     rule (.K => UNDEF("CCV6", "Casting void type to non-void type."))
          ~> castHold(ut(_, T::SimpleUType), voidVal)
          requires T =/=K void
          [structural]

     /*@ \fromStandard{\source[n1570]{\para{6.3.2.3}{1--2}}}{
     A pointer to void may be converted to or from a pointer to any object
     type. A pointer to any object type may be converted to a pointer to void
     and back again; the result shall compare equal to the original pointer.

     For any qualifier $q$, a pointer to a non-$q$-qualified type may be
     converted to a pointer to the $q$-qualified version of the type; the
     values stored in the original and converted pointers shall compare equal.
     }*/


     /*@ \fromStandard{\source[n1570]{\para{6.3.2.3}{3}}}{
     An integer constant expression with the value 0, or such an expression
     cast to type \cinline{void *}, is called a null pointer constant. If a
     null pointer constant is converted to a pointer type, the resulting
     pointer, called a null pointer, is guaranteed to compare unequal to a
     pointer to any object or function.
     }*/
     rule cast(T':PointerUType, V:RValue) => tv(NullPointer, cast(T', utype(V)))
          requires isNullPointerConstant(V)

     /*@ \fromStandard{\source[n1570]{\para{6.3.2.3}{4}}}{
     Conversion of a null pointer to another pointer type yields a null pointer
     of that type. Any two null pointers shall compare equal.
     }*/
     rule cast(T':PointerUType, tv(NullPointer, T:PointerUType))
          => tv(NullPointer, cast(T', T))

     /*@ \fromStandard{\source[n1570]{\para{6.3.2.3}{5}}}{
     An integer may be converted to any pointer type. Except as previously
     specified, the result is implementation-defined, might not be correctly
     aligned, might not point to an entity of the referenced type, and might be
     a trap representation.
     }*/
     rule cast(T':PointerUType, tv(V:CValue, T:IntegerUType))
          => castHold(T', tv(V, T))
          requires notBool isNullPointerConstant(tv(V, T))
     rule (.K => IMPL("CCV13", "Conversion from an integer to non-null pointer."))
          ~> castHold(T':PointerUType, tv(V:CValue, T:IntegerUType))
          requires notBool isNullPointerConstant(tv(V, T))

     /*@ \fromStandard{\source[n1570]{\para{6.3.2.3}{6}}}{
     Any pointer type may be converted to an integer type. Except as previously
     specified, the result is implementation-defined. If the result cannot be
     represented in the integer type, the behavior is undefined. The result
     need not be in the range of values of any integer type.
     }*/
     rule cast(T':IntegerUType, tv(V::CValue, T:PointerUType))
          => checkUse(tv(cfg:pointerToInt(V, T'), cast(T', T)))
          requires notBool isBoolUType(T')
               andBool (byteSizeofType(T) <=Int byteSizeofType(T')
                    orBool (V ==K NullPointer))
     rule cast(T':IntegerUType, tv(V::CValue, T:PointerUType))
          => castHold(T', tv(V:CValue, T))
          requires (V =/=K NullPointer)
               andBool notBool isBoolUType(T')
               andBool byteSizeofType(T) >Int byteSizeofType(T')
     rule (.K => UNDEF("CCV7",
               "Conversion from pointer to integer of a value possibly unrepresentable in the integer type."))
          ~> castHold(T':IntegerUType, tv(V::CValue, T:PointerUType))
          requires (V =/=K NullPointer)
               andBool notBool isBoolUType(T')
               andBool byteSizeofType(T) >Int byteSizeofType(T')
          [structural]

     rule cast(T'::UType, tv(V::CValue, T::UType))
          => castHold(T', tv(V, T))
          requires (isPointerUType(T) andBool isFloatUType(T'))
               orBool (isFloatUType(T) andBool isPointerUType(T'))
               orBool (T =/=Type T'
                    andBool ((notBool isPointerUType(T)
                              andBool notBool isArithmeticType(type(T))
                              andBool notBool isVoidType(type(T')))
                         orBool (notBool isPointerUType(T')
                              andBool notBool isArithmeticType(type(T'))
                              andBool notBool isVoidType(type(T')))))

     rule (.K => CV("CCV9",
          "Conversion from pointer to floating point type or from floating point type to pointer."))
          ~> castHold(T'::UType, tv(_, T::UType))
          requires (isPointerUType(T) andBool isFloatUType(T'))
               orBool (isFloatUType(T) andBool isPointerUType(T'))

     rule (.K => CV("CCV10",
          "Conversion to or from non-scalar type."))
          ~> castHold(T'::UType, tv(_, T::UType))
          requires notBool isVoidType(type(T')) andBool (
               (notBool isPointerUType(T) andBool notBool isArithmeticType(type(T))) orBool
               (notBool isPointerUType(T') andBool notBool isArithmeticType(type(T'))))

     /*@ \fromStandard{\source[n1570]{\para{6.3.2.3}{7}}}{
     A pointer to an object type may be converted to a pointer to a different
     object type. If the resulting pointer is not correctly aligned for the
     referenced type, the behavior is undefined. Otherwise, when converted back
     again, the result shall compare equal to the original pointer. When a
     pointer to an object is converted to a pointer to a character type, the
     result points to the lowest addressed byte of the object. Successive
     increments of the result, up to the size of the object, yield pointers to
     the remaining bytes of the object.
     }*/
     /*@ \fromStandard{\source[n1570]{\para{6.3.2.3}{8}}}{
     A pointer to a function of one type may be converted to a pointer to a
     function of another type and back again; the result shall compare equal to
     the original pointer. If a converted pointer is used to call a function
     whose type is not compatible with the referenced type, the behavior is
     undefined.
     }*/
     rule cast(ut(Mods'::Set, pointerType(T'::Type)),
               tv(Loc:SymLoc, ut(Mods::Set, pointerType(T::Type))))
          => tv(Loc, cast(ut(Mods', pointerType(T')), ut(Mods, pointerType(T))))
          requires notBool isCompleteType(T')
               orBool type(pointerType(T')) ==Type type(pointerType(T))
               orBool getAlignas(T') <=Int getAlign(Loc)
               orBool (isFunctionType(T) andBool isFunctionType(T'))
     //TODO(dwightguth): handle pointer alignment
     rule cast(ut(Mods'::Set, pointerType(T'::Type)), tv(Loc:SymLoc, ut(Mods::Set, pointerType(T::Type))))
          => castHold(ut(Mods', pointerType(T':Type)), tv(Loc, ut(Mods, pointerType(T))))
          requires isCompleteType(T')
               andBool type(pointerType(T')) =/=Type type(pointerType(T))
               andBool getAlignas(T') >Int getAlign(Loc)
     rule (.K => UNDEF("CCV11",
               "Conversion to a pointer type with a stricter alignment requirement (possibly undefined)."))
          ~> castHold(ut(_, pointerType(T':Type)), tv(Loc:SymLoc, ut(_, pointerType(_))))
          requires getAlignas(T') >Int getAlign(Loc)
          [structural]

     syntax UType ::= cast(UType, UType) [function, klabel(castTypes)]
     rule cast(ut(_, T'::SimpleUType), ut(Mods::Set, _)) => ut(Mods, T')

endmodule

