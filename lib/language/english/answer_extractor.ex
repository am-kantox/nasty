defmodule Nasty.Language.English.AnswerExtractor do
  @moduledoc """
  Extracts answer spans from a document based on question analysis.

  Uses keyword matching, entity type filtering, and semantic role information
  to identify relevant passages and extract concise answers.
  """

  alias Nasty.AST.{Answer, Document, Paragraph, Sentence, Token}
  alias Nasty.Language.English.{EntityRecognizer, QuestionAnalyzer}

  # Stop words for TF calculation
  @stop_words ~w(
    a an the this that these those
    is are was were be been being
    have has had having
    do does did doing
    will would shall should may might can could must
    i me my mine you your yours he him his she her hers it its
    we us our ours they them their theirs
    in on at by for with from to of about
    and or but nor
  )

  @doc """
  Extracts answers from a document based on question analysis.

  ## Options

  - `:max_answers` - Maximum number of answers to return (default: 3)
  - `:min_confidence` - Minimum confidence threshold (default: 0.2)
  - `:max_answer_length` - Maximum answer length in tokens (default: 20)

  ## Examples

      iex> document = parse_document("John Smith founded Google in 1998.")
      iex> question_analysis = %QuestionAnalyzer{type: :who, answer_type: :person, keywords: [...]}
      iex> answers = AnswerExtractor.extract(document, question_analysis)
      [%Answer{text: "John Smith", confidence: 0.85, ...}]
  """
  @spec extract(Document.t(), QuestionAnalyzer.t(), keyword()) :: [Answer.t()]
  def extract(%Document{paragraphs: paragraphs} = document, question_analysis, opts \\ []) do
    max_answers = Keyword.get(opts, :max_answers, 3)
    min_confidence = Keyword.get(opts, :min_confidence, 0.1)

    # Extract all sentences with indices
    sentences =
      paragraphs
      |> Enum.flat_map(fn %Paragraph{sentences: sents} -> sents end)
      |> Enum.with_index()

    # Score each sentence
    scored_sentences =
      sentences
      |> Enum.map(fn {sentence, idx} ->
        score = score_sentence(sentence, question_analysis, sentences)
        {sentence, idx, score}
      end)
      |> Enum.sort_by(fn {_sent, _idx, score} -> -score end)
      |> Enum.take(10)

    # Extract answer candidates from top sentences
    answers =
      scored_sentences
      |> Enum.flat_map(fn {sentence, idx, sent_score} ->
        extract_answer_candidates(sentence, idx, question_analysis, sent_score, document)
      end)
      |> Enum.filter(fn answer -> answer.confidence >= min_confidence end)
      |> Answer.sort_by_confidence()
      |> Enum.take(max_answers)

    answers
  end

  # Score a sentence for relevance to the question
  defp score_sentence(sentence, question_analysis, all_sentences) do
    keyword_score = keyword_match_score(sentence, question_analysis)
    entity_score = entity_type_score(sentence, question_analysis)
    position_score = position_score(sentence, all_sentences)

    # Weighted combination - keyword matching is most important
    # Give base score even with no keyword matches to allow fallback
    base = 0.1
    base + keyword_score * 0.6 + entity_score * 0.2 + position_score * 0.2
  end

  # Score based on keyword overlap
  defp keyword_match_score(sentence, %QuestionAnalyzer{keywords: keywords}) do
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

  # Score based on expected entity type
  defp entity_type_score(sentence, %QuestionAnalyzer{answer_type: answer_type}) do
    tokens = extract_sentence_tokens(sentence)
    entities = EntityRecognizer.recognize(tokens)

    relevant_entities =
      Enum.count(entities, fn entity ->
        QuestionAnalyzer.expects_entity_type?(
          %QuestionAnalyzer{answer_type: answer_type, type: :unknown, keywords: [], focus: nil},
          entity.type
        )
      end)

    case relevant_entities do
      0 -> 0.0
      1 -> 0.6
      2 -> 0.9
      _ -> 1.0
    end
  end

  # Score based on position (earlier sentences preferred slightly)
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

  # Extract answer candidates from a sentence
  defp extract_answer_candidates(
         sentence,
         sent_idx,
         question_analysis,
         base_score,
         document
       ) do
    # Try specific extractors first, then fallback to NPs
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
          extract_temporal_answers(sentence, sent_idx, base_score, document)

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

  # Extract noun phrase answers
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
  defp extract_temporal_answers(sentence, sent_idx, base_score, document) do
    tokens = extract_sentence_tokens(sentence)

    # Look for years, dates, temporal nouns, numbers that could be years
    temporal_tokens =
      Enum.filter(tokens, fn token ->
        # Match 4-digit years or common temporal words
        String.match?(token.text, ~r/^\d{4}$/) or
          String.match?(token.text, ~r/^\d{1,2}$/) or
          String.downcase(token.lemma) in ~w(year month day today yesterday tomorrow week monday tuesday wednesday thursday friday saturday sunday january february march april may june july august september october november december)
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
