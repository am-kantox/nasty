defmodule Nasty.Language.Spanish.CoreferenceResolver do
  @moduledoc """
  Resolves coreferences (anaphora) in Spanish documents.

  Identifies mentions (pronouns, noun phrases) that refer to the same entity
  and groups them into coreference chains.

  ## Spanish-Specific Features

  - Gender/number agreement (él→Juan, ella→María)
  - Pro-drop null subjects (Ø→Juan)
  - Clitic pronouns (lo→libro, le→Juan)
  - Reflexive constructions (se→sí mismo)

  ## Example

      iex> doc = parse("Juan compró un libro. Él lo leyó ayer.")
      iex> chains = CoreferenceResolver.resolve(doc)
      [
        # Chain 1: Juan ← él
        [
          %Mention{text: "Juan", span: ...},
          %Mention{text: "Él", span: ...}
        ],
        # Chain 2: un libro ← lo
        [
          %Mention{text: "un libro", span: ...},
          %Mention{text: "lo", span: ...}
        ]
      ]
  """

  alias Nasty.AST.Document
  alias Nasty.Language.Spanish.CoreferenceConfig
  alias Nasty.Semantic.Coreference.Resolver

  @doc """
  Resolves coreferences in a Spanish document.

  Returns a list of coreference chains (lists of mentions that refer to the same entity).
  """
  @spec resolve(Document.t()) :: [[map()]]
  def resolve(%Document{language: :es} = doc) do
    config = CoreferenceConfig.get()
    Resolver.resolve(doc, config)
  end

  def resolve(%Document{language: lang}) do
    raise ArgumentError,
          "Spanish coreference resolver called with #{lang} document. Use language-specific resolver."
  end
end
