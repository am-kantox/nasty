defmodule Nasty.Statistics.SequenceLabeling.Features do
  @moduledoc """
  Feature extraction for sequence labeling tasks (NER, POS tagging, etc.).

  Extracts rich feature representations from tokens including lexical,
  orthographic, POS, contextual, and gazetteer-based features.

  ## Feature Types

  1. **Lexical**: word, lowercased, lemma
  2. **Orthographic**: capitalization, shape, digits
  3. **POS**: part-of-speech tags
  4. **Context**: surrounding words and POS tags
  5. **Affixes**: prefixes and suffixes
  6. **Gazetteers**: matches in entity lists
  7. **Patterns**: special character patterns

  ## Examples

      iex> token = %Token{text: "John", pos_tag: :propn, lemma: "John"}
      iex> context = %{prev_word: "Mr.", next_word: "Smith", position: 1}
      iex> features = Features.extract(token, context)
      ["word=john", "pos=PROPN", "capitalized=true", "prefix-2=Jo", ...]
  """

  alias Nasty.AST.Token

  @type context :: %{
          optional(:prev_word) => String.t(),
          optional(:next_word) => String.t(),
          optional(:prev_pos) => atom(),
          optional(:next_pos) => atom(),
          optional(:prev_label) => atom(),
          optional(:position) => non_neg_integer(),
          optional(:sequence_length) => non_neg_integer()
        }

  @type feature :: String.t()
  @type feature_vector :: [feature()]

  @doc """
  Extracts features from a token given its context.

  ## Parameters

  - `token` - Token to extract features from
  - `context` - Contextual information (surrounding words, position, etc.)
  - `opts` - Options:
    - `:use_gazetteers` - Enable gazetteer features (default: true)
    - `:max_affix_length` - Maximum prefix/suffix length (default: 4)

  ## Returns

  List of feature strings
  """
  @spec extract(Token.t(), context(), keyword()) :: feature_vector()
  def extract(token, context \\ %{}, opts \\ []) do
    use_gazetteers = Keyword.get(opts, :use_gazetteers, true)
    max_affix = Keyword.get(opts, :max_affix_length, 4)

    [
      lexical_features(token),
      orthographic_features(token),
      pos_features(token),
      context_features(token, context),
      affix_features(token, max_affix),
      pattern_features(token)
    ]
    |> then(fn features ->
      if use_gazetteers do
        [gazetteer_features(token) | features]
      else
        features
      end
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc """
  Extracts features for an entire sequence of tokens.

  Automatically builds context for each token from surrounding tokens.

  ## Parameters

  - `tokens` - List of tokens
  - `opts` - Options passed to `extract/3`

  ## Returns

  List of feature vectors, one per token
  """
  @spec extract_sequence([Token.t()], keyword()) :: [feature_vector()]
  def extract_sequence(tokens, opts \\ []) do
    n = length(tokens)

    Enum.with_index(tokens)
    |> Enum.map(fn {token, i} ->
      context = build_context(tokens, i, n)
      extract(token, context, opts)
    end)
  end

  ## Feature Extractors

  # Lexical features: word, lowercased, lemma
  defp lexical_features(token) do
    [
      "word=#{token.text}",
      "word_lower=#{String.downcase(token.text)}"
    ]
    |> then(fn features ->
      if token.lemma do
        ["lemma=#{token.lemma}" | features]
      else
        features
      end
    end)
  end

  # Orthographic features: capitalization, word shape, digits
  defp orthographic_features(token) do
    text = token.text

    [
      "capitalized=#{capitalized?(text)}",
      "all_caps=#{all_caps?(text)}",
      "title_case=#{title_case?(text)}",
      "word_shape=#{word_shape(text)}",
      "short_word_shape=#{short_word_shape(text)}",
      "has_digit=#{has_digit?(text)}",
      "has_hyphen=#{String.contains?(text, "-")}",
      "has_punctuation=#{has_punctuation?(text)}"
    ]
  end

  # POS tag features
  defp pos_features(token) do
    if token.pos_tag do
      tag_str = token.pos_tag |> to_string() |> String.upcase()
      ["pos=#{tag_str}"]
    else
      []
    end
  end

  # Context features: surrounding words and POS tags
  defp context_features(_token, context) do
    [
      if(context[:prev_word], do: "prev_word=#{context[:prev_word]}", else: "prev_word=<START>"),
      if(context[:next_word], do: "next_word=#{context[:next_word]}", else: "next_word=<END>"),
      if(context[:prev_pos],
        do: "prev_pos=#{context[:prev_pos] |> to_string() |> String.upcase()}",
        else: nil
      ),
      if(context[:next_pos],
        do: "next_pos=#{context[:next_pos] |> to_string() |> String.upcase()}",
        else: nil
      ),
      if(context[:prev_label], do: "prev_label=#{context[:prev_label]}", else: nil),
      if(context[:position] == 0, do: "is_first=true", else: nil),
      if(
        context[:position] && context[:sequence_length] &&
          context[:position] == context[:sequence_length] - 1,
        do: "is_last=true",
        else: nil
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Prefix and suffix features
  defp affix_features(token, max_length) do
    text = String.downcase(token.text)

    prefixes =
      for len <- 1..min(max_length, String.length(text)),
          len <= String.length(text) do
        prefix = String.slice(text, 0, len)
        "prefix-#{len}=#{prefix}"
      end

    suffixes =
      for len <- 1..min(max_length, String.length(text)),
          len <= String.length(text) do
        suffix = String.slice(text, -len, len)
        "suffix-#{len}=#{suffix}"
      end

    prefixes ++ suffixes
  end

  # Pattern features
  defp pattern_features(token) do
    text = token.text

    [
      if(String.match?(text, ~r/^\d+$/), do: "pattern=all_digits", else: nil),
      if(String.match?(text, ~r/^\d{4}$/), do: "pattern=year", else: nil),
      if(String.match?(text, ~r/^\d+\.\d+$/), do: "pattern=decimal", else: nil),
      if(String.match?(text, ~r/^[A-Z]\.$/), do: "pattern=initial", else: nil),
      if(String.match?(text, ~r/^[A-Z]+$/), do: "pattern=acronym", else: nil),
      if(String.length(text) == 1, do: "length=1", else: nil),
      if(String.length(text) <= 3, do: "short_word=true", else: nil),
      if(String.length(text) >= 10, do: "long_word=true", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Gazetteer features: check if word appears in entity lists
  defp gazetteer_features(token) do
    word = String.downcase(token.text)

    [
      if(person_name?(word), do: "in_gazetteer=person", else: nil),
      if(place_name?(word), do: "in_gazetteer=place", else: nil),
      if(organization_name?(word), do: "in_gazetteer=org", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
  end

  ## Helper Functions

  # Build context map for token at position i
  defp build_context(tokens, i, n) do
    %{
      prev_word: if(i > 0, do: Enum.at(tokens, i - 1).text, else: nil),
      next_word: if(i < n - 1, do: Enum.at(tokens, i + 1).text, else: nil),
      prev_pos: if(i > 0, do: Enum.at(tokens, i - 1).pos_tag, else: nil),
      next_pos: if(i < n - 1, do: Enum.at(tokens, i + 1).pos_tag, else: nil),
      position: i,
      sequence_length: n
    }
  end

  # Capitalization checks
  defp capitalized?(text) do
    String.length(text) > 0 and String.at(text, 0) == String.upcase(String.at(text, 0))
  end

  defp all_caps?(text) do
    text == String.upcase(text) and String.match?(text, ~r/[A-Z]/)
  end

  defp title_case?(text) do
    words = String.split(text, " ")

    Enum.all?(words, fn word ->
      capitalized?(word) and String.length(word) > 1
    end)
  end

  # Word shape: abstract representation
  # "John" -> "Xxxx", "IBM" -> "XXX", "123" -> "ddd"
  defp word_shape(text) do
    text
    |> String.graphemes()
    |> Enum.map_join("", fn char ->
      cond do
        String.match?(char, ~r/[A-Z]/) -> "X"
        String.match?(char, ~r/[a-z]/) -> "x"
        String.match?(char, ~r/\d/) -> "d"
        true -> char
      end
    end)
  end

  # Short word shape: collapse consecutive same chars
  # "Xxxx" -> "Xx", "XXX" -> "X", "ddd" -> "d"
  defp short_word_shape(text) do
    text
    |> word_shape()
    |> String.graphemes()
    |> Enum.chunk_by(& &1)
    |> Enum.map_join("", &hd/1)
  end

  defp has_digit?(text) do
    String.match?(text, ~r/\d/)
  end

  defp has_punctuation?(text) do
    String.match?(text, ~r/[[:punct:]]/)
  end

  # Gazetteer lookups (simple subset - in production, load from files)
  defp person_name?(word) do
    word in ~w(
      john mary james patricia robert jennifer michael linda
      william elizabeth david barbara richard susan joseph jessica
      thomas sarah charles karen christopher nancy daniel betty
      matthew sandra anthony ashley mark donna paul michelle
      donald kimberly george emily kenneth lisa steven margaret
      mr mrs ms dr prof sir
    )
  end

  defp place_name?(word) do
    word in ~w(
      london paris tokyo beijing moscow dubai singapore sydney
      mumbai toronto barcelona madrid amsterdam berlin rome
      new york los angeles chicago houston phoenix philadelphia
      america canada mexico brazil china japan india russia
      germany france italy spain australia california texas
    )
  end

  defp organization_name?(word) do
    word in ~w(
      google apple microsoft amazon facebook meta tesla
      walmart toyota samsung ibm oracle netflix spotify
      harvard mit stanford oxford cambridge university
      nasa who unesco inc corp ltd llc company
    )
  end
end
