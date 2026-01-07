defmodule Nasty.AST.Semantic.Entity do
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

defmodule Nasty.AST.Semantic.Relation do
  @moduledoc """
  Relation node representing a semantic relationship between entities.

  Relations connect entities with typed relationships (e.g., "works_for", "located_in").
  """

  alias Nasty.AST.Node
  alias Nasty.AST.Semantic.Entity

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

defmodule Nasty.AST.Semantic.Reference do
  @moduledoc """
  Reference node representing anaphora and coreference.

  References link pronouns and referring expressions to their antecedents,
  building entity chains across sentences.
  """

  alias Nasty.AST.{Node, NounPhrase, Token}
  alias Nasty.AST.Semantic.Entity

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

defmodule Nasty.AST.Semantic.Event do
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

defmodule Nasty.AST.Semantic.Modality do
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

defmodule Nasty.AST.Semantic.Role do
  @moduledoc """
  Semantic role assigned to a phrase in relation to a predicate.

  Represents the semantic function of a participant or circumstance
  in a predicate-argument structure (e.g., Agent, Patient, Location).

  Based on PropBank and VerbNet role inventories.
  """

  alias Nasty.AST.{Node, Phrase, Token}

  @typedoc """
  Semantic role types.

  ## Core roles (arguments)
  - `:agent` - Volitional causer/actor (typically subject of transitive)
  - `:patient` - Entity acted upon (typically direct object)
  - `:theme` - Entity undergoing action or in a state
  - `:experiencer` - Entity experiencing a mental/perceptual state
  - `:recipient` - Entity receiving something
  - `:beneficiary` - Entity benefiting from action
  - `:source` - Starting point of motion/transfer
  - `:goal` - Endpoint of motion/transfer

  ## Adjunct roles (modifiers)
  - `:location` - Place where action occurs
  - `:time` - Time when action occurs
  - `:manner` - How action is performed
  - `:instrument` - Tool/means used
  - `:purpose` - Reason/goal for action
  - `:cause` - Reason/cause of action
  - `:comitative` - Accompanying entity ("with X")
  """
  # Core
  @type role_type ::
          :agent
          | :patient
          | :theme
          | :experiencer
          | :recipient
          | :beneficiary
          | :source
          | :goal
          # Adjunct
          | :location
          | :time
          | :manner
          | :instrument
          | :purpose
          | :cause
          | :comitative

  @type t :: %__MODULE__{
          type: role_type(),
          phrase: Phrase.t() | nil,
          text: String.t(),
          span: Node.span()
        }

  @enforce_keys [:type, :text, :span]
  defstruct [:type, :phrase, :text, :span]

  @doc """
  Creates a new semantic role.
  """
  @spec new(role_type(), String.t(), Node.span(), keyword()) :: t()
  def new(type, text, span, opts \\ []) do
    %__MODULE__{
      type: type,
      text: text,
      span: span,
      phrase: Keyword.get(opts, :phrase)
    }
  end

  @doc """
  Checks if role is a core argument (not an adjunct).
  """
  @spec core_role?(t()) :: boolean()
  def core_role?(%__MODULE__{type: type}) do
    type in [:agent, :patient, :theme, :experiencer, :recipient, :beneficiary, :source, :goal]
  end

  @doc """
  Checks if role is an adjunct (not a core argument).
  """
  @spec adjunct_role?(t()) :: boolean()
  def adjunct_role?(%__MODULE__{} = role), do: not core_role?(role)
end

defmodule Nasty.AST.Semantic.Frame do
  @moduledoc """
  Semantic frame representing a predicate with its arguments and adjuncts.

  A frame captures the "who did what to whom, where, when, how" structure
  of a clause. Each frame is anchored by a predicate (typically a verb)
  and includes semantic roles for participants and circumstances.
  """

  alias Nasty.AST.{Node, Token}
  alias Nasty.AST.Semantic.Role

  @type t :: %__MODULE__{
          predicate: Token.t(),
          roles: [Role.t()],
          voice: :active | :passive | :unknown,
          span: Node.span()
        }

  @enforce_keys [:predicate, :roles, :span]
  defstruct [:predicate, :roles, :span, voice: :active]

  @doc """
  Creates a new semantic frame.
  """
  @spec new(Token.t(), [Role.t()], Node.span(), keyword()) :: t()
  def new(predicate, roles, span, opts \\ []) do
    %__MODULE__{
      predicate: predicate,
      roles: roles,
      span: span,
      voice: Keyword.get(opts, :voice, :active)
    }
  end

  @doc """
  Finds roles of a specific type in the frame.
  """
  @spec find_roles(t(), Role.role_type()) :: [Role.t()]
  def find_roles(%__MODULE__{roles: roles}, type) do
    Enum.filter(roles, fn role -> role.type == type end)
  end

  @doc """
  Gets the agent role if present.
  """
  @spec agent(t()) :: Role.t() | nil
  def agent(%__MODULE__{} = frame) do
    frame
    |> find_roles(:agent)
    |> List.first()
  end

  @doc """
  Gets the patient/theme role if present.
  """
  @spec patient(t()) :: Role.t() | nil
  def patient(%__MODULE__{} = frame) do
    case find_roles(frame, :patient) do
      [p | _] -> p
      [] -> frame |> find_roles(:theme) |> List.first()
    end
  end

  @doc """
  Returns core roles (arguments) only.
  """
  @spec core_roles(t()) :: [Role.t()]
  def core_roles(%__MODULE__{roles: roles}) do
    Enum.filter(roles, &Role.core_role?/1)
  end

  @doc """
  Returns adjunct roles (modifiers) only.
  """
  @spec adjunct_roles(t()) :: [Role.t()]
  def adjunct_roles(%__MODULE__{roles: roles}) do
    Enum.filter(roles, &Role.adjunct_role?/1)
  end
end

defmodule Nasty.AST.Semantic.Mention do
  @moduledoc """
  Mention of an entity in text, used for coreference resolution.

  A mention can be a pronoun, proper name, or definite noun phrase
  that refers to an entity. Mentions are linked together into
  coreference chains.
  """

  alias Nasty.AST.{Node, Phrase, Token}

  @typedoc """
  Mention types for coreference resolution.
  """
  @type mention_type ::
          :pronoun
          | :proper_name
          | :definite_np
          | :indefinite_np
          | :demonstrative

  @type gender :: :male | :female | :neutral | :plural | :unknown
  @type grammatical_number :: :singular | :plural | :unknown

  @type t :: %__MODULE__{
          text: String.t(),
          type: mention_type(),
          tokens: [Token.t()],
          phrase: Phrase.t() | nil,
          sentence_idx: non_neg_integer(),
          token_idx: non_neg_integer(),
          gender: gender(),
          number: grammatical_number(),
          entity_type: atom() | nil,
          span: Node.span()
        }

  @enforce_keys [:text, :type, :sentence_idx, :token_idx, :span]
  defstruct [
    :text,
    :type,
    :sentence_idx,
    :token_idx,
    :span,
    :phrase,
    tokens: [],
    gender: :unknown,
    number: :unknown,
    entity_type: nil
  ]

  @doc """
  Creates a new mention.
  """
  @spec new(
          String.t(),
          mention_type(),
          non_neg_integer(),
          non_neg_integer(),
          Node.span(),
          keyword()
        ) ::
          t()
  def new(text, type, sentence_idx, token_idx, span, opts \\ []) do
    %__MODULE__{
      text: text,
      type: type,
      sentence_idx: sentence_idx,
      token_idx: token_idx,
      span: span,
      tokens: Keyword.get(opts, :tokens, []),
      phrase: Keyword.get(opts, :phrase),
      gender: Keyword.get(opts, :gender, :unknown),
      number: Keyword.get(opts, :number, :unknown),
      entity_type: Keyword.get(opts, :entity_type)
    }
  end

  @doc """
  Checks if mention is pronominal.
  """
  @spec pronoun?(t()) :: boolean()
  def pronoun?(%__MODULE__{type: :pronoun}), do: true
  def pronoun?(_), do: false

  @doc """
  Checks if mention is a proper name.
  """
  @spec proper_name?(t()) :: boolean()
  def proper_name?(%__MODULE__{type: :proper_name}), do: true
  def proper_name?(_), do: false

  @doc """
  Checks if mention is a definite noun phrase.
  """
  @spec definite_np?(t()) :: boolean()
  def definite_np?(%__MODULE__{type: :definite_np}), do: true
  def definite_np?(_), do: false

  @doc """
  Checks if gender agreement holds between two mentions.
  """
  @spec gender_agrees?(t(), t()) :: boolean()
  def gender_agrees?(%__MODULE__{gender: :unknown}, _), do: true
  def gender_agrees?(_, %__MODULE__{gender: :unknown}), do: true
  def gender_agrees?(%__MODULE__{gender: g1}, %__MODULE__{gender: g2}), do: g1 == g2

  @doc """
  Checks if number agreement holds between two mentions.
  """
  @spec number_agrees?(t(), t()) :: boolean()
  def number_agrees?(%__MODULE__{number: :unknown}, _), do: true
  def number_agrees?(_, %__MODULE__{number: :unknown}), do: true
  def number_agrees?(%__MODULE__{number: n1}, %__MODULE__{number: n2}), do: n1 == n2
end

defmodule Nasty.AST.Semantic.CorefChain do
  @moduledoc """
  Coreference chain linking mentions that refer to the same entity.

  A chain contains all mentions of an entity throughout a document,
  along with a representative mention (typically the first proper name
  or most informative noun phrase).
  """

  alias Nasty.AST.Semantic.Mention

  @type t :: %__MODULE__{
          id: pos_integer(),
          mentions: [Mention.t()],
          representative: String.t(),
          entity_type: atom() | nil
        }

  @enforce_keys [:id, :mentions, :representative]
  defstruct [:id, :mentions, :representative, entity_type: nil]

  @doc """
  Creates a new coreference chain.
  """
  @spec new(pos_integer(), [Mention.t()], String.t(), keyword()) :: t()
  def new(id, mentions, representative, opts \\ []) do
    %__MODULE__{
      id: id,
      mentions: mentions,
      representative: representative,
      entity_type: Keyword.get(opts, :entity_type)
    }
  end

  @doc """
  Returns the first mention in the chain.
  """
  @spec first_mention(t()) :: Mention.t() | nil
  def first_mention(%__MODULE__{mentions: []}), do: nil
  def first_mention(%__MODULE__{mentions: [first | _]}), do: first

  @doc """
  Returns the last mention in the chain.
  """
  @spec last_mention(t()) :: Mention.t() | nil
  def last_mention(%__MODULE__{mentions: []}), do: nil
  def last_mention(%__MODULE__{mentions: mentions}), do: List.last(mentions)

  @doc """
  Counts mentions in the chain.
  """
  @spec mention_count(t()) :: non_neg_integer()
  def mention_count(%__MODULE__{mentions: mentions}), do: length(mentions)

  @doc """
  Finds mention at a specific sentence index.
  """
  @spec find_mention_at(t(), non_neg_integer()) :: [Mention.t()]
  def find_mention_at(%__MODULE__{mentions: mentions}, sentence_idx) do
    Enum.filter(mentions, fn m -> m.sentence_idx == sentence_idx end)
  end

  @doc """
  Selects the best representative mention from a list.

  Preference order:
  1. First proper name
  2. Longest definite NP
  3. First mention
  """
  @spec select_representative([Mention.t()]) :: String.t()
  def select_representative([]), do: ""

  def select_representative(mentions) do
    # Try to find proper name
    case Enum.find(mentions, &Mention.proper_name?/1) do
      %Mention{text: text} ->
        text

      nil ->
        # Find longest definite NP
        mentions
        |> Enum.filter(fn m -> m.type == :definite_np end)
        |> case do
          [] ->
            # Fall back to first mention
            mentions |> List.first() |> Map.get(:text)

          definite_nps ->
            definite_nps
            |> Enum.max_by(fn m -> String.length(m.text) end)
            |> Map.get(:text)
        end
    end
  end
end
