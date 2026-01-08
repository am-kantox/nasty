defmodule Nasty.Language.Spanish do
  @moduledoc """
  Spanish language implementation.

  Provides full NLP pipeline for Spanish text:
  1. Tokenization (NimbleParsec-based with Spanish punctuation)
  2. POS tagging (rule-based with Universal Dependencies tags)
  3. Morphological analysis (lemmatization + features)
  4. Parsing (phrase and sentence structure)
  5. Semantic analysis (NER, coreference, SRL)
  6. NLP operations (summarization, QA, classification)
  """

  @behaviour Nasty.Language.Behaviour

  alias Nasty.AST.{Classification, Document, Paragraph}

  alias Nasty.Language.Spanish.{
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
  def language_code, do: :es

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
    # Full phrase structure parsing with Spanish word order
    with {:ok, analyzed} <- Morphology.analyze(tokens),
         {:ok, sentences} <- SentenceParser.parse_sentences(analyzed, opts) do
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
        language: :es
      }

      # Create base document
      document = %Document{
        paragraphs: [paragraph],
        span: doc_span,
        language: :es,
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
      name: "Spanish",
      native_name: "Español",
      iso_639_1: "es",
      iso_639_3: "spa",
      family: "Indo-European",
      branch: "Romance",
      script: "Latin",
      features: [
        :tokenization,
        :pos_tagging,
        :lemmatization,
        :morphology,
        :semantic_roles,
        :coreference,
        :question_answering,
        :text_classification,
        :summarization
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
  Performs semantic role labeling on a Spanish document.

  Extracts predicate-argument structure for all sentences.

  ## Examples

      iex> {:ok, frames} = Spanish.label_semantic_roles(document)
      iex> is_list(frames)
      true
  """
  @spec label_semantic_roles(Document.t()) ::
          {:ok, [Nasty.AST.Semantic.Frame.t()]} | {:error, term()}
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
  Performs coreference resolution on a Spanish document.

  Links mentions (pronouns, proper names, definite NPs) into coreference chains.

  ## Examples

      iex> {:ok, chains} = Spanish.resolve_coreference(document)
      iex> is_list(chains)
      true
  """
  @spec resolve_coreference(Document.t()) ::
          {:ok, [Nasty.AST.Semantic.CorefChain.t()]} | {:error, term()}
  def resolve_coreference(%Document{} = document) do
    CoreferenceResolver.resolve(document)
  end

  @doc """
  Summarizes a Spanish document by extracting important sentences.

  ## Options

  - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
  - `:max_sentences` - Maximum number of sentences in summary
  - `:min_sentence_length` - Minimum sentence length (in tokens)
  - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)
  - `:mmr_lambda` - MMR diversity parameter, 0-1 (default: 0.5)

  ## Examples

      iex> summary = Spanish.summarize(document, max_sentences: 3)
      iex> is_list(summary)
      true
  """
  @spec summarize(Document.t(), keyword()) :: [Nasty.AST.Sentence.t()]
  def summarize(%Document{} = document, opts \\ []) do
    Summarizer.summarize(document, opts)
  end

  @doc """
  Answers a question based on a Spanish document.

  ## Options

  - `:max_answers` - Maximum number of answers to return (default: 3)
  - `:min_confidence` - Minimum confidence threshold (default: 0.3)
  - `:max_answer_length` - Maximum answer length in tokens (default: 20)

  ## Examples

      iex> {:ok, answers} = Spanish.answer_question(document, "¿Quién fundó Google?")
      iex> is_list(answers)
      true
  """
  @spec answer_question(Document.t(), String.t(), keyword()) ::
          {:ok, [Nasty.AST.Answer.t()]} | {:error, term()}
  def answer_question(%Document{} = document, question_text, opts \\ []) do
    with {:ok, tokens} <- tokenize(question_text),
         {:ok, tagged} <- tag_pos(tokens),
         {:ok, analysis} <- QuestionAnalyzer.analyze(tagged) do
      # Use generic QA engine with Spanish config
      alias Nasty.Language.Spanish.QAConfig
      alias Nasty.Operations.QA.QAEngine

      # Convert analysis to QuestionClassifier struct
      classifier_analysis = %Nasty.Operations.QA.QuestionClassifier{
        type: analysis.type,
        answer_type: analysis.answer_type,
        focus: analysis.focus,
        keywords: analysis.keywords,
        aux_verb: nil
      }

      answers = QAEngine.answer(document, classifier_analysis, QAConfig.config(), opts)
      {:ok, answers}
    end
  end

  @doc """
  Trains a text classifier on labeled Spanish documents.

  ## Options

  - `:features` - Feature types to extract (default: `[:bow]`)
  - `:smoothing` - Smoothing parameter (default: 1.0)
  - `:min_frequency` - Minimum feature frequency (default: 2)

  ## Examples

      iex> training_data = [{spam_doc, :spam}, {ham_doc, :ham}]
      iex> model = Spanish.train_classifier(training_data)
      iex> model.algorithm
      :naive_bayes
  """
  @spec train_classifier([{Document.t(), atom()}], keyword()) ::
          Nasty.AST.ClassificationModel.t()
  def train_classifier(training_data, opts \\ []) do
    TextClassifier.train(training_data, opts)
  end

  @doc """
  Classifies a Spanish document using a trained model.

  Returns classifications sorted by confidence.

  ## Examples

      iex> {:ok, classifications} = Spanish.classify(document, model)
      iex> [top | _rest] = classifications
      iex> is_atom(top.class)
      true
  """
  @spec classify(Document.t(), Nasty.AST.ClassificationModel.t(), keyword()) ::
          {:ok, [Nasty.AST.Classification.t()]} | {:error, term()}
  def classify(%Document{} = document, model, _opts \\ []) do
    # Extract text from document
    text =
      document
      |> Document.all_sentences()
      |> Enum.map_join(" ", &sentence_to_text/1)

    case TextClassifier.classify(text, model) do
      {:ok, class, confidence} ->
        classification = Classification.new(class, confidence, :es)
        {:ok, [classification]}

      error ->
        error
    end
  end

  defp sentence_to_text(_sentence) do
    # Simplified text extraction - would need proper implementation
    ""
  end

  @doc """
  Extracts classification features from a Spanish document.

  ## Options

  - `:features` - Feature types (default: `[:bow, :ngrams]`)
  - `:ngram_size` - N-gram size (default: 2)
  - `:min_frequency` - Minimum frequency (default: 1)

  ## Examples

      iex> features = Spanish.extract_features(document)
      iex> is_map(features)
      true
  """
  @spec extract_features(Document.t(), keyword()) :: map()
  def extract_features(%Document{} = document, _opts \\ []) do
    FeatureExtractor.extract(document)
  end
end
