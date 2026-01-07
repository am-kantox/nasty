defmodule Nasty.Statistics.Neural.Embeddings do
  @moduledoc """
  Word and character embedding utilities for neural models.

  Provides:
  - Pre-trained embedding loading (GloVe, FastText)
  - Random embedding initialization
  - Vocabulary management
  - Efficient embedding lookup
  - Embedding caching

  ## Example

      # Create vocabulary from corpus
      {:ok, vocab} = Embeddings.build_vocabulary(corpus, min_freq: 2)

      # Initialize random embeddings
      {:ok, embeddings} = Embeddings.init_random(vocab, embedding_dim: 300)

      # Load pre-trained GloVe embeddings
      {:ok, embeddings} = Embeddings.load_glove("glove.6B.300d.txt", vocab)

      # Look up word embeddings
      {:ok, vector} = Embeddings.lookup(embeddings, "cat")
  """

  require Logger

  @special_tokens %{
    pad: "<PAD>",
    unk: "<UNK>",
    start: "<START>",
    end: "<END>"
  }

  @type vocabulary :: %{
          word_to_id: map(),
          id_to_word: map(),
          frequencies: map(),
          size: non_neg_integer()
        }

  @type embeddings :: %{
          vocab: vocabulary(),
          vectors: Nx.Tensor.t(),
          embedding_dim: pos_integer()
        }

  @doc """
  Builds a vocabulary from a corpus of sentences.

  ## Parameters

    - `corpus` - List of sentences (each sentence is a list of words)
    - `opts` - Vocabulary options

  ## Options

    - `:min_freq` - Minimum word frequency to include (default: 1)
    - `:max_size` - Maximum vocabulary size (default: unlimited)
    - `:special_tokens` - Include special tokens (default: true)
    - `:lowercase` - Convert all words to lowercase (default: true)

  ## Returns

    - `{:ok, vocabulary}` - Vocabulary with word_to_id and id_to_word maps
  """
  @spec build_vocabulary([[String.t()]], keyword()) :: {:ok, vocabulary()}
  def build_vocabulary(corpus, opts \\ []) do
    min_freq = Keyword.get(opts, :min_freq, 1)
    max_size = Keyword.get(opts, :max_size, :infinity)
    include_special = Keyword.get(opts, :special_tokens, true)
    lowercase = Keyword.get(opts, :lowercase, true)

    Logger.info("Building vocabulary from #{length(corpus)} sentences")

    # Count word frequencies
    frequencies =
      corpus
      |> List.flatten()
      |> Enum.map(fn word -> if lowercase, do: String.downcase(word), else: word end)
      |> Enum.frequencies()
      |> Enum.filter(fn {_word, freq} -> freq >= min_freq end)
      |> Enum.sort_by(fn {_word, freq} -> -freq end)
      |> Enum.take(if max_size == :infinity, do: :infinity, else: max_size)
      |> Map.new()

    # Add special tokens
    {word_to_id, id_to_word} =
      if include_special do
        special_words = Map.values(@special_tokens)

        words_with_special =
          special_words ++ (frequencies |> Map.keys() |> Enum.reject(&(&1 in special_words)))

        word_to_id = words_with_special |> Enum.with_index() |> Map.new()

        id_to_word =
          words_with_special
          |> Enum.with_index()
          |> Enum.map(fn {w, i} -> {i, w} end)
          |> Map.new()

        {word_to_id, id_to_word}
      else
        words = Map.keys(frequencies)
        word_to_id = words |> Enum.with_index() |> Map.new()
        id_to_word = words |> Enum.with_index() |> Enum.map(fn {w, i} -> {i, w} end) |> Map.new()

        {word_to_id, id_to_word}
      end

    vocab = %{
      word_to_id: word_to_id,
      id_to_word: id_to_word,
      frequencies: frequencies,
      size: map_size(word_to_id)
    }

    Logger.info("Vocabulary built: #{vocab.size} words")

    {:ok, vocab}
  end

  @doc """
  Initializes random embeddings for a vocabulary.

  ## Parameters

    - `vocab` - Vocabulary struct
    - `opts` - Embedding options

  ## Options

    - `:embedding_dim` - Embedding dimensionality (default: 300)
    - `:init_method` - Initialization method: `:uniform`, `:normal`, `:xavier` (default: `:uniform`)
    - `:scale` - Initialization scale (default: 0.1)

  ## Returns

    - `{:ok, embeddings}` - Embeddings struct with random vectors
  """
  @spec init_random(vocabulary(), keyword()) :: {:ok, embeddings()}
  def init_random(vocab, opts \\ []) do
    embedding_dim = Keyword.get(opts, :embedding_dim, 300)
    init_method = Keyword.get(opts, :init_method, :uniform)
    scale = Keyword.get(opts, :scale, 0.1)

    Logger.info("Initializing random embeddings: #{vocab.size} x #{embedding_dim}")

    vectors =
      case init_method do
        :uniform ->
          Nx.Random.uniform({vocab.size, embedding_dim}, -scale, scale, type: :f32)

        :normal ->
          Nx.Random.normal({vocab.size, embedding_dim}, 0.0, scale, type: :f32)

        :xavier ->
          # Xavier initialization
          limit = :math.sqrt(6.0 / (vocab.size + embedding_dim))
          Nx.Random.uniform({vocab.size, embedding_dim}, -limit, limit, type: :f32)

        _ ->
          raise ArgumentError, "Unknown initialization method: #{init_method}"
      end

    embeddings = %{
      vocab: vocab,
      vectors: vectors,
      embedding_dim: embedding_dim
    }

    {:ok, embeddings}
  end

  @doc """
  Loads pre-trained GloVe embeddings.

  ## Parameters

    - `path` - Path to GloVe file (e.g., "glove.6B.300d.txt")
    - `vocab` - Vocabulary to load embeddings for
    - `opts` - Loading options

  ## Options

    - `:embedding_dim` - Expected embedding dimension (auto-detected if not provided)
    - `:lowercase` - Lowercase words when matching (default: true)

  ## Returns

    - `{:ok, embeddings}` - Embeddings struct with pre-trained vectors
    - `{:error, reason}` - Loading error

  ## GloVe Format

  Each line: `word val1 val2 ... valn`
  """
  @spec load_glove(Path.t(), vocabulary(), keyword()) :: {:ok, embeddings()} | {:error, term()}
  def load_glove(path, vocab, opts \\ []) do
    lowercase = Keyword.get(opts, :lowercase, true)

    Logger.info("Loading GloVe embeddings from #{path}")

    if File.exists?(path) do
      try do
        # Read first line to detect embedding dimension
        first_line = File.stream!(path) |> Enum.take(1) |> List.first()
        [_word | values] = String.split(first_line)
        embedding_dim = length(values)

        Logger.info("Detected embedding dimension: #{embedding_dim}")

        # Initialize embedding matrix with random values
        {:ok, embeddings} = init_random(vocab, embedding_dim: embedding_dim)

        # Load embeddings from file
        loaded_count =
          path
          |> File.stream!()
          |> Stream.map(&String.trim/1)
          |> Stream.filter(&(&1 != ""))
          |> Enum.reduce(0, fn line, count ->
            [word | values] = String.split(line)
            word = if lowercase, do: String.downcase(word), else: word

            case Map.get(vocab.word_to_id, word) do
              nil ->
                count

              word_id ->
                vector = Enum.map(values, &String.to_float/1)
                # Update embedding for this word
                embeddings.vectors
                |> Nx.put_slice([word_id, 0], Nx.tensor([vector]))

                count + 1
            end
          end)

        Logger.info("Loaded #{loaded_count} pre-trained embeddings")
        Logger.info("Coverage: #{Float.round(loaded_count / vocab.size * 100, 1)}%")

        {:ok, embeddings}
      rescue
        error -> {:error, error}
      end
    else
      {:error, :file_not_found}
    end
  end

  @doc """
  Looks up the embedding vector for a word.

  ## Parameters

    - `embeddings` - Embeddings struct
    - `word` - Word to look up
    - `opts` - Lookup options

  ## Options

    - `:default` - Return this if word not found (default: UNK embedding)

  ## Returns

    - `{:ok, vector}` - Embedding vector (Nx.Tensor)
    - `{:error, :not_found}` - Word not in vocabulary
  """
  @spec lookup(embeddings(), String.t(), keyword()) :: {:ok, Nx.Tensor.t()} | {:error, term()}
  def lookup(embeddings, word, opts \\ []) do
    case Map.get(embeddings.vocab.word_to_id, word) do
      nil ->
        # Try UNK token as fallback
        unk_token = @special_tokens.unk
        unk_id = Map.get(embeddings.vocab.word_to_id, unk_token)

        if unk_id do
          vector = Nx.slice_along_axis(embeddings.vectors, unk_id, 1, axis: 0)
          {:ok, Nx.squeeze(vector)}
        else
          case Keyword.get(opts, :default) do
            nil -> {:error, :not_found}
            default -> {:ok, default}
          end
        end

      word_id ->
        vector = Nx.slice_along_axis(embeddings.vectors, word_id, 1, axis: 0)
        {:ok, Nx.squeeze(vector)}
    end
  end

  @doc """
  Converts a list of words to a tensor of word IDs.

  ## Parameters

    - `vocab` - Vocabulary struct
    - `words` - List of words
    - `opts` - Conversion options

  ## Options

    - `:max_length` - Truncate or pad to this length (default: no padding)
    - `:pad_value` - Value to use for padding (default: PAD token ID)

  ## Returns

    - `{:ok, tensor}` - Tensor of word IDs
  """
  @spec words_to_ids(vocabulary(), [String.t()], keyword()) :: {:ok, Nx.Tensor.t()}
  def words_to_ids(vocab, words, opts \\ []) do
    max_length = Keyword.get(opts, :max_length)
    pad_id = Map.get(vocab.word_to_id, @special_tokens.pad, 0)
    unk_id = Map.get(vocab.word_to_id, @special_tokens.unk, 1)

    ids =
      words
      |> Enum.map(fn word ->
        Map.get(vocab.word_to_id, word, unk_id)
      end)

    # Apply max_length if specified
    ids =
      if max_length do
        cond do
          length(ids) > max_length ->
            Enum.take(ids, max_length)

          length(ids) < max_length ->
            ids ++ List.duplicate(pad_id, max_length - length(ids))

          true ->
            ids
        end
      else
        ids
      end

    {:ok, Nx.tensor(ids)}
  end

  @doc """
  Converts a tensor of word IDs back to words.

  ## Parameters

    - `vocab` - Vocabulary struct
    - `id_tensor` - Tensor of word IDs
    - `opts` - Conversion options

  ## Returns

    - `{:ok, words}` - List of words
  """
  @spec ids_to_words(vocabulary(), Nx.Tensor.t(), keyword()) :: {:ok, [String.t()]}
  def ids_to_words(vocab, id_tensor, _opts \\ []) do
    ids = Nx.to_flat_list(id_tensor)

    words =
      ids
      |> Enum.map(fn id ->
        Map.get(vocab.id_to_word, id, @special_tokens.unk)
      end)

    {:ok, words}
  end

  @doc """
  Returns special token IDs.
  """
  @spec special_token_ids(vocabulary()) :: map()
  def special_token_ids(vocab) do
    @special_tokens
    |> Enum.map(fn {name, token} ->
      {name, Map.get(vocab.word_to_id, token)}
    end)
    |> Enum.reject(fn {_name, id} -> is_nil(id) end)
    |> Map.new()
  end
end
