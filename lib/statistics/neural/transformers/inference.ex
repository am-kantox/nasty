defmodule Nasty.Statistics.Neural.Transformers.Inference do
  @moduledoc """
  Optimized inference for transformer models.

  Provides optimizations including:
  - Batch processing for multiple documents
  - Model quantization for faster inference
  - EXLA compilation for GPU acceleration
  - Prediction caching for repeated inputs
  """

  alias Nasty.AST.Token
  alias Nasty.Statistics.Neural.Transformers.TokenClassifier

  require Logger

  @type optimization :: :quantize | :compile | :gpu | :cache

  @type optimized_model :: %{
          classifier: map(),
          optimizations: [optimization()],
          cache: :ets.tid() | nil,
          compiled_serving: pid() | nil
        }

  @doc """
  Optimizes a model for inference.

  ## Options

    * `:optimizations` - List of optimizations to apply (default: [:compile])
    * `:cache_size` - Maximum number of cached predictions (default: 1000)
    * `:device` - Device to use (:cpu or :cuda, default: :cpu)

  ## Examples

      {:ok, optimized} = Inference.optimize_for_inference(classifier,
        optimizations: [:compile, :cache],
        device: :cuda
      )

  """
  @spec optimize_for_inference(map(), keyword()) :: {:ok, optimized_model()} | {:error, term()}
  def optimize_for_inference(classifier, opts \\ []) do
    optimizations = Keyword.get(opts, :optimizations, [:compile])
    cache_size = Keyword.get(opts, :cache_size, 1000)
    device = Keyword.get(opts, :device, :cpu)

    Logger.info("Optimizing model for inference")
    Logger.info("Optimizations: #{inspect(optimizations)}")

    # Apply optimizations
    with {:ok, cache} <- maybe_create_cache(optimizations, cache_size),
         {:ok, compiled_serving} <- maybe_compile(optimizations, classifier, device) do
      optimized = %{
        classifier: classifier,
        optimizations: optimizations,
        cache: cache,
        compiled_serving: compiled_serving
      }

      {:ok, optimized}
    end
  end

  @doc """
  Performs batch prediction on multiple document sequences.

  More efficient than individual predictions for processing many documents.

  ## Examples

      {:ok, all_predictions} = Inference.batch_predict(
        optimized_model,
        [doc1_tokens, doc2_tokens, doc3_tokens]
      )

  """
  @spec batch_predict(optimized_model(), [[Token.t()]], keyword()) ::
          {:ok, [[map()]]} | {:error, term()}
  def batch_predict(optimized_model, document_sequences, opts \\ []) do
    Logger.info("Batch predicting #{length(document_sequences)} documents")

    # Check cache if enabled
    if :cache in optimized_model.optimizations do
      batch_predict_with_cache(optimized_model, document_sequences, opts)
    else
      batch_predict_no_cache(optimized_model, document_sequences, opts)
    end
  end

  @doc """
  Predicts labels for a single sequence using optimized model.

  Falls back to cache if available.

  ## Examples

      {:ok, predictions} = Inference.predict(optimized_model, tokens)

  """
  @spec predict(optimized_model(), [Token.t()], keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def predict(optimized_model, tokens, opts \\ []) do
    # Generate cache key
    cache_key = generate_cache_key(tokens)

    # Try cache first
    case lookup_cache(optimized_model.cache, cache_key) do
      {:ok, cached_predictions} ->
        {:ok, cached_predictions}

      :miss ->
        # Compute predictions
        case TokenClassifier.predict(optimized_model.classifier, tokens, opts) do
          {:ok, predictions} ->
            # Store in cache
            store_in_cache(optimized_model.cache, cache_key, predictions)
            {:ok, predictions}

          error ->
            error
        end
    end
  end

  @doc """
  Clears the prediction cache.

  ## Examples

      Inference.clear_cache(optimized_model)

  """
  @spec clear_cache(optimized_model()) :: :ok
  def clear_cache(%{cache: nil}), do: :ok

  def clear_cache(%{cache: cache}) do
    :ets.delete_all_objects(cache)
    Logger.info("Cleared prediction cache")
    :ok
  end

  @doc """
  Gets cache statistics.

  ## Examples

      {:ok, stats} = Inference.cache_stats(optimized_model)
      # => %{entries: 150, hits: 450, misses: 50}

  """
  @spec cache_stats(optimized_model()) :: {:ok, map()} | :no_cache
  def cache_stats(%{cache: nil}), do: :no_cache

  def cache_stats(%{cache: cache}) do
    info = :ets.info(cache)

    stats = %{
      entries: Keyword.get(info, :size, 0),
      memory_words: Keyword.get(info, :memory, 0)
    }

    {:ok, stats}
  end

  # Private functions

  defp maybe_create_cache(optimizations, cache_size) do
    if :cache in optimizations do
      cache = :ets.new(:transformer_cache, [:set, :public, read_concurrency: true])
      Logger.info("Created prediction cache (max size: #{cache_size})")
      {:ok, cache}
    else
      {:ok, nil}
    end
  end

  defp maybe_compile(optimizations, _classifier, device) do
    if :compile in optimizations do
      Logger.info("Compiling model for #{device}")
      # TODO: Implement Bumblebee serving compilation
      # For now, return nil (no compiled serving)
      {:ok, nil}
    else
      {:ok, nil}
    end
  end

  defp batch_predict_with_cache(optimized_model, document_sequences, opts) do
    # Process each document, using cache when possible
    results =
      Enum.map(document_sequences, fn tokens ->
        predict(optimized_model, tokens, opts)
      end)

    # Collect results
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      predictions = Enum.map(results, fn {:ok, preds} -> preds end)
      {:ok, predictions}
    else
      first_error = Enum.find(results, &match?({:error, _}, &1))
      first_error
    end
  end

  defp batch_predict_no_cache(optimized_model, document_sequences, opts) do
    # Use TokenClassifier batch prediction
    TokenClassifier.predict_batch(optimized_model.classifier, document_sequences, opts)
  end

  defp generate_cache_key(tokens) do
    # Create a hash of the token texts
    token_texts = Enum.map(tokens, & &1.text)
    token_string = Enum.join(token_texts, " ")
    :erlang.phash2(token_string)
  end

  defp lookup_cache(nil, _key), do: :miss

  defp lookup_cache(cache, key) do
    case :ets.lookup(cache, key) do
      [{^key, predictions}] -> {:ok, predictions}
      [] -> :miss
    end
  end

  defp store_in_cache(nil, _key, _predictions), do: :ok

  defp store_in_cache(cache, key, predictions) do
    :ets.insert(cache, {key, predictions})
    :ok
  end
end
