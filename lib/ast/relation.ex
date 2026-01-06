defmodule Nasty.AST.Relation do
  @moduledoc """
  Represents a semantic relation between two entities.

  Relations capture structured information like employment ("works_at"),
  organization structure ("founded"), location ("located_in"), etc.

  ## Examples

      %Relation{
        type: :works_at,
        subject: %Entity{text: "John Smith", type: :person},
        object: %Entity{text: "Google", type: :org},
        confidence: 0.9,
        evidence: "John Smith works at Google",
        span: {{1, 1}, {1, 30}},
        language: :en
      }
  """

  alias Nasty.AST.{Entity, Node}

  @type relation_type ::
          :works_at
          | :employed_by
          | :founded
          | :acquired_by
          | :subsidiary_of
          | :located_in
          | :based_in
          | :headquarters_in
          | :born_in
          | :educated_at
          | :member_of
          | :ceo_of
          | :part_of
          | :occurred_on
          | :founded_in
          | atom()

  @type t :: %__MODULE__{
          type: relation_type(),
          subject: Entity.t() | String.t(),
          object: Entity.t() | String.t(),
          confidence: float(),
          evidence: String.t() | nil,
          metadata: map(),
          span: Node.span() | nil,
          language: Node.language()
        }

  defstruct [
    :type,
    :subject,
    :object,
    confidence: 1.0,
    evidence: nil,
    metadata: %{},
    span: nil,
    language: :en
  ]

  @doc """
  Creates a new relation.

  ## Examples

      iex> Relation.new(:works_at, subject, object, :en)
      %Relation{type: :works_at, subject: subject, object: object, language: :en}

      iex> Relation.new(:works_at, subject, object, :en, confidence: 0.8)
      %Relation{type: :works_at, confidence: 0.8, ...}
  """
  @spec new(
          relation_type(),
          Entity.t() | String.t(),
          Entity.t() | String.t(),
          Node.language(),
          keyword()
        ) :: t()
  def new(type, subject, object, language, opts \\ []) do
    %__MODULE__{
      type: type,
      subject: subject,
      object: object,
      language: language,
      confidence: Keyword.get(opts, :confidence, 1.0),
      evidence: Keyword.get(opts, :evidence),
      metadata: Keyword.get(opts, :metadata, %{}),
      span: Keyword.get(opts, :span)
    }
  end

  @doc """
  Returns the inverse of a relation type.

  ## Examples

      iex> Relation.inverse_type(:works_at)
      :employed_by

      iex> Relation.inverse_type(:founded)
      :founded_by
  """
  @spec inverse_type(relation_type()) :: relation_type()
  def inverse_type(:works_at), do: :employed_by
  def inverse_type(:employed_by), do: :works_at
  def inverse_type(:founded), do: :founded_by
  def inverse_type(:founded_by), do: :founded
  def inverse_type(:acquired_by), do: :acquired
  def inverse_type(:acquired), do: :acquired_by
  def inverse_type(:located_in), do: :location_of
  def inverse_type(:location_of), do: :located_in
  def inverse_type(:member_of), do: :has_member
  def inverse_type(:has_member), do: :member_of
  def inverse_type(:part_of), do: :has_part
  def inverse_type(:has_part), do: :part_of
  def inverse_type(:ceo_of), do: :has_ceo
  def inverse_type(:has_ceo), do: :ceo_of
  def inverse_type(type), do: type

  @doc """
  Inverts a relation (swaps subject and object, inverts type).

  ## Examples

      iex> relation = Relation.new(:works_at, john, google, :en)
      iex> Relation.invert(relation)
      %Relation{type: :employed_by, subject: google, object: john}
  """
  @spec invert(t()) :: t()
  def invert(%__MODULE__{} = relation) do
    %{
      relation
      | type: inverse_type(relation.type),
        subject: relation.object,
        object: relation.subject
    }
  end

  @doc """
  Sorts relations by confidence (descending).

  ## Examples

      iex> relations = [%Relation{confidence: 0.5}, %Relation{confidence: 0.9}]
      iex> Relation.sort_by_confidence(relations)
      [%Relation{confidence: 0.9}, %Relation{confidence: 0.5}]
  """
  @spec sort_by_confidence([t()]) :: [t()]
  def sort_by_confidence(relations) do
    Enum.sort_by(relations, & &1.confidence, :desc)
  end

  @doc """
  Filters relations by type.

  ## Examples

      iex> Relation.filter_by_type(relations, :works_at)
      [%Relation{type: :works_at}, ...]
  """
  @spec filter_by_type([t()], relation_type()) :: [t()]
  def filter_by_type(relations, type) do
    Enum.filter(relations, &(&1.type == type))
  end

  @doc """
  Filters relations by minimum confidence threshold.

  ## Examples

      iex> Relation.filter_by_confidence(relations, 0.7)
      [%Relation{confidence: 0.9}, %Relation{confidence: 0.8}]
  """
  @spec filter_by_confidence([t()], float()) :: [t()]
  def filter_by_confidence(relations, min_confidence) do
    Enum.filter(relations, &(&1.confidence >= min_confidence))
  end

  @doc """
  Gets the text representation of subject.
  """
  @spec subject_text(t()) :: String.t()
  def subject_text(%__MODULE__{subject: %Entity{text: text}}), do: text
  def subject_text(%__MODULE__{subject: text}) when is_binary(text), do: text

  @doc """
  Gets the text representation of object.
  """
  @spec object_text(t()) :: String.t()
  def object_text(%__MODULE__{object: %Entity{text: text}}), do: text
  def object_text(%__MODULE__{object: text}) when is_binary(text), do: text

  @doc """
  Converts a relation to a human-readable string.

  ## Examples

      iex> Relation.to_string(relation)
      "John Smith works_at Google (confidence: 0.9)"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = relation) do
    subj = subject_text(relation)
    obj = object_text(relation)
    "#{subj} #{relation.type} #{obj} (confidence: #{Float.round(relation.confidence, 2)})"
  end
end
