defmodule Nasty.Language.English.FeatureExtractor do
  @moduledoc """
  Extracts classification features from parsed documents.

  Supports multiple feature types:
  - Bag of Words (BoW): Lemmatized word frequencies
  - N-grams: Word sequences (bigrams, trigrams)
  - POS patterns: Part-of-speech tag sequences
  - Syntactic features: Sentence structure statistics
  - Entity features: Named entity type distributions
  - Lexical features: Vocabulary richness, sentence length
  """

  alias Nasty.AST.{Document, Paragraph, Sentence}
  alias Nasty.Language.English.EntityRecognizer

  # Stop words to exclude from BoW features
  @stop_words MapSet.new(~w(
    a an the this that these those
    is are was were be been being
    have has had having
    do does did doing done
    will would shall should may might can could must
    i me my mine you your yours he him his she her hers it its
    we us our ours they them their theirs
    in on at by for with from to of about
    and or but nor so yet
    as if because when where while
  ))

  @doc """
  Extracts features from a document.

  ## Options

  - `:features` - List of feature types to extract (default: `[:bow, :ngrams]`)
    - `:bow` - Bag of words (lemmatized)
    - `:ngrams` - Word n-grams
    - `:pos_patterns` - POS tag sequences
    - `:syntactic` - Sentence structure features
    - `:entities` - Entity type features
    - `:lexical` - Lexical statistics
  - `:ngram_size` - Size of n-grams (default: 2)
  - `:max_features` - Maximum number of features to keep (default: 1000)
  - `:min_frequency` - Minimum frequency threshold (default: 1)
  - `:include_stop_words` - Include stop words in BoW (default: false)

  ## Examples

      iex> document = parse("The cat sat on the mat.")
      iex> features = FeatureExtractor.extract(document, features: [:bow, :ngrams])
      %{
        bow: %{"cat" => 1, "sat" => 1, "mat" => 1},
        ngrams: %{{"cat", "sat"} => 1, {"sat", "mat"} => 1}
      }
  """
  @spec extract(Document.t(), keyword()) :: map()
  def extract(%Document{} = document, opts \\ []) do
    feature_types = Keyword.get(opts, :features, [:bow, :ngrams])

    feature_types
    |> Enum.map(fn type ->
      {type, extract_feature_type(type, document, opts)}
    end)
    |> Enum.into(%{})
  end

  # Extract specific feature type
  defp extract_feature_type(:bow, document, opts) do
    extract_bow(document, opts)
  end

  defp extract_feature_type(:ngrams, document, opts) do
    extract_ngrams(document, opts)
  end

  defp extract_feature_type(:pos_patterns, document, opts) do
    extract_pos_patterns(document, opts)
  end

  defp extract_feature_type(:syntactic, document, opts) do
    extract_syntactic_features(document, opts)
  end

  defp extract_feature_type(:entities, document, opts) do
    extract_entity_features(document, opts)
  end

  defp extract_feature_type(:lexical, document, opts) do
    extract_lexical_features(document, opts)
  end

  defp extract_feature_type(_, _document, _opts), do: %{}

  # Bag of Words: lemmatized word frequencies
  defp extract_bow(document, opts) do
    include_stop_words = Keyword.get(opts, :include_stop_words, false)
    min_freq = Keyword.get(opts, :min_frequency, 1)

    tokens = get_all_tokens(document)

    tokens
    |> Enum.map(&normalize_token/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(fn word ->
      not include_stop_words and MapSet.member?(@stop_words, word)
    end)
    |> Enum.frequencies()
    |> Enum.filter(fn {_word, freq} -> freq >= min_freq end)
    |> Enum.into(%{})
  end

  # N-grams: sequences of words
  defp extract_ngrams(document, opts) do
    n = Keyword.get(opts, :ngram_size, 2)
    min_freq = Keyword.get(opts, :min_frequency, 1)

    tokens = get_all_tokens(document)
    words = Enum.map(tokens, &normalize_token/1) |> Enum.reject(&is_nil/1)

    words
    |> Enum.chunk_every(n, 1, :discard)
    |> Enum.map(&List.to_tuple/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_ngram, freq} -> freq >= min_freq end)
    |> Enum.into(%{})
  end

  # POS patterns: sequences of POS tags
  defp extract_pos_patterns(document, opts) do
    n = Keyword.get(opts, :ngram_size, 2)
    min_freq = Keyword.get(opts, :min_frequency, 1)

    tokens = get_all_tokens(document)
    pos_tags = Enum.map(tokens, & &1.pos_tag)

    pos_tags
    |> Enum.chunk_every(n, 1, :discard)
    |> Enum.map(&List.to_tuple/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_pattern, freq} -> freq >= min_freq end)
    |> Enum.into(%{})
  end

  # Syntactic features: sentence structure statistics
  defp extract_syntactic_features(document, _opts) do
    sentences = Document.all_sentences(document)

    structure_counts =
      sentences
      |> Enum.frequencies_by(& &1.structure)

    function_counts =
      sentences
      |> Enum.frequencies_by(& &1.function)

    clause_counts =
      sentences
      |> Enum.map(fn s -> length([s.main_clause | s.additional_clauses]) end)
      |> Enum.frequencies()

    %{
      sentence_structures: structure_counts,
      sentence_functions: function_counts,
      clause_distribution: clause_counts,
      total_sentences: length(sentences),
      avg_clauses_per_sentence:
        if(length(sentences) > 0,
          do: Enum.sum(Map.values(clause_counts)) / length(sentences),
          else: 0.0
        )
    }
  end

  # Entity features: named entity type counts
  defp extract_entity_features(document, _opts) do
    tokens = get_all_tokens(document)
    entities = EntityRecognizer.recognize(tokens)

    entity_counts = Enum.frequencies_by(entities, & &1.type)
    total_entities = length(entities)

    %{
      entity_counts: entity_counts,
      total_entities: total_entities,
      entity_density: if(length(tokens) > 0, do: total_entities / length(tokens), else: 0.0)
    }
  end

  # Lexical features: vocabulary and text statistics
  defp extract_lexical_features(document, _opts) do
    tokens = get_all_tokens(document)
    words = Enum.map(tokens, &normalize_token/1) |> Enum.reject(&is_nil/1)
    unique_words = MapSet.new(words)
    sentences = Document.all_sentences(document)

    avg_sentence_length =
      if length(sentences) > 0, do: length(tokens) / length(sentences), else: 0.0

    type_token_ratio =
      if length(words) > 0, do: MapSet.size(unique_words) / length(words), else: 0.0

    %{
      total_tokens: length(tokens),
      unique_tokens: MapSet.size(unique_words),
      type_token_ratio: type_token_ratio,
      avg_sentence_length: avg_sentence_length,
      total_sentences: length(sentences)
    }
  end

  # Helper: Get all tokens from document
  defp get_all_tokens(%Document{metadata: %{tokens: tokens}}) when is_list(tokens) do
    tokens
  end

  defp get_all_tokens(%Document{paragraphs: paragraphs}) do
    paragraphs
    |> Enum.flat_map(fn %Paragraph{sentences: sentences} ->
      Enum.flat_map(sentences, &get_sentence_tokens/1)
    end)
  end

  # Helper: Get tokens from sentence
  defp get_sentence_tokens(%Sentence{main_clause: clause, additional_clauses: additional}) do
    main_tokens = get_clause_tokens(clause)
    additional_tokens = Enum.flat_map(additional, &get_clause_tokens/1)
    main_tokens ++ additional_tokens
  end

  # Helper: Get tokens from clause
  defp get_clause_tokens(%{subject: subj, predicate: pred}) do
    subj_tokens = if subj, do: get_phrase_tokens(subj), else: []
    pred_tokens = get_phrase_tokens(pred)
    subj_tokens ++ pred_tokens
  end

  # Helper: Get tokens from phrase
  defp get_phrase_tokens(%{head: head, determiner: det, modifiers: mods}) do
    tokens = [head | mods]
    if det, do: [det | tokens], else: tokens
  end

  defp get_phrase_tokens(%{head: head, auxiliaries: aux}) do
    [head | aux]
  end

  defp get_phrase_tokens(%{head: head}) do
    [head]
  end

  defp get_phrase_tokens(_), do: []

  # Helper: Normalize token to lowercase lemma or text
  defp normalize_token(%{lemma: lemma}) when is_binary(lemma) and lemma != "" do
    String.downcase(lemma)
  end

  defp normalize_token(%{text: text, pos_tag: pos}) when pos not in [:punct, :sym] do
    String.downcase(text)
  end

  defp normalize_token(_), do: nil

  @doc """
  Converts a feature map to a sparse vector representation.

  Useful for machine learning algorithms that expect numeric vectors.

  ## Examples

      iex> features = %{bow: %{"cat" => 2, "dog" => 1}}
      iex> FeatureExtractor.to_vector(features, [:bow])
      %{"bow:cat" => 2, "bow:dog" => 1}
  """
  @spec to_vector(map(), [atom()]) :: %{String.t() => number()}
  def to_vector(features, feature_types) do
    feature_types
    |> Enum.flat_map(fn type ->
      case Map.get(features, type) do
        map when is_map(map) ->
          map
          |> Enum.flat_map(fn {key, value} ->
            cond do
              is_number(value) ->
                [{"#{type}:#{inspect(key)}", value}]

              is_map(value) ->
                # Flatten nested maps (e.g., entity_counts)
                Enum.map(value, fn {k, v} ->
                  {"#{type}:#{inspect(key)}:#{inspect(k)}", v}
                end)

              true ->
                []
            end
          end)

        _ ->
          []
      end
    end)
    |> Enum.into(%{})
  end
end
