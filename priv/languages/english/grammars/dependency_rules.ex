defmodule Nasty.Language.English.Grammar.DependencyRules do
  @moduledoc """
  Universal Dependencies (UD) grammatical relation templates for English.

  This module defines dependency extraction rules that map phrase structures
  to Universal Dependencies grammatical relations.

  Based on `docs/languages/ENGLISH_GRAMMAR.md` specification and
  Universal Dependencies v2 standard.
  """

  @doc """
  Returns all Universal Dependencies relations with descriptions and examples.

  Each relation is represented as a map with:
  - `:relation` - The dependency relation atom
  - `:category` - The category (core, non_core, nominal, etc.)
  - `:description` - Human-readable description
  - `:example` - Example phrase
  - `:head_dependent` - Example of head → dependent

  ## Examples

      iex> relations = DependencyRules.relations()
      iex> Enum.find(relations, fn r -> r.relation == :nsubj end)
      %{relation: :nsubj, category: :core, description: "Nominal subject", ...}
  """
  def relations do
    core_arguments() ++ non_core_dependents() ++ nominal_dependents() ++
      coordination() ++ mwe_and_other() ++ special()
  end

  @doc """
  Returns core argument relations (subjects, objects, clausal complements).

  These are the most essential grammatical relations that define the core
  argument structure of a predicate.
  """
  def core_arguments do
    [
      %{
        relation: :nsubj,
        category: :core,
        description: "Nominal subject",
        example: "The cat sat",
        head_dependent: "sat → cat"
      },
      %{
        relation: :obj,
        category: :core,
        description: "Direct object",
        example: "ate the food",
        head_dependent: "ate → food"
      },
      %{
        relation: :iobj,
        category: :core,
        description: "Indirect object",
        example: "gave her the book",
        head_dependent: "gave → her"
      },
      %{
        relation: :csubj,
        category: :core,
        description: "Clausal subject",
        example: "That he left is sad",
        head_dependent: "sad → left"
      },
      %{
        relation: :ccomp,
        category: :core,
        description: "Clausal complement",
        example: "He said that she left",
        head_dependent: "said → left"
      },
      %{
        relation: :xcomp,
        category: :core,
        description: "Open clausal complement (infinitive)",
        example: "She wants to go",
        head_dependent: "wants → go"
      }
    ]
  end

  @doc """
  Returns non-core dependent relations (adverbials, auxiliaries, markers).

  These are modifiers and function words that provide additional information
  but are not core arguments.
  """
  def non_core_dependents do
    [
      %{
        relation: :obl,
        category: :non_core,
        description: "Oblique nominal (prepositional complement of verb)",
        example: "sat on the mat",
        head_dependent: "sat → mat"
      },
      %{
        relation: :advmod,
        category: :non_core,
        description: "Adverbial modifier",
        example: "runs quickly",
        head_dependent: "runs → quickly"
      },
      %{
        relation: :advcl,
        category: :non_core,
        description: "Adverbial clause modifier",
        example: "left because tired",
        head_dependent: "left → tired"
      },
      %{
        relation: :aux,
        category: :non_core,
        description: "Auxiliary verb",
        example: "is running",
        head_dependent: "running → is"
      },
      %{
        relation: :cop,
        category: :non_core,
        description: "Copula (linking verb)",
        example: "is happy",
        head_dependent: "happy → is"
      },
      %{
        relation: :mark,
        category: :non_core,
        description: "Marker (subordinator or complementizer)",
        example: "because it rained",
        head_dependent: "rained → because"
      }
    ]
  end

  @doc """
  Returns nominal dependent relations (modifiers within noun phrases).

  These are relations that attach to noun heads.
  """
  def nominal_dependents do
    [
      %{
        relation: :nmod,
        category: :nominal,
        description: "Nominal modifier (PP attached to noun)",
        example: "cat on the mat",
        head_dependent: "cat → mat"
      },
      %{
        relation: :appos,
        category: :nominal,
        description: "Appositional modifier",
        example: "John, my friend",
        head_dependent: "John → friend"
      },
      %{
        relation: :nummod,
        category: :nominal,
        description: "Numeric modifier",
        example: "three cats",
        head_dependent: "cats → three"
      },
      %{
        relation: :acl,
        category: :nominal,
        description: "Adnominal clause (relative clause)",
        example: "cat that sits",
        head_dependent: "cat → sits"
      },
      %{
        relation: :amod,
        category: :nominal,
        description: "Adjectival modifier",
        example: "big cat",
        head_dependent: "cat → big"
      },
      %{
        relation: :det,
        category: :nominal,
        description: "Determiner",
        example: "the cat",
        head_dependent: "cat → the"
      },
      %{
        relation: :case,
        category: :nominal,
        description: "Case marking (preposition)",
        example: "on the mat",
        head_dependent: "mat → on"
      },
      %{
        relation: :clf,
        category: :nominal,
        description: "Classifier",
        example: "three cups of tea",
        head_dependent: "cups → of"
      }
    ]
  end

  @doc """
  Returns coordination relations.

  These handle coordinated structures with conjunctions.
  """
  def coordination do
    [
      %{
        relation: :conj,
        category: :coordination,
        description: "Conjunct (coordinated element)",
        example: "cat and dog",
        head_dependent: "cat → dog"
      },
      %{
        relation: :cc,
        category: :coordination,
        description: "Coordinating conjunction",
        example: "cat and dog",
        head_dependent: "cat → and"
      }
    ]
  end

  @doc """
  Returns multi-word expression and miscellaneous relations.
  """
  def mwe_and_other do
    [
      %{
        relation: :fixed,
        category: :mwe,
        description: "Fixed multiword expression",
        example: "as well as",
        head_dependent: "as → well, as → as"
      },
      %{
        relation: :flat,
        category: :mwe,
        description: "Flat multiword expression (proper names)",
        example: "New York",
        head_dependent: "New → York"
      },
      %{
        relation: :compound,
        category: :mwe,
        description: "Compound word",
        example: "ice cream",
        head_dependent: "ice → cream"
      },
      %{
        relation: :list,
        category: :other,
        description: "List element",
        example: "1, 2, 3",
        head_dependent: "1 → 2, 1 → 3"
      },
      %{
        relation: :parataxis,
        category: :other,
        description: "Parataxis (loosely joined clauses)",
        example: "Go ahead, make my day",
        head_dependent: "Go → make"
      },
      %{
        relation: :punct,
        category: :other,
        description: "Punctuation",
        example: "The cat sat.",
        head_dependent: "sat → ."
      }
    ]
  end

  @doc """
  Returns special relations (root, unspecified).
  """
  def special do
    [
      %{
        relation: :root,
        category: :special,
        description: "Root of the sentence (attaches to virtual ROOT node)",
        example: "The cat sat.",
        head_dependent: "ROOT → sat"
      },
      %{
        relation: :dep,
        category: :special,
        description: "Unspecified dependency (fallback)",
        example: "",
        head_dependent: "head → dep"
      }
    ]
  end

  @doc """
  Returns phrase-to-dependency extraction templates.

  These templates define how phrase structures (NP, VP, PP, etc.) are
  converted into dependency relations.

  Each template is a map with:
  - `:phrase_type` - Type of phrase (:np, :vp, :pp, etc.)
  - `:rule` - Description of extraction rule
  - `:produces` - List of dependency relations produced
  """
  def extraction_templates do
    [
      np_template(),
      vp_template(),
      pp_template(),
      clause_template(),
      relative_clause_template()
    ]
  end

  @doc """
  Extraction template for Noun Phrases (NP).

  ```
  NP(determiner=D, head=H, modifiers=[M1, M2], post_modifiers=[PP])
  → det(H, D)
    amod(H, M1)
    amod(H, M2)
    [dependencies from PP with H as governor]
  ```
  """
  def np_template do
    %{
      phrase_type: :np,
      rule: "NP(determiner, modifiers, head, post_modifiers)",
      produces: [
        %{relation: :det, from: :head, to: :determiner, condition: "if determiner present"},
        %{relation: :amod, from: :head, to: :each_modifier, condition: "for each modifier"},
        %{relation: :nmod, from: :head, to: :pp_object, condition: "for each PP post-modifier"},
        %{relation: :acl, from: :head, to: :rc_predicate, condition: "for each relative clause"}
      ],
      notes: "Determiners and modifiers attach to the noun head"
    }
  end

  @doc """
  Extraction template for Verb Phrases (VP).

  ```
  VP(auxiliaries=[A1, A2], head=V, complements=[NP, PP, ADVP])
  → aux(V, A1)
    aux(V, A2)
    obj(V, NP.head)
    [dependencies from NP]
    [dependencies from PP with V as governor]
    advmod(V, ADVP.head)
  ```
  """
  def vp_template do
    %{
      phrase_type: :vp,
      rule: "VP(auxiliaries, head, complements)",
      produces: [
        %{relation: :aux, from: :head, to: :each_auxiliary, condition: "for each auxiliary"},
        %{relation: :obj, from: :head, to: :np_complement, condition: "if NP complement present"},
        %{relation: :obl, from: :head, to: :pp_object, condition: "for each PP complement"},
        %{relation: :advmod, from: :head, to: :advp_head, condition: "for each ADVP"}
      ],
      notes: "All elements attach to the main verb"
    }
  end

  @doc """
  Extraction template for Prepositional Phrases (PP).

  ```
  PP(head=P, object=NP)
  → case(NP.head, P)
    [with governor G:]
      obl(G, NP.head)    # if G is verb
      nmod(G, NP.head)   # if G is noun
    [dependencies from NP]
  ```
  """
  def pp_template do
    %{
      phrase_type: :pp,
      rule: "PP(preposition, object_np)",
      produces: [
        %{relation: :case, from: :np_head, to: :preposition, condition: "always"},
        %{
          relation: :obl,
          from: :governor,
          to: :np_head,
          condition: "if governor is verb"
        },
        %{
          relation: :nmod,
          from: :governor,
          to: :np_head,
          condition: "if governor is noun"
        }
      ],
      notes: "PP attaches differently depending on whether governor is verb or noun"
    }
  end

  @doc """
  Extraction template for Clauses.

  ```
  Clause(subject=NP_subj, predicate=VP, subordinator=S)
  → nsubj(VP.head, NP_subj.head)
    [dependencies from NP_subj]
    [dependencies from VP]
    mark(VP.head, S)  # if subordinator present
  ```
  """
  def clause_template do
    %{
      phrase_type: :clause,
      rule: "Clause(subject, predicate, subordinator?)",
      produces: [
        %{relation: :nsubj, from: :predicate_head, to: :subject_head, condition: "always"},
        %{relation: :mark, from: :predicate_head, to: :subordinator, condition: "if subordinate clause"}
      ],
      notes: "Subject attaches to verb; subordinator marks dependent clauses"
    }
  end

  @doc """
  Extraction template for Relative Clauses.

  ```
  RelativeClause(relativizer=R, clause=C, attached_to=N)
  → mark(C.predicate.head, R)
    acl(N, C.predicate.head)
    [dependencies from C]
  ```
  """
  def relative_clause_template do
    %{
      phrase_type: :relative_clause,
      rule: "RelativeClause(relativizer, clause, antecedent)",
      produces: [
        %{relation: :mark, from: :clause_predicate, to: :relativizer, condition: "if explicit relativizer"},
        %{relation: :acl, from: :antecedent, to: :clause_predicate, condition: "always"}
      ],
      notes: "Relative clause modifies noun via acl relation"
    }
  end

  @doc """
  Returns relation hierarchy (supertype relationships).

  Some relations are subtypes of more general relations.
  """
  def relation_hierarchy do
    %{
      # nsubj/csubj are subtypes of subj
      subj: [:nsubj, :csubj],
      # obj/iobj are subtypes of complement
      comp: [:obj, :iobj, :ccomp, :xcomp],
      # All modifiers
      mod: [:nmod, :amod, :advmod, :nummod],
      # All clausal relations
      clausal: [:csubj, :ccomp, :xcomp, :acl, :advcl]
    }
  end

  @doc """
  Checks if a relation is valid Universal Dependencies relation.

  ## Examples

      iex> DependencyRules.valid_relation?(:nsubj)
      true

      iex> DependencyRules.valid_relation?(:invalid)
      false
  """
  def valid_relation?(relation) do
    relations()
    |> Enum.any?(fn r -> r.relation == relation end)
  end

  @doc """
  Returns the category of a given relation.

  ## Examples

      iex> DependencyRules.category(:nsubj)
      :core

      iex> DependencyRules.category(:amod)
      :nominal
  """
  def category(relation) do
    relations()
    |> Enum.find_value(fn r ->
      if r.relation == relation, do: r.category
    end)
  end
end
