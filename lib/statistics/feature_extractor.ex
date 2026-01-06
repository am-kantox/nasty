defmodule Nasty.Statistics.FeatureExtractor do
  @moduledoc """
  Feature extraction utilities for statistical models.

  Extracts rich feature representations from tokens for use in
  machine learning models (HMM, MaxEnt, CRF, etc.).

  ## Feature Types

  - **Lexical**: Word form, lemma, lowercased form
  - **Contextual**: Words/POS tags in surrounding window
  - **Morphological**: Prefixes, suffixes, character n-grams
  - **Orthographic**: Capitalization patterns, digits, punctuation
  - **Positional**: Sentence/document position features

  ## Examples

      iex> token = %Token{text: "Running", pos_tag: :verb}
      iex> FeatureExtractor.extract_lexical(token)
      %{word: "Running", lowercase: "running", length: 7}

      iex> tokens = [token1, token2, token3]
      iex> FeatureExtractor.extract_context(tokens, 1, window: 1)
      %{prev_word: "The", next_word: "cat"}
  """

  alias Nasty.AST.Token

  @doc """
  Extract all features for a token in context.

  Combines lexical, morphological, orthographic, and contextual features.

  ## Parameters

    - `tokens` - List of all tokens in the sequence
    - `index` - Index of the target token
    - `opts` - Options
      - `:window` - Context window size (default: 2)
      - `:ngram_size` - Character n-gram size (default: 3)

  ## Returns

    - Feature map for the token
  """
  @spec extract_all([Token.t()], non_neg_integer(), keyword()) :: map()
  def extract_all(tokens, index, opts \\ []) do
    token = Enum.at(tokens, index)

    Map.merge(
      extract_lexical(token),
      extract_morphological(token, opts)
    )
    |> Map.merge(extract_orthographic(token))
    |> Map.merge(extract_context(tokens, index, opts))
    |> Map.merge(extract_positional(tokens, index))
  end

  @doc """
  Extract lexical features from a token.

  ## Features

  - `:word` - Original word form
  - `:lowercase` - Lowercased form
  - `:length` - Word length

  ## Examples

      iex> token = %Token{text: "Running"}
      iex> FeatureExtractor.extract_lexical(token)
      %{word: "Running", lowercase: "running", length: 7}
  """
  @spec extract_lexical(Token.t()) :: map()
  def extract_lexical(%Token{text: text}) do
    %{
      word: text,
      lowercase: String.downcase(text),
      length: String.length(text)
    }
  end

  @doc """
  Extract morphological features from a token.

  ## Features

  - `:prefix_N` - First N characters (for N in 1..4)
  - `:suffix_N` - Last N characters (for N in 1..4)
  - `:contains_hyphen` - Boolean
  - `:contains_digit` - Boolean

  ## Options

    - `:ngram_size` - Maximum n-gram size (default: 3)
  """
  @spec extract_morphological(Token.t(), keyword()) :: map()
  def extract_morphological(%Token{text: text}, opts \\ []) do
    ngram_size = Keyword.get(opts, :ngram_size, 3)
    lowercase = String.downcase(text)

    prefixes =
      1..min(ngram_size, String.length(text))
      |> Enum.map(fn n ->
        {String.to_atom("prefix_#{n}"), String.slice(lowercase, 0, n)}
      end)
      |> Enum.into(%{})

    suffixes =
      1..min(ngram_size, String.length(text))
      |> Enum.map(fn n ->
        {String.to_atom("suffix_#{n}"), String.slice(lowercase, -n, n)}
      end)
      |> Enum.into(%{})

    Map.merge(prefixes, suffixes)
    |> Map.merge(%{
      contains_hyphen: String.contains?(text, "-"),
      contains_digit: String.match?(text, ~r/\d/)
    })
  end

  @doc """
  Extract orthographic features from a token.

  ## Features

  - `:is_capitalized` - First letter uppercase
  - `:is_all_caps` - All letters uppercase
  - `:is_all_lower` - All letters lowercase
  - `:has_internal_caps` - Mixed case (e.g., "iPhone")
  - `:is_numeric` - Contains only digits
  - `:is_alphanumeric` - Contains letters and digits
  - `:has_punctuation` - Contains punctuation characters

  ## Examples

      iex> token = %Token{text: "iPhone"}
      iex> extract_orthographic(token)
      %{is_capitalized: false, has_internal_caps: true, ...}
  """
  @spec extract_orthographic(Token.t()) :: map()
  def extract_orthographic(%Token{text: text}) do
    first_char = String.first(text)
    has_upper = String.match?(text, ~r/[A-Z]/)
    has_lower = String.match?(text, ~r/[a-z]/)

    %{
      is_capitalized: first_char == String.upcase(first_char) and has_lower,
      is_all_caps: has_upper and not has_lower and String.length(text) > 1,
      is_all_lower: has_lower and not has_upper,
      has_internal_caps: has_upper and has_lower and String.length(text) > 1,
      is_numeric: String.match?(text, ~r/^\d+$/),
      is_alphanumeric: String.match?(text, ~r/^[a-zA-Z0-9]+$/),
      has_punctuation: String.match?(text, ~r/[[:punct:]]/)
    }
  end

  @doc """
  Extract contextual features from surrounding tokens.

  ## Features

  - `:prev_word_N` - Word N positions before (for N in 1..window)
  - `:next_word_N` - Word N positions after (for N in 1..window)
  - `:prev_pos_N` - POS tag N positions before (if available)
  - `:next_pos_N` - POS tag N positions after (if available)

  ## Options

    - `:window` - Context window size (default: 2)

  ## Examples

      iex> tokens = [token1, token2, token3]
      iex> extract_context(tokens, 1, window: 1)
      %{prev_word_1: "The", next_word_1: "cat"}
  """
  @spec extract_context([Token.t()], non_neg_integer(), keyword()) :: map()
  def extract_context(tokens, index, opts \\ []) do
    window = Keyword.get(opts, :window, 2)

    prev_features =
      1..window
      |> Enum.flat_map(fn n ->
        case Enum.at(tokens, index - n) do
          nil ->
            []

          %Token{text: text, pos_tag: pos_tag} ->
            features = [{String.to_atom("prev_word_#{n}"), String.downcase(text)}]

            if pos_tag do
              [{String.to_atom("prev_pos_#{n}"), pos_tag} | features]
            else
              features
            end
        end
      end)

    next_features =
      1..window
      |> Enum.flat_map(fn n ->
        case Enum.at(tokens, index + n) do
          nil ->
            []

          %Token{text: text, pos_tag: pos_tag} ->
            features = [{String.to_atom("next_word_#{n}"), String.downcase(text)}]

            if pos_tag do
              [{String.to_atom("next_pos_#{n}"), pos_tag} | features]
            else
              features
            end
        end
      end)

    Enum.into(prev_features ++ next_features, %{})
  end

  @doc """
  Extract positional features for a token.

  ## Features

  - `:position` - Absolute position in sequence (0-indexed)
  - `:relative_position` - Position as fraction of sequence length
  - `:is_first` - Boolean, true if first token
  - `:is_last` - Boolean, true if last token
  - `:distance_from_start` - Distance from beginning
  - `:distance_from_end` - Distance from end
  """
  @spec extract_positional([Token.t()], non_neg_integer()) :: map()
  def extract_positional(tokens, index) do
    length = length(tokens)

    %{
      position: index,
      relative_position: if(length > 0, do: index / length, else: 0.0),
      is_first: index == 0,
      is_last: index == length - 1,
      distance_from_start: index,
      distance_from_end: length - index - 1
    }
  end

  @doc """
  Extract features for an entire sequence of tokens.

  Returns a list of feature maps, one per token.

  ## Examples

      iex> tokens = [token1, token2, token3]
      iex> features = extract_sequence(tokens)
      [%{word: "The", ...}, %{word: "cat", ...}, %{word: "sat", ...}]
  """
  @spec extract_sequence([Token.t()], keyword()) :: [map()]
  def extract_sequence(tokens, opts \\ []) do
    tokens
    |> Enum.with_index()
    |> Enum.map(fn {_token, index} ->
      extract_all(tokens, index, opts)
    end)
  end

  @doc """
  Convert feature map to a list of binary feature indicators.

  Useful for models that expect binary feature vectors.

  ## Examples

      iex> features = %{word: "cat", is_capitalized: true, length: 3}
      iex> to_binary_features(features)
      ["word=cat", "is_capitalized=true", "length=3"]
  """
  @spec to_binary_features(map()) :: [String.t()]
  def to_binary_features(features) when is_map(features) do
    features
    |> Enum.map(fn {key, value} ->
      "#{key}=#{inspect(value)}"
    end)
    |> Enum.sort()
  end
end
