defmodule Nasty.Statistics.Model do
  @moduledoc """
  Behaviour for statistical models in Nasty.

  All statistical models (HMM, PCFG, CRF, etc.) implement this behaviour,
  providing a consistent interface for training, prediction, and persistence.

  ## Model Lifecycle

      # Training
      model = MyModel.new(opts)
      model = MyModel.train(model, training_data)
      :ok = MyModel.save(model, "path/to/model.bin")

      # Loading and prediction
      {:ok, model} = MyModel.load("path/to/model.bin")
      predictions = MyModel.predict(model, input_data)

  ## Callbacks

  - `train/2` - Train the model on annotated data
  - `predict/2` - Make predictions on new data
  - `save/2` - Serialize model to disk
  - `load/1` - Deserialize model from disk
  - `metadata/1` - Get model metadata (version, accuracy, etc.)
  """

  @type model :: struct()
  @type training_data :: list()
  @type input_data :: term()
  @type predictions :: term()
  @type options :: keyword()
  @type metadata :: %{
          required(:version) => String.t(),
          required(:trained_at) => DateTime.t(),
          optional(:accuracy) => float(),
          optional(:training_size) => pos_integer(),
          optional(atom()) => term()
        }

  @doc """
  Train the model on annotated training data.

  ## Parameters

    - `model` - The model struct to train
    - `training_data` - Annotated training examples
    - `opts` - Training options (learning rate, iterations, etc.)

  ## Returns

    - `{:ok, trained_model}` - Successfully trained model
    - `{:error, reason}` - Training failed
  """
  @callback train(model, training_data, options) :: {:ok, model} | {:error, term()}

  @doc """
  Make predictions on new input data.

  ## Parameters

    - `model` - Trained model
    - `input_data` - Data to predict on
    - `opts` - Prediction options

  ## Returns

    - `{:ok, predictions}` - Predicted labels/structures
    - `{:error, reason}` - Prediction failed
  """
  @callback predict(model, input_data, options) :: {:ok, predictions} | {:error, term()}

  @doc """
  Serialize and save the model to disk.

  ## Parameters

    - `model` - Model to save
    - `path` - File path for saving

  ## Returns

    - `:ok` - Successfully saved
    - `{:error, reason}` - Save failed
  """
  @callback save(model, Path.t()) :: :ok | {:error, term()}

  @doc """
  Load a serialized model from disk.

  ## Parameters

    - `path` - File path to load from

  ## Returns

    - `{:ok, model}` - Successfully loaded model
    - `{:error, reason}` - Load failed
  """
  @callback load(Path.t()) :: {:ok, model} | {:error, term()}

  @doc """
  Get model metadata (version, training info, etc.).

  ## Parameters

    - `model` - The model

  ## Returns

    - Metadata map with version, accuracy, training time, etc.
  """
  @callback metadata(model) :: metadata

  @doc """
  Helper function to serialize a model to binary format.

  Uses Erlang's term_to_binary for efficient serialization.
  Includes versioning and compression.
  """
  @spec serialize(model, metadata) :: binary()
  def serialize(model, metadata) do
    data = %{
      version: "1.0",
      metadata: metadata,
      model: model
    }

    :erlang.term_to_binary(data, compressed: 6)
  end

  @doc """
  Helper function to deserialize a model from binary format.

  Validates version compatibility and extracts model data.
  """
  @spec deserialize(binary()) :: {:ok, model, metadata} | {:error, term()}
  def deserialize(binary) when is_binary(binary) do
    try do
      case :erlang.binary_to_term(binary, [:safe]) do
        %{version: version, metadata: metadata, model: model} ->
          if compatible_version?(version) do
            {:ok, model, metadata}
          else
            {:error, {:incompatible_version, version}}
          end

        _ ->
          {:error, :invalid_format}
      end
    rescue
      e -> {:error, {:deserialization_failed, e}}
    end
  end

  defp compatible_version?("1.0"), do: true
  defp compatible_version?(_), do: false
end
