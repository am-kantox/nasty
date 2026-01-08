# English Coordination Grammar Rules
#
# This file defines rules for coordinating conjunctions and how clauses
# are coordinated in compound sentences.
#
# Reference: Coordination in English grammar

%{
  # Coordinating conjunctions
  coordinating_conjunctions: [
    %{
      word: "and",
      type: :additive,
      description: "Adds information",
      examples: ["cats and dogs", "I ran and she walked"],
      pos_tag: :cconj
    },
    %{
      word: "or",
      type: :alternative,
      description: "Presents alternatives",
      examples: ["cats or dogs", "run or walk"],
      pos_tag: :cconj
    },
    %{
      word: "but",
      type: :adversative,
      description: "Contrasts information",
      examples: ["small but strong", "I tried but failed"],
      pos_tag: :cconj
    },
    %{
      word: "yet",
      type: :adversative,
      description: "Introduces contrast",
      examples: ["tired yet happy", "simple yet effective"],
      pos_tag: :cconj
    },
    %{
      word: "so",
      type: :causal,
      description: "Indicates result or consequence",
      examples: ["hungry so I ate", "tired so I slept"],
      pos_tag: :cconj
    },
    %{
      word: "nor",
      type: :negative_alternative,
      description: "Neither...nor construction",
      examples: ["neither cats nor dogs", "not here nor there"],
      pos_tag: :cconj
    },
    %{
      word: "for",
      type: :explanatory,
      description: "Provides reason (formal)",
      examples: ["stayed home for I was sick"],
      pos_tag: :cconj,
      note: "Rare in modern usage"
    }
  ],

  # Coordination patterns
  coordination_patterns: [
    %{
      pattern: "NP and NP",
      description: "Noun phrase coordination",
      examples: ["dogs and cats", "the man and the woman", "John and Mary"],
      conjunct_type: :noun_phrase
    },
    %{
      pattern: "VP and VP",
      description: "Verb phrase coordination",
      examples: ["run and jump", "ate pizza and drank soda"],
      conjunct_type: :verb_phrase
    },
    %{
      pattern: "Clause and Clause",
      description: "Clause coordination (compound sentence)",
      examples: ["I ran and she walked", "The dog barked but the cat slept"],
      conjunct_type: :clause,
      creates_compound_sentence: true
    },
    %{
      pattern: "Adj and Adj",
      description: "Adjective coordination",
      examples: ["big and red", "fast and furious"],
      conjunct_type: :adjective
    },
    %{
      pattern: "Adv and Adv",
      description: "Adverb coordination",
      examples: ["quickly and quietly", "here and there"],
      conjunct_type: :adverb
    },
    %{
      pattern: "PP and PP",
      description: "Prepositional phrase coordination",
      examples: ["in the morning and at night", "on the table or under the chair"],
      conjunct_type: :prepositional_phrase
    }
  ],

  # Coordination structure
  coordination_structure: %{
    basic: %{
      pattern: "X conj Y",
      description: "Basic two-way coordination",
      examples: ["cats and dogs"],
      min_conjuncts: 2,
      max_conjuncts: 2
    },
    
    multiple: %{
      pattern: "X, Y, and Z",
      description: "Multiple coordination with serial comma",
      examples: ["cats, dogs, and birds", "red, white, and blue"],
      min_conjuncts: 3,
      uses_comma: true,
      conjunction_position: :before_last
    },
    
    multiple_no_comma: %{
      pattern: "X and Y and Z",
      description: "Multiple coordination without commas",
      examples: ["cats and dogs and birds"],
      min_conjuncts: 3,
      uses_comma: false,
      note: "Less common, sometimes emphatic"
    }
  },

  # Coordination detection rules
  detection_rules: %{
    conjunction_position: %{
      description: "Find coordinating conjunction between two constituents",
      algorithm: "Scan for CCONJ token, split tokens at that position",
      examples: [
        "I ran [CCONJ:and] she walked",
        "cats [CCONJ:or] dogs"
      ]
    },
    
    conjunct_matching: %{
      description: "Ensure conjuncts are same type",
      rule: "Both sides of conjunction must be same phrase type",
      examples: [
        "NP [and] NP ✓",
        "NP [and] VP ✗",
        "Clause [but] Clause ✓"
      ]
    },
    
    comma_handling: %{
      description: "Handle commas in multiple coordination",
      rule: "Commas separate conjuncts, final conjunction before last item",
      examples: [
        "A, B, and C → conjuncts: [A, B, C]",
        "A and B and C → conjuncts: [A, B, C]"
      ]
    }
  },

  # Parsing strategy
  parsing_strategy: %{
    clause_level: %{
      description: "Detect coordination at clause level first",
      steps: [
        "1. Scan for coordinating conjunction (CCONJ)",
        "2. Split tokens at conjunction position",
        "3. Parse left side as clause",
        "4. Parse right side as clause",
        "5. If both succeed, create coordinated structure",
        "6. Otherwise, parse as simple clause"
      ],
      result: "List of clauses or single clause"
    },
    
    phrase_level: %{
      description: "Coordination handled within phrase parsing",
      note: "Currently not implemented - phrases don't detect internal coordination",
      future_enhancement: true
    }
  },

  # Dependency relations
  dependency_relations: %{
    conj: %{
      description: "Links first conjunct to subsequent conjuncts",
      pattern: "first_conjunct → [conj] → second_conjunct",
      examples: ["cats [→conj dogs]", "ran [→conj jumped]"]
    },
    
    cc: %{
      description: "Links conjunction to first conjunct",
      pattern: "first_conjunct → [cc] → conjunction",
      examples: ["cats [→cc and]", "ran [→cc but]"]
    }
  },

  # Special cases
  special_cases: %{
    both_and: %{
      description: "Correlative conjunction 'both...and'",
      examples: ["both cats and dogs", "both here and there"],
      note: "Not currently handled specially"
    },
    
    either_or: %{
      description: "Correlative conjunction 'either...or'",
      examples: ["either cats or dogs", "either this or that"],
      note: "Not currently handled specially"
    },
    
    neither_nor: %{
      description: "Correlative conjunction 'neither...nor'",
      examples: ["neither cats nor dogs", "neither here nor there"],
      note: "Not currently handled specially"
    },
    
    not_only_but_also: %{
      description: "Correlative conjunction 'not only...but also'",
      examples: ["not only smart but also kind"],
      note: "Not currently handled specially"
    }
  }
}
