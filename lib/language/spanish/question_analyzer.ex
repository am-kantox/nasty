defmodule Nasty.Language.Spanish.QuestionAnalyzer do
  @moduledoc """
  Analyzes Spanish questions and finds answers in documents.

  Identifies question type, expected answer type, and searches
  for matching answer spans in the provided context.

  ## Spanish Question Types

  - ¿Quién? (who) → person names
  - ¿Qué? (what) → entities, objects
  - ¿Dónde? (where) → locations
  - ¿Cuándo? (when) → dates, times
  - ¿Por qué? (why) → reasons, causes
  - ¿Cómo? (how) → manner, methods
  - ¿Cuánto? (how much/many) → quantities

  ## Example

      iex> context = parse("Juan García nació en Madrid en 1990")
      iex> question = "¿Quién nació en Madrid?"
      iex> answer = QuestionAnalyzer.answer(question, context)
      %{
        answer: "Juan García",
        confidence: 0.95,
        type: :person,
        span: %{start_pos: {1, 1}, end_pos: {1, 12}}
      }
  """

  alias Nasty.AST.Document
  alias Nasty.Language.Spanish.QAConfig
  alias Nasty.Operations.QA.QAEngine

  @doc """
  Analyzes a Spanish question and extracts its type, focus, and keywords.

  Returns a question analysis struct for answer extraction.
  """
  @spec analyze(list()) :: {:ok, map()} | {:error, term()}
  def analyze(tagged_tokens) do
    # Extract question words and determine type
    question_text = Enum.map_join(tagged_tokens, " ", & &1.text)
    type = classify(question_text)

    # Extract focus (main content words)
    focus =
      tagged_tokens
      |> Enum.filter(&(&1.pos_tag in [:noun, :verb, :adj]))
      |> Enum.map(& &1.lemma)

    # Extract keywords for matching
    keywords =
      tagged_tokens
      |> Enum.reject(&(&1.pos_tag in [:det, :punct]))
      |> Enum.map(& &1.lemma)

    {:ok,
     %{
       type: type,
       answer_type: QAConfig.get_answer_type(type || :what),
       focus: focus,
       keywords: keywords
     }}
  end

  @doc """
  Answers a Spanish question given a context document.

  Returns a map with answer text, confidence, type, and span.
  """
  @spec answer(String.t(), Document.t()) :: map() | nil
  def answer(question, %Document{language: :es} = context) do
    config = QAConfig.config()
    QAEngine.answer(question, context, config)
  end

  def answer(_question, %Document{language: lang}) do
    raise ArgumentError,
          "Spanish question analyzer called with #{lang} document. Use language-specific analyzer."
  end

  @doc """
  Identifies the type of a Spanish question.
  """
  @spec classify(String.t()) :: atom() | nil
  def classify(question) do
    QAConfig.identify_question_type(question)
  end
end
