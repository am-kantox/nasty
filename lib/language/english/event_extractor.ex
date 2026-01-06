defmodule Nasty.Language.English.EventExtractor do
  @moduledoc """
  Extracts events from documents using semantic role labeling and temporal expressions.

  Events are identified by trigger verbs or nominalizations, with participants
  extracted from semantic roles and temporal information from date/time expressions.

  ## Examples

      iex> {:ok, events} = EventExtractor.extract(document)
      {:ok, [
        %Event{
          type: :business_acquisition,
          trigger: %Token{text: "acquired"},
          participants: %{agent: google, patient: youtube},
          time: "October 2006"
        },
        ...
      ]}
  """

  alias Nasty.AST.{Document, Event, Sentence}
  alias Nasty.Language.English.{EntityRecognizer, SemanticRoleLabeler}

  # Event trigger verbs mapped to event types
  # Note: Include both full forms and stems since lemmatization may produce stems
  @event_triggers %{
    # Business events
    ~w(acquire acquired acquir buy bought purchase purchased takeover) => :business_acquisition,
    ~w(merge merged consolidate consolidated) => :business_merger,
    ~w(launch launched release released introduce introduced unveil unveiled) => :product_launch,
    ~w(found founded establish established start started create created) => :company_founding,
    # Employment events
    ~w(hire hired join joined recruit recruited appoint appointed) => :employment_start,
    ~w(resign resigned quit leave left fire fired layoff terminate terminated) => :employment_end,
    # Communication events
    ~w(announce announced say said state stated declare declared report reported) =>
      :announcement,
    ~w(meet met discuss discussed negotiate negotiated) => :meeting,
    # Movement events
    ~w(move moved travel traveled go went come came arrive arrived depart departed) => :movement,
    # Transaction events
    ~w(sell sold trade traded exchange exchanged transfer transferred) => :transaction
  }

  # Nominalization triggers (nouns that represent events)
  @nominalization_triggers %{
    ~w(acquisition takeover buyout purchase) => :business_acquisition,
    ~w(merger consolidation) => :business_merger,
    ~w(launch release introduction unveiling) => :product_launch,
    ~w(founding establishment creation) => :company_founding,
    ~w(hiring recruitment appointment) => :employment_start,
    ~w(resignation departure firing layoff termination) => :employment_end,
    ~w(announcement declaration statement) => :announcement,
    ~w(meeting discussion negotiation conference) => :meeting
  }

  @doc """
  Extracts events from a document.

  ## Options

  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:max_events` - Maximum events to return (default: unlimited)
  - `:event_types` - List of event types to extract (default: all)

  ## Examples

      iex> EventExtractor.extract(document, min_confidence: 0.7)
      {:ok, [%Event{confidence: 0.9}, ...]}
  """
  @spec extract(Document.t(), keyword()) :: {:ok, [Event.t()]}
  def extract(%Document{} = document, opts \\ []) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)
    max_events = Keyword.get(opts, :max_events, :infinity)

    # Get all sentences
    sentences = Document.all_sentences(document)

    # Extract events from each sentence
    events =
      sentences
      |> Enum.flat_map(fn sentence ->
        extract_from_sentence(sentence, document.language)
      end)
      |> Event.filter_by_confidence(min_confidence)
      |> Event.sort_by_confidence()
      |> maybe_limit(max_events)

    {:ok, events}
  end

  # Extract events from a single sentence
  defp extract_from_sentence(sentence, language) do
    # Get tokens
    tokens = get_sentence_tokens(sentence)

    # Get entities for participant extraction
    entities = EntityRecognizer.recognize(tokens)

    # Try to get semantic roles
    semantic_frames =
      case SemanticRoleLabeler.label(sentence) do
        {:ok, frames} -> frames
        _ -> []
      end

    # Extract temporal expressions
    temporal_expressions = extract_temporal_expressions(entities)

    # Find event triggers (verbs)
    verb_events = extract_verb_events(tokens, semantic_frames, temporal_expressions, language)

    # Find nominalization triggers
    nom_events =
      extract_nominalization_events(tokens, entities, temporal_expressions, language)

    verb_events ++ nom_events
  end

  # Extract events from verb triggers
  defp extract_verb_events(tokens, semantic_frames, temporal_expressions, language) do
    tokens
    |> Enum.filter(&(&1.pos_tag == :verb))
    |> Enum.flat_map(fn verb_token ->
      lemma = verb_token.lemma || String.downcase(verb_token.text)
      event_type = find_event_type(lemma, @event_triggers)

      if event_type do
        # Find semantic frame for this verb
        frame = find_semantic_frame(verb_token, semantic_frames)
        participants = extract_participants_from_frame(frame)
        time = List.first(temporal_expressions)

        [
          Event.new(event_type, verb_token, language,
            participants: participants,
            time: time,
            confidence: 0.8
          )
        ]
      else
        []
      end
    end)
  end

  # Extract events from nominalization triggers
  defp extract_nominalization_events(tokens, entities, temporal_expressions, language) do
    tokens
    |> Enum.filter(&(&1.pos_tag == :noun))
    |> Enum.flat_map(fn noun_token ->
      lemma = noun_token.lemma || String.downcase(noun_token.text)
      event_type = find_event_type(lemma, @nominalization_triggers)

      if event_type do
        # For nominalizations, extract participants from nearby entities
        participants = extract_participants_from_entities(entities, noun_token)
        time = List.first(temporal_expressions)

        [
          Event.new(event_type, noun_token, language,
            participants: participants,
            time: time,
            confidence: 0.7
          )
        ]
      else
        []
      end
    end)
  end

  # Find event type from trigger word
  defp find_event_type(word, trigger_map) do
    Enum.find_value(trigger_map, fn {triggers, type} ->
      if word in triggers, do: type, else: nil
    end)
  end

  # Find semantic frame for a verb
  defp find_semantic_frame(verb_token, frames) do
    Enum.find(frames, fn frame ->
      frame.predicate == verb_token.text || frame.predicate == verb_token.lemma
    end)
  end

  # Extract participants from semantic frame
  defp extract_participants_from_frame(nil), do: %{}

  defp extract_participants_from_frame(frame) do
    frame.roles
    |> Enum.map(fn role ->
      # Map SRL roles to event participant roles
      participant_role =
        case role.type do
          :agent -> :agent
          :patient -> :patient
          :theme -> :theme
          :recipient -> :recipient
          :beneficiary -> :beneficiary
          :instrument -> :instrument
          :location -> :location
          _ -> role.type
        end

      {participant_role, role.text}
    end)
    |> Enum.into(%{})
  end

  # Extract participants from nearby entities (for nominalizations)
  defp extract_participants_from_entities(entities, _trigger_token) do
    # Simple heuristic: first two entities as agent and patient
    case entities do
      [e1, e2 | _] ->
        %{agent: e1, patient: e2}

      [e1] ->
        %{agent: e1}

      [] ->
        %{}
    end
  end

  # Extract temporal expressions from entities
  defp extract_temporal_expressions(entities) do
    entities
    |> Enum.filter(&(&1.type in [:date, :time]))
    |> Enum.map(& &1.text)
  end

  # Get all tokens from a sentence
  defp get_sentence_tokens(%Sentence{main_clause: clause, additional_clauses: additional}) do
    main_tokens = get_clause_tokens(clause)
    additional_tokens = Enum.flat_map(additional, &get_clause_tokens/1)
    main_tokens ++ additional_tokens
  end

  # Get tokens from a clause
  defp get_clause_tokens(%{subject: subj, predicate: pred}) do
    subj_tokens = if subj, do: get_phrase_tokens(subj), else: []
    pred_tokens = get_phrase_tokens(pred)
    subj_tokens ++ pred_tokens
  end

  # Get tokens from a phrase
  defp get_phrase_tokens(%{
         head: head,
         determiner: det,
         modifiers: mods,
         post_modifiers: post_mods
       }) do
    # NounPhrase with post_modifiers
    tokens = [head | mods]
    tokens = if det, do: [det | tokens], else: tokens
    post_tokens = Enum.flat_map(post_mods, &get_phrase_tokens/1)
    tokens ++ post_tokens
  end

  defp get_phrase_tokens(%{head: head, determiner: det, modifiers: mods}) do
    # NounPhrase without post_modifiers
    tokens = [head | mods]
    if det, do: [det | tokens], else: tokens
  end

  defp get_phrase_tokens(%{head: head, auxiliaries: aux, complements: comps}) do
    # VerbPhrase with complements
    comp_tokens = Enum.flat_map(comps, &get_phrase_tokens/1)
    [head | aux] ++ comp_tokens
  end

  defp get_phrase_tokens(%{head: head, auxiliaries: aux}) do
    # VerbPhrase without complements field (shouldn't happen but be defensive)
    [head | aux]
  end

  defp get_phrase_tokens(%{head: head, object: obj}) do
    # PrepositionalPhrase
    [head | get_phrase_tokens(obj)]
  end

  defp get_phrase_tokens(%{head: head}) do
    [head]
  end

  defp get_phrase_tokens(_), do: []

  # Limit results if max specified
  defp maybe_limit(events, :infinity), do: events
  defp maybe_limit(events, max), do: Enum.take(events, max)
end
