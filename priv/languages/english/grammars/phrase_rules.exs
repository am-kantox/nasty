# English Phrase Structure Grammar Rules
#
# This file defines the phrase structure rules for English grammar.
# These rules are used by the PhraseParser to build syntactic phrases.
#
# Grammar notation:
# - Optional: suffix with ?
# - Zero or more: suffix with *
# - One or more: suffix with +
# - Alternative: use list of options

%{
  noun_phrases: [
    %{
      pattern: [:det, :adj, :noun],
      description: "Full noun phrase with determiner and adjective",
      examples: ["the big dog", "a red car", "the old house"],
      optional: [:det],
      repeating: [:adj]
    },
    %{
      pattern: [:adj, :noun],
      description: "Noun phrase without determiner",
      examples: ["big dogs", "red cars", "old houses"],
      repeating: [:adj]
    },
    %{
      pattern: [:det, :noun],
      description: "Noun phrase with determiner only",
      examples: ["the dog", "a car", "the house"]
    },
    %{
      pattern: [:noun],
      description: "Bare noun",
      examples: ["dogs", "water", "information"]
    },
    %{
      pattern: [:propn],
      description: "Proper noun (name)",
      examples: ["John", "London", "Microsoft"],
      note: "Multiple consecutive proper nouns are merged"
    },
    %{
      pattern: [:pron],
      description: "Pronoun as noun phrase",
      examples: ["I", "he", "they", "who", "this"]
    },
    %{
      pattern: [:det, :adj, :noun, :pp],
      description: "Noun phrase with prepositional phrase modifier",
      examples: ["the book on the table", "a dog in the park"],
      repeating: [:adj, :pp]
    }
  ],

  verb_phrases: [
    %{
      pattern: [:aux, :verb],
      description: "Verb phrase with auxiliary",
      examples: ["is running", "has eaten", "will go"],
      repeating: [:aux]
    },
    %{
      pattern: [:verb, :np],
      description: "Transitive verb with direct object",
      examples: ["eat food", "read books", "see him"]
    },
    %{
      pattern: [:verb],
      description: "Intransitive verb",
      examples: ["sleep", "run", "arrive"]
    },
    %{
      pattern: [:aux, :verb, :np],
      description: "Auxiliary + verb + object",
      examples: ["has eaten food", "is reading books"],
      repeating: [:aux]
    },
    %{
      pattern: [:verb, :pp],
      description: "Verb with prepositional complement",
      examples: ["go to school", "look at me"],
      repeating: [:pp]
    },
    %{
      pattern: [:verb, :np, :pp],
      description: "Verb with object and prepositional complement",
      examples: ["put books on table", "give money to charity"],
      repeating: [:pp]
    },
    %{
      pattern: [:verb, :adv],
      description: "Verb with adverb",
      examples: ["run quickly", "speak loudly"]
    },
    %{
      pattern: [:aux],
      description: "Copula (auxiliary as main verb)",
      examples: ["is happy", "are engineers"],
      note: "Used when auxiliary appears without main verb"
    }
  ],

  prepositional_phrases: [
    %{
      pattern: [:adp, :np],
      description: "Standard prepositional phrase",
      examples: ["on the table", "in the park", "with friends"],
      head_pos: :adp
    },
    %{
      pattern: [:sconj, :np],
      description: "Comparative construction with 'than'",
      examples: ["than 21", "than me"],
      condition: "text == 'than'",
      head_pos: :sconj
    },
    %{
      pattern: [:adp, :num],
      description: "Preposition with number (in comparatives)",
      examples: ["than 21", "by 5"],
      note: "Number is wrapped in minimal NP"
    }
  ],

  adjectival_phrases: [
    %{
      pattern: [:adv, :adj],
      description: "Adjective with intensifier",
      examples: ["very big", "extremely fast", "quite good"],
      optional: [:adv]
    },
    %{
      pattern: [:adj],
      description: "Simple adjective",
      examples: ["big", "red", "happy"]
    },
    %{
      pattern: [:adj, :pp],
      description: "Adjective with prepositional complement",
      examples: ["greater than 21", "happy with results"],
      optional: [:pp],
      note: "Used in comparative and superlative constructions"
    }
  ],

  adverbial_phrases: [
    %{
      pattern: [:adv],
      description: "Simple adverb",
      examples: ["quickly", "very", "extremely"]
    }
  ],

  relative_clauses: [
    %{
      pattern: [:rel_pron, :clause],
      description: "Relative clause with relative pronoun",
      examples: ["who ate the cake", "which is on the table"],
      relative_pronouns: ["who", "whom", "whose", "which", "that"]
    },
    %{
      pattern: [:rel_adv, :clause],
      description: "Relative clause with relative adverb",
      examples: ["where I live", "when we met"],
      relative_adverbs: ["where", "when", "why"]
    }
  ],

  # Post-modifiers that can attach to noun phrases
  post_modifiers: [
    %{
      type: :prepositional_phrase,
      description: "PP attachment to NP",
      examples: ["book [on the table]", "dog [in the park]"],
      can_repeat: true
    },
    %{
      type: :relative_clause,
      description: "Relative clause attachment to NP",
      examples: ["dog [that barks]", "person [who called]"],
      can_repeat: false,
      attachment: :right
    }
  ],

  # Complements that can attach to verb phrases
  vp_complements: [
    %{
      type: :prepositional_phrase,
      description: "PP complement to VP",
      examples: ["go [to school]", "look [at me]"],
      can_repeat: true
    },
    %{
      type: :adverbial_phrase,
      description: "Adverbial complement to VP",
      examples: ["run [quickly]", "speak [loudly]"],
      can_repeat: true
    }
  ],

  # POS tag sets for phrase heads
  phrase_heads: %{
    noun_phrase: [:noun, :propn, :pron],
    verb_phrase: [:verb, :aux],
    prepositional_phrase: [:adp, :sconj],
    adjectival_phrase: [:adj],
    adverbial_phrase: [:adv]
  },

  # Special handling rules
  special_rules: %{
    # Proper nouns: consume consecutive PROPNs
    consecutive_propn: %{
      description: "Merge multiple consecutive proper nouns",
      examples: ["New York", "John Smith", "Microsoft Corporation"],
      applies_to: :noun_phrase
    },

    # Comparative "than" as pseudo-preposition
    comparative_than: %{
      description: "Treat 'than' as preposition in comparatives",
      condition: "token.pos_tag == :sconj and token.text == 'than'",
      treat_as: :adp,
      applies_to: :prepositional_phrase
    },

    # Copula construction: auxiliary without main verb
    copula: %{
      description: "Last auxiliary becomes main verb when no verb follows",
      examples: ["is happy", "are engineers", "was tired"],
      applies_to: :verb_phrase
    },

    # Number in PP (for comparatives)
    number_in_pp: %{
      description: "Wrap number token in minimal NP for PP object",
      examples: ["than 21", "by 5"],
      applies_to: :prepositional_phrase
    }
  }
}
