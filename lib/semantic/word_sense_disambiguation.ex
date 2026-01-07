defmodule Nasty.Semantic.WordSenseDisambiguation do
  @moduledoc """
  Word Sense Disambiguation (WSD) - determining which meaning of a word
  is used in a given context.

  This module provides a simplified, knowledge-based approach suitable for
  pure Elixir implementation. For state-of-the-art WSD, neural models
  trained on large corpora would be required.

  ## Approach

  1. **Lesk Algorithm**: Overlap between word definitions and context
  2. **Part-of-Speech filtering**: Use POS tags to narrow sense candidates
  3. **Context similarity**: Compare surrounding words with sense definitions
  4. **Frequency-based**: Default to most common sense

  ## Example

      iex> tokens = [%Token{text: "bank", pos_tag: :noun}, %Token{text: "river", pos_tag: :noun}]
      iex> sense = WSD.disambiguate("bank", tokens, language: :en)
      {:ok, %Sense{word: "bank", definition: "land alongside a body of water", pos: :noun}}
  """

  alias Nasty.AST.Token

  @type sense :: %{
          word: String.t(),
          definition: String.t(),
          pos: atom(),
          examples: [String.t()],
          frequency_rank: integer()
        }

  @doc """
  Callback for providing sense definitions for a word.
  Returns list of possible senses with definitions.
  """
  @callback get_senses(String.t(), atom()) :: [sense()]

  @doc """
  Callback for getting related words for a sense (synonyms, hypernyms).
  """
  @callback get_related_words(sense()) :: [String.t()]

  @optional_callbacks get_related_words: 1

  @doc """
  Disambiguates the sense of a target word given its context.

  ## Parameters

  - `impl` - Implementation module providing sense definitions
  - `target_word` - The word to disambiguate
  - `context_tokens` - List of tokens in the surrounding context
  - `opts` - Options
    - `:pos_tag` - POS tag of target word (helps filter senses)
    - `:window_size` - Context window size (default: 10)

  Returns `{:ok, sense}` or `{:error, reason}`.
  """
  @spec disambiguate(module(), String.t(), [Token.t()], keyword()) ::
          {:ok, sense()} | {:error, term()}
  def disambiguate(impl, target_word, context_tokens, opts \\ []) do
    pos_tag = Keyword.get(opts, :pos_tag)
    window_size = Keyword.get(opts, :window_size, 10)

    # Get all possible senses for the word
    all_senses = impl.get_senses(target_word, pos_tag)

    case all_senses do
      [] ->
        {:error, :no_senses_found}

      [single_sense] ->
        {:ok, single_sense}

      multiple_senses ->
        # Score each sense based on context overlap
        scored_senses = score_senses(impl, multiple_senses, context_tokens, window_size)

        best_sense =
          scored_senses
          |> Enum.max_by(fn {_sense, score} -> score end)
          |> elem(0)

        {:ok, best_sense}
    end
  end

  @doc """
  Scores senses using Lesk algorithm (context-definition overlap).
  """
  @spec score_senses(module(), [sense()], [Token.t()], integer()) :: [{sense(), float()}]
  def score_senses(impl, senses, context_tokens, window_size) do
    # Extract context words
    context_words =
      context_tokens
      |> Enum.take(window_size)
      |> Enum.map(&String.downcase(&1.text))
      |> MapSet.new()

    # Score each sense
    Enum.map(senses, fn sense ->
      score = calculate_sense_score(impl, sense, context_words)
      {sense, score}
    end)
  end

  @doc """
  Calculates overlap score between sense and context.
  """
  @spec calculate_sense_score(module(), sense(), MapSet.t()) :: float()
  def calculate_sense_score(impl, sense, context_words) do
    # Base score from frequency (most common sense preferred)
    frequency_score = 1.0 / (sense[:frequency_rank] || 1)

    # Definition overlap
    definition_words =
      sense[:definition]
      |> String.downcase()
      |> String.split(~r/\W+/)
      |> MapSet.new()

    definition_overlap = MapSet.intersection(context_words, definition_words) |> MapSet.size()

    # Example overlap
    example_overlap =
      (sense[:examples] || [])
      |> Enum.flat_map(&String.split(&1, ~r/\W+/))
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()
      |> MapSet.intersection(context_words)
      |> MapSet.size()

    # Related words overlap (if available)
    related_overlap =
      if function_exported?(impl, :get_related_words, 1) do
        impl.get_related_words(sense)
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()
        |> MapSet.intersection(context_words)
        |> MapSet.size()
      else
        0
      end

    # Weighted combination
    frequency_score * 0.2 +
      definition_overlap * 0.4 +
      example_overlap * 0.2 +
      related_overlap * 0.2
  end

  @doc """
  Disambiguates all content words in a list of tokens.

  Returns list of {token, sense} tuples.
  """
  @spec disambiguate_all(module(), [Token.t()], keyword()) :: [{Token.t(), sense()}]
  def disambiguate_all(impl, tokens, _opts \\ []) do
    # Only disambiguate content words
    content_pos = [:noun, :verb, :adj, :adv, :propn]

    tokens
    |> Enum.with_index()
    |> Enum.filter(fn {token, _idx} -> token.pos_tag in content_pos end)
    |> Enum.map(fn {token, idx} ->
      # Get context window around token
      context = get_context_window(tokens, idx, 10)

      case disambiguate(impl, token.text, context, pos_tag: token.pos_tag) do
        {:ok, sense} -> {token, sense}
        {:error, _} -> {token, nil}
      end
    end)
    |> Enum.reject(fn {_token, sense} -> is_nil(sense) end)
  end

  # Get tokens in window around target index
  defp get_context_window(tokens, target_idx, window_size) do
    start_idx = max(0, target_idx - window_size)
    end_idx = min(length(tokens) - 1, target_idx + window_size)

    tokens
    |> Enum.slice(start_idx..end_idx)
    |> Enum.reject(&(&1 == Enum.at(tokens, target_idx)))
  end
end
