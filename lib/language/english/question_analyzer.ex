defmodule Nasty.Language.English.QuestionAnalyzer do
  @moduledoc """
  English question analysis for Question Answering.

  Thin wrapper around generic question classifier with English-specific configuration.
  Classifies questions by interrogative word and determines expected answer type.
  """

  alias Nasty.AST.Token
  alias Nasty.Language.English.QAConfig
  alias Nasty.Operations.QA.QuestionClassifier

  @typedoc """
  Question type based on interrogative word.
  """
  @type question_type :: :who | :what | :when | :where | :why | :how | :which | :yes_no

  @typedoc """
  Expected answer type for the question.
  """
  @type answer_type ::
          :person | :location | :time | :thing | :reason | :manner | :quantity | :boolean

  @type t :: %__MODULE__{
          type: question_type(),
          answer_type: answer_type(),
          focus: Token.t() | nil,
          keywords: [Token.t()],
          aux_verb: Token.t() | nil
        }

  defstruct type: nil, answer_type: nil, focus: nil, keywords: [], aux_verb: nil

  @doc """
  Analyzes a question to extract type, expected answer type, and keywords.

  Delegates to generic question classifier with English configuration.
  """
  @spec analyze([Token.t()]) :: {:ok, t()} | {:error, term()}
  def analyze(tokens) do
    case QuestionClassifier.classify(tokens, QAConfig.config()) do
      {:ok, %QuestionClassifier{} = analysis} ->
        # Convert to this module's struct for API compatibility
        result = %__MODULE__{
          type: analysis.type,
          answer_type: analysis.answer_type,
          focus: analysis.focus,
          keywords: analysis.keywords,
          aux_verb: analysis.aux_verb
        }

        {:ok, result}

      error ->
        error
    end
  end

  @doc """
  Checks if a question expects a specific entity type.

  Delegates to QA config.
  """
  @spec expects_entity_type?(t(), atom()) :: boolean()
  def expects_entity_type?(%__MODULE__{answer_type: answer_type}, entity_type) do
    QAConfig.expects_entity_type?(answer_type, entity_type)
  end

  @doc """
  Returns a human-readable description of the question analysis.
  """
  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{type: type, answer_type: answer_type}) do
    type_str = type |> to_string() |> String.upcase()
    answer_str = answer_type |> to_string() |> String.upcase()
    "#{type_str} question expecting #{answer_str} answer"
  end
end
