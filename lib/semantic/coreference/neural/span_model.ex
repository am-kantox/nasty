defmodule Nasty.Semantic.Coreference.Neural.SpanModel do
  @moduledoc """
  End-to-end span-based model for coreference resolution.

  This model jointly learns mention detection and coreference resolution
  in a single end-to-end architecture. It consists of:

  1. Shared BiLSTM encoder
  2. Span scorer head (mention detection)
  3. Pairwise scorer head (coreference resolution)

  The model is trained with a joint loss function that combines both tasks.

  ## Architecture

      Text → Token Embeddings → BiLSTM → Span Representations
                                           ↓                  ↓
                                    Span Scorer         Pair Scorer
                                    (mention?)          (coref?)

  ## Example

      # Build model
      model = SpanModel.build_model(
        vocab_size: 10000,
        embed_dim: 100,
        hidden_dim: 256
      )

      # Initialize parameters
      params = SpanModel.init_params(model, template_input)

      # Forward pass
      {span_scores, coref_scores} = SpanModel.forward(
        model,
        params,
        token_ids,
        spans
      )
  """

  import Nx.Defn
  alias Nasty.Semantic.Coreference.Neural.SpanEnumeration

  @doc """
  Build the full end-to-end span model.

  ## Parameters

    - `opts` - Model options

  ## Options

    - `:vocab_size` - Vocabulary size (required)
    - `:embed_dim` - Token embedding dimension (default: 100)
    - `:hidden_dim` - LSTM hidden dimension (default: 256)
    - `:width_emb_dim` - Span width embedding dimension (default: 20)
    - `:max_span_width` - Maximum span width (default: 10)
    - `:span_scorer_hidden` - Span scorer hidden layers (default: [256, 128])
    - `:pair_scorer_hidden` - Pair scorer hidden layers (default: [512, 256])
    - `:dropout` - Dropout rate (default: 0.3)

  ## Returns

    - Map with `:encoder`, `:span_scorer`, and `:pair_scorer` models
  """
  def build_model(opts) do
    vocab_size = Keyword.fetch!(opts, :vocab_size)
    embed_dim = Keyword.get(opts, :embed_dim, 100)
    hidden_dim = Keyword.get(opts, :hidden_dim, 256)
    width_emb_dim = Keyword.get(opts, :width_emb_dim, 20)
    max_span_width = Keyword.get(opts, :max_span_width, 10)
    span_scorer_hidden = Keyword.get(opts, :span_scorer_hidden, [256, 128])
    pair_scorer_hidden = Keyword.get(opts, :pair_scorer_hidden, [512, 256])
    dropout = Keyword.get(opts, :dropout, 0.3)

    # 1. Build shared encoder
    encoder = build_encoder(vocab_size, embed_dim, hidden_dim, dropout)

    # 2. Build span scorer
    span_dim = hidden_dim * 3 + width_emb_dim
    span_scorer = build_span_scorer(span_dim, span_scorer_hidden, dropout)

    # 3. Build pairwise scorer
    # Two spans + features
    pair_input_dim = span_dim * 2 + 20
    pair_scorer = build_pair_scorer(pair_input_dim, pair_scorer_hidden, dropout)

    # 4. Build width embeddings
    width_embeddings = build_width_embeddings(max_span_width, width_emb_dim)

    %{
      encoder: encoder,
      span_scorer: span_scorer,
      pair_scorer: pair_scorer,
      width_embeddings: width_embeddings,
      config: %{
        hidden_dim: hidden_dim,
        width_emb_dim: width_emb_dim,
        max_span_width: max_span_width
      }
    }
  end

  @doc """
  Build the shared BiLSTM encoder.

  ## Parameters

    - `vocab_size` - Vocabulary size
    - `embed_dim` - Embedding dimension
    - `hidden_dim` - LSTM hidden dimension
    - `dropout` - Dropout rate

  ## Returns

    - Axon model
  """
  def build_encoder(vocab_size, embed_dim, hidden_dim, dropout) do
    input = Axon.input("token_ids", shape: {nil, nil})

    # Token embeddings
    embedded = Axon.embedding(input, vocab_size, embed_dim)

    # BiLSTM - forward pass
    {forward_output, _forward_state} = Axon.lstm(embedded, hidden_dim, name: "lstm_forward")

    # BiLSTM - backward pass
    reversed = Axon.nx(embedded, &Nx.reverse(&1, axes: [1]))
    {backward_output, _backward_state} = Axon.lstm(reversed, hidden_dim, name: "lstm_backward")
    backward_output = Axon.nx(backward_output, &Nx.reverse(&1, axes: [1]))

    # Concatenate forward and backward
    bilstm = Axon.concatenate(forward_output, backward_output, axis: -1)

    # Dropout
    Axon.dropout(bilstm, rate: dropout)
  end

  @doc """
  Build span scorer head.

  Scores whether a span is a valid mention.

  ## Parameters

    - `span_dim` - Span representation dimension
    - `hidden_layers` - Hidden layer sizes
    - `dropout` - Dropout rate

  ## Returns

    - Axon model
  """
  def build_span_scorer(span_dim, hidden_layers, dropout) do
    input = Axon.input("span_repr", shape: {nil, span_dim})

    # Feedforward layers
    hidden =
      Enum.reduce(hidden_layers, input, fn size, layer ->
        layer
        |> Axon.dense(size, activation: :relu)
        |> Axon.dropout(rate: dropout)
      end)

    # Output: binary classification
    Axon.dense(hidden, 1, activation: :sigmoid, name: "span_score")
  end

  @doc """
  Build pairwise scorer head.

  Scores whether two spans are coreferent.

  ## Parameters

    - `pair_dim` - Pair representation dimension
    - `hidden_layers` - Hidden layer sizes
    - `dropout` - Dropout rate

  ## Returns

    - Axon model
  """
  def build_pair_scorer(pair_dim, hidden_layers, dropout) do
    input = Axon.input("pair_repr", shape: {nil, pair_dim})

    # Feedforward layers
    hidden =
      Enum.reduce(hidden_layers, input, fn size, layer ->
        layer
        |> Axon.dense(size, activation: :relu)
        |> Axon.dropout(rate: dropout)
      end)

    # Output: binary classification
    Axon.dense(hidden, 1, activation: :sigmoid, name: "coref_score")
  end

  @doc """
  Build learned width embeddings.

  ## Parameters

    - `max_width` - Maximum span width
    - `embed_dim` - Embedding dimension

  ## Returns

    - Axon model
  """
  def build_width_embeddings(max_width, embed_dim) do
    input = Axon.input("width", shape: {nil})
    Axon.embedding(input, max_width + 1, embed_dim, name: "width_embeddings")
  end

  @doc """
  Extract pairwise features between two spans.

  Features include:
  - Distance (sentence, token)
  - String match (exact, partial, head match)
  - Span properties (lengths, positions)

  ## Parameters

    - `span1` - First span
    - `span2` - Second span
    - `tokens` - Document tokens (optional, for string matching)

  ## Returns

    - Feature tensor [20]
  """
  def extract_pair_features(span1, span2, tokens \\ nil) do
    # Distance features
    token_distance = span2.start_idx - span1.end_idx
    normalized_distance = min(token_distance / 50.0, 1.0)

    # Span length features
    len1 = span1.end_idx - span1.start_idx + 1
    len2 = span2.end_idx - span2.start_idx + 1
    same_length = if len1 == len2, do: 1.0, else: 0.0

    # String match features (if tokens provided)
    {exact_match, partial_match, head_match} =
      if tokens do
        compute_string_features(span1, span2, tokens)
      else
        {0.0, 0.0, 0.0}
      end

    # Construct feature vector
    Nx.tensor([
      # Distance (2)
      normalized_distance,
      if(token_distance < 5, do: 1.0, else: 0.0),
      # Length (3)
      len1 / 10.0,
      len2 / 10.0,
      same_length,
      # String match (3)
      exact_match,
      partial_match,
      head_match,
      # Position (4)
      span1.start_idx / 100.0,
      span2.start_idx / 100.0,
      if(span1.start_idx == 0, do: 1.0, else: 0.0),
      if(span2.start_idx == 0, do: 1.0, else: 0.0),
      # Padding to 20
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ])
  end

  @doc """
  Forward pass through the full model.

  ## Parameters

    - `models` - Model map (encoder, scorers)
    - `params` - Parameters map
    - `token_ids` - Token ID tensor [batch, seq_len]
    - `spans` - List of span structs

  ## Returns

    - `{span_scores, coref_scores}` tuple
  """
  def forward(models, params, token_ids, spans) do
    # 1. Encode with BiLSTM
    lstm_outputs = Axon.predict(models.encoder, params.encoder, %{"token_ids" => token_ids})

    # 2. Compute span representations
    span_reprs =
      Enum.map(spans, fn span ->
        SpanEnumeration.span_representation(
          lstm_outputs,
          span.start_idx,
          span.end_idx
        )
      end)
      |> Nx.stack()

    # 3. Score spans
    span_scores =
      Axon.predict(models.span_scorer, params.span_scorer, %{"span_repr" => span_reprs})

    # 4. Score pairs (only for valid spans)
    # For efficiency, score only a subset of pairs
    coref_scores = score_span_pairs(models, params, spans, span_reprs)

    {span_scores, coref_scores}
  end

  @doc """
  Compute joint loss.

  ## Parameters

    - `span_scores` - Predicted span scores
    - `coref_scores` - Predicted coreference scores
    - `gold_span_labels` - Gold span labels (1 = mention, 0 = non-mention)
    - `gold_coref_labels` - Gold coreference labels
    - `opts` - Loss options

  ## Options

    - `:span_loss_weight` - Weight for span loss (default: 0.3)
    - `:coref_loss_weight` - Weight for coref loss (default: 0.7)

  ## Returns

    - Total loss scalar
  """
  def compute_loss(span_scores, coref_scores, gold_span_labels, gold_coref_labels, opts \\ []) do
    span_weight = Keyword.get(opts, :span_loss_weight, 0.3)
    coref_weight = Keyword.get(opts, :coref_loss_weight, 0.7)

    # Binary cross-entropy for span detection
    span_loss = binary_cross_entropy(span_scores, gold_span_labels)

    # Binary cross-entropy for coreference
    coref_loss = binary_cross_entropy(coref_scores, gold_coref_labels)

    # Weighted sum
    Nx.add(
      Nx.multiply(span_weight, span_loss),
      Nx.multiply(coref_weight, coref_loss)
    )
  end

  ## Private Functions

  # Binary cross-entropy loss
  defnp binary_cross_entropy(predictions, labels) do
    # Clamp predictions for numerical stability
    preds = Nx.clip(predictions, 1.0e-7, 1.0 - 1.0e-7)

    # BCE formula: -[y*log(p) + (1-y)*log(1-p)]
    pos_loss = Nx.multiply(labels, Nx.log(preds))
    neg_loss = Nx.multiply(Nx.subtract(1.0, labels), Nx.log(Nx.subtract(1.0, preds)))

    Nx.mean(Nx.negate(Nx.add(pos_loss, neg_loss)))
  end

  # Score all span pairs
  defp score_span_pairs(models, params, spans, span_reprs) do
    # For each span, score with all previous spans (antecedents)
    pairs =
      for {span2, idx2} <- Enum.with_index(spans),
          {span1, idx1} <- Enum.with_index(spans),
          idx1 < idx2,
          # Limit distance for efficiency
          span2.start_idx - span1.end_idx <= 100 do
        repr1 = Nx.slice_along_axis(span_reprs, idx1, 1, axis: 0) |> Nx.squeeze(axes: [0])
        repr2 = Nx.slice_along_axis(span_reprs, idx2, 1, axis: 0) |> Nx.squeeze(axes: [0])

        features = extract_pair_features(span1, span2)

        pair_repr = Nx.concatenate([repr1, repr2, features])
        {idx1, idx2, pair_repr}
      end

    if Enum.empty?(pairs) do
      # No pairs to score
      Nx.tensor([])
    else
      # Stack pair representations
      pair_reprs = Enum.map(pairs, fn {_, _, repr} -> repr end) |> Nx.stack()

      # Score
      Axon.predict(models.pair_scorer, params.pair_scorer, %{"pair_repr" => pair_reprs})
    end
  end

  # Compute string matching features
  defp compute_string_features(span1, span2, tokens) do
    text1 = extract_span_text(span1, tokens)
    text2 = extract_span_text(span2, tokens)

    exact = if text1 == text2, do: 1.0, else: 0.0

    # Partial match: any word overlap
    words1 = String.split(text1)
    words2 = String.split(text2)
    overlap = MapSet.intersection(MapSet.new(words1), MapSet.new(words2))
    partial = if MapSet.size(overlap) > 0, do: 1.0, else: 0.0

    # Head match: first word matches
    head = if List.first(words1) == List.first(words2), do: 1.0, else: 0.0

    {exact, partial, head}
  end

  # Extract text for span
  defp extract_span_text(span, tokens) do
    tokens
    |> Enum.slice(span.start_idx..span.end_idx)
    |> Enum.map_join(" ", & &1.text)
  end
end
