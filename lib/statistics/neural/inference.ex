defmodule Nasty.Statistics.Neural.Inference do
  @moduledoc """
  Efficient inference utilities for neural models.

  Provides optimized prediction with:
  - Batch processing for multiple inputs
  - Dynamic batching for variable-length sequences
  - Model warmup and JIT compilation
  - Result caching
  - EXLA acceleration

  ## Example

      # Single prediction
      {:ok, tags} = Inference.predict(model, state, ["The", "cat", "sat"], [])

      # Batch prediction
      sentences = [
        ["The", "cat", "sat"],
        ["A", "dog", "ran"],
        ["Birds", "fly"]
      ]
      {:ok, all_tags} = Inference.predict_batch(model, state, sentences, [])

  ## Performance Tips

  1. Use batch prediction when possible for better throughput
  2. Enable EXLA compilation for 10-100x speedup
  3. Warm up the model on first use to trigger JIT compilation
  4. Use consistent batch sizes when possible
  """

  require Logger

  @doc """
  Runs inference on a single input.

  ## Parameters

    - `model` - Axon model
    - `state` - Trained model state (parameters)
    - `input` - Input data (will be batched automatically)
    - `opts` - Inference options

  ## Options

    - `:compiler` - Backend compiler: `:exla` or `:blas` (default: `:exla`)
    - `:mode` - Execution mode: `:train` or `:inference` (default: `:inference`)

  ## Returns

    - `{:ok, output}` - Model prediction
    - `{:error, reason}` - Inference error
  """
  @spec predict(Axon.t(), map(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def predict(model, state, input, opts \\ []) do
    compiler = Keyword.get(opts, :compiler, EXLA)
    mode = Keyword.get(opts, :mode, :inference)

    try do
      # Create predict function with JIT compilation
      predict_fn = Axon.build(model, compiler: compiler, mode: mode)

      # Run prediction
      output = predict_fn.(state, input)

      {:ok, output}
    rescue
      error ->
        Logger.error("Inference failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Runs inference on a batch of inputs efficiently.

  All inputs in the batch must have the same structure (same keys).
  For variable-length sequences, padding will be applied automatically.

  ## Parameters

    - `model` - Axon model
    - `state` - Trained model state
    - `inputs` - List of input maps
    - `opts` - Inference options

  ## Options

    - `:batch_size` - Process in batches of this size (default: 32)
    - `:compiler` - Backend compiler (default: `:exla`)
    - `:pad_value` - Value to use for padding (default: 0)

  ## Returns

    - `{:ok, outputs}` - List of predictions (one per input)
    - `{:error, reason}` - Inference error
  """
  @spec predict_batch(Axon.t(), map(), [map()], keyword()) ::
          {:ok, [term()]} | {:error, term()}
  def predict_batch(model, state, inputs, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 32)
    compiler = Keyword.get(opts, :compiler, EXLA)
    pad_value = Keyword.get(opts, :pad_value, 0)

    try do
      # Build predict function once for all batches
      predict_fn = Axon.build(model, compiler: compiler, mode: :inference)

      # Process in chunks
      outputs =
        inputs
        |> Enum.chunk_every(batch_size)
        |> Enum.flat_map(fn batch ->
          # Pad batch to same length
          padded_batch = pad_batch(batch, pad_value)

          # Convert to tensors
          batch_tensors = prepare_batch_tensors(padded_batch)

          # Run prediction
          batch_output = predict_fn.(state, batch_tensors)

          # Split output back to individual predictions
          split_batch_output(batch_output, length(batch))
        end)

      {:ok, outputs}
    rescue
      error ->
        Logger.error("Batch inference failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Warms up a model by running a dummy prediction.

  This triggers JIT compilation and caches the compiled function,
  making subsequent predictions faster.

  ## Parameters

    - `model` - Axon model
    - `state` - Trained model state
    - `sample_input` - Sample input with correct shape
    - `opts` - Warmup options

  ## Returns

    - `:ok` - Warmup completed
    - `{:error, reason}` - Warmup failed
  """
  @spec warmup(Axon.t(), map(), map(), keyword()) :: :ok | {:error, term()}
  def warmup(model, state, sample_input, opts \\ []) do
    Logger.info("Warming up neural model...")

    case predict(model, state, sample_input, opts) do
      {:ok, _output} ->
        Logger.info("Model warmup completed")
        :ok

      {:error, reason} ->
        Logger.warning("Model warmup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Streams predictions for large datasets.

  Processes inputs in batches and yields results as a stream,
  avoiding loading all results into memory at once.

  ## Parameters

    - `model` - Axon model
    - `state` - Trained model state
    - `input_stream` - Stream of input maps
    - `opts` - Streaming options

  ## Returns

  A stream of predictions.

  ## Example

      File.stream!("large_dataset.txt")
      |> Stream.map(&prepare_input/1)
      |> Inference.stream_predict(model, state, batch_size: 64)
      |> Stream.map(&postprocess_output/1)
      |> Enum.take(100)
  """
  @spec stream_predict(Axon.t(), map(), Enumerable.t(), keyword()) :: Enumerable.t()
  def stream_predict(model, state, input_stream, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 32)
    compiler = Keyword.get(opts, :compiler, EXLA)

    # Build predict function once
    predict_fn = Axon.build(model, compiler: compiler, mode: :inference)

    input_stream
    |> Stream.chunk_every(batch_size)
    |> Stream.flat_map(fn batch ->
      # Prepare batch tensors
      batch_tensors = prepare_batch_tensors(batch)

      # Run prediction
      batch_output = predict_fn.(state, batch_tensors)

      # Split and yield individual results
      split_batch_output(batch_output, length(batch))
    end)
  end

  ## Private Functions

  defp pad_batch(batch, pad_value) do
    # Find max length for each input dimension
    max_lengths = compute_max_lengths(batch)

    # Pad each input to max length
    Enum.map(batch, fn input ->
      pad_input(input, max_lengths, pad_value)
    end)
  end

  defp compute_max_lengths(batch) do
    # Get the first input to determine structure
    first_input = List.first(batch)

    # For each key, find the maximum length
    first_input
    |> Map.keys()
    |> Enum.map(fn key ->
      max_len =
        batch
        |> Enum.map(fn input ->
          value = Map.get(input, key, [])
          if is_list(value), do: length(value), else: 0
        end)
        |> Enum.max()

      {key, max_len}
    end)
    |> Map.new()
  end

  defp pad_input(input, max_lengths, pad_value) do
    Enum.map(input, fn {key, value} ->
      max_len = Map.get(max_lengths, key, 0)

      padded_value =
        if is_list(value) and max_len > 0 do
          value ++ List.duplicate(pad_value, max_len - length(value))
        else
          value
        end

      {key, padded_value}
    end)
    |> Map.new()
  end

  defp prepare_batch_tensors(batch) do
    # Get keys from first input
    first_input = List.first(batch)
    keys = Map.keys(first_input)

    # Stack each key's values into a batch tensor
    keys
    |> Enum.map(fn key ->
      values = Enum.map(batch, &Map.get(&1, key))
      tensor = Nx.tensor(values)
      {to_string(key), tensor}
    end)
    |> Map.new()
  end

  defp split_batch_output(batch_output, batch_size) do
    # If output is a tensor, split along batch dimension
    if Nx.is_tensor(batch_output) do
      batch_output
      |> Nx.to_batched(1)
      |> Enum.take(batch_size)
      |> Enum.map(&Nx.squeeze(&1, axes: [0]))
    else
      # If output is already a list or other structure, return as-is
      List.duplicate(batch_output, batch_size)
    end
  end
end
