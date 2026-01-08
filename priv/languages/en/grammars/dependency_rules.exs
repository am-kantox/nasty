# English Dependency Grammar Rules
#
# This file defines dependency relations based on Universal Dependencies v2.
# These rules are used by the DependencyExtractor to create dependency graphs.
#
# Reference: https://universaldependencies.org/

%{
  # Core argument relations
  core_arguments: [
    %{
      relation: :nsubj,
      description: "Nominal subject",
      pattern: "subject NP → predicate verb",
      examples: ["The cat [nsubj→ sat]", "She [nsubj→ runs]"],
      head_pos: [:verb, :aux, :adj],
      dependent_pos: [:noun, :propn, :pron]
    },
    %{
      relation: :obj,
      description: "Direct object",
      pattern: "verb → object NP",
      examples: ["eat [→obj food]", "see [→obj him]"],
      head_pos: [:verb],
      dependent_pos: [:noun, :propn, :pron]
    },
    %{
      relation: :iobj,
      description: "Indirect object",
      pattern: "verb → indirect object NP",
      examples: ["give [→iobj him] a book"],
      head_pos: [:verb],
      dependent_pos: [:noun, :propn, :pron],
      note: "Not currently extracted, would require verb frame knowledge"
    }
  ],

  # Non-core dependents
  non_core: [
    %{
      relation: :obl,
      description: "Oblique nominal (prepositional complement of verb)",
      pattern: "verb → PP object",
      examples: ["sit [→obl mat] on", "go [→obl school] to"],
      head_pos: [:verb, :aux],
      dependent_pos: [:noun, :propn, :pron],
      notes: "Used when PP attaches to verb"
    },
    %{
      relation: :advmod,
      description: "Adverbial modifier",
      pattern: "head → adverb",
      examples: ["run [→advmod quickly]", "very [→advmod fast]"],
      head_pos: [:verb, :adj, :adv],
      dependent_pos: [:adv]
    }
  ],

  # Nominal dependents
  nominal_dependents: [
    %{
      relation: :nmod,
      description: "Nominal modifier (prepositional complement of noun)",
      pattern: "noun → PP object",
      examples: ["book [→nmod table] on", "dog [→nmod park] in"],
      head_pos: [:noun, :propn],
      dependent_pos: [:noun, :propn, :pron],
      notes: "Used when PP attaches to noun"
    },
    %{
      relation: :amod,
      description: "Adjectival modifier",
      pattern: "noun → adjective",
      examples: ["dog [→amod big]", "car [→amod red]"],
      head_pos: [:noun, :propn],
      dependent_pos: [:adj]
    },
    %{
      relation: :det,
      description: "Determiner",
      pattern: "noun → determiner",
      examples: ["dog [→det the]", "car [→det a]"],
      head_pos: [:noun, :propn],
      dependent_pos: [:det]
    },
    %{
      relation: :nummod,
      description: "Numeric modifier",
      pattern: "noun → number",
      examples: ["dogs [→nummod three]", "years [→nummod 10]"],
      head_pos: [:noun],
      dependent_pos: [:num]
    }
  ],

  # Case marking
  case_marking: [
    %{
      relation: :case,
      description: "Case marking (preposition)",
      pattern: "PP object → preposition",
      examples: ["table [→case on]", "school [→case to]"],
      head_pos: [:noun, :propn, :pron],
      dependent_pos: [:adp]
    }
  ],

  # Clausal dependents
  clausal_dependents: [
    %{
      relation: :acl,
      description: "Clausal modifier of noun (relative clause)",
      pattern: "noun → relative clause head",
      examples: ["dog [→acl barks] that", "person [→acl called] who"],
      head_pos: [:noun, :propn],
      dependent_pos: [:verb],
      notes: "For relative clauses attached to nouns"
    },
    %{
      relation: :advcl,
      description: "Adverbial clause modifier",
      pattern: "main verb → subordinate clause head",
      examples: ["left [→advcl arrived] because we", "eat [→advcl hungry] when you're"],
      head_pos: [:verb],
      dependent_pos: [:verb],
      notes: "For subordinate clauses"
    },
    %{
      relation: :ccomp,
      description: "Clausal complement",
      pattern: "verb → complement clause head",
      examples: ["think [→ccomp wins] that he", "know [→ccomp left] she"],
      head_pos: [:verb],
      dependent_pos: [:verb],
      notes: "For that-clauses and similar"
    },
    %{
      relation: :xcomp,
      description: "Open clausal complement",
      pattern: "verb → infinitive/gerund head",
      examples: ["want [→xcomp go] to", "like [→xcomp swimming]"],
      head_pos: [:verb],
      dependent_pos: [:verb],
      notes: "For infinitives and gerunds"
    }
  ],

  # Function words
  function_words: [
    %{
      relation: :aux,
      description: "Auxiliary",
      pattern: "main verb → auxiliary",
      examples: ["running [→aux is]", "eaten [→aux has]"],
      head_pos: [:verb],
      dependent_pos: [:aux]
    },
    %{
      relation: :cop,
      description: "Copula",
      pattern: "predicate → copula",
      examples: ["happy [→cop is]", "engineer [→cop are]"],
      head_pos: [:adj, :noun],
      dependent_pos: [:aux],
      notes: "When 'be' is the main verb"
    },
    %{
      relation: :mark,
      description: "Marker (subordinating conjunction or relativizer)",
      pattern: "clause head → marker",
      examples: ["left [→mark because]", "barks [→mark that]"],
      head_pos: [:verb],
      dependent_pos: [:sconj, :part, :pron]
    }
  ],

  # Coordination
  coordination: [
    %{
      relation: :conj,
      description: "Conjunct",
      pattern: "first conjunct → second conjunct",
      examples: ["cats [→conj dogs] and", "run [→conj jump] and"],
      head_pos: [:any],
      dependent_pos: [:same_as_head]
    },
    %{
      relation: :cc,
      description: "Coordinating conjunction",
      pattern: "first conjunct → conjunction",
      examples: ["cats [→cc and] dogs", "run [→cc or] jump"],
      head_pos: [:any],
      dependent_pos: [:cconj]
    }
  ],

  # Other relations
  other: [
    %{
      relation: :punct,
      description: "Punctuation",
      pattern: "head → punctuation",
      examples: ["word [→punct .]", "word [→punct ,]"],
      head_pos: [:any],
      dependent_pos: [:punct]
    },
    %{
      relation: :compound,
      description: "Compound",
      pattern: "compound head → compound modifier",
      examples: ["York [→compound New]", "school [→compound high]"],
      head_pos: [:noun, :propn],
      dependent_pos: [:noun, :propn]
    }
  ],

  # Direction rules (head → dependent or dependent → head)
  # Most relations go: governor (head) → dependent
  direction: %{
    head_to_dependent: [
      :nsubj, :obj, :iobj, :obl, :advmod, :nmod, :amod, :det, :nummod,
      :acl, :advcl, :ccomp, :xcomp, :aux, :cop, :conj, :cc, :punct, :compound
    ],
    dependent_to_head: [
      :case, :mark
    ]
  },

  # Relation priorities (for ambiguous cases)
  priorities: %{
    # When PP could attach to verb or noun, prefer verb (obl) over noun (nmod)
    pp_attachment: [:obl, :nmod],
    
    # Object vs oblique: direct NP is obj, PP is obl
    verb_arguments: [:obj, :obl],
    
    # Modifier types in order of precedence
    modifiers: [:amod, :nmod, :advmod, :nummod]
  },

  # Extraction order (process in this order to build dep tree correctly)
  extraction_order: [
    # 1. Core arguments first
    :nsubj,
    :obj,
    
    # 2. Nominal structure
    :det,
    :amod,
    :nummod,
    
    # 3. Function words
    :aux,
    :cop,
    :mark,
    :case,
    
    # 4. Modifiers
    :advmod,
    :nmod,
    :obl,
    
    # 5. Clausal dependents
    :acl,
    :advcl,
    :ccomp,
    :xcomp,
    
    # 6. Coordination
    :cc,
    :conj,
    
    # 7. Other
    :compound,
    :punct
  ],

  # POS-based heuristics for relation selection
  heuristics: %{
    # PP attachment: if governor is verb → obl, if noun → nmod
    pp_relation: %{
      verb_governor: :obl,
      noun_governor: :nmod
    },
    
    # Auxiliary vs copula: if predicate is adj/noun → cop, else → aux
    aux_relation: %{
      adj_predicate: :cop,
      noun_predicate: :cop,
      verb_predicate: :aux
    }
  }
}
