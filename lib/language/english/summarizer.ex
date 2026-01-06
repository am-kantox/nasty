defmodule Nasty.Language.English.Summarizer do
  @moduledoc """
  Extractive text summarization for English.

  Extracts the most important sentences from a document using scoring heuristics:
  - Position (sentences early in document are more important)
  - Length (prefer moderate-length sentences)
  - Term frequency (TF for important content words)
  - Named entities (sentences with entities are more important)
  - Discourse markers (signal words like "importantly", "in conclusion")
  - Coreference participation (sentences in coreference chains)

  Supports two selection methods:
  - `:greedy` - Select top-N sentences by score (default)
  - `:mmr` - Maximal Marginal Relevance to reduce redundancy

  ## Examples

      iex> document = parse("The cat sat on the mat. The dog ran in the park. ...")
      iex> summary = Summarizer.summarize(document, ratio: 0.3)
      [%Sentence{}, ...]

      iex> summary = Summarizer.summarize(document, max_sentences: 3, method: :mmr)
      [%Sentence{}, ...]
  """

  alias Nasty.AST.{Document, Paragraph, Sentence}
  alias Nasty.Language.English.EntityRecognizer

  # Discourse markers that signal important content
  @discourse_markers ~w(
    conclusion summary finally therefore thus hence consequently
    important importantly significant notably crucially essential critical
    indeed fact actually certainly definitely clearly obviously
    however nevertheless nonetheless although despite though but yet
  )

  # Stop words to exclude from TF calculation
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
  Summarizes a document by extracting important sentences.

  ## Options

  - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
  - `:max_sentences` - Maximum number of sentences in summary
  - `:min_sentence_length` - Minimum sentence length (in tokens)
  - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)
  - `:mmr_lambda` - MMR diversity parameter, 0-1 (default: 0.5)

  Returns a list of selected sentences in document order.
  """
  @spec summarize(Document.t(), keyword()) :: [Sentence.t()]
  def summarize(%Document{paragraphs: paragraphs, coref_chains: coref_chains}, opts \\ []) do
    ratio = Keyword.get(opts, :ratio, 0.3)
    max_sentences = Keyword.get(opts, :max_sentences)
    min_length = Keyword.get(opts, :min_sentence_length, 3)
    method = Keyword.get(opts, :method, :greedy)

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
        score = score_sentence(sentence, idx, sentences, coref_chains || [])
        {sentence, idx, score}
      end)

    # Select sentences based on method
    selected =
      case method do
        :mmr -> select_mmr(scored_sentences, target_count, opts)
        _ -> select_greedy(scored_sentences, target_count)
      end

    # Sort by original order and extract sentences
    selected
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
  defp score_sentence(sentence, position, all_sentences, coref_chains) do
    position_score = position_score(position, length(all_sentences))
    length_score = length_score(sentence)
    entity_score = entity_score(sentence)
    keyword_score = keyword_score(sentence, all_sentences)
    discourse_score = discourse_marker_score(sentence)
    coref_score = coreference_score(sentence, position, coref_chains)

    # Weighted combination
    position_score * 0.25 +
      length_score * 0.15 +
      entity_score * 0.25 +
      keyword_score * 0.15 +
      discourse_score * 0.1 +
      coref_score * 0.1
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

  # Discourse marker score: signal words indicate importance
  defp discourse_marker_score(sentence) do
    tokens = extract_tokens_from_sentence(sentence)
    words = Enum.map(tokens, &String.downcase(&1.text))

    matching_count = Enum.count(words, &(&1 in @discourse_markers))
    min(matching_count * 0.3, 1.0)
  end

  # Coreference score: sentences participating in coref chains are important
  defp coreference_score(_sentence, _position, []), do: 0.0

  defp coreference_score(_sentence, position, coref_chains) do
    # Count mentions in this sentence across all chains
    mention_count =
      coref_chains
      |> Enum.flat_map(fn chain -> chain.mentions end)
      |> Enum.count(&(&1.sentence_idx == position))

    min(mention_count * 0.2, 1.0)
  end

  # Greedy selection: pick top-N by score
  defp select_greedy(scored_sentences, count) do
    scored_sentences
    |> Enum.sort_by(fn {_sent, _idx, score} -> -score end)
    |> Enum.take(count)
  end

  # MMR selection: maximize relevance while minimizing redundancy
  defp select_mmr(scored_sentences, count, opts) do
    lambda = Keyword.get(opts, :mmr_lambda, 0.5)

    # Sort by score
    sorted = Enum.sort_by(scored_sentences, fn {_sent, _idx, score} -> -score end)

    case sorted do
      [] ->
        []

      [{first_sent, first_idx, first_score} | rest] ->
        # Start with highest scored sentence
        select_mmr_recursive(
          [{first_sent, first_idx, first_score}],
          rest,
          count - 1,
          lambda
        )
    end
  end

  defp select_mmr_recursive(selected, _remaining, 0, _lambda), do: selected
  defp select_mmr_recursive(selected, [], _count, _lambda), do: selected

  defp select_mmr_recursive(selected, remaining, count, lambda) do
    # For each remaining sentence, calculate MMR score
    mmr_scored =
      Enum.map(remaining, fn {sent, idx, relevance} ->
        # Calculate max similarity to already selected sentences
        max_similarity = calculate_max_similarity(sent, selected)

        # MMR = λ * Relevance - (1-λ) * MaxSimilarity
        mmr_score = lambda * relevance - (1 - lambda) * max_similarity

        {sent, idx, relevance, mmr_score}
      end)

    # Select sentence with highest MMR score
    {best_sent, best_idx, best_rel, _mmr} =
      Enum.max_by(mmr_scored, fn {_s, _i, _r, mmr} -> mmr end)

    # Add to selected and continue
    new_selected = selected ++ [{best_sent, best_idx, best_rel}]
    new_remaining = Enum.reject(remaining, fn {s, i, _} -> s == best_sent and i == best_idx end)

    select_mmr_recursive(new_selected, new_remaining, count - 1, lambda)
  end

  # Calculate maximum similarity between a sentence and selected sentences
  defp calculate_max_similarity(sent, selected) do
    sent_terms = extract_term_set(sent)

    selected
    |> Enum.map(fn {sel_sent, _idx, _score} ->
      sel_terms = extract_term_set(sel_sent)
      jaccard_similarity(sent_terms, sel_terms)
    end)
    |> Enum.max(fn -> 0.0 end)
  end

  # Extract set of content word lemmas from sentence
  defp extract_term_set(sentence) do
    sentence
    |> extract_tokens_from_sentence()
    |> Enum.filter(&(&1.pos_tag in [:noun, :verb, :adj, :propn]))
    |> Enum.map(&(&1.lemma || String.downcase(&1.text)))
    |> Enum.reject(&(&1 in @stop_words))
    |> MapSet.new()
  end

  # Calculate Jaccard similarity between two term sets
  defp jaccard_similarity(set1, set2) do
    intersection_size = MapSet.intersection(set1, set2) |> MapSet.size()
    union_size = MapSet.union(set1, set2) |> MapSet.size()

    if union_size > 0 do
      intersection_size / union_size
    else
      0.0
    end
  end
end
