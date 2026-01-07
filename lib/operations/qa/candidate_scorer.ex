defmodule Nasty.Operations.QA.CandidateScorer do
  @moduledoc """
  Generic sentence scoring for Question Answering.

  Scores sentences for relevance to a question using:
  - Keyword matching (lemma overlap)
  - Entity type matching (expected answer type)
  - Position bias (earlier sentences preferred)
  """

  alias Nasty.AST.Sentence
  alias Nasty.Language.English.EntityRecognizer
  alias Nasty.Operations.QA.QuestionClassifier

  @doc """
  Scores a sentence for relevance to a question.

  Returns a score between 0.0 and 1.0+, where higher scores indicate
  more relevant sentences.

  ## Scoring Components
  - Base score: 0.1 (allows fallback even with no keyword matches)
  - Keyword match: 0.6 weight
  - Entity type: 0.2 weight
  - Position: 0.2 weight
  """
  @spec score_sentence(
          Sentence.t(),
          QuestionClassifier.t(),
          [{Sentence.t(), integer()}],
          map()
        ) :: float()
  def score_sentence(sentence, question_analysis, all_sentences, _config) do
    keyword_score = keyword_match_score(sentence, question_analysis)
    entity_score = entity_type_score(sentence, question_analysis)
    position_score = position_score(sentence, all_sentences)

    # Weighted combination - keyword matching is most important
    base = 0.1
    base + keyword_score * 0.6 + entity_score * 0.2 + position_score * 0.2
  end

  # Score based on keyword overlap with question
  defp keyword_match_score(sentence, %QuestionClassifier{keywords: keywords}) do
    sentence_tokens = extract_sentence_tokens(sentence)
    sentence_lemmas = MapSet.new(sentence_tokens, & &1.lemma)
    question_lemmas = MapSet.new(keywords, & &1.lemma)

    if MapSet.size(question_lemmas) == 0 do
      0.0
    else
      overlap = MapSet.intersection(sentence_lemmas, question_lemmas) |> MapSet.size()
      overlap / MapSet.size(question_lemmas)
    end
  end

  # Score based on expected entity type presence
  defp entity_type_score(sentence, %QuestionClassifier{answer_type: answer_type}) do
    tokens = extract_sentence_tokens(sentence)
    entities = EntityRecognizer.recognize(tokens)

    # Count entities matching expected answer type
    relevant_entities =
      Enum.count(entities, fn entity ->
        entity_type_matches?(answer_type, entity.type)
      end)

    case relevant_entities do
      0 -> 0.0
      1 -> 0.6
      2 -> 0.9
      _ -> 1.0
    end
  end

  # Check if entity type matches expected answer type
  defp entity_type_matches?(answer_type, entity_type) do
    case {answer_type, entity_type} do
      {:person, :person} -> true
      {:location, :gpe} -> true
      {:location, :loc} -> true
      {:thing, :org} -> true
      _ -> false
    end
  end

  # Score based on position (earlier sentences preferred)
  defp position_score(sentence, all_sentences) do
    total = length(all_sentences)

    position =
      Enum.find_index(all_sentences, fn {sent, _idx} ->
        sent == sentence
      end) || 0

    cond do
      position < total * 0.2 -> 1.0
      position < total * 0.5 -> 0.8
      true -> 0.6
    end
  end

  # Extract all tokens from a sentence
  defp extract_sentence_tokens(%Sentence{main_clause: clause, additional_clauses: additional}) do
    main_tokens = extract_clause_tokens(clause)
    additional_tokens = Enum.flat_map(additional, &extract_clause_tokens/1)
    main_tokens ++ additional_tokens
  end

  defp extract_clause_tokens(%{subject: subj, predicate: pred}) do
    subj_tokens = if subj, do: extract_phrase_tokens(subj), else: []
    pred_tokens = extract_phrase_tokens(pred)
    subj_tokens ++ pred_tokens
  end

  defp extract_phrase_tokens(%{head: head, determiner: det, modifiers: mods}) do
    tokens = [head | mods]
    if det, do: [det | tokens], else: tokens
  end

  defp extract_phrase_tokens(%{head: head, auxiliaries: aux}) do
    [head | aux]
  end

  defp extract_phrase_tokens(%{head: head}) do
    [head]
  end

  defp extract_phrase_tokens(_), do: []
end
