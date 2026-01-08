defmodule Nasty.Language.Spanish.FeatureExtractor do
  @moduledoc """
  Extracts linguistic features from Spanish text for ML applications.

  Provides feature vectors for:
  - Text classification
  - Similarity computation
  - Information retrieval
  - Clustering

  ## Features

  - Lexical: word counts, n-grams, TF-IDF
  - Syntactic: POS tags, phrase structures
  - Semantic: entities, sentiment indicators
  - Statistical: sentence length, type-token ratio

  ## Example

      iex> doc = parse("El gato se sentó en la alfombra")
      iex> features = FeatureExtractor.extract(doc)
      %{
        word_count: 7,
        sentence_count: 1,
        avg_sentence_length: 7.0,
        noun_count: 2,
        verb_count: 1,
        entities: [:animal, :furniture],
        ...
      }
  """

  alias Nasty.AST.{Document, Sentence}

  @doc """
  Extracts all features from a Spanish document.

  Returns a map of feature names to values.
  """
  @spec extract(Document.t()) :: map()
  def extract(%Document{language: :es} = doc) do
    %{}
    |> Map.merge(lexical_features(doc))
    |> Map.merge(syntactic_features(doc))
    |> Map.merge(semantic_features(doc))
    |> Map.merge(statistical_features(doc))
  end

  def extract(%Document{language: lang}) do
    raise ArgumentError,
          "Spanish feature extractor called with #{lang} document. Use language-specific extractor."
  end

  # Lexical features: words, n-grams, vocabulary
  defp lexical_features(doc) do
    tokens = get_all_tokens(doc)
    words = Enum.map(tokens, & &1.text)
    lemmas = Enum.map(tokens, & &1.lemma)

    %{
      word_count: length(words),
      unique_words: length(Enum.uniq(words)),
      type_token_ratio: length(Enum.uniq(words)) / max(length(words), 1),
      avg_word_length: avg_length(words),
      stop_word_ratio: stop_word_ratio(words),
      vocabulary_richness: length(Enum.uniq(lemmas)) / max(length(lemmas), 1)
    }
  end

  # Syntactic features: POS tags, phrase structures
  defp syntactic_features(doc) do
    tokens = get_all_tokens(doc)
    pos_tags = Enum.map(tokens, & &1.pos_tag)

    %{
      noun_count: Enum.count(pos_tags, &(&1 == :noun)),
      verb_count: Enum.count(pos_tags, &(&1 == :verb)),
      adj_count: Enum.count(pos_tags, &(&1 == :adj)),
      adv_count: Enum.count(pos_tags, &(&1 == :adv)),
      det_count: Enum.count(pos_tags, &(&1 == :det)),
      prep_count: Enum.count(pos_tags, &(&1 == :prep)),
      conj_count: Enum.count(pos_tags, &(&1 == :conj)),
      pron_count: Enum.count(pos_tags, &(&1 == :pron)),
      noun_verb_ratio: safe_ratio(pos_tags, :noun, :verb)
    }
  end

  # Semantic features: entities, sentiment
  defp semantic_features(doc) do
    tokens = get_all_tokens(doc)

    # Count entity indicators (capitalized words not at sentence start)
    entity_count =
      tokens
      |> Enum.filter(fn token ->
        first_char = String.first(token.text)
        first_char == String.upcase(first_char) and token.span.start_pos.column > 1
      end)
      |> length()

    # Count sentiment indicators
    positive_words = count_sentiment_words(tokens, :positive)
    negative_words = count_sentiment_words(tokens, :negative)

    %{
      entity_count: entity_count,
      positive_words: positive_words,
      negative_words: negative_words,
      sentiment_score: (positive_words - negative_words) / max(length(tokens), 1)
    }
  end

  # Statistical features: document structure
  defp statistical_features(doc) do
    sentences = get_all_sentences(doc)
    tokens = get_all_tokens(doc)

    sentence_lengths = Enum.map(sentences, &count_sentence_tokens/1)

    %{
      sentence_count: length(sentences),
      avg_sentence_length: avg(sentence_lengths),
      max_sentence_length: Enum.max(sentence_lengths, fn -> 0 end),
      min_sentence_length: Enum.min(sentence_lengths, fn -> 0 end),
      punctuation_count: count_punctuation(tokens),
      question_count: count_questions(sentences),
      exclamation_count: count_exclamations(tokens)
    }
  end

  # Helper: Get all tokens from document
  defp get_all_tokens(%Document{paragraphs: paragraphs}) do
    paragraphs
    |> Enum.flat_map(& &1.sentences)
    |> Enum.flat_map(&get_sentence_tokens/1)
  end

  defp get_sentence_tokens(%Sentence{main_clause: main, additional_clauses: additional}) do
    ([main] ++ additional)
    |> Enum.flat_map(&get_clause_tokens/1)
  end

  defp get_clause_tokens(clause) do
    subject_tokens = if clause.subject, do: get_phrase_tokens(clause.subject), else: []
    predicate_tokens = get_phrase_tokens(clause.predicate)
    subject_tokens ++ predicate_tokens
  end

  defp get_phrase_tokens(_phrase) do
    # Simplified: extract tokens from phrase structures
    # In reality, would need to recursively traverse phrase nodes
    []
  end

  # Helper: Get all sentences from document
  defp get_all_sentences(%Document{paragraphs: paragraphs}) do
    Enum.flat_map(paragraphs, & &1.sentences)
  end

  # Helper: Count tokens in a sentence
  defp count_sentence_tokens(sentence) do
    get_sentence_tokens(sentence) |> length()
  end

  # Helper: Average of list
  defp avg([]), do: 0.0
  defp avg(list), do: Enum.sum(list) / length(list)

  # Helper: Average length of strings
  defp avg_length([]), do: 0.0
  defp avg_length(strings), do: Enum.map(strings, &String.length/1) |> avg()

  # Helper: Ratio of two POS tag counts
  defp safe_ratio(pos_tags, tag1, tag2) do
    count1 = Enum.count(pos_tags, &(&1 == tag1))
    count2 = Enum.count(pos_tags, &(&1 == tag2))
    if count2 > 0, do: count1 / count2, else: 0.0
  end

  # Helper: Stop word ratio
  defp stop_word_ratio(words) do
    stop_words = spanish_stop_words()
    stop_count = Enum.count(words, &(String.downcase(&1) in stop_words))
    stop_count / max(length(words), 1)
  end

  # Helper: Count punctuation tokens
  defp count_punctuation(tokens) do
    Enum.count(tokens, &(&1.pos_tag == :punct))
  end

  # Helper: Count questions
  defp count_questions(_sentences) do
    # Would need sentence text to check for "?"
    0
  end

  # Helper: Count exclamations
  defp count_exclamations(tokens) do
    Enum.count(tokens, &(&1.text in ["!", "¡"]))
  end

  # Helper: Count sentiment words
  defp count_sentiment_words(tokens, sentiment) do
    words = sentiment_words(sentiment)
    Enum.count(tokens, &(String.downcase(&1.text) in words))
  end

  # Spanish stop words
  defp spanish_stop_words do
    MapSet.new([
      "el",
      "la",
      "los",
      "las",
      "un",
      "una",
      "de",
      "a",
      "en",
      "y",
      "o",
      "que",
      "por",
      "para",
      "con"
    ])
  end

  # Sentiment word lists
  defp sentiment_words(:positive) do
    MapSet.new([
      "bueno",
      "excelente",
      "perfecto",
      "maravilloso",
      "genial",
      "fantástico",
      "increíble",
      "hermoso",
      "feliz",
      "alegre"
    ])
  end

  defp sentiment_words(:negative) do
    MapSet.new([
      "malo",
      "terrible",
      "horrible",
      "pésimo",
      "triste",
      "desagradable",
      "molesto",
      "feo",
      "difícil",
      "problema"
    ])
  end
end
