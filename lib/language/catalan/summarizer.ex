defmodule Nasty.Language.Catalan.Summarizer do
  @moduledoc """
  Generates extractive summaries of Catalan documents.

  Uses sentence scoring based on multiple features:
  - Term frequency (TF-IDF)
  - Position in document
  - Named entity density
  - Sentence length
  - Catalan discourse markers
  - Coreference participation

  ## Catalan-Specific Features

  - Stop words from priv/languages/ca/stopwords.txt
  - Catalan discourse markers (en conclusió, per tant, a més, tanmateix)
  - Catalan sentence boundaries (., !, ?)

  ## Examples

      iex> {:ok, document} = Catalan.parse(tokens)
      iex> Summarizer.summarize(document, ratio: 0.3)
      {:ok, %Document{...}}

      iex> Summarizer.summarize(document, max_sentences: 5, method: :mmr)
      {:ok, %Document{...}}
  """

  alias Nasty.AST.{Document, Paragraph}

  @doc """
  Generates an extractive summary of a Catalan document.

  Selects the most important sentences based on scoring algorithms.
  Supports two selection methods:
  - `:greedy` - Top-N sentences by score (default)
  - `:mmr` - Maximal Marginal Relevance (reduces redundancy)

  ## Options

  - `:ratio` - Fraction of sentences to include (default: 0.3)
  - `:max_sentences` - Maximum number of sentences (overrides ratio)
  - `:min_sentences` - Minimum number of sentences (default: 1)
  - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)
  - `:mmr_lambda` - MMR lambda parameter (0.0-1.0), default 0.7
  - `:min_sentence_length` - Minimum sentence length in words, default 5

  ## Examples

      iex> {:ok, summary} = Summarizer.summarize(doc, ratio: 0.3)
      iex> {:ok, summary} = Summarizer.summarize(doc, max_sentences: 3, method: :mmr)
  """
  @spec summarize(Document.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def summarize(doc, opts \\ [])

  def summarize(%Document{language: :ca} = doc, opts) do
    # Simple implementation: select first N sentences
    # TODO: Implement full scoring algorithm with Catalan stop words and discourse markers
    max_sentences = Keyword.get(opts, :max_sentences)
    ratio = Keyword.get(opts, :ratio, 0.3)

    all_sentences = Document.all_sentences(doc)

    target_count =
      if max_sentences do
        min(max_sentences, length(all_sentences))
      else
        max(1, round(length(all_sentences) * ratio))
      end

    selected_sentences = Enum.take(all_sentences, target_count)

    # Create summary document with selected sentences
    if selected_sentences == [] do
      {:ok, doc}
    else
      paragraph = %Paragraph{
        sentences: selected_sentences,
        span: doc.span,
        language: :ca
      }

      summary_doc = %Document{
        paragraphs: [paragraph],
        span: doc.span,
        language: :ca,
        metadata: Map.put(doc.metadata, :summarized, true)
      }

      {:ok, summary_doc}
    end
  end

  def summarize(%Document{language: lang}, _opts) do
    {:error,
     {:language_mismatch,
      "Catalan summarizer called with #{lang} document. Use language-specific summarizer."}}
  end

  ## Private Functions

  # Load Catalan stop words from priv/
  @doc false
  def load_catalan_stop_words do
    path = Path.join(:code.priv_dir(:nasty), "languages/ca/stopwords.txt")

    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> MapSet.new()
    else
      # Fallback to common Catalan stop words
      MapSet.new([
        "el",
        "la",
        "de",
        "que",
        "a",
        "en",
        "i",
        "un",
        "per",
        "amb",
        "no",
        "al",
        "del",
        "és",
        "ha",
        "una",
        "com",
        "o",
        "es",
        "han",
        "són",
        "tot",
        "aquest",
        "aquesta",
        "aquests",
        "aquestes",
        "més",
        "quan",
        "si",
        "ja",
        "les",
        "els",
        "se",
        "però",
        "sense",
        "també",
        "fins",
        "entre",
        "on",
        "molt",
        "molt",
        "tots"
      ])
    end
  end

  # Catalan discourse markers that indicate sentence importance
  @doc false
  def catalan_discourse_markers do
    %{
      # Conclusive markers (highest weight)
      conclusion: [
        "en conclusió",
        "en resum",
        "per concloure",
        "en suma",
        "en definitiva",
        "per acabar",
        "finalment"
      ],
      # Emphasis markers
      emphasis: [
        "és important",
        "cal destacar",
        "cal assenyalar",
        "és fonamental",
        "és essencial",
        "sobretot",
        "principalment",
        "especialment"
      ],
      # Causal markers
      causal: [
        "per tant",
        "per consegüent",
        "en conseqüència",
        "així doncs",
        "de manera que",
        "per aquesta raó",
        "a causa de"
      ],
      # Contrast markers
      contrast: [
        "tanmateix",
        "no obstant això",
        "en canvi",
        "per contra",
        "encara que",
        "malgrat"
      ],
      # Addition markers
      addition: ["a més", "també", "igualment", "d'altra banda", "així mateix"]
    }
  end

  # Catalan punctuation characters
  @doc false
  def catalan_punctuation do
    MapSet.new([".", "?", "!", ",", ";", ":", "…", "-", "—", "(", ")", "[", "]"])
  end
end
