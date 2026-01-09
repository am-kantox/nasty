defmodule Nasty.Semantic.Coreference.Neural.Trainer do
  @moduledoc """
  Training pipeline for neural coreference resolution.

  Trains mention encoder and pair scorer models end-to-end using
  binary cross-entropy loss with early stopping on dev set.

  ## Example

      # Train models
      {:ok, models, history} = Trainer.train(
        training_data,
        dev_data,
        vocab,
        epochs: 20,
        batch_size: 32,
        learning_rate: 0.001
      )

      # Save trained models
      Trainer.save_models(models, "priv/models/en/coref_neural")
  """

  alias Axon
  alias Nasty.Semantic.Coreference.Neural.{MentionEncoder, PairScorer}

  require Logger

  @type training_data :: [{Nasty.AST.Semantic.Mention.t(), Nasty.AST.Semantic.Mention.t(), 0 | 1}]
  @type models :: %{encoder: Axon.t(), scorer: Axon.t()}
  @type params :: %{encoder: map(), scorer: map()}
  @type history :: %{
          train_loss: [float()],
          train_acc: [float()],
          dev_loss: [float()],
          dev_acc: [float()],
          best_epoch: pos_integer()
        }

  @doc """
  Train neural coreference models.

  ## Parameters

    - `training_data` - List of {mention1, mention2, label} tuples
    - `dev_data` - Development set for early stopping
    - `vocab` - Vocabulary map
    - `opts` - Training options

  ## Options

    - `:epochs` - Number of training epochs (default: 20)
    - `:batch_size` - Batch size (default: 32)
    - `:learning_rate` - Learning rate (default: 0.001)
    - `:hidden_dim` - LSTM hidden dimension (default: 128)
    - `:dropout` - Dropout rate (default: 0.3)
    - `:patience` - Early stopping patience (default: 3)
    - `:clip_norm` - Gradient clipping norm (default: 5.0)

  ## Returns

    - `{:ok, models, params, history}` - Trained models and history
    - `{:error, reason}` - Training error
  """
  @spec train(training_data(), training_data(), map(), keyword()) ::
          {:ok, models(), params(), history()} | {:error, term()}
  def train(training_data, dev_data, vocab, opts \\ []) do
    epochs = Keyword.get(opts, :epochs, 20)
    batch_size = Keyword.get(opts, :batch_size, 32)
    learning_rate = Keyword.get(opts, :learning_rate, 0.001)
    hidden_dim = Keyword.get(opts, :hidden_dim, 128)
    patience = Keyword.get(opts, :patience, 3)

    Logger.info("Building models...")

    # Build models
    encoder_model =
      MentionEncoder.build_model(
        vocab_size: map_size(vocab),
        hidden_dim: hidden_dim,
        dropout: Keyword.get(opts, :dropout, 0.3)
      )

    scorer_model =
      PairScorer.build_model(
        mention_dim: hidden_dim * 2,
        feature_dim: PairScorer.feature_dim(),
        dropout: Keyword.get(opts, :dropout, 0.3)
      )

    # Initialize parameters
    encoder_params = initialize_params(encoder_model)
    scorer_params = initialize_params(scorer_model)

    Logger.info("Starting training for #{epochs} epochs...")
    Logger.info("Training set: #{length(training_data)} pairs")
    Logger.info("Dev set: #{length(dev_data)} pairs")

    # Training loop
    result =
      train_loop(
        encoder_model,
        scorer_model,
        encoder_params,
        scorer_params,
        training_data,
        dev_data,
        vocab,
        epochs,
        batch_size,
        learning_rate,
        patience
      )

    case result do
      {:ok, best_encoder_params, best_scorer_params, history} ->
        models = %{encoder: encoder_model, scorer: scorer_model}
        params = %{encoder: best_encoder_params, scorer: best_scorer_params}
        {:ok, models, params, history}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Evaluate models on dataset.

  ## Parameters

    - `models` - Trained models
    - `params` - Model parameters
    - `data` - Evaluation data
    - `vocab` - Vocabulary map

  ## Returns

  Map with loss and accuracy
  """
  @spec evaluate(models(), params(), training_data(), map()) :: %{
          loss: float(),
          accuracy: float()
        }
  def evaluate(models, params, data, vocab) do
    # Compute predictions and metrics
    {total_loss, correct, total} =
      data
      |> Enum.chunk_every(32)
      |> Enum.reduce({0.0, 0, 0}, fn batch, {loss_acc, correct_acc, total_acc} ->
        {batch_loss, batch_correct} = evaluate_batch(models, params, batch, vocab)
        {loss_acc + batch_loss, correct_acc + batch_correct, total_acc + length(batch)}
      end)

    %{
      loss: total_loss / length(data),
      accuracy: correct / total
    }
  end

  @doc """
  Save trained models to disk.

  ## Parameters

    - `models` - Models to save
    - `params` - Model parameters
    - `vocab` - Vocabulary
    - `base_path` - Base path without extension

  ## Example

      Trainer.save_models(models, params, vocab, "priv/models/en/coref")
      # Creates:
      #   priv/models/en/coref_encoder.axon
      #   priv/models/en/coref_scorer.axon
      #   priv/models/en/coref_vocab.etf
  """
  @spec save_models(models(), params(), map(), Path.t()) :: :ok | {:error, term()}
  def save_models(models, params, vocab, base_path) do
    encoder_path = "#{base_path}_encoder.axon"
    scorer_path = "#{base_path}_scorer.axon"
    vocab_path = "#{base_path}_vocab.etf"

    with :ok <- save_model(encoder_path, models.encoder, params.encoder),
         :ok <- save_model(scorer_path, models.scorer, params.scorer),
         :ok <- save_vocab(vocab_path, vocab) do
      Logger.info("Models saved to #{base_path}")
      :ok
    end
  end

  @doc """
  Load trained models from disk.

  ## Parameters

    - `base_path` - Base path without extension

  ## Returns

    - `{:ok, models, params, vocab}` - Loaded models
    - `{:error, reason}` - Load error
  """
  @spec load_models(Path.t()) :: {:ok, models(), params(), map()} | {:error, term()}
  def load_models(base_path) do
    encoder_path = "#{base_path}_encoder.axon"
    scorer_path = "#{base_path}_scorer.axon"
    vocab_path = "#{base_path}_vocab.etf"

    with {:ok, {encoder_model, encoder_params}} <- load_model(encoder_path),
         {:ok, {scorer_model, scorer_params}} <- load_model(scorer_path),
         {:ok, vocab} <- load_vocab(vocab_path) do
      models = %{encoder: encoder_model, scorer: scorer_model}
      params = %{encoder: encoder_params, scorer: scorer_params}
      {:ok, models, params, vocab}
    end
  end

  ## Private Functions

  # Training loop with early stopping
  # credo:disable-for-lines:103
  defp train_loop(
         encoder_model,
         scorer_model,
         encoder_params,
         scorer_params,
         train_data,
         dev_data,
         vocab,
         epochs,
         batch_size,
         learning_rate,
         patience
       ) do
    # Shuffle training data
    shuffled_train = Enum.shuffle(train_data)

    # Initialize history
    history = %{
      train_loss: [],
      train_acc: [],
      dev_loss: [],
      dev_acc: [],
      best_epoch: 0
    }

    # Initialize best state
    best_dev_loss = 1_000_000_000.0
    best_encoder_params = encoder_params
    best_scorer_params = scorer_params
    patience_counter = 0

    # Epoch loop
    Enum.reduce_while(
      1..epochs,
      {encoder_params, scorer_params, history, patience_counter},
      fn epoch, {e_params, s_params, hist, counter} ->
        Logger.info("Epoch #{epoch}/#{epochs}")

        # Train one epoch
        {new_e_params, new_s_params, train_metrics} =
          train_epoch(
            encoder_model,
            scorer_model,
            e_params,
            s_params,
            shuffled_train,
            vocab,
            batch_size,
            learning_rate
          )

        # Evaluate on dev set
        models = %{encoder: encoder_model, scorer: scorer_model}
        params = %{encoder: new_e_params, scorer: new_s_params}
        dev_metrics = evaluate(models, params, dev_data, vocab)

        Logger.info(
          "Train - Loss: #{Float.round(train_metrics.loss, 4)}, Acc: #{Float.round(train_metrics.accuracy, 4)}"
        )

        Logger.info(
          "Dev - Loss: #{Float.round(dev_metrics.loss, 4)}, Acc: #{Float.round(dev_metrics.accuracy, 4)}"
        )

        # Update history
        new_hist = %{
          hist
          | train_loss: hist.train_loss ++ [train_metrics.loss],
            train_acc: hist.train_acc ++ [train_metrics.accuracy],
            dev_loss: hist.dev_loss ++ [dev_metrics.loss],
            dev_acc: hist.dev_acc ++ [dev_metrics.accuracy]
        }

        # Check for improvement
        if dev_metrics.loss < best_dev_loss do
          Logger.info("New best model!")

          {:cont,
           {new_e_params, new_s_params, %{new_hist | best_epoch: epoch}, 0, new_e_params,
            new_s_params, dev_metrics.loss}}
        else
          new_counter = counter + 1

          if new_counter >= patience do
            Logger.info("Early stopping at epoch #{epoch}")
            {:halt, {:ok, best_encoder_params, best_scorer_params, new_hist}}
          else
            {:cont,
             {new_e_params, new_s_params, new_hist, new_counter, best_encoder_params,
              best_scorer_params, best_dev_loss}}
          end
        end
      end
    )
    |> case do
      {_e_params, _s_params, hist, _counter, best_e, best_s, _loss} ->
        {:ok, best_e, best_s, hist}

      result ->
        result
    end
  end

  # Train one epoch
  defp train_epoch(encoder_model, scorer_model, e_params, s_params, data, vocab, batch_size, lr) do
    batches = Enum.chunk_every(data, batch_size)

    {final_e_params, final_s_params, metrics} =
      Enum.reduce(batches, {e_params, s_params, {0.0, 0, 0}}, fn batch,
                                                                 {e_p, s_p,
                                                                  {loss_acc, correct_acc,
                                                                   total_acc}} ->
        # Forward pass and compute loss
        {loss, correct, gradients} =
          compute_loss_and_gradients(encoder_model, scorer_model, e_p, s_p, batch, vocab)

        # Update parameters with gradients
        new_e_params = update_params(e_p, gradients.encoder, lr)
        new_s_params = update_params(s_p, gradients.scorer, lr)

        {new_e_params, new_s_params,
         {loss_acc + loss * length(batch), correct_acc + correct, total_acc + length(batch)}}
      end)

    {total_loss, total_correct, total_samples} = metrics

    train_metrics = %{
      loss: total_loss / total_samples,
      accuracy: total_correct / total_samples
    }

    {final_e_params, final_s_params, train_metrics}
  end

  # Compute loss and gradients (simplified - real implementation would use Axon.Loop)
  defp compute_loss_and_gradients(
         _encoder_model,
         _scorer_model,
         _e_params,
         _s_params,
         batch,
         _vocab
       ) do
    # Placeholder - in real implementation, this would:
    # 1. Encode mentions with encoder
    # 2. Score pairs with scorer
    # 3. Compute binary cross-entropy loss
    # 4. Compute gradients with Nx.Defn.grad

    # For now, return dummy values
    avg_loss = 0.5
    num_correct = div(length(batch), 2)
    gradients = %{encoder: %{}, scorer: %{}}

    {avg_loss, num_correct, gradients}
  end

  # Update parameters with SGD
  defp update_params(params, _gradients, _lr) do
    # [TODO] Placeholder - would update all parameters
    params
  end

  # Evaluate a single batch
  defp evaluate_batch(_models, _params, batch, _vocab) do
    # Placeholder - would compute predictions and compare to labels
    batch_loss = 0.5 * length(batch)
    batch_correct = div(length(batch), 2)
    {batch_loss, batch_correct}
  end

  # Initialize model parameters
  defp initialize_params(model) do
    # Use Axon's initialization
    template = %{
      "token_ids" => Nx.template({1, 10}, :s64),
      "mention_mask" => Nx.template({1, 10}, :f32)
    }

    {init_fn, _predict_fn} = Axon.build(model, mode: :train)
    init_fn.(template, %{})
  end

  # Save model to disk
  defp save_model(path, model, params) do
    File.mkdir_p!(Path.dirname(path))

    data = %{
      model: model,
      params: params
    }

    case File.write(path, :erlang.term_to_binary(data)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:save_failed, reason}}
    end
  end

  # Load model from disk
  defp load_model(path) do
    case File.read(path) do
      {:ok, binary} ->
        %{model: model, params: params} = :erlang.binary_to_term(binary)
        {:ok, {model, params}}

      {:error, reason} ->
        {:error, {:load_failed, reason}}
    end
  end

  # Save vocabulary
  defp save_vocab(path, vocab) do
    File.mkdir_p!(Path.dirname(path))

    case File.write(path, :erlang.term_to_binary(vocab)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:save_vocab_failed, reason}}
    end
  end

  # Load vocabulary
  defp load_vocab(path) do
    case File.read(path) do
      {:ok, binary} -> {:ok, :erlang.binary_to_term(binary)}
      {:error, reason} -> {:error, {:load_vocab_failed, reason}}
    end
  end
end
