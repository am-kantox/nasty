defmodule Nasty.Language.English.WordSenseDisambiguator do
  @moduledoc """
  English word sense disambiguation using WordNet.

  Provides comprehensive word sense disambiguation by leveraging the full
  Open English WordNet database with 120K+ synsets.

  ## Example

      iex> WSD.disambiguate("bank", [river_token], pos_tag: :noun)
      {:ok, %{definition: "land alongside water", synset_id: "oewn-...", ...}}

  ## Features

  - Full WordNet coverage (120K+ synsets)
  - Automatic lemmatization and POS conversion
  - Context-based disambiguation using Lesk algorithm
  - Semantic similarity scoring
  - Frequency-based fallback
  """

  @behaviour Nasty.Semantic.WordSenseDisambiguation

  alias Nasty.AST.Token
  alias Nasty.Lexical.WordNet
  alias Nasty.Semantic.WordSenseDisambiguation, as: WSD

  # No hardcoded senses - using WordNet!

  @impl true
  def get_senses(word, pos_tag \\ nil) do
    # Convert UD POS tags to WordNet POS tags if needed
    wn_pos = convert_pos_tag(pos_tag)

    # Get synsets from WordNet
    synsets = WordNet.synsets(word, wn_pos, :en)

    # Convert synsets to sense format expected by WSD behaviour
    Enum.with_index(synsets, 1)
    |> Enum.map(fn {synset, rank} ->
      %{
        word: word,
        definition: synset.definition,
        pos: synset.pos,
        examples: synset.examples,
        frequency_rank: rank,
        synset_id: synset.id
      }
    end)
  end

  @impl true
  def get_related_words(sense) do
    synset_id = sense[:synset_id]

    if synset_id do
      # Get hypernyms (more general concepts)
      hypernym_ids = WordNet.hypernyms(synset_id, :en)

      hypernym_words =
        hypernym_ids
        |> Enum.flat_map(fn id ->
          case WordNet.synset(id, :en) do
            nil -> []
            synset -> synset.lemmas
          end
        end)

      # Get synonyms from same synset
      synset = WordNet.synset(synset_id, :en)
      synonyms = if synset, do: synset.lemmas, else: []

      # Combine and deduplicate
      (synonyms ++ hypernym_words)
      |> Enum.uniq()
      |> Enum.take(10)
    else
      # Fallback: extract words from definition
      sense[:definition]
      |> String.split(~r/\W+/)
      |> Enum.reject(&(String.length(&1) < 3))
      |> Enum.take(5)
    end
  end

  # Private helpers

  defp convert_pos_tag(nil), do: nil

  defp convert_pos_tag(pos_tag) when is_atom(pos_tag) do
    case pos_tag do
      pos when pos in [:noun, :propn] -> :noun
      pos when pos in [:verb, :aux] -> :verb
      :adj -> :adj
      :adv -> :adv
      _ -> nil
    end
  end

  @doc """
  Public API: Disambiguate a word in context.
  """
  @spec disambiguate(String.t(), [Token.t()], keyword()) ::
          {:ok, WSD.sense()} | {:error, term()}
  def disambiguate(word, context_tokens, opts \\ []) do
    WSD.disambiguate(__MODULE__, word, context_tokens, opts)
  end

  @doc """
  Public API: Disambiguate all content words.
  """
  @spec disambiguate_all([Token.t()], keyword()) :: [{Token.t(), WSD.sense()}]
  def disambiguate_all(tokens, opts \\ []) do
    WSD.disambiguate_all(__MODULE__, tokens, opts)
  end
end
