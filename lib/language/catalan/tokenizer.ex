defmodule Nasty.Language.Catalan.Tokenizer do
  @moduledoc """
  Tokenizer for Catalan text.

  Handles Catalan-specific features:
  - Interpunct (l·l): Keeps as single token
  - Apostrophe contractions: l', d', s', n', m', t'
  - Article contractions: del, al, pel, etc.
  - Catalan diacritics: à, è, é, í, ï, ò, ó, ú, ü, ç

  ## Examples

      iex> Tokenizer.tokenize("L'home col·labora.")
      {:ok, [%Token{text: "L'"}, %Token{text: "home"}, %Token{text: "col·labora"}, %Token{text: "."}]}
  """

  alias Nasty.AST.Token

  @doc """
  Tokenizes Catalan text into a list of tokens with position tracking.

  ## Options

  - `:preserve_contractions` - Keep contractions intact (default: false)

  ## Examples

      iex> Tokenizer.tokenize("El gat dorm.")
      {:ok, [%Token{text: "El"}, %Token{text: "gat"}, %Token{text: "dorm"}, %Token{text: "."}]}
  """
  @spec tokenize(String.t(), keyword()) :: {:ok, [Token.t()]} | {:error, term()}
  def tokenize(_text, _opts \\ []) do
    # TODO: Implement Catalan tokenization
    # Will be implemented in Phase 2
    {:error, :not_implemented}
  end
end
