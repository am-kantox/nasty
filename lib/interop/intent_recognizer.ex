defmodule Nasty.Interop.IntentRecognizer do
  @moduledoc """
  Recognizes intents from natural language sentences using semantic role labeling.

  This module acts as the bridge between natural language AST and code generation,
  extracting the action, target, and arguments needed to generate executable code.

  ## Intent Recognition Strategy

  1. **Sentence function** - Determines intent type:
     - Imperative → :action
     - Interrogative → :query
     - Declarative → :definition
     - Conditional markers → :conditional

  2. **Semantic frames** - Extracts action and parameters:
     - Predicate → action verb
     - Agent/Theme → target (what to act on)
     - Patient/Goal → arguments
     - Modifiers → constraints

  3. **Verb mapping** - Maps English verbs to code operations:
     - "sort" → Enum.sort
     - "filter" → Enum.filter
     - "map" → Enum.map
     - "calculate", "compute" → arithmetic ops
  """

  alias Nasty.AST.{Intent, Sentence, Token, VerbPhrase}
  alias Nasty.AST.Semantic.Frame, as: SemanticFrame

  @doc """
  Recognizes intent from a sentence.

  ## Examples

      iex> {:ok, document} = English.parse("Sort the list.")
      iex> sentence = List.first(document.paragraphs |> List.first() |> Map.get(:sentences))
      iex> {:ok, intent} = IntentRecognizer.recognize(sentence)
      iex> intent.type
      :action
      iex> intent.action
      "sort"
  """
  @spec recognize(Sentence.t()) :: {:ok, Intent.t()} | {:error, term()}
  def recognize(%Sentence{} = sentence) do
    # Step 1: Determine intent type from sentence function
    intent_type = classify_intent_type(sentence)

    # Step 2: Extract semantic frames from clause structure
    # Note: semantic_frames may not be populated in Clause yet, fallback to manual extraction
    frames =
      case sentence.main_clause do
        %{semantic_frames: sf} when is_list(sf) and length(sf) > 0 -> sf
        _ -> extract_frames_from_clause(sentence.main_clause)
      end

    # Step 3: Build intent from frames and sentence structure with enhanced extraction
    build_intent_from_sentence(intent_type, sentence, frames)

    # case build_intent_from_sentence(intent_type, sentence, frames) do
    #   {:ok, intent} -> {:ok, intent}
    #   {:error, reason} -> {:error, reason}
    # end
  end

  @doc """
  Recognizes intent from text by first parsing it.

  ## Examples

      iex> {:ok, intent} = IntentRecognizer.recognize_from_text("Filter the users by role.", language: :en)
      iex> intent.action
      "filter"
  """
  @spec recognize_from_text(String.t(), keyword()) :: {:ok, Intent.t()} | {:error, term()}
  def recognize_from_text(text, opts \\ [language: :en]) when is_binary(text) do
    with {:ok, document} <- Nasty.parse(text, opts),
         sentence when not is_nil(sentence) <- get_first_sentence(document) do
      recognize(sentence)
    else
      nil -> {:error, :no_sentence_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp classify_intent_type(%Sentence{function: :imperative}), do: :action
  defp classify_intent_type(%Sentence{function: :interrogative}), do: :query

  defp classify_intent_type(%Sentence{function: :declarative} = sentence) do
    # Check if declarative contains conditional markers
    if has_conditional_marker?(sentence) do
      :conditional
    else
      :definition
    end
  end

  defp classify_intent_type(_), do: :action

  defp has_conditional_marker?(sentence) do
    # Look for "if", "when", "unless" in tokens
    tokens = extract_all_tokens(sentence.main_clause)

    Enum.any?(tokens, fn token ->
      lemma = String.downcase(token.lemma || token.text)
      lemma in ["if", "when", "unless", "while"]
    end)
  end

  defp extract_frames_from_clause(nil), do: []

  defp extract_frames_from_clause(clause) do
    # Extract main verb from predicate (verb phrase)
    predicate_token =
      case clause.predicate do
        %VerbPhrase{head: head} when not is_nil(head) -> head
        _ -> nil
      end

    if predicate_token do
      # Create minimal semantic frame from clause structure
      frame = %SemanticFrame{
        predicate: predicate_token,
        roles: [],
        span: clause.span
      }

      [frame]
    else
      []
    end
  end

  defp build_intent_from_sentence(intent_type, sentence, frames) do
    # Get primary semantic frame (first one)
    primary_frame = List.first(frames)

    # Extract action verb
    action = extract_action(primary_frame, sentence)

    # Extract target (what to act on)
    target = extract_target(primary_frame, sentence)

    # Extract arguments
    arguments = extract_arguments(primary_frame, sentence)

    # Extract constraints (filters, conditions)
    constraints = extract_constraints(primary_frame, sentence)

    # Calculate confidence
    confidence = calculate_confidence(intent_type, action, target)

    intent =
      Intent.new(intent_type, action, sentence.language, sentence.span,
        target: target,
        arguments: arguments,
        constraints: constraints,
        confidence: confidence,
        metadata: %{
          sentence_function: sentence.function,
          has_semantic_frames: not is_nil(primary_frame)
        }
      )

    {:ok, intent}
  end

  defp extract_action(nil, sentence) do
    # Fallback: extract main verb from sentence
    tokens = extract_all_tokens(sentence.main_clause)

    verb =
      Enum.find(tokens, fn token ->
        token.pos_tag == :verb
      end)

    if verb do
      normalize_action(verb.lemma || verb.text)
    else
      "unknown"
    end
  end

  defp extract_action(%SemanticFrame{predicate: predicate}, _sentence) do
    normalize_action(predicate.lemma || predicate.text)
  end

  # Map English verbs to code operations
  # credo:disable-for-lines:36
  defp normalize_action(verb) do
    verb_lower = String.downcase(verb)

    case verb_lower do
      # List operations
      "sort" -> "sort"
      "filter" -> "filter"
      "map" -> "map"
      "transform" -> "map"
      "reduce" -> "reduce"
      "sum" -> "sum"
      "count" -> "count"
      "find" -> "find"
      "select" -> "filter"
      "reject" -> "reject"
      # Arithmetic
      "add" -> "add"
      "subtract" -> "subtract"
      "multiply" -> "multiply"
      "divide" -> "divide"
      "calculate" -> "calculate"
      "compute" -> "compute"
      # Comparisons
      "equal" -> "equal"
      "match" -> "match"
      "compare" -> "compare"
      "check" -> "check"
      # Assignment
      "assign" -> "assign"
      "set" -> "set"
      "define" -> "define"
      "be" -> "assign"
      # Default
      _ -> verb_lower
    end
  end

  defp extract_target(nil, sentence) do
    # Fallback: extract first noun phrase as target
    tokens = extract_all_tokens(sentence.main_clause)

    noun =
      Enum.find(tokens, fn token ->
        token.pos_tag in [:noun, :propn]
      end)

    if noun do
      normalize_variable_name(noun.text)
    else
      nil
    end
  end

  defp extract_target(%SemanticFrame{roles: roles}, _sentence) do
    # Look for patient, theme, or goal role
    target_role =
      Enum.find(roles, fn role ->
        role.type in [:patient, :theme, :goal]
      end)

    if target_role do
      normalize_variable_name(target_role.text)
    else
      nil
    end
  end

  defp extract_arguments(nil, _sentence), do: []

  defp extract_arguments(%SemanticFrame{roles: roles}, _sentence) do
    # Extract non-target core arguments and convert to terms
    roles
    |> Enum.filter(fn role ->
      role.type in [:agent, :source, :recipient, :instrument]
    end)
    |> Enum.map(fn role ->
      # Try to parse as literal value or keep as variable name
      parse_argument_value(role.text)
    end)
  end

  defp parse_argument_value(text) do
    # Try to parse as integer
    case Integer.parse(text) do
      {int, ""} ->
        int

      _ ->
        # Try to parse as float
        case Float.parse(text) do
          {float, ""} ->
            float

          _ ->
            # Keep as string/variable name
            normalize_variable_name(text)
        end
    end
  end

  defp extract_constraints(nil, sentence) do
    # Fallback: extract constraints from prepositional phrases and adverbials
    extract_constraints_from_sentence(sentence)
  end

  defp extract_constraints(%SemanticFrame{roles: roles}, sentence) do
    # Look for manner, purpose, or instrument roles that indicate constraints
    role_constraints =
      roles
      |> Enum.filter(fn role ->
        role.type in [:manner, :purpose, :instrument]
      end)
      |> Enum.map(&parse_constraint/1)
      |> Enum.reject(&is_nil/1)

    # Also extract from sentence structure for additional constraints
    sentence_constraints = extract_constraints_from_sentence(sentence)

    # Combine and deduplicate
    (role_constraints ++ sentence_constraints) |> Enum.uniq()
  end

  # Extract constraints from sentence prepositional phrases
  defp extract_constraints_from_sentence(sentence) do
    tokens = extract_all_tokens(sentence.main_clause)

    # Look for comparison patterns in tokens
    extract_comparison_constraints(tokens) ++
      extract_property_constraints(tokens) ++
      extract_range_constraints(tokens)
  end

  # Extract comparison constraints (greater than, less than, etc.)
  defp extract_comparison_constraints(tokens) do
    text = Enum.map_join(tokens, " ", & &1.text) |> String.downcase()

    comparisons = [
      {~r/greater than (\d+)/, :greater_than},
      {~r/more than (\d+)/, :greater_than},
      {~r/above (\d+)/, :greater_than},
      {~r/less than (\d+)/, :less_than},
      {~r/fewer than (\d+)/, :less_than},
      {~r/below (\d+)/, :less_than},
      {~r/at least (\d+)/, :greater_than_or_equal},
      {~r/at most (\d+)/, :less_than_or_equal}
    ]

    Enum.flat_map(comparisons, fn {pattern, op} ->
      case Regex.run(pattern, text) do
        [_, value] -> [{:comparison, op, String.to_integer(value)}]
        _ -> []
      end
    end)
  end

  # Extract property-based constraints (active, valid, etc.)
  defp extract_property_constraints(tokens) do
    property_words = ~w(active inactive valid invalid enabled disabled archived)

    tokens
    |> Enum.filter(fn token ->
      String.downcase(token.text) in property_words
    end)
    |> Enum.map(fn token ->
      property = String.downcase(token.text) |> String.to_atom()
      {:property, property, true}
    end)
  end

  # Extract range constraints (between X and Y)
  defp extract_range_constraints(tokens) do
    text = Enum.map_join(tokens, " ", & &1.text) |> String.downcase()

    case Regex.run(~r/between (\d+) and (\d+)/, text) do
      [_, min, max] ->
        [{:range, String.to_integer(min), String.to_integer(max)}]

      _ ->
        []
    end
  end

  defp parse_constraint(role) do
    text = String.downcase(role.text)

    cond do
      String.contains?(text, "greater than") ->
        # Extract value after "greater than"
        case Regex.run(~r/greater than (\d+)/, text) do
          [_, value] ->
            {:comparison, :greater_than, String.to_integer(value)}

          _ ->
            nil
        end

      String.contains?(text, "less than") ->
        case Regex.run(~r/less than (\d+)/, text) do
          [_, value] ->
            {:comparison, :less_than, String.to_integer(value)}

          _ ->
            nil
        end

      String.contains?(text, "equal to") or String.contains?(text, "equals") ->
        # Extract value
        case Regex.run(~r/equals? (?:to )?(.+)/, text) do
          [_, value] ->
            {:equality, String.trim(value)}

          _ ->
            nil
        end

      true ->
        nil
    end
  end

  defp calculate_confidence(intent_type, action, target) do
    base_confidence =
      case intent_type do
        :action -> 0.8
        :query -> 0.7
        :definition -> 0.75
        :conditional -> 0.65
      end

    # Boost confidence if we successfully extracted action and target
    boost =
      cond do
        action != "unknown" and not is_nil(target) -> 0.15
        action != "unknown" -> 0.1
        not is_nil(target) -> 0.05
        true -> 0.0
      end

    min(base_confidence + boost, 1.0)
  end

  # Normalize variable names: "the list" -> "list", "my users" -> "users"
  defp normalize_variable_name(text) do
    text
    |> String.downcase()
    |> String.replace(~r/^(the|a|an|my|your|our|their)\s+/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.trim()
  end

  defp extract_all_tokens(nil), do: []

  defp extract_all_tokens(clause) do
    # Extract tokens from subject and predicate
    subject_tokens =
      case clause.subject do
        nil ->
          []

        subject ->
          extract_tokens_from_phrase(subject)
      end

    predicate_tokens =
      case clause.predicate do
        nil -> []
        predicate -> extract_tokens_from_phrase(predicate)
      end

    subject_tokens ++ predicate_tokens
  end

  defp extract_tokens_from_phrase(%VerbPhrase{head: head, auxiliaries: aux, adverbials: adv}) do
    [head] ++ aux ++ Enum.flat_map(adv || [], &extract_tokens_from_phrase/1)
  end

  defp extract_tokens_from_phrase(%Token{} = token), do: [token]
  defp extract_tokens_from_phrase(_), do: []

  defp get_first_sentence(%{paragraphs: paragraphs}) do
    paragraphs
    |> List.first()
    |> case do
      nil -> nil
      paragraph -> List.first(paragraph.sentences)
    end
  end
end
