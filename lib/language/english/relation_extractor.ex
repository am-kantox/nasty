defmodule Nasty.Language.English.RelationExtractor do
  @moduledoc """
  Extracts semantic relations between entities in a document.

  Uses dependency paths, verb patterns, and heuristics to identify
  relationships like employment, organization structure, location, etc.

  ## Examples

      iex> {:ok, relations} = RelationExtractor.extract(document)
      {:ok, [
        %Relation{type: :works_at, subject: %Entity{text: "John"}, object: %Entity{text: "Google"}},
        ...
      ]}
  """

  alias Nasty.AST.{Document, Relation, Sentence}
  alias Nasty.Language.English.{DependencyExtractor, EntityRecognizer}

  # Verb patterns for different relation types
  @employment_verbs ~w(work works worked join joins joined employ employs employed hire hires hired)
  @founding_verbs ~w(found founded establish established create created start started launch launched)
  @acquisition_verbs ~w(acquire acquired buy bought purchase purchased takeover)
  @location_verbs ~w(locate located base based headquarter headquartered)
  @membership_verbs ~w(member join lead head chair)

  @doc """
  Extracts relations from a document.

  ## Options

  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:max_relations` - Maximum relations to return (default: unlimited)
  - `:relation_types` - List of relation types to extract (default: all)

  ## Examples

      iex> RelationExtractor.extract(document, min_confidence: 0.7)
      {:ok, [%Relation{confidence: 0.9}, ...]}
  """
  @spec extract(Document.t(), keyword()) :: {:ok, [Relation.t()]}
  def extract(%Document{} = document, opts \\ []) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)
    max_relations = Keyword.get(opts, :max_relations, :infinity)

    # Get all sentences
    sentences = Document.all_sentences(document)

    # Extract entities from each sentence
    relations =
      sentences
      |> Enum.flat_map(fn sentence ->
        extract_from_sentence(sentence, document.language)
      end)
      |> Relation.filter_by_confidence(min_confidence)
      |> Relation.sort_by_confidence()
      |> maybe_limit(max_relations)

    {:ok, relations}
  end

  # Extract relations from a single sentence
  defp extract_from_sentence(sentence, language) do
    # Get all tokens from the sentence
    tokens = get_sentence_tokens(sentence)

    # Recognize entities
    entities = EntityRecognizer.recognize(tokens)

    # Extract dependencies
    dependencies = DependencyExtractor.extract(sentence)

    # Generate entity pairs
    entity_pairs = generate_entity_pairs(entities)

    # Extract relations for each pair
    entity_pairs
    |> Enum.flat_map(fn {e1, e2} ->
      case extract_relation_for_pair(e1, e2, sentence, tokens, dependencies, language) do
        nil -> []
        relation -> [relation]
      end
    end)
  end

  # Generate all pairs of entities
  defp generate_entity_pairs(entities) do
    for e1 <- entities, e2 <- entities, e1 != e2, do: {e1, e2}
  end

  # Extract relation between an entity pair
  defp extract_relation_for_pair(entity1, entity2, sentence, tokens, _dependencies, language) do
    # Get indices of entities in token list
    idx1 = find_entity_index(entity1, tokens)
    idx2 = find_entity_index(entity2, tokens)

    if idx1 && idx2 && idx1 < idx2 do
      # Get tokens between entities
      between_tokens = Enum.slice(tokens, (idx1 + 1)..(idx2 - 1)//1)

      # Try to match relation patterns
      match_relation_pattern(entity1, entity2, between_tokens, sentence, language)
    else
      nil
    end
  end

  # Match relation patterns based on tokens between entities
  # credo:disable-for-lines:62
  defp match_relation_pattern(entity1, entity2, between_tokens, sentence, language) do
    # Extract lemmas from between tokens
    lemmas =
      between_tokens
      |> Enum.map(fn token -> token.lemma || String.downcase(token.text) end)

    # Check for employment relations
    cond do
      entity1.type == :person && entity2.type == :org && has_employment_verb?(lemmas) ->
        Relation.new(:works_at, entity1, entity2, language,
          confidence: 0.8,
          evidence: sentence_text(sentence)
        )

      entity1.type == :org && entity2.type == :org && has_acquisition_verb?(lemmas) ->
        Relation.new(:acquired_by, entity2, entity1, language,
          confidence: 0.75,
          evidence: sentence_text(sentence)
        )

      entity1.type == :person && entity2.type == :org && has_founding_verb?(lemmas) ->
        Relation.new(:founded, entity2, entity1, language,
          confidence: 0.7,
          evidence: sentence_text(sentence)
        )

      entity1.type in [:org, :person] && entity2.type in [:gpe, :loc] &&
          has_location_verb?(lemmas) ->
        Relation.new(:located_in, entity1, entity2, language,
          confidence: 0.7,
          evidence: sentence_text(sentence)
        )

      entity1.type == :person && entity2.type == :org && has_membership_verb?(lemmas) ->
        Relation.new(:member_of, entity1, entity2, language,
          confidence: 0.65,
          evidence: sentence_text(sentence)
        )

      # Preposition-based relations (weaker confidence)
      has_preposition?(between_tokens, "at") && entity1.type == :person && entity2.type == :org ->
        Relation.new(:works_at, entity1, entity2, language,
          confidence: 0.6,
          evidence: sentence_text(sentence)
        )

      has_preposition?(between_tokens, "in") && entity2.type in [:gpe, :loc] ->
        Relation.new(:located_in, entity1, entity2, language,
          confidence: 0.55,
          evidence: sentence_text(sentence)
        )

      has_preposition?(between_tokens, "of") && entity1.type == :person && entity2.type == :org ->
        Relation.new(:member_of, entity1, entity2, language,
          confidence: 0.5,
          evidence: sentence_text(sentence)
        )

      true ->
        nil
    end
  end

  # Check if lemmas contain employment verbs
  defp has_employment_verb?(lemmas) do
    Enum.any?(lemmas, &(&1 in @employment_verbs))
  end

  defp has_founding_verb?(lemmas) do
    Enum.any?(lemmas, &(&1 in @founding_verbs))
  end

  defp has_acquisition_verb?(lemmas) do
    Enum.any?(lemmas, &(&1 in @acquisition_verbs))
  end

  defp has_location_verb?(lemmas) do
    Enum.any?(lemmas, &(&1 in @location_verbs))
  end

  defp has_membership_verb?(lemmas) do
    Enum.any?(lemmas, &(&1 in @membership_verbs))
  end

  # Check for specific preposition
  defp has_preposition?(tokens, prep) do
    Enum.any?(tokens, fn token ->
      token.pos_tag == :adp && String.downcase(token.text) == prep
    end)
  end

  # Find entity's starting position in token list
  defp find_entity_index(entity, tokens) do
    entity_text = String.downcase(entity.text)

    Enum.find_index(tokens, fn token ->
      String.downcase(token.text) == entity_text ||
        String.contains?(entity_text, String.downcase(token.text))
    end)
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
  defp maybe_limit(relations, :infinity), do: relations
  defp maybe_limit(relations, max), do: Enum.take(relations, max)
end
