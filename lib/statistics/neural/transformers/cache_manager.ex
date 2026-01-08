defmodule Nasty.Statistics.Neural.Transformers.CacheManager do
  @moduledoc """
  Manages caching of downloaded transformer models.

  Handles model versioning, disk space management, and cache lookup
  to avoid re-downloading large models from HuggingFace Hub.
  """

  require Logger

  @type cache_entry :: %{
          model_name: atom(),
          path: String.t(),
          size_bytes: integer(),
          downloaded_at: DateTime.t(),
          version: String.t()
        }

  @doc """
  Gets the cached model path if it exists.

  ## Examples

      CacheManager.get_cached_model(:roberta_base, "/path/to/cache")
      # => {:ok, "/path/to/cache/roberta-base"}
      # or :not_found

  """
  @spec get_cached_model(atom(), String.t()) :: {:ok, String.t()} | :not_found
  def get_cached_model(model_name, cache_dir) do
    model_path = build_model_path(model_name, cache_dir)

    if cached?(model_path) do
      {:ok, cache_dir}
    else
      :not_found
    end
  end

  @doc """
  Records a model in the cache registry.

  ## Examples

      CacheManager.register_cached_model(:roberta_base, "/path/to/cache")

  """
  @spec register_cached_model(atom(), String.t(), keyword()) :: :ok
  def register_cached_model(model_name, cache_dir, opts \\ []) do
    model_path = build_model_path(model_name, cache_dir)
    size_bytes = calculate_directory_size(cache_dir)
    version = Keyword.get(opts, :version, "unknown")

    entry = %{
      model_name: model_name,
      path: model_path,
      size_bytes: size_bytes,
      downloaded_at: DateTime.utc_now(),
      version: version
    }

    write_cache_entry(cache_dir, model_name, entry)
    Logger.info("Cached model #{model_name} (#{format_bytes(size_bytes)})")
    :ok
  end

  @doc """
  Clears cached models.

  ## Examples

      # Clear specific model
      CacheManager.clear_cache(:roberta_base, cache_dir)

      # Clear all models
      CacheManager.clear_cache(:all, cache_dir)

  """
  @spec clear_cache(atom() | :all, String.t()) :: :ok | {:error, term()}
  def clear_cache(:all, cache_dir) do
    case File.rm_rf(cache_dir) do
      {:ok, _} ->
        Logger.info("Cleared all cached models from #{cache_dir}")
        :ok

      {:error, reason, _} ->
        {:error, {:clear_failed, reason}}
    end
  end

  def clear_cache(model_name, cache_dir) do
    model_path = build_model_path(model_name, cache_dir)

    case File.rm_rf(model_path) do
      {:ok, _} ->
        remove_cache_entry(cache_dir, model_name)
        Logger.info("Cleared cached model #{model_name}")
        :ok

      {:error, reason, _} ->
        {:error, {:clear_failed, reason}}
    end
  end

  @doc """
  Calculates total cache size in bytes.

  ## Examples

      {:ok, size} = CacheManager.cache_size(cache_dir)
      # => {:ok, 1_234_567_890}

  """
  @spec cache_size(String.t()) :: {:ok, integer()} | {:error, term()}
  def cache_size(cache_dir) do
    if File.exists?(cache_dir) do
      size = calculate_directory_size(cache_dir)
      {:ok, size}
    else
      {:ok, 0}
    end
  end

  @doc """
  Lists all cached models with their metadata.

  ## Examples

      CacheManager.list_cached_models(cache_dir)
      # => [%{model_name: :roberta_base, size_bytes: 500_000_000, ...}, ...]

  """
  @spec list_cached_models(String.t()) :: [cache_entry()]
  def list_cached_models(cache_dir) do
    cache_index = cache_index_path(cache_dir)

    if File.exists?(cache_index) do
      case read_cache_index(cache_dir) do
        {:ok, entries} -> entries
        {:error, _} -> []
      end
    else
      []
    end
  end

  # Private functions

  defp build_model_path(model_name, cache_dir) do
    # Convert atom to repo format: :roberta_base -> "roberta-base"
    repo_name = model_name_to_repo(model_name)
    Path.join(cache_dir, repo_name)
  end

  defp model_name_to_repo(model_name) do
    model_name
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  defp cached?(model_path) do
    File.exists?(model_path) and has_required_files?(model_path)
  end

  defp has_required_files?(model_path) do
    # Check for essential model files (Bumblebee downloads these)
    required_files = [
      "config.json",
      "tokenizer.json"
    ]

    Enum.all?(required_files, fn file ->
      File.exists?(Path.join(model_path, file))
    end)
  end

  defp calculate_directory_size(dir) do
    if File.exists?(dir) do
      dir
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&File.stat!/1)
      |> Enum.map(& &1.size)
      |> Enum.sum()
    else
      0
    end
  end

  defp cache_index_path(cache_dir) do
    Path.join(cache_dir, ".cache_index.json")
  end

  defp read_cache_index(cache_dir) do
    cache_index = cache_index_path(cache_dir)

    with {:ok, contents} <- File.read(cache_index) do
      # json.decode returns the data directly
      data = :json.decode(contents)
      # Data is a map with "entries" key
      entries_data = Map.get(data, "entries", [])

      entries =
        Enum.map(entries_data, fn entry ->
          %{
            model_name: String.to_atom(entry["model_name"]),
            path: entry["path"],
            size_bytes: entry["size_bytes"],
            downloaded_at: DateTime.from_iso8601(entry["downloaded_at"]) |> elem(1),
            version: entry["version"]
          }
        end)

      {:ok, entries}
    end
  rescue
    _ -> {:error, :decode_failed}
  end

  defp write_cache_entry(cache_dir, model_name, entry) do
    cache_index = cache_index_path(cache_dir)
    File.mkdir_p!(cache_dir)

    # Use a lock file to prevent concurrent writes
    lock_file = cache_index <> ".lock"

    # Acquire lock with retry
    acquire_lock(lock_file)

    try do
      existing_entries =
        case read_cache_index(cache_dir) do
          {:ok, entries} -> entries
          {:error, _} -> []
        end

      # Remove old entry for this model if exists
      existing_entries = Enum.reject(existing_entries, &(&1.model_name == model_name))

      # Add new entry
      updated_entries = [entry | existing_entries]

      # Serialize with ISO8601 timestamps
      serializable_entries =
        Enum.map(updated_entries, fn e ->
          %{
            "model_name" => Atom.to_string(e.model_name),
            "path" => e.path,
            "size_bytes" => e.size_bytes,
            "downloaded_at" => DateTime.to_iso8601(e.downloaded_at),
            "version" => e.version
          }
        end)

      data = %{"entries" => serializable_entries}
      json = :json.encode(data)
      File.write!(cache_index, IO.iodata_to_binary(json))
    after
      release_lock(lock_file)
    end
  end

  defp remove_cache_entry(cache_dir, model_name) do
    cache_index = cache_index_path(cache_dir)

    case read_cache_index(cache_dir) do
      {:ok, entries} ->
        updated_entries = Enum.reject(entries, &(&1.model_name == model_name))

        serializable_entries =
          Enum.map(updated_entries, fn e ->
            %{
              "model_name" => Atom.to_string(e.model_name),
              "path" => e.path,
              "size_bytes" => e.size_bytes,
              "downloaded_at" => DateTime.to_iso8601(e.downloaded_at),
              "version" => e.version
            }
          end)

        data = %{"entries" => serializable_entries}
        json = :json.encode(data)
        File.write!(cache_index, IO.iodata_to_binary(json))

      {:error, _} ->
        :ok
    end
  end

  defp acquire_lock(lock_file, retries \\ 50) do
    case File.open(lock_file, [:write, :exclusive]) do
      {:ok, file} ->
        File.close(file)
        :ok

      {:error, :eexist} when retries > 0 ->
        # Lock file exists, wait and retry
        Process.sleep(10)
        acquire_lock(lock_file, retries - 1)

      {:error, :eexist} ->
        # Max retries reached, force remove stale lock
        File.rm(lock_file)
        acquire_lock(lock_file, 5)
    end
  end

  defp release_lock(lock_file) do
    File.rm(lock_file)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
end
