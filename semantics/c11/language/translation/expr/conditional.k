module C-EXPR-CONDITIONAL
     imports BASIC-K
     imports BOOL
     imports INT
     imports K-EQUAL
     imports BITS-SYNTAX
     imports C-DYNAMIC-SYNTAX
     imports C-EXPR-LOGICAL-SYNTAX
     imports C-SYNTAX
     imports C-TYPING-SYNTAX
     imports C-TYPING-EXPR-SYNTAX

     /*@ \fromStandard{\source[n1570]{\para{6.5.15}{4}}}{
     The first operand is evaluated; there is a sequence point between its
     evaluation and the evaluation of the second or third operand (whichever is
     evaluated). The second operand is evaluated only if the first compares
     unequal to 0; the third operand is evaluated only if the first compares
     equal to 0; the result is the value of the second or third operand
     (whichever is evaluated), converted to the type described below.
     }*/

     rule E:K ? E1:K : E2:K
          => evalConditional(simplifyTruth(E), E1, E2)

     syntax KItem ::= evalConditional(K, K, K)
     context evalConditional(HOLE:KItem => reval(HOLE), _, _) [result(RValue)]
     context evalConditional(_, HOLE:KItem => reval(HOLE), _) [result(RValue)]
     context evalConditional(_, _, HOLE:KItem => reval(HOLE)) [result(RValue)]

     rule (.K => typeof(C ? E1 : E2)) ~> evalConditional(C:RValue, E1:RValue, E2:RValue)

     rule typeof(T:Type) ~> evalConditional(E:K, E1:K, E2:K)
          => evalConditional(E, Cast(T, E1), Cast(T, E2), utype(T))
          requires notBool isVariablyModifiedType(T)
     rule typeof(T:Type) ~> evalConditional(E:K, E1:K, E2:K)
          => evalConditional(E, E1, E2, utype(T))
          requires isVariablyModifiedType(T)

     syntax KItem ::= evalConditional(K, K, K, UType) [klabel(evalConditional4)]
     context evalConditional(HOLE:KItem => reval(HOLE), _, _, _) [result(RValue)]
     context evalConditional(_, HOLE:KItem => reval(HOLE), _, _) [result(RValue)]
     context evalConditional(_, _, HOLE:KItem => reval(HOLE), _) [result(RValue)]

     rule evalConditional(C:RValue, E1:RValue, E2:RValue, T::UType)
          => te(stripHold(C) ? E1 : E2, stripConstants(T))
          requires isHold(C) orBool isVariablyModifiedType(type(T))
     rule evalConditional(tv(1, ut(_, int)), E1:RValue, _:RValue, T::UType) => E1
          requires notBool isVariablyModifiedType(type(T))
     rule evalConditional(tv(0, ut(_, int)), _:RValue, E2:RValue, T::UType) => E2
          requires notBool isVariablyModifiedType(type(T))
     rule evalConditional(tv((unknown(I:Int) => #if I ==Int 0 #then 0 #else 1 #fi), ut(_, int)), _, _, T::UType)
          requires notBool isVariablyModifiedType(type(T))

endmodule

