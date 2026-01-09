defmodule Nasty.Semantic.Coreference.Neural.SpanEnumeration do
  @moduledoc """
  Span enumeration and pruning for end-to-end coreference resolution.

  Generates all possible spans up to a maximum length, scores them,
  and prunes to the top-K candidates. This is the first stage of the
  span-based end-to-end model.

  ## Workflow

  1. Enumerate all spans up to max_length
  2. Compute span representations from LSTM states
  3. Score spans using feedforward network
  4. Keep only top-K highest scoring spans

  ## Example

      # Encode document with BiLSTM
      lstm_outputs = encode_document(doc)

      # Enumerate and score spans
      {:ok, spans} = SpanEnumeration.enumerate_and_prune(
        lstm_outputs,
        max_length: 10,
        top_k: 50
      )
  """

  import Nx.Defn

  @type span :: %{
          start_idx: non_neg_integer(),
          end_idx: non_neg_integer(),
          score: float(),
          representation: Nx.Tensor.t()
        }

  @doc """
  Enumerate all possible spans and prune to top-K.

  ## Parameters

    - `lstm_outputs` - LSTM hidden states [seq_len, hidden_dim]
    - `opts` - Options

  ## Options

    - `:max_length` - Maximum span length in tokens (default: 10)
    - `:top_k` - Number of spans to keep per sentence (default: 50)
    - `:scorer_model` - Trained span scorer model (optional)
    - `:scorer_params` - Scorer parameters (optional)

  ## Returns

    - `{:ok, spans}` - List of top-K scored spans
  """
  @spec enumerate_and_prune(Nx.Tensor.t(), keyword()) :: {:ok, [span()]}
  def enumerate_and_prune(lstm_outputs, opts \\ []) do
    max_length = Keyword.get(opts, :max_length, 10)
    top_k = Keyword.get(opts, :top_k, 50)
    scorer_model = Keyword.get(opts, :scorer_model)
    scorer_params = Keyword.get(opts, :scorer_params)

    # Enumerate all spans
    all_spans = enumerate_spans(lstm_outputs, max_length)

    # Score spans
    scored_spans =
      if scorer_model && scorer_params do
        score_spans_with_model(all_spans, lstm_outputs, scorer_model, scorer_params)
      else
        # Use simple heuristic scorer
        score_spans_heuristic(all_spans, lstm_outputs)
      end

    # Prune to top-K
    pruned = prune_spans(scored_spans, top_k)

    {:ok, pruned}
  end

  @doc """
  Enumerate all spans up to max_length.

  Returns list of span indices: [{start, end}, ...]
  """
  @spec enumerate_spans(Nx.Tensor.t(), pos_integer()) :: [{non_neg_integer(), non_neg_integer()}]
  def enumerate_spans(lstm_outputs, max_length) do
    seq_len = Nx.axis_size(lstm_outputs, 0)

    for start <- 0..(seq_len - 1),
        length <- 1..min(max_length, seq_len - start) do
      {start, start + length - 1}
    end
  end

  @doc """
  Compute span representation from LSTM states.

  Representation is concatenation of:
  - Start state
  - End state
  - Attention-weighted average over span
  - Span width embedding

  ## Parameters

    - `lstm_outputs` - LSTM hidden states [seq_len, hidden_dim]
    - `start_idx` - Start index
    - `end_idx` - End index (inclusive)
    - `width_embeddings` - Optional width embedding tensor [max_width, width_dim]

  ## Returns

    - Span representation tensor [span_dim]
  """
  @spec span_representation(
          Nx.Tensor.t(),
          non_neg_integer(),
          non_neg_integer(),
          Nx.Tensor.t() | nil
        ) ::
          Nx.Tensor.t()
  def span_representation(lstm_outputs, start_idx, end_idx, width_embeddings \\ nil) do
    # Extract states
    start_state =
      Nx.slice_along_axis(lstm_outputs, start_idx, 1, axis: 0) |> Nx.squeeze(axes: [0])

    end_state = Nx.slice_along_axis(lstm_outputs, end_idx, 1, axis: 0) |> Nx.squeeze(axes: [0])

    # Compute attention over span
    span_length = end_idx - start_idx + 1
    span_states = Nx.slice_along_axis(lstm_outputs, start_idx, span_length, axis: 0)
    attended = attention_over_span(span_states)

    # Width embedding
    width = end_idx - start_idx

    width_emb =
      if width_embeddings do
        Nx.slice_along_axis(width_embeddings, width, 1, axis: 0) |> Nx.squeeze(axes: [0])
      else
        # Simple learned embedding (would be learned in full model)
        Nx.broadcast(Nx.tensor(0.0), {20})
      end

    # Concatenate components
    Nx.concatenate([start_state, end_state, attended, width_emb])
  end

  @doc """
  Build Axon model for span scoring.

  ## Parameters

    - `opts` - Model options

  ## Options

    - `:hidden_dim` - LSTM hidden dimension (default: 256)
    - `:width_emb_dim` - Width embedding dimension (default: 20)
    - `:scorer_hidden` - Scorer hidden layers (default: [256, 128])
    - `:dropout` - Dropout rate (default: 0.3)

  ## Returns

    - Axon model
  """
  def build_span_scorer(opts \\ []) do
    hidden_dim = Keyword.get(opts, :hidden_dim, 256)
    width_emb_dim = Keyword.get(opts, :width_emb_dim, 20)
    scorer_hidden = Keyword.get(opts, :scorer_hidden, [256, 128])
    dropout = Keyword.get(opts, :dropout, 0.3)

    # Input: [start, end, attended, width] concatenated
    span_dim = hidden_dim * 3 + width_emb_dim

    input = Axon.input("span", shape: {nil, span_dim})

    # Feedforward scorer
    hidden =
      Enum.reduce(scorer_hidden, input, fn hidden_size, layer ->
        layer
        |> Axon.dense(hidden_size, activation: :relu)
        |> Axon.dropout(rate: dropout)
      end)

    # Output: span validity score
    Axon.dense(hidden, 1, activation: :sigmoid)
  end

  ## Private Functions

  # Attention over span tokens
  defnp attention_over_span(span_states) do
    # Simple average attention for now
    # Full model would use learned attention weights
    Nx.mean(span_states, axes: [0])
  end

  # Score spans using trained model
  defp score_spans_with_model(spans, lstm_outputs, model, params) do
    Enum.map(spans, fn {start_idx, end_idx} ->
      # Compute representation
      repr = span_representation(lstm_outputs, start_idx, end_idx)

      # Score
      score =
        Axon.predict(model, params, %{"span" => Nx.new_axis(repr, 0)})
        |> Nx.squeeze()
        |> Nx.to_number()

      %{
        start_idx: start_idx,
        end_idx: end_idx,
        score: score,
        representation: repr
      }
    end)
  end

  # Simple heuristic scoring (for testing without trained model)
  defp score_spans_heuristic(spans, lstm_outputs) do
    Enum.map(spans, fn {start_idx, end_idx} ->
      # Heuristic: prefer shorter spans, penalize very short/long
      length = end_idx - start_idx + 1
      score = heuristic_score(length)

      repr = span_representation(lstm_outputs, start_idx, end_idx)

      %{
        start_idx: start_idx,
        end_idx: end_idx,
        score: score,
        representation: repr
      }
    end)
  end

  # Heuristic score based on span length
  defp heuristic_score(length) when length == 1, do: 0.6
  defp heuristic_score(length) when length == 2, do: 0.8
  defp heuristic_score(length) when length == 3, do: 0.9
  defp heuristic_score(length) when length in 4..6, do: 0.7
  defp heuristic_score(length) when length in 7..10, do: 0.5
  defp heuristic_score(_length), do: 0.3

  # Prune to top-K spans by score
  defp prune_spans(scored_spans, top_k) do
    scored_spans
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(top_k)
  end
end
