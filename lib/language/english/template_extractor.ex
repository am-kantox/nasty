defmodule Nasty.Language.English.TemplateExtractor do
  @moduledoc """
  Template-based information extraction with customizable patterns and slot filling.

  Allows defining extraction templates with typed slots that are filled by matching
  entities and patterns in text.

  ## Examples

      # Define a template
      template = %{
        name: "employment",
        pattern: "[PERSON] works at [ORG]",
        slots: [
          %{name: :employee, type: :PERSON, required: true},
          %{name: :employer, type: :ORG, required: true}
        ]
      }

      # Extract using template
      {:ok, results} = TemplateExtractor.extract(document, [template])
      # => [%{employee: "John Smith", employer: "Google", confidence: 0.85}]
  """

  alias Nasty.AST.{Document, Entity, Sentence}
  alias Nasty.Language.English.EntityRecognizer

  @type slot :: %{
          name: atom(),
          type: atom(),
          required: boolean(),
          multiple: boolean()
        }

  @type template :: %{
          name: String.t(),
          pattern: String.t(),
          slots: [slot()],
          metadata: map()
        }

  @type extraction_result :: %{
          template: String.t(),
          slots: map(),
          confidence: float(),
          evidence: String.t()
        }

  @doc """
  Extracts information using provided templates.

  ## Arguments

  - `document` - Document to extract from
  - `templates` - List of template definitions
  - `opts` - Options

  ## Options

  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:max_results` - Maximum results to return (default: unlimited)

  ## Examples

      iex> templates = [employment_template(), acquisition_template()]
      iex> TemplateExtractor.extract(document, templates)
      {:ok, [%{template: "employment", slots: %{...}, ...}]}
  """
  @spec extract(Document.t(), [template()], keyword()) :: {:ok, [extraction_result()]}
  def extract(%Document{} = document, templates, opts \\ []) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)
    max_results = Keyword.get(opts, :max_results, :infinity)

    # Get all sentences
    sentences = Document.all_sentences(document)

    # Extract using each template
    results =
      sentences
      |> Enum.flat_map(fn sentence ->
        Enum.flat_map(templates, fn template ->
          match_template(sentence, template, document.language)
        end)
      end)
      |> Enum.filter(&(&1.confidence >= min_confidence))
      |> Enum.sort_by(& &1.confidence, :desc)
      |> maybe_limit(max_results)

    {:ok, results}
  end

  @doc """
  Creates a template for employment relations.

  ## Examples

      iex> TemplateExtractor.employment_template()
      %{name: "employment", pattern: "[PERSON] works at [ORG]", ...}
  """
  @spec employment_template() :: template()
  def employment_template do
    %{
      name: "employment",
      pattern: "[PERSON] works at [ORG]",
      patterns: [
        "[PERSON] works at [ORG]",
        "[PERSON] employed by [ORG]",
        "[PERSON] joins [ORG]",
        "[PERSON] hired by [ORG]"
      ],
      slots: [
        %{name: :employee, type: :person, required: true, multiple: false},
        %{name: :employer, type: :org, required: true, multiple: false}
      ],
      metadata: %{relation_type: :works_at}
    }
  end

  @doc """
  Creates a template for acquisition events.
  """
  @spec acquisition_template() :: template()
  def acquisition_template do
    %{
      name: "acquisition",
      pattern: "[ORG] acquired [ORG]",
      patterns: [
        "[ORG] acquired [ORG]",
        "[ORG] bought [ORG]",
        "[ORG] purchased [ORG]",
        "[ORG] acquires [ORG]"
      ],
      slots: [
        %{name: :acquirer, type: :org, required: true, multiple: false},
        %{name: :target, type: :org, required: true, multiple: false},
        %{name: :amount, type: :money, required: false, multiple: false}
      ],
      metadata: %{event_type: :business_acquisition}
    }
  end

  @doc """
  Creates a template for location relations.
  """
  @spec location_template() :: template()
  def location_template do
    %{
      name: "location",
      pattern: "[ORG] located in [GPE]",
      patterns: [
        "[ORG] located in [GPE]",
        "[ORG] based in [GPE]",
        "[ORG] headquarters in [GPE]"
      ],
      slots: [
        %{name: :entity, type: :org, required: true, multiple: false},
        %{name: :location, type: :gpe, required: true, multiple: false}
      ],
      metadata: %{relation_type: :located_in}
    }
  end

  # Match a template against a sentence
  defp match_template(sentence, template, language) do
    # Get tokens and entities from sentence
    tokens = get_sentence_tokens(sentence)
    entities = EntityRecognizer.recognize(tokens)

    # Get all patterns (use patterns list if available, otherwise single pattern)
    patterns = Map.get(template, :patterns, [template.pattern])

    # Try each pattern
    patterns
    |> Enum.flat_map(fn pattern ->
      case try_match_pattern(pattern, entities, template.slots) do
        {:ok, filled_slots, confidence} ->
          [
            %{
              template: template.name,
              slots: filled_slots,
              confidence: confidence,
              evidence: sentence_text(sentence),
              metadata: Map.get(template, :metadata, %{})
            }
          ]

        :no_match ->
          []
      end
    end)
  end

  # Try to match a pattern and fill slots
  defp try_match_pattern(pattern, entities, slots) do
    # Parse pattern to extract slot positions
    slot_markers = extract_slot_markers(pattern)

    # Try to fill slots with entities
    case fill_slots(slot_markers, entities, slots) do
      {:ok, filled_slots} ->
        # Calculate confidence based on how well slots were filled
        confidence = calculate_confidence(filled_slots, slots)
        {:ok, filled_slots, confidence}

      :no_match ->
        :no_match
    end
  end

  # Extract slot markers from pattern (e.g., "[PERSON]", "[ORG]")
  defp extract_slot_markers(pattern) do
    ~r/\[(\w+)\]/
    |> Regex.scan(pattern, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.downcase/1)
    |> Enum.map(&String.to_atom/1)
  end

  # Fill slots with matching entities
  defp fill_slots(slot_markers, entities, slot_defs) do
    # Group entities by type
    entities_by_type = Enum.group_by(entities, & &1.type)

    # Try to fill each slot marker in order
    filled =
      slot_markers
      |> Enum.with_index()
      |> Enum.map(fn {marker_type, index} ->
        # Find corresponding slot definition
        slot_def = find_slot_for_type(slot_defs, marker_type)

        if slot_def do
          # Get entities of the required type
          matching_entities = Map.get(entities_by_type, marker_type, [])

          # Take the entity at the corresponding index (if available)
          entity = Enum.at(matching_entities, 0)

          if entity do
            {slot_def.name, entity.text}
          else
            nil
          end
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})

    # Check if all required slots were filled
    required_slots = Enum.filter(slot_defs, & &1.required)
    required_filled = Enum.all?(required_slots, &Map.has_key?(filled, &1.name))

    if required_filled do
      {:ok, filled}
    else
      :no_match
    end
  end

  # Find slot definition for a type
  defp find_slot_for_type(slot_defs, type) do
    Enum.find(slot_defs, &(&1.type == type))
  end

  # Calculate confidence based on slot filling
  defp calculate_confidence(filled_slots, slot_defs) do
    total_slots = length(slot_defs)
    filled_count = map_size(filled_slots)

    if total_slots > 0 do
      # Base confidence from fill rate
      base = filled_count / total_slots

      # Boost if all required slots filled
      required_slots = Enum.filter(slot_defs, & &1.required)
      required_filled = Enum.all?(required_slots, &Map.has_key?(filled_slots, &1.name))

      if required_filled do
        min(base + 0.2, 1.0)
      else
        base * 0.7
      end
    else
      0.5
    end
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
  defp get_phrase_tokens(%{head: head, determiner: det, modifiers: mods}) do
    tokens = [head | mods]
    if det, do: [det | tokens], else: tokens
  end

  defp get_phrase_tokens(%{head: head, auxiliaries: aux}) do
    [head | aux]
  end

  defp get_phrase_tokens(%{head: head}) do
    [head]
  end

  defp get_phrase_tokens(_), do: []

  # Get sentence text
  defp sentence_text(sentence) do
    sentence
    |> get_sentence_tokens()
    |> Enum.map(& &1.text)
    |> Enum.join(" ")
  end

  # Limit results if max specified
  defp maybe_limit(results, :infinity), do: results
  defp maybe_limit(results, max), do: Enum.take(results, max)
end
