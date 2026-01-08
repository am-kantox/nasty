defmodule Nasty.Language.Spanish.Summarizer do
  @moduledoc """
  Generates summaries of Spanish documents.

  Delegates to generic extractive summarization with Spanish-specific configuration.

  ## Extractive Summarization

  Ranks sentences by importance using:
  - TF-IDF term frequency
  - Position in document
  - Named entity density
  - Sentence length
  - Spanish discourse markers

  ## Spanish-Specific Features

  - Stop words (el, la, de, en, y, etc.)
  - Sentence boundaries (., !, ?, ;, ¿, ¡)
  - Discourse markers (además, sin embargo, por lo tanto, en conclusión)

  ## Example

      iex> doc = parse("El gato es un animal. Los gatos son carnívoros. Les gusta dormir.")
      iex> summary = Summarizer.summarize(doc, ratio: 0.5)
      {:ok, %Document{...}}
  """

  alias Nasty.AST.Document
  alias Nasty.Language.Spanish.Adapters.SummarizerAdapter

  @doc """
  Generates an extractive summary of a Spanish document.

  Delegates to the Spanish adapter which uses generic extractive summarization
  with Spanish-specific configuration (stop words, discourse markers, punctuation).

  ## Options

  - `:ratio` - Fraction of sentences to include (default: 0.3)
  - `:max_sentences` - Maximum number of sentences (default: unlimited)
  - `:min_sentences` - Minimum number of sentences (default: 1)
  - `:method` - Selection method: `:greedy` (default) or `:mmr`
  - `:mmr_lambda` - MMR lambda parameter (0.0-1.0), default 0.7

  ## Examples

      iex> {:ok, summary} = Summarizer.summarize(doc, ratio: 0.3)
      iex> {:ok, summary} = Summarizer.summarize(doc, max_sentences: 3, method: :mmr)
  """
  @spec summarize(Document.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def summarize(doc, opts \\ [])

  def summarize(%Document{language: :es} = doc, opts) do
    SummarizerAdapter.summarize(doc, opts)
  end

  def summarize(%Document{language: lang}, opts) do
    {:error,
     {:language_mismatch,
      "Spanish summarizer called with #{lang} document. Use language-specific summarizer."}}
  end
end
