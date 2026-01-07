defmodule Nasty.Statistics.Neural.Transformers.Config do
  @moduledoc """
  Configuration management for transformer models.

  Provides centralized configuration via:
  - Application config (config.exs)
  - Environment variables
  - Runtime options

  ## Environment Variables

  - `NASTY_MODEL_CACHE_DIR` - Model cache location
  - `NASTY_USE_GPU` - Enable GPU acceleration (true/false)
  - `NASTY_TRANSFORMER_MODEL` - Default transformer model
  - `NASTY_HF_HOME` - HuggingFace cache directory

  ## Application Configuration

      config :nasty, :transformers,
        cache_dir: "priv/models/transformers",
        default_model: :roberta_base,
        backend: :exla,
        device: :cpu,
        offline_mode: false

  """

  @type device :: :cpu | :cuda

  @type backend :: :exla | :nx_binary

  @type config :: %{
          cache_dir: String.t(),
          default_model: atom(),
          backend: backend(),
          device: device(),
          offline_mode: boolean()
        }

  @default_config %{
    cache_dir: "priv/models/transformers",
    default_model: :roberta_base,
    backend: :exla,
    device: :cpu,
    offline_mode: false
  }

  @doc """
  Gets the current transformer configuration.

  Precedence (highest to lowest):
  1. Runtime options passed to functions
  2. Environment variables
  3. Application config
  4. Default config

  ## Examples

      Config.get()
      # => %{cache_dir: "priv/models/transformers", ...}

      Config.get(:cache_dir)
      # => "priv/models/transformers"
  """
  @spec get() :: config()
  def get do
    @default_config
    |> merge_app_config()
    |> merge_env_config()
  end

  @spec get(atom()) :: term()
  def get(key) do
    Map.get(get(), key)
  end

  @doc """
  Gets configuration with runtime options merged.

  ## Examples

      Config.with_opts(cache_dir: "/tmp/models", device: :cuda)
      # => %{cache_dir: "/tmp/models", device: :cuda, ...}
  """
  @spec with_opts(keyword()) :: config()
  def with_opts(opts) do
    get()
    |> Map.merge(Enum.into(opts, %{}))
  end

  @doc """
  Gets the model cache directory.

  Checks in order:
  1. NASTY_MODEL_CACHE_DIR env var
  2. NASTY_HF_HOME env var (for compatibility)
  3. Application config
  4. Default: priv/models/transformers

  ## Examples

      Config.cache_dir()
      # => "/home/user/.cache/nasty/transformers"
  """
  @spec cache_dir() :: String.t()
  def cache_dir do
    cond do
      env_cache = System.get_env("NASTY_MODEL_CACHE_DIR") ->
        env_cache

      hf_home = System.get_env("NASTY_HF_HOME") ->
        Path.join(hf_home, "transformers")

      true ->
        get(:cache_dir)
    end
  end

  @doc """
  Gets the default transformer model.

  ## Examples

      Config.default_model()
      # => :roberta_base
  """
  @spec default_model() :: atom()
  def default_model do
    case System.get_env("NASTY_TRANSFORMER_MODEL") do
      nil ->
        get(:default_model)

      model_str ->
        String.to_atom(model_str)
    end
  end

  @doc """
  Gets the computation device (CPU or CUDA).

  ## Examples

      Config.device()
      # => :cpu
  """
  @spec device() :: device()
  def device do
    case System.get_env("NASTY_USE_GPU") do
      nil ->
        get(:device)

      "true" ->
        :cuda

      "false" ->
        :cpu

      _ ->
        get(:device)
    end
  end

  @doc """
  Gets the numerical backend.

  ## Examples

      Config.backend()
      # => :exla
  """
  @spec backend() :: backend()
  def backend do
    get(:backend)
  end

  @doc """
  Checks if offline mode is enabled.

  In offline mode, only cached models are used and no network requests
  are made to HuggingFace Hub.

  ## Examples

      Config.offline_mode?()
      # => false
  """
  @spec offline_mode?() :: boolean()
  def offline_mode? do
    case System.get_env("NASTY_OFFLINE_MODE") do
      nil ->
        get(:offline_mode)

      "true" ->
        true

      "false" ->
        false

      _ ->
        get(:offline_mode)
    end
  end

  @doc """
  Validates configuration and provides helpful error messages.

  ## Examples

      Config.validate!()
      # => :ok (or raises if invalid)
  """
  @spec validate!() :: :ok
  def validate! do
    config = get()

    # Check cache directory is writable
    cache_dir = Map.get(config, :cache_dir)

    unless File.exists?(cache_dir) do
      File.mkdir_p!(cache_dir)
    end

    unless File.dir?(cache_dir) do
      raise "Cache directory is not a directory: #{cache_dir}"
    end

    # Check device availability
    device = Map.get(config, :device)

    if device == :cuda and not cuda_available?() do
      IO.warn("CUDA device requested but not available, falling back to CPU")
    end

    :ok
  end

  @doc """
  Returns configuration as keyword list for passing to functions.

  ## Examples

      Config.to_keyword()
      # => [cache_dir: "...", default_model: :roberta_base, ...]
  """
  @spec to_keyword() :: keyword()
  def to_keyword do
    get() |> Map.to_list()
  end

  # Private functions

  defp merge_app_config(config) do
    app_config = Application.get_env(:nasty, :transformers, %{})
    Map.merge(config, app_config)
  end

  defp merge_env_config(config) do
    env_config = %{
      cache_dir: cache_dir_from_env(config.cache_dir),
      default_model: default_model_from_env(config.default_model),
      device: device_from_env(config.device),
      offline_mode: offline_mode_from_env(config.offline_mode)
    }

    Map.merge(config, env_config)
  end

  defp cache_dir_from_env(default) do
    System.get_env("NASTY_MODEL_CACHE_DIR") ||
      (System.get_env("NASTY_HF_HOME") &&
         Path.join(System.get_env("NASTY_HF_HOME"), "transformers")) ||
      default
  end

  defp default_model_from_env(default) do
    case System.get_env("NASTY_TRANSFORMER_MODEL") do
      nil -> default
      model_str -> String.to_atom(model_str)
    end
  end

  defp device_from_env(default) do
    case System.get_env("NASTY_USE_GPU") do
      "true" -> :cuda
      "false" -> :cpu
      _ -> default
    end
  end

  defp offline_mode_from_env(default) do
    case System.get_env("NASTY_OFFLINE_MODE") do
      "true" -> true
      "false" -> false
      _ -> default
    end
  end

  defp cuda_available? do
    # Check if CUDA is available
    # This is a simple check - in production would check EXLA/CUDA properly
    System.find_executable("nvidia-smi") != nil
  end
end
