defmodule Nasty.Data.Corpus do
  @moduledoc """
  Corpus loading and management with caching.

  Handles loading training data from various formats (CoNLL-U, raw text)
  and provides utilities for train/validation/test splitting.

  ## Examples

      # Load UD corpus
      {:ok, corpus} = Corpus.load_ud("data/en_ewt-ud-train.conllu")

      # Split into train/dev/test
      {train, dev, test} = Corpus.split(corpus, ratios: [0.8, 0.1, 0.1])

      # Extract POS tagging training data
      pos_data = Corpus.extract_pos_sequences(train)
  """

  alias Nasty.Data.CoNLLU

  @type corpus :: %{sentences: [CoNLLU.sentence()], metadata: map()}

  @doc """
  Load a Universal Dependencies corpus from CoNLL-U file.

  ## Parameters

    - `path` - Path to .conllu file
    - `opts` - Options
      - `:cache` - Enable caching (default: true)
      - `:language` - Language code (default: :en)

  ## Returns

    - `{:ok, corpus}` - Loaded corpus
    - `{:error, reason}` - Load failed
  """
  @spec load_ud(Path.t(), keyword()) :: {:ok, corpus()} | {:error, term()}
  def load_ud(path, opts \\ []) do
    case CoNLLU.parse_file(path) do
      {:ok, sentences} ->
        corpus = %{
          sentences: sentences,
          metadata: %{
            source: path,
            format: :conllu,
            language: Keyword.get(opts, :language, :en),
            size: length(sentences)
          }
        }

        {:ok, corpus}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Split corpus into train/validation/test sets.

  ## Parameters

    - `corpus` - The corpus to split
    - `opts` - Options
      - `:ratios` - Split ratios [train, val, test] (default: [0.8, 0.1, 0.1])
      - `:shuffle` - Shuffle before splitting (default: true)
      - `:seed` - Random seed for shuffling (default: :rand.uniform(10000))

  ## Returns

    - `{train_corpus, val_corpus, test_corpus}` - Three corpora

  ## Examples

      {train, dev, test} = Corpus.split(corpus, ratios: [0.8, 0.1, 0.1])
  """
  @spec split(corpus(), keyword()) :: {corpus(), corpus(), corpus()}
  def split(corpus, opts \\ []) do
    ratios = Keyword.get(opts, :ratios, [0.8, 0.1, 0.1])
    shuffle = Keyword.get(opts, :shuffle, true)
    seed = Keyword.get(opts, :seed, :rand.uniform(10_000))

    sentences =
      if shuffle do
        :rand.seed(:exsss, {seed, seed, seed})
        Enum.shuffle(corpus.sentences)
      else
        corpus.sentences
      end

    total = length(sentences)
    [train_ratio, val_ratio, _test_ratio] = ratios

    train_size = round(total * train_ratio)
    val_size = round(total * val_ratio)

    {train_sentences, rest} = Enum.split(sentences, train_size)
    {val_sentences, test_sentences} = Enum.split(rest, val_size)

    train_corpus = %{
      corpus
      | sentences: train_sentences,
        metadata: Map.put(corpus.metadata, :split, :train)
    }

    val_corpus = %{
      corpus
      | sentences: val_sentences,
        metadata: Map.put(corpus.metadata, :split, :val)
    }

    test_corpus = %{
      corpus
      | sentences: test_sentences,
        metadata: Map.put(corpus.metadata, :split, :test)
    }

    {train_corpus, val_corpus, test_corpus}
  end

  @doc """
  Extract POS tagging sequences from corpus.

  Returns list of `{words, tags}` tuples suitable for POS tagger training.

  ## Examples

      pos_data = Corpus.extract_pos_sequences(corpus)
      # => [{["The", "cat", "sat"], [:det, :noun, :verb]}, ...]
  """
  @spec extract_pos_sequences(corpus()) :: [{[String.t()], [atom()]}]
  def extract_pos_sequences(corpus) do
    corpus.sentences
    |> Enum.map(fn sentence ->
      words = Enum.map(sentence.tokens, & &1.form)
      tags = Enum.map(sentence.tokens, & &1.upos)
      {words, tags}
    end)
  end

  @doc """
  Extract dependency relations from corpus.

  Returns list of sentences with dependency information.
  """
  @spec extract_dependencies(corpus()) :: [map()]
  def extract_dependencies(corpus) do
    corpus.sentences
    |> Enum.map(fn sentence ->
      %{
        tokens: sentence.tokens,
        dependencies:
          Enum.map(sentence.tokens, fn token ->
            {token.id, token.head, token.deprel}
          end)
      }
    end)
  end

  @doc """
  Get corpus statistics.

  ## Returns

    - Map with corpus statistics:
      - `:num_sentences` - Number of sentences
      - `:num_tokens` - Total tokens
      - `:num_types` - Unique word types
      - `:pos_distribution` - POS tag counts
      - `:avg_sentence_length` - Average sentence length
  """
  @spec statistics(corpus()) :: map()
  def statistics(corpus) do
    sentences = corpus.sentences

    all_tokens = Enum.flat_map(sentences, & &1.tokens)
    all_words = Enum.map(all_tokens, & &1.form)
    all_tags = Enum.map(all_tokens, & &1.upos) |> Enum.reject(&is_nil/1)

    %{
      num_sentences: length(sentences),
      num_tokens: length(all_tokens),
      num_types: all_words |> Enum.uniq() |> length(),
      pos_distribution: Enum.frequencies(all_tags),
      avg_sentence_length: length(all_tokens) / max(length(sentences), 1)
    }
  end
end
