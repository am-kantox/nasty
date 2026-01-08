defmodule Nasty.Lexical.WordNet.Synset do
  @moduledoc """
  Represents a WordNet synset (synonym set) - a group of words that share the same meaning.

  A synset is the fundamental unit of WordNet, grouping together words (lemmas) that are
  synonymous and interchangeable in some context. Each synset has a unique ID, part of speech,
  definition, usage examples, and links to other synsets through semantic relations.

  ## Fields

  - `id` - Unique synset identifier (e.g., "oewn-02084071-n")
  - `pos` - Part of speech (:noun, :verb, :adj, :adv)
  - `definition` - Textual definition/gloss of the synset meaning
  - `examples` - List of example sentences demonstrating usage
  - `lemmas` - List of word forms (strings) in this synset
  - `language` - ISO 639-1 language code (:en, :es, :ca, etc.)
  - `ili` - Interlingual Index ID for cross-lingual linking (optional)

  ## Example

      %Synset{
        id: "oewn-02084071-n",
        pos: :noun,
        definition: "a member of the genus Canis",
        examples: ["the dog barked all night"],
        lemmas: ["dog", "domestic dog", "Canis familiaris"],
        language: :en,
        ili: "i2084071"
      }
  """

  @type pos_tag :: :noun | :verb | :adj | :adv
  @type language_code :: atom()

  @type t :: %__MODULE__{
          id: String.t(),
          pos: pos_tag(),
          definition: String.t(),
          examples: [String.t()],
          lemmas: [String.t()],
          language: language_code(),
          ili: String.t() | nil
        }

  @enforce_keys [:id, :pos, :definition, :language]
  defstruct [
    :id,
    :pos,
    :definition,
    :ili,
    examples: [],
    lemmas: [],
    language: :en
  ]

  @doc """
  Creates a new synset struct with validation.

  ## Examples

      iex> Synset.new("oewn-02084071-n", :noun, "a member of the genus Canis", :en)
      {:ok, %Synset{id: "oewn-02084071-n", pos: :noun, ...}}

      iex> Synset.new("invalid", :invalid, "definition", :en)
      {:error, :invalid_pos}
  """
  @spec new(String.t(), pos_tag(), String.t(), language_code(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def new(id, pos, definition, language, opts \\ []) do
    if valid_pos?(pos) do
      synset = %__MODULE__{
        id: id,
        pos: pos,
        definition: definition,
        language: language,
        examples: Keyword.get(opts, :examples, []),
        lemmas: Keyword.get(opts, :lemmas, []),
        ili: Keyword.get(opts, :ili)
      }

      {:ok, synset}
    else
      {:error, :invalid_pos}
    end
  end

  @doc """
  Checks if a part-of-speech tag is valid.
  """
  @spec valid_pos?(atom()) :: boolean()
  def valid_pos?(pos), do: pos in [:noun, :verb, :adj, :adv]

  @doc """
  Converts Universal Dependencies POS tag to WordNet POS tag.

  ## Examples

      iex> Synset.from_ud_pos(:propn)
      :noun

      iex> Synset.from_ud_pos(:aux)
      :verb
  """
  @spec from_ud_pos(atom()) :: pos_tag() | nil
  def from_ud_pos(ud_pos) do
    case ud_pos do
      pos when pos in [:noun, :propn] -> :noun
      pos when pos in [:verb, :aux] -> :verb
      pos when pos in [:adj] -> :adj
      pos when pos in [:adv] -> :adv
      _ -> nil
    end
  end

  @doc """
  Returns the primary lemma (first lemma in the synset).

  ## Examples

      iex> synset = %Synset{lemmas: ["dog", "domestic dog"]}
      iex> Synset.primary_lemma(synset)
      "dog"
  """
  @spec primary_lemma(t()) :: String.t() | nil
  def primary_lemma(%__MODULE__{lemmas: [first | _]}), do: first
  def primary_lemma(%__MODULE__{lemmas: []}), do: nil
end
