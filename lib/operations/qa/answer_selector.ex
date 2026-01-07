defmodule Nasty.Operations.QA.AnswerSelector do
  @moduledoc """
  Generic answer candidate extraction for Question Answering.

  Extracts answer candidates from sentences based on question type:
  - Entity-based answers (person, location, organization)
  - Temporal answers (dates, years, times)
  - Number/quantity answers
  - Clause-based answers (reason, manner)
  - Noun phrase answers (fallback)
  """

  alias Nasty.AST.{Answer, Document, Sentence}
  alias Nasty.Language.English.EntityRecognizer
  alias Nasty.Operations.QA.QuestionClassifier

  @typedoc """
  Language configuration for answer selection.

  Required fields:
  - `temporal_patterns` - List of regex patterns for temporal expressions
  - `temporal_keywords` - List of temporal keywords (year, month, day, etc.)
  """
  @type language_config :: %{
          temporal_patterns: [Regex.t()],
          temporal_keywords: [String.t()]
        }

  @doc """
  Extracts answer candidates from a sentence based on question analysis.

  Returns a list of Answer structs with confidence scores.
  """
  @spec extract_candidates(
          Sentence.t(),
          integer(),
          QuestionClassifier.t(),
          float(),
          Document.t(),
          language_config()
        ) :: [Answer.t()]
  def extract_candidates(sentence, sent_idx, question_analysis, base_score, document, config) do
    # Try specific extractors first based on answer type
    answers =
      case question_analysis.answer_type do
        :person ->
          extract_entity_answers(sentence, sent_idx, :person, base_score, document)

        :location ->
          extract_entity_answers(sentence, sent_idx, :gpe, base_score, document) ++
            extract_entity_answers(sentence, sent_idx, :loc, base_score, document)

        :thing ->
          extract_entity_answers(sentence, sent_idx, :org, base_score, document)

        :time ->
          extract_temporal_answers(sentence, sent_idx, base_score, document, config)

        :reason ->
          extract_clause_answers(sentence, sent_idx, base_score, document, :reason)

        :manner ->
          extract_clause_answers(sentence, sent_idx, base_score, document, :manner)

        :quantity ->
          extract_number_answers(sentence, sent_idx, base_score, document)

        _ ->
          []
      end

    # If no specific answers found, fallback to noun phrases
    if answers == [] do
      extract_noun_phrase_answers(sentence, sent_idx, base_score, document)
    else
      answers
    end
  end

  # Extract entity-based answers
  defp extract_entity_answers(sentence, sent_idx, entity_type, base_score, document) do
    tokens = extract_sentence_tokens(sentence)
    entities = EntityRecognizer.recognize(tokens)

    entity_answers =
      entities
      |> Enum.filter(&(&1.type == entity_type))
      |> Enum.map(fn entity ->
        confidence = base_score * (entity.confidence || 0.8)

        Answer.new(entity.text, confidence, document.language,
          span: {sent_idx, 0, 0},
          source_sentence: sentence,
          reasoning: "Entity match: #{entity.type}"
        )
      end)

    # Always add proper nouns as potential answers for person/location
    proper_noun_answers =
      if entity_type in [:person, :gpe, :loc] do
        tokens
        |> Enum.filter(&(&1.pos_tag == :propn))
        |> Enum.take(5)
        |> Enum.map(fn token ->
          # Boost confidence if it's also an entity
          conf =
            if entity_answers != [] and
                 Enum.any?(entity_answers, &String.contains?(&1.text, token.text)),
               do: base_score * 0.9,
               else: base_score * 0.7

          Answer.new(token.text, conf, document.language,
            span: {sent_idx, 0, 0},
            source_sentence: sentence,
            reasoning: "Proper noun (#{entity_type})"
          )
        end)
      else
        []
      end

    entity_answers ++ proper_noun_answers
  end

  # Extract noun phrase answers (fallback)
  defp extract_noun_phrase_answers(sentence, sent_idx, base_score, document) do
    # Extract NPs from clause subject
    nps =
      case sentence.main_clause.subject do
        nil -> []
        subject -> [subject]
      end

    nps
    |> Enum.map(fn np ->
      text = np.head.text

      Answer.new(text, base_score * 0.7, document.language,
        span: {sent_idx, 0, 0},
        source_sentence: sentence,
        reasoning: "Noun phrase match"
      )
    end)
  end

  # Extract temporal expressions
  defp extract_temporal_answers(sentence, sent_idx, base_score, document, config) do
    tokens = extract_sentence_tokens(sentence)
    temporal_patterns = config.temporal_patterns
    temporal_keywords = config.temporal_keywords

    # Look for years, dates, temporal nouns, numbers that could be years
    temporal_tokens =
      Enum.filter(tokens, fn token ->
        text = token.text
        lemma_lower = String.downcase(token.lemma)

        # Match patterns or keywords
        Enum.any?(temporal_patterns, &String.match?(text, &1)) or
          lemma_lower in temporal_keywords
      end)

    answers =
      temporal_tokens
      |> Enum.map(fn token ->
        # Higher confidence for 4-digit years
        conf =
          if String.match?(token.text, ~r/^\d{4}$/),
            do: base_score * 0.8,
            else: base_score * 0.5

        Answer.new(token.text, conf, document.language,
          span: {sent_idx, 0, 0},
          source_sentence: sentence,
          reasoning: "Temporal expression"
        )
      end)

    # Fallback: if no temporal tokens, return numbers as potential dates
    if answers == [] do
      tokens
      |> Enum.filter(fn token -> String.match?(token.text, ~r/^\d+$/) end)
      |> Enum.take(2)
      |> Enum.map(fn token ->
        Answer.new(token.text, base_score * 0.4, document.language,
          span: {sent_idx, 0, 0},
          source_sentence: sentence,
          reasoning: "Number (potential date)"
        )
      end)
    else
      answers
    end
  end

  # Extract clause-based answers (for WHY, HOW)
  defp extract_clause_answers(sentence, sent_idx, base_score, document, type) do
    # For now, return the predicate as the answer
    # Future: extract subordinate clauses, PPs
    predicate_text = sentence.main_clause.predicate.head.text

    [
      Answer.new(predicate_text, base_score * 0.5, document.language,
        span: {sent_idx, 0, 0},
        source_sentence: sentence,
        reasoning: "#{type} clause"
      )
    ]
  end

  # Extract number/quantity answers
  defp extract_number_answers(sentence, sent_idx, base_score, document) do
    tokens = extract_sentence_tokens(sentence)

    number_tokens =
      Enum.filter(tokens, fn token ->
        String.match?(token.text, ~r/^\d+(\.\d+)?$/) or token.pos_tag == :num
      end)

    number_tokens
    |> Enum.map(fn token ->
      Answer.new(token.text, base_score * 0.7, document.language,
        span: {sent_idx, 0, 0},
        source_sentence: sentence,
        reasoning: "Quantity"
      )
    end)
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
