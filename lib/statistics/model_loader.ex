defmodule Nasty.Statistics.ModelLoader do
  @moduledoc """
  Loads statistical models from the filesystem and registers them.

  ModelLoader discovers models in the `priv/models/` directory and loads them
  on demand. Models are organized by language and task:

      priv/models/
        en/
          pos_hmm_v1.model
          pos_hmm_v1.meta.json
          pos_hmm_v2.model
          pos_hmm_v2.meta.json

  Model files use the naming convention: `{task}_{model_type}_{version}.model`
  Metadata files use: `{task}_{model_type}_{version}.meta.json`

  ## Usage

      # Load a specific model
      {:ok, model} = ModelLoader.load_model(:en, :pos_tagging, "v1")

      # Load latest version
      {:ok, model} = ModelLoader.load_latest(:en, :pos_tagging)

      # Discover all available models
      models = ModelLoader.discover_models()
  """

  alias Nasty.Statistics.{ModelRegistry, POSTagging.HMMTagger}
  require Logger

  @models_dir "priv/models"

  @doc """
  Discovers all available models in the models directory.

  Returns a list of tuples: `{language, task, version, model_path, metadata_path}`.

  ## Examples

      iex> ModelLoader.discover_models()
      [
        {:en, :pos_tagging, "v1", "priv/models/en/pos_hmm_v1.model", "priv/models/en/pos_hmm_v1.meta.json"}
      ]
  """
  @spec discover_models() :: [
          {atom(), atom(), String.t(), String.t(), String.t() | nil}
        ]
  def discover_models do
    models_path = Path.expand(@models_dir)

    if File.exists?(models_path) do
      File.ls!(models_path)
      |> Enum.flat_map(fn language_dir ->
        language_path = Path.join(models_path, language_dir)

        if File.dir?(language_path) do
          discover_models_in_language_dir(language_dir, language_path)
        else
          []
        end
      end)
    else
      []
    end
  end

  @doc """
  Loads a model from the filesystem and registers it in the ModelRegistry.

  Returns `{:ok, model}` if successful, `{:error, reason}` otherwise.

  ## Examples

      iex> ModelLoader.load_model(:en, :pos_tagging, "v1")
      {:ok, %Nasty.Statistics.POSTagging.HMMTagger{...}}

      iex> ModelLoader.load_model(:en, :nonexistent, "v1")
      {:error, :not_found}
  """
  @spec load_model(atom(), atom(), String.t()) :: {:ok, Model.t()} | {:error, term()}
  def load_model(language, task, version) do
    # Check if already loaded in registry
    case ModelRegistry.lookup(language, task, version) do
      {:ok, model, _metadata} ->
        {:ok, model}

      {:error, :not_found} ->
        # Try to load from filesystem
        load_and_register(language, task, version)
    end
  end

  @doc """
  Loads the latest version of a model for the given language and task.

  Returns `{:ok, model}` if successful, `{:error, reason}` otherwise.

  ## Examples

      iex> ModelLoader.load_latest(:en, :pos_tagging)
      {:ok, %Nasty.Statistics.POSTagging.HMMTagger{...}}
  """
  @spec load_latest(atom(), atom()) :: {:ok, Model.t()} | {:error, term()}
  def load_latest(language, task) do
    # Get all versions for this language and task
    versions = ModelRegistry.list_versions(language, task)

    case versions do
      [] ->
        # Not in registry, try to discover and load
        case find_latest_version(language, task) do
          {:ok, version} -> load_model(language, task, version)
          {:error, _} = error -> error
        end

      versions ->
        # Get the latest version from registry
        {latest_version, _metadata} = List.last(versions)
        load_model(language, task, latest_version)
    end
  end

  @doc """
  Gets the path to a model file.

  Returns `{:ok, path}` if the model file exists, `{:error, :not_found}` otherwise.

  ## Examples

      iex> ModelLoader.get_model_path(:en, :pos_tagging, "v1")
      {:ok, "/path/to/priv/models/en/pos_hmm_v1.model"}
  """
  @spec get_model_path(atom(), atom(), String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def get_model_path(language, task, version) do
    discovered = discover_models()

    case Enum.find(discovered, fn {lang, tsk, ver, _path, _meta} ->
           lang == language and tsk == task and ver == version
         end) do
      {_lang, _task, _version, path, _meta_path} -> {:ok, Path.expand(path)}
      nil -> {:error, :not_found}
    end
  end

  ## Private Functions

  defp discover_models_in_language_dir(language_dir, language_path) do
    language = String.to_atom(language_dir)

    File.ls!(language_path)
    |> Enum.filter(&String.ends_with?(&1, ".model"))
    |> Enum.map(fn model_file ->
      relative_model_path = Path.join([@models_dir, language_dir, model_file])

      # Parse filename: {task}_{model_type}_{version}.model
      case parse_model_filename(model_file) do
        {:ok, task, version} ->
          # Check for metadata file
          meta_file = String.replace(model_file, ".model", ".meta.json")
          meta_path = Path.join(language_path, meta_file)
          relative_meta_path = Path.join([@models_dir, language_dir, meta_file])

          meta =
            if File.exists?(meta_path) do
              relative_meta_path
            else
              nil
            end

          {language, task, version, relative_model_path, meta}

        {:error, _reason} ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_model_filename(filename) do
    # Expected format: {task}_{model_type}_{version}.model
    # Examples: pos_hmm_v1.model, ner_crf_v2.model
    case String.split(filename, "_") do
      [task_str, _model_type, version_with_ext] ->
        version = String.replace(version_with_ext, ".model", "")
        task = task_to_atom(task_str)
        {:ok, task, version}

      _ ->
        {:error, :invalid_filename}
    end
  end

  defp task_to_atom("pos"), do: :pos_tagging
  defp task_to_atom("ner"), do: :ner
  defp task_to_atom("parsing"), do: :parsing
  defp task_to_atom(other), do: String.to_atom(other)

  defp load_and_register(language, task, version) do
    discovered = discover_models()

    case Enum.find(discovered, fn {lang, tsk, ver, _path, _meta} ->
           lang == language and tsk == task and ver == version
         end) do
      {_lang, _task, _version, model_path, meta_path} ->
        load_model_from_path(language, task, version, model_path, meta_path)

      nil ->
        {:error, :not_found}
    end
  end

  defp load_model_from_path(language, task, version, model_path, meta_path) do
    expanded_path = Path.expand(model_path)

    # Determine model loader based on task
    loader_module =
      case task do
        :pos_tagging -> HMMTagger
        _ -> nil
      end

    do_load_model_from_path(loader_module, language, task, version, expanded_path, meta_path)
  end

  defp do_load_model_from_path(nil, _language, task, _version, _expanded_path, _meta_path) do
    {:error, {:unsupported_task, task}}
  end

  defp do_load_model_from_path(loader_module, language, task, version, expanded_path, meta_path) do
    case loader_module.load(expanded_path) do
      {:ok, model} ->
        metadata = load_metadata(meta_path)

        ModelRegistry.register(language, task, version, model, metadata)

        Logger.info("Loaded model: language=#{language}, task=#{task}, version=#{version}")

        {:ok, model}

      {:error, _reason} = error ->
        Logger.error(
          "Failed to load model: language=#{language}, task=#{task}, version=#{version}, path=#{expanded_path}"
        )

        error
    end
  end

  defp load_metadata(meta_path) do
    expanded_path = Path.expand(meta_path)

    if File.exists?(expanded_path) do
      case File.read(expanded_path) do
        {:ok, content} ->
          case :json.decode(content) do
            {:ok, metadata} when is_map(metadata) ->
              atomize_keys(metadata)

            _ ->
              Logger.warning("Failed to parse metadata file: #{expanded_path}")
              %{}
          end

        {:error, reason} ->
          Logger.warning("Failed to read metadata file: #{expanded_path}, reason: #{reason}")
          %{}
      end
    else
      %{}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), atomize_keys(value)}
      {key, value} -> {key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(value), do: value

  defp find_latest_version(language, task) do
    discovered = discover_models()

    versions =
      discovered
      |> Enum.filter(fn {lang, tsk, _ver, _path, _meta} ->
        lang == language and tsk == task
      end)
      |> Enum.map(fn {_lang, _task, version, _path, _meta} -> version end)
      |> Enum.sort()

    case List.last(versions) do
      nil -> {:error, :not_found}
      version -> {:ok, version}
    end
  end
end
