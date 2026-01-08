defmodule Nasty.Language.Spanish.Summarizer do
  @moduledoc """
  Generates summaries of Spanish documents.

  Supports both extractive (selecting key sentences) and abstractive
  (generating new sentences) summarization.

  ## Extractive Summarization

  Ranks sentences by importance using:
  - TF-IDF term frequency
  - Position in document
  - Named entity density
  - Sentence length

  ## Spanish-Specific Features

  - Stop words (el, la, de, en, y, etc.)
  - Sentence boundaries (., !, ?, ;)
  - Discourse markers (además, sin embargo, por lo tanto)

  ## Example

      iex> doc = parse("El gato es un animal. Los gatos son carnívoros. Les gusta dormir.")
      iex> summary = Summarizer.summarize(doc, ratio: 0.5)
      "Los gatos son carnívoros."
  """

  alias Nasty.AST.Document
  alias Nasty.Operations.Summarization.Extractive

  @doc """
  Generates an extractive summary of a Spanish document.

  ## Options

  - `:ratio` - Fraction of sentences to include (default: 0.3)
  - `:max_sentences` - Maximum number of sentences (default: unlimited)
  - `:min_sentences` - Minimum number of sentences (default: 1)
  """
  @spec summarize(Document.t(), keyword()) :: String.t()
  def summarize(doc, opts \\ [])

  def summarize(%Document{language: :es} = doc, opts) do
    config = spanish_config()
    Extractive.summarize(doc, Keyword.merge([config: config], opts))
  end

  def summarize(%Document{language: lang}, _opts) do
    raise ArgumentError,
          "Spanish summarizer called with #{lang} document. Use language-specific summarizer."
  end

  # Spanish-specific summarization configuration
  defp spanish_config do
    %{
      # Common Spanish stop words (most frequent function words)
      stop_words:
        MapSet.new([
          # Articles
          "el",
          "la",
          "los",
          "las",
          "un",
          "una",
          "unos",
          "unas",
          # Prepositions
          "de",
          "a",
          "en",
          "por",
          "para",
          "con",
          "sin",
          "sobre",
          "entre",
          "desde",
          "hasta",
          # Conjunctions
          "y",
          "e",
          "o",
          "u",
          "pero",
          "mas",
          "sino",
          "ni",
          "que",
          # Pronouns
          "yo",
          "tú",
          "él",
          "ella",
          "nosotros",
          "vosotros",
          "ellos",
          "me",
          "te",
          "lo",
          "la",
          "se",
          "nos",
          "os",
          "les",
          # Common verbs
          "ser",
          "estar",
          "haber",
          "tener",
          "hacer",
          "poder",
          "decir",
          # Adverbs
          "muy",
          "más",
          "menos",
          "también",
          "tampoco",
          "sí",
          "no",
          "ya",
          "aún"
        ]),
      # Discourse markers that signal importance
      discourse_markers: [
        # Additive
        "además",
        "asimismo",
        "igualmente",
        "también",
        # Contrastive
        "sin embargo",
        "no obstante",
        "pero",
        "aunque",
        # Causal
        "porque",
        "ya que",
        "puesto que",
        "por lo tanto",
        "por eso",
        # Sequential
        "primero",
        "segundo",
        "luego",
        "después",
        "finalmente",
        # Conclusive
        "en conclusión",
        "en resumen",
        "por último"
      ],
      # Sentence importance weights
      weights: %{
        position: 0.3,
        # First sentences more important
        tf_idf: 0.4,
        # Term frequency
        entity_density: 0.2,
        # Named entities
        length: 0.1
        # Prefer medium-length sentences
      }
    }
  end
end
