defmodule Nasty.Semantic.Coreference.Neural.E2EResolver do
  @moduledoc """
  End-to-end coreference resolver using span-based models.

  Performs joint mention detection and coreference resolution without
  requiring a separate mention detection stage.

  ## Workflow

  1. Encode document with BiLSTM
  2. Enumerate and score candidate spans
  3. Prune to top-K spans (mentions)
  4. Score pairwise coreference between spans
  5. Build coreference chains using clustering

  ## Example

      # Load trained models
      {:ok, models, params, vocab} = E2ETrainer.load_models("priv/models/en/e2e_coref")

      # Resolve coreferences
      {:ok, document} = E2EResolver.resolve(document, models, params, vocab)

      # Access chains
      chains = document.coref_chains
  """

  require Logger

  alias Nasty.AST.{Document, Sentence}
  alias Nasty.AST.Semantic.{CorefChain, Mention}
  alias Nasty.Semantic.Coreference.Neural.{E2ETrainer, SpanEnumeration, SpanModel}

  @type models :: E2ETrainer.models()
  @type params :: E2ETrainer.params()

  @doc """
  Resolve coreferences using end-to-end span model.

  ## Parameters

    - `document` - Document to resolve
    - `models` - Trained e2e models
    - `params` - Model parameters
    - `vocab` - Vocabulary map
    - `opts` - Resolution options

  ## Options

    - `:max_span_length` - Maximum span length (default: 10)
    - `:top_k_spans` - Top K spans to keep (default: 50)
    - `:min_span_score` - Minimum span score threshold (default: 0.5)
    - `:min_coref_score` - Minimum coreference score threshold (default: 0.5)

  ## Returns

    - `{:ok, document}` - Document with coreference chains
    - `{:error, reason}` - Resolution error
  """
  @spec resolve(Document.t(), models(), params(), map(), keyword()) ::
          {:ok, Document.t()} | {:error, term()}
  def resolve(%Document{} = document, models, params, vocab, opts \\ []) do
    max_span_length = Keyword.get(opts, :max_span_length, 10)
    top_k = Keyword.get(opts, :top_k_spans, 50)
    min_span_score = Keyword.get(opts, :min_span_score, 0.5)
    min_coref_score = Keyword.get(opts, :min_coref_score, 0.5)

    try do
      # Step 1: Extract tokens from document
      tokens = extract_document_tokens(document)

      if Enum.empty?(tokens) do
        {:ok, %{document | coref_chains: []}}
      else
        # Step 2: Convert tokens to IDs
        token_ids = tokens_to_ids(tokens, vocab)

        # Step 3: Encode with BiLSTM
        Logger.debug("Encoding document with BiLSTM...")
        lstm_outputs = encode_document(models.encoder, params.encoder, token_ids)

        # Step 4: Enumerate and score spans
        Logger.debug("Enumerating candidate spans...")

        {:ok, candidate_spans} =
          SpanEnumeration.enumerate_and_prune(
            lstm_outputs,
            max_length: max_span_length,
            top_k: top_k,
            scorer_model: models.span_scorer,
            scorer_params: params.span_scorer
          )

        # Step 5: Filter by span score threshold
        valid_spans = Enum.filter(candidate_spans, fn span -> span.score >= min_span_score end)

        Logger.debug("Found #{length(valid_spans)} valid spans")

        if Enum.empty?(valid_spans) do
          {:ok, %{document | coref_chains: []}}
        else
          # Step 6: Score pairwise coreference
          Logger.debug("Scoring coreference pairs...")
          coref_scores = score_coreference_pairs(models, params, valid_spans, tokens)

          # Step 7: Build chains using clustering
          Logger.debug("Building coreference chains...")
          chains = build_chains(valid_spans, coref_scores, tokens, min_coref_score)

          # Step 8: Attach chains to document
          resolved_document = %{document | coref_chains: chains}

          {:ok, resolved_document}
        end
      end
    rescue
      error ->
        Logger.error("E2E resolution failed: #{inspect(error)}")
        {:error, {:e2e_resolution_failed, error}}
    end
  end

  @doc """
  Resolve with automatic model loading.

  Convenience function that loads models from disk if path is provided.

  ## Parameters

    - `document` - Document to resolve
    - `model_path` - Path to saved models
    - `opts` - Resolution options

  ## Returns

    - `{:ok, document}` - Document with coreference chains
    - `{:error, reason}` - Resolution error
  """
  @spec resolve_auto(Document.t(), Path.t(), keyword()) ::
          {:ok, Document.t()} | {:error, term()}
  def resolve_auto(document, model_path, opts \\ []) do
    case E2ETrainer.load_models(model_path) do
      {:ok, models, params, vocab} ->
        resolve(document, models, params, vocab, opts)

      {:error, reason} ->
        {:error, {:model_load_failed, reason}}
    end
  end

  ## Private Functions

  # Extract all tokens from document
  defp extract_document_tokens(document) do
    document.paragraphs
    |> Enum.flat_map(fn para -> para.sentences end)
    |> Enum.flat_map(fn sent ->
      sent
      |> Sentence.all_clauses()
      |> Enum.flat_map(&extract_clause_tokens/1)
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

  # Convert tokens to IDs using vocabulary
  defp tokens_to_ids(tokens, vocab) do
    ids =
      Enum.map(tokens, fn token ->
        Map.get(vocab, String.downcase(token.text), 0)
      end)

    Nx.tensor([ids])
  end

  # Encode document with BiLSTM
  defp encode_document(encoder_model, encoder_params, token_ids) do
    Axon.predict(encoder_model, encoder_params, %{"token_ids" => token_ids})
    |> Nx.squeeze(axes: [0])
  end

  # Score all span pairs for coreference
  defp score_coreference_pairs(models, params, spans, tokens) do
    # For each span, score with all previous spans
    pairs =
      for {span2, idx2} <- Enum.with_index(spans),
          {span1, idx1} <- Enum.with_index(spans),
          idx1 < idx2,
          # Limit distance for efficiency
          span2.start_idx - span1.end_idx <= 100 do
        # Extract features
        features = SpanModel.extract_pair_features(span1, span2, tokens)

        # Create pair representation
        pair_repr = Nx.concatenate([span1.representation, span2.representation, features])

        {{idx1, idx2}, pair_repr}
      end

    if Enum.empty?(pairs) do
      %{}
    else
      # Batch score all pairs
      pair_reprs = Enum.map(pairs, fn {_key, repr} -> repr end) |> Nx.stack()

      scores =
        Axon.predict(models.pair_scorer, params.pair_scorer, %{"pair_repr" => pair_reprs})
        |> Nx.squeeze(axes: [1])
        |> Nx.to_flat_list()

      # Map indices to scores
      pairs
      |> Enum.zip(scores)
      |> Enum.map(fn {{key, _repr}, score} -> {key, score} end)
      |> Map.new()
    end
  end

  # Build coreference chains from scored pairs using clustering
  defp build_chains(spans, coref_scores, tokens, min_score) do
    # Greedy left-to-right clustering
    # For each span, find best antecedent with score > threshold
    initial_clusters = Enum.map(spans, fn span -> [span] end)

    final_clusters =
      spans
      |> Enum.with_index()
      |> Enum.reduce(initial_clusters, fn {_span, idx}, clusters ->
        # Find best antecedent
        best_antecedent =
          0..(idx - 1)
          |> Enum.map(fn ant_idx ->
            score = Map.get(coref_scores, {ant_idx, idx}, 0.0)
            {ant_idx, score}
          end)
          |> Enum.filter(fn {_idx, score} -> score >= min_score end)
          |> Enum.max_by(fn {_idx, score} -> score end, fn -> nil end)

        case best_antecedent do
          {ant_idx, _score} ->
            # Merge with antecedent's cluster
            merge_clusters(clusters, ant_idx, idx)

          nil ->
            # Keep as singleton
            clusters
        end
      end)

    # Convert clusters to coreference chains
    final_clusters
    |> Enum.with_index(1)
    |> Enum.map(fn {cluster, id} ->
      # Convert spans to mentions
      mentions =
        Enum.map(cluster, fn span ->
          span_tokens = Enum.slice(tokens, span.start_idx..span.end_idx)
          text = Enum.map_join(span_tokens, " ", & &1.text)

          Mention.new(
            text,
            :noun_phrase,
            0,
            span.start_idx,
            nil,
            tokens: span_tokens
          )
        end)

      if length(mentions) >= 2 do
        representative = List.first(mentions).text
        CorefChain.new(id, mentions, representative)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Merge clusters by moving span from one to another
  defp merge_clusters(clusters, from_idx, to_idx) do
    to_span = Enum.at(clusters, to_idx) |> List.first()
    from_cluster = Enum.at(clusters, from_idx)

    # Add to_span to from_cluster
    merged_cluster = [to_span | from_cluster]

    # Update clusters
    clusters
    |> List.update_at(from_idx, fn _ -> merged_cluster end)
    |> List.update_at(to_idx, fn _ -> [] end)
  end
end
