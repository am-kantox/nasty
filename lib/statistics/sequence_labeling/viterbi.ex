defmodule Nasty.Statistics.SequenceLabeling.Viterbi do
  @moduledoc """
  Viterbi algorithm for sequence labeling with linear-chain CRFs.

  Finds the most likely label sequence given feature weights and
  transition scores using dynamic programming.

  ## Algorithm

  1. Initialize scores for first position
  2. For each subsequent position:
     - Compute emission score (from features)
     - Compute transition score (from previous label)
     - Keep track of best previous label (backpointer)
  3. Backtrack from best final label to reconstruct sequence

  ## Complexity

  Time: O(n × L²) where n = sequence length, L = number of labels
  Space: O(n × L)
  """

  @type label :: atom()
  @type feature_vector :: [String.t()]
  @type score :: float()
  @type label_sequence :: [label()]

  @doc """
  Decodes the most likely label sequence using Viterbi algorithm.

  ## Parameters

  - `feature_sequence` - List of feature vectors (one per token)
  - `feature_weights` - Map of feature → label → weight
  - `transition_weights` - Map of {prev_label, curr_label} → weight
  - `labels` - List of all possible labels
  - `opts` - Options:
    - `:log_domain` - Use log probabilities (default: true)

  ## Returns

  `{:ok, label_sequence, score}` - Best label sequence and its score
  """
  @spec decode([feature_vector()], map(), map(), [label()], keyword()) ::
          {:ok, label_sequence(), score()}
  def decode(feature_sequence, feature_weights, transition_weights, labels, opts \\ []) do
    log_domain = Keyword.get(opts, :log_domain, true)

    n = length(feature_sequence)

    if n == 0 do
      {:ok, [], 0.0}
    else
      # Initialize Viterbi tables
      {viterbi, backpointers} =
        initialize_viterbi(feature_sequence, feature_weights, labels, log_domain)

      # Forward pass
      {final_viterbi, final_backpointers} =
        forward_pass(
          feature_sequence,
          feature_weights,
          transition_weights,
          labels,
          viterbi,
          backpointers,
          log_domain
        )

      # Backtrack to find best path
      best_sequence = backtrack(final_viterbi, final_backpointers, labels, n, log_domain)
      best_score = get_best_final_score(final_viterbi, labels, n - 1, log_domain)

      {:ok, best_sequence, best_score}
    end
  end

  @doc """
  Computes emission score for a label given features.

  Sum of all feature weights for features present in the feature vector.
  """
  @spec emission_score(feature_vector(), atom(), map(), boolean()) :: score()
  def emission_score(features, label, feature_weights, log_domain \\ true) do
    score =
      Enum.reduce(features, 0.0, fn feature, acc ->
        weight = get_in(feature_weights, [feature, label]) || 0.0
        acc + weight
      end)

    if log_domain, do: score, else: :math.exp(score)
  end

  @doc """
  Computes transition score between two labels.
  """
  @spec transition_score(atom() | nil, atom(), map(), boolean()) :: score()
  def transition_score(prev_label, curr_label, transition_weights, log_domain \\ true) do
    key = {prev_label, curr_label}
    score = Map.get(transition_weights, key, 0.0)

    if log_domain, do: score, else: :math.exp(score)
  end

  ## Private Functions

  # Initialize Viterbi table for first position
  defp initialize_viterbi(feature_sequence, feature_weights, labels, log_domain) do
    first_features = List.first(feature_sequence)

    initial_scores =
      for label <- labels, into: %{} do
        score = emission_score(first_features, label, feature_weights, log_domain)
        {{0, label}, score}
      end

    {initial_scores, %{}}
  end

  # Forward pass through sequence
  defp forward_pass(
         feature_sequence,
         feature_weights,
         transition_weights,
         labels,
         viterbi,
         backpointers,
         log_domain
       ) do
    n = length(feature_sequence)

    Enum.reduce(1..(n - 1), {viterbi, backpointers}, fn t, {vit_acc, bp_acc} ->
      features_t = Enum.at(feature_sequence, t)

      # For each current label
      {new_vit, new_bp} =
        Enum.reduce(labels, {vit_acc, bp_acc}, fn curr_label, {v_acc2, b_acc2} ->
          # Find best previous label
          {best_score, best_prev} =
            labels
            |> Enum.map(fn prev_label ->
              prev_score = Map.get(v_acc2, {t - 1, prev_label}, neg_infinity(log_domain))

              trans_score =
                transition_score(prev_label, curr_label, transition_weights, log_domain)

              emit_score = emission_score(features_t, curr_label, feature_weights, log_domain)

              total_score =
                if log_domain do
                  prev_score + trans_score + emit_score
                else
                  prev_score * trans_score * emit_score
                end

              {total_score, prev_label}
            end)
            |> Enum.max_by(fn {score, _} -> score end)

          # Update tables
          v_acc3 = Map.put(v_acc2, {t, curr_label}, best_score)
          b_acc3 = Map.put(b_acc2, {t, curr_label}, best_prev)

          {v_acc3, b_acc3}
        end)

      {new_vit, new_bp}
    end)
  end

  # Backtrack to reconstruct best label sequence
  defp backtrack(viterbi, backpointers, labels, n, log_domain) do
    # Find best final label
    best_final_label =
      labels
      |> Enum.max_by(fn label ->
        Map.get(viterbi, {n - 1, label}, neg_infinity(log_domain))
      end)

    # Reconstruct path backwards
    path = reconstruct_path(backpointers, best_final_label, n - 1, [best_final_label])
    Enum.reverse(path)
  end

  defp reconstruct_path(_backpointers, _label, 0, path), do: path

  defp reconstruct_path(backpointers, curr_label, t, path) do
    prev_label = Map.get(backpointers, {t, curr_label})

    if prev_label do
      reconstruct_path(backpointers, prev_label, t - 1, [prev_label | path])
    else
      path
    end
  end

  # Get best score at final position
  defp get_best_final_score(viterbi, labels, final_pos, log_domain) do
    labels
    |> Enum.map(fn label ->
      Map.get(viterbi, {final_pos, label}, neg_infinity(log_domain))
    end)
    |> Enum.max()
  end

  # Negative infinity for log domain, or 0 for probability domain
  defp neg_infinity(true), do: :neg_infinity
  defp neg_infinity(false), do: 0.0

  @doc """
  Computes forward probabilities (for training).

  Used in CRF training to compute feature expectations.

  Returns map of {position, label} → forward probability.
  """
  @spec forward_probabilities([feature_vector()], map(), map(), [label()]) :: map()
  def forward_probabilities(feature_sequence, feature_weights, transition_weights, labels) do
    n = length(feature_sequence)

    # Initialize
    {forward, _} = initialize_viterbi(feature_sequence, feature_weights, labels, true)

    # Forward pass (sum instead of max)
    Enum.reduce(1..(n - 1), forward, fn t, fwd_acc ->
      features_t = Enum.at(feature_sequence, t)

      Enum.reduce(labels, fwd_acc, fn curr_label, acc2 ->
        # Sum over all previous labels
        score_sum =
          Enum.reduce(labels, :neg_infinity, fn prev_label, sum_acc ->
            prev_score = Map.get(acc2, {t - 1, prev_label}, :neg_infinity)
            trans_score = transition_score(prev_label, curr_label, transition_weights, true)
            emit_score = emission_score(features_t, curr_label, feature_weights, true)

            log_sum_exp(sum_acc, prev_score + trans_score + emit_score)
          end)

        Map.put(acc2, {t, curr_label}, score_sum)
      end)
    end)
  end

  @doc """
  Computes backward probabilities (for training).

  Returns map of {position, label} → backward probability.
  """
  @spec backward_probabilities([feature_vector()], map(), map(), [label()]) :: map()
  def backward_probabilities(feature_sequence, feature_weights, transition_weights, labels) do
    n = length(feature_sequence)

    # Initialize (all zeros at final position)
    backward =
      for label <- labels, into: %{} do
        {{n - 1, label}, 0.0}
      end

    # Backward pass
    Enum.reduce((n - 2)..0, backward, fn t, bwd_acc ->
      features_next = Enum.at(feature_sequence, t + 1)

      Enum.reduce(labels, bwd_acc, fn curr_label, acc2 ->
        # Sum over all next labels
        score_sum =
          Enum.reduce(labels, :neg_infinity, fn next_label, sum_acc ->
            next_score = Map.get(acc2, {t + 1, next_label}, :neg_infinity)
            trans_score = transition_score(curr_label, next_label, transition_weights, true)
            emit_score = emission_score(features_next, next_label, feature_weights, true)

            log_sum_exp(sum_acc, next_score + trans_score + emit_score)
          end)

        Map.put(acc2, {t, curr_label}, score_sum)
      end)
    end)
  end

  # Log-sum-exp trick for numerical stability
  # log(exp(a) + exp(b)) = log(exp(a) * (1 + exp(b-a)))
  #                       = a + log(1 + exp(b-a))
  defp log_sum_exp(:neg_infinity, b), do: b
  defp log_sum_exp(a, :neg_infinity), do: a
  defp log_sum_exp(a, b) when a > b, do: a + :math.log(1 + :math.exp(b - a))
  defp log_sum_exp(a, b), do: b + :math.log(1 + :math.exp(a - b))

  @doc """
  Computes partition function Z(x) for normalization.

  Z(x) = sum over all possible label sequences of exp(score(x, y))
  """
  @spec partition_function(map(), [label()], non_neg_integer()) :: float()
  def partition_function(forward, labels, final_pos) do
    # Sum of forward probabilities at final position
    labels
    |> Enum.reduce(:neg_infinity, fn label, acc ->
      score = Map.get(forward, {final_pos, label}, :neg_infinity)
      log_sum_exp(acc, score)
    end)
  end
end
