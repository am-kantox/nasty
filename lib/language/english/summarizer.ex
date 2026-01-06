defmodule Nasty.Language.English.Summarizer do
  @moduledoc """
  Simple extractive text summarization for English.

  Extracts the most important sentences from a document using scoring heuristics:
  - Position (sentences early in document are more important)
  - Length (prefer moderate-length sentences)
  - Term frequency (sentences with frequent terms are important)
  - Named entities (sentences with entities are more important)
  - Keywords (sentences with keywords/proper nouns)

  ## Approach

  This is a simplified extractive summarization approach. Production systems use:
  - TF-IDF for term importance
  - PageRank/LexRank for sentence connectivity
  - Neural abstractive summarization (T5, BART, etc.)

  ## Examples

      iex> document = parse("The cat sat on the mat. The dog ran in the park. ...")
      iex> summary = Summarizer.summarize(document, ratio: 0.3)
      %Summary{sentences: [...], compression_ratio: 0.3}
  """

  alias Nasty.AST.{Document, Paragraph, Sentence}
  alias Nasty.Language.English.EntityRecognizer

  @doc """
  Summarizes a document by extracting important sentences.

  ## Options

  - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
  - `:max_sentences` - Maximum number of sentences in summary
  - `:min_sentence_length` - Minimum sentence length (in tokens)

  Returns a list of selected sentences in document order.
  """
  @spec summarize(Document.t(), keyword()) :: [Sentence.t()]
  def summarize(%Document{paragraphs: paragraphs}, opts \\ []) do
    ratio = Keyword.get(opts, :ratio, 0.3)
    max_sentences = Keyword.get(opts, :max_sentences)
    min_length = Keyword.get(opts, :min_sentence_length, 3)

    # Extract all sentences from document
    all_sentences = extract_sentences(paragraphs)

    # Filter out very short sentences
    sentences =
      Enum.filter(all_sentences, fn s ->
        sentence_length(s) >= min_length
      end)

    # Calculate how many sentences to include
    target_count =
      if max_sentences do
        min(max_sentences, length(sentences))
      else
        max(1, round(length(sentences) * ratio))
      end

    # Score each sentence
    scored_sentences =
      sentences
      |> Enum.with_index()
      |> Enum.map(fn {sentence, idx} ->
        score = score_sentence(sentence, idx, sentences)
        {sentence, idx, score}
      end)

    # Select top sentences and sort by original order
    scored_sentences
    |> Enum.sort_by(fn {_s, _idx, score} -> -score end)
    |> Enum.take(target_count)
    |> Enum.sort_by(fn {_s, idx, _score} -> idx end)
    |> Enum.map(fn {sentence, _idx, _score} -> sentence end)
  end

  # Extract all sentences from paragraphs
  defp extract_sentences(paragraphs) do
    paragraphs
    |> Enum.flat_map(fn %Paragraph{sentences: sentences} -> sentences end)
  end

  # Calculate sentence length in tokens
  defp sentence_length(%Sentence{main_clause: clause}) do
    # Count all tokens in the sentence
    tokens = extract_tokens_from_clause(clause)
    length(tokens)
  end

  # Score a sentence based on multiple heuristics
  defp score_sentence(sentence, position, all_sentences) do
    position_score = position_score(position, length(all_sentences))
    length_score = length_score(sentence)
    entity_score = entity_score(sentence)
    keyword_score = keyword_score(sentence, all_sentences)

    # Weighted combination
    position_score * 0.3 +
      length_score * 0.2 +
      entity_score * 0.3 +
      keyword_score * 0.2
  end

  # Position score: earlier sentences are more important
  defp position_score(position, total) do
    cond do
      # First sentence is very important
      position == 0 -> 1.0
      # Early sentences
      position < total * 0.2 -> 0.8
      # Middle sentences
      position < total * 0.5 -> 0.5
      # Later sentences
      true -> 0.3
    end
  end

  # Length score: prefer moderate-length sentences
  defp length_score(sentence) do
    length = sentence_length(sentence)

    cond do
      # Too short
      length < 5 -> 0.3
      length < 10 -> 0.7
      # Ideal length
      length < 20 -> 1.0
      length < 30 -> 0.8
      # Too long
      true -> 0.5
    end
  end

  # Entity score: sentences with named entities are more important
  defp entity_score(sentence) do
    tokens = extract_tokens_from_sentence(sentence)
    entities = EntityRecognizer.recognize(tokens)

    case length(entities) do
      0 -> 0.3
      1 -> 0.6
      2 -> 0.9
      # 3+ entities
      _ -> 1.0
    end
  end

  # Keyword score: based on term frequency
  defp keyword_score(sentence, all_sentences) do
    # Build term frequency map for entire document
    doc_tokens =
      all_sentences
      |> Enum.flat_map(&extract_tokens_from_sentence/1)
      |> Enum.map(fn t -> String.downcase(t.text) end)
      |> Enum.filter(fn text ->
        # Filter out stop words and punctuation
        String.length(text) > 2 && text =~ ~r/^[a-z]+$/
      end)

    term_freq = Enum.frequencies(doc_tokens)

    # Calculate sentence score based on term frequencies
    sentence_tokens =
      sentence
      |> extract_tokens_from_sentence()
      |> Enum.map(fn t -> String.downcase(t.text) end)
      |> Enum.filter(fn text -> String.length(text) > 2 && text =~ ~r/^[a-z]+$/ end)

    case sentence_tokens do
      [] ->
        0.0

      _ ->
        total_freq =
          sentence_tokens
          |> Enum.map(fn token -> Map.get(term_freq, token, 0) end)
          |> Enum.sum()

        avg_freq = total_freq / length(sentence_tokens)

        # Normalize to 0-1 range (heuristic)
        min(avg_freq / 3.0, 1.0)
    end
  end

  # Extract all tokens from a sentence
  defp extract_tokens_from_sentence(%Sentence{
         main_clause: clause,
         additional_clauses: additional
       }) do
    main_tokens = extract_tokens_from_clause(clause)
    additional_tokens = Enum.flat_map(additional, &extract_tokens_from_clause/1)
    main_tokens ++ additional_tokens
  end

  defp extract_tokens_from_clause(%{subject: subj, predicate: pred}) do
    subj_tokens = if subj, do: extract_tokens_from_phrase(subj), else: []
    pred_tokens = extract_tokens_from_phrase(pred)
    subj_tokens ++ pred_tokens
  end

  defp extract_tokens_from_phrase(%{
         head: head,
         determiner: det,
         modifiers: mods,
         post_modifiers: _post
       }) do
    tokens = [head | mods]
    if det, do: [det | tokens], else: tokens
  end

  defp extract_tokens_from_phrase(%{head: head, auxiliaries: aux, complements: _comps}) do
    [head | aux]
  end

  defp extract_tokens_from_phrase(%{head: head}) do
    [head]
  end

  defp extract_tokens_from_phrase(_), do: []
end
