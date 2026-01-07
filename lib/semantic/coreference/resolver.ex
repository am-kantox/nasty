defmodule Nasty.Semantic.Coreference.Resolver do
  @moduledoc """
  Generic coreference resolution coordinator.

  Orchestrates the complete resolution pipeline:
  1. Mention detection - Extract mentions from document
  2. Clustering - Build coreference chains
  3. Attachment - Attach chains to document

  This module is language-agnostic and delegates language-specific operations
  to callbacks provided in the language configuration.
  """

  alias Nasty.AST.Document
  alias Nasty.Semantic.Coreference.{Clusterer, MentionDetector}

  @type language_config :: MentionDetector.language_config()

  @doc """
  Resolves coreferences in a document.

  This is the main entry point for coreference resolution. It extracts mentions,
  builds coreference chains, and returns the document with chains attached.

  ## Parameters

    - `document` - Document AST to process
    - `language_config` - Language-specific configuration map with callbacks:
      - `:pronoun?` - Check if token is pronoun
      - `:classify_pronoun` - Get pronoun gender/number
      - `:infer_gender` - Infer gender from name/entity type
      - `:definite_determiner?` - Check if determiner is definite
      - `:plural_marker?` - Check if text is plural
    - `opts` - Resolution options
      - `:max_sentence_distance` - Max sentence gap (default: 3)
      - `:min_score` - Min score for merging (default: 0.3)
      - `:merge_strategy` - Clustering linkage (default: :average)
      - `:weights` - Custom scoring weights

  ## Returns

    - `{:ok, document}` - Document with `coref_chains` field populated
    - `{:error, reason}` - Resolution error

  ## Examples

      iex> config = %{
      ...>   pronoun?: &EnglishConfig.pronoun?/1,
      ...>   classify_pronoun: &EnglishConfig.classify_pronoun/1,
      ...>   infer_gender: &EnglishConfig.infer_person_gender/2,
      ...>   definite_determiner?: &EnglishConfig.definite_determiner?/1,
      ...>   plural_marker?: &EnglishConfig.plural_marker?/1
      ...> }
      iex> {:ok, resolved} = Resolver.resolve(document, config, [])
      iex> resolved.coref_chains
      [%CorefChain{...}, ...]
  """
  @spec resolve(Document.t(), language_config(), keyword()) ::
          {:ok, Document.t()} | {:error, term()}
  def resolve(%Document{} = document, language_config, opts \\ []) do
    # Step 1: Extract mentions
    mentions = MentionDetector.extract_mentions(document, language_config)

    # Step 2: Build coreference chains
    chains = Clusterer.build_chains(mentions, opts)

    # Step 3: Attach chains to document
    resolved_document = %{document | coref_chains: chains}

    {:ok, resolved_document}
  rescue
    error ->
      {:error, {:resolution_failed, error}}
  end
end
