defmodule Nasty.Operations.Summarization.Extractive do
  @moduledoc """
  Language-agnostic extractive summarization algorithms.

  Provides generic scoring and selection methods that work with any AST
  structure. Language-specific implementations provide configuration like
  stop words, discourse markers, and entity recognition.

  ## Usage

      defmodule MyLanguage.Summarizer do
        use Nasty.Operations.Summarization.Extractive

        @impl true
        def stop_words, do: ["a", "the", "is"]

        @impl true
        def discourse_markers, do: ["therefore", "conclusion"]

        @impl true
        def entity_recognizer, do: MyLanguage.EntityRecognizer
      end
  """

  alias Nasty.AST.{Document, Paragraph, Sentence}

  @doc """
  Callback for providing stop words for keyword scoring.
  """
  @callback stop_words() :: [String.t()]

  @doc """
  Callback for providing discourse markers.
  """
  @callback discourse_markers() :: [String.t()]

  @doc """
  Callback for entity recognition module (optional).
  """
  @callback entity_recognizer() :: module() | nil

  @doc """
  Callback for extracting tokens from a sentence.
  Must be implemented by language-specific module.
  """
  @callback extract_tokens(Sentence.t()) :: [term()]

  @optional_callbacks entity_recognizer: 0

  @doc """
  Summarizes a document using extractive methods.

  ## Options

  - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
  - `:max_sentences` - Maximum number of sentences in summary
  - `:min_sentence_length` - Minimum sentence length (in tokens)
  - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)
  - `:mmr_lambda` - MMR diversity parameter, 0-1 (default: 0.5)
  - `:score_weights` - Custom weights for scoring components (map)

  Returns a list of selected sentences in document order.
  """
  @spec summarize(module(), Document.t(), keyword()) :: [Sentence.t()]
  def summarize(impl, %Document{paragraphs: paragraphs, coref_chains: coref_chains}, opts \\ []) do
    ratio = Keyword.get(opts, :ratio, 0.3)
    max_sentences = Keyword.get(opts, :max_sentences)
    min_length = Keyword.get(opts, :min_sentence_length, 3)
    method = Keyword.get(opts, :method, :greedy)

    # Extract all sentences from document
    all_sentences = extract_sentences(paragraphs)

    # Filter out very short sentences
    sentences =
      Enum.filter(all_sentences, fn s ->
        sentence_length(impl, s) >= min_length
      end)

    # Calculate how many sentences to include
    target_count = calculate_target_count(sentences, max_sentences, ratio)

    # Score each sentence
    scored_sentences = score_all_sentences(impl, sentences, coref_chains || [], opts)

    # Select sentences based on method
    selected =
      case method do
        :mmr -> select_mmr(impl, scored_sentences, target_count, opts)
        _ -> select_greedy(scored_sentences, target_count)
      end

    # Sort by original order and extract sentences
    selected
    |> Enum.sort_by(fn {_s, idx, _score} -> idx end)
    |> Enum.map(fn {sentence, _idx, _score} -> sentence end)
  end

  @doc """
  Extracts all sentences from paragraphs.
  """
  @spec extract_sentences([Paragraph.t()]) :: [Sentence.t()]
  def extract_sentences(paragraphs) do
    paragraphs
    |> Enum.flat_map(fn %Paragraph{sentences: sentences} -> sentences end)
  end

  @doc """
  Calculates target number of sentences for summary.
  """
  @spec calculate_target_count([Sentence.t()], integer() | nil, float()) :: integer()
  def calculate_target_count(sentences, max_sentences, ratio) do
    if max_sentences do
      min(max_sentences, length(sentences))
    else
      max(1, round(length(sentences) * ratio))
    end
  end

  @doc """
  Scores all sentences in a document.
  """
  @spec score_all_sentences(module(), [Sentence.t()], [term()], keyword()) :: [
          {Sentence.t(), integer(), float()}
        ]
  def score_all_sentences(impl, sentences, coref_chains, opts) do
    sentences
    |> Enum.with_index()
    |> Enum.map(fn {sentence, idx} ->
      score = score_sentence(impl, sentence, idx, sentences, coref_chains, opts)
      {sentence, idx, score}
    end)
  end

  @doc """
  Scores a single sentence using multiple heuristics.

  ## Default weights

  - Position: 0.25
  - Length: 0.15
  - Entity: 0.25
  - Keyword: 0.15
  - Discourse: 0.10
  - Coreference: 0.10
  """
  @spec score_sentence(module(), Sentence.t(), integer(), [Sentence.t()], [term()], keyword()) ::
          float()
  def score_sentence(impl, sentence, position, all_sentences, coref_chains, opts) do
    weights = Keyword.get(opts, :score_weights, %{})

    position_score = position_score(position, length(all_sentences))
    length_score = length_score(impl, sentence)
    entity_score = entity_score(impl, sentence)
    keyword_score = keyword_score(impl, sentence, all_sentences)
    discourse_score = discourse_marker_score(impl, sentence)
    coref_score = coreference_score(sentence, position, coref_chains)

    # Apply weights (with defaults)
    Map.get(weights, :position, 0.25) * position_score +
      Map.get(weights, :length, 0.15) * length_score +
      Map.get(weights, :entity, 0.25) * entity_score +
      Map.get(weights, :keyword, 0.15) * keyword_score +
      Map.get(weights, :discourse, 0.1) * discourse_score +
      Map.get(weights, :coref, 0.1) * coref_score
  end

  @doc """
  Position score: earlier sentences are more important.
  """
  @spec position_score(integer(), integer()) :: float()
  def position_score(position, total) do
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

  @doc """
  Length score: prefer moderate-length sentences.
  """
  @spec length_score(module(), Sentence.t()) :: float()
  def length_score(impl, sentence) do
    length = sentence_length(impl, sentence)

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

  @doc """
  Entity score: sentences with named entities are more important.
  """
  @spec entity_score(module(), Sentence.t()) :: float()
  def entity_score(impl, sentence) do
    if function_exported?(impl, :entity_recognizer, 0) do
      recognizer = impl.entity_recognizer()

      if recognizer do
        tokens = impl.extract_tokens(sentence)
        entities = recognizer.recognize(tokens)

        case length(entities) do
          0 -> 0.3
          1 -> 0.6
          2 -> 0.9
          # 3+ entities
          _ -> 1.0
        end
      else
        0.5
      end
    else
      0.5
    end
  end

  @doc """
  Keyword score based on term frequency.
  """
  @spec keyword_score(module(), Sentence.t(), [Sentence.t()]) :: float()
  def keyword_score(impl, sentence, all_sentences) do
    stop_words = MapSet.new(impl.stop_words())

    # Build term frequency map for entire document
    doc_tokens =
      all_sentences
      |> Enum.flat_map(&impl.extract_tokens/1)
      |> Enum.map(fn t -> String.downcase(t.text) end)
      |> Enum.filter(fn text ->
        # Filter out stop words and punctuation
        String.length(text) > 2 && text =~ ~r/^[a-z]+$/ && not MapSet.member?(stop_words, text)
      end)

    term_freq = Enum.frequencies(doc_tokens)

    # Calculate sentence score based on term frequencies
    sentence_tokens =
      sentence
      |> impl.extract_tokens()
      |> Enum.map(fn t -> String.downcase(t.text) end)
      |> Enum.filter(fn text ->
        String.length(text) > 2 && text =~ ~r/^[a-z]+$/ && not MapSet.member?(stop_words, text)
      end)

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

  @doc """
  Discourse marker score: signal words indicate importance.
  """
  @spec discourse_marker_score(module(), Sentence.t()) :: float()
  def discourse_marker_score(impl, sentence) do
    markers = MapSet.new(impl.discourse_markers())
    tokens = impl.extract_tokens(sentence)
    words = Enum.map(tokens, &String.downcase(&1.text))

    matching_count = Enum.count(words, &MapSet.member?(markers, &1))
    min(matching_count * 0.3, 1.0)
  end

  @doc """
  Coreference score: sentences participating in coref chains are important.
  """
  @spec coreference_score(Sentence.t(), integer(), [term()]) :: float()
  def coreference_score(_sentence, _position, []), do: 0.0

  def coreference_score(_sentence, position, coref_chains) do
    # Count mentions in this sentence across all chains
    mention_count =
      coref_chains
      |> Enum.flat_map(fn chain -> chain.mentions end)
      |> Enum.count(&(&1.sentence_idx == position))

    min(mention_count * 0.2, 1.0)
  end

  @doc """
  Greedy selection: pick top-N by score.
  """
  @spec select_greedy([{Sentence.t(), integer(), float()}], integer()) :: [
          {Sentence.t(), integer(), float()}
        ]
  def select_greedy(scored_sentences, count) do
    scored_sentences
    |> Enum.sort_by(fn {_sent, _idx, score} -> -score end)
    |> Enum.take(count)
  end

  @doc """
  MMR selection: maximize relevance while minimizing redundancy.
  """
  @spec select_mmr(module(), [{Sentence.t(), integer(), float()}], integer(), keyword()) :: [
          {Sentence.t(), integer(), float()}
        ]
  def select_mmr(_impl, scored_sentences, count, opts) do
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

  # MMR recursive helper
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

  @doc """
  Calculates maximum similarity between a sentence and selected sentences.
  """
  @spec calculate_max_similarity(Sentence.t(), [{Sentence.t(), integer(), float()}]) :: float()
  def calculate_max_similarity(sent, selected) do
    sent_terms = extract_term_set(sent)

    selected
    |> Enum.map(fn {sel_sent, _idx, _score} ->
      sel_terms = extract_term_set(sel_sent)
      jaccard_similarity(sent_terms, sel_terms)
    end)
    |> Enum.max(fn -> 0.0 end)
  end

  @doc """
  Calculates Jaccard similarity between two term sets.
  """
  @spec jaccard_similarity(MapSet.t(), MapSet.t()) :: float()
  def jaccard_similarity(set1, set2) do
    intersection_size = MapSet.intersection(set1, set2) |> MapSet.size()
    union_size = MapSet.union(set1, set2) |> MapSet.size()

    if union_size > 0 do
      intersection_size / union_size
    else
      0.0
    end
  end

  # Private helpers

  defp sentence_length(impl, sentence) do
    tokens = impl.extract_tokens(sentence)
    length(tokens)
  end

  defp extract_term_set(sentence) do
    # For MMR, we need a simple extraction without dependencies
    # This is a basic implementation - language-specific versions can override
    case sentence do
      %Sentence{main_clause: clause} ->
        extract_terms_from_clause(clause)

      _ ->
        MapSet.new()
    end
  end

  defp extract_terms_from_clause(%{subject: subj, predicate: pred}) do
    subj_terms = if subj, do: extract_terms_from_phrase(subj), else: MapSet.new()
    pred_terms = extract_terms_from_phrase(pred)
    MapSet.union(subj_terms, pred_terms)
  end

  defp extract_terms_from_phrase(%{head: head} = phrase) when is_map(phrase) do
    # Extract lemma or text from head token
    term =
      case head do
        %{lemma: lemma, text: text} -> lemma || String.downcase(text)
        %{text: text} -> String.downcase(text)
        _ -> nil
      end

    if term, do: MapSet.new([term]), else: MapSet.new()
  end

  defp extract_terms_from_phrase(_), do: MapSet.new()
end
