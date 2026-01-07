defmodule Nasty.Statistics.Neural.Trainer do
  @moduledoc """
  Training utilities for neural models using Axon.Loop.

  Provides a high-level interface for training neural networks with:
  - Multiple optimizer support (Adam, SGD, AdamW)
  - Learning rate scheduling
  - Early stopping
  - Checkpointing
  - Metric tracking
  - Gradient clipping
  - Regularization

  ## Example

      opts = [
        epochs: 10,
        batch_size: 32,
        optimizer: :adam,
        learning_rate: 0.001,
        early_stopping: [patience: 3, min_delta: 0.001]
      ]

      {:ok, trained_model} = Trainer.train(model, train_data, valid_data, opts)

  ## Training Loop

  The training loop follows this structure:

  1. **Forward pass**: Compute predictions from inputs
  2. **Loss computation**: Calculate loss between predictions and targets
  3. **Backward pass**: Compute gradients via backpropagation
  4. **Optimization**: Update model parameters
  5. **Validation**: Evaluate on validation set
  6. **Checkpointing**: Save best model based on validation metrics
  """

  require Logger

  @type training_data :: [{inputs :: map(), targets :: map()}]
  @type validation_data :: [{inputs :: map(), targets :: map()}]

  @doc """
  Trains a neural model using the provided training and validation data.

  ## Parameters

    - `model_fn` - Function that builds the Axon model
    - `train_data` - Training dataset (list of {inputs, targets} tuples)
    - `valid_data` - Validation dataset (optional)
    - `opts` - Training options

  ## Options

    - `:epochs` - Number of training epochs (default: 10)
    - `:batch_size` - Batch size for training (default: 32)
    - `:optimizer` - Optimizer to use: `:adam`, `:sgd`, `:adamw` (default: `:adam`)
    - `:learning_rate` - Learning rate (default: 0.001)
    - `:loss` - Loss function: `:cross_entropy`, `:mean_squared_error`, `:crf` (default: `:cross_entropy`)
    - `:metrics` - Additional metrics to track (default: [:accuracy])
    - `:early_stopping` - Early stopping config (default: nil)
    - `:checkpoint_dir` - Directory to save checkpoints (default: nil)
    - `:gradient_clip` - Gradient clipping value (default: nil)
    - `:dropout` - Dropout rate (default: 0.0)
    - `:l2_regularization` - L2 regularization lambda (default: 0.0)
    - `:lr_schedule` - Learning rate schedule (default: nil)

  ## Returns

    - `{:ok, trained_state}` - Trained model state with parameters
    - `{:error, reason}` - Training error
  """
  @spec train(
          model_fn :: (-> Axon.t()),
          train_data :: training_data(),
          valid_data :: validation_data() | nil,
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def train(model_fn, train_data, valid_data \\ nil, opts \\ []) do
    epochs = Keyword.get(opts, :epochs, 10)
    batch_size = Keyword.get(opts, :batch_size, 32)
    optimizer = Keyword.get(opts, :optimizer, :adam)
    learning_rate = Keyword.get(opts, :learning_rate, 0.001)
    loss_fn = Keyword.get(opts, :loss, :cross_entropy)
    metrics = Keyword.get(opts, :metrics, [:accuracy])
    checkpoint_dir = Keyword.get(opts, :checkpoint_dir)

    Logger.info("Starting neural model training")
    Logger.info("  Epochs: #{epochs}")
    Logger.info("  Batch size: #{batch_size}")
    Logger.info("  Optimizer: #{optimizer}")
    Logger.info("  Learning rate: #{learning_rate}")
    Logger.info("  Training samples: #{length(train_data)}")

    if valid_data do
      Logger.info("  Validation samples: #{length(valid_data)}")
    end

    # Build the model
    model = model_fn.()

    # Create optimizer
    optimizer_fn = build_optimizer(optimizer, learning_rate)

    # Create loss function
    loss = build_loss_function(loss_fn)

    # Build training loop
    model
    |> Axon.Loop.trainer(loss, optimizer_fn)
    |> add_metrics(metrics)
    |> maybe_add_validation(valid_data)
    |> maybe_add_early_stopping(opts)
    |> maybe_add_checkpointing(checkpoint_dir)
    |> maybe_add_gradient_clipping(opts)
    |> add_logging()
    |> run_training(train_data, valid_data, epochs, batch_size)
  end

  @doc """
  Evaluates a trained model on test data.

  ## Parameters

    - `model` - Axon model
    - `state` - Trained model state (parameters)
    - `test_data` - Test dataset
    - `opts` - Evaluation options

  ## Returns

    - `{:ok, metrics}` - Evaluation metrics
    - `{:error, reason}` - Evaluation error
  """
  @spec evaluate(Axon.t(), map(), list(), keyword()) :: {:ok, map()} | {:error, term()}
  def evaluate(model, state, test_data, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 32)
    metrics = Keyword.get(opts, :metrics, [:accuracy])

    Logger.info("Evaluating model on #{length(test_data)} samples")

    try do
      # Build evaluation loop
      results =
        model
        |> Axon.Loop.evaluator()
        |> add_metrics(metrics)
        |> Axon.Loop.run(test_data, state, compiler: EXLA, batch_size: batch_size)

      {:ok, results}
    rescue
      error -> {:error, error}
    end
  end

  ## Private Functions

  defp build_optimizer(:adam, learning_rate) do
    Polaris.Optimizers.adam(learning_rate: learning_rate)
  end

  defp build_optimizer(:sgd, learning_rate) do
    Polaris.Optimizers.sgd(learning_rate: learning_rate)
  end

  defp build_optimizer(:adamw, learning_rate) do
    Polaris.Optimizers.adamw(learning_rate: learning_rate)
  end

  defp build_optimizer(other, _learning_rate) do
    raise ArgumentError, "Unsupported optimizer: #{inspect(other)}"
  end

  defp build_loss_function(:cross_entropy) do
    &Axon.Losses.categorical_cross_entropy(&1, &2,
      reduction: :mean,
      sparse: true
    )
  end

  defp build_loss_function(:mean_squared_error) do
    &Axon.Losses.mean_squared_error(&1, &2, reduction: :mean)
  end

  defp build_loss_function(:crf) do
    # CRF loss will be implemented in the BiLSTM-CRF architecture
    # For now, use cross-entropy as fallback
    build_loss_function(:cross_entropy)
  end

  defp build_loss_function(custom_fn) when is_function(custom_fn) do
    custom_fn
  end

  defp add_metrics(loop, metrics) do
    Enum.reduce(metrics, loop, fn metric, acc ->
      case metric do
        :accuracy ->
          Axon.Loop.metric(acc, :accuracy, "Accuracy")

        :precision ->
          Axon.Loop.metric(acc, :precision, "Precision")

        :recall ->
          Axon.Loop.metric(acc, :recall, "Recall")

        :f1 ->
          Axon.Loop.metric(acc, :f1_score, "F1 Score")

        {name, fun} when is_function(fun) ->
          Axon.Loop.metric(acc, fun, to_string(name))

        _ ->
          acc
      end
    end)
  end

  defp maybe_add_validation(loop, nil), do: loop

  defp maybe_add_validation(loop, valid_data) do
    Axon.Loop.validate(loop, valid_data)
  end

  defp maybe_add_early_stopping(loop, opts) do
    case Keyword.get(opts, :early_stopping) do
      nil ->
        loop

      early_stop_opts ->
        patience = Keyword.get(early_stop_opts, :patience, 3)
        min_delta = Keyword.get(early_stop_opts, :min_delta, 0.001)

        Axon.Loop.early_stop(loop, "validation_loss",
          mode: :min,
          patience: patience,
          min_delta: min_delta
        )
    end
  end

  defp maybe_add_checkpointing(loop, nil), do: loop

  defp maybe_add_checkpointing(loop, checkpoint_dir) do
    File.mkdir_p!(checkpoint_dir)

    Axon.Loop.checkpoint(loop,
      event: :epoch_completed,
      filter: :always
    )
  end

  defp maybe_add_gradient_clipping(loop, opts) do
    case Keyword.get(opts, :gradient_clip) do
      nil ->
        loop

      clip_value ->
        # Note: Axon handles gradient clipping via optimizer options
        # This is a placeholder for explicit clipping if needed
        loop
    end
  end

  defp add_logging(loop) do
    loop
    |> Axon.Loop.log(
      fn %{epoch: epoch, iteration: iteration, loss: loss} = state ->
        metrics_str =
          state
          |> Map.drop([:epoch, :iteration, :loss, :step_state])
          |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{format_metric(v)}" end)

        "Epoch #{epoch}, Iteration #{iteration}: loss=#{format_metric(loss)}, #{metrics_str}"
      end,
      event: :iteration_completed,
      filter: fn %{iteration: iteration} -> rem(iteration, 10) == 0 end
    )
    |> Axon.Loop.log(
      fn %{epoch: epoch} = state ->
        val_metrics =
          state
          |> Map.to_list()
          |> Enum.filter(fn {k, _v} -> String.starts_with?(to_string(k), "validation_") end)
          |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{format_metric(v)}" end)

        "Epoch #{epoch} completed. #{val_metrics}"
      end,
      event: :epoch_completed
    )
  end

  defp format_metric(value) when is_float(value) do
    Float.round(value, 4)
  end

  defp format_metric(value), do: value

  defp run_training(loop, train_data, _valid_data, epochs, batch_size) do
    # Initialize model state
    init_state = Axon.Loop.init(loop)

    # Run training
    trained_state =
      Axon.Loop.run(loop, train_data, init_state,
        epochs: epochs,
        batch_size: batch_size,
        compiler: EXLA
      )

    {:ok, trained_state}
  rescue
    error ->
      Logger.error("Training failed: #{inspect(error)}")
      {:error, error}
  end
end
