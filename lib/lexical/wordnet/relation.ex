defmodule Nasty.Lexical.WordNet.Relation do
  @moduledoc """
  Represents a semantic relation between two WordNet synsets.

  Relations define how synsets are connected semantically. Common relations include
  hypernymy (is-a), meronymy (part-of), antonymy (opposite), and many others.

  ## Relation Types

  ### Taxonomic Relations
  - `:hypernym` - More general concept (dog → canine)
  - `:hyponym` - More specific concept (canine → dog)
  - `:instance_hypernym` - Instance to class (Einstein → physicist)
  - `:instance_hyponym` - Class to instance (physicist → Einstein)

  ### Part-Whole Relations
  - `:meronym` - Part-of (wheel → car)
  - `:holonym` - Whole-of (car → wheel)
  - `:member_meronym` - Member-of (player → team)
  - `:member_holonym` - Has-member (team → player)
  - `:substance_meronym` - Made-of (wood → tree)
  - `:substance_holonym` - Has-substance (tree → wood)

  ### Similarity/Difference
  - `:similar_to` - Similar meaning (big → large)
  - `:antonym` - Opposite meaning (hot → cold)
  - `:also_see` - Related concept

  ### Verb Relations
  - `:entailment` - Logical entailment (snore → sleep)
  - `:cause` - Causation (kill → die)
  - `:verb_group` - Semantically related verbs

  ### Adjective Relations
  - `:attribute` - Noun attribute (heavy → weight)
  - `:pertainym` - Pertains to (atomic → atom)

  ### Derivational Relations
  - `:derivationally_related` - Morphologically related words

  ## Fields

  - `type` - Relation type (see above)
  - `source_id` - Source synset ID
  - `target_id` - Target synset ID

  ## Example

      %Relation{
        type: :hypernym,
        source_id: "oewn-02084071-n",  # dog
        target_id: "oewn-02083346-n"   # canine
      }
  """

  @type relation_type ::
          :hypernym
          | :hyponym
          | :instance_hypernym
          | :instance_hyponym
          | :meronym
          | :holonym
          | :member_meronym
          | :member_holonym
          | :substance_meronym
          | :substance_holonym
          | :similar_to
          | :antonym
          | :also_see
          | :entailment
          | :cause
          | :verb_group
          | :attribute
          | :pertainym
          | :derivationally_related

  @type t :: %__MODULE__{
          type: relation_type(),
          source_id: String.t(),
          target_id: String.t()
        }

  @enforce_keys [:type, :source_id, :target_id]
  defstruct [:type, :source_id, :target_id]

  @doc """
  Creates a new relation.

  ## Examples

      iex> Relation.new(:hypernym, "oewn-02084071-n", "oewn-02083346-n")
      {:ok, %Relation{type: :hypernym, ...}}
  """
  @spec new(relation_type(), String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def new(type, source_id, target_id) do
    if valid_type?(type) do
      {:ok, %__MODULE__{type: type, source_id: source_id, target_id: target_id}}
    else
      {:error, :invalid_relation_type}
    end
  end

  @doc """
  Checks if a relation type is valid.
  """
  @spec valid_type?(atom()) :: boolean()
  def valid_type?(type) do
    type in [
      :hypernym,
      :hyponym,
      :instance_hypernym,
      :instance_hyponym,
      :meronym,
      :holonym,
      :member_meronym,
      :member_holonym,
      :substance_meronym,
      :substance_holonym,
      :similar_to,
      :antonym,
      :also_see,
      :entailment,
      :cause,
      :verb_group,
      :attribute,
      :pertainym,
      :derivationally_related
    ]
  end

  @doc """
  Returns the inverse relation type if it exists.

  ## Examples

      iex> Relation.inverse(:hypernym)
      {:ok, :hyponym}

      iex> Relation.inverse(:antonym)
      {:ok, :antonym}

      iex> Relation.inverse(:also_see)
      {:error, :no_inverse}
  """
  @spec inverse(relation_type()) :: {:ok, relation_type()} | {:error, :no_inverse}
  def inverse(type) do
    case type do
      :hypernym -> {:ok, :hyponym}
      :hyponym -> {:ok, :hypernym}
      :instance_hypernym -> {:ok, :instance_hyponym}
      :instance_hyponym -> {:ok, :instance_hypernym}
      :meronym -> {:ok, :holonym}
      :holonym -> {:ok, :meronym}
      :member_meronym -> {:ok, :member_holonym}
      :member_holonym -> {:ok, :member_meronym}
      :substance_meronym -> {:ok, :substance_holonym}
      :substance_holonym -> {:ok, :substance_meronym}
      :antonym -> {:ok, :antonym}
      :similar_to -> {:ok, :similar_to}
      _ -> {:error, :no_inverse}
    end
  end

  @doc """
  Checks if this is a taxonomic relation (hypernym/hyponym).
  """
  @spec taxonomic?(t()) :: boolean()
  def taxonomic?(%__MODULE__{type: type}) do
    type in [:hypernym, :hyponym, :instance_hypernym, :instance_hyponym]
  end

  @doc """
  Checks if this is a symmetric relation (same in both directions).
  """
  @spec symmetric?(relation_type()) :: boolean()
  def symmetric?(type) do
    type in [:antonym, :similar_to, :also_see, :verb_group, :derivationally_related]
  end
end
