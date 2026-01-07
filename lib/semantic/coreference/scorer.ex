defmodule Nasty.Semantic.Coreference.Scorer do
  @moduledoc """
  Generic scoring module for coreference resolution.

  Scores pairs of mentions for coreference likelihood using multiple features:
  - Sentence distance (recency)
  - Gender and number agreement
  - String matching (exact and partial)
  - Entity type compatibility
  - Mention type patterns (pronoun-name, etc.)

  All weights are configurable to allow tuning for different languages and domains.
  """

  alias Nasty.AST.Semantic.Mention

  @default_weights [
    distance: 0.4,
    gender_agreement: 0.3,
    number_agreement: 0.3,
    string_match: 0.5,
    partial_match: 0.2,
    entity_type: 0.2,
    pronoun_name: 0.3
  ]

  @doc """
  Scores a pair of mentions for coreference likelihood.

  Returns a float score between 0.0 and ~2.0, where higher scores indicate
  stronger coreference evidence.

  ## Parameters

    - `mention1` - First mention
    - `mention2` - Second mention
    - `opts` - Scoring options
      - `:max_distance` - Maximum sentence distance (default: 3)
      - `:weights` - Custom weight configuration (default: @default_weights)

  ## Examples

      iex> score = Scorer.score_mention_pair(m1, m2, max_distance: 3)
      0.85
  """
  @spec score_mention_pair(Mention.t(), Mention.t(), keyword()) :: float()
  def score_mention_pair(m1, m2, opts \\ []) do
    max_distance = Keyword.get(opts, :max_distance, 3)
    weights = Keyword.get(opts, :weights, @default_weights)

    score = 0.0

    # Distance score (recency)
    score = score + distance_score(m1, m2, max_distance, weights[:distance])

    # Agreement scores
    score = score + gender_agreement_score(m1, m2, weights[:gender_agreement])
    score = score + number_agreement_score(m1, m2, weights[:number_agreement])

    # String matching scores
    score = score + string_match_score(m1, m2, weights[:string_match])
    score = score + partial_match_score(m1, m2, weights[:partial_match])

    # Entity type score
    score = score + entity_type_score(m1, m2, weights[:entity_type])

    # Mention type pattern bonus
    score = score + pronoun_name_boost(m1, m2, weights[:pronoun_name])

    score
  end

  @doc """
  Scores based on sentence distance (recency).

  Closer mentions get higher scores. Mentions beyond max_distance get 0 score.
  """
  @spec distance_score(Mention.t(), Mention.t(), pos_integer(), float()) :: float()
  def distance_score(m1, m2, max_distance, weight) do
    distance = abs(m1.sentence_idx - m2.sentence_idx)

    if distance <= max_distance do
      (1.0 - distance / max_distance) * weight
    else
      0.0
    end
  end

  @doc """
  Scores based on gender agreement.

  Returns weight if genders agree, 0 otherwise.
  """
  @spec gender_agreement_score(Mention.t(), Mention.t(), float()) :: float()
  def gender_agreement_score(m1, m2, weight) do
    if Mention.gender_agrees?(m1, m2) do
      weight
    else
      0.0
    end
  end

  @doc """
  Scores based on number agreement.

  Returns weight if numbers agree, 0 otherwise.
  """
  @spec number_agreement_score(Mention.t(), Mention.t(), float()) :: float()
  def number_agreement_score(m1, m2, weight) do
    if Mention.number_agrees?(m1, m2) do
      weight
    else
      0.0
    end
  end

  @doc """
  Scores based on exact string match (case-insensitive).

  Returns weight if texts match exactly, 0 otherwise.
  """
  @spec string_match_score(Mention.t(), Mention.t(), float()) :: float()
  def string_match_score(m1, m2, weight) do
    if String.downcase(m1.text) == String.downcase(m2.text) do
      weight
    else
      0.0
    end
  end

  @doc """
  Scores based on partial string match.

  Returns weight if one text contains the other, 0 otherwise.
  """
  @spec partial_match_score(Mention.t(), Mention.t(), float()) :: float()
  def partial_match_score(m1, m2, weight) do
    if partial_match?(m1.text, m2.text) do
      weight
    else
      0.0
    end
  end

  @doc """
  Scores based on entity type match.

  Returns weight if both have same entity type, 0 otherwise.
  """
  @spec entity_type_score(Mention.t(), Mention.t(), float()) :: float()
  def entity_type_score(m1, m2, weight) do
    if m1.entity_type && m2.entity_type && m1.entity_type == m2.entity_type do
      weight
    else
      0.0
    end
  end

  @doc """
  Boost score for pronoun-name pairs.

  These are common coreference patterns (e.g., "John... he").
  Returns weight if one is pronoun and other is proper name, 0 otherwise.
  """
  @spec pronoun_name_boost(Mention.t(), Mention.t(), float()) :: float()
  def pronoun_name_boost(m1, m2, weight) do
    if (Mention.pronoun?(m1) and Mention.proper_name?(m2)) or
         (Mention.proper_name?(m1) and Mention.pronoun?(m2)) do
      weight
    else
      0.0
    end
  end

  @doc """
  Scores a pair of mention clusters for merging.

  Uses average linkage: averages scores of all mention pairs between clusters.

  ## Options

    - `:merge_strategy` - Linkage type (default: :average)
      - `:average` - Average of all pairwise scores
      - `:best` - Maximum pairwise score
      - `:worst` - Minimum pairwise score
  """
  @spec score_cluster_pair([Mention.t()], [Mention.t()], keyword()) :: float()
  def score_cluster_pair(cluster1, cluster2, opts \\ []) do
    strategy = Keyword.get(opts, :merge_strategy, :average)

    scores =
      for m1 <- cluster1, m2 <- cluster2 do
        score_mention_pair(m1, m2, opts)
      end

    case strategy do
      :average ->
        if Enum.empty?(scores) do
          0.0
        else
          Enum.sum(scores) / length(scores)
        end

      :best ->
        Enum.max(scores, fn -> 0.0 end)

      :worst ->
        Enum.min(scores, fn -> 0.0 end)
    end
  end

  ## Private Helpers

  # Check for partial string match
  defp partial_match?(text1, text2) do
    lower1 = String.downcase(text1)
    lower2 = String.downcase(text2)

    String.contains?(lower1, lower2) or String.contains?(lower2, lower1)
  end
end
