defmodule Nasty.Statistics.Neural.Model do
  @moduledoc """
  Behaviour for neural network models using Axon.

  Extends `Nasty.Statistics.Model` with neural-specific callbacks for
  architecture definition, tensor handling, and efficient inference.

  ## Model Lifecycle

  1. **Architecture Definition**: Define the Axon model structure
  2. **Training**: Train on labeled data with backpropagation
  3. **Serialization**: Save model parameters and metadata
  4. **Loading**: Restore model from disk
  5. **Inference**: Predict on new data with efficient batching

  ## Example

      defmodule MyNeuralTagger do
        @behaviour Nasty.Statistics.Neural.Model

        @impl true
        def model_architecture(opts) do
          vocab_size = Keyword.fetch!(opts, :vocab_size)
          num_tags = Keyword.fetch!(opts, :num_tags)
          
          Axon.input("tokens", shape: {nil, nil})
          |> Axon.embedding(vocab_size, 128)
          |> Axon.lstm(256, return_sequences: true)
          |> Axon.dense(num_tags)
        end

        @impl true
        def input_shape(_model), do: {nil, nil}

        @impl true
        def output_shape(model), do: {nil, nil, model.num_tags}
      end

  ## Integration with Existing Models

  Neural models implement the standard `Nasty.Statistics.Model` behaviour,
  so they can be used interchangeably with HMM and other statistical models.
  """

  alias Nasty.Statistics.Model

  @doc """
  Returns the Axon model architecture.

  ## Parameters

    - `opts` - Architecture options (vocab_size, num_tags, hidden_size, etc.)

  ## Returns

  An `%Axon{}` struct defining the model architecture.

  ## Examples

      iex> model_architecture(vocab_size: 10000, num_tags: 17)
      %Axon{...}
  """
  @callback model_architecture(opts :: keyword()) :: Axon.t()

  @doc """
  Returns the expected input shape for the model.

  Shapes use `nil` for dynamic dimensions (batch size, sequence length).

  ## Examples

      iex> input_shape(model)
      {nil, nil}  # {batch_size, seq_length}

      iex> input_shape(model)
      {nil, nil, 50}  # {batch_size, seq_length, char_length}
  """
  @callback input_shape(model :: struct()) :: tuple()

  @doc """
  Returns the expected output shape for the model.

  ## Examples

      iex> output_shape(model)
      {nil, nil, 17}  # {batch_size, seq_length, num_tags}
  """
  @callback output_shape(model :: struct()) :: tuple()

  @doc """
  Prepares input data for model inference.

  Converts raw input (tokens, text, etc.) into tensors suitable for
  the neural network. Handles padding, vocabulary mapping, and batching.

  ## Parameters

    - `model` - The trained model
    - `input` - Raw input data (list of words, tokens, etc.)
    - `opts` - Preprocessing options

  ## Returns

    - `{:ok, tensors}` - Map of input tensors keyed by input name
    - `{:error, reason}` - Preprocessing error

  ## Examples

      iex> prepare_input(model, ["The", "cat", "sat"], [])
      {:ok, %{"tokens" => #Nx.Tensor<s64[1][3]>}}
  """
  @callback prepare_input(model :: struct(), input :: term(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Post-processes model output into predictions.

  Converts raw model output tensors (logits, probabilities) into
  structured predictions (tags, labels, etc.).

  ## Parameters

    - `model` - The trained model
    - `output` - Raw model output (tensor)
    - `input` - Original input (for alignment)
    - `opts` - Post-processing options

  ## Returns

    - `{:ok, predictions}` - Structured predictions
    - `{:error, reason}` - Post-processing error

  ## Examples

      iex> postprocess_output(model, logits_tensor, ["The", "cat"], [])
      {:ok, [:det, :noun]}
  """
  @callback postprocess_output(
              model :: struct(),
              output :: Nx.Tensor.t(),
              input :: term(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @optional_callbacks [prepare_input: 3, postprocess_output: 4]

  @doc """
  Validates that a module correctly implements the Neural.Model behaviour.

  ## Examples

      iex> Nasty.Statistics.Neural.Model.validate_implementation!(MyNeuralTagger)
      :ok
  """
  @spec validate_implementation!(module()) :: :ok | no_return()
  def validate_implementation!(module) do
    # Check it implements the base Model behaviour
    Model.validate_implementation!(module)

    # Check neural-specific callbacks
    required_callbacks = [
      {:model_architecture, 1},
      {:input_shape, 1},
      {:output_shape, 1}
    ]

    behaviours = module.__info__(:attributes)[:behaviour] || []

    unless __MODULE__ in behaviours do
      raise ArgumentError,
            "Module #{inspect(module)} does not implement Nasty.Statistics.Neural.Model"
    end

    missing =
      Enum.filter(required_callbacks, fn {name, arity} ->
        not function_exported?(module, name, arity)
      end)

    if missing != [] do
      raise ArgumentError,
            "Module #{inspect(module)} is missing required callbacks: #{inspect(missing)}"
    end

    :ok
  end
end
