defmodule Nasty.Operations.QA.QAEngine do
  @moduledoc """
  Generic Question Answering engine.

  Coordinates the full QA pipeline:
  1. Classify question → identify type and expected answer
  2. Score sentences → rank by relevance
  3. Extract candidates → find answers in top sentences
  4. Sort and filter → return top N answers
  """

  alias Nasty.AST.{Answer, Document, Paragraph}
  alias Nasty.Operations.QA.{AnswerSelector, CandidateScorer, QuestionClassifier}

  @doc """
  Answers a question from a document.

  ## Options
  - `:max_answers` - Maximum number of answers to return (default: 3)
  - `:min_confidence` - Minimum confidence threshold (default: 0.1)
  - `:max_sentences` - Maximum sentences to extract from (default: 10)

  ## Returns
  List of Answer structs, sorted by confidence (highest first)
  """
  @spec answer(Document.t(), QuestionClassifier.t(), map(), keyword()) :: [Answer.t()]
  def answer(%Document{paragraphs: paragraphs} = document, question_analysis, config, opts \\ []) do
    max_answers = Keyword.get(opts, :max_answers, 3)
    min_confidence = Keyword.get(opts, :min_confidence, 0.1)
    max_sentences = Keyword.get(opts, :max_sentences, 10)

    # Extract all sentences with indices
    sentences =
      paragraphs
      |> Enum.flat_map(fn %Paragraph{sentences: sents} -> sents end)
      |> Enum.with_index()

    # Score each sentence for relevance
    scored_sentences =
      sentences
      |> Enum.map(fn {sentence, idx} ->
        score = CandidateScorer.score_sentence(sentence, question_analysis, sentences, config)
        {sentence, idx, score}
      end)
      |> Enum.sort_by(fn {_sent, _idx, score} -> -score end)
      |> Enum.take(max_sentences)

    # Extract answer candidates from top sentences
    answers =
      scored_sentences
      |> Enum.flat_map(fn {sentence, idx, sent_score} ->
        AnswerSelector.extract_candidates(
          sentence,
          idx,
          question_analysis,
          sent_score,
          document,
          config
        )
      end)
      |> Enum.filter(fn answer -> answer.confidence >= min_confidence end)
      |> Answer.sort_by_confidence()
      |> Enum.take(max_answers)

    answers
  end
end
