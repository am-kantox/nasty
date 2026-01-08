defmodule Nasty.Language.Spanish.CoreferenceResolver do
  @moduledoc """
  Resolves coreferences (anaphora) in Spanish documents.

  Delegates to generic coreference resolution with Spanish-specific configuration.

  Identifies mentions (pronouns, noun phrases) that refer to the same entity
  and groups them into coreference chains.

  ## Spanish-Specific Features

  - Spanish pronouns (él, ella, ellos, ellas, lo, la, los, las)
  - Gender/number agreement (él→Juan, ella→María)
  - Pro-drop null subjects (Ø→Juan)
  - Clitic pronouns (lo→libro, le→Juan)
  - Reflexive constructions (se→sí mismo)
  - Spanish possessives (su, sus, suyo, suya)
  - Spanish demonstratives (este, ese, aquel)

  ## Example

      iex> {:ok, chains} = CoreferenceResolver.resolve(doc)
      {:ok, [%CorefChain{representative: "Juan", mentions: ["Juan", "él"]}, ...]}
  """

  alias Nasty.AST.Document
  alias Nasty.AST.Semantic.CorefChain
  alias Nasty.Language.Spanish.Adapters.CoreferenceResolverAdapter

  @doc """
  Resolves coreferences in a Spanish document.

  Delegates to the Spanish adapter which uses Spanish pronouns, gender/number
  agreement, and other language-specific features.

  ## Options

  - `:max_distance` - Maximum sentence distance for coreference (default: 3)
  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:use_gender` - Use gender agreement (default: true)
  - `:use_number` - Use number agreement (default: true)

  ## Examples

      iex> {:ok, chains} = CoreferenceResolver.resolve(doc)
      {:ok, [%CorefChain{...}]}

      iex> {:ok, chains} = CoreferenceResolver.resolve(doc, max_distance: 5)
      {:ok, [%CorefChain{...}]}
  """
  @spec resolve(Document.t(), keyword()) :: {:ok, [CorefChain.t()]} | {:error, term()}
  def resolve(%Document{language: :es} = doc, opts \\ []) do
    CoreferenceResolverAdapter.resolve(doc, opts)
  end

  def resolve(%Document{language: lang}, _opts) do
    {:error,
     {:language_mismatch,
      "Spanish coreference resolver called with #{lang} document. Use language-specific resolver."}}
  end
end
