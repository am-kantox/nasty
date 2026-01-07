defmodule Nasty.Language.English.SRLConfig do
  @moduledoc """
  English-specific configuration for Semantic Role Labeling.

  Provides:
  - Passive auxiliary patterns
  - Passive participle detection
  - Temporal adverb recognition
  - Preposition-to-role mappings
  """

  alias Nasty.AST.Token

  # Passive auxiliaries (forms of "be")
  @passive_aux ["was", "were", "is", "are", "been", "being", "be"]

  # Temporal adverbs
  @temporal_adverbs [
    "now",
    "then",
    "today",
    "yesterday",
    "tomorrow",
    "recently",
    "soon",
    "already",
    "always",
    "never",
    "often",
    "sometimes",
    "seldom",
    "rarely",
    "frequently"
  ]

  # Preposition to semantic role mapping
  @preposition_roles %{
    # Location
    "at" => :location,
    "in" => :location,
    "on" => :location,
    "near" => :location,
    "to" => :location,
    "from" => :location,
    "into" => :location,
    "onto" => :location,
    "above" => :location,
    "below" => :location,
    "under" => :location,
    "over" => :location,
    "beside" => :location,
    "behind" => :location,
    # Time
    "during" => :time,
    "before" => :time,
    "after" => :time,
    "since" => :time,
    "until" => :time,
    "till" => :time,
    "throughout" => :time,
    # Instrument
    "with" => :instrument,
    "using" => :instrument,
    "by" => :instrument,
    "via" => :instrument,
    # Purpose
    "for" => :purpose,
    # Manner (how)
    "like" => :manner,
    "as" => :manner
  }

  @doc """
  Check if a token is a passive auxiliary.

  Returns true for forms of "be" (was, were, is, are, been, being, be).
  """
  @spec passive_auxiliary?(Token.t()) :: boolean()
  def passive_auxiliary?(%Token{text: text}) do
    String.downcase(text) in @passive_aux
  end

  @doc """
  Check if a token is a passive participle.

  Heuristics:
  - Morphology indicates :past_participle
  - Ends in -ed (regular verbs)
  - Ends in -en (some irregular verbs: written, taken, etc.)
  - Has POS tag indicating past participle (if available)
  - If it's a verb (not -ing form), assume it could be participle
    (for irregular verbs like "read", "cut", "put" that don't change form)
  """
  @spec passive_participle?(Token.t()) :: boolean()
  def passive_participle?(%Token{} = token) do
    # Check morphology
    morphology_participle? =
      case token.morphology do
        %{tense: :past_participle} -> true
        _ -> false
      end

    # Check endings (common patterns)
    ends_with_ed? = String.ends_with?(token.text, "ed")
    ends_with_en? = String.ends_with?(token.text, "en")

    # If verb doesn't end in -ing, it could be a participle
    # (This handles irregular verbs like "read", "cut", "put")
    not_present_participle? = not String.ends_with?(token.text, "ing")

    # If POS tag is verb, not gerund
    is_verb? = token.pos_tag == :verb

    morphology_participle? or ends_with_ed? or ends_with_en? or
      (is_verb? and not_present_participle?)
  end

  @doc """
  Check if text is a temporal adverb.

  Returns true for adverbs like "yesterday", "now", "always", etc.
  """
  @spec temporal_adverb?(String.t()) :: boolean()
  def temporal_adverb?(text) do
    String.downcase(text) in @temporal_adverbs
  end

  @doc """
  Returns the preposition-to-role mapping.

  Maps preposition strings (lowercase) to semantic role atoms.
  """
  @spec preposition_role_map() :: map()
  def preposition_role_map do
    @preposition_roles
  end

  @doc """
  Returns the complete configuration map for use with generic SRL modules.
  """
  @spec config() :: Nasty.Semantic.SRL.Labeler.language_config()
  def config do
    %{
      passive_auxiliary?: &passive_auxiliary?/1,
      passive_participle?: &passive_participle?/1,
      temporal_adverb?: &temporal_adverb?/1,
      preposition_role_map: &preposition_role_map/0
    }
  end
end
