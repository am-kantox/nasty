defmodule Nasty.Language.Catalan.Renderer do
  @moduledoc """
  Renders Catalan AST nodes back to natural language text.

  Delegates most rendering to the generic `Nasty.Rendering.Text` module,
  which handles language-agnostic surface realization.

  Catalan-specific features that are preserved:
  - Interpunct (l·l) in compound words
  - Apostrophe contractions (l', d', s')
  - Article contractions (del, al, pel)
  - Proper word order (post-nominal adjectives)
  - Catalan punctuation

  ## Examples

      iex> document = %Document{...}
      iex> Renderer.render(document)
      {:ok, "El gat dorm al sofà."}
  """

  alias Nasty.AST.Document
  alias Nasty.Rendering.Text

  @doc """
  Renders a Catalan AST node to text.

  Delegates to the generic text renderer since Catalan word forms are already
  stored in the Token text fields from tokenization. The renderer just
  reconstructs the text with proper spacing and punctuation.

  ## Options

  - `:capitalize_sentences` - Whether to capitalize first word of sentences (default: true)
  - `:add_punctuation` - Whether to add sentence-ending punctuation (default: true)
  - `:paragraph_separator` - String to separate paragraphs (default: "\\n\\n")

  ## Examples

      iex> Renderer.render(document)
      {:ok, "El gat dorm al sofà."}

      iex> Renderer.render(document, capitalize_sentences: false)
      {:ok, "el gat dorm al sofà."}
  """
  @spec render(term(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(node, opts \\ [])

  def render(%Document{language: :ca} = doc, opts) do
    # Delegate to generic text renderer
    # Catalan-specific features (interpunct, contractions) are already
    # in the token text, so generic rendering preserves them
    Text.render(doc, opts)
  end

  def render(%Document{language: lang}, _opts) do
    {:error,
     {:language_mismatch,
      "Catalan renderer called with #{lang} document. Use language-specific renderer."}}
  end

  def render(node, opts) do
    # For non-Document nodes, delegate directly
    Text.render(node, opts)
  end
end
