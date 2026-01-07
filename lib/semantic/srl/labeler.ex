defmodule Nasty.Semantic.SRL.Labeler do
  @moduledoc """
  Generic coordinator for Semantic Role Labeling.

  Orchestrates the SRL pipeline:
  1. Identify predicates (main verbs)
  2. Detect voice (active/passive)
  3. Extract core argument roles
  4. Classify adjunct roles
  5. Build semantic frames

  Language-specific patterns are provided via configuration.
  """

  alias Nasty.AST.{Clause, Sentence}
  alias Nasty.AST.Semantic.Frame
  alias Nasty.Semantic.SRL.{AdjunctClassifier, CoreArgumentMapper, PredicateDetector}

  @typedoc """
  Combined language configuration for SRL.

  Includes all callbacks needed for predicate detection, core role mapping,
  and adjunct classification.
  """
  @type language_config :: %{
          passive_auxiliary?: (Nasty.AST.Token.t() -> boolean()),
          passive_participle?: (Nasty.AST.Token.t() -> boolean()),
          temporal_adverb?: (String.t() -> boolean()),
          preposition_role_map: (%{} -> map())
        }

  @doc """
  Labels semantic roles for all predicates in a sentence.

  Returns `{:ok, frames}` where frames is a list of semantic frames,
  one per predicate in the sentence.
  """
  @spec label(Sentence.t(), language_config(), keyword()) :: {:ok, [Frame.t()]} | {:error, term()}
  def label(%Sentence{} = sentence, config, _opts \\ []) do
    frames =
      sentence
      |> Sentence.all_clauses()
      |> Enum.flat_map(&label_clause(&1, config))

    {:ok, frames}
  end

  @doc """
  Labels semantic roles for a single clause.

  Returns a list of frames (typically one per main verb in the clause).
  """
  @spec label_clause(Clause.t(), language_config()) :: [Frame.t()]
  def label_clause(%Clause{predicate: predicate} = clause, config) do
    # Identify main verb(s)
    verbs = PredicateDetector.identify_predicates(predicate)

    # Build frame for each verb
    Enum.map(verbs, fn verb ->
      build_frame(verb, clause, config)
    end)
  end

  # Build a semantic frame for a predicate
  defp build_frame(predicate, clause, config) do
    # Detect voice
    voice = PredicateDetector.detect_voice(predicate, clause.predicate, config)

    # Extract core argument roles
    core_roles = CoreArgumentMapper.extract_core_roles(clause, voice)

    # Classify adjunct roles
    adjunct_roles = AdjunctClassifier.classify_adverbials(clause, config)

    # Combine all roles
    all_roles = core_roles ++ adjunct_roles

    # Build frame
    Frame.new(predicate, all_roles, clause.span, voice: voice)
  end
end
