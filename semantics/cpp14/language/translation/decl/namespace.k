module CPP-DECL-NAMESPACE
     imports C-CONFIGURATION
     imports K-EQUAL
     imports COMPAT-SYNTAX
     imports CPP-ABSTRACT-SYNTAX
     imports CPP-DYNAMIC-SYNTAX
     imports CPP-ENV-SYNTAX
     imports CPP-SYNTAX
     imports CPP-TRANSLATION-INIT-SYNTAX
     imports CPP-TRANSLATION-NAME-SYNTAX

     syntax Decl ::= NamespaceNameDecl(Expr, Bool, List) [strict(1)]
                   | NamespaceNameAliasDecl(CId, Expr) [strict(2)]
                   | UsingNameDirective(Expr) [strict(1)]

     rule <k> NamespaceDecl(X::CId, IsInline::Bool, Decls::List) => NamespaceNameDecl(nameLookupInNamespace(X, N, NoTag(), defaultMask), IsInline, Decls) ...</k>
          <curr-scope> namespaceScope(N::Namespace) </curr-scope>
          requires X =/=K #NoName

     rule <k> NamespaceNameDecl(nsRef(N::Namespace), false, Decls::List)
              => setScope(namespaceScope(N))
              ~> listToK(Decls)
              ~> setScope(OldScope)
          ...</k>
          <curr-scope> OldScope:NamespaceScope </curr-scope>

     rule <k> (.K => addInlineNamespace(N, N) ~> addUsingDirective(N))
              ~> NamespaceNameDecl(nsRef(N::Namespace), (true => false), _)
          ...</k>
          <curr-tu> Tu::String </curr-tu>
          <tu-id> Tu </tu-id>
          <ns-id> N </ns-id>
          <is-inline> _ => true </is-inline>

     rule <k> (.K => makeNs(N :: Namespace(X))) 
              ~> NamespaceNameDecl((notFound(X::CId) => nsRef(N :: Namespace(X))), _, _)
          ...</k>
          <curr-scope> namespaceScope(N::Namespace) </curr-scope>
          <curr-tu> Tu::String </curr-tu>
          <tu-id> Tu </tu-id>
          <ns-id> N </ns-id>
          <nested-namespaces> Env::Map => Env[X <- N :: Namespace(X)] </nested-namespaces>

     rule NamespaceAliasDecl(X::CId, Y::CId, NoNNS()) => NamespaceNameAliasDecl(X, nameLookup(Y, NoTag(), namespaceMask))
     rule NamespaceAliasDecl(X::CId, Y::CId, N::NNS) => NamespaceNameAliasDecl(X, qualifiedNameLookup(Y, N, namespaceMask))
          requires N =/=K NoNNS()

     rule <k> NamespaceNameAliasDecl(X::CId, nsRef(N::Namespace)) => .K ...</k>
          <curr-scope> namespaceScope(M::Namespace) </curr-scope>
          <curr-tu> Tu::String </curr-tu>
          <tu-id> Tu </tu-id>
          <ns-id> M </ns-id>
          <nested-namespaces> Env::Map => Env[X <- N] </nested-namespaces>

     syntax KItem ::= addInlineNamespace(Namespace, Namespace)
                    | addUsingDirective(Namespace)
     // the global namespace cannot be inline, because it's implicitly declared
     rule <k> addInlineNamespace((Enclosing::Namespace :: _) => Enclosing, N::Namespace) ...</k>
          <curr-tu> Tu::String </curr-tu>
          <tu-id> Tu </tu-id>
          <ns-id> Enclosing </ns-id>
          <inline-namespaces>... .Set => SetItem(N) ...</inline-namespaces>
          <is-inline> true </is-inline>
     rule <k> addInlineNamespace(Enclosing::Namespace :: _, N::Namespace) => .K ...</k>
          <curr-tu> Tu::String </curr-tu>
          <tu-id> Tu </tu-id>
          <ns-id> Enclosing </ns-id>
          <inline-namespaces>... .Set => SetItem(N) ...</inline-namespaces>
          <is-inline> false </is-inline>

     // transitivity is handled in expr/name.k because if namespace A uses namespace B and namespace B uses namespace C, and namespace C is later redefined to use namespace D, then namespaces A and B need to use namespace D. If we tried to handle it here, then we would
     // need to track some kind of "used-by".
     rule <k> addUsingDirective(N::Namespace) => .K ...</k>
          <curr-scope> namespaceScope(Enclosing::Namespace) </curr-scope>
          <curr-tu> Tu::String </curr-tu>
          <tu-id> Tu </tu-id>
          <ns-id> Enclosing </ns-id>
          <nusing-namespaces>... .Set => SetItem(N) ...</nusing-namespaces>

     rule UsingDirective(X::CId, NoNNS()) => UsingNameDirective(nameLookup(X, NoTag(), namespaceMask))
     rule UsingDirective(X::CId, N::NNS) => UsingNameDirective(qualifiedNameLookup(X, N, namespaceMask))
          requires N =/=K NoNNS()
     rule <k> UsingNameDirective(nsRef(N::Namespace)) => .K ...</k>
          <curr-scope> namespaceScope(Enclosing::Namespace) </curr-scope>
          <curr-tu> Tu::String </curr-tu>
          <tu-id> Tu </tu-id>
          <ns-id> Enclosing </ns-id>
          <nusing-namespaces>... .Set => SetItem(N) ...</nusing-namespaces>
     rule <k> UsingNameDirective(nsRef(N::Namespace)) => .K ...</k>
          <curr-scope> blockScope(...) </curr-scope>
          <using-namespaces>... .Set => SetItem(N) ...</using-namespaces>

endmodule
