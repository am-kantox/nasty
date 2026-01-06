defmodule Nasty.AST.Entity do
  @moduledoc """
  Entity node representing a named entity (person, organization, location, etc.).

  Named Entity Recognition (NER) identifies and classifies entities mentioned in text.
  """

  alias Nasty.AST.{Node, Token}

  @typedoc """
  Entity type classification following common NER standards.

  ## People & Organizations
  - `:person` - Individual person ("Barack Obama")
  - `:org` - Organization ("Apple Inc.", "United Nations")

  ## Locations
  - `:loc` - Physical location ("Paris", "Mount Everest")
  - `:gpe` - Geopolitical entity ("France", "California")

  ## Temporal
  - `:date` - Specific date ("January 5, 2026")
  - `:time` - Time of day ("3:00 PM")

  ## Numerical
  - `:money` - Monetary value ("$100", "€50")
  - `:percent` - Percentage ("25%")
  - `:quantity` - Measurement ("5 kg", "10 meters")

  ## Other
  - `:event` - Named event ("World War II", "Olympics")
  - `:product` - Product or service ("iPhone", "Windows")
  - `:language` - Language name ("English", "Spanish")
  - `:misc` - Miscellaneous entities
  """
  @type entity_type ::
          :person
          | :org
          | :loc
          | :gpe
          | :date
          | :time
          | :money
          | :percent
          | :quantity
          | :event
          | :product
          | :language
          | :misc

  @type t :: %__MODULE__{
          text: String.t(),
          type: entity_type(),
          tokens: [Token.t()],
          canonical_form: String.t() | nil,
          confidence: float() | nil,
          span: Node.span()
        }

  @enforce_keys [:text, :type, :span]
  defstruct [
    :text,
    :type,
    :span,
    tokens: [],
    canonical_form: nil,
    confidence: nil
  ]

  @doc """
  Creates a new entity.

  ## Examples

      iex> tokens = [%Token{text: "John", ...}]
      iex> span = Node.make_span({1, 0}, 0, {1, 4}, 4)
      iex> Entity.new(:person, "John", tokens, span)
      %Entity{type: :person, text: "John", ...}
  """
  @spec new(entity_type(), String.t(), [Token.t()], Node.span(), keyword()) :: t()
  def new(type, text, tokens, span, opts \\ []) do
    %__MODULE__{
      type: type,
      text: text,
      tokens: tokens,
      span: span,
      canonical_form: Keyword.get(opts, :canonical_form),
      confidence: Keyword.get(opts, :confidence)
    }
  end

  @doc """
  Returns all supported entity types.
  """
  @spec entity_types() :: [entity_type()]
  def entity_types do
    [
      :person,
      :org,
      :loc,
      :gpe,
      :date,
      :time,
      :money,
      :percent,
      :quantity,
      :event,
      :product,
      :language,
      :misc
    ]
  end
end

defmodule Nasty.AST.Relation do
  @moduledoc """
  Relation node representing a semantic relationship between entities.

  Relations connect entities with typed relationships (e.g., "works_for", "located_in").
  """

  alias Nasty.AST.{Entity, Node}

  @typedoc """
  Relation type classification.

  Common semantic relations:
  - `:is_a` - Type/class membership ("cat is an animal")
  - `:part_of` - Part-whole relationship ("wheel is part of car")
  - `:located_in` - Spatial containment ("Paris is in France")
  - `:works_for` - Employment ("Alice works for Company")
  - `:founded_by` - Creation relationship
  - `:owns` - Ownership
  - `:married_to` - Personal relationship
  - Custom relation types as atoms
  """
  @type relation_type :: atom()

  @type t :: %__MODULE__{
          type: relation_type(),
          source: Entity.t(),
          target: Entity.t(),
          confidence: float() | nil,
          span: Node.span()
        }

  @enforce_keys [:type, :source, :target, :span]
  defstruct [
    :type,
    :source,
    :target,
    :span,
    confidence: nil
  ]
end

defmodule Nasty.AST.Reference do
  @moduledoc """
  Reference node representing anaphora and coreference.

  References link pronouns and referring expressions to their antecedents,
  building entity chains across sentences.
  """

  alias Nasty.AST.{Entity, Node, NounPhrase, Token}

  @typedoc """
  Reference type classification.

  - `:pronominal` - Pronoun reference ("he", "it", "they")
  - `:nominal` - Definite noun phrase ("the company", "the president")
  - `:proper` - Proper name ("Obama", "Microsoft")
  - `:demonstrative` - Demonstrative reference ("this", "that", "these")
  """
  @type reference_type :: :pronominal | :nominal | :proper | :demonstrative

  @type t :: %__MODULE__{
          type: reference_type(),
          referring_expression: Token.t() | NounPhrase.t(),
          antecedent: NounPhrase.t() | Entity.t() | nil,
          entity_chain_id: String.t() | nil,
          span: Node.span()
        }

  @enforce_keys [:type, :referring_expression, :span]
  defstruct [
    :type,
    :referring_expression,
    :span,
    antecedent: nil,
    entity_chain_id: nil
  ]
end

defmodule Nasty.AST.Event do
  @moduledoc """
  Event node representing actions, states, or processes.

  Events capture temporal and aspectual information about actions mentioned in text.
  """

  alias Nasty.AST.{Node, Token, VerbPhrase}

  @typedoc """
  Event type classification.

  - `:action` - Dynamic event with agent ("run", "build", "write")
  - `:state` - Static situation ("know", "believe", "exist")
  - `:process` - Gradual change ("grow", "decay", "develop")
  - `:achievement` - Instantaneous event ("arrive", "die", "win")
  """
  @type event_type :: :action | :state | :process | :achievement

  @typedoc """
  Temporal information about the event.

  - `tense` - Past, present, or future
  - `aspect` - Perfective, imperfective, progressive, etc.
  - `timestamp` - Specific time reference (if mentioned)
  """
  @type temporal_info :: %{
          tense: :past | :present | :future | nil,
          aspect: atom() | nil,
          timestamp: String.t() | nil
        }

  @type t :: %__MODULE__{
          type: event_type(),
          trigger: Token.t() | VerbPhrase.t(),
          participants: %{atom() => term()},
          temporal: temporal_info(),
          span: Node.span()
        }

  @enforce_keys [:type, :trigger, :span]
  defstruct [
    :type,
    :trigger,
    :span,
    participants: %{},
    temporal: %{tense: nil, aspect: nil, timestamp: nil}
  ]
end

defmodule Nasty.AST.Modality do
  @moduledoc """
  Modality node representing epistemic and deontic modality.

  Modality expresses the speaker's attitude toward the proposition:
  necessity, possibility, certainty, obligation, permission, etc.
  """

  alias Nasty.AST.{Node, Token}

  @typedoc """
  Modality type classification.

  ## Epistemic (knowledge-related)
  - `:certainty` - High confidence ("certainly", "definitely")
  - `:probability` - Likely but not certain ("probably", "likely")
  - `:possibility` - May or may not be true ("possibly", "maybe")

  ## Deontic (obligation/permission-related)
  - `:necessity` - Required ("must", "have to")
  - `:obligation` - Expected ("should", "ought to")
  - `:permission` - Allowed ("can", "may")

  ## Dynamic (ability-related)
  - `:ability` - Capable of ("can", "able to")
  """
  @type modality_type ::
          :certainty
          | :probability
          | :possibility
          | :necessity
          | :obligation
          | :permission
          | :ability

  @typedoc """
  Strength of the modal (0.0 to 1.0).

  - 1.0 = Strong modality ("must", "certainly")
  - 0.5 = Medium modality ("should", "probably")
  - 0.0 = Weak modality ("might", "possibly")
  """
  @type modal_strength :: float()

  @type t :: %__MODULE__{
          type: modality_type(),
          marker: Token.t(),
          strength: modal_strength(),
          span: Node.span()
        }

  @enforce_keys [:type, :marker, :strength, :span]
  defstruct [:type, :marker, :strength, :span]
end
