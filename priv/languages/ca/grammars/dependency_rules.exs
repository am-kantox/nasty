%{
  # Catalan Universal Dependencies Relations
  # Based on UD v2 standard with Catalan-specific patterns

  # Core argument relations
  core_arguments: [
    # Subject (nominal subject)
    # Example: "El gat dorm" → gat is nsubj of dorm
    {:nsubj, [:noun, :pron, :propn], :verb},

    # Direct object
    # Example: "Menja pomes" → pomes is obj of Menja
    {:obj, :verb, [:noun, :pron, :propn]},

    # Indirect object
    # Example: "Dono el llibre a Maria" → Maria is iobj
    {:iobj, :verb, :np}
  ],

  # Non-core dependents
  non_core_dependents: [
    # Oblique nominal (prepositional complement)
    # Example: "Va a Barcelona" → Barcelona is obl of Va
    {:obl, :verb, :pp},

    # Adverbial modifier
    # Example: "Corre ràpidament" → ràpidament is advmod of Corre
    {:advmod, :verb, :adv},

    # Discourse element
    {:discourse, :any, :intj}
  ],

  # Nominal dependents
  nominal_dependents: [
    # Determiner
    # Example: "el gat" → el is det of gat
    {:det, :noun, :det},

    # Adjectival modifier
    # Example: "casa gran" → gran is amod of casa
    {:amod, :noun, :adj},

    # Nominal modifier (apposition)
    # Example: "Barcelona, capital de Catalunya" → capital is nmod
    {:nmod, :noun, :noun},

    # Prepositional modifier
    # Example: "llibre de Maria" → de Maria is nmod of llibre
    {:nmod, :noun, :pp}
  ],

  # Clausal dependents
  clausal_dependents: [
    # Clausal complement
    {:ccomp, :verb, :clause},

    # Adverbial clause modifier
    {:advcl, :verb, :clause},

    # Relative clause
    {:acl, :noun, :relative_clause}
  ],

  # Function word relations
  function_words: [
    # Copula (ser, estar)
    {:cop, [:noun, :adj], :aux},

    # Auxiliary
    {:aux, :verb, :aux},

    # Case marker (preposition)
    {:case, :noun, :adp},

    # Marker (subordinating conjunction)
    {:mark, :verb, :sconj}
  ],

  # Coordination
  coordination: [
    # Coordination relation
    {:conj, :any, :any},

    # Coordinating conjunction
    {:cc, :any, :cconj}
  ],

  # Special relations
  special: [
    # Root of sentence
    {:root, :sentence, :verb},

    # Punctuation
    {:punct, :any, :punct}
  ],

  # Catalan-specific patterns
  catalan_specific: [
    # Clitic pronouns attach to verb
    # Example: "Dona-li el llibre" → li is iobj:clit
    {:iobj_clit, :verb, :pron},

    # Pro-drop: implicit subject
    {:nsubj_implied, :verb, :null}
  ]
}
