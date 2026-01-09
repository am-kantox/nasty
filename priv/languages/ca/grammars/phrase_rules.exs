%{
  # Catalan Phrase Structure Grammar Rules
  # Based on Catalan linguistic patterns with flexible word order
  #
  # Key features:
  # - Post-nominal adjectives: "la casa vermella" (the red house)
  # - Pre-nominal quantifiers: "molts llibres" (many books)
  # - Pro-drop: subject pronouns often omitted
  # - Flexible word order: SVO, VSO, VOS all possible
  # - Interpunct in compound words: "col·laborar", "intel·ligent"

  # Noun Phrase Patterns
  # Catalan NP: Det? QuantAdj* (Noun | PropN | Pron) Adj* PP*
  noun_phrases: [
    # Simple NP with determiner and noun
    # Example: "el gat" (the cat)
    {:np, [:det, :noun]},

    # NP with bare noun (no determiner)
    # Example: "aigua" (water) - mass nouns
    {:np, [:noun]},

    # NP with proper noun
    # Example: "Barcelona", "Maria"
    {:np, [:propn]},

    # NP with pronoun
    # Example: "ell" (he), "ella" (she)
    {:np, [:pron]},

    # NP with determiner, noun, and post-nominal adjective(s)
    # Example: "la casa vermella" (the red house)
    # Example: "el llibre interessant gran" (the big interesting book)
    {:np, [:det, :noun, {:many, :adj}]},

    # NP with quantifying adjective before noun and descriptive after
    # Example: "molts llibres interessants" (many interesting books)
    # Quantifying adjectives: molt, poc, varis, algun, cap, tot, altre
    {:np, [:det?, {:many, :quant_adj}, :noun, {:many, :adj}]},

    # NP with prepositional phrase modifier
    # Example: "el llibre de Joan" (Joan's book)
    # Example: "la casa a la muntanya" (the house in the mountain)
    {:np, [:det, :noun, {:many, :pp}]},

    # NP with relative clause
    # Example: "el llibre que vaig llegir" (the book that I read)
    {:np, [:det, :noun, :relative_clause]},

    # Multi-word proper nouns
    # Example: "Pau Garcia", "Banc de Catalunya"
    {:np, [{:many, :propn}]}
  ],

  # Verb Phrase Patterns
  # Catalan VP: Aux* MainVerb NP? PP* Adv*
  verb_phrases: [
    # Simple VP with just main verb
    # Example: "corre" (runs)
    {:vp, [:verb]},

    # VP with auxiliary and main verb
    # Auxiliaries: haver (he, has, ha), ser (és, són), estar (està, estan)
    # Example: "ha menjat" (has eaten)
    # Example: "està corrent" (is running)
    {:vp, [{:many, :aux}, :verb]},

    # VP with direct object
    # Example: "menja pomes" (eats apples)
    {:vp, [:verb, :np]},

    # VP with auxiliary and object
    # Example: "ha menjat la poma" (has eaten the apple)
    {:vp, [{:many, :aux}, :verb, :np]},

    # VP with prepositional complements
    # Example: "va a la botiga" (goes to the store)
    {:vp, [:verb, {:many, :pp}]},

    # VP with adverbial modifiers
    # Example: "corre ràpidament" (runs quickly)
    {:vp, [:verb, {:many, :adv}]},

    # Complex VP with object, PP, and adverbs
    # Example: "posa el llibre a la taula acuradament"
    # (puts the book on the table carefully)
    {:vp, [:verb, :np, {:many, :pp}, {:many, :adv}]},

    # Copula constructions (ser/estar + adjective/noun)
    # Example: "és feliç" (is happy), "són enginyers" (are engineers)
    {:vp, [:aux, :np_or_adjp]}
  ],

  # Prepositional Phrase Patterns
  # Catalan PP: Prep NP
  prepositional_phrases: [
    # Basic PP
    # Prepositions: a, amb, cap, contra, de, des, durant, en, entre,
    #               fins, per, sense, sobre, vers
    # Example: "a la casa" (in the house)
    {:pp, [:adp, :np]},

    # PP with complex NP object
    # Example: "amb el llibre vermell" (with the red book)
    {:pp, [:adp, {:np, [:det, :noun, :adj]}]},

    # Nested PP (rare but possible)
    # Example: "des de la casa de Maria" (from Maria's house)
    {:pp, [:adp, {:np, [:det, :noun, :pp]}]}
  ],

  # Adjectival Phrase Patterns
  # Catalan AdjP: Adv? Adj PP?
  adjectival_phrases: [
    # Simple adjective
    # Example: "vermell" (red)
    {:adjp, [:adj]},

    # Adjective with intensifier
    # Intensifiers: molt, força, massa, tan, més, menys
    # Example: "molt bonic" (very pretty)
    # Example: "força gran" (quite big)
    {:adjp, [:adv, :adj]},

    # Adjective with prepositional complement
    # Example: "content amb el resultat" (happy with the result)
    # Example: "interessat en política" (interested in politics)
    {:adjp, [:adj, :pp]}
  ],

  # Adverbial Phrase Patterns
  # Catalan AdvP: Adv | Adv Adv
  adverbial_phrases: [
    # Simple adverb
    # Example: "ràpidament" (quickly)
    {:advp, [:adv]},

    # Intensified adverb
    # Example: "molt ràpidament" (very quickly)
    {:advp, [:adv, :adv]}
  ],

  # Relative Clause Patterns
  # Catalan Relative: RelativePron/RelAdv + Clause
  relative_clauses: [
    # Relative pronoun + clause
    # Pronouns: que, qui, quin, quina, qual, quals
    # Example: "que vaig llegir" (that I read)
    # Example: "qui va venir" (who came)
    {:relative_clause, [:pron, :clause]},

    # Relative adverb + clause
    # Adverbs: on, quan, com
    # Example: "on visc" (where I live)
    # Example: "quan va arribar" (when he/she arrived)
    {:relative_clause, [:adv, :clause]}
  ],

  # Post-modifiers for Noun Phrases
  post_modifiers: [
    # Prepositional phrase
    :pp,

    # Relative clause
    :relative_clause,

    # Multiple post-modifiers possible
    {:many, [:pp, :relative_clause]}
  ],

  # VP Complements (objects, PPs, adverbs)
  vp_complements: [
    # Noun phrase (direct object)
    :np,

    # Prepositional phrase (oblique, indirect object, adverbial)
    :pp,

    # Adverbial phrase
    :advp,

    # Multiple complements
    {:many, [:np, :pp, :advp]}
  ],

  # Special handling rules
  special_rules: [
    # Consecutive proper nouns merge into single NP
    # Example: "Pau Garcia" → single NP with head "Pau", modifier "Garcia"
    {:consecutive_propn, :merge_to_single_np},

    # Quantifying adjectives come BEFORE noun in Catalan
    # List: molt/a/s, poc/a/s, varis/àries, algun/a/s,
    #       cap, tot/a/s, altre/a/s, cada, ambdós/dues
    {:quantifying_adj, :pre_nominal},

    # Descriptive adjectives typically come AFTER noun in Catalan
    # Exception: some adjectives can go before for emphasis
    # Examples: "bon dia" (good day), "mal temps" (bad weather)
    {:descriptive_adj, :post_nominal},

    # Interpunct words treated as single lexical unit
    # Example: "col·laborar", "intel·ligent"
    {:interpunct_word, :single_token},

    # Apostrophe contractions: l', d', s', n', m', t'
    # Example: "l'home" → [l', home]
    {:apostrophe_contraction, :separate_tokens}
  ]
}
