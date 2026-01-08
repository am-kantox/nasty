defmodule Nasty.Language.Spanish.Adapters.SummarizerAdapter do
  @moduledoc """
  Adapter that bridges Spanish.Summarizer to generic Operations.Summarization.Extractive.

  This adapter provides Spanish-specific configuration while delegating the core
  summarization algorithm to the language-agnostic implementation.

  ## Configuration

  Spanish-specific settings:
  - Stop words from priv/languages/spanish/stopwords.txt
  - Discourse markers in Spanish ("en conclusión", "por lo tanto", etc.)
  - Spanish punctuation and sentence boundaries
  """

  alias Nasty.AST.Document

  @doc """
  Summarize a Spanish document using extractive summarization.

  Delegates to `Operations.Summarization.Extractive` with Spanish configuration.

  ## Options

  - `:ratio` - Compression ratio (0.0-1.0), e.g., 0.3 for 30% of original
  - `:max_sentences` - Maximum number of sentences to extract
  - `:method` - Selection method: `:greedy` (default) or `:mmr`
  - `:mmr_lambda` - MMR lambda parameter (0.0-1.0), default 0.7
  - `:min_sentence_length` - Minimum sentence length in words, default 5

  ## Examples

      iex> {:ok, summary} = SummarizerAdapter.summarize(spanish_doc, ratio: 0.3)
      {:ok, %Document{...}}

      iex> {:ok, summary} = SummarizerAdapter.summarize(spanish_doc, max_sentences: 3, method: :mmr)
      {:ok, %Document{...}}
  """
  @spec summarize(Document.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def summarize(document, opts \\ []) do
    # [TODO]: Implement full behavior-based delegation to Extractive
    # For now, return a simple summary by selecting first N sentences
    max_sentences = Keyword.get(opts, :max_sentences)
    ratio = Keyword.get(opts, :ratio, 0.3)

    all_sentences = Document.all_sentences(document)

    target_count =
      if max_sentences do
        min(max_sentences, length(all_sentences))
      else
        max(1, round(length(all_sentences) * ratio))
      end

    selected_sentences = Enum.take(all_sentences, target_count)

    # Create summary document with selected sentences
    if selected_sentences == [] do
      {:ok, document}
    else
      _first_sent = hd(selected_sentences)
      _last_sent = List.last(selected_sentences)

      paragraph = %Nasty.AST.Paragraph{
        sentences: selected_sentences,
        span: document.span,
        language: :es
      }

      summary_doc = %Document{
        paragraphs: [paragraph],
        span: document.span,
        language: :es,
        metadata: document.metadata
      }

      {:ok, summary_doc}
    end
  end

  ## Private Functions

  # Load Spanish stop words from priv/
  @doc false
  def load_spanish_stop_words do
    path = Path.join(:code.priv_dir(:nasty), "languages/spanish/stopwords.txt")

    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> MapSet.new()
    else
      # Fallback to common Spanish stop words
      MapSet.new([
        "el",
        "la",
        "de",
        "que",
        "y",
        "a",
        "en",
        "un",
        "ser",
        "se",
        "no",
        "haber",
        "por",
        "con",
        "su",
        "para",
        "como",
        "estar",
        "tener",
        "le",
        "lo",
        "todo",
        "pero",
        "más",
        "hacer",
        "o",
        "poder",
        "decir",
        "este",
        "ir",
        "otro",
        "ese",
        "la",
        "si",
        "me",
        "ya",
        "ver",
        "porque",
        "dar",
        "cuando",
        "él",
        "muy",
        "sin",
        "vez",
        "mucho",
        "saber",
        "qué",
        "sobre",
        "mi",
        "alguno",
        "mismo",
        "yo",
        "también",
        "hasta",
        "año",
        "dos",
        "querer",
        "entre",
        "así",
        "primero",
        "desde",
        "grande",
        "eso",
        "ni",
        "nos",
        "llegar",
        "pasar",
        "tiempo",
        "ella",
        "sí",
        "día",
        "uno",
        "bien",
        "poco",
        "deber",
        "entonces",
        "poner",
        "cosa",
        "tanto",
        "hombre",
        "parecer",
        "nuestro",
        "tan",
        "donde",
        "ahora",
        "parte",
        "después",
        "vida",
        "quedar",
        "siempre",
        "creer",
        "hablar",
        "llevar",
        "dejar",
        "nada",
        "cada",
        "seguir",
        "menos",
        "nuevo",
        "encontrar",
        "algo",
        "solo",
        "decir",
        "estos",
        "trabajar",
        "primero",
        "último",
        "largo",
        "propio",
        "la",
        "tener",
        "puerta",
        "creer",
        "país"
      ])
    end
  end

  # Spanish discourse markers that indicate sentence importance
  @doc false
  def spanish_discourse_markers do
    %{
      # Conclusive markers (highest weight)
      conclusion: [
        "en conclusión",
        "en resumen",
        "para concluir",
        "en suma",
        "en definitiva",
        "por último",
        "finalmente"
      ],
      # Emphasis markers
      emphasis: [
        "es importante",
        "cabe destacar",
        "hay que señalar",
        "es fundamental",
        "es esencial",
        "sobre todo",
        "principalmente",
        "especialmente"
      ],
      # Causal markers
      causal: [
        "por lo tanto",
        "por consiguiente",
        "en consecuencia",
        "así pues",
        "de modo que",
        "por esta razón",
        "debido a"
      ],
      # Contrast markers
      contrast: [
        "sin embargo",
        "no obstante",
        "por el contrario",
        "en cambio",
        "aunque",
        "a pesar de"
      ],
      # Addition markers
      addition: ["además", "asimismo", "también", "igualmente", "por otra parte"]
    }
  end

  # Spanish punctuation characters
  @doc false
  def spanish_punctuation do
    MapSet.new([".", "?", "!", ",", ";", ":", "¿", "¡", "…", "-", "—", "(", ")", "[", "]"])
  end
end
