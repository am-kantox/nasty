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
    AnswerExtractor,
    CoreferenceResolver,
    FeatureExtractor,
    Morphology,
    POSTagger,
    QuestionAnalyzer,
    SemanticRoleLabeler,
    SentenceParser,
    Summarizer,
    TextClassifier,
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
        :coreference,
        :question_answering,
        :text_classification
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

  @doc """
  Summarizes a document by extracting important sentences.

  ## Options

  - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
  - `:max_sentences` - Maximum number of sentences in summary
  - `:min_sentence_length` - Minimum sentence length (in tokens)
  - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)
  - `:mmr_lambda` - MMR diversity parameter, 0-1 (default: 0.5)

  ## Examples

      iex> document = English.parse("Long text...")
      iex> summary_sentences = English.summarize(document, max_sentences: 3)
      iex> is_list(summary_sentences)
      true

      # With MMR to reduce redundancy
      iex> summary = English.summarize(document, max_sentences: 5, method: :mmr)
      iex> length(summary) <= 5
      true
  """
  @spec summarize(Document.t(), keyword()) :: [Nasty.AST.Sentence.t()]
  def summarize(%Document{} = document, opts \\ []) do
    Summarizer.summarize(document, opts)
  end

  @doc """
  Answers a question based on a document.

  Takes a question as text, analyzes it to determine type and expected answer,
  then searches the document for relevant passages and extracts answer spans.

  ## Options

  - `:max_answers` - Maximum number of answers to return (default: 3)
  - `:min_confidence` - Minimum confidence threshold (default: 0.3)
  - `:max_answer_length` - Maximum answer length in tokens (default: 20)

  ## Examples

      iex> {:ok, document} = English.parse(tagged_tokens)
      iex> {:ok, answers} = English.answer_question(document, "Who founded Google?")
      iex> is_list(answers)
      true

      iex> {:ok, answers} = English.answer_question(document, "When was the company founded?", max_answers: 1)
      iex> hd(answers).answer_type
      :time
  """
  @spec answer_question(Document.t(), String.t(), keyword()) ::
          {:ok, [Nasty.AST.Answer.t()]} | {:error, term()}
  def answer_question(%Document{} = document, question_text, opts \\ []) do
    with {:ok, tokens} <- tokenize(question_text),
         {:ok, tagged} <- tag_pos(tokens),
         {:ok, analysis} <- QuestionAnalyzer.analyze(tagged) do
      answers = AnswerExtractor.extract(document, analysis, opts)
      {:ok, answers}
    end
  end

  @doc """
  Trains a text classifier on labeled documents.

  ## Arguments

  - `training_data` - List of `{document, class}` tuples
  - `opts` - Training options

  ## Options

  - `:features` - Feature types to extract (default: `[:bow]`)
  - `:smoothing` - Smoothing parameter (default: 1.0)
  - `:min_frequency` - Minimum feature frequency (default: 2)

  ## Examples

      iex> training_data = [
      ...>   {spam_doc, :spam},
      ...>   {ham_doc, :ham}
      ...> ]
      iex> model = English.train_classifier(training_data)
      iex> model.algorithm
      :naive_bayes
  """
  @spec train_classifier([{Document.t(), atom()}], keyword()) ::
          Nasty.AST.ClassificationModel.t()
  def train_classifier(training_data, opts \\ []) do
    TextClassifier.train(training_data, opts)
  end

  @doc """
  Classifies a document using a trained model.

  Returns classifications sorted by confidence.

  ## Examples

      iex> {:ok, document} = English.parse(tokens)
      iex> {:ok, classifications} = English.classify(document, model)
      iex> [top | _rest] = classifications
      iex> top.class
      :spam
  """
  @spec classify(Document.t(), Nasty.AST.ClassificationModel.t(), keyword()) ::
          {:ok, [Nasty.AST.Classification.t()]} | {:error, term()}
  def classify(%Document{} = document, model, opts \\ []) do
    TextClassifier.predict(model, document, opts)
  end

  @doc """
  Extracts classification features from a document.

  ## Options

  - `:features` - Feature types (default: `[:bow, :ngrams]`)
  - `:ngram_size` - N-gram size (default: 2)
  - `:min_frequency` - Minimum frequency (default: 1)

  ## Examples

      iex> features = English.extract_features(document)
      iex> is_map(features)
      true
  """
  @spec extract_features(Document.t(), keyword()) :: map()
  def extract_features(%Document{} = document, opts \\ []) do
    FeatureExtractor.extract(document, opts)
  end
end
