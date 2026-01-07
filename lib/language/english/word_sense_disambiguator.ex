defmodule Nasty.Language.English.WordSenseDisambiguator do
  @moduledoc """
  Simple English word sense disambiguation implementation.

  Provides basic sense definitions for common ambiguous words.
  For production use, integrate with WordNet or similar lexical database.

  ## Example

      iex> WSD.disambiguate("bank", [river_token], pos_tag: :noun)
      {:ok, %{definition: "land alongside water", ...}}
  """

  @behaviour Nasty.Semantic.WordSenseDisambiguation

  alias Nasty.AST.Token
  alias Nasty.Semantic.WordSenseDisambiguation, as: WSD

  # Sample sense dictionary for common ambiguous words
  @senses %{
    "bank" => [
      %{
        word: "bank",
        definition: "financial institution that accepts deposits",
        pos: :noun,
        examples: ["I need to go to the bank to deposit money"],
        frequency_rank: 1
      },
      %{
        word: "bank",
        definition: "land alongside a body of water",
        pos: :noun,
        examples: ["We sat on the river bank"],
        frequency_rank: 2
      }
    ],
    "bark" => [
      %{
        word: "bark",
        definition: "sound made by a dog",
        pos: :noun,
        examples: ["The dog's bark was loud"],
        frequency_rank: 1
      },
      %{
        word: "bark",
        definition: "outer covering of a tree",
        pos: :noun,
        examples: ["The bark protects the tree"],
        frequency_rank: 2
      },
      %{
        word: "bark",
        definition: "make the sound of a dog",
        pos: :verb,
        examples: ["The dog barked at the stranger"],
        frequency_rank: 1
      }
    ],
    "bat" => [
      %{
        word: "bat",
        definition: "flying nocturnal mammal",
        pos: :noun,
        examples: ["Bats sleep hanging upside down"],
        frequency_rank: 1
      },
      %{
        word: "bat",
        definition: "wooden stick used in sports",
        pos: :noun,
        examples: ["He swung the baseball bat"],
        frequency_rank: 2
      }
    ],
    "crane" => [
      %{
        word: "crane",
        definition: "large wading bird",
        pos: :noun,
        examples: ["The crane flew over the marsh"],
        frequency_rank: 1
      },
      %{
        word: "crane",
        definition: "machine for lifting heavy objects",
        pos: :noun,
        examples: ["The construction crane lifted steel beams"],
        frequency_rank: 2
      }
    ],
    "match" => [
      %{
        word: "match",
        definition: "small stick for making fire",
        pos: :noun,
        examples: ["Strike a match to light the candle"],
        frequency_rank: 1
      },
      %{
        word: "match",
        definition: "contest or game between opponents",
        pos: :noun,
        examples: ["We watched the tennis match"],
        frequency_rank: 2
      },
      %{
        word: "match",
        definition: "be equal or correspond to",
        pos: :verb,
        examples: ["These socks don't match"],
        frequency_rank: 1
      }
    ]
  }

  @impl true
  def get_senses(word, pos_tag \\ nil) do
    word_lower = String.downcase(word)

    case Map.get(@senses, word_lower) do
      nil ->
        []

      senses when is_nil(pos_tag) ->
        senses

      senses ->
        Enum.filter(senses, fn sense -> sense.pos == pos_tag end)
    end
  end

  @impl true
  def get_related_words(sense) do
    # Simple related words based on definition
    # In production, use WordNet synsets
    case {sense.word, sense.frequency_rank} do
      {"bank", 1} -> ["money", "deposit", "account", "finance"]
      {"bank", 2} -> ["river", "shore", "water", "stream"]
      {"bark", 1} -> ["dog", "sound", "animal", "woof"]
      {"bark", 2} -> ["tree", "wood", "trunk", "outer"]
      {"bat", 1} -> ["animal", "fly", "mammal", "night"]
      {"bat", 2} -> ["baseball", "hit", "sport", "swing"]
      {"crane", 1} -> ["bird", "heron", "water", "wading"]
      {"crane", 2} -> ["construction", "lift", "machine", "heavy"]
      {"match", 1} -> ["fire", "light", "flame", "ignite"]
      {"match", 2} -> ["game", "competition", "play", "opponent"]
      _ -> []
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
