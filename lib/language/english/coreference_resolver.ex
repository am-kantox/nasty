defmodule Nasty.Language.English.CoreferenceResolver do
  @moduledoc """
  Coreference Resolution for English.

  This is a thin wrapper around the generic coreference resolution modules.
  It provides English-specific configuration and delegates to the generic
  resolver for the actual algorithm.

  Links referring expressions (pronouns, definite NPs, proper names) across
  sentences to build coreference chains representing entities.

  Uses rule-based heuristics with agreement constraints (gender, number)
  and salience-based scoring (recency, syntactic position).

  ## Examples

      iex> document = parse_document("John works at Google. He is an engineer.")
      iex> {:ok, chains} = CoreferenceResolver.resolve(document)
      iex> chain = List.first(chains)
      iex> chain.representative
      "John"
      iex> length(chain.mentions)
      2
  """

  alias Nasty.AST.Document
  alias Nasty.AST.Semantic.CorefChain
  alias Nasty.Language.English.CoreferenceConfig
  alias Nasty.Semantic.Coreference.Resolver

  @doc """
  Resolves coreferences in a document.

  Delegates to the generic resolver with English-specific configuration.

  ## Options

  - `:max_sentence_distance` - Maximum sentence distance for coreference (default: 3)
  - `:min_score` - Minimum score threshold for coreference (default: 0.3)
  - `:merge_strategy` - Clustering linkage type (default: :average)
  - `:weights` - Custom scoring weights

  ## Returns

  - `{:ok, chains}` - List of coreference chains
  - `{:error, reason}` - Resolution error
  """
  @spec resolve(Document.t(), keyword()) :: {:ok, [CorefChain.t()]} | {:error, term()}
  def resolve(%Document{} = document, opts \\ []) do
    # Get English-specific configuration
    config = CoreferenceConfig.config()

    # Delegate to generic resolver
    case Resolver.resolve(document, config, opts) do
      {:ok, resolved_document} ->
        {:ok, resolved_document.coref_chains}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
