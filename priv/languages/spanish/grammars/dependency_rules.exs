%{
  # Spanish Dependency Grammar Rules (Universal Dependencies v2)
  # Based on Spanish UD guidelines with pro-drop and flexible word order

  # Core arguments (clause level)
  core_arguments: [
    # Subject (nominal subject)
    # Example: "Juan come" → nsubj(come, Juan)
    # Spanish allows null subjects (pro-drop): "Como" instead of "Yo como"
    %{
      relation: :nsubj,
      description: "Nominal subject",
      direction: :dependent_to_head,
      head_pos: [:verb, :aux],
      dependent_pos: [:noun, :propn, :pron],
      example_es: "El gato duerme → nsubj(duerme, gato)",
      note: "May be null due to pro-drop"
    },

    # Direct object
    # Example: "Juan come manzanas" → obj(come, manzanas)
    %{
      relation: :obj,
      description: "Direct object",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:noun, :propn, :pron],
      example_es: "Leo el libro → obj(Leo, libro)"
    },

    # Indirect object
    # Example: "Doy el libro a Juan" → iobj(Doy, Juan)
    # Often marked with preposition "a"
    %{
      relation: :iobj,
      description: "Indirect object",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:noun, :propn, :pron],
      example_es: "Da el libro a María → iobj(Da, María)"
    },

    # Clausal complement
    # Example: "Dijo que vendría" → ccomp(Dijo, vendría)
    %{
      relation: :ccomp,
      description: "Clausal complement",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:verb],
      example_es: "Dijo que vendría → ccomp(Dijo, vendría)"
    },

    # Open clausal complement (no subject)
    # Example: "Quiere comer" → xcomp(Quiere, comer)
    %{
      relation: :xcomp,
      description: "Open clausal complement",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:verb, :adj],
      example_es: "Quiere comer → xcomp(Quiere, comer)"
    }
  ],

  # Non-core dependents
  non_core_dependents: [
    # Oblique nominal (prepositional object)
    # Example: "Voy a Madrid" → obl(Voy, Madrid)
    %{
      relation: :obl,
      description: "Oblique nominal",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:noun, :propn, :pron],
      example_es: "Va a la tienda → obl(Va, tienda)",
      note: "Prepositional object of verb"
    },

    # Adverbial modifier
    # Example: "Corre rápidamente" → advmod(Corre, rápidamente)
    %{
      relation: :advmod,
      description: "Adverbial modifier",
      direction: :dependent_to_head,
      head_pos: [:verb, :adj, :adv],
      dependent_pos: [:adv],
      example_es: "Corre rápidamente → advmod(Corre, rápidamente)"
    },

    # Discourse marker
    # Example: "Bueno, vamos" → discourse(vamos, Bueno)
    %{
      relation: :discourse,
      description: "Discourse element",
      direction: :dependent_to_head,
      head_pos: [:verb, :adj, :noun],
      dependent_pos: [:intj],
      example_es: "Bueno, vamos → discourse(vamos, Bueno)"
    }
  ],

  # Nominal dependents
  nominal_dependents: [
    # Nominal modifier (PP modifying noun)
    # Example: "el libro de Juan" → nmod(libro, Juan)
    %{
      relation: :nmod,
      description: "Nominal modifier",
      direction: :dependent_to_head,
      head_pos: [:noun, :propn, :pron],
      dependent_pos: [:noun, :propn, :pron],
      example_es: "el libro de Juan → nmod(libro, Juan)",
      note: "Usually introduced by preposition"
    },

    # Adjectival modifier
    # Example: "casa roja" → amod(casa, roja)
    # Spanish: adjectives typically post-nominal
    %{
      relation: :amod,
      description: "Adjectival modifier",
      direction: :dependent_to_head,
      head_pos: [:noun, :propn],
      dependent_pos: [:adj],
      example_es: "casa roja → amod(casa, roja)",
      note: "Post-nominal in Spanish"
    },

    # Numeric modifier
    # Example: "tres libros" → nummod(libros, tres)
    %{
      relation: :nummod,
      description: "Numeric modifier",
      direction: :dependent_to_head,
      head_pos: [:noun],
      dependent_pos: [:num],
      example_es: "tres libros → nummod(libros, tres)"
    },

    # Clausal modifier of noun (relative clause)
    # Example: "el libro que leí" → acl(libro, leí)
    %{
      relation: :acl,
      description: "Clausal modifier of noun",
      direction: :dependent_to_head,
      head_pos: [:noun, :propn],
      dependent_pos: [:verb],
      example_es: "el libro que leí → acl(libro, leí)"
    },

    # Adverbial clause modifier
    # Example: "Vine cuando llegaste" → advcl(Vine, llegaste)
    %{
      relation: :advcl,
      description: "Adverbial clause modifier",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:verb],
      example_es: "Vine cuando llegaste → advcl(Vine, llegaste)"
    },

    # Determiner
    # Example: "el gato" → det(gato, el)
    # Spanish articles: el, la, los, las, un, una, unos, unas
    %{
      relation: :det,
      description: "Determiner",
      direction: :dependent_to_head,
      head_pos: [:noun, :propn],
      dependent_pos: [:det],
      example_es: "el gato → det(gato, el)"
    }
  ],

  # Case marking
  case_marking: [
    # Case marker (preposition)
    # Example: "en la casa" → case(casa, en)
    # Spanish prepositions: a, ante, bajo, con, contra, de, desde, en, entre,
    #                       hacia, hasta, para, por, según, sin, sobre, tras
    %{
      relation: :case,
      description: "Case marking",
      direction: :dependent_to_head,
      head_pos: [:noun, :propn, :pron],
      dependent_pos: [:adp],
      example_es: "en la casa → case(casa, en)"
    }
  ],

  # Function words
  function_words: [
    # Auxiliary
    # Example: "ha comido" → aux(comido, ha)
    # Spanish auxiliaries: haber (he, has, ha, hemos, habéis, han)
    %{
      relation: :aux,
      description: "Auxiliary",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:aux],
      example_es: "ha comido → aux(comido, ha)"
    },

    # Copula
    # Example: "es feliz" → cop(feliz, es)
    # Copulas: ser (es, son), estar (está, están)
    %{
      relation: :cop,
      description: "Copula",
      direction: :dependent_to_head,
      head_pos: [:adj, :noun],
      dependent_pos: [:aux],
      example_es: "es feliz → cop(feliz, es)",
      note: "Ser and estar as copula"
    },

    # Marker (subordinating conjunction)
    # Example: "Dijo que vendría" → mark(vendría, que)
    # Spanish subordinators: que, porque, cuando, si, aunque, mientras, etc.
    %{
      relation: :mark,
      description: "Marker",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:sconj],
      example_es: "Dijo que vendría → mark(vendría, que)"
    }
  ],

  # Coordination
  coordination: [
    # Conjunction
    # Example: "Juan y María" → conj(Juan, María)
    %{
      relation: :conj,
      description: "Conjunct",
      direction: :first_to_second,
      head_pos: [:noun, :verb, :adj, :adv],
      dependent_pos: [:noun, :verb, :adj, :adv],
      example_es: "Juan y María → conj(Juan, María)"
    },

    # Coordinating conjunction
    # Example: "Juan y María" → cc(María, y)
    # Spanish coordinators: y, e, o, u, pero, mas, sino, ni
    %{
      relation: :cc,
      description: "Coordinating conjunction",
      direction: :second_to_coordinator,
      head_pos: [:noun, :verb, :adj, :adv],
      dependent_pos: [:cconj],
      example_es: "Juan y María → cc(María, y)"
    }
  ],

  # Other relations
  other: [
    # Punctuation
    %{
      relation: :punct,
      description: "Punctuation",
      direction: :dependent_to_head,
      head_pos: [:verb, :noun, :adj],
      dependent_pos: [:punct],
      example_es: "Come. → punct(Come, .)"
    },

    # Compound (multi-word proper names)
    # Example: "Pablo García" → flat(Pablo, García)
    %{
      relation: :flat,
      description: "Flat multiword expression",
      direction: :first_to_rest,
      head_pos: [:propn],
      dependent_pos: [:propn],
      example_es: "Pablo García → flat(Pablo, García)",
      note: "For proper names"
    },

    # Fixed multiword expression
    # Example: "a pesar de" (in spite of)
    %{
      relation: :fixed,
      description: "Fixed multiword expression",
      direction: :first_to_rest,
      head_pos: [:adp, :sconj, :adv],
      dependent_pos: [:adp, :noun, :verb],
      example_es: "a pesar de → fixed(a, pesar), fixed(a, de)"
    }
  ],

  # Spanish-specific relations
  spanish_specific: [
    # Reflexive clitic pronoun
    # Example: "se sentó" (sat down) → expl:pv(sentó, se)
    # Clitics: me, te, se, nos, os, se, lo, la, los, las, le, les
    %{
      relation: :"expl:pv",
      description: "Reflexive pronominal verb",
      direction: :dependent_to_head,
      head_pos: [:verb],
      dependent_pos: [:pron],
      example_es: "se sentó → expl:pv(sentó, se)",
      note: "Pronominal verbs in Spanish"
    }
  ],

  # Direction rules
  direction_rules: %{
    dependent_to_head: "Dependent points to head (arrow goes up)",
    head_to_dependent: "Head points to dependent (arrow goes down)",
    first_to_second: "First conjunct points to second (coordination)",
    first_to_rest: "First element points to rest (compounds)",
    second_to_coordinator: "Second conjunct points to coordinator"
  },

  # Extraction priorities (which dependencies to extract first)
  extraction_priorities: [
    # 1. Core arguments (subjects, objects)
    :nsubj,
    :obj,
    :iobj,

    # 2. Function words (determiners, auxiliaries)
    :det,
    :aux,
    :cop,

    # 3. Modifiers
    :amod,
    :nmod,
    :advmod,
    :nummod,

    # 4. Case marking
    :case,

    # 5. Clausal relations
    :acl,
    :advcl,
    :ccomp,
    :xcomp,

    # 6. Coordination
    :conj,
    :cc,

    # 7. Subordination markers
    :mark,

    # 8. Others
    :punct,
    :flat,
    :fixed,
    :"expl:pv"
  ],

  # POS-based heuristics for Spanish
  pos_heuristics: %{
    # Verb is typically the head of a clause
    verb: :clause_head,

    # Noun is head of NP
    noun: :np_head,

    # Preposition takes noun as object
    adp: :takes_noun_object,

    # Auxiliary depends on main verb
    aux: :depends_on_verb,

    # Determiner depends on noun
    det: :depends_on_noun,

    # Adjective modifies noun (usually post-nominal in Spanish)
    adj: :modifies_noun_post,

    # Adverb modifies verb, adj, or adv
    adv: :modifies_verb_adj_adv,

    # Coordinating conjunction between conjuncts
    cconj: :between_conjuncts,

    # Subordinating conjunction marks dependent clause
    sconj: :marks_dependent_clause
  },

  # Special considerations for Spanish
  spanish_notes: %{
    pro_drop: "Spanish allows null subjects. nsubj may be implicit.",
    word_order: "SVO is default, but VSO and VOS are common. Parser must handle flexible order.",
    clitic_pronouns: "Attached to verbs (me, te, se, lo, la, etc.). Use expl:pv for reflexive.",
    personal_a: "Preposition 'a' marks animate direct objects. Still use obj relation, not obl.",
    ser_estar: "Two copulas with different semantics. Both use cop relation.",
    gender_number: "Agreement is morphological, not syntactic. Not reflected in dependencies.",
    leismo_laismo: "Dialectal pronoun variation. Does not affect dependency structure."
  },

  # Extraction order (process phrases in this order)
  extraction_order: [
    # 1. Extract from subject NP (if present)
    :subject_np,

    # 2. Extract from predicate VP
    :predicate_vp,

    # 3. Extract subordinator (if present)
    :subordinator,

    # 4. Link subject to predicate
    :subject_predicate_link,

    # 5. Process coordinated clauses
    :coordination,

    # 6. Process subordinate clauses
    :subordination
  ]
}
