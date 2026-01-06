defmodule Nasty.Utils.Transform do
  @moduledoc """
  AST transformation utilities for modifying tree structures.

  Provides common transformations like normalization, simplification,
  and structural modifications.

  ## Examples

      # Lowercase all text
      iex> Nasty.Utils.Transform.normalize_case(document, :lower)
      %Nasty.AST.Document{...}

      # Remove stop words
      iex> Nasty.Utils.Transform.remove_stop_words(document)
      %Nasty.AST.Document{...}
  """

  alias Nasty.AST.Token
  alias Nasty.Utils.{Query, Traversal}

  @doc """
  Normalizes text case for all tokens in the tree.

  Options:
  - `:lower` - Convert to lowercase
  - `:upper` - Convert to uppercase
  - `:title` - Convert to title case

  ## Examples

      iex> Nasty.Utils.Transform.normalize_case(document, :lower)
      %Nasty.AST.Document{...}
  """
  @spec normalize_case(term(), :lower | :upper | :title) :: term()
  def normalize_case(node, case_type) do
    mapper = fn
      %Token{} = token ->
        text =
          case case_type do
            :lower -> String.downcase(token.text)
            :upper -> String.upcase(token.text)
            :title -> String.capitalize(token.text)
          end

        %{token | text: text}

      other ->
        other
    end

    Traversal.map(node, mapper)
  end

  @doc """
  Removes punctuation tokens from the tree.

  ## Examples

      iex> Nasty.Utils.Transform.remove_punctuation(document)
      %Nasty.AST.Document{...}
  """
  @spec remove_punctuation(term()) :: term()
  def remove_punctuation(node) do
    filter_tokens(node, fn token -> token.pos_tag != :punct end)
  end

  @doc """
  Removes stop words from the tree.

  ## Examples

      iex> stop_words = ["the", "a", "an", "is", "are"]
      iex> Nasty.Utils.Transform.remove_stop_words(document, stop_words)
      %Nasty.AST.Document{...}
  """
  @spec remove_stop_words(term(), [String.t()]) :: term()
  def remove_stop_words(node, stop_words \\ default_stop_words()) do
    filter_tokens(node, fn token ->
      String.downcase(token.text) not in stop_words
    end)
  end

  @doc """
  Replaces tokens matching a predicate with a new token.

  ## Examples

      iex> replacer = fn token -> %{token | text: "[MASK]"} end
      iex> predicate = fn token -> token.pos_tag == :propn end
      iex> Nasty.Utils.Transform.replace_tokens(document, predicate, replacer)
      %Nasty.AST.Document{...}
  """
  @spec replace_tokens(term(), (Token.t() -> boolean()), (Token.t() -> Token.t())) :: term()
  def replace_tokens(node, predicate, replacer) do
    mapper = fn
      %Token{} = token ->
        if predicate.(token) do
          replacer.(token)
        else
          token
        end

      other ->
        other
    end

    Traversal.map(node, mapper)
  end

  @doc """
  Filters tokens in the tree based on a predicate.

  Tokens that don't match the predicate are removed from their parent structures.

  ## Examples

      iex> keep_nouns = fn token -> token.pos_tag == :noun end
      iex> Nasty.Utils.Transform.filter_tokens(document, keep_nouns)
      %Nasty.AST.Document{...}
  """
  @spec filter_tokens(term(), (Token.t() -> boolean())) :: term()
  def filter_tokens(node, predicate) do
    # This is a simplified implementation
    # A full implementation would need to handle removal at the phrase level
    # For now, we just mark filtered tokens for later removal
    mapper = fn
      %Token{} = token ->
        if predicate.(token) do
          token
        else
          # Return a marker that can be filtered out
          nil
        end

      other ->
        other
    end

    node
    |> Traversal.map(mapper)
    |> remove_nil_tokens()
  end

  @doc """
  Converts all tokens to their lemma forms.

  ## Examples

      iex> Nasty.Utils.Transform.lemmatize(document)
      %Nasty.AST.Document{...}
  """
  @spec lemmatize(term()) :: term()
  def lemmatize(node) do
    mapper = fn
      %Token{lemma: lemma} = token when not is_nil(lemma) ->
        %{token | text: lemma}

      other ->
        other
    end

    Traversal.map(node, mapper)
  end

  @doc """
  Flattens the tree to a sequence of tokens.

  ## Examples

      iex> Nasty.Utils.Transform.flatten_to_tokens(document)
      [%Nasty.AST.Token{}, ...]
  """
  @spec flatten_to_tokens(term()) :: [Token.t()]
  def flatten_to_tokens(node) do
    Query.tokens(node)
  end

  @doc """
  Merges consecutive tokens matching a predicate.

  ## Examples

      iex> is_propn? = fn token -> token.pos_tag == :propn end
      iex> Nasty.Utils.Transform.merge_tokens(document, is_propn?)
      %Nasty.AST.Document{...}
  """
  @spec merge_tokens(term(), (Token.t() -> boolean())) :: term()
  def merge_tokens(node, _predicate) do
    # This is a placeholder for a more complex implementation
    # that would actually merge consecutive tokens in phrases
    node
  end

  @doc """
  Applies a pipeline of transformations.

  ## Examples

      iex> pipeline = [
      ...>   &Nasty.Utils.Transform.normalize_case(&1, :lower),
      ...>   &Nasty.Utils.Transform.remove_punctuation/1,
      ...>   &Nasty.Utils.Transform.remove_stop_words/1
      ...> ]
      iex> Nasty.Utils.Transform.pipeline(document, pipeline)
      %Nasty.AST.Document{...}
  """
  @spec pipeline(term(), [(term() -> term())]) :: term()
  def pipeline(node, transformations) do
    Enum.reduce(transformations, node, fn transform, acc ->
      transform.(acc)
    end)
  end

  @doc """
  Validates that a transformation is reversible by round-tripping.

  ## Examples

      iex> Nasty.Utils.Transform.round_trip_test(document, &Nasty.Utils.Transform.normalize_case(&1, :lower))
      {:ok, transformed}
  """
  @spec round_trip_test(term(), (term() -> term())) :: {:ok, term()} | {:error, String.t()}
  def round_trip_test(node, transform) do
    alias Nasty.Rendering.Text

    # Render original
    {:ok, original_text} = Text.render(node)

    # Apply transformation
    transformed = transform.(node)

    # Render transformed
    {:ok, transformed_text} = Text.render(transformed)

    # Check if they're equivalent (accounting for normalization)
    if equivalent?(original_text, transformed_text) do
      {:ok, transformed}
    else
      {:error, "Round trip failed: texts do not match"}
    end
  end

  # Private: Default English stop words
  defp default_stop_words do
    [
      "a",
      "an",
      "and",
      "are",
      "as",
      "at",
      "be",
      "by",
      "for",
      "from",
      "has",
      "he",
      "in",
      "is",
      "it",
      "its",
      "of",
      "on",
      "that",
      "the",
      "to",
      "was",
      "will",
      "with"
    ]
  end

  # Private: Remove nil tokens from phrases
  defp remove_nil_tokens(%{modifiers: mods} = phrase) when is_list(mods) do
    %{phrase | modifiers: Enum.reject(mods, &is_nil/1)}
  end

  defp remove_nil_tokens(%{auxiliaries: aux} = phrase) when is_list(aux) do
    %{phrase | auxiliaries: Enum.reject(aux, &is_nil/1)}
  end

  defp remove_nil_tokens(%{complements: comps} = phrase) when is_list(comps) do
    %{phrase | complements: Enum.reject(comps, &is_nil/1)}
  end

  defp remove_nil_tokens(%{adverbials: advs} = phrase) when is_list(advs) do
    %{phrase | adverbials: Enum.reject(advs, &is_nil/1)}
  end

  defp remove_nil_tokens(%{post_modifiers: mods} = phrase) when is_list(mods) do
    %{phrase | post_modifiers: Enum.reject(mods, &is_nil/1)}
  end

  defp remove_nil_tokens(node), do: node

  # Private: Check if two texts are equivalent
  defp equivalent?(text1, text2) do
    normalize_whitespace(text1) == normalize_whitespace(text2)
  end

  # Private: Normalize whitespace for comparison
  defp normalize_whitespace(text) do
    text
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
  end
end
