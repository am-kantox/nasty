defmodule Nasty.Statistics.SequenceLabeling.CRF do
  @moduledoc """
  Conditional Random Field (CRF) for sequence labeling.

  Implements linear-chain CRF with feature-based modeling for tasks
  like Named Entity Recognition (NER), POS tagging, etc.

  ## Model

  Linear-chain CRF models the conditional probability:
  ```
  P(y|x) = exp(score(x, y)) / Z(x)
  ```

  Where:
  - `score(x, y) = Σ feature_weights + Σ transition_weights`
  - `Z(x)` is the partition function (normalizer)

  ## Training

  Uses forward-backward algorithm to compute gradients and
  gradient descent with momentum for optimization.

  ## Prediction

  Uses Viterbi algorithm to find the most likely label sequence.

  ## Examples

      # Training
      model = CRF.new(labels: [:person, :gpe, :org, :none])
      training_data = load_annotated_data()
      {:ok, trained} = CRF.train(model, training_data, iterations: 100)

      # Prediction
      {:ok, labels} = CRF.predict(trained, tokens, [])
  """

  @behaviour Nasty.Statistics.Model

  alias Nasty.AST.Token
  alias Nasty.Statistics.Model
  alias Nasty.Statistics.SequenceLabeling.{Features, Optimizer, Viterbi}

  defstruct [
    :feature_weights,
    # Map of feature → label → weight
    :transition_weights,
    # Map of {prev_label, curr_label} → weight
    :label_set,
    # Set of all possible labels
    :labels,
    # List of labels
    :language,
    # Language code
    :metadata
    # Training metadata
  ]

  @type t :: %__MODULE__{
          feature_weights: map(),
          transition_weights: map(),
          label_set: MapSet.t(),
          labels: [atom()],
          language: atom(),
          metadata: map()
        }

  @doc """
  Creates a new untrained CRF model.

  ## Options

  - `:labels` - List of possible labels (required)
  - `:language` - Language code (default: `:en`)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    labels = Keyword.fetch!(opts, :labels)

    %__MODULE__{
      feature_weights: %{},
      transition_weights: %{},
      label_set: MapSet.new(labels),
      labels: labels,
      language: Keyword.get(opts, :language, :en),
      metadata: %{}
    }
  end

  @impl true
  @doc """
  Trains the CRF model on annotated sequence data.

  ## Training Data Format

  List of `{tokens, labels}` tuples where:
  - `tokens` is a list of `%Token{}` structs
  - `labels` is a list of label atoms (same length as tokens)

  ## Options

  - `:iterations` - Maximum training iterations (default: 100)
  - `:learning_rate` - Initial learning rate (default: 0.1)
  - `:regularization` - L2 regularization strength (default: 1.0)
  - `:method` - Optimization method (`:sgd`, `:momentum`, `:adagrad`) (default: `:momentum`)
  - `:convergence_threshold` - Gradient norm threshold (default: 0.01)

  ## Returns

  `{:ok, trained_model}` with learned feature and transition weights
  """
  @spec train(t(), [{[Token.t()], [atom()]}], keyword()) :: {:ok, t()} | {:error, term()}
  def train(model, training_data, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 100)
    learning_rate = Keyword.get(opts, :learning_rate, 0.1)
    regularization = Keyword.get(opts, :regularization, 1.0)
    method = Keyword.get(opts, :method, :momentum)
    convergence_threshold = Keyword.get(opts, :convergence_threshold, 0.01)

    # Extract all features from training data
    all_features = extract_all_features(training_data)

    # Initialize weights with nested structure for features
    feature_weights = initialize_feature_weights(all_features, model.labels)
    transition_weights = initialize_transition_weights(model.labels)

    # Initialize optimizer
    optimizer =
      Optimizer.new(
        method: method,
        learning_rate: learning_rate,
        regularization: regularization
      )

    # Training loop
    {final_fw, final_tw, final_meta} =
      train_loop(
        training_data,
        model.labels,
        feature_weights,
        transition_weights,
        optimizer,
        iterations,
        convergence_threshold
      )

    trained_model = %{
      model
      | feature_weights: final_fw,
        transition_weights: final_tw,
        metadata: Map.merge(model.metadata, final_meta)
    }

    {:ok, trained_model}
  end

  @impl true
  @doc """
  Predicts labels for a sequence of tokens using Viterbi decoding.

  ## Parameters

  - `model` - Trained CRF model
  - `tokens` - List of `%Token{}` structs
  - `opts` - Options (currently unused)

  ## Returns

  `{:ok, labels}` - Predicted label sequence
  """
  @spec predict(t(), [Token.t()], keyword()) :: {:ok, [atom()]} | {:error, term()}
  def predict(model, tokens, _opts \\ []) do
    # Extract features for each token
    feature_sequence = Features.extract_sequence(tokens)

    # Decode using Viterbi
    {:ok, labels, _score} =
      Viterbi.decode(
        feature_sequence,
        model.feature_weights,
        model.transition_weights,
        model.labels
      )

    {:ok, labels}
  end

  @impl true
  @doc """
  Saves the trained CRF model to disk.
  """
  @spec save(t(), Path.t()) :: :ok | {:error, term()}
  def save(model, path) do
    binary = Model.serialize(model, model.metadata)

    case File.write(path, binary) do
      :ok -> :ok
      {:error, reason} -> {:error, {:file_write_failed, reason}}
    end
  end

  @impl true
  @doc """
  Loads a trained CRF model from disk.
  """
  @spec load(Path.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    case File.read(path) do
      {:ok, binary} ->
        case Model.deserialize(binary) do
          {:ok, model, _metadata} -> {:ok, model}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, {:file_read_failed, reason}}
    end
  end

  @impl true
  @doc """
  Returns model metadata.
  """
  @spec metadata(t()) :: map()
  def metadata(model), do: model.metadata

  ## Private Functions - Training

  # Main training loop
  defp train_loop(
         training_data,
         labels,
         feature_weights,
         transition_weights,
         optimizer,
         max_iterations,
         convergence_threshold
       ) do
    IO.puts("Starting CRF training...")

    initial_state = %{
      feature_weights: feature_weights,
      transition_weights: transition_weights,
      optimizer: optimizer,
      iteration: 0,
      prev_loss: :infinity
    }

    final_state =
      Enum.reduce_while(1..max_iterations, initial_state, fn iter, state ->
        # Compute gradient
        {fw_grad, tw_grad, avg_loss} =
          compute_gradient(
            training_data,
            labels,
            state.feature_weights,
            state.transition_weights
          )

        # Check convergence
        converged =
          Optimizer.converged?(
            fw_grad,
            state.prev_loss,
            avg_loss,
            grad_threshold: convergence_threshold,
            iteration: iter,
            max_iterations: max_iterations
          )

        if converged do
          IO.puts("Converged at iteration #{iter}")
          {:halt, state}
        else
          # Update weights
          {new_fw, new_opt1} = Optimizer.step(state.feature_weights, fw_grad, state.optimizer)
          {new_tw, new_opt2} = Optimizer.step(state.transition_weights, tw_grad, new_opt1)

          # Progress report every 10 iterations
          if rem(iter, 10) == 0 do
            grad_norm = Optimizer.gradient_norm(fw_grad)

            IO.puts(
              "Iteration #{iter}: loss=#{Float.round(avg_loss, 4)}, grad_norm=#{Float.round(grad_norm, 4)}"
            )
          end

          {:cont,
           %{
             feature_weights: new_fw,
             transition_weights: new_tw,
             optimizer: new_opt2,
             iteration: iter,
             prev_loss: avg_loss
           }}
        end
      end)

    metadata = %{
      trained_at: DateTime.utc_now(),
      training_size: length(training_data),
      iterations: final_state.iteration,
      final_loss: final_state.prev_loss,
      num_features: map_size(final_state.feature_weights)
    }

    {final_state.feature_weights, final_state.transition_weights, metadata}
  end

  # Compute gradient for entire training set
  defp compute_gradient(training_data, labels, feature_weights, transition_weights) do
    {total_fw_grad, total_tw_grad, total_loss} =
      Enum.reduce(training_data, {%{}, %{}, 0.0}, fn {tokens, gold_labels},
                                                     {fw_acc, tw_acc, loss_acc} ->
        # Extract features
        feature_sequence = Features.extract_sequence(tokens)

        # Compute forward-backward probabilities
        forward =
          Viterbi.forward_probabilities(
            feature_sequence,
            feature_weights,
            transition_weights,
            labels
          )

        backward =
          Viterbi.backward_probabilities(
            feature_sequence,
            feature_weights,
            transition_weights,
            labels
          )

        z = Viterbi.partition_function(forward, labels, length(tokens) - 1)

        # Compute expected feature counts
        expected_fw =
          expected_feature_counts(feature_sequence, labels, forward, backward, z, feature_weights)

        expected_tw =
          expected_transition_counts(
            labels,
            forward,
            backward,
            z,
            transition_weights,
            length(tokens)
          )

        # Compute observed feature counts (from gold labels)
        observed_fw = observed_feature_counts(feature_sequence, gold_labels)
        observed_tw = observed_transition_counts(gold_labels)

        # Gradient = observed - expected
        fw_grad = subtract_weights(observed_fw, expected_fw)
        tw_grad = subtract_weights(observed_tw, expected_tw)

        # Compute log-likelihood
        gold_score =
          score_sequence(feature_sequence, gold_labels, feature_weights, transition_weights)

        ll = gold_score - z

        {
          Optimizer.add_weights(fw_acc, fw_grad),
          Optimizer.add_weights(tw_acc, tw_grad),
          loss_acc - ll
        }
      end)

    # Average gradient and loss
    n = length(training_data)

    avg_fw_grad = Optimizer.scale_weights(total_fw_grad, -1.0 / n)
    avg_tw_grad = Optimizer.scale_weights(total_tw_grad, -1.0 / n)
    avg_loss = total_loss / n

    {avg_fw_grad, avg_tw_grad, avg_loss}
  end

  # Compute expected feature counts under model distribution
  # Returns nested structure: feature -> label -> count
  defp expected_feature_counts(feature_sequence, labels, forward, backward, z, _feature_weights) do
    n = length(feature_sequence)

    for t <- 0..(n - 1),
        label <- labels,
        feature <- Enum.at(feature_sequence, t),
        reduce: %{} do
      acc ->
        # P(label at position t) = forward[t,label] * backward[t,label] / Z
        fwd = Map.get(forward, {t, label}, :neg_infinity)
        bwd = Map.get(backward, {t, label}, :neg_infinity)

        prob =
          if fwd == :neg_infinity or bwd == :neg_infinity or z == :neg_infinity or z == :infinity do
            0.0
          else
            :math.exp(fwd + bwd - z)
          end

        # Expected count for this feature-label pair (nested structure)
        Map.update(acc, feature, %{label => prob}, fn label_map ->
          Map.update(label_map, label, prob, &(&1 + prob))
        end)
    end
  end

  # Compute expected transition counts
  defp expected_transition_counts(labels, forward, backward, z, transition_weights, n) do
    for t <- 0..(n - 2)//1,
        prev_label <- labels,
        curr_label <- labels,
        reduce: %{} do
      acc ->
        fwd_prev = Map.get(forward, {t, prev_label}, :neg_infinity)
        trans_score = Viterbi.transition_score(prev_label, curr_label, transition_weights, true)
        # Emission handled in features
        emit_score = 0.0
        bwd_curr = Map.get(backward, {t + 1, curr_label}, :neg_infinity)

        prob =
          if fwd_prev == :neg_infinity or bwd_curr == :neg_infinity or z == :neg_infinity or
               z == :infinity do
            0.0
          else
            :math.exp(fwd_prev + trans_score + emit_score + bwd_curr - z)
          end

        key = {prev_label, curr_label}
        Map.update(acc, key, prob, &(&1 + prob))
    end
  end

  # Compute observed feature counts from gold labels
  # Returns nested structure: feature -> label -> count
  defp observed_feature_counts(feature_sequence, labels) do
    feature_sequence
    |> Enum.zip(labels)
    |> Enum.reduce(%{}, fn {features, label}, acc ->
      Enum.reduce(features, acc, fn feature, acc2 ->
        Map.update(acc2, feature, %{label => 1.0}, fn label_map ->
          Map.update(label_map, label, 1.0, &(&1 + 1.0))
        end)
      end)
    end)
  end

  # Compute observed transition counts
  defp observed_transition_counts(labels) do
    labels
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(%{}, fn [prev, curr], acc ->
      key = {prev, curr}
      Map.update(acc, key, 1.0, &(&1 + 1.0))
    end)
  end

  # Score a specific label sequence
  defp score_sequence(feature_sequence, labels, feature_weights, transition_weights) do
    # Emission scores
    emission_score =
      feature_sequence
      |> Enum.zip(labels)
      |> Enum.reduce(0.0, fn {features, label}, acc ->
        acc + Viterbi.emission_score(features, label, feature_weights, true)
      end)

    # Transition scores
    transition_score =
      labels
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(0.0, fn [prev, curr], acc ->
        acc + Viterbi.transition_score(prev, curr, transition_weights, true)
      end)

    emission_score + transition_score
  end

  # Extract all unique features from training data
  defp extract_all_features(training_data) do
    training_data
    |> Enum.flat_map(fn {tokens, _labels} ->
      Features.extract_sequence(tokens)
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  # Initialize feature weights with nested structure: feature -> label -> weight
  defp initialize_feature_weights(features, labels) do
    for feature <- features, into: %{} do
      label_weights =
        for label <- labels, into: %{} do
          # Small random weight between -0.01 and +0.01
          {label, :rand.uniform() * 0.02 - 0.01}
        end

      {feature, label_weights}
    end
  end

  # Initialize transition weights
  defp initialize_transition_weights(labels) do
    for prev <- labels, curr <- labels, into: %{} do
      {{prev, curr}, 0.0}
    end
  end

  # Subtract weight maps element-wise (handles nested structures)
  defp subtract_weights(weights1, weights2) do
    all_keys = MapSet.union(MapSet.new(Map.keys(weights1)), MapSet.new(Map.keys(weights2)))

    Map.new(all_keys, fn key ->
      val1 = Map.get(weights1, key, %{})
      val2 = Map.get(weights2, key, %{})

      # Handle nested structure
      result =
        case {val1, val2} do
          {v1, v2} when is_map(v1) and is_map(v2) ->
            # Nested structure: subtract label maps
            label_keys = MapSet.union(MapSet.new(Map.keys(v1)), MapSet.new(Map.keys(v2)))

            Map.new(label_keys, fn label ->
              {label, Map.get(v1, label, 0.0) - Map.get(v2, label, 0.0)}
            end)

          {v1, v2} when is_number(v1) and is_number(v2) ->
            v1 - v2

          {v1, v2} when is_map(v1) and is_number(v2) ->
            Map.new(v1, fn {k, v} -> {k, v - v2} end)

          {v1, v2} when is_number(v1) and is_map(v2) ->
            Map.new(v2, fn {k, v} -> {k, v1 - v} end)

          _ ->
            0.0
        end

      {key, result}
    end)
  end
end
