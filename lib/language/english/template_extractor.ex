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

  alias Nasty.AST.{Document, Sentence}
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

  @doc """
  Creates a template for product launch events.
  """
  @spec product_launch_template() :: template()
  def product_launch_template do
    %{
      name: "product_launch",
      pattern: "[ORG] launched [PRODUCT]",
      patterns: [
        "[ORG] launched [PRODUCT]",
        "[ORG] released [PRODUCT]",
        "[ORG] announced [PRODUCT]",
        "[ORG] unveiled [PRODUCT]"
      ],
      slots: [
        %{name: :company, type: :org, required: true, multiple: false},
        %{name: :product, type: :product, required: true, multiple: false},
        %{name: :date, type: :date, required: false, multiple: false}
      ],
      metadata: %{event_type: :product_launch}
    }
  end

  @doc """
  Creates a template for educational affiliations.
  """
  @spec education_template() :: template()
  def education_template do
    %{
      name: "education",
      pattern: "[PERSON] studied at [ORG]",
      patterns: [
        "[PERSON] studied at [ORG]",
        "[PERSON] graduated from [ORG]",
        "[PERSON] attended [ORG]",
        "[PERSON] earned degree from [ORG]"
      ],
      slots: [
        %{name: :student, type: :person, required: true, multiple: false},
        %{name: :institution, type: :org, required: true, multiple: false}
      ],
      metadata: %{relation_type: :educated_at}
    }
  end

  @doc """
  Creates a template for founding events.
  """
  @spec founding_template() :: template()
  def founding_template do
    %{
      name: "founding",
      pattern: "[PERSON] founded [ORG]",
      patterns: [
        "[PERSON] founded [ORG]",
        "[PERSON] co-founded [ORG]",
        "[PERSON] established [ORG]",
        "[PERSON] created [ORG]"
      ],
      slots: [
        %{name: :founder, type: :person, required: true, multiple: true},
        %{name: :organization, type: :org, required: true, multiple: false},
        %{name: :date, type: :date, required: false, multiple: false}
      ],
      metadata: %{event_type: :founding}
    }
  end

  @doc """
  Creates a template for parent-subsidiary relations.
  """
  @spec subsidiary_template() :: template()
  def subsidiary_template do
    %{
      name: "subsidiary",
      pattern: "[ORG] is a subsidiary of [ORG]",
      patterns: [
        "[ORG] is a subsidiary of [ORG]",
        "[ORG] owned by [ORG]",
        "[ORG] is a division of [ORG]",
        "[ORG] part of [ORG]"
      ],
      slots: [
        %{name: :subsidiary, type: :org, required: true, multiple: false},
        %{name: :parent, type: :org, required: true, multiple: false}
      ],
      metadata: %{relation_type: :subsidiary_of}
    }
  end

  # Match a template against a sentence
  defp match_template(sentence, template, _language) do
    # Get tokens and entities from sentence
    tokens = get_sentence_tokens(sentence)
    entities = EntityRecognizer.recognize(tokens)

    # Get all patterns (use patterns list if available, otherwise single pattern)
    patterns = Map.get(template, :patterns, [template.pattern])

    # Try each pattern
    patterns
    |> Enum.flat_map(fn pattern ->
      case try_match_pattern(pattern, tokens, entities, template.slots) do
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
  # Now verifies that pattern words appear in the sentence in correct order
  defp try_match_pattern(pattern, tokens, entities, slot_defs) do
    # Parse pattern into components (slot markers and literal words)
    pattern_parts = parse_pattern(pattern)

    # Try to match pattern against tokens and entities
    case match_pattern_parts(pattern_parts, tokens, entities, slot_defs) do
      {:ok, filled_slots} ->
        # Calculate confidence based on how well slots were filled
        confidence = calculate_confidence(filled_slots, slot_defs)
        {:ok, filled_slots, confidence}

      :no_match ->
        :no_match
    end
  end

  # Parse pattern into slot markers and literal words
  # E.g., "[ORG] acquired [ORG]" -> [{:slot, :org}, {:word, "acquired"}, {:slot, :org}]
  defp parse_pattern(pattern) do
    # Split by slot markers but keep them
    parts = Regex.split(~r/(\[\w+\])/, pattern, include_captures: true, trim: true)

    Enum.map(parts, fn part ->
      case Regex.run(~r/\[(\w+)\]/, part) do
        [_, type] ->
          {:slot, String.downcase(type) |> String.to_atom()}

        nil ->
          # Literal word(s) - normalize and split
          part
          |> String.trim()
          |> String.downcase()
          |> String.split()
          |> Enum.map(&{:word, &1})
      end
    end)
    |> List.flatten()
    |> Enum.reject(fn
      {:word, ""} -> true
      _ -> false
    end)
  end

  # Match pattern parts against tokens and entities
  defp match_pattern_parts(pattern_parts, tokens, entities, slot_defs) do
    # Create a map of token positions to entities
    entity_positions = build_entity_position_map(tokens, entities)

    # Try to find a matching sequence in the tokens
    case find_matching_sequence(pattern_parts, tokens, entity_positions, slot_defs, 0) do
      {:ok, filled_slots} -> {:ok, filled_slots}
      :no_match -> :no_match
    end
  end

  # Build a map of token index -> entity
  defp build_entity_position_map(tokens, entities) do
    entities
    |> Enum.flat_map(fn entity ->
      # Find token indices that are part of this entity
      tokens
      |> Enum.with_index()
      |> Enum.filter(fn {token, _idx} ->
        # Check if token is part of entity
        entity_tokens = Enum.map(entity.tokens, & &1.text)
        token.text in entity_tokens
      end)
      |> Enum.map(fn {_token, idx} -> {idx, entity} end)
    end)
    |> Enum.into(%{})
  end

  # Find a matching sequence starting from pos
  defp find_matching_sequence(pattern_parts, tokens, entity_positions, slot_defs, start_pos) do
    if start_pos >= length(tokens) do
      :no_match
    else
      case try_match_from_position(
             pattern_parts,
             tokens,
             entity_positions,
             slot_defs,
             start_pos,
             %{}
           ) do
        {:ok, filled_slots} ->
          {:ok, filled_slots}

        :no_match ->
          # Try next position
          find_matching_sequence(
            pattern_parts,
            tokens,
            entity_positions,
            slot_defs,
            start_pos + 1
          )
      end
    end
  end

  # Try to match pattern starting from a specific token position
  defp try_match_from_position([], _tokens, _entity_positions, _slot_defs, _pos, filled_slots) do
    # Successfully matched all pattern parts
    {:ok, filled_slots}
  end

  defp try_match_from_position(
         [{:slot, slot_type} | rest],
         tokens,
         entity_positions,
         slot_defs,
         pos,
         filled_slots
       ) do
    # Try to match a slot at this position
    case Map.get(entity_positions, pos) do
      %{type: ^slot_type} = entity ->
        # Entity matches the slot type
        # Find the first unfilled slot definition of this type
        slot_def = find_unfilled_slot_for_type(slot_defs, slot_type, filled_slots)

        if slot_def do
          # Add to filled slots
          new_filled = Map.put(filled_slots, slot_def.name, entity.text)
          # Skip past all tokens that are part of this entity
          entity_length = length(entity.tokens)

          try_match_from_position(
            rest,
            tokens,
            entity_positions,
            slot_defs,
            pos + entity_length,
            new_filled
          )
        else
          :no_match
        end

      _ ->
        :no_match
    end
  end

  defp try_match_from_position(
         [{:word, word} | rest],
         tokens,
         entity_positions,
         slot_defs,
         pos,
         filled_slots
       ) do
    # Try to match a literal word at this position
    case Enum.at(tokens, pos) do
      %{text: text} when is_binary(text) ->
        token_lemma = get_token_lemma(Enum.at(tokens, pos))

        if String.downcase(text) == word or token_lemma == word do
          # Word matches
          try_match_from_position(
            rest,
            tokens,
            entity_positions,
            slot_defs,
            pos + 1,
            filled_slots
          )
        else
          :no_match
        end

      _ ->
        :no_match
    end
  end

  defp try_match_from_position(_, _, _, _, _, _), do: :no_match

  # Get token lemma or text in lowercase
  defp get_token_lemma(token) do
    (token.lemma || token.text) |> String.downcase()
  end

  # Find the first unfilled slot definition of a given type
  defp find_unfilled_slot_for_type(slot_defs, type, filled_slots) do
    slot_defs
    |> Enum.filter(&(&1.type == type))
    |> Enum.find(&(not Map.has_key?(filled_slots, &1.name)))
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

  # Get sentence text
  defp sentence_text(sentence) do
    sentence
    |> get_sentence_tokens()
    |> Enum.map_join(" ", & &1.text)
  end

  # Limit results if max specified
  defp maybe_limit(results, :infinity), do: results
  defp maybe_limit(results, max), do: Enum.take(results, max)
end
