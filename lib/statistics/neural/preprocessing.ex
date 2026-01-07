defmodule Nasty.Statistics.Neural.Preprocessing do
  @moduledoc """
  Preprocessing utilities for neural models.

  Provides text normalization, augmentation, and feature extraction
  for neural network training.

  ## Features

  - Text normalization (lowercase, punctuation, etc.)
  - Character-level features
  - Data augmentation
  - Feature extraction (capitalization, word shape, etc.)
  - Sequence padding and truncation

  ## Example

      # Normalize text
      normalized = Preprocessing.normalize_text(text, lowercase: true)

      # Extract character sequences
      char_ids = Preprocessing.extract_char_features(words, char_vocab)

      # Augment training data
      augmented = Preprocessing.augment(sentences, methods: [:synonym, :shuffle])
  """

  alias Nasty.Statistics.Neural.Embeddings

  @doc """
  Normalizes text for neural model input.

  ## Parameters

    - `text` - Text to normalize
    - `opts` - Normalization options

  ## Options

    - `:lowercase` - Convert to lowercase (default: false)
    - `:remove_accents` - Remove accents/diacritics (default: false)
    - `:normalize_digits` - Replace digits with <NUM> (default: false)
    - `:normalize_urls` - Replace URLs with <URL> (default: false)
    - `:normalize_emails` - Replace emails with <EMAIL> (default: false)

  ## Returns

  Normalized text string.
  """
  @spec normalize_text(String.t(), keyword()) :: String.t()
  def normalize_text(text, opts \\ []) do
    text
    |> maybe_lowercase(Keyword.get(opts, :lowercase, false))
    |> maybe_remove_accents(Keyword.get(opts, :remove_accents, false))
    |> maybe_normalize_digits(Keyword.get(opts, :normalize_digits, false))
    |> maybe_normalize_urls(Keyword.get(opts, :normalize_urls, false))
    |> maybe_normalize_emails(Keyword.get(opts, :normalize_emails, false))
  end

  @doc """
  Extracts character-level features from words.

  Converts each word into a sequence of character IDs for use in
  character-level CNNs or embeddings.

  ## Parameters

    - `words` - List of words
    - `char_vocab` - Character vocabulary %{char => id}
    - `opts` - Extraction options

  ## Options

    - `:max_word_length` - Maximum characters per word (default: 20)
    - `:pad_value` - Padding value for short words (default: 0)

  ## Returns

  Tensor of shape `[num_words, max_word_length]` with character IDs.
  """
  @spec extract_char_features([String.t()], map(), keyword()) :: Nx.Tensor.t()
  def extract_char_features(words, char_vocab, opts \\ []) do
    max_word_length = Keyword.get(opts, :max_word_length, 20)
    pad_value = Keyword.get(opts, :pad_value, 0)
    unk_value = Map.get(char_vocab, "<UNK>", 1)

    char_ids =
      Enum.map(words, fn word ->
        chars = String.graphemes(word) |> Enum.take(max_word_length)

        ids =
          Enum.map(chars, fn char ->
            Map.get(char_vocab, char, unk_value)
          end)

        # Pad to max_word_length
        ids ++ List.duplicate(pad_value, max_word_length - length(ids))
      end)

    Nx.tensor(char_ids, type: :s64)
  end

  @doc """
  Builds character vocabulary from words.

  ## Parameters

    - `words` - List of words
    - `opts` - Vocabulary options

  ## Options

    - `:special_tokens` - Include special tokens (default: true)
    - `:min_freq` - Minimum character frequency (default: 1)

  ## Returns

    - `{:ok, char_vocab}` - Character to ID mapping
  """
  @spec build_char_vocabulary([String.t()], keyword()) :: {:ok, map()}
  def build_char_vocabulary(words, opts \\ []) do
    include_special = Keyword.get(opts, :special_tokens, true)
    min_freq = Keyword.get(opts, :min_freq, 1)

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

    char_vocab = chars |> Enum.with_index() |> Map.new()

    {:ok, char_vocab}
  end

  @doc """
  Extracts handcrafted features from words.

  Extracts linguistic features like capitalization, word shape, etc.
  Useful for augmenting neural models.

  ## Parameters

    - `words` - List of words

  ## Returns

  List of feature maps, one per word.

  ## Feature Types

  - `:is_capitalized` - First letter uppercase
  - `:is_all_caps` - All letters uppercase
  - `:is_numeric` - Contains numbers
  - `:has_hyphen` - Contains hyphen
  - `:word_shape` - Pattern (e.g., "Xxxxx" for "Hello")
  - `:prefix` - First 3 characters
  - `:suffix` - Last 3 characters
  """
  @spec extract_word_features([String.t()]) :: [map()]
  def extract_word_features(words) do
    Enum.map(words, fn word ->
      %{
        is_capitalized: capitalized?(word),
        is_all_caps: all_caps?(word),
        is_numeric: numeric?(word),
        has_hyphen: String.contains?(word, "-"),
        word_shape: word_shape(word),
        prefix: String.slice(word, 0..2),
        suffix: String.slice(word, -3..-1)
      }
    end)
  end

  @doc """
  Pads or truncates sequences to a fixed length.

  ## Parameters

    - `sequences` - List of sequences (lists)
    - `max_length` - Target length
    - `opts` - Padding options

  ## Options

    - `:pad_value` - Value to use for padding (default: 0)
    - `:truncate` - Truncation strategy: `:pre` or `:post` (default: `:post`)

  ## Returns

  List of sequences, all of length `max_length`.
  """
  @spec pad_sequences([list()], non_neg_integer(), keyword()) :: [list()]
  def pad_sequences(sequences, max_length, opts \\ []) do
    pad_value = Keyword.get(opts, :pad_value, 0)
    truncate = Keyword.get(opts, :truncate, :post)

    Enum.map(sequences, fn seq ->
      cond do
        length(seq) > max_length ->
          case truncate do
            :post -> Enum.take(seq, max_length)
            :pre -> Enum.drop(seq, length(seq) - max_length)
          end

        length(seq) < max_length ->
          seq ++ List.duplicate(pad_value, max_length - length(seq))

        true ->
          seq
      end
    end)
  end

  @doc """
  Augments training data with various techniques.

  ## Parameters

    - `sentences` - List of {words, tags} tuples
    - `opts` - Augmentation options

  ## Options

    - `:methods` - List of augmentation methods (default: [:synonym])
    - `:probability` - Probability of applying augmentation (default: 0.3)

  ## Augmentation Methods

    - `:shuffle` - Shuffle word order (for non-syntactic tasks)
    - `:dropout` - Randomly drop words
    - `:synonym` - Replace with synonyms (requires word embeddings)

  ## Returns

  Augmented list of sentences.

  ## Note

  This is a placeholder for future implementation.
  Full augmentation requires external resources (synonym dictionaries, etc.)
  """
  @spec augment([{[String.t()], [atom()]}], keyword()) :: [{[String.t()], [atom()]}]
  def augment(sentences, _opts \\ []) do
    # Placeholder - return original sentences
    # Future: implement word dropout, synonym replacement, etc.
    sentences
  end

  ## Private Functions

  defp maybe_lowercase(text, true), do: String.downcase(text)
  defp maybe_lowercase(text, false), do: text

  defp maybe_remove_accents(text, true) do
    # Simple accent removal (full implementation would use Unicode normalization)
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/[\u0300-\u036f]/, "")
  end

  defp maybe_remove_accents(text, false), do: text

  defp maybe_normalize_digits(text, true) do
    String.replace(text, ~r/\d+/, "<NUM>")
  end

  defp maybe_normalize_digits(text, false), do: text

  defp maybe_normalize_urls(text, true) do
    String.replace(text, ~r/https?:\/\/[^\s]+/, "<URL>")
  end

  defp maybe_normalize_urls(text, false), do: text

  defp maybe_normalize_emails(text, true) do
    String.replace(text, ~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, "<EMAIL>")
  end

  defp maybe_normalize_emails(text, false), do: text

  defp capitalized?(word) do
    first = String.first(word)
    first == String.upcase(first) and first =~ ~r/[A-Z]/
  end

  defp all_caps?(word) do
    word == String.upcase(word) and word =~ ~r/[A-Z]/
  end

  defp numeric?(word) do
    word =~ ~r/\d/
  end

  defp word_shape(word) do
    word
    |> String.graphemes()
    |> Enum.map(fn char ->
      cond do
        char =~ ~r/[A-Z]/ -> "X"
        char =~ ~r/[a-z]/ -> "x"
        char =~ ~r/\d/ -> "d"
        true -> char
      end
    end)
    |> Enum.join()
  end
end
