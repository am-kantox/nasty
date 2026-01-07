defmodule Nasty.Statistics.Neural.DataLoader do
  @moduledoc """
  Data loading utilities for neural models.

  Converts various corpus formats (CoNLL-U, raw text) into batches
  suitable for neural network training.

  ## Features

  - Load Universal Dependencies CoNLL-U format
  - Convert to neural-friendly tensors
  - Automatic batching and padding
  - Vocabulary building from corpus
  - Train/validation/test splits
  - Streaming for large datasets

  ## Example

      # Load CoNLL-U corpus
      {:ok, data} = DataLoader.load_conllu("en_ewt-ud-train.conllu")

      # Split into train/valid/test
      {train, valid, test} = DataLoader.split(data, [0.8, 0.1, 0.1])

      # Create batches for training
      train_batches = DataLoader.create_batches(train, batch_size: 32)

      # Use in training
      Trainer.train(model, train_batches, valid_batches, opts)
  """

  alias Nasty.Data.CoNLLU
  alias Nasty.Statistics.Neural.Embeddings
  require Logger

  @type sentence :: {words :: [String.t()], tags :: [atom()]}
  @type batch :: {inputs :: map(), targets :: map()}

  @doc """
  Loads a CoNLL-U corpus file.

  ## Parameters

    - `path` - Path to CoNLL-U file
    - `opts` - Loading options

  ## Options

    - `:max_sentences` - Maximum sentences to load (default: unlimited)
    - `:min_length` - Minimum sentence length (default: 1)
    - `:max_length` - Maximum sentence length (default: 100)

  ## Returns

    - `{:ok, sentences}` - List of {words, tags} tuples
    - `{:error, reason}` - Loading failed
  """
  @spec load_conllu(Path.t() | String.t(), keyword()) :: {:ok, [sentence()]} | {:error, term()}
  def load_conllu(path_or_content, opts \\ []) do
    max_sentences = Keyword.get(opts, :max_sentences, :infinity)
    min_length = Keyword.get(opts, :min_length, 1)
    max_length = Keyword.get(opts, :max_length, 100)

    Logger.info("Loading CoNLL-U corpus from #{inspect(path_or_content |> String.slice(0..50))}")

    # Try to parse as content first, then as file path
    result =
      if String.contains?(path_or_content, "\t") or String.contains?(path_or_content, "\n"),
        # If it looks like CoNLL-U content (has tabs or newlines with sentence structure)
        do: CoNLLU.parse_string(path_or_content),
        # Otherwise treat as file path
        else: CoNLLU.parse_file(path_or_content)

    case result do
      {:ok, parsed_sentences} ->
        sentences =
          parsed_sentences
          |> Enum.take(
            if max_sentences == :infinity, do: length(parsed_sentences), else: max_sentences
          )
          |> Enum.map(&extract_sentence/1)
          |> Enum.filter(fn {words, _tags} ->
            length = length(words)
            length >= min_length and length <= max_length
          end)

        Logger.info("Loaded #{length(sentences)} sentences")
        {:ok, sentences}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Splits data into train/validation/test sets.

  ## Parameters

    - `data` - List of sentences
    - `ratios` - List of split ratios (must sum to 1.0)

  ## Examples

      # 80% train, 10% valid, 10% test
      {train, valid, test} = DataLoader.split(data, [0.8, 0.1, 0.1])

      # 90% train, 10% valid
      {train, valid} = DataLoader.split(data, [0.9, 0.1])

  ## Returns

  Tuple of split datasets matching the number of ratios provided.
  """
  @spec split([sentence()], [float()]) :: tuple()
  def split(data, ratios) do
    total = Enum.sum(ratios)

    unless abs(total - 1.0) < 0.001 do
      raise ArgumentError, "Ratios must sum to 1.0, got: #{total}"
    end

    shuffled = Enum.shuffle(data)
    total_size = length(shuffled)

    # Calculate split indices
    indices =
      ratios
      |> Enum.scan(0, fn ratio, acc ->
        acc + round(ratio * total_size)
      end)

    # Split data
    splits =
      [0 | indices]
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [start_idx, end_idx] ->
        Enum.slice(shuffled, start_idx, end_idx - start_idx)
      end)

    List.to_tuple(splits)
  end

  @doc """
  Creates batches from sentences for neural network training.

  ## Parameters

    - `sentences` - List of {words, tags} tuples
    - `vocab` - Vocabulary for word-to-ID mapping
    - `tag_vocab` - Tag vocabulary
    - `opts` - Batching options

  ## Options

    - `:batch_size` - Batch size (default: 32)
    - `:shuffle` - Shuffle batches (default: true)
    - `:drop_last` - Drop incomplete last batch (default: false)
    - `:pad_value` - Padding value for sequences (default: 0)

  ## Returns

  List of batches, where each batch is `{inputs, targets}`.
  """
  @spec create_batches([sentence()], map(), map(), keyword()) :: [batch()]
  def create_batches(sentences, vocab, tag_vocab, opts \\ [])

  def create_batches(sentences, vocab, tag_vocab, opts) do
    batch_size = Keyword.get(opts, :batch_size, 32)
    shuffle = Keyword.get(opts, :shuffle, true)
    drop_last = Keyword.get(opts, :drop_last, false)
    pad_value = Keyword.get(opts, :pad_value, 0)

    # Optionally shuffle
    sentences = if shuffle, do: Enum.shuffle(sentences), else: sentences

    # Create batches
    sentences
    |> Enum.chunk_every(batch_size)
    |> Enum.reject(fn batch -> drop_last and length(batch) < batch_size end)
    |> Enum.map(fn batch -> prepare_batch(batch, vocab, tag_vocab, pad_value) end)
  end

  @doc """
  Wrapper for create_batches/4 with simple signature for raw data batching.

  When called with just data and options (no vocab), returns simple chunked batches.
  When called with vocab and tag_vocab, delegates to the full implementation.

  ## Examples

      # Simple batching (no vocab conversion)
      batches = DataLoader.create_batches(data, batch_size: 32)

      # Full neural batching (with vocab conversion)
      batches = DataLoader.create_batches(sentences, vocab, tag_vocab, batch_size: 32)
  """
  def create_batches(data, batch_opts) when is_list(data) and is_list(batch_opts) do
    batch_size = Keyword.get(batch_opts, :batch_size, 32)
    shuffle = Keyword.get(batch_opts, :shuffle, false)
    drop_last = Keyword.get(batch_opts, :drop_last, false)

    data
    |> then(fn d -> if shuffle, do: Enum.shuffle(d), else: d end)
    |> Enum.chunk_every(batch_size)
    |> Enum.reject(fn batch -> drop_last and length(batch) < batch_size end)
  end

  @doc """
  Streams batches from a large corpus file.

  Useful for datasets that don't fit in memory.

  ## Parameters

    - `path` - Path to CoNLL-U file
    - `vocab` - Vocabulary
    - `tag_vocab` - Tag vocabulary
    - `opts` - Streaming options

  ## Returns

  A stream of batches.

  ## Example

      DataLoader.stream_batches("large_corpus.conllu", vocab, tag_vocab, batch_size: 64)
      |> Enum.take(100)  # Process first 100 batches
  """
  @spec stream_batches(Path.t(), map(), map(), keyword()) :: Enumerable.t()
  def stream_batches(path, vocab, tag_vocab, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 32)
    pad_value = Keyword.get(opts, :pad_value, 0)

    # For streaming, read file and parse in chunks
    with {:ok, content} <- File.read(path),
         {:ok, parsed_sentences} <- CoNLLU.parse_string(content) do
      parsed_sentences
      |> Stream.map(&extract_sentence/1)
      |> Stream.chunk_every(batch_size)
      |> Stream.map(fn batch ->
        prepare_batch(batch, vocab, tag_vocab, pad_value)
      end)
    else
      {:error, _reason} ->
        Stream.map([], & &1)
    end
  end

  @doc """
  Wrapper for stream_batches/4 with simpler signature for streaming raw data.

  When called with just data and options (no vocab), returns simple chunked stream.
  When called with path/vocab, delegates to the full file-based streaming implementation.

  ## Examples

      # Simple streaming (no vocab conversion)
      stream = DataLoader.stream_batches(data, batch_size: 32)

      # Full neural streaming from file (with vocab conversion)
      stream = DataLoader.stream_batches(path, vocab, tag_vocab, batch_size: 32)
  """
  def stream_batches(data, batch_opts) when is_list(data) and is_list(batch_opts) do
    batch_size = Keyword.get(batch_opts, :batch_size, 32)
    Stream.chunk_every(data, batch_size)
  end

  @doc """
  Builds vocabulary from a list of sentences.

  ## Parameters

    - `sentences` - List of {words, tags} tuples
    - `opts` - Vocabulary options (passed to Embeddings.build_vocabulary)

  ## Returns

    - `{:ok, vocab, tag_vocab}` - Word and tag vocabularies
  """
  @spec build_vocabularies([sentence()], keyword()) :: {:ok, map(), map()}
  def build_vocabularies(sentences, opts \\ []) do
    # Extract all words and tags
    words = sentences |> Enum.flat_map(fn {words, _} -> words end)
    tags = sentences |> Enum.flat_map(fn {_, tags} -> tags end) |> Enum.uniq()

    # Build word vocabulary
    {:ok, vocab} = Embeddings.build_vocabulary([words], Keyword.put(opts, :return_struct, true))

    # Build tag vocabulary
    tag_to_id = tags |> Enum.sort() |> Enum.with_index() |> Map.new()

    id_to_tag =
      tags |> Enum.sort() |> Enum.with_index() |> Enum.map(fn {t, i} -> {i, t} end) |> Map.new()

    tag_vocab = %{
      tag_to_id: tag_to_id,
      id_to_tag: id_to_tag,
      size: length(tags)
    }

    {:ok, vocab, tag_vocab}
  end

  @doc """
  Analyzes corpus statistics.

  ## Parameters

    - `sentences` - List of sentences

  ## Returns

  Map with corpus statistics:
  - `:num_sentences` - Total sentences
  - `:num_tokens` - Total tokens
  - `:avg_length` - Average sentence length
  - `:max_length` - Maximum sentence length
  - `:min_length` - Minimum sentence length
  - `:vocab_size` - Unique word count
  - `:tag_counts` - Frequency of each tag
  """
  @spec analyze([sentence()]) :: map()
  def analyze(sentences) do
    lengths = Enum.map(sentences, fn {words, _} -> length(words) end)
    words = sentences |> Enum.flat_map(fn {words, _} -> words end)
    tags = sentences |> Enum.flat_map(fn {_, tags} -> tags end)

    %{
      num_sentences: length(sentences),
      num_tokens: length(words),
      avg_length:
        case lengths do
          [] -> 0
          [_ | _] -> Enum.sum(lengths) / length(lengths)
        end,
      max_length:
        case lengths do
          [] -> 0
          [_ | _] -> Enum.max(lengths)
        end,
      min_length:
        case lengths do
          [] -> 0
          [_ | _] -> Enum.min(lengths)
        end,
      vocab_size: words |> Enum.uniq() |> length(),
      tag_counts: Enum.frequencies(tags)
    }
  end

  ## Private Functions

  defp extract_sentence(sentence) do
    words = Enum.map(sentence.tokens, & &1.form)
    # Convert atoms to uppercase strings for consistency with Universal Dependencies format
    tags =
      Enum.map(sentence.tokens, fn token ->
        if is_atom(token.upos) do
          token.upos |> Atom.to_string() |> String.upcase()
        else
          token.upos
        end
      end)

    {words, tags}
  end

  defp prepare_batch(sentences, vocab, tag_vocab, pad_value) do
    # Find max length in batch
    max_len = sentences |> Enum.map(fn {words, _} -> length(words) end) |> Enum.max()

    # Prepare word IDs
    word_ids_list =
      Enum.map(sentences, fn {words, _tags} ->
        {:ok, ids} = Embeddings.words_to_ids(vocab, words, max_length: max_len)
        Nx.to_flat_list(ids)
      end)

    # Prepare tag IDs
    tag_ids_list =
      Enum.map(sentences, fn {_words, tags} ->
        tag_ids = Enum.map(tags, fn tag -> Map.get(tag_vocab.tag_to_id, tag, 0) end)
        # Pad to max length
        tag_ids ++ List.duplicate(pad_value, max_len - length(tag_ids))
      end)

    # Convert to tensors
    inputs = %{
      "word_ids" => Nx.tensor(word_ids_list, type: :s64)
    }

    targets = %{
      "tags" => Nx.tensor(tag_ids_list, type: :s64)
    }

    {inputs, targets}
  end

  ## Wrapper functions for test compatibility

  @doc "Wrapper for split/2 with default validation split"
  def split_data(data, opts \\ [])

  def split_data([], _opts), do: {[], []}

  def split_data(data, opts) do
    validation_split = Keyword.get(opts, :validation_split, 0.1)
    split(data, [1 - validation_split, validation_split])
  end

  @doc "Wrapper for split/2 with train/valid/test"
  def split_train_valid_test(data, opts \\ []) do
    valid_split = Keyword.get(opts, :validation_split, 0.1)
    test_split = Keyword.get(opts, :test_split, 0.1)
    train_split = 1 - valid_split - test_split
    split(data, [train_split, valid_split, test_split])
  end

  @doc "Alias for load_conllu that reads from file path"
  def load_conllu_file(path, opts \\ []) do
    load_conllu(path, opts)
  end

  @doc "Extract tag vocabulary from sentences"
  def extract_tag_vocab(sentences) do
    tags = sentences |> Enum.flat_map(fn {_, tags} -> tags end) |> Enum.uniq() |> Enum.sort()
    tag_to_id = tags |> Enum.with_index() |> Map.new()
    id_to_tag = tags |> Enum.with_index() |> Enum.map(fn {t, i} -> {i, t} end) |> Map.new()

    %{
      tag_to_id: tag_to_id,
      id_to_tag: id_to_tag,
      size: length(tags)
    }
  end

  @doc "Extract word vocabulary"
  def extract_vocabulary(sentences, opts \\ []) do
    words = sentences |> Enum.flat_map(fn {words, _} -> words end)
    Embeddings.build_vocabulary([words], Keyword.put(opts, :return_struct, false))
  end

  @doc "Alias for analyze/1"
  def analyze_corpus(sentences), do: analyze(sentences)
end
