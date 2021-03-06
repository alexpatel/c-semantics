module C-DECL-TAGGED-SYNTAX
     imports LIST
     imports COMMON-SORTS
     imports C-TYPING-SORTS
     // Not defined, just used.
     syntax KItem ::= addGlobalTag(CId, TagInfo)
     syntax KItem ::= addLocalTag(CId, TagInfo)

     syntax FieldInfo ::= makeStructFieldInfo(Bool, List) [function]
     syntax FieldInfo ::= makeUnionFieldInfo(Bool, List) [function]
endmodule

module C-DECL-TAGGED
     imports BOOL
     imports C-ABSTRACT-SYNTAX
     imports C-ALIGNMENT-SYNTAX
     imports C-BITSIZE-SYNTAX
     imports C-CONFIGURATION
     imports C-DECL-DEFINITION-SYNTAX
     imports C-DECL-TAGGED-SYNTAX
     imports C-DYNAMIC-SYNTAX
     imports C-ENV-SYNTAX
     imports C-ERROR-SYNTAX
     imports COMPAT-SYNTAX
     imports C-SETTINGS-SYNTAX
     imports C-SYNTAX
     imports C-TYPING-SYNTAX
     imports INT
     imports MAP
     imports SETTINGS-SYNTAX
     imports STRING

     context StructDef(_, HOLE:StrictList => seqstrict(HOLE), _)
     context UnionDef(_, HOLE:StrictList => seqstrict(HOLE), _)

     // TODO(chathhorn): handle global/local differently.
     // note that struct defs might appear buried in a type.
     rule EnumDef(X::CId, list(L:List), list(Mods::List))
          => defEnumConstants(Packed() in Mods, X, 0, 0, 0, L)
          [structural]
     rule StructDef(X::CId, krlist(L:List), list(Mods::List))
          => addTag(X, makeStructFieldInfo(Packed() in Mods, incompleteToFlexibleArrayMember(numberUnnamed(L))))
          requires hasNamedField(L) andBool structFieldsComplete(L)
          [structural]
     rule (.K => UNDEF("CDT1", "Structs must contain a named member."))
          ~> StructDef(_, krlist(L:List), _)
          requires notBool hasNamedField(L)
          [structural]
     rule (.K => CV("CDT3", "Field " +String firstIncompleteOrFlexible(L) +String " has incomplete type or contains a flexible array member."))
          ~> StructDef(_, krlist(L:List), _)
          requires notBool structFieldsComplete(L)
          [structural]
     rule UnionDef(X::CId, krlist(L:List), list(Mods::List))
          => addTag(X, makeUnionFieldInfo(Packed() in Mods, numberUnnamed(L)))
          requires hasNamedField(L) andBool allComplete(L)
          [structural]
     rule (.K => UNDEF("CDT2", "Unions must contain a named member."))
          ~> UnionDef(_, krlist(L:List), _)
          requires notBool hasNamedField(L)
          [structural]
     rule (.K => CV("CDT4", "Field " +String firstIncomplete(L) +String " has incomplete type."))
          ~> UnionDef(_, krlist(L:List), _)
          requires notBool allComplete(L)
          [structural]

     syntax KItem ::= defEnumConstants(Bool, CId, Int, Int, Int, List)

     rule defEnumConstants(Pack::Bool, X::CId, Min::Int, Max::Int, Next::Int, ListItem(EnumItem(E::CId)) L::List)
          => initEnum(E, tv(Next, ut(SetItem(IntegerConstant), int)))
          ~> defEnumConstants(Pack, X, minInt(Min, Next), maxInt(Max, Next), Next +Int 1, L)
          [structural]
     context defEnumConstants(_, _, _, _, _, ListItem(EnumItemInit(_, HOLE:KItem => reval(HOLE))) _) [result(RValue)]
     rule defEnumConstants(Pack::Bool, X::CId, Min::Int, Max::Int, _, ListItem(EnumItemInit(E::CId, R:RValue)) L::List)
          => initEnum(E, R)
          ~> defEnumConstants(Pack, X, minInt(Min, asInt(R)), maxInt(Max, asInt(R)), asInt(R) +Int 1, L)
          [structural]
      // Packed enums attempt to use a smaller type as the alias.
     rule defEnumConstants(true, X::CId, Min::Int, Max::Int, _, .List)
          => addTag(X, enumAlias(firstSuitableType(Min, Max, allEnumAliases)))
          [structural]
     rule defEnumConstants(false, X::CId, _, _, _, .List)
          => addTag(X, enumAlias(cfg:enumAlias))
          [structural]

     // Defaults to int (the largest allowed enum type alias).
     syntax SimpleType ::= firstSuitableType(Int, Int, List) [function]
     rule firstSuitableType(Min::Int, Max::Int, ListItem(T::SimpleType) _) => T
          requires Min >=Int min(utype(T)) andBool Max <=Int max(utype(T))
     rule firstSuitableType(_, _, .List) => int
     rule firstSuitableType(_, _, (ListItem(_) => .List) _) [owise]

     syntax List ::= "allEnumAliases" [function]
     rule allEnumAliases
          => ListItem(signed-char)
             ListItem(unsigned-char)
             ListItem(short-int)
             ListItem(unsigned-short-int)
             ListItem(int)

     syntax Int ::= asInt(RValue) [function]
     rule asInt(R::RValue) => value(R)
          requires isInt(value(R))
     // In this case, the configuration should be about to get stuck, so it
     // doesn't matter.
     rule asInt(_) => 0 [owise]

     syntax KItem ::= initEnum(CId, RValue)
     rule initEnum(X:CId, tv(Value:Int, T:IntegerUType)) => addEnum(X, Value)
          requires IntegerConstant in getModifiers(T)
     rule (.K => CV("CDE1", "Enum initializer not an integer constant expression."))
          ~> initEnum(_, R:RValue)
          requires isHold(R) orBool notBool isIntegerType(type(R))
               orBool notBool IntegerConstant in getModifiers(utype(R))

     syntax Bool ::= hasNamedField(List) [function]
     rule hasNamedField(ListItem(typedDeclaration(_, F::CId)) _) => true
          requires notBool isNoName(F)
     rule hasNamedField(ListItem(typedDeclaration(T::Type, _:NoName)) L:List)
          => hasNamedField(L)
          requires notBool isStructOrUnionType(T)
     rule hasNamedField(ListItem(typedDeclaration(T:StructOrUnionType, _:NoName)) L:List)
          => hasNamedField(getFields(getFieldInfo(T)) L)
     rule hasNamedField(.List) => false

     syntax List ::= numberUnnamed(List) [function]
                   | numberUnnamed(Int, List) [function, klabel(numberUnnamed2)]
     rule numberUnnamed(Fs::List) => numberUnnamed(0, Fs)
     rule numberUnnamed(N::Int, ListItem(typedDeclaration(T::Type, _:NoName)) Fs::List)
          => ListItem(typedDeclaration(T, #NoName(N))) numberUnnamed(N +Int 1, Fs)
     rule numberUnnamed(N::Int, ListItem(typedDeclaration(T::Type, F::CId)) Fs::List)
          => ListItem(typedDeclaration(T, F)) numberUnnamed(N +Int 1, Fs)
          requires notBool isNoName(F)
     rule numberUnnamed(_, .List) => .List

     rule makeStructFieldInfo(Pack::Bool, Fs::List)
          => makeStructFieldInfo'(Pack, Fs, 0, .Map, .Map, .List)

     syntax FieldInfo ::= "makeStructFieldInfo'" "(" Bool "," List "," Int "," Map ","  Map "," List ")"
                         [function]

     rule makeStructFieldInfo'(Pack::Bool,
               ListItem(typedDeclaration(T::Type, Field::CId)) L::List,
               V::Int,
               Types::Map,
               Offsets::Map,
               NL::List)
          => makeStructFieldInfo'(Pack,
               L,
               pad(V, T) +Int bitSizeofType(T),
               Types[Field <- T],
               Offsets[Field <- pad(V, T)],
               NL ListItem(typedDeclaration(T, Field)))
     rule makeStructFieldInfo'(true, .List, V::Int, Types::Map, Offsets::Map, NL::List)
          => fieldInfo(NL, padTo(V, 1),
               Types, Offsets,
               computePaddingOffsets(NL, padTo(V, 1), Types, Offsets, 0))
     rule makeStructFieldInfo'(false, .List, V::Int, Types::Map, Offsets::Map, NL::List)
          => fieldInfo(NL, padTo(V, maxByteAlignofList(NL)),
               Types, Offsets,
               computePaddingOffsets(NL, padTo(V, maxByteAlignofList(NL)), Types, Offsets, 0))

     // The padding associated with a particular field precedes it, with
     // possibly some extra padding at the end of the whole struct not
     // associated with any field. This is important for understanding the
     // effect of the gcc et al. padding attr as applied to a particular field.

     syntax Int ::= pad(Int, Type) [function]
     // Non-bitfields are aligned according to their type (if we note that
     // fields tagged with the Packed() attribute have an alignment of 1 byte).
     rule pad(V::Int, T::Type) => padTo(V, byteAlignofType(T))
          requires notBool isBitfieldType(T)
     // Non-packed bitfields that would cross an alignment boundary and
     // zero-length bitfields have an alignment of the bitfield field type.
     rule pad(V::Int, T:BitfieldType) => padTo(V, byteAlignofType(innerType(T)))
          requires notBool (Packed() in getModifiers(T))
               andBool (V +Int bitSizeofType(T)) >Int padTo(V, byteAlignofType(innerType(T)))
     rule pad(V::Int, T:BitfieldType) => padTo(V, byteAlignofType(innerType(T)))
          requires bitSizeofType(T) ==Int 0
     // Packed bitfields and non-packed bitfields that don't cross an alignment
     // boundary have 1-bit alignment (no padding).
     rule pad(V::Int, _) => V [owise]

     // Round up to the nearest multiple of the second arg * cfg:bitsPerByte.
     syntax Int ::= padTo(Int, Int) [function]
     rule padTo(N::Int, A::Int) => N
          requires (N %Int (A *Int cfg:bitsPerByte)) ==Int 0
     rule padTo(N::Int, A::Int)
          => N +Int ((A *Int cfg:bitsPerByte) -Int (N %Int (A *Int cfg:bitsPerByte))) [owise]

     syntax List ::= incompleteToFlexibleArrayMember(List) [function]
     rule incompleteToFlexibleArrayMember(
          ListItem(typedDeclaration(T::Type, X:CId))
          L:List)
          => ListItem(typedDeclaration(T, X)) incompleteToFlexibleArrayMember(L)
          requires isCompleteType(T)
     rule incompleteToFlexibleArrayMember(
          ListItem(typedDeclaration(t(Qs::Quals, Mods::Set, incompleteArrayType(T::Type)), X:CId)))
          => ListItem(typedDeclaration(t(Qs, Mods, flexibleArrayType(T)), X))
     rule incompleteToFlexibleArrayMember(.List) => .List

     syntax Bool ::= structFieldsComplete(List) [function]
     rule structFieldsComplete(L::List ListItem(typedDeclaration(T::Type, _)))
          => allComplete(L) andBool allRigid(L)
               andBool ((isCompleteType(T) andBool isRigidType(T)) orBool isIncompleteArrayType(T))
     rule structFieldsComplete(.List) => true

     syntax Bool ::= allComplete(List) [function]
     rule allComplete(L::List) => all(mapList(L, #klabel(`type`)), #klabel(`isCompleteType`))

     syntax Bool ::= allRigid(List) [function]
     rule allRigid(L::List) => all(mapList(L, #klabel(`type`)), #klabel(`isRigidType`))

     syntax Bool ::= isRigidType(Type) [function]
     rule isRigidType(T::Type) => notBool isFlexibleType(T)

     syntax String ::= firstIncomplete(List) [function]
     rule firstIncomplete(ListItem(typedDeclaration(T::Type, X::CId)) _) => idToString(X)
          requires notBool isCompleteType(T)
     rule firstIncomplete((ListItem(typedDeclaration(T::Type, X::CId)) => .List) _)
          requires isCompleteType(T)
     rule firstIncomplete(.List) => ""

     syntax String ::= firstIncompleteOrFlexible(List) [function]
     rule firstIncompleteOrFlexible(ListItem(typedDeclaration(T::Type, X::CId)) _) => idToString(X)
          requires notBool isCompleteType(T) orBool isFlexibleType(T)
     rule firstIncompleteOrFlexible((ListItem(typedDeclaration(T::Type, X::CId)) => .List) _)
          requires isCompleteType(T) andBool notBool isFlexibleType(T)
     rule firstIncompleteOrFlexible(.List) => ""

     rule makeUnionFieldInfo(Pack::Bool, Fs::List)
          => makeUnionFieldInfo'(Pack, Fs, .Map, .Map, .List)

     syntax FieldInfo ::= "makeUnionFieldInfo'" "(" Bool "," List "," Map ","  Map "," List ")" [function]
     rule makeUnionFieldInfo'(Pack::Bool,
               ListItem(typedDeclaration(T::Type, Field::CId)) L::List,
               Types::Map,
               Offsets::Map,
               NL::List)
          => makeUnionFieldInfo'(Pack, L,
               Types[Field <- T], Offsets[Field <- 0],
               NL ListItem(typedDeclaration(T, Field)))
     rule makeUnionFieldInfo'(true, .List, Types::Map, Offsets::Map, NL::List)
          => fieldInfo(NL, maxByteSizeofList(NL) *Int cfg:bitsPerByte,
               Types, Offsets,
               computePaddingOffsets(NL, maxByteSizeofList(NL) *Int cfg:bitsPerByte, Types, Offsets, 0))
     rule makeUnionFieldInfo'(false, .List, Types::Map, Offsets::Map, NL::List)
          => makePaddedUnionFieldInfo(
               padTo(maxByteSizeofList(NL) *Int cfg:bitsPerByte, maxByteAlignofList(NL)),
               Types, Offsets, NL)

     syntax FieldInfo ::= makePaddedUnionFieldInfo(Int, Map, Map, List) [function]
     rule makePaddedUnionFieldInfo(NBits::Int, Types::Map, Offsets::Map, NL::List)
          => fieldInfo(NL, NBits, Types, Offsets, computePaddingOffsets(NL, NBits, Types, Offsets, 0))

     syntax Set ::= computePaddingOffsets(List, Int, Map, Map, Int) [function]
     rule computePaddingOffsets(L::List, Len::Int, Types::Map, Offsets::Map, Offset::Int)
          => SetItem(Offset) computePaddingOffsets(L, Len, Types, Offsets, Offset +Int cfg:bitsPerByte)
          requires notBool isNonPaddingOffset(Offset, L, Types, Offsets) andBool Offset <Int Len
     rule computePaddingOffsets(L::List, Len::Int, Types::Map, Offsets::Map, (Offset::Int => Offset +Int cfg:bitsPerByte))
          requires isNonPaddingOffset(Offset, L, Types, Offsets) andBool Offset <Int Len
     rule computePaddingOffsets(_, Len::Int, _, _, Offset::Int) => .Set
          requires Offset >=Int Len

     syntax Bool ::= isNonPaddingOffset(Int, List, Map, Map) [function]
     rule isNonPaddingOffset(Offset:Int, ListItem(typedDeclaration(_, F:CId)) Decls:List, Types:Map, Offsets:Map)
          => ({{Offsets[F]}<:K}:>Int <=Int Offset andBool Offset <Int {{Offsets[F]}<:K}:>Int +Int
               bitSizeofType({{Types[F]}<:K}:>Type))
          orBool isNonPaddingOffset(Offset, Decls, Types, Offsets)
     rule isNonPaddingOffset(_, .List, _, _) => false

     syntax KItem ::= addTag(CId, TagInfo)
     rule <k> addTag(S:CId, fieldInfo(Fs:List, NBits:Int, Ts:Map, Offs:Map, PaddingOffs:Set))
               // Elide function parameter names in struct types.
               => addGlobalTag(S, fieldInfo(elideList(Fs), NBits, elideMap(Ts), Offs, PaddingOffs))
          ...</k>
          <curr-scope> fileScope </curr-scope>
          [structural]
     rule <k> addTag(S:CId, enumAlias(T::SimpleType))
               => addGlobalTag(S, enumAlias(T))
          ...</k>
          <curr-scope> fileScope </curr-scope>
          [structural]
     rule <k> addTag(S:CId, fieldInfo(Fs:List, NBits:Int, Ts:Map, Offs:Map, PaddingOffs:Set))
               => addLocalTag(S, fieldInfo(elideList(Fs), NBits, elideMap(Ts), Offs, PaddingOffs))
          ...</k>
          <curr-scope> Scope:Scope </curr-scope>
          requires isFileScope(Scope) =/=K true
          [structural]
     rule <k> addTag(S:CId, enumAlias(T::SimpleType))
               => addLocalTag(S, enumAlias(T))
          ...</k>
          <curr-scope> Scope:Scope </curr-scope>
          requires isFileScope(Scope) =/=K true
          [structural]

     rule <k> addLocalTag(_, _) ...</k>
          <curr-tu> Tu:String </curr-tu>
          <tags> S:Map => S[Tu <- .Map] </tags>
          requires notBool (Tu in_keys(S))

     rule <k> addLocalTag(X:CId, Info::TagInfo) => .K ...</k>
          <tags>... Tu |-> (Structs:Map => Structs[tag(X, Tu, BlockNum) <- Info]) ...</tags>
          <curr-tu> Tu:String </curr-tu>
          <curr-scope> blockScope(_, BlockNum:Int) </curr-scope>
          requires notBool (tag(X, Tu, global) in_keys(Structs))
               andBool notBool (tag(X, Tu, BlockNum) in_keys(Structs))
          [structural]
     rule <k> (.K => CV("TDG15", "Redefinition of a struct, union, or enum: "
               +String idToString(X)))
               ~> addLocalTag(X:CId, _)
          ...</k>
          <curr-tu> Tu:String </curr-tu>
          <tags>... Tu |-> Structs:Map ...</tags>
          <curr-scope> blockScope(_, BlockNum:Int) </curr-scope>
          requires (tag(X, Tu, global) in_keys(Structs))
               orBool (tag(X, Tu, BlockNum) in_keys(Structs))
          [structural]
endmodule

