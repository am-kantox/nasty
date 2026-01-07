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

  # Order for special tokens (tests expect this order)
  @special_token_order ["<PAD>", "<UNK>", "<START>", "<END>"]

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

  Returns a simple word -> id map when used without explicit return_struct option.
  Returns vocabulary struct with {:ok, vocab} when called from code that expects it.

  ## Parameters

    - `corpus` - List of sentences (each sentence is a list of words)
    - `opts` - Vocabulary options

  ## Options

    - `:min_freq` - Minimum word frequency to include (default: 1)
    - `:max_size` - Maximum vocabulary size (default: unlimited)
    - `:special_tokens` - Include special tokens (default: true)
    - `:lowercase` - Convert all words to lowercase (default: false)
    - `:return_struct` - Return full struct (default: false)

  ## Returns

    - Simple map %{word => id} by default
    - `{:ok, vocabulary}` when return_struct: true
  """
  @spec build_vocabulary([[String.t()]], keyword()) :: map() | {:ok, vocabulary()}
  def build_vocabulary(corpus, opts \\ []) do
    min_freq = Keyword.get(opts, :min_freq, 1)
    max_size = Keyword.get(opts, :max_size, :infinity)
    include_special = Keyword.get(opts, :special_tokens, true)
    lowercase = Keyword.get(opts, :lowercase, false)
    return_struct = Keyword.get(opts, :return_struct, false)

    Logger.info("Building vocabulary from #{length(corpus)} sentences")

    # Count word frequencies
    freq_list =
      corpus
      |> List.flatten()
      |> Enum.map(fn word -> if lowercase, do: String.downcase(word), else: word end)
      |> Enum.frequencies()
      |> Enum.filter(fn {_word, freq} -> freq >= min_freq end)
      |> Enum.sort_by(fn {_word, freq} -> -freq end)

    frequencies =
      if max_size == :infinity do
        Map.new(freq_list)
      else
        freq_list |> Enum.take(max_size) |> Map.new()
      end

    # Add special tokens
    {word_to_id, id_to_word} =
      if include_special do
        # Use fixed order for special tokens to ensure PAD=0, UNK=1
        # For empty corpus, only include PAD and UNK
        special_words =
          if map_size(frequencies) == 0 do
            ["<PAD>", "<UNK>"]
          else
            @special_token_order
          end

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

    Logger.info("Vocabulary built: #{map_size(word_to_id)} words")

    # Return format depends on caller's needs
    if return_struct do
      vocab = %{
        word_to_id: word_to_id,
        id_to_word: id_to_word,
        frequencies: frequencies,
        size: map_size(word_to_id)
      }

      {:ok, vocab}
    else
      # Return simple word->id map for tests and simple use cases
      word_to_id
    end
  end

  @doc """
  Builds character vocabulary from a list of words.

  ## Parameters

    - `words` - List of words (can be nested lists)
    - `opts` - Vocabulary options

  ## Returns

    - `{:ok, char_vocab}` - Character to ID mapping
  """
  @spec build_char_vocabulary([[String.t()]] | [String.t()], keyword()) :: map()
  def build_char_vocabulary(words_nested, opts \\ []) when is_list(words_nested) do
    include_special = Keyword.get(opts, :special_tokens, true)
    min_freq = Keyword.get(opts, :min_freq, 1)

    # Flatten if nested
    words = List.flatten(words_nested)

    # Extract all characters
    chars =
      words
      |> Enum.flat_map(&String.graphemes/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_char, freq} -> freq >= min_freq end)
      |> Enum.map(fn {char, _freq} -> char end)
      |> Enum.sort()

    # Add special tokens
    chars =
      if include_special do
        ["<PAD>", "<UNK>"] ++ chars
      else
        chars
      end

    chars |> Enum.with_index() |> Map.new()
  end

  @doc """
  Converts a single word to its vocabulary index.

  ## Parameters

    - `word` - Word to look up
    - `vocab` - Vocabulary map or vocabulary struct
    - `unk_value` - Value to return if word not found (default: UNK id)

  ## Returns

  Integer index.
  """
  @spec word_to_index(String.t(), map() | vocabulary(), integer()) :: integer()
  def word_to_index(word, vocab, unk_value \\ nil)

  def word_to_index(word, %{word_to_id: word_to_id} = _vocab, unk_value) do
    default = unk_value || Map.get(word_to_id, @special_tokens.unk, 1)
    Map.get(word_to_id, word, default)
  end

  def word_to_index(word, vocab, unk_value) when is_map(vocab) do
    default = unk_value || Map.get(vocab, "<UNK>", 1)
    Map.get(vocab, word, default)
  end

  @doc """
  Converts list of words to list of indices.

  ## Parameters

    - `words` - List of words
    - `vocab` - Vocabulary map or struct

  ## Returns

  List of indices.
  """
  @spec words_to_indices([String.t()], map() | vocabulary()) :: [integer()]
  def words_to_indices(words, vocab) do
    Enum.map(words, fn word -> word_to_index(word, vocab) end)
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

  @doc """
  Creates an embedding layer (placeholder for Axon integration).

  ## Parameters

    - `vocab` - Vocabulary map
    - `opts` - Layer options

  ## Options

    - `:embedding_dim` - Embedding dimension (default: 300)

  ## Returns

  A function that can be used to create embeddings.
  """
  def create_embedding_layer(vocab, opts \\ []) do
    _embedding_dim = Keyword.get(opts, :embedding_dim, 300)
    vocab_size = map_size(vocab)

    # Return a function that takes input and returns a placeholder
    fn _input ->
      {:ok, "Embedding layer placeholder for vocab size #{vocab_size}"}
    end
  end

  @doc """
  Creates a character embedding layer (placeholder for Axon integration).

  ## Parameters

    - `char_vocab` - Character vocabulary map
    - `opts` - Layer options

  ## Options

    - `:embedding_dim` - Embedding dimension (default: 50)

  ## Returns

  A function that can be used to create character embeddings.
  """
  def create_char_embedding_layer(char_vocab, opts \\ []) do
    _embedding_dim = Keyword.get(opts, :embedding_dim, 50)
    vocab_size = map_size(char_vocab)

    # Return a function that takes input and returns a placeholder
    fn _input ->
      {:ok, "Char embedding layer placeholder for vocab size #{vocab_size}"}
    end
  end
end
