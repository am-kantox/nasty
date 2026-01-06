defmodule Nasty.Language.English do
  @moduledoc """
  English language implementation.

  Provides full NLP pipeline for English text:
  1. Tokenization (NimbleParsec-based)
  2. POS tagging (rule-based with Universal Dependencies tags)
  3. Morphological analysis (lemmatization + features)
  4. Parsing (placeholder - returns tokens as document)
  """

  @behaviour Nasty.Language.Behaviour

  alias Nasty.AST.{Document, Paragraph}

  alias Nasty.Language.English.{
    CoreferenceResolver,
    Morphology,
    POSTagger,
    SemanticRoleLabeler,
    SentenceParser,
    Tokenizer
  }

  @impl true
  def language_code, do: :en

  @impl true
  def tokenize(text, _opts \\ []) do
    Tokenizer.tokenize(text)
  end

  @impl true
  def tag_pos(tokens, opts \\ []) do
    POSTagger.tag_pos(tokens, opts)
  end

  @impl true
  def parse(tokens, opts \\ []) do
    # Parse takes already-tagged tokens per Language.Behaviour spec
    # Phase 3: Full phrase structure parsing
    with {:ok, analyzed} <- Morphology.analyze(tokens),
         {:ok, sentences} <- SentenceParser.parse_sentences(analyzed) do
      # Calculate document span
      doc_span =
        if Enum.empty?(sentences) do
          # Empty document
          Nasty.AST.Node.make_span({1, 0}, 0, {1, 0}, 0)
        else
          first = hd(sentences)
          last = List.last(sentences)

          Nasty.AST.Node.make_span(
            first.span.start_pos,
            first.span.start_offset,
            last.span.end_pos,
            last.span.end_offset
          )
        end

      # Create paragraph from sentences
      paragraph = %Paragraph{
        sentences: sentences,
        span: doc_span,
        language: :en
      }

      # Create base document
      document = %Document{
        paragraphs: [paragraph],
        span: doc_span,
        language: :en,
        metadata: %{
          source: "parsed",
          token_count: length(analyzed),
          sentence_count: length(sentences),
          tokens: analyzed
        }
      }

      # Optionally run semantic analysis
      document =
        document
        |> maybe_add_semantic_frames(opts)
        |> maybe_add_coreference_chains(opts)

      {:ok, document}
    end
  end

  @impl true
  def render(document, _opts \\ []) do
    # Simple rendering: extract text from tokens stored in document metadata
    tokens = Map.get(document.metadata, :tokens, [])
    text = Enum.map_join(tokens, " ", & &1.text)
    {:ok, text}
  end

  @impl true
  def metadata do
    %{
      name: "English",
      native_name: "English",
      iso_639_1: "en",
      iso_639_3: "eng",
      family: "Indo-European",
      script: "Latin",
      features: [
        :tokenization,
        :pos_tagging,
        :lemmatization,
        :morphology,
        :semantic_roles,
        :coreference
      ],
      version: "0.1.0"
    }
  end

  # Helper: Add semantic role labeling if requested
  defp maybe_add_semantic_frames(document, opts) do
    if Keyword.get(opts, :semantic_roles, false) do
      {:ok, frames} = label_semantic_roles(document)
      %{document | semantic_frames: frames}
    else
      document
    end
  end

  # Helper: Add coreference resolution if requested
  defp maybe_add_coreference_chains(document, opts) do
    if Keyword.get(opts, :coreference, false) do
      {:ok, chains} = resolve_coreference(document)
      %{document | coref_chains: chains}
    else
      document
    end
  end

  @doc """
  Performs semantic role labeling on a document.

  Extracts predicate-argument structure for all sentences.

  ## Examples

      iex> {:ok, frames} = English.label_semantic_roles(document)
      iex> is_list(frames)
      true
  """
  @spec label_semantic_roles(Document.t()) ::
          {:ok, [Nasty.AST.SemanticFrame.t()]} | {:error, term()}
  def label_semantic_roles(%Document{} = document) do
    frames =
      document
      |> Document.all_sentences()
      |> Enum.flat_map(fn sentence ->
        {:ok, sentence_frames} = SemanticRoleLabeler.label(sentence)
        sentence_frames
      end)

    {:ok, frames}
  end

  @doc """
  Performs coreference resolution on a document.

  Links mentions (pronouns, proper names, definite NPs) into coreference chains.

  ## Examples

      iex> {:ok, chains} = English.resolve_coreference(document)
      iex> is_list(chains)
      true
  """
  @spec resolve_coreference(Document.t()) :: {:ok, [Nasty.AST.CorefChain.t()]} | {:error, term()}
  def resolve_coreference(%Document{} = document) do
    CoreferenceResolver.resolve(document)
  end
end
