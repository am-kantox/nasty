defmodule Nasty.AST.Event do
  @moduledoc """
  Represents an event extracted from text.

  Events capture actions, occurrences, or states with their participants,
  temporal information, and location.

  ## Examples

      %Event{
        trigger: %Token{text: "acquired", lemma: "acquire"},
        type: :business_acquisition,
        participants: %{
          agent: %Entity{text: "Google", type: :org},
          patient: %Entity{text: "YouTube", type: :org},
          value: "1.65 billion"
        },
        time: "October 2006",
        confidence: 0.85,
        language: :en
      }
  """

  alias Nasty.AST.{Entity, Node, Token}

  @type event_type ::
          :business_acquisition
          | :business_merger
          | :product_launch
          | :employment_start
          | :employment_end
          | :company_founding
          | :meeting
          | :announcement
          | :election
          | :birth
          | :death
          | :movement
          | :transaction
          | :communication
          | atom()

  @type participant_role ::
          :agent | :patient | :theme | :recipient | :beneficiary | :instrument | atom()

  @type t :: %__MODULE__{
          trigger: Token.t() | String.t(),
          type: event_type(),
          participants: %{participant_role() => Entity.t() | String.t()},
          time: String.t() | nil,
          location: Entity.t() | String.t() | nil,
          confidence: float(),
          metadata: map(),
          span: Node.span() | nil,
          language: Node.language()
        }

  defstruct [
    :trigger,
    :type,
    participants: %{},
    time: nil,
    location: nil,
    confidence: 1.0,
    metadata: %{},
    span: nil,
    language: :en
  ]

  @doc """
  Creates a new event.

  ## Examples

      iex> Event.new(:business_acquisition, trigger, :en)
      %Event{type: :business_acquisition, trigger: trigger, language: :en}

      iex> Event.new(:business_acquisition, trigger, :en,
      ...>   participants: %{agent: buyer, patient: target},
      ...>   confidence: 0.8
      ...> )
      %Event{type: :business_acquisition, participants: %{agent: ..., patient: ...}, ...}
  """
  @spec new(event_type(), Token.t() | String.t(), Node.language(), keyword()) :: t()
  def new(type, trigger, language, opts \\ []) do
    %__MODULE__{
      type: type,
      trigger: trigger,
      language: language,
      participants: Keyword.get(opts, :participants, %{}),
      time: Keyword.get(opts, :time),
      location: Keyword.get(opts, :location),
      confidence: Keyword.get(opts, :confidence, 1.0),
      metadata: Keyword.get(opts, :metadata, %{}),
      span: Keyword.get(opts, :span)
    }
  end

  @doc """
  Adds a participant to an event.

  ## Examples

      iex> event = Event.new(:business_acquisition, trigger, :en)
      iex> Event.add_participant(event, :agent, buyer_entity)
      %Event{participants: %{agent: buyer_entity}}
  """
  @spec add_participant(t(), participant_role(), Entity.t() | String.t()) :: t()
  def add_participant(%__MODULE__{} = event, role, participant) do
    %{event | participants: Map.put(event.participants, role, participant)}
  end

  @doc """
  Gets a participant by role.

  ## Examples

      iex> Event.get_participant(event, :agent)
      %Entity{text: "Google", type: :org}

      iex> Event.get_participant(event, :missing_role)
      nil
  """
  @spec get_participant(t(), participant_role()) :: Entity.t() | String.t() | nil
  def get_participant(%__MODULE__{participants: participants}, role) do
    Map.get(participants, role)
  end

  @doc """
  Gets the text representation of the trigger.
  """
  @spec trigger_text(t()) :: String.t()
  def trigger_text(%__MODULE__{trigger: %Token{text: text}}), do: text
  def trigger_text(%__MODULE__{trigger: %Token{lemma: lemma}}) when is_binary(lemma), do: lemma
  def trigger_text(%__MODULE__{trigger: text}) when is_binary(text), do: text

  @doc """
  Sorts events by confidence (descending).

  ## Examples

      iex> events = [%Event{confidence: 0.5}, %Event{confidence: 0.9}]
      iex> Event.sort_by_confidence(events)
      [%Event{confidence: 0.9}, %Event{confidence: 0.5}]
  """
  @spec sort_by_confidence([t()]) :: [t()]
  def sort_by_confidence(events) do
    Enum.sort_by(events, & &1.confidence, :desc)
  end

  @doc """
  Filters events by type.

  ## Examples

      iex> Event.filter_by_type(events, :business_acquisition)
      [%Event{type: :business_acquisition}, ...]
  """
  @spec filter_by_type([t()], event_type()) :: [t()]
  def filter_by_type(events, type) do
    Enum.filter(events, &(&1.type == type))
  end

  @doc """
  Filters events by minimum confidence threshold.

  ## Examples

      iex> Event.filter_by_confidence(events, 0.7)
      [%Event{confidence: 0.9}, %Event{confidence: 0.8}]
  """
  @spec filter_by_confidence([t()], float()) :: [t()]
  def filter_by_confidence(events, min_confidence) do
    Enum.filter(events, &(&1.confidence >= min_confidence))
  end

  @doc """
  Filters events that have a specific participant role.

  ## Examples

      iex> Event.filter_by_participant(events, :agent)
      [%Event{participants: %{agent: ...}}, ...]
  """
  @spec filter_by_participant([t()], participant_role()) :: [t()]
  def filter_by_participant(events, role) do
    Enum.filter(events, fn event ->
      Map.has_key?(event.participants, role)
    end)
  end

  @doc """
  Converts an event to a human-readable string.

  ## Examples

      iex> Event.to_string(event)
      "business_acquisition: Google acquired YouTube (confidence: 0.85)"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = event) do
    trigger = trigger_text(event)
    participants_str = format_participants(event.participants)
    time_str = if event.time, do: " [#{event.time}]", else: ""

    "#{event.type}: #{trigger} #{participants_str}#{time_str} (confidence: #{Float.round(event.confidence, 2)})"
  end

  # Helper to format participants for display
  defp format_participants(participants) when map_size(participants) == 0, do: ""

  defp format_participants(participants) do
    Enum.map_join(participants, ", ", fn {role, entity} ->
      text =
        case entity do
          %Entity{text: t} -> t
          t when is_binary(t) -> t
          _ -> "?"
        end

      "#{role}:#{text}"
    end)
  end
end
