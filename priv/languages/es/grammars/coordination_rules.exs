%{
  # Spanish Coordination Grammar Rules
  # Based on Spanish coordinating conjunctions and coordination patterns

  # Coordinating Conjunctions (CCONJ)
  # Spanish coordinators link elements of equal syntactic status
  coordinating_conjunctions: [
    # Copulative (additive)
    %{
      conjunction: "y",
      type: :copulative,
      meaning: "and",
      usage: "General additive conjunction",
      example_es: "Juan y María"
    },
    %{
      conjunction: "e",
      type: :copulative,
      meaning: "and",
      usage: "Before words starting with /i/ or /hi/ sound",
      example_es: "padre e hijo",
      note: "Phonetic variant of 'y'"
    },
    %{
      conjunction: "ni",
      type: :copulative,
      meaning: "nor/neither",
      usage: "Negative additive",
      example_es: "ni Juan ni María"
    },

    # Disjunctive (alternative)
    %{
      conjunction: "o",
      type: :disjunctive,
      meaning: "or",
      usage: "General disjunctive conjunction",
      example_es: "café o té"
    },
    %{
      conjunction: "u",
      type: :disjunctive,
      meaning: "or",
      usage: "Before words starting with /o/ or /ho/ sound",
      example_es: "siete u ocho",
      note: "Phonetic variant of 'o'"
    },

    # Adversative (contrast)
    %{
      conjunction: "pero",
      type: :adversative,
      meaning: "but",
      usage: "General adversative conjunction",
      example_es: "pequeño pero fuerte"
    },
    %{
      conjunction: "mas",
      type: :adversative,
      meaning: "but",
      usage: "Formal/literary adversative",
      example_es: "lo intentó mas no pudo",
      note: "Literary variant of 'pero'"
    },
    %{
      conjunction: "sino",
      type: :adversative,
      meaning: "but rather/but instead",
      usage: "Exclusive adversative (after negative)",
      example_es: "no es rojo sino azul",
      note: "Used after negation to introduce alternative"
    }
  ],

  # Coordination Patterns
  # Structures that can be coordinated in Spanish
  coordination_patterns: [
    # Noun phrase coordination
    # Example: "Juan y María", "el gato y el perro"
    %{
      pattern: :np_coordination,
      structure: "NP CCONJ NP",
      pos_sequence: [:noun, :cconj, :noun],
      example_es: "Juan y María",
      note: "Noun phrases of equal status"
    },

    # Verb phrase coordination
    # Example: "come y bebe", "corrió pero cayó"
    %{
      pattern: :vp_coordination,
      structure: "VP CCONJ VP",
      pos_sequence: [:verb, :cconj, :verb],
      example_es: "come y bebe",
      note: "Verb phrases sharing same subject"
    },

    # Clause coordination
    # Example: "Juan come y María bebe"
    %{
      pattern: :clause_coordination,
      structure: "Clause CCONJ Clause",
      example_es: "Juan come y María bebe",
      note: "Independent clauses with equal status"
    },

    # Adjective coordination
    # Example: "grande y fuerte", "rojo, blanco y azul"
    %{
      pattern: :adj_coordination,
      structure: "Adj CCONJ Adj",
      pos_sequence: [:adj, :cconj, :adj],
      example_es: "grande y fuerte",
      note: "Adjectives modifying same noun"
    },

    # Adverb coordination
    # Example: "rápida y cuidadosamente"
    %{
      pattern: :adv_coordination,
      structure: "Adv CCONJ Adv",
      pos_sequence: [:adv, :cconj, :adv],
      example_es: "rápida y cuidadosamente",
      note: "Adverbs modifying same element"
    },

    # Prepositional phrase coordination
    # Example: "en la casa y en el jardín"
    %{
      pattern: :pp_coordination,
      structure: "PP CCONJ PP",
      example_es: "en la casa y en el jardín",
      note: "Prepositional phrases with same function"
    }
  ],

  # Coordination Structure
  # How coordinated elements are organized
  coordination_structure: [
    # Basic two-element coordination
    # Structure: X CCONJ Y
    %{
      type: :basic,
      pattern: "X CCONJ Y",
      example_es: "Juan y María",
      dependencies: [
        "conj(X, Y) - Y is conjunct of X",
        "cc(Y, CCONJ) - CCONJ is coordinator of Y"
      ],
      note: "First element (X) is head of coordination"
    },

    # Multiple coordination with commas
    # Structure: X, Y, CCONJ Z
    %{
      type: :multiple_with_commas,
      pattern: "X, Y, CCONJ Z",
      example_es: "Juan, María y Pedro",
      dependencies: [
        "conj(X, Y) - Y is conjunct of X",
        "conj(X, Z) - Z is conjunct of X",
        "cc(Z, CCONJ) - CCONJ is coordinator of Z",
        "punct(Y, ,) - comma attached to Y"
      ],
      note: "Oxford comma optional in Spanish"
    },

    # Multiple coordination without commas (rare)
    # Structure: X CCONJ Y CCONJ Z
    %{
      type: :multiple_without_commas,
      pattern: "X CCONJ Y CCONJ Z",
      example_es: "ni Juan ni María ni Pedro",
      dependencies: [
        "conj(X, Y) - Y is conjunct of X",
        "conj(X, Z) - Z is conjunct of X",
        "cc(Y, CCONJ1) - first coordinator of Y",
        "cc(Z, CCONJ2) - second coordinator of Z"
      ],
      note: "Common with 'ni...ni...ni' (neither...nor...nor)"
    }
  ],

  # Detection Rules
  # How to identify coordination in a token sequence
  detection_rules: [
    # Look for coordinating conjunction
    %{
      rule: :find_cconj,
      description: "Scan tokens for CCONJ POS tag",
      conjunctions: ["y", "e", "o", "u", "pero", "mas", "sino", "ni"]
    },

    # Check for coordinated elements on both sides
    %{
      rule: :check_parallel_elements,
      description: "Verify elements before and after CCONJ have similar POS or structure",
      note: "Spanish allows coordination of parallel syntactic categories"
    },

    # Handle comma-separated lists
    %{
      rule: :comma_separated_list,
      description: "Detect X, Y, CCONJ Z pattern",
      note: "Comma before final CCONJ is optional in Spanish"
    }
  ],

  # Parsing Strategy
  # How to parse coordinated structures
  parsing_strategy: [
    # Step 1: Identify coordination point
    %{
      step: 1,
      action: "Find CCONJ token in sequence",
      details: "Locate coordinating conjunction(s)"
    },

    # Step 2: Determine coordination boundaries
    %{
      step: 2,
      action: "Find start and end of coordinated elements",
      details: "Split token sequence at CCONJ, handle commas"
    },

    # Step 3: Parse each conjunct
    %{
      step: 3,
      action: "Parse left and right conjuncts independently",
      details: "Use appropriate phrase parser (NP, VP, etc.)"
    },

    # Step 4: Create coordination structure
    %{
      step: 4,
      action: "Build coordinated clause/phrase structure",
      details: "First conjunct is head, subsequent are dependents"
    },

    # Step 5: Establish dependency relations
    %{
      step: 5,
      action: "Create conj and cc dependency relations",
      details: "conj(head, conjunct), cc(conjunct, coordinator)"
    }
  ],

  # Dependency Relations in Coordination
  dependency_relations: [
    # conj: Conjunct relation
    %{
      relation: :conj,
      description: "Links first conjunct (head) to subsequent conjuncts",
      direction: "head → conjunct",
      example_es: "Juan y María → conj(Juan, María)"
    },

    # cc: Coordinating conjunction
    %{
      relation: :cc,
      description: "Links conjunct to its coordinator",
      direction: "conjunct → coordinator",
      example_es: "Juan y María → cc(María, y)"
    }
  ],

  # Special Cases in Spanish Coordination
  special_cases: [
    # Correlative conjunctions
    # Example: "tanto...como", "ni...ni", "o...o"
    %{
      type: :correlative,
      patterns: [
        %{
          pair: ["tanto", "como"],
          meaning: "both...and / as much...as",
          example_es: "tanto Juan como María"
        },
        %{
          pair: ["ni", "ni"],
          meaning: "neither...nor",
          example_es: "ni Juan ni María",
          note: "Very common in Spanish"
        },
        %{
          pair: ["o", "o"],
          meaning: "either...or",
          example_es: "o Juan o María"
        },
        %{
          pair: ["ya", "ya"],
          meaning: "whether...or",
          example_es: "ya llueva ya haga sol"
        }
      ],
      parsing_note: "First element is correlative marker, second is coordinator"
    },

    # Adversative coordination with negation
    # "sino" must follow negative clause
    %{
      type: :sino_coordination,
      conjunction: "sino",
      requirement: "Must follow negative clause",
      example_es: "No es rojo sino azul",
      note: "Sino = but rather/but instead, exclusive alternative"
    },

    # Phonetic variants
    %{
      type: :phonetic_variants,
      variants: [
        %{from: "y", to: "e", context: "Before /i/ or /hi/"},
        %{from: "o", to: "u", context: "Before /o/ or /ho/"}
      ],
      examples: [
        "padre e hijo (not 'y hijo')",
        "siete u ocho (not 'o ocho')"
      ],
      note: "Prevents vowel hiatus"
    }
  ],

  # Semantic Types of Coordination
  semantic_types: %{
    copulative: "Additive/cumulative meaning (y, e, ni)",
    disjunctive: "Alternative/choice meaning (o, u)",
    adversative: "Contrast/opposition meaning (pero, mas, sino)"
  },

  # Notes on Spanish Coordination
  notes: %{
    comma_usage: "Oxford comma (comma before final 'y') is optional and less common in Spanish",
    ni_repetition: "'ni...ni' is more common than single 'ni' in coordination",
    sino_vs_pero: "'sino' requires preceding negation, 'pero' does not",
    phonetic_harmony: "Use 'e' instead of 'y' before /i/, 'u' instead of 'o' before /o/",
    gapping: "Spanish allows verb gapping in coordination: 'Juan come manzanas y María, peras'",
    position: "Coordinators always between conjuncts (no initial position like English 'And,...')"
  }
}
