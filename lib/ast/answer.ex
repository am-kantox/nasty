defmodule Nasty.AST.Answer do
  @moduledoc """
  Answer node representing an extracted answer to a question.

  Used by question answering systems to represent candidate answers
  with confidence scores and supporting evidence.
  """

  alias Nasty.AST.{Node, Sentence}

  @typedoc """
  Answer span location within a document.

  The span consists of:
  - `sentence_idx` - Index of the sentence containing the answer
  - `token_start` - Starting token index within the sentence
  - `token_end` - Ending token index (inclusive) within the sentence
  """
  @type answer_span :: {
          sentence_idx :: non_neg_integer(),
          token_start :: non_neg_integer(),
          token_end :: non_neg_integer()
        }

  @type t :: %__MODULE__{
          text: String.t(),
          span: answer_span() | nil,
          confidence: float(),
          source_sentence: Sentence.t() | nil,
          reasoning: String.t() | nil,
          language: Node.language()
        }

  @enforce_keys [:text, :confidence, :language]
  defstruct [
    :text,
    :span,
    :confidence,
    :source_sentence,
    :reasoning,
    :language
  ]

  @doc """
  Creates a new answer.

  ## Examples

      iex> answer = Nasty.AST.Answer.new("John Smith", 0.95, :en)
      iex> answer.text
      "John Smith"
      iex> answer.confidence
      0.95
  """
  @spec new(String.t(), float(), Node.language(), keyword()) :: t()
  def new(text, confidence, language, opts \\ []) do
    %__MODULE__{
      text: text,
      confidence: confidence,
      language: language,
      span: Keyword.get(opts, :span),
      source_sentence: Keyword.get(opts, :source_sentence),
      reasoning: Keyword.get(opts, :reasoning)
    }
  end

  @doc """
  Checks if answer meets a minimum confidence threshold.

  ## Examples

      iex> answer = Nasty.AST.Answer.new("test", 0.8, :en)
      iex> Nasty.AST.Answer.confident?(answer, 0.7)
      true
      iex> Nasty.AST.Answer.confident?(answer, 0.9)
      false
  """
  @spec confident?(t(), float()) :: boolean()
  def confident?(%__MODULE__{confidence: conf}, threshold) when conf >= threshold, do: true
  def confident?(_, _), do: false

  @doc """
  Sorts answers by confidence (highest first).

  ## Examples

      iex> answers = [
      ...>   Nasty.AST.Answer.new("low", 0.3, :en),
      ...>   Nasty.AST.Answer.new("high", 0.9, :en),
      ...>   Nasty.AST.Answer.new("mid", 0.6, :en)
      ...> ]
      iex> sorted = Nasty.AST.Answer.sort_by_confidence(answers)
      iex> Enum.map(sorted, & &1.text)
      ["high", "mid", "low"]
  """
  @spec sort_by_confidence([t()]) :: [t()]
  def sort_by_confidence(answers) do
    Enum.sort_by(answers, & &1.confidence, :desc)
  end
end
