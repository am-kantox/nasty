# English Subordination Grammar Rules
#
# This file defines rules for subordinating conjunctions and how subordinate
# clauses attach to main clauses in complex sentences.
#
# Reference: Subordination in English grammar

%{
  # Subordinating conjunctions
  subordinating_conjunctions: [
    # Time
    %{
      word: "when",
      type: :temporal,
      description: "Indicates time",
      examples: ["I left when she arrived", "Call me when you're ready"],
      pos_tag: :sconj
    },
    %{
      word: "while",
      type: :temporal,
      description: "Indicates simultaneous time",
      examples: ["Read while you wait", "I slept while he worked"],
      pos_tag: :sconj
    },
    %{
      word: "before",
      type: :temporal,
      description: "Indicates prior time",
      examples: ["Leave before it rains", "Think before you speak"],
      pos_tag: :sconj
    },
    %{
      word: "after",
      type: :temporal,
      description: "Indicates subsequent time",
      examples: ["Call me after you arrive", "We left after dinner"],
      pos_tag: :sconj
    },
    %{
      word: "since",
      type: :temporal,
      description: "Indicates time from past to present",
      examples: ["I've lived here since I was born"],
      pos_tag: :sconj
    },
    %{
      word: "until",
      type: :temporal,
      description: "Indicates duration up to a point",
      examples: ["Wait until I return", "Stay until sunset"],
      pos_tag: :sconj
    },
    %{
      word: "as",
      type: :temporal_or_causal,
      description: "Indicates time or cause",
      examples: ["As I walked, I thought", "As you know, I'm busy"],
      pos_tag: :sconj
    },

    # Cause/Reason
    %{
      word: "because",
      type: :causal,
      description: "Indicates reason or cause",
      examples: ["I left because I was tired", "She cried because she was sad"],
      pos_tag: :sconj
    },
    %{
      word: "since",
      type: :causal,
      description: "Indicates reason (also temporal)",
      examples: ["Since you're here, let's talk"],
      pos_tag: :sconj
    },
    %{
      word: "as",
      type: :causal,
      description: "Indicates reason (also temporal)",
      examples: ["As you suggested, I'll wait"],
      pos_tag: :sconj
    },

    # Condition
    %{
      word: "if",
      type: :conditional,
      description: "Indicates condition",
      examples: ["If it rains, we'll stay home", "Call if you need help"],
      pos_tag: :sconj
    },
    %{
      word: "unless",
      type: :conditional,
      description: "Indicates negative condition",
      examples: ["Unless you hurry, we'll be late"],
      pos_tag: :sconj
    },
    %{
      word: "provided",
      type: :conditional,
      description: "Indicates condition (formal)",
      examples: ["Provided that you agree, we'll proceed"],
      pos_tag: :sconj
    },

    # Concession/Contrast
    %{
      word: "although",
      type: :concessive,
      description: "Indicates concession",
      examples: ["Although tired, I continued", "I went although it was late"],
      pos_tag: :sconj
    },
    %{
      word: "though",
      type: :concessive,
      description: "Indicates concession (informal)",
      examples: ["Though small, it's powerful", "I'll try though I doubt it"],
      pos_tag: :sconj
    },
    %{
      word: "even though",
      type: :concessive,
      description: "Indicates strong concession",
      examples: ["Even though I'm tired, I'll help"],
      pos_tag: :sconj,
      multi_word: true
    },
    %{
      word: "whereas",
      type: :contrastive,
      description: "Indicates contrast",
      examples: ["I like coffee whereas she likes tea"],
      pos_tag: :sconj
    },

    # Purpose
    %{
      word: "so that",
      type: :purposive,
      description: "Indicates purpose",
      examples: ["I left early so that I'd arrive on time"],
      pos_tag: :sconj,
      multi_word: true
    },
    %{
      word: "in order that",
      type: :purposive,
      description: "Indicates purpose (formal)",
      examples: ["We hurried in order that we might catch the train"],
      pos_tag: :sconj,
      multi_word: true
    },

    # Result
    %{
      word: "so",
      type: :result,
      description: "Indicates result (with 'that')",
      examples: ["It was so hot that we couldn't sleep"],
      pos_tag: :sconj,
      note: "Often paired with 'that'"
    },

    # Manner/Comparison
    %{
      word: "as if",
      type: :manner,
      description: "Indicates manner or comparison",
      examples: ["He acts as if he owns the place"],
      pos_tag: :sconj,
      multi_word: true
    },
    %{
      word: "as though",
      type: :manner,
      description: "Indicates manner (like 'as if')",
      examples: ["She spoke as though nothing happened"],
      pos_tag: :sconj,
      multi_word: true
    }
  ],

  # Relative pronouns and adverbs (introduce relative clauses)
  relative_markers: [
    %{
      word: "who",
      type: :relative_pronoun,
      description: "Refers to person (subject)",
      examples: ["the man who called", "people who care"],
      pos_tag: :pron,
      antecedent: :person
    },
    %{
      word: "whom",
      type: :relative_pronoun,
      description: "Refers to person (object)",
      examples: ["the man whom I saw", "people whom we trust"],
      pos_tag: :pron,
      antecedent: :person,
      note: "Formal, often replaced by 'who'"
    },
    %{
      word: "whose",
      type: :relative_pronoun,
      description: "Indicates possession",
      examples: ["the man whose car broke", "people whose homes were lost"],
      pos_tag: :pron
    },
    %{
      word: "which",
      type: :relative_pronoun,
      description: "Refers to thing or animal",
      examples: ["the book which I read", "the dog which barked"],
      pos_tag: :pron,
      antecedent: :non_person
    },
    %{
      word: "that",
      type: :relative_pronoun,
      description: "Refers to person or thing",
      examples: ["the book that I read", "the man that called"],
      pos_tag: :pron,
      antecedent: :any,
      note: "Most common relative pronoun"
    },
    %{
      word: "where",
      type: :relative_adverb,
      description: "Refers to place",
      examples: ["the house where I live", "the place where we met"],
      pos_tag: :adv,
      semantic_role: :location
    },
    %{
      word: "when",
      type: :relative_adverb,
      description: "Refers to time",
      examples: ["the day when we met", "the time when everything changed"],
      pos_tag: :adv,
      semantic_role: :time
    },
    %{
      word: "why",
      type: :relative_adverb,
      description: "Refers to reason",
      examples: ["the reason why I left", "I don't know why she cried"],
      pos_tag: :adv,
      semantic_role: :reason
    }
  ],

  # Subordinate clause types
  clause_types: [
    %{
      type: :adverbial,
      description: "Modifies verb, adjective, or sentence",
      marker_type: :subordinating_conjunction,
      examples: [
        "I left because I was tired",
        "When she arrived, I left",
        "If it rains, we'll stay home"
      ],
      semantic_roles: [:time, :cause, :condition, :concession, :purpose, :result, :manner]
    },
    %{
      type: :relative,
      description: "Modifies noun",
      marker_type: :relative_pronoun_or_adverb,
      examples: [
        "the book that I read",
        "the man who called",
        "the place where we met"
      ],
      attaches_to: :noun_phrase
    },
    %{
      type: :nominal,
      description: "Functions as noun (subject, object, complement)",
      marker_type: :complementizer,
      examples: [
        "That he left surprised me (subject)",
        "I know that she's here (object)",
        "The fact is that we're late (complement)"
      ],
      markers: ["that", "whether", "if"]
    }
  ],

  # Subordination patterns
  subordination_patterns: [
    %{
      pattern: "SCONJ Clause, Main Clause",
      description: "Fronted subordinate clause",
      examples: [
        "Because I was tired, I left",
        "When she arrived, I left",
        "Although it rained, we went"
      ],
      punctuation: :comma_required
    },
    %{
      pattern: "Main Clause SCONJ Clause",
      description: "Final subordinate clause",
      examples: [
        "I left because I was tired",
        "I left when she arrived",
        "We went although it rained"
      ],
      punctuation: :comma_optional
    },
    %{
      pattern: "NP [RelPron Clause]",
      description: "Relative clause modifying noun",
      examples: [
        "the book [that I read]",
        "the man [who called]",
        "the place [where we met]"
      ],
      attachment: :right,
      attaches_to: :noun_phrase
    }
  ],

  # Detection rules
  detection_rules: %{
    subordinate_clause: %{
      description: "Detect subordinate clause at sentence start",
      algorithm: "Check if first token is SCONJ, parse remainder as clause",
      result: "Subordinate clause type with subordinator marker"
    },
    
    relative_clause: %{
      description: "Detect relative clause after noun",
      algorithm: "After parsing NP, check for relative pronoun/adverb, parse following tokens as clause",
      result: "Relative clause attached to noun as post-modifier"
    }
  },

  # Parsing strategy
  parsing_strategy: %{
    sentence_level: %{
      description: "Check for subordination before coordination",
      order: [
        "1. Check for SCONJ at start → subordinate clause",
        "2. Check for CCONJ in middle → coordination",
        "3. Otherwise → simple clause"
      ]
    },
    
    phrase_level: %{
      description: "Handle relative clauses as NP post-modifiers",
      order: [
        "1. Parse base NP (Det? Adj* Noun)",
        "2. Check for PP post-modifiers",
        "3. Check for relative clause (RelPron/RelAdv + Clause)",
        "4. Attach all post-modifiers to NP"
      ]
    }
  },

  # Dependency relations
  dependency_relations: %{
    mark: %{
      description: "Links subordinator to subordinate clause head",
      pattern: "clause_head → [mark] → subordinator",
      examples: ["left [→mark because]", "arrived [→mark when]"]
    },
    
    advcl: %{
      description: "Links adverbial clause to main clause",
      pattern: "main_verb → [advcl] → subordinate_verb",
      examples: ["left [→advcl tired] because"]
    },
    
    acl: %{
      description: "Links relative clause to noun",
      pattern: "noun → [acl] → relative_clause_head",
      examples: ["book [→acl read] that", "man [→acl called] who"]
    },
    
    ccomp: %{
      description: "Links clausal complement to verb",
      pattern: "main_verb → [ccomp] → complement_verb",
      examples: ["know [→ccomp here] that she's", "think [→ccomp wins] he"]
    }
  },

  # Semantic roles of subordinate clauses
  semantic_roles: %{
    temporal: ["when", "while", "before", "after", "since", "until", "as"],
    causal: ["because", "since", "as"],
    conditional: ["if", "unless", "provided"],
    concessive: ["although", "though", "even though"],
    contrastive: ["whereas"],
    purposive: ["so that", "in order that"],
    result: ["so"],
    manner: ["as if", "as though"]
  }
}
