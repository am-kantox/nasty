defmodule Nasty.Language.Spanish.EntityRecognizer do
  @moduledoc """
  Recognizes named entities in Spanish text.

  Delegates to generic rule-based entity recognition with Spanish-specific configuration.

  Uses rule-based patterns to identify:
  - PERSON: names (Juan García, María López)
  - LOCATION: cities, countries (Madrid, España, Barcelona, Cataluña)
  - ORGANIZATION: companies, institutions (Banco de España, Real Madrid)
  - DATE: temporal expressions (lunes, 15 de enero, 2024)
  - MONEY: currency amounts (100 euros, $50, 25€)
  - PERCENT: percentages (25%, 3.5 por ciento)

  ## Spanish-Specific Features

  - Spanish name lexicons (common Spanish names, surnames)
  - Spanish place lexicons (Spanish cities, regions, Latin American countries)
  - Spanish titles (Sr., Sra., Dr., Dra., Don, Doña)
  - Spanish date formats (15 de enero de 2024)
  - Euro currency symbols (€)
  - Spanish organizational patterns (S.A., S.L., Ltda.)

  ## Example

      iex> {:ok, entities} = EntityRecognizer.recognize(spanish_tokens)
      {:ok, [%Entity{type: :PERSON, text: "Juan García"}, ...]}
  """

  alias Nasty.AST.{Entity, Token}
  alias Nasty.Language.Spanish.Adapters.EntityRecognizerAdapter

  @doc """
  Recognizes named entities in Spanish tokens.

  Delegates to the Spanish adapter which uses generic rule-based entity recognition
  with Spanish-specific configuration (lexicons, patterns, heuristics).

  ## Options

  - `:types` - List of entity types to extract (default: all)
  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:use_context` - Use context for disambiguation (default: true)

  ## Examples

      iex> {:ok, entities} = EntityRecognizer.recognize(tokens)
      {:ok, [%Entity{type: :PERSON, text: "María García"}, ...]}

      iex> {:ok, entities} = EntityRecognizer.recognize(tokens, types: [:PERSON, :ORG])
      {:ok, [%Entity{...}]}
  """
  @spec recognize([Token.t()], keyword()) :: {:ok, [Entity.t()]} | {:error, term()}
  def recognize(tokens, opts \\ []) when is_list(tokens) do
    EntityRecognizerAdapter.recognize(tokens, opts)
  end
end
