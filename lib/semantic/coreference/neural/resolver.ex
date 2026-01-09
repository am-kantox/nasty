defmodule Nasty.Semantic.Coreference.Neural.Resolver do
  @moduledoc """
  Neural coreference resolver integrating with existing pipeline.

  Replaces the rule-based scorer with neural models while keeping
  the existing mention detection and clustering infrastructure.

  ## Workflow

  1. Use existing mention detector to extract mentions
  2. Encode all mentions with neural encoder
  3. Score all mention pairs with neural scorer
  4. Use existing clusterer with neural scores
  5. Build coreference chains

  ## Example

      # Load trained models
      {:ok, models, params, vocab} = Trainer.load_models("priv/models/en/coref")

      # Resolve coreferences
      {:ok, document} = NeuralResolver.resolve(document, models, params, vocab)

      # Access chains
      chains = document.coref_chains
  """

  alias Nasty.AST.{Document, Sentence}
  alias Nasty.AST.Semantic.{CorefChain, Mention}
  alias Nasty.Language.English.CoreferenceConfig
  alias Nasty.Semantic.Coreference.{Clusterer, MentionDetector}
  alias Nasty.Semantic.Coreference.Neural.{MentionEncoder, PairScorer, Trainer}

  require Logger

  @type models :: Trainer.models()
  @type params :: Trainer.params()

  @doc """
  Resolve coreferences using neural models.

  ## Parameters

    - `document` - Document to resolve
    - `models` - Trained neural models
    - `params` - Model parameters
    - `vocab` - Vocabulary map
    - `opts` - Resolution options

  ## Options

    - `:min_score` - Minimum score threshold (default: 0.5)
    - `:max_distance` - Maximum sentence distance (default: 3)
    - `:merge_strategy` - Clustering strategy (default: :average)
    - `:context_window` - Context window for mentions (default: 10)

  ## Returns

    - `{:ok, document}` - Document with neural coreference chains
    - `{:error, reason}` - Resolution error
  """
  @spec resolve(Document.t(), models(), params(), map(), keyword()) ::
          {:ok, Document.t()} | {:error, term()}
  def resolve(%Document{} = document, models, params, vocab, opts \\ []) do
    min_score = Keyword.get(opts, :min_score, 0.5)
    max_distance = Keyword.get(opts, :max_distance, 3)
    context_window = Keyword.get(opts, :context_window, 10)

    # Step 1: Extract mentions using existing detector
    config = CoreferenceConfig.config()
    mentions = MentionDetector.extract_mentions(document, config)

    if Enum.empty?(mentions) do
      # No mentions found
      {:ok, %{document | coref_chains: []}}
    else
      # Step 2: Extract context for each mention
      mentions_with_context = extract_contexts(document, mentions, context_window)

      # Step 3: Encode all mentions
      Logger.debug("Encoding #{length(mentions)} mentions...")
      encodings = encode_mentions(models.encoder, params.encoder, mentions_with_context, vocab)

      # Step 4: Score all mention pairs
      Logger.debug("Scoring mention pairs...")
      scored_pairs = score_all_pairs(models.scorer, params.scorer, mentions, encodings)

      # Step 5: Build clusters using neural scores
      Logger.debug("Building coreference chains...")
      chains = build_chains_from_scores(mentions, scored_pairs, min_score, max_distance, opts)

      # Step 6: Attach chains to document
      resolved_document = %{document | coref_chains: chains}

      {:ok, resolved_document}
    end
  rescue
    error ->
      Logger.error("Neural resolution failed: #{inspect(error)}")
      {:error, {:neural_resolution_failed, error}}
  end

  @doc """
  Resolve with automatic model loading.

  Convenience function that loads models from disk if path is provided,
  or uses already-loaded models.

  ## Parameters

    - `document` - Document to resolve
    - `model_path_or_models` - Either path to models or loaded models
    - `opts` - Resolution options

  ## Returns

    - `{:ok, document}` - Document with coreference chains
    - `{:error, reason}` - Resolution error
  """
  @spec resolve_auto(Document.t(), Path.t() | {models(), params(), map()}, keyword()) ::
          {:ok, Document.t()} | {:error, term()}
  def resolve_auto(document, model_path, opts) when is_binary(model_path) do
    case Trainer.load_models(model_path) do
      {:ok, models, params, vocab} ->
        resolve(document, models, params, vocab, opts)

      {:error, reason} ->
        {:error, {:model_load_failed, reason}}
    end
  end

  def resolve_auto(document, {models, params, vocab}, opts) do
    resolve(document, models, params, vocab, opts)
  end

  ## Private Functions

  # Extract context tokens for each mention
  defp extract_contexts(document, mentions, context_window) do
    # Get all tokens from document
    all_tokens =
      document.paragraphs
      |> Enum.flat_map(fn para -> para.sentences end)
      |> Enum.flat_map(fn sent ->
        sent
        |> Sentence.all_clauses()
        |> Enum.flat_map(&extract_clause_tokens/1)
      end)

    # For each mention, extract surrounding context
    Enum.map(mentions, fn mention ->
      # Find mention position in token sequence
      mention_start = mention.sentence_idx * 100 + mention.token_idx
      context_start = max(0, mention_start - context_window)
      context_end = mention_start + length(mention.tokens) + context_window

      context_tokens = Enum.slice(all_tokens, context_start..context_end)

      {mention, context_tokens}
    end)
  end

  # Extract tokens from clause
  defp extract_clause_tokens(clause) do
    subject_tokens =
      if clause.subject do
        extract_np_tokens(clause.subject)
      else
        []
      end

    predicate_tokens = extract_vp_tokens(clause.predicate)

    subject_tokens ++ predicate_tokens
  end

  defp extract_np_tokens(np) do
    [
      if(np.determiner, do: [np.determiner], else: []),
      np.modifiers,
      [np.head]
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp extract_vp_tokens(vp) do
    vp.auxiliaries ++ [vp.head]
  end

  # Encode all mentions
  defp encode_mentions(encoder_model, encoder_params, mentions_with_context, vocab) do
    MentionEncoder.batch_encode_mentions(
      encoder_model,
      encoder_params,
      mentions_with_context,
      vocab
    )
  end

  # Score all mention pairs
  defp score_all_pairs(scorer_model, scorer_params, mentions, encodings) do
    # Create all pairs within reasonable distance
    pairs =
      for {m1, idx1} <- Enum.with_index(mentions),
          {m2, idx2} <- Enum.with_index(mentions),
          idx1 < idx2,
          abs(m1.sentence_idx - m2.sentence_idx) <= 5 do
        # Get encodings
        enc1 = Nx.slice_along_axis(encodings, idx1, 1, axis: 0) |> Nx.squeeze(axes: [0])
        enc2 = Nx.slice_along_axis(encodings, idx2, 1, axis: 0) |> Nx.squeeze(axes: [0])

        # Extract features
        features = PairScorer.extract_features(m1, m2)

        # Score pair
        score = PairScorer.score_pair(scorer_model, scorer_params, enc1, enc2, features)

        {{idx1, idx2}, score}
      end

    Map.new(pairs)
  end

  # Build coreference chains from scored pairs
  defp build_chains_from_scores(mentions, scored_pairs, min_score, _max_distance, _opts) do
    # Convert neural scores to clustering format
    # Start with each mention in its own cluster
    clusters = Enum.map(mentions, fn m -> [m] end)

    # Iteratively merge high-scoring pairs
    final_clusters = merge_by_scores(clusters, mentions, scored_pairs, min_score)

    # Convert to coreference chains
    final_clusters
    |> Enum.with_index(1)
    |> Enum.map(fn {cluster, id} ->
      representative = Clusterer.select_representative(cluster)
      entity_type = get_cluster_entity_type(cluster)
      CorefChain.new(id, cluster, representative, entity_type: entity_type)
    end)
    |> Enum.reject(fn chain -> CorefChain.mention_count(chain) < 2 end)
  end

  # Merge clusters based on neural scores
  defp merge_by_scores(clusters, mentions, scored_pairs, min_score) do
    # Find best scoring pair between clusters
    case find_best_cluster_pair(clusters, mentions, scored_pairs, min_score) do
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
        merge_by_scores(new_clusters, mentions, scored_pairs, min_score)

      :none ->
        # No more merges
        clusters
    end
  end

  # Find best scoring cluster pair
  defp find_best_cluster_pair(clusters, mentions, scored_pairs, min_score) do
    # For each cluster pair, compute average score
    cluster_scores =
      for {c1, i1} <- Enum.with_index(clusters),
          {c2, i2} <- Enum.with_index(clusters),
          i1 < i2 do
        # Get all pair scores between clusters
        pair_scores =
          for m1 <- c1, m2 <- c2 do
            m1_idx = Enum.find_index(mentions, fn m -> m == m1 end)
            m2_idx = Enum.find_index(mentions, fn m -> m == m2 end)

            if m1_idx && m2_idx do
              key = if m1_idx < m2_idx, do: {m1_idx, m2_idx}, else: {m2_idx, m1_idx}
              Map.get(scored_pairs, key, 0.0)
            else
              0.0
            end
          end

        avg_score =
          if Enum.empty?(pair_scores), do: 0.0, else: Enum.sum(pair_scores) / length(pair_scores)

        {{i1, i2}, avg_score}
      end

    # Find best
    case Enum.max_by(cluster_scores, fn {_pair, score} -> score end, fn -> nil end) do
      {pair, score} when score >= min_score -> {:ok, pair}
      _ -> :none
    end
  end

  # Get entity type from cluster
  defp get_cluster_entity_type(cluster) do
    cluster
    |> Enum.find(fn m -> m.entity_type != nil end)
    |> case do
      %Mention{entity_type: type} -> type
      nil -> nil
    end
  end
end
