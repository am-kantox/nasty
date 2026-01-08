defmodule Nasty.Lexical.WordNet.Lemma do
  @moduledoc """
  Represents a WordNet lemma - a word form with a specific sense in a synset.

  A lemma is a specific word form that belongs to a synset. The same word can have multiple
  lemmas if it appears in different synsets (different senses). Lemmas connect the lexical
  level (words) to the semantic level (synsets/meanings).

  ## Fields

  - `word` - The word form/text (e.g., "dog", "run")
  - `pos` - Part of speech tag
  - `synset_id` - ID of the synset this lemma belongs to
  - `sense_key` - Unique identifier for this word-sense pair
  - `frequency` - Usage frequency (higher = more common), optional
  - `language` - Language code

  ## Example

      %Lemma{
        word: "dog",
        pos: :noun,
        synset_id: "oewn-02084071-n",
        sense_key: "dog%1:05:00::",
        frequency: 10,
        language: :en
      }
  """

  alias Nasty.Lexical.WordNet.Synset

  @type t :: %__MODULE__{
          word: String.t(),
          pos: Synset.pos_tag(),
          synset_id: String.t(),
          sense_key: String.t(),
          frequency: integer() | nil,
          language: Synset.language_code()
        }

  @enforce_keys [:word, :pos, :synset_id, :sense_key, :language]
  defstruct [
    :word,
    :pos,
    :synset_id,
    :sense_key,
    :frequency,
    :language
  ]

  @doc """
  Creates a new lemma struct.

  ## Examples

      iex> Lemma.new("dog", :noun, "oewn-02084071-n", "dog%1:05:00::", :en)
      {:ok, %Lemma{word: "dog", pos: :noun, ...}}
  """
  @spec new(
          String.t(),
          Synset.pos_tag(),
          String.t(),
          String.t(),
          Synset.language_code(),
          keyword()
        ) ::
          {:ok, t()} | {:error, term()}
  def new(word, pos, synset_id, sense_key, language, opts \\ []) do
    if Synset.valid_pos?(pos) do
      lemma = %__MODULE__{
        word: String.downcase(word),
        pos: pos,
        synset_id: synset_id,
        sense_key: sense_key,
        language: language,
        frequency: Keyword.get(opts, :frequency)
      }

      {:ok, lemma}
    else
      {:error, :invalid_pos}
    end
  end

  @doc """
  Returns a normalized version of the word for matching.

  Converts to lowercase and removes diacritics/special characters.
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(word) do
    word
    |> String.downcase()
    |> String.trim()
  end

  @doc """
  Checks if two lemmas are for the same word (case-insensitive).
  """
  @spec same_word?(t(), t()) :: boolean()
  def same_word?(%__MODULE__{word: w1}, %__MODULE__{word: w2}) do
    normalize(w1) == normalize(w2)
  end

  @doc """
  Checks if lemma matches a word and optional POS.
  """
  @spec matches?(t(), String.t(), Synset.pos_tag() | nil) :: boolean()
  def matches?(%__MODULE__{word: lemma_word, pos: _lemma_pos}, word, nil) do
    normalize(lemma_word) == normalize(word)
  end

  def matches?(%__MODULE__{word: lemma_word, pos: lemma_pos}, word, pos) do
    normalize(lemma_word) == normalize(word) and lemma_pos == pos
  end
end
