defmodule Nasty.Language.English.CoreferenceResolver do
  @moduledoc """
  Coreference Resolution for English.

  Links referring expressions (pronouns, definite NPs, proper names) across
  sentences to build coreference chains representing entities.

  Uses rule-based heuristics with agreement constraints (gender, number)
  and salience-based scoring (recency, syntactic position).

  ## Examples

      iex> document = parse_document("John works at Google. He is an engineer.")
      iex> {:ok, chains} = CoreferenceResolver.resolve(document)
      iex> chain = List.first(chains)
      iex> chain.representative
      "John"
      iex> length(chain.mentions)
      2
  """

  alias Nasty.AST.{
    Clause,
    CorefChain,
    Document,
    Entity,
    Mention,
    NounPhrase,
    Sentence,
    Token
  }

  alias Nasty.Language.English.EntityRecognizer

  # Pronoun categories
  @male_pronouns ["he", "him", "his", "himself"]
  @female_pronouns ["she", "her", "hers", "herself"]
  @neutral_pronouns ["it", "its", "itself"]
  @plural_pronouns ["they", "them", "their", "theirs", "themselves"]

  @doc """
  Resolves coreferences in a document.

  Returns a list of coreference chains linking mentions of the same entity.

  ## Options

  - `:max_sentence_distance` - Maximum sentence distance for coreference (default: 3)
  - `:min_score` - Minimum score threshold for coreference (default: 0.3)
  """
  @spec resolve(Document.t(), keyword()) :: {:ok, [CorefChain.t()]} | {:error, term()}
  def resolve(%Document{} = document, opts \\ []) do
    max_distance = Keyword.get(opts, :max_sentence_distance, 3)
    min_score = Keyword.get(opts, :min_score, 0.3)

    # Extract mentions from document
    mentions = extract_mentions(document)

    # Build coreference chains
    chains = build_chains(mentions, max_distance, min_score)

    {:ok, chains}
  end

  @doc """
  Extracts all mentions from a document.

  Identifies:
  - Pronouns (he, she, it, they, etc.)
  - Proper names (from entity recognition)
  - Definite noun phrases (the company, the president)
  """
  @spec extract_mentions(Document.t()) :: [Mention.t()]
  def extract_mentions(%Document{paragraphs: paragraphs}) do
    paragraphs
    |> Enum.flat_map(fn para -> para.sentences end)
    |> Enum.with_index()
    |> Enum.flat_map(fn {sentence, sent_idx} ->
      extract_mentions_from_sentence(sentence, sent_idx)
    end)
  end

  # Extract mentions from a single sentence
  defp extract_mentions_from_sentence(sentence, sent_idx) do
    # Get all tokens from clauses
    tokens =
      sentence
      |> Sentence.all_clauses()
      |> Enum.flat_map(&extract_tokens_from_clause/1)
      |> Enum.with_index()

    # Extract pronoun mentions
    pronoun_mentions =
      tokens
      |> Enum.filter(fn {token, _idx} -> pronoun?(token) end)
      |> Enum.map(fn {token, tok_idx} ->
        create_pronoun_mention(token, sent_idx, tok_idx)
      end)

    # Extract proper name mentions (from entities)
    entity_mentions = extract_entity_mentions(sentence, sent_idx)

    # Extract definite NP mentions
    definite_np_mentions = extract_definite_np_mentions(sentence, sent_idx)

    pronoun_mentions ++ entity_mentions ++ definite_np_mentions
  end

  # Extract all tokens from a clause
  defp extract_tokens_from_clause(%Clause{subject: subject, predicate: predicate}) do
    subject_tokens = if subject, do: extract_tokens_from_np(subject), else: []
    predicate_tokens = extract_tokens_from_vp(predicate)
    subject_tokens ++ predicate_tokens
  end

  # Extract tokens from NP
  defp extract_tokens_from_np(%NounPhrase{} = np) do
    [
      if(np.determiner, do: [np.determiner], else: []),
      np.modifiers,
      [np.head]
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  # Extract tokens from VP
  defp extract_tokens_from_vp(%{auxiliaries: aux, head: head}) do
    aux ++ [head]
  end

  defp extract_tokens_from_vp(_), do: []

  # Check if token is a pronoun
  defp pronoun?(%Token{pos_tag: pos, text: text}) do
    pos == :pron or
      String.downcase(text) in (@male_pronouns ++
                                  @female_pronouns ++
                                  @neutral_pronouns ++
                                  @plural_pronouns)
  end

  # Create a pronoun mention
  defp create_pronoun_mention(token, sent_idx, tok_idx) do
    text_lower = String.downcase(token.text)
    {gender, number} = classify_pronoun(text_lower)

    Mention.new(
      token.text,
      :pronoun,
      sent_idx,
      tok_idx,
      token.span,
      tokens: [token],
      gender: gender,
      number: number
    )
  end

  # Classify pronoun gender and number
  defp classify_pronoun(text) do
    cond do
      text in @male_pronouns -> {:male, :singular}
      text in @female_pronouns -> {:female, :singular}
      text in @neutral_pronouns -> {:neutral, :singular}
      text in @plural_pronouns -> {:plural, :plural}
      true -> {:unknown, :unknown}
    end
  end

  # Extract entity mentions (proper names)
  defp extract_entity_mentions(sentence, sent_idx) do
    # Get tokens for entity recognition
    tokens =
      sentence
      |> Sentence.all_clauses()
      |> Enum.flat_map(&extract_tokens_from_clause/1)

    # Run entity recognizer
    entities = EntityRecognizer.recognize(tokens)

    # Convert entities to mentions
    entities
    |> Enum.with_index()
    |> Enum.map(fn {entity, idx} ->
      {gender, number} = infer_entity_attributes(entity)

      Mention.new(
        entity.text,
        :proper_name,
        sent_idx,
        idx,
        entity.span,
        tokens: entity.tokens,
        gender: gender,
        number: number,
        entity_type: entity.type
      )
    end)
  end

  # Infer gender/number from entity type
  defp infer_entity_attributes(%Entity{type: type, text: text}) do
    gender =
      case type do
        :person -> infer_person_gender(text)
        _ -> :neutral
      end

    number = if String.contains?(text, " and "), do: :plural, else: :singular

    {gender, number}
  end

  # Simple heuristic for person gender (very basic)
  defp infer_person_gender(text) do
    # This is a placeholder - would need a name database for accuracy
    cond do
      String.contains?(text, ["Mr.", "John", "James", "Michael"]) -> :male
      String.contains?(text, ["Ms.", "Mrs.", "Mary", "Sarah", "Jennifer"]) -> :female
      true -> :unknown
    end
  end

  # Extract definite NP mentions
  defp extract_definite_np_mentions(sentence, sent_idx) do
    sentence
    |> Sentence.all_clauses()
    |> Enum.flat_map(fn clause ->
      extract_definite_nps_from_clause(clause, sent_idx)
    end)
  end

  defp extract_definite_nps_from_clause(%Clause{subject: subject}, sent_idx) do
    if subject && definite_np?(subject) do
      tokens = extract_tokens_from_np(subject)

      [
        Mention.new(
          extract_np_text(subject),
          :definite_np,
          sent_idx,
          0,
          subject.span,
          tokens: tokens,
          phrase: subject,
          gender: :unknown,
          number: if(plural_np?(subject), do: :plural, else: :singular)
        )
      ]
    else
      []
    end
  end

  # Check if NP is definite
  defp definite_np?(%NounPhrase{determiner: det}) do
    det && String.downcase(det.text) in ["the", "this", "that", "these", "those"]
  end

  # Check if NP is plural
  defp plural_np?(%NounPhrase{head: head}) do
    head.pos_tag == :noun && String.ends_with?(head.text, "s")
  end

  # Extract text from NP
  defp extract_np_text(%NounPhrase{} = np) do
    tokens = extract_tokens_from_np(np)
    Enum.map_join(tokens, " ", & &1.text)
  end

  @doc """
  Builds coreference chains from mentions using scoring heuristics.
  """
  @spec build_chains([Mention.t()], pos_integer(), float()) :: [CorefChain.t()]
  def build_chains(mentions, max_distance, min_score) do
    # Start with each mention in its own cluster
    clusters = Enum.map(mentions, fn m -> [m] end)

    # Iteratively merge clusters based on scores
    final_clusters = merge_clusters(clusters, mentions, max_distance, min_score)

    # Convert clusters to chains
    final_clusters
    |> Enum.with_index(1)
    |> Enum.map(fn {cluster, id} ->
      representative = CorefChain.select_representative(cluster)
      entity_type = get_cluster_entity_type(cluster)

      CorefChain.new(id, cluster, representative, entity_type: entity_type)
    end)
    |> Enum.reject(fn chain -> CorefChain.mention_count(chain) < 2 end)
  end

  # Merge clusters iteratively
  defp merge_clusters(clusters, mentions, max_distance, min_score) do
    # Try to find best merge
    case find_best_merge(clusters, mentions, max_distance, min_score) do
      {:ok, {idx1, idx2}} ->
        # Merge clusters
        cluster1 = Enum.at(clusters, idx1)
        cluster2 = Enum.at(clusters, idx2)
        merged = cluster1 ++ cluster2

        # Remove old clusters and add merged
        new_clusters =
          clusters
          |> Enum.with_index()
          |> Enum.reject(fn {_c, i} -> i == idx1 or i == idx2 end)
          |> Enum.map(fn {c, _i} -> c end)
          |> then(fn cs -> [merged | cs] end)

        # Continue merging
        merge_clusters(new_clusters, mentions, max_distance, min_score)

      :none ->
        # No more merges possible
        clusters
    end
  end

  # Find best pair of clusters to merge
  defp find_best_merge(clusters, _mentions, max_distance, min_score) do
    # Score all pairs
    pairs =
      for {c1, i1} <- Enum.with_index(clusters),
          {c2, i2} <- Enum.with_index(clusters),
          i1 < i2 do
        score = score_cluster_pair(c1, c2, max_distance)
        {{i1, i2}, score}
      end

    # Find best scoring pair above threshold
    case Enum.max_by(pairs, fn {_pair, score} -> score end, fn -> nil end) do
      {pair, score} when score >= min_score -> {:ok, pair}
      _ -> :none
    end
  end

  # Score a pair of mention clusters for coreference
  defp score_cluster_pair(cluster1, cluster2, max_distance) do
    # Score all mention pairs between clusters
    scores =
      for m1 <- cluster1, m2 <- cluster2 do
        score_mention_pair(m1, m2, max_distance)
      end

    # Return average score
    if Enum.empty?(scores) do
      0.0
    else
      Enum.sum(scores) / length(scores)
    end
  end

  # Score a pair of mentions for coreference
  defp score_mention_pair(m1, m2, max_distance) do
    score = 0.0

    # Distance penalty (recency)
    distance = abs(m1.sentence_idx - m2.sentence_idx)

    score =
      if distance <= max_distance do
        score + (1.0 - distance / max_distance) * 0.4
      else
        score
      end

    # Gender agreement
    score = if Mention.gender_agrees?(m1, m2), do: score + 0.3, else: score

    # Number agreement
    score = if Mention.number_agrees?(m1, m2), do: score + 0.3, else: score

    # String match bonus
    score =
      if String.downcase(m1.text) == String.downcase(m2.text) do
        score + 0.5
      else
        score
      end

    # Partial string match
    score =
      if partial_match?(m1.text, m2.text) do
        score + 0.2
      else
        score
      end

    # Entity type match
    score =
      if m1.entity_type && m2.entity_type && m1.entity_type == m2.entity_type do
        score + 0.2
      else
        score
      end

    # Pronoun-name boost
    score =
      if (Mention.pronoun?(m1) and Mention.proper_name?(m2)) or
           (Mention.proper_name?(m1) and Mention.pronoun?(m2)) do
        score + 0.3
      else
        score
      end

    score
  end

  # Check for partial string match
  defp partial_match?(text1, text2) do
    lower1 = String.downcase(text1)
    lower2 = String.downcase(text2)

    String.contains?(lower1, lower2) or String.contains?(lower2, lower1)
  end

  # Get entity type for cluster (from first proper name mention)
  defp get_cluster_entity_type(cluster) do
    cluster
    |> Enum.find(fn m -> m.entity_type != nil end)
    |> case do
      %Mention{entity_type: type} -> type
      nil -> nil
    end
  end
end
