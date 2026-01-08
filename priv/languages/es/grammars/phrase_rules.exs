%{
  # Spanish Phrase Structure Grammar Rules
  # Based on Spanish linguistic patterns with flexible word order
  #
  # Key differences from English:
  # - Post-nominal adjectives: "la casa roja" (the red house)
  # - Pre-nominal quantifiers: "muchos libros" (many books)
  # - Pro-drop: subject pronouns often omitted
  # - Flexible word order: SVO, VSO, VOS all possible

  # Noun Phrase Patterns
  # Spanish NP: Det? QuantAdj* (Noun | PropN | Pron) Adj* PP*
  noun_phrases: [
    # Simple NP with determiner and noun
    # Example: "el gato" (the cat)
    {:np, [:det, :noun]},

    # NP with bare noun (no determiner)
    # Example: "agua" (water) - mass nouns
    {:np, [:noun]},

    # NP with proper noun
    # Example: "Madrid", "Ana"
    {:np, [:propn]},

    # NP with pronoun
    # Example: "él" (he), "ella" (she)
    {:np, [:pron]},

    # NP with determiner, noun, and post-nominal adjective(s)
    # Example: "la casa roja" (the red house)
    # Example: "el libro interesante grande" (the big interesting book)
    {:np, [:det, :noun, {:many, :adj}]},

    # NP with quantifying adjective before noun and descriptive after
    # Example: "muchos libros interesantes" (many interesting books)
    # Quantifying adjectives: mucho, poco, varios, alguno, ninguno, todo, otro
    {:np, [:det?, {:many, :quant_adj}, :noun, {:many, :adj}]},

    # NP with prepositional phrase modifier
    # Example: "el libro de Juan" (Juan's book)
    # Example: "la casa en la montaña" (the house in the mountain)
    {:np, [:det, :noun, {:many, :pp}]},

    # NP with relative clause
    # Example: "el libro que leí" (the book that I read)
    {:np, [:det, :noun, :relative_clause]},

    # Multi-word proper nouns
    # Example: "Pablo García", "Banco de España"
    {:np, [{:many, :propn}]}
  ],

  # Verb Phrase Patterns
  # Spanish VP: Aux* MainVerb NP? PP* Adv*
  verb_phrases: [
    # Simple VP with just main verb
    # Example: "corre" (runs)
    {:vp, [:verb]},

    # VP with auxiliary and main verb
    # Auxiliaries: haber (he, has, ha), ser (es, son), estar (está, están)
    # Example: "ha comido" (has eaten)
    # Example: "está corriendo" (is running)
    {:vp, [{:many, :aux}, :verb]},

    # VP with direct object
    # Example: "come manzanas" (eats apples)
    {:vp, [:verb, :np]},

    # VP with auxiliary and object
    # Example: "ha comido la manzana" (has eaten the apple)
    {:vp, [{:many, :aux}, :verb, :np]},

    # VP with prepositional complements
    # Example: "va a la tienda" (goes to the store)
    {:vp, [:verb, {:many, :pp}]},

    # VP with adverbial modifiers
    # Example: "corre rápidamente" (runs quickly)
    {:vp, [:verb, {:many, :adv}]},

    # Complex VP with object, PP, and adverbs
    # Example: "pone el libro en la mesa cuidadosamente"
    # (puts the book on the table carefully)
    {:vp, [:verb, :np, {:many, :pp}, {:many, :adv}]},

    # Copula constructions (ser/estar + adjective/noun)
    # Example: "es feliz" (is happy), "son ingenieros" (are engineers)
    # When AUX is at end and no VERB, treat last AUX as copula
    {:vp, [:aux, :np_or_adjp]}
  ],

  # Prepositional Phrase Patterns
  # Spanish PP: Prep NP
  prepositional_phrases: [
    # Basic PP
    # Prepositions: a, ante, bajo, con, contra, de, desde, en, entre,
    #               hacia, hasta, para, por, según, sin, sobre, tras
    # Example: "en la casa" (in the house)
    {:pp, [:adp, :np]},

    # PP with complex NP object
    # Example: "con el libro rojo" (with the red book)
    {:pp, [:adp, {:np, [:det, :noun, :adj]}]},

    # Nested PP (rare but possible)
    # Example: "desde la casa de María" (from María's house)
    {:pp, [:adp, {:np, [:det, :noun, :pp]}]}
  ],

  # Adjectival Phrase Patterns
  # Spanish AdjP: Adv? Adj PP?
  adjectival_phrases: [
    # Simple adjective
    # Example: "rojo" (red)
    {:adjp, [:adj]},

    # Adjective with intensifier
    # Intensifiers: muy, bastante, demasiado, tan, más, menos
    # Example: "muy bonita" (very pretty)
    # Example: "bastante grande" (quite big)
    {:adjp, [:adv, :adj]},

    # Adjective with prepositional complement
    # Example: "contento con el resultado" (happy with the result)
    # Example: "interesado en política" (interested in politics)
    {:adjp, [:adj, :pp]}
  ],

  # Adverbial Phrase Patterns
  # Spanish AdvP: Adv | Adv Adv
  adverbial_phrases: [
    # Simple adverb
    # Example: "rápidamente" (quickly)
    {:advp, [:adv]},

    # Intensified adverb
    # Example: "muy rápidamente" (very quickly)
    {:advp, [:adv, :adv]}
  ],

  # Relative Clause Patterns
  # Spanish Relative: RelativePron/RelAdv + Clause
  relative_clauses: [
    # Relative pronoun + clause
    # Pronouns: que, quien, quienes, cual, cuales, cuyo, cuya, cuyos, cuyas
    # Example: "que leí" (that I read)
    # Example: "quien vino" (who came)
    {:relative_clause, [:pron, :clause]},

    # Relative adverb + clause
    # Adverbs: donde, cuando, como
    # Example: "donde vivo" (where I live)
    # Example: "cuando llegó" (when he/she arrived)
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
    # Example: "Pablo García" → single NP with head "Pablo", modifier "García"
    {:consecutive_propn, :merge_to_single_np},

    # Quantifying adjectives come BEFORE noun in Spanish
    # List of quantifying adjectives that precede noun:
    # mucho/a/os/as, poco/a/os/as, varios/as, alguno/a/os/as,
    # ninguno/a/os/as, todo/a/os/as, otro/a/os/as, cada,
    # ambos/as, sendos/as
    {:quantifying_adj, :pre_nominal},

    # Descriptive adjectives typically come AFTER noun in Spanish
    # Exception: some adjectives can go before for emphasis or style
    {:descriptive_adj, :post_nominal},

    # Copula construction: when AUX is at end with no VERB,
    # treat last AUX as main verb (copula)
    {:copula, :last_aux_as_head},

    # Clitic pronouns are already attached to verbs by tokenizer
    # Example: "dámelo" → "da" + "me" + "lo" (give-me-it)
    # Parser does not need to handle this separately
    {:clitic_pronouns, :pre_tokenized}
  ],

  # Notes on Spanish-specific features
  notes: %{
    word_order: "Spanish has flexible word order (SVO, VSO, VOS). Parser must handle all.",
    pro_drop: "Subject pronouns often omitted. Parser allows nil subject.",
    adjective_position: "Most adjectives post-nominal, but quantifiers pre-nominal.",
    clitic_pronouns: "Attached to verbs in infinitive, gerund, and imperative.",
    gender_agreement: "Adjectives must agree in gender/number. Checked by morphology module.",
    prepositions: "a, ante, bajo, con, contra, de, desde, en, entre, hacia, hasta, para, por, según, sin, sobre, tras"
  }
}
