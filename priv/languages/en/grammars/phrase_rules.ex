defmodule Nasty.Language.English.Grammar.PhraseRules do
  @moduledoc """
  Formal Context-Free Grammar (CFG) rules for English phrase structure.

  This module defines the phrase structure rules used by the English parser.
  Rules are organized hierarchically from sentence level down to terminal symbols.

  Based on `docs/languages/ENGLISH_GRAMMAR.md` specification.
  """

  @doc """
  Returns all phrase structure rules as a list of tuples.

  Each rule is represented as `{lhs, rhs}` where:
  - `lhs` is the left-hand side non-terminal (atom)
  - `rhs` is a list of right-hand side symbols (atoms or lists of alternatives)

  ## Examples

      iex> rules = PhraseRules.rules()
      iex> Enum.find(rules, fn {lhs, _} -> lhs == :np end)
      {:np, [[:det, :adj, :noun], [:det, :noun], [:noun], [:propn], [:pron]]}
  """
  def rules do
    sentence_rules() ++ clause_rules() ++ phrase_rules()
  end

  @doc """
  Returns sentence-level CFG rules.

  ## Rules

  - S → CLAUSE+ PUNCT
  - SENT → MAIN_CLAUSE COORD_CLAUSE* SUBORD_CLAUSE*
  """
  def sentence_rules do
    [
      {:sentence, [
        [:clause, :punct],
        [:clause, :clause, :punct],
        [:clause, :clause, :clause, :punct]
      ]},
      {:sent, [
        [:main_clause],
        [:main_clause, :coord_clause],
        [:main_clause, :subord_clause],
        [:main_clause, :coord_clause, :subord_clause]
      ]}
    ]
  end

  @doc """
  Returns clause-level CFG rules.

  ## Rules

  - MAIN_CLAUSE → NP VP
  - COORD_CLAUSE → CCONJ NP VP
  - SUBORD_CLAUSE → SCONJ VP | SCONJ NP VP
  """
  def clause_rules do
    [
      {:main_clause, [
        [:np, :vp]
      ]},
      {:coord_clause, [
        [:cconj, :np, :vp],
        [:cconj, :vp]
      ]},
      {:subord_clause, [
        [:sconj, :vp],
        [:sconj, :np, :vp]
      ]}
    ]
  end

  @doc """
  Returns phrase-level CFG rules.

  ## Rules

  - NP → DET? ADJ* (NOUN | PROPN | PRON) PP* RC*
  - VP → AUX* VERB NP? PP* ADVP*
  - PP → ADP NP
  - ADJP → ADV? ADJ
  - ADVP → ADV+
  - RC → REL_PRON_ADV CLAUSE
  """
  def phrase_rules do
    [
      # Noun Phrases
      {:np, [
        [:det, :adj, :adj, :noun, :pp],
        [:det, :adj, :noun, :pp],
        [:det, :noun, :pp],
        [:adj, :noun, :pp],
        [:noun, :pp],
        [:det, :adj, :adj, :noun],
        [:det, :adj, :noun],
        [:det, :noun],
        [:adj, :noun],
        [:noun],
        [:propn, :propn],
        [:propn],
        [:pron]
      ]},

      # Verb Phrases
      {:vp, [
        [:aux, :aux, :aux, :verb, :np, :pp, :advp],
        [:aux, :aux, :verb, :np, :pp, :advp],
        [:aux, :verb, :np, :pp, :advp],
        [:verb, :np, :pp, :advp],
        [:aux, :aux, :aux, :verb, :np, :pp],
        [:aux, :aux, :verb, :np, :pp],
        [:aux, :verb, :np, :pp],
        [:verb, :np, :pp],
        [:aux, :aux, :aux, :verb, :np],
        [:aux, :aux, :verb, :np],
        [:aux, :verb, :np],
        [:verb, :np],
        [:aux, :aux, :aux, :verb, :pp],
        [:aux, :aux, :verb, :pp],
        [:aux, :verb, :pp],
        [:verb, :pp],
        [:aux, :aux, :aux, :verb],
        [:aux, :aux, :verb],
        [:aux, :verb],
        [:verb],
        # Copula constructions (auxiliary as main verb)
        [:aux, :adjp],
        [:aux, :np],
        [:aux, :pp]
      ]},

      # Prepositional Phrases
      {:pp, [
        [:adp, :np]
      ]},

      # Adjectival Phrases
      {:adjp, [
        [:adv, :adj],
        [:adj]
      ]},

      # Adverbial Phrases
      {:advp, [
        [:adv, :adv],
        [:adv]
      ]},

      # Relative Clauses
      {:rc, [
        [:rel_pron, :vp],
        [:rel_pron, :np, :vp]
      ]}
    ]
  end

  @doc """
  Returns lexical category definitions for terminal symbols.

  Maps POS tags to their lexical categories with example words.
  """
  def lexical_categories do
    %{
      det: %{
        name: "Determiner",
        examples: ["the", "a", "an", "this", "that", "some", "any", "my", "your"],
        description: "Articles, demonstratives, quantifiers"
      },
      adj: %{
        name: "Adjective",
        examples: ["big", "small", "happy", "fast", "beautiful", "old"],
        description: "Modifies nouns"
      },
      noun: %{
        name: "Noun",
        examples: ["cat", "dog", "tree", "idea", "happiness", "book"],
        description: "Common nouns"
      },
      propn: %{
        name: "Proper Noun",
        examples: ["London", "Mary", "Monday", "Google", "Shakespeare"],
        description: "Names of specific entities"
      },
      pron: %{
        name: "Pronoun",
        examples: ["I", "you", "he", "she", "it", "we", "they", "who", "which"],
        description: "Pronouns"
      },
      verb: %{
        name: "Verb",
        examples: ["run", "eat", "think", "walk", "write", "destroy"],
        description: "Main verbs"
      },
      aux: %{
        name: "Auxiliary",
        examples: ["be", "have", "do", "will", "can", "should", "must"],
        description: "Auxiliary and modal verbs"
      },
      adp: %{
        name: "Adposition",
        examples: ["in", "on", "at", "by", "for", "with", "from", "to", "of"],
        description: "Prepositions"
      },
      cconj: %{
        name: "Coordinating Conjunction",
        examples: ["and", "or", "but", "nor", "yet", "so", "for"],
        description: "Coordinates words, phrases, clauses"
      },
      sconj: %{
        name: "Subordinating Conjunction",
        examples: ["because", "if", "when", "while", "although", "since", "unless"],
        description: "Introduces subordinate clauses"
      },
      adv: %{
        name: "Adverb",
        examples: ["very", "quickly", "often", "well", "extremely"],
        description: "Modifies verbs, adjectives, adverbs"
      },
      rel_pron: %{
        name: "Relative Pronoun/Adverb",
        examples: ["who", "whom", "whose", "which", "that", "where", "when", "why"],
        description: "Introduces relative clauses"
      },
      punct: %{
        name: "Punctuation",
        examples: [".", ",", ";", ":", "!", "?", "(", ")", "[", "]"],
        description: "Punctuation marks"
      }
    }
  end

  @doc """
  Returns production rules in Chomsky Normal Form (CNF).

  CNF rules have the form:
  - A → BC (two non-terminals)
  - A → a (single terminal)

  This is useful for algorithms like CYK parsing.
  """
  def cnf_rules do
    [
      # Binary rules (A → BC)
      {:s, [:np, :vp]},
      {:np, [:det, :n_bar]},
      {:n_bar, [:adj, :noun]},
      {:vp, [:aux, :v_bar]},
      {:v_bar, [:verb, :np]},
      {:pp, [:adp, :np]},

      # Unary rules (A → B)
      {:n_bar, [:noun]},
      {:v_bar, [:verb]},

      # Lexical rules (A → a) - handled by POS tagging
    ]
  end

  @doc """
  Checks if a given rule exists in the grammar.

  ## Examples

      iex> PhraseRules.has_rule?(:np, [:det, :noun])
      true

      iex> PhraseRules.has_rule?(:np, [:verb, :noun])
      false
  """
  def has_rule?(lhs, rhs) do
    rules()
    |> Enum.any?(fn {rule_lhs, alternatives} ->
      rule_lhs == lhs and rhs in alternatives
    end)
  end

  @doc """
  Returns all possible right-hand sides for a given non-terminal.

  ## Examples

      iex> PhraseRules.alternatives(:adjp)
      [[:adv, :adj], [:adj]]
  """
  def alternatives(non_terminal) do
    rules()
    |> Enum.find_value([], fn
      {^non_terminal, rhs} -> rhs
      _ -> nil
    end)
  end
end
