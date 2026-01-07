defmodule Nasty.Semantic.SRL.PredicateDetector do
  @moduledoc """
  Generic predicate (main verb) detection and voice identification for Semantic Role Labeling.

  This module provides language-agnostic algorithms for:
  - Identifying predicates in clauses
  - Detecting voice (active vs passive)

  Language-specific patterns are provided via configuration callbacks.
  """

  alias Nasty.AST.{Token, VerbPhrase}

  @typedoc """
  Language configuration for predicate detection.

  Required callbacks:
  - `passive_auxiliary?/1` - Check if token is a passive auxiliary (e.g., "was", "were", "be")
  - `passive_participle?/1` - Check if token is a passive participle form
  """
  @type language_config :: %{
          passive_auxiliary?: (Token.t() -> boolean()),
          passive_participle?: (Token.t() -> boolean())
        }

  @doc """
  Identifies main predicates (verbs) in a predicate phrase.

  Returns a list of predicate tokens. For most clauses, this is a single main verb.
  """
  @spec identify_predicates(VerbPhrase.t() | nil) :: [Token.t()]
  def identify_predicates(%VerbPhrase{head: main_verb}) when is_struct(main_verb, Token) do
    [main_verb]
  end

  def identify_predicates(_), do: []

  @doc """
  Detects voice (active vs passive) of the predicate.

  Uses language configuration to identify passive constructions:
  - Passive auxiliary (be, was, were) + past participle
  - Returns `:active`, `:passive`, or `:unknown`
  """
  @spec detect_voice(Token.t(), VerbPhrase.t() | nil, language_config()) ::
          :active | :passive | :unknown
  def detect_voice(predicate, verb_phrase, config)

  def detect_voice(predicate, %VerbPhrase{auxiliaries: auxiliaries} = _vp, config) do
    passive_aux? = config.passive_auxiliary?
    passive_participle? = config.passive_participle?

    # Check for passive auxiliary in VP
    has_passive_aux =
      case auxiliaries do
        nil -> false
        [] -> false
        list when is_list(list) -> Enum.any?(list, fn aux -> passive_aux?.(aux) end)
      end

    # Check if main verb is passive participle
    is_participle = passive_participle?.(predicate)

    if has_passive_aux and is_participle do
      :passive
    else
      :active
    end
  end

  def detect_voice(_predicate, _verb_phrase, _config), do: :active
end
