module SYMLOC-SORTS
     syntax IntPtr ::= SymLoc
     syntax SymBase
     syntax SymLoc
     syntax CValue ::= IntPtr
endmodule

module SYMLOC-SYNTAX
     imports SYMLOC-SORTS
     imports LIST
     imports COMPAT-SYNTAX

     syntax SymBase ::= base(IntPtr) [function]
     syntax Int ::= offset(SymLoc) [function]

     // Allocated duration.
     syntax Duration ::= "alloc"
     // Dynamic duration. (C++)
     syntax Duration ::= "dynamic"
     // Static duration.
     syntax Duration ::= static(String)
     syntax Duration ::= link(String)
     syntax Duration ::= string(String)
     syntax Duration ::= wstring(List)
     syntax Duration ::= builtinSymbol(String)
     syntax Duration ::= nativeSymbol(String)
     // Thread local duration.
     syntax Duration ::= threadLocal(Int)
     // Auto storage duration.
     syntax Duration ::= auto(Int)
     syntax Duration ::= "argv"
     // We strip storage class specifiers when processing declarations, so this
     // is how we keep track of register-ness.
     syntax Duration ::= register(Int)

     syntax Duration ::= nativeAddress()

     syntax Bool ::= isAllocatedDuration(SymLoc) [function]
     syntax Bool ::= isAllocatedDuration(SymBase) [function, klabel(isAllocatedDuration2)]
     // I.e., static or link.
     syntax Bool ::= isStaticDuration(SymLoc) [function]
     syntax Bool ::= isStaticDuration(SymBase) [function, klabel(isStaticDuration2)]
     syntax Bool ::= isThreadDuration(SymLoc) [function]
     syntax Bool ::= isAutoDuration(SymLoc) [function]
     syntax Bool ::= isAutoDuration(SymBase) [function, klabel(isAutoDuration2)]

     syntax Bool ::= isStringLoc(SymLoc) [function]
     syntax Bool ::= isLinkerLoc(SymLoc) [function]
     syntax Bool ::= isLinkerLoc(SymBase) [function, klabel(isLinkerLoc2)]
     syntax Bool ::= isBuiltinLoc(SymLoc) [function]
     syntax Bool ::= isBuiltinLoc(SymBase) [function, klabel(isBuiltinLoc2)]
     syntax Bool ::= isRegisterLoc(SymLoc) [function]
     syntax Bool ::= isNativeLoc(SymLoc) [function]
     syntax Bool ::= isNativeLoc(SymBase) [function, klabel(isNativeLoc2)]

     syntax SymBase ::= autoToRegister(SymBase) [function]

     syntax SymBase ::= obj(id: Int, align: Int, d: Duration)


     syntax SymLoc ::= resolveLinking(SymLoc, Map) [function]

     // Base, byte offset, bit offset.
     syntax SymLoc ::= loc(SymBase, Int)
     syntax SymLoc ::= CanonicalSymLoc
     syntax CanonicalSymLoc ::= loc(SymBase, Int, Set) [klabel(loc3)]
     syntax CanonicalSymLoc ::= "NullPointer" [klabel(NullPointer)]

     syntax KResult ::= SymLoc

     syntax SymLoc ::= SymLoc "+bytes" Int [function]

     syntax Bool ::= SymLoc ">bytes" SymLoc [function]
                   | SymLoc ">=bytes" SymLoc [function]
                   | SymLoc "<bytes" SymLoc [function]
                   | SymLoc "<=bytes" SymLoc [function]
                   | SymLoc "==bytes" SymLoc [function]

     syntax Bool ::= sameBase(IntPtr, IntPtr) [function]
     syntax Bool ::= sameAddress(SymLoc, SymLoc) [function]

     syntax String ::= getTU(SymLoc) [function]
     syntax String ::= getTU(SymBase) [function, klabel(getTU2)]
     syntax ThreadId ::= getThreadId(SymLoc) [function]
     syntax ThreadId ::= Int | "no-thread"
     syntax Int ::= getBitOffset(SymLoc) [function]

     syntax Set ::= prov(SymLoc) [function]
     syntax SymLoc ::= addProv(Provenance, SymLoc) [function]
     syntax SymLoc ::= addProv(Set, SymLoc) [function]

     // Pointers from an array need to be checked that they don't go out of
     // bounds of that array, even if that array happens to be part of a larger
     // object (i.e., surrounded by valid addresses).
     syntax Provenance ::= fromArray(Int, Int)
     // used to tag bit fields so that we know how many bits into the current byte they begin
     syntax Provenance ::= bitOffset(Int)

     syntax Bool ::= isFromArray(SymLoc) [function]

     syntax SymLoc ::= stripFromArray(SymLoc) [function]
     syntax SymLoc ::= stripProv(SymLoc) [function]

     syntax SymLoc ::= stripProv(SymLoc, K) [function, klabel(stripProvByKLabel)]
     syntax K ::= getProv(SymLoc, K) [function]
endmodule

module SYMLOC
     imports SYMLOC-SYNTAX
     imports COMPAT
     imports K-REFLECTION
     imports MAP

     rule isAllocatedDuration(NullPointer) => false
     rule isAllocatedDuration(Loc:SymLoc) => isAllocatedDuration(base(Loc)) [owise]

     rule isAllocatedDuration(obj(... d: alloc)) => true
     rule isAllocatedDuration(_::SymBase) => false [owise]

     rule isStaticDuration(NullPointer) => false
     rule isStaticDuration(Loc:SymLoc) => isStaticDuration(base(Loc)) [owise]

     rule isStaticDuration(obj(... d: static(_))) => true
     rule isStaticDuration(obj(... d: link(_))) => true
     rule isStaticDuration(obj(... d: string(_))) => true
     rule isStaticDuration(obj(... d: wstring(_))) => true
     rule isStaticDuration(obj(... d: builtinSymbol(_))) => true
     rule isStaticDuration(_::SymBase) => false [owise]

     rule isThreadDuration(loc(obj(... d: threadLocal(_)), _)) => true
     rule isThreadDuration(loc(obj(... d: threadLocal(_)), _, _)) => true
     rule isThreadDuration(_) => false [owise]

     rule isAutoDuration(NullPointer) => false
     rule isAutoDuration(Loc:SymLoc) => isAutoDuration(base(Loc)) [owise]

     rule isAutoDuration(obj(... d: auto(_))) => true
     rule isAutoDuration(obj(... d: argv)) => true
     rule isAutoDuration(obj(... d: register(_))) => true
     rule isAutoDuration(_::SymBase) => false [owise]

     rule isStringLoc(loc(obj(... d: string(_)), _)) => true
     rule isStringLoc(loc(obj(... d: string(_)), _, _)) => true
     rule isStringLoc(loc(obj(... d: wstring(_)), _)) => true
     rule isStringLoc(loc(obj(... d: wstring(_)), _, _)) => true
     rule isStringLoc(_) => false [owise]

     rule isLinkerLoc(NullPointer) => false
     rule isLinkerLoc(Loc:SymLoc) => isLinkerLoc(base(Loc)) [owise]

     rule isLinkerLoc(obj(... d: link(_))) => true
     rule isLinkerLoc(_::SymBase) => false [owise]

     rule isBuiltinLoc(NullPointer) => false
     rule isBuiltinLoc(Loc:SymLoc) => isBuiltinLoc(base(Loc)) [owise]

     rule isBuiltinLoc(obj(... d: builtinSymbol(_))) => true
     rule isBuiltinLoc(_::SymBase) => false [owise]

     rule isLinkerLoc(NullPointer) => false
     rule isLinkerLoc(Loc::SymLoc) => isLinkerLoc(base(Loc)) [owise]

     rule isRegisterLoc(loc(obj(... d: register(_)), _)) => true
     rule isRegisterLoc(loc(obj(... d: register(_)), _, _)) => true
     rule isRegisterLoc(_) => false [owise]

     rule isNativeLoc(obj(... d: nativeAddress())) => true
     rule isNativeLoc(obj(... d: nativeSymbol(_))) => true
     rule isNativeLoc(_::SymBase) => false [owise]

     rule isNativeLoc(NullPointer) => false
     rule isNativeLoc(Loc::SymLoc) => isNativeLoc(base(Loc)) [owise]

     rule autoToRegister(obj(Id::Int, Align::Int, auto(Th:Int))) => obj(Id, Align, register(Th))

     rule base(loc(Base:SymBase, _)) => Base
     rule base(loc(Base:SymBase, _, _)) => Base

     rule offset(loc(_, Offset:Int)) => Offset
     rule offset(loc(_, Offset:Int, _)) => Offset

     rule loc(Base:SymBase, Offset:Int) +bytes N:Int
          => loc(Base, Offset +Int N)
     rule loc(Base:SymBase, Offset:Int, Prov:Set) +bytes N:Int
          => loc(Base, Offset +Int N, Prov)
     rule NullPointer +bytes _ => NullPointer

     rule loc(_, A:Int) >bytes loc(_, B:Int) => A >Int B
     rule loc(_, A:Int) >=bytes loc(_, B:Int) => A >=Int B
     rule loc(_, A:Int) <bytes loc(_, B:Int) => A <Int B
     rule loc(_, A:Int) <=bytes loc(_, B:Int) => A <=Int B
     rule loc(_, A:Int) ==bytes loc(_, B:Int) => A ==Int B

     rule loc(_, A:Int, _) >bytes loc(_, B:Int, _) => A >Int B
     rule loc(_, A:Int, _) >=bytes loc(_, B:Int, _) => A >=Int B
     rule loc(_, A:Int, _) <bytes loc(_, B:Int, _) => A <Int B
     rule loc(_, A:Int, _) <=bytes loc(_, B:Int, _) => A <=Int B
     rule loc(_, A:Int, _) ==bytes loc(_, B:Int, _) => A ==Int B

     rule sameBase(loc(A:SymBase, _), loc(B:SymBase, _)) => A ==K B
     rule sameBase(loc(A:SymBase, _, _), loc(B:SymBase, _, _)) => A ==K B
     rule sameBase(loc(A:SymBase, _), loc(B:SymBase, _, _)) => A ==K B
     rule sameBase(loc(A:SymBase, _, _), loc(B:SymBase, _)) => A ==K B
     rule sameBase(_, _) => false [owise]


     rule sameAddress(loc(A::SymBase, B::Int), loc(A::SymBase, B::Int)) => true
     rule sameAddress(loc(A::SymBase, B::Int, _), loc(A::SymBase, B::Int, _)) => true
     rule sameAddress(loc(A::SymBase, B::Int), loc(A::SymBase, B::Int, _)) => true
     rule sameAddress(loc(A::SymBase, B::Int, _), loc(A::SymBase, B::Int)) => true
     rule sameAddress(NullPointer, NullPointer) => true
     rule sameAddress(_, _) => false [owise]

     rule getTU(NullPointer) => ""
     rule getTU(Loc:SymLoc) => getTU(base(Loc)) [owise]

     rule getTU(obj(... d: static(Tu:String))) => Tu
     rule getTU(obj(... d: link(Tu:String))) => Tu
     rule getTU(obj(... d: nativeAddress())) => "native"
     rule getTU(obj(... d: nativeSymbol(_))) => "native"
     rule getTU(obj(... d: builtinSymbol(_))) => "builtin"

     rule getThreadId(loc(obj(... d: threadLocal(Th:Int)), _)) => Th
     rule getThreadId(loc(obj(... d: threadLocal(Th:Int)), _, _)) => Th
     rule getThreadId(loc(obj(... d: auto(Th:Int)), _)) => Th
     rule getThreadId(loc(obj(... d: auto(Th:Int)), _, _)) => Th
     rule getThreadId(loc(obj(... d: register(Th:Int)), _)) => Th
     rule getThreadId(loc(obj(... d: register(Th:Int)), _, _)) => Th
     rule getThreadId(loc(obj(... d: argv), _)) => 0
     rule getThreadId(loc(obj(... d: argv), _, _)) => 0
     rule getThreadId(_) => no-thread [owise]

     rule addProv(P:Provenance, loc(Base:SymBase, Offset:Int, Prov:Set))
          => loc(Base, Offset, Prov SetItem(P))
     rule addProv(P:Provenance, loc(Base:SymBase, Offset:Int))
          => loc(Base, Offset, SetItem(P))
     rule addProv(_:Provenance, NullPointer) => NullPointer

     rule addProv(Prov':Set, loc(Base:SymBase, Offset:Int, Prov:Set))
          => loc(Base, Offset, Prov Prov')
     rule addProv(Prov':Set, loc(Base:SymBase, Offset:Int))
          => loc(Base, Offset, Prov')
     rule addProv(_:Set, NullPointer) => NullPointer

     rule prov(loc(_, _, Prov:Set)) => Prov
     rule prov(loc(_, _)) => .Set
     rule prov(NullPointer) => .Set

     rule isFromArray(Loc:SymLoc) => #isFromArray(Loc)

     syntax Bool ::= #isFromArray(SymLoc) [function]
     rule #isFromArray(loc(Base:SymBase, Offset:Int, SetItem(K:K) S:Set))
          => getKLabel(K) ==K #klabel(`fromArray`) orBool #isFromArray(loc(Base, Offset, S))
     rule #isFromArray(_) => false [owise]

     rule stripFromArray(loc(Base:SymBase, Offset:Int)) => loc(Base, Offset)
     rule stripFromArray(loc(Base:SymBase, Offset:Int, Prov:Set))
          => loc(Base, Offset, filterSet(Prov, #klabel(`notFromArray`)))
     rule stripFromArray(Loc:SymLoc) => Loc [owise]

     syntax Bool ::= notFromArray(Provenance) [function]
     rule notFromArray(fromArray(_, _)) => false
     rule notFromArray(_) => true [owise]

     rule stripProv(loc(Base:SymBase, Offset:Int, _)) => loc(Base, Offset)
     rule stripProv(loc(Base:SymBase, Offset:Int)) => loc(Base, Offset)
     rule stripProv(Loc:SymLoc) => Loc [owise]

     rule getBitOffset(loc(_, _, _:Set SetItem(bitOffset(I::Int)))) => I
     rule getBitOffset(_) => 0 [owise]

     rule stripProv(loc(Base::SymBase, Offset::Int, SetItem(K:K) S::Set), Lbl:K) => loc(Base, Offset, S)
          requires getKLabel(K) ==K Lbl
     rule stripProv(Loc::SymLoc, _) => Loc [owise]
     rule getProv(loc(_, _, SetItem(K:K) _), Lbl:K) => K
          requires getKLabel(K) ==K Lbl
     rule getProv(_, _) => .K [owise]

     rule resolveLinking(loc(Base::SymBase, Offset::Int, Prov::Set), _ Base |-> Base'::SymBase) => loc(Base', Offset, Prov)
     rule resolveLinking(loc(Base::SymBase, Offset::Int), _ Base |-> Base'::SymBase) => loc(Base', Offset)
     rule resolveLinking(Loc::SymLoc, _) => Loc
          requires notBool isLinkerLoc(Loc) [owise]
endmodule

