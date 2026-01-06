defmodule Nasty.Statistics.ModelRegistry do
  @moduledoc """
  A registry for managing and caching statistical models.

  The ModelRegistry is a GenServer that maintains an ETS table for efficient
  model lookup and caching. Models are stored with their metadata and can be
  retrieved by language, task type, and version.

  ## Usage

      # Register a model
      ModelRegistry.register(:en, :pos_tagging, "v1", model, metadata)

      # Lookup a model
      {:ok, model, metadata} = ModelRegistry.lookup(:en, :pos_tagging, "v1")

      # List all registered models
      models = ModelRegistry.list()

      # Clear all models
      ModelRegistry.clear()

  ## Model Metadata

  Metadata is a map that can include:
  - `:version` - Model version string
  - `:model_type` - Type of model (e.g., "hmm_pos_tagger")
  - `:trained_on` - Corpus used for training
  - `:training_date` - Date of training
  - `:training_size` - Number of training samples
  - `:test_accuracy` - Accuracy on test set
  - `:test_f1` - F1 score on test set
  - `:vocab_size` - Vocabulary size
  - `:num_tags` - Number of tags
  - `:file_size_bytes` - Model file size
  - `:sha256` - SHA256 checksum
  - `:hyperparameters` - Map of hyperparameters
  """

  use GenServer
  require Logger

  @table_name :nasty_model_registry
  @type language :: atom()
  @type task :: atom()
  @type version :: String.t()
  @type model :: term()
  @type metadata :: map()
  @type model_key :: {language, task, version}

  ## Client API

  @doc """
  Starts the ModelRegistry GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a model with its metadata.

  ## Parameters
  - `language` - Language code (e.g., `:en`, `:es`)
  - `task` - Task type (e.g., `:pos_tagging`, `:ner`)
  - `version` - Model version string (e.g., "v1", "v2")
  - `model` - The model struct or data
  - `metadata` - Map of metadata about the model

  ## Examples

      iex> ModelRegistry.register(:en, :pos_tagging, "v1", model, %{
      ...>   test_accuracy: 0.947,
      ...>   trained_on: "UD_English-EWT v2.13"
      ...> })
      :ok
  """
  @spec register(language, task, version, model, metadata) :: :ok
  def register(language, task, version, model, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register, language, task, version, model, metadata})
  end

  @doc """
  Looks up a model by language, task, and version.

  Returns `{:ok, model, metadata}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> ModelRegistry.lookup(:en, :pos_tagging, "v1")
      {:ok, model, %{test_accuracy: 0.947}}

      iex> ModelRegistry.lookup(:en, :ner, "v1")
      {:error, :not_found}
  """
  @spec lookup(language, task, version) :: {:ok, model, metadata} | {:error, :not_found}
  def lookup(language, task, version) do
    GenServer.call(__MODULE__, {:lookup, language, task, version})
  end

  @doc """
  Lists all registered models.

  Returns a list of tuples: `{language, task, version, metadata}`.
  The actual model data is not included in the list to keep it lightweight.

  ## Examples

      iex> ModelRegistry.list()
      [
        {:en, :pos_tagging, "v1", %{test_accuracy: 0.947}},
        {:en, :pos_tagging, "v2", %{test_accuracy: 0.952}}
      ]
  """
  @spec list() :: [{language, task, version, metadata}]
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Lists models for a specific language and task.

  Returns a list of tuples: `{version, metadata}`.

  ## Examples

      iex> ModelRegistry.list_versions(:en, :pos_tagging)
      [
        {"v1", %{test_accuracy: 0.947}},
        {"v2", %{test_accuracy: 0.952}}
      ]
  """
  @spec list_versions(language, task) :: [{version, metadata}]
  def list_versions(language, task) do
    GenServer.call(__MODULE__, {:list_versions, language, task})
  end

  @doc """
  Removes a specific model from the registry.

  ## Examples

      iex> ModelRegistry.unregister(:en, :pos_tagging, "v1")
      :ok
  """
  @spec unregister(language, task, version) :: :ok
  def unregister(language, task, version) do
    GenServer.call(__MODULE__, {:unregister, language, task, version})
  end

  @doc """
  Clears all models from the registry.

  ## Examples

      iex> ModelRegistry.clear()
      :ok
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :protected, :named_table])
    Logger.info("ModelRegistry started")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, language, task, version, model, metadata}, _from, state) do
    key = {language, task, version}
    value = {model, metadata}
    :ets.insert(state.table, {key, value})

    Logger.debug("Registered model: language=#{language}, task=#{task}, version=#{version}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:lookup, language, task, version}, _from, state) do
    key = {language, task, version}

    result =
      case :ets.lookup(state.table, key) do
        [{^key, {model, metadata}}] -> {:ok, model, metadata}
        [] -> {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    models =
      :ets.tab2list(state.table)
      |> Enum.map(fn {{language, task, version}, {_model, metadata}} ->
        {language, task, version, metadata}
      end)
      |> Enum.sort()

    {:reply, models, state}
  end

  @impl true
  def handle_call({:list_versions, language, task}, _from, state) do
    versions =
      :ets.tab2list(state.table)
      |> Enum.filter(fn {{lang, tsk, _version}, _value} ->
        lang == language and tsk == task
      end)
      |> Enum.map(fn {{_lang, _tsk, version}, {_model, metadata}} ->
        {version, metadata}
      end)
      |> Enum.sort()

    {:reply, versions, state}
  end

  @impl true
  def handle_call({:unregister, language, task, version}, _from, state) do
    key = {language, task, version}
    :ets.delete(state.table, key)

    Logger.debug("Unregistered model: language=#{language}, task=#{task}, version=#{version}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    Logger.debug("Cleared all models from registry")
    {:reply, :ok, state}
  end
end
