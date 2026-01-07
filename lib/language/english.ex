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
    EventExtractor,
    FeatureExtractor,
    Morphology,
    POSTagger,
    QuestionAnalyzer,
    RelationExtractor,
    SemanticRoleLabeler,
    SentenceParser,
    Summarizer,
    TemplateExtractor,
    TextClassifier,
    Tokenizer
  }

  alias Nasty.Interop.CodeGen.Elixir, as: ElixirCodeGen
  alias Nasty.Interop.CodeGen.Explain
  alias Nasty.Interop.{IntentRecognizer, RagexBridge}

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
    # Options can include :model => :pcfg for statistical parsing
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
        :text_classification,
        :information_extraction
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
  Performs coreference resolution on a document.

  Links mentions (pronouns, proper names, definite NPs) into coreference chains.

  ## Examples

      iex> {:ok, chains} = English.resolve_coreference(document)
      iex> is_list(chains)
      true
  """
  @spec resolve_coreference(Document.t()) ::
          {:ok, [Nasty.AST.Semantic.CorefChain.t()]} | {:error, term()}
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

  @doc """
  Extracts semantic relations between entities in a document.

  ## Options

  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:max_relations` - Maximum relations to return (default: unlimited)
  - `:relation_types` - List of relation types to extract (default: all)

  ## Examples

      iex> {:ok, document} = English.parse(tokens)
      iex> {:ok, relations} = English.extract_relations(document)
      iex> hd(relations).type
      :works_at
  """
  @spec extract_relations(Document.t(), keyword()) :: {:ok, [Nasty.AST.Relation.t()]}
  def extract_relations(%Document{} = document, opts \\ []) do
    RelationExtractor.extract(document, opts)
  end

  @doc """
  Extracts events from a document.

  ## Options

  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:max_events` - Maximum events to return (default: unlimited)
  - `:event_types` - List of event types to extract (default: all)

  ## Examples

      iex> {:ok, document} = English.parse(tokens)
      iex> {:ok, events} = English.extract_events(document)
      iex> hd(events).type
      :business_acquisition
  """
  @spec extract_events(Document.t(), keyword()) :: {:ok, [Nasty.AST.Event.t()]}
  def extract_events(%Document{} = document, opts \\ []) do
    EventExtractor.extract(document, opts)
  end

  @doc """
  Extracts information using templates.

  ## Arguments

  - `document` - Document to extract from
  - `templates` - List of template definitions
  - `opts` - Options

  ## Options

  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:max_results` - Maximum results to return (default: unlimited)

  ## Examples

      iex> templates = [TemplateExtractor.employment_template()]
      iex> {:ok, results} = English.extract_templates(document, templates)
      iex> hd(results).template
      "employment"
  """
  @spec extract_templates(Document.t(), [TemplateExtractor.template()], keyword()) ::
          {:ok, [TemplateExtractor.extraction_result()]}
  def extract_templates(%Document{} = document, templates, opts \\ []) do
    TemplateExtractor.extract(document, templates, opts)
  end

  # Code Interoperability

  @doc """
  Converts natural language to Elixir code.

  Takes a natural language command and generates executable Elixir code.

  ## Options

  - `:enhance_with_ragex` - Use Ragex for context-aware suggestions (default: false)

  ## Examples

      iex> {:ok, code} = English.to_code("Sort the numbers")
      iex> code
      "Enum.sort(numbers)"

      iex> {:ok, code} = English.to_code("Filter users where age is greater than 18")
      iex> code
      "Enum.filter(users, fn item -> item > 18 end)"
  """
  @spec to_code(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_code(text, opts \\ []) when is_binary(text) do
    with {:ok, intent} <- IntentRecognizer.recognize_from_text(text, language: :en),
         intent <- maybe_enhance_with_ragex(intent, opts),
         do: ElixirCodeGen.generate_string(intent, opts)
  end

  @doc """
  Converts natural language to Elixir AST.

  Similar to `to_code/2` but returns the Elixir AST instead of a string.

  ## Examples

      iex> {:ok, ast} = English.to_code_ast("Sort the list")
      iex> Macro.to_string(ast)
      "Enum.sort(list)"
  """
  @spec to_code_ast(String.t(), keyword()) :: {:ok, Macro.t()} | {:error, term()}
  def to_code_ast(text, opts \\ []) when is_binary(text) do
    with {:ok, intent} <- IntentRecognizer.recognize_from_text(text, language: :en),
         intent <- maybe_enhance_with_ragex(intent, opts),
         do: ElixirCodeGen.generate(intent, opts)
  end

  @doc """
  Explains Elixir code in natural language.

  Takes Elixir code (string or AST) and generates a natural language explanation.

  ## Examples

      iex> {:ok, explanation} = English.explain_code("Enum.sort(numbers)")
      iex> explanation
      "sort numbers"

      iex> {:ok, explanation} = English.explain_code("x = 5")
      iex> explanation
      "X is 5"
  """
  @spec explain_code(String.t() | Macro.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def explain_code(code, opts \\ []) do
    Explain.explain_code(code, opts)
  end

  @doc """
  Explains Elixir code and returns a natural language AST Document.

  ## Examples

      iex> ast = quote do: Enum.sort(list)
      iex> {:ok, document} = English.explain_code_to_document(ast)
      iex> document.language
      :en
  """
  @spec explain_code_to_document(Macro.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def explain_code_to_document(ast, opts \\ []) do
    Explain.explain_ast_to_document(ast, opts)
  end

  @doc """
  Recognizes intent from natural language text.

  This is a lower-level function that extracts the semantic intent
  without generating code. Useful for understanding what action
  the user wants to perform.

  ## Examples

      iex> {:ok, intent} = English.recognize_intent("Sort the numbers")
      iex> intent.type
      :action
      iex> intent.action
      "sort"
  """
  @spec recognize_intent(String.t(), keyword()) :: {:ok, Nasty.AST.Intent.t()} | {:error, term()}
  def recognize_intent(text, opts \\ []) when is_binary(text) do
    IntentRecognizer.recognize_from_text(text, Keyword.put(opts, :language, :en))
  end

  # Private helper for Ragex integration
  defp maybe_enhance_with_ragex(intent, opts) do
    if Keyword.get(opts, :enhance_with_ragex, false) and RagexBridge.available?() do
      case RagexBridge.enhance_intent(intent) do
        {:ok, enhanced} -> enhanced
        {:error, _} -> intent
      end
    else
      intent
    end
  end
end
