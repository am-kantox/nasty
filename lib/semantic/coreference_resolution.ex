defmodule Nasty.Semantic.CoreferenceResolution do
  @moduledoc """
  Behaviour for language-agnostic coreference resolution.

  Coreference resolution identifies when different expressions in text refer
  to the same entity (e.g., "Mary" and "she" referring to the same person).
  """

  alias Nasty.AST.Document

  @type options :: keyword()

  @doc """
  Resolves coreferences in a document.

  Identifies coreference chains linking mentions that refer to the same entity.

  ## Parameters

    - `document` - Document AST to process
    - `opts` - Resolution options
      - `:algorithm` - Resolution algorithm (`:rule_based`, `:statistical`)
      - `:max_distance` - Maximum sentence distance for coreference

  ## Returns

    - `{:ok, document}` - Document with `coref_chains` populated
    - `{:error, reason}` - Resolution error

  ## Examples

      iex> doc = parse("Mary loves her cat. She feeds it daily.")
      iex> {:ok, resolved} = Resolver.resolve(doc)
      iex> resolved.coref_chains
      [
        %CorefChain{mentions: [mention1, mention2], entity_type: :person},
        %CorefChain{mentions: [mention3, mention4], entity_type: :animal}
      ]
  """
  @callback resolve(document :: Document.t(), opts :: options()) ::
              {:ok, Document.t()} | {:error, term()}

  @doc """
  Returns resolution algorithms supported by this implementation.
  """
  @callback algorithms() :: [atom()]

  @optional_callbacks [algorithms: 0]
end
