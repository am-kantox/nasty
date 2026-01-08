defmodule Nasty.Statistics.Neural.Pretrained do
  @moduledoc """
  Integration with pre-trained transformer models via Bumblebee.

  Provides access to state-of-the-art pre-trained models from HuggingFace
  for tasks like POS tagging, NER, and text classification.

  ## Supported Models

  - BERT (bert-base-uncased, bert-base-cased)
  - RoBERTa (roberta-base, roberta-large)
  - DistilBERT (distilbert-base-uncased)
  - Custom fine-tuned models

  ## Usage

      # Load a pre-trained BERT model for POS tagging
      {:ok, model} = Pretrained.load_model("bert-base-uncased", task: :pos_tagging)

      # Fine-tune on your data
      {:ok, fine_tuned} = Pretrained.fine_tune(model, training_data, epochs: 3)

      # Use for prediction
      {:ok, tags} = Pretrained.predict(fine_tuned, words)

  ## Note

  This module requires downloading models from HuggingFace. Models are cached
  locally after the first download.

  Full implementation requires:
  - Model downloading and caching
  - Tokenization with Bumblebee tokenizers
  - Fine-tuning interface
  - Integration with existing pipeline

  ## Future Enhancements

  - Support for multilingual models (mBERT, XLM-R)
  - Zero-shot classification
  - Model quantization for efficiency
  - Custom model registration
  """

  require Logger

  @doc """
  Loads a pre-trained model from Bumblebee/HuggingFace.

  ## Parameters

    - `model_name` - Model identifier (e.g., "bert-base-uncased")
    - `opts` - Loading options

  ## Options

    - `:task` - Task type: :pos_tagging, :ner, :classification
    - `:cache_dir` - Model cache directory (default: ~/.cache/nasty/models)
    - `:device` - Device to load on: :cpu or :cuda (default: :cpu)

  ## Returns

    - `{:ok, model}` - Loaded model
    - `{:error, reason}` - Loading failed

  ## Examples

      {:ok, model} = Pretrained.load_model("bert-base-uncased", task: :pos_tagging)
  """
  @spec load_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def load_model(model_name, opts \\ []) do
    Logger.info("Loading pre-trained model: #{model_name}")

    # Convert string model name to atom if needed
    model_atom =
      if is_binary(model_name) do
        String.replace(model_name, "-", "_") |> String.to_atom()
      else
        model_name
      end

    # Use the new Transformers.Loader
    alias Nasty.Statistics.Neural.Transformers.Loader

    case Loader.load_model(model_atom, opts) do
      {:ok, model} ->
        Logger.info("Successfully loaded transformer model: #{model_name}")
        {:ok, model}

      {:error, reason} ->
        Logger.error("Failed to load model #{model_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fine-tunes a pre-trained model on task-specific data.

  ## Parameters

    - `model` - Pre-trained model
    - `training_data` - Task-specific training data
    - `opts` - Fine-tuning options

  ## Options

    - `:epochs` - Number of epochs (default: 3)
    - `:learning_rate` - Learning rate (default: 2e-5)
    - `:batch_size` - Batch size (default: 16)
    - `:warmup_ratio` - Warmup ratio (default: 0.1)

  ## Returns

    - `{:ok, fine_tuned_model}` - Fine-tuned model
    - `{:error, reason}` - Fine-tuning failed
  """
  @spec fine_tune(map(), list(), keyword()) :: {:ok, map()} | {:error, term()}
  def fine_tune(model, training_data, opts \\ []) do
    Logger.info("Fine-tuning transformer model")

    # Use the new Transformers.FineTuner
    alias Nasty.Statistics.Neural.Transformers.FineTuner

    case FineTuner.fine_tune(model, training_data, opts) do
      {:ok, fine_tuned_model} ->
        Logger.info("Successfully fine-tuned model")
        {:ok, fine_tuned_model}

      {:error, reason} ->
        Logger.error("Fine-tuning failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Makes predictions using a pre-trained or fine-tuned model.

  ## Parameters

    - `model` - Model (pre-trained or fine-tuned)
    - `input` - Input text or tokens
    - `opts` - Prediction options

  ## Returns

    - `{:ok, predictions}` - Model predictions
    - `{:error, reason}` - Prediction failed
  """
  @spec predict(map(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def predict(model, input, opts \\ []) do
    # Use TokenClassifier for token-level predictions
    alias Nasty.Statistics.Neural.Transformers.TokenClassifier

    # Determine task from options or model config
    task = Keyword.get(opts, :task, :pos_tagging)

    case task do
      :pos_tagging ->
        TokenClassifier.predict(model, input, opts)

      :ner ->
        TokenClassifier.predict(model, input, opts)

      :token_classification ->
        TokenClassifier.predict(model, input, opts)

      _ ->
        {:error, {:unsupported_task, task}}
    end
  end

  @doc """
  Lists available pre-trained models.

  ## Returns

  List of available model names with metadata.
  """
  @spec list_models() :: [map()]
  def list_models do
    [
      %{
        name: "bert-base-uncased",
        description: "BERT base model (uncased)",
        tasks: [:pos_tagging, :ner, :classification],
        size_mb: 110
      },
      %{
        name: "bert-base-cased",
        description: "BERT base model (cased)",
        tasks: [:pos_tagging, :ner, :classification],
        size_mb: 110
      },
      %{
        name: "roberta-base",
        description: "RoBERTa base model",
        tasks: [:pos_tagging, :ner, :classification],
        size_mb: 125
      },
      %{
        name: "distilbert-base-uncased",
        description: "DistilBERT base model (faster, smaller)",
        tasks: [:pos_tagging, :ner, :classification],
        size_mb: 66
      }
    ]
  end
end
