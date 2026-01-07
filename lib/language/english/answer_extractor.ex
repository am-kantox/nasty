defmodule Nasty.Language.English.AnswerExtractor do
  @moduledoc """
  English answer extraction for Question Answering.

  Thin wrapper around generic QA engine with English-specific configuration.
  Extracts answer spans from documents based on question analysis.
  """

  alias Nasty.AST.{Answer, Document}
  alias Nasty.Language.English.{QAConfig, QuestionAnalyzer}
  alias Nasty.Operations.QA.QAEngine

  @doc """
  Extracts answers from a document based on question analysis.

  Delegates to generic QA engine with English configuration.

  ## Options

  - `:max_answers` - Maximum number of answers to return (default: 3)
  - `:min_confidence` - Minimum confidence threshold (default: 0.1)
  - `:max_sentences` - Maximum sentences to extract from (default: 10)

  ## Examples

      iex> document = parse_document("John Smith founded Google in 1998.")
      iex> question_analysis = %QuestionAnalyzer{type: :who, answer_type: :person, keywords: [...]}
      iex> answers = AnswerExtractor.extract(document, question_analysis)
      [%Answer{text: "John Smith", confidence: 0.85, ...}]
  """
  @spec extract(Document.t(), QuestionAnalyzer.t(), keyword()) :: [Answer.t()]
  def extract(%Document{} = document, %QuestionAnalyzer{} = question_analysis, opts \\ []) do
    # Convert QuestionAnalyzer struct to QuestionClassifier struct for generic engine
    classifier_analysis = %Nasty.Operations.QA.QuestionClassifier{
      type: question_analysis.type,
      answer_type: question_analysis.answer_type,
      focus: question_analysis.focus,
      keywords: question_analysis.keywords,
      aux_verb: question_analysis.aux_verb
    }

    QAEngine.answer(document, classifier_analysis, QAConfig.config(), opts)
  end
end
