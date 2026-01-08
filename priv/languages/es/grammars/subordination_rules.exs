%{
  # Spanish Subordination Grammar Rules
  # Based on Spanish subordinating conjunctions and subordinate clause patterns

  # Subordinating Conjunctions (SCONJ)
  # Spanish subordinators mark dependent clauses
  subordinating_conjunctions: [
    # Temporal (time)
    %{
      conjunction: "cuando",
      type: :temporal,
      meaning: "when",
      example_es: "Vine cuando llegaste",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "mientras",
      type: :temporal,
      meaning: "while",
      example_es: "Estudia mientras yo cocino",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "antes de que",
      type: :temporal,
      meaning: "before",
      example_es: "Llegó antes de que empezara",
      subordinate_type: :adverbial,
      note: "Multi-word subordinator"
    },
    %{
      conjunction: "después de que",
      type: :temporal,
      meaning: "after",
      example_es: "Salió después de que terminó",
      subordinate_type: :adverbial,
      note: "Multi-word subordinator"
    },
    %{
      conjunction: "hasta que",
      type: :temporal,
      meaning: "until",
      example_es: "Esperó hasta que llegaron",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "desde que",
      type: :temporal,
      meaning: "since",
      example_es: "Ha cambiado desde que se fue",
      subordinate_type: :adverbial
    },

    # Causal (reason/cause)
    %{
      conjunction: "porque",
      type: :causal,
      meaning: "because",
      example_es: "Vino porque lo invitaron",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "como",
      type: :causal,
      meaning: "since/as",
      example_es: "Como estaba cansado, se durmió",
      subordinate_type: :adverbial,
      note: "Causal 'como' appears clause-initially"
    },
    %{
      conjunction: "ya que",
      type: :causal,
      meaning: "since",
      example_es: "No vino ya que estaba enfermo",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "puesto que",
      type: :causal,
      meaning: "since/given that",
      example_es: "Lo hizo puesto que era necesario",
      subordinate_type: :adverbial
    },

    # Conditional
    %{
      conjunction: "si",
      type: :conditional,
      meaning: "if",
      example_es: "Si llueve, no vamos",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "como",
      type: :conditional,
      meaning: "if (warning)",
      example_es: "Como no vengas, me voy",
      subordinate_type: :adverbial,
      note: "Conditional 'como' in warnings"
    },
    %{
      conjunction: "a menos que",
      type: :conditional,
      meaning: "unless",
      example_es: "Iré a menos que llueva",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "con tal de que",
      type: :conditional,
      meaning: "provided that",
      example_es: "Acepto con tal de que me paguen",
      subordinate_type: :adverbial
    },

    # Concessive (contrast/concession)
    %{
      conjunction: "aunque",
      type: :concessive,
      meaning: "although/even though",
      example_es: "Vino aunque estaba cansado",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "a pesar de que",
      type: :concessive,
      meaning: "despite/in spite of",
      example_es: "Lo hizo a pesar de que era difícil",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "por más que",
      type: :concessive,
      meaning: "however much/no matter how much",
      example_es: "Por más que intentes, no funcionará",
      subordinate_type: :adverbial
    },

    # Purposive (purpose/goal)
    %{
      conjunction: "para que",
      type: :purposive,
      meaning: "so that/in order that",
      example_es: "Lo hice para que entendieras",
      subordinate_type: :adverbial
    },
    %{
      conjunction: "a fin de que",
      type: :purposive,
      meaning: "in order that",
      example_es: "Estudia a fin de que aprenda",
      subordinate_type: :adverbial
    },

    # Result/consecutive
    %{
      conjunction: "así que",
      type: :result,
      meaning: "so/therefore",
      example_es: "Estaba cansado, así que se durmió",
      subordinate_type: :adverbial,
      note: "Can be CCONJ or SCONJ depending on analysis"
    },
    %{
      conjunction: "de modo que",
      type: :result,
      meaning: "so that/in such a way that",
      example_es: "Lo explicó de modo que todos entendieron",
      subordinate_type: :adverbial
    },

    # Manner (how)
    %{
      conjunction: "como",
      type: :manner,
      meaning: "how/as",
      example_es: "Lo hizo como le dijeron",
      subordinate_type: :adverbial,
      note: "'Como' has multiple meanings based on context"
    },
    %{
      conjunction: "según",
      type: :manner,
      meaning: "according to/as",
      example_es: "Lo hice según me indicaste",
      subordinate_type: :adverbial
    },

    # Complementizer (that)
    %{
      conjunction: "que",
      type: :complementizer,
      meaning: "that",
      example_es: "Dijo que vendría",
      subordinate_type: :nominal,
      note: "Introduces clausal complements (ccomp)"
    }
  ],

  # Relative Markers
  # Words that introduce relative clauses in Spanish
  relative_markers: [
    # Relative pronouns
    %{
      marker: "que",
      type: :relative_pronoun,
      meaning: "that/which/who",
      example_es: "el libro que leí",
      note: "Most common Spanish relative pronoun"
    },
    %{
      marker: "quien",
      type: :relative_pronoun,
      meaning: "who/whom (singular)",
      example_es: "la persona quien vino",
      note: "Refers to people"
    },
    %{
      marker: "quienes",
      type: :relative_pronoun,
      meaning: "who/whom (plural)",
      example_es: "las personas quienes vinieron",
      note: "Plural of 'quien'"
    },
    %{
      marker: "cual",
      type: :relative_pronoun,
      meaning: "which (singular)",
      example_es: "el libro el cual leí",
      note: "More formal than 'que'"
    },
    %{
      marker: "cuales",
      type: :relative_pronoun,
      meaning: "which (plural)",
      example_es: "los libros los cuales leí",
      note: "Plural of 'cual'"
    },
    %{
      marker: "cuyo",
      type: :relative_pronoun,
      meaning: "whose (masc. sing.)",
      example_es: "el hombre cuyo hijo vino",
      note: "Possessive relative, agrees in gender/number"
    },
    %{
      marker: "cuya",
      type: :relative_pronoun,
      meaning: "whose (fem. sing.)",
      example_es: "la mujer cuya hija vino",
      note: "Feminine form"
    },
    %{
      marker: "cuyos",
      type: :relative_pronoun,
      meaning: "whose (masc. pl.)",
      example_es: "los hombres cuyos hijos vinieron",
      note: "Masculine plural"
    },
    %{
      marker: "cuyas",
      type: :relative_pronoun,
      meaning: "whose (fem. pl.)",
      example_es: "las mujeres cuyas hijas vinieron",
      note: "Feminine plural"
    },

    # Relative adverbs
    %{
      marker: "donde",
      type: :relative_adverb,
      meaning: "where",
      example_es: "la casa donde vivo",
      note: "Refers to place"
    },
    %{
      marker: "cuando",
      type: :relative_adverb,
      meaning: "when",
      example_es: "el día cuando llegaste",
      note: "Refers to time"
    },
    %{
      marker: "como",
      type: :relative_adverb,
      meaning: "how",
      example_es: "la manera como lo hizo",
      note: "Refers to manner"
    }
  ],

  # Subordinate Clause Types
  subordinate_clause_types: [
    # Adverbial clauses
    # Modify verbs, expressing time, cause, condition, etc.
    %{
      type: :adverbial,
      function: "Modifies verb or clause",
      introduced_by: "subordinating conjunction (SCONJ)",
      dependency_relation: :advcl,
      examples: [
        "Vine cuando llegaste → advcl(Vine, llegaste)",
        "No vino porque estaba enfermo → advcl(vino, estaba)"
      ],
      subtypes: [:temporal, :causal, :conditional, :concessive, :purposive, :result, :manner]
    },

    # Relative clauses
    # Modify nouns
    %{
      type: :relative,
      function: "Modifies noun",
      introduced_by: "relative pronoun/adverb",
      dependency_relation: :acl,
      examples: [
        "el libro que leí → acl(libro, leí)",
        "la casa donde vivo → acl(casa, vivo)"
      ],
      note: "Also called 'adjectival clauses'"
    },

    # Nominal clauses (complement clauses)
    # Function as subject or object
    %{
      type: :nominal,
      function: "Acts as noun (subject/object)",
      introduced_by: "complementizer 'que'",
      dependency_relation: :ccomp,
      examples: [
        "Dijo que vendría → ccomp(Dijo, vendría)",
        "Es importante que estudies → ccomp(importante, estudies)"
      ],
      note: "Also called 'complement clauses'"
    }
  ],

  # Subordination Patterns
  subordination_patterns: [
    # Fronted adverbial clause
    # Pattern: SCONJ Clause, MainClause
    %{
      pattern: :fronted_adverbial,
      structure: "SCONJ SubordClause , MainClause",
      example_es: "Cuando llegaste, yo salí",
      note: "Subordinate clause before main clause, comma typical"
    },

    # Final adverbial clause
    # Pattern: MainClause SCONJ Clause
    %{
      pattern: :final_adverbial,
      structure: "MainClause SCONJ SubordClause",
      example_es: "Yo salí cuando llegaste",
      note: "Subordinate clause after main clause, no comma"
    },

    # Relative clause attached to noun
    # Pattern: NP RelPron Clause
    %{
      pattern: :relative_clause,
      structure: "NP RelMarker Clause",
      example_es: "el libro que leí",
      note: "Immediately follows modified noun"
    },

    # Nominal clause as object
    # Pattern: Verb que Clause
    %{
      pattern: :nominal_complement,
      structure: "Verb que Clause",
      example_es: "Dijo que vendría",
      note: "Complement of verb"
    }
  ],

  # Detection Rules
  # How to identify subordination in token sequence
  detection_rules: [
    # Look for subordinating conjunction (SCONJ)
    %{
      rule: :find_sconj,
      description: "Scan for SCONJ POS tag or known subordinator",
      markers: ["que", "porque", "cuando", "si", "aunque", "mientras", "como", "según"]
    },

    # Look for relative pronouns/adverbs after noun
    %{
      rule: :find_relative_marker,
      description: "Detect relative marker following noun",
      markers: ["que", "quien", "quienes", "cual", "cuales", "cuyo", "donde", "cuando", "como"]
    },

    # Identify clause boundaries
    %{
      rule: :identify_clause_boundary,
      description: "Find where subordinate clause starts and ends",
      note: "Subordinate clause extends to next major punctuation or clause boundary"
    }
  ],

  # Parsing Strategy (Sentence Level)
  parsing_strategy_sentence: [
    # Step 1: Check for initial subordinator
    %{
      step: 1,
      action: "Check if sentence starts with SCONJ",
      details: "If yes, parse as fronted subordinate clause + main clause"
    },

    # Step 2: Find verb positions
    %{
      step: 2,
      action: "Locate all verbs in sentence",
      details: "Multiple verbs suggest multiple clauses"
    },

    # Step 3: Identify subordination points
    %{
      step: 3,
      action: "Find SCONJ or relative markers",
      details: "These mark boundaries between clauses"
    },

    # Step 4: Parse main clause
    %{
      step: 4,
      action: "Parse independent/main clause first",
      details: "Subject + predicate of main clause"
    },

    # Step 5: Parse subordinate clause
    %{
      step: 5,
      action: "Parse dependent/subordinate clause",
      details: "Parse as separate clause, link to main clause via dependency"
    },

    # Step 6: Establish dependency relations
    %{
      step: 6,
      action: "Create advcl, acl, or ccomp relations",
      details: "Link subordinate clause to appropriate head in main clause"
    }
  ],

  # Parsing Strategy (Phrase Level - for relative clauses)
  parsing_strategy_phrase: [
    # Step 1: Parse noun phrase up to relative marker
    %{
      step: 1,
      action: "Parse NP head and pre-modifiers",
      details: "Det? Adj* Noun"
    },

    # Step 2: Detect relative marker
    %{
      step: 2,
      action: "Check if next token is relative pronoun/adverb",
      details: "que, quien, donde, etc."
    },

    # Step 3: Parse relative clause
    %{
      step: 3,
      action: "Parse clause following relative marker",
      details: "Usually VP or full clause"
    },

    # Step 4: Attach to NP
    %{
      step: 4,
      action: "Add relative clause as post-modifier of NP",
      details: "RelativeClause struct attached to NP.post_modifiers"
    }
  ],

  # Dependency Relations in Subordination
  dependency_relations: [
    # mark: Subordinating marker
    %{
      relation: :mark,
      description: "Links subordinator to subordinate clause verb",
      direction: "subordinate verb ← subordinator",
      example_es: "Dijo que vendría → mark(vendría, que)"
    },

    # advcl: Adverbial clause modifier
    %{
      relation: :advcl,
      description: "Links adverbial clause to modified verb",
      direction: "main verb ← subordinate verb",
      example_es: "Vine cuando llegaste → advcl(Vine, llegaste)"
    },

    # acl: Clausal modifier of noun (relative clause)
    %{
      relation: :acl,
      description: "Links relative clause to modified noun",
      direction: "noun ← relative clause verb",
      example_es: "el libro que leí → acl(libro, leí)"
    },

    # ccomp: Clausal complement
    %{
      relation: :ccomp,
      description: "Links complement clause to main verb",
      direction: "main verb ← complement verb",
      example_es: "Dijo que vendría → ccomp(Dijo, vendría)"
    }
  ],

  # Semantic Roles
  # Semantic function of subordinate clauses
  semantic_roles: %{
    temporal: "When the action occurs",
    causal: "Why the action occurs",
    conditional: "Under what condition the action occurs",
    concessive: "Despite what the action occurs",
    purposive: "For what purpose the action occurs",
    result: "What result the action produces",
    manner: "How the action occurs",
    complement: "What is said/thought/believed"
  },

  # Special Cases in Spanish Subordination
  special_cases: [
    # Ambiguous 'que'
    # Can be complementizer, relative pronoun, or part of multi-word subordinator
    %{
      type: :ambiguous_que,
      word: "que",
      possibilities: [
        "Complementizer (nominal clause): Dijo que vendría",
        "Relative pronoun (relative clause): el libro que leí",
        "Part of subordinator: antes de que, después de que, para que"
      ],
      disambiguation: "Check preceding context: verb → complementizer, noun → relative, preposition → part of subordinator"
    },

    # Ambiguous 'como'
    # Can be manner, causal, conditional, or relative
    %{
      type: :ambiguous_como,
      word: "como",
      possibilities: [
        "Causal (clause-initial): Como estaba cansado, se durmió",
        "Manner: Lo hizo como le dijeron",
        "Conditional (warning): Como no vengas, me voy",
        "Relative adverb: la manera como lo hizo"
      ],
      disambiguation: "Position and context determine meaning"
    },

    # Subjunctive mood requirement
    # Many subordinators require subjunctive in subordinate clause
    %{
      type: :subjunctive_requirement,
      subordinators: ["aunque", "para que", "antes de que", "sin que", "con tal de que", "a menos que"],
      example_es: "Para que entiendas (not 'entiendes')",
      note: "Morphological, not syntactic. Parser doesn't check mood."
    },

    # Personal 'a' in relative clauses
    # Preposition 'a' before relative pronoun referring to person
    %{
      type: :personal_a_relative,
      pattern: "a quien",
      example_es: "la persona a quien vi",
      note: "Preposition marked with :case relation"
    }
  ],

  # Multi-word Subordinators
  # Subordinating conjunctions consisting of multiple words
  multi_word_subordinators: [
    "antes de que", "después de que", "a pesar de que", "a fin de que",
    "con tal de que", "a menos que", "por más que", "de modo que",
    "ya que", "puesto que", "así que"
  ],

  # Notes on Spanish Subordination
  notes: %{
    que_frequency: "'que' is the most frequent subordinator in Spanish",
    subjunctive: "Many subordinators trigger subjunctive mood in subordinate clause",
    indicative_vs_subjunctive: "Some subordinators (como 'aunque') can take indicative or subjunctive with meaning difference",
    clause_order: "Subordinate clause can come before or after main clause",
    comma_usage: "Comma typical when subordinate clause precedes main clause",
    relative_clause_position: "Relative clauses immediately follow modified noun (no separation)",
    que_deletion: "Unlike English, 'que' cannot be deleted in relative clauses"
  }
}
