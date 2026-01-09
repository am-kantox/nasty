defmodule Nasty.Semantic.Coreference.Evaluator do
  @moduledoc """
  Coreference resolution evaluation metrics.

  Implements standard coreference evaluation metrics:
  - MUC (Vilain et al., 1995) - Mention-based
  - B³ (Bagga & Baldwin, 1998) - Entity-based
  - CEAF (Luo, 2005) - Entity-based with optimal alignment
  - CoNLL F1 - Average of MUC, B³, and CEAF

  ## Example

      # Evaluate predictions
      metrics = Evaluator.evaluate(gold_chains, predicted_chains)

      # Access individual metrics
      muc_f1 = metrics.muc.f1
      b3_f1 = metrics.b3.f1
      ceaf_f1 = metrics.ceaf.f1
      conll_f1 = metrics.conll_f1

  ## References

  - MUC: Vilain et al. (1995). "A model-theoretic coreference scoring scheme"
  - B³: Bagga & Baldwin (1998). "Algorithms for scoring coreference chains"
  - CEAF: Luo (2005). "On coreference resolution performance metrics"
  - CoNLL: Pradhan et al. (2012). "CoNLL-2012 shared task"
  """

  alias Nasty.AST.Semantic.CorefChain

  @type metric :: %{precision: float(), recall: float(), f1: float()}
  @type evaluation :: %{
          muc: metric(),
          b3: metric(),
          ceaf: metric(),
          conll_f1: float()
        }

  @doc """
  Evaluate predicted coreference chains against gold standard.

  ## Parameters

    - `gold_chains` - Gold standard coreference chains
    - `predicted_chains` - Predicted coreference chains

  ## Returns

  Map with all evaluation metrics
  """
  @spec evaluate([CorefChain.t()], [CorefChain.t()]) :: evaluation()
  def evaluate(gold_chains, predicted_chains) do
    # Compute individual metrics
    muc = compute_muc(gold_chains, predicted_chains)
    b3 = compute_b3(gold_chains, predicted_chains)
    ceaf = compute_ceaf(gold_chains, predicted_chains)

    # Compute CoNLL F1 (average of three metrics)
    conll_f1 = (muc.f1 + b3.f1 + ceaf.f1) / 3.0

    %{
      muc: muc,
      b3: b3,
      ceaf: ceaf,
      conll_f1: conll_f1
    }
  end

  @doc """
  Compute MUC metric (mention-based).

  MUC measures the minimum number of links needed to connect mentions
  in the same cluster.

  ## Parameters

    - `gold_chains` - Gold standard chains
    - `predicted_chains` - Predicted chains

  ## Returns

  Map with precision, recall, and F1
  """
  @spec compute_muc([CorefChain.t()], [CorefChain.t()]) :: metric()
  def compute_muc(gold_chains, predicted_chains) do
    # Convert chains to mention sets
    gold_partitions = chains_to_partitions(gold_chains)
    pred_partitions = chains_to_partitions(predicted_chains)

    # Compute recall (using gold as key)
    recall_num =
      Enum.sum(
        Enum.map(gold_partitions, fn partition ->
          muc_partition_links(partition, pred_partitions)
        end)
      )

    recall_denom = Enum.sum(Enum.map(gold_partitions, &(length(&1) - 1)))

    # Compute precision (using predicted as key)
    precision_num =
      Enum.sum(
        Enum.map(pred_partitions, fn partition ->
          muc_partition_links(partition, gold_partitions)
        end)
      )

    precision_denom = Enum.sum(Enum.map(pred_partitions, &(length(&1) - 1)))

    # Compute metrics
    recall = safe_divide(recall_num, recall_denom)
    precision = safe_divide(precision_num, precision_denom)
    f1 = compute_f1(precision, recall)

    %{precision: precision, recall: recall, f1: f1}
  end

  @doc """
  Compute B³ metric (entity-based).

  B³ computes precision and recall for each mention individually,
  then averages across all mentions.

  ## Parameters

    - `gold_chains` - Gold standard chains
    - `predicted_chains` - Predicted chains

  ## Returns

  Map with precision, recall, and F1
  """
  @spec compute_b3([CorefChain.t()], [CorefChain.t()]) :: metric()
  def compute_b3(gold_chains, predicted_chains) do
    # Get all mentions
    all_mentions = get_all_mentions(gold_chains ++ predicted_chains)

    # Build mention to chain maps
    gold_map = build_mention_to_chain_map(gold_chains)
    pred_map = build_mention_to_chain_map(predicted_chains)

    # Compute precision and recall for each mention
    {precision_sum, recall_sum} =
      Enum.reduce(all_mentions, {0.0, 0.0}, fn mention, {p_acc, r_acc} ->
        gold_cluster = Map.get(gold_map, mention_key(mention), [mention])
        pred_cluster = Map.get(pred_map, mention_key(mention), [mention])

        # Count common mentions
        common = length(intersection(gold_cluster, pred_cluster))

        mention_precision = safe_divide(common, length(pred_cluster))
        mention_recall = safe_divide(common, length(gold_cluster))

        {p_acc + mention_precision, r_acc + mention_recall}
      end)

    # Average over all mentions
    num_mentions = length(all_mentions)
    precision = safe_divide(precision_sum, num_mentions)
    recall = safe_divide(recall_sum, num_mentions)
    f1 = compute_f1(precision, recall)

    %{precision: precision, recall: recall, f1: f1}
  end

  @doc """
  Compute CEAF metric (entity-based with optimal alignment).

  CEAF finds the optimal alignment between gold and predicted chains
  using the Kuhn-Munkres algorithm (Hungarian algorithm).

  ## Parameters

    - `gold_chains` - Gold standard chains
    - `predicted_chains` - Predicted chains

  ## Returns

  Map with precision, recall, and F1
  """
  @spec compute_ceaf([CorefChain.t()], [CorefChain.t()]) :: metric()
  def compute_ceaf(gold_chains, predicted_chains) do
    # Convert to mention sets
    gold_partitions = chains_to_partitions(gold_chains)
    pred_partitions = chains_to_partitions(predicted_chains)

    # Find optimal alignment (simplified - uses greedy matching)
    # Full implementation would use Hungarian algorithm
    alignment_score = ceaf_optimal_alignment(gold_partitions, pred_partitions)

    # Compute precision and recall
    gold_size = Enum.sum(Enum.map(gold_partitions, &length/1))
    pred_size = Enum.sum(Enum.map(pred_partitions, &length/1))

    recall = safe_divide(alignment_score, gold_size)
    precision = safe_divide(alignment_score, pred_size)
    f1 = compute_f1(precision, recall)

    %{precision: precision, recall: recall, f1: f1}
  end

  @doc """
  Compute CoNLL F1 score.

  CoNLL F1 is the average of MUC, B³, and CEAF F1 scores.

  ## Parameters

    - `gold_chains` - Gold standard chains
    - `predicted_chains` - Predicted chains

  ## Returns

  CoNLL F1 score (0.0 to 1.0)
  """
  @spec conll_f1([CorefChain.t()], [CorefChain.t()]) :: float()
  def conll_f1(gold_chains, predicted_chains) do
    metrics = evaluate(gold_chains, predicted_chains)
    metrics.conll_f1
  end

  ## Private Functions

  # Convert chains to partitions (sets of mentions)
  defp chains_to_partitions(chains) do
    Enum.map(chains, fn chain ->
      Enum.map(chain.mentions, &mention_key/1)
    end)
  end

  # Create unique key for mention
  defp mention_key(mention) do
    {mention.sentence_idx, mention.token_idx, mention.text}
  end

  # Get all unique mentions from chains
  defp get_all_mentions(chains) do
    chains
    |> Enum.flat_map(fn chain -> chain.mentions end)
    |> Enum.uniq_by(&mention_key/1)
  end

  # Build map from mention to its cluster
  defp build_mention_to_chain_map(chains) do
    chains
    |> Enum.flat_map(fn chain ->
      Enum.map(chain.mentions, fn mention ->
        {mention_key(mention), Enum.map(chain.mentions, &mention_key/1)}
      end)
    end)
    |> Enum.into(%{})
  end

  # Compute number of links in partition given other partitions
  defp muc_partition_links(partition, other_partitions) do
    # For each element in partition, find which other partition it maps to
    mapped =
      Enum.map(partition, fn element ->
        Enum.find(other_partitions, fn other_partition ->
          element in other_partition
        end)
      end)

    # Count unique partitions - 1 (number of links needed)
    unique_partitions = mapped |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length()
    max(length(partition) - unique_partitions, 0)
  end

  # Find optimal alignment between two sets of partitions (greedy approximation)
  defp ceaf_optimal_alignment(gold_partitions, pred_partitions) do
    # Greedy matching: for each gold partition, find best matching predicted partition
    used_pred = MapSet.new()

    {total_score, _used} =
      Enum.reduce(gold_partitions, {0, used_pred}, fn gold_part, {score_acc, used_acc} ->
        # Find best matching pred partition that hasn't been used
        {best_score, best_idx} =
          pred_partitions
          |> Enum.with_index()
          |> Enum.reject(fn {_part, idx} -> MapSet.member?(used_acc, idx) end)
          |> Enum.map(fn {pred_part, idx} ->
            {length(intersection(gold_part, pred_part)), idx}
          end)
          |> Enum.max_by(fn {score, _idx} -> score end, fn -> {0, nil} end)

        new_used = if best_idx, do: MapSet.put(used_acc, best_idx), else: used_acc
        {score_acc + best_score, new_used}
      end)

    total_score
  end

  # Set intersection
  defp intersection(list1, list2) do
    set1 = MapSet.new(list1)
    set2 = MapSet.new(list2)
    MapSet.intersection(set1, set2) |> MapSet.to_list()
  end

  # Safe division (returns 0 if denominator is 0)
  defp safe_divide(_num, 0), do: 0.0
  defp safe_divide(_num, +0.0), do: 0.0
  defp safe_divide(num, denom), do: num / denom

  # Compute F1 from precision and recall
  defp compute_f1(+0.0, +0.0), do: 0.0

  defp compute_f1(precision, recall) do
    2 * precision * recall / (precision + recall)
  end

  @doc """
  Format evaluation results as string.

  ## Parameters

    - `metrics` - Evaluation metrics

  ## Returns

  Formatted string with all metrics
  """
  @spec format_results(evaluation()) :: String.t()
  def format_results(metrics) do
    """
    Coreference Evaluation Results
    ==============================

    MUC:
      Precision: #{format_percent(metrics.muc.precision)}
      Recall:    #{format_percent(metrics.muc.recall)}
      F1:        #{format_percent(metrics.muc.f1)}

    B³:
      Precision: #{format_percent(metrics.b3.precision)}
      Recall:    #{format_percent(metrics.b3.recall)}
      F1:        #{format_percent(metrics.b3.f1)}

    CEAF:
      Precision: #{format_percent(metrics.ceaf.precision)}
      Recall:    #{format_percent(metrics.ceaf.recall)}
      F1:        #{format_percent(metrics.ceaf.f1)}

    CoNLL F1:  #{format_percent(metrics.conll_f1)}
    """
  end

  defp format_percent(value) do
    "#{Float.round(value * 100, 2)}%"
  end
end
