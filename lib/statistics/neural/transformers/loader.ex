defmodule Nasty.Statistics.Neural.Transformers.Loader do
  @moduledoc """
  Loads pre-trained transformer models from HuggingFace Hub or local paths.

  Supports BERT, RoBERTa, DistilBERT, and XLM-RoBERTa models via Bumblebee.
  """

  alias Nasty.Statistics.Neural.Transformers.CacheManager

  @type model_name ::
          :bert_base_cased
          | :bert_base_uncased
          | :roberta_base
          | :xlm_roberta_base
          | :distilbert_base

  @type transformer_model :: %{
          name: model_name(),
          model_info: map(),
          tokenizer: map(),
          config: model_config(),
          serving: pid() | nil
        }

  @type model_config :: %{
          repo: String.t(),
          params: integer(),
          hidden_size: integer(),
          num_layers: integer(),
          languages: [atom()]
        }

  @available_models %{
    bert_base_cased: %{
      repo: "bert-base-cased",
      params: 110_000_000,
      hidden_size: 768,
      num_layers: 12,
      languages: [:en]
    },
    bert_base_uncased: %{
      repo: "bert-base-uncased",
      params: 110_000_000,
      hidden_size: 768,
      num_layers: 12,
      languages: [:en]
    },
    roberta_base: %{
      repo: "roberta-base",
      params: 125_000_000,
      hidden_size: 768,
      num_layers: 12,
      languages: [:en]
    },
    xlm_roberta_base: %{
      repo: "xlm-roberta-base",
      params: 270_000_000,
      hidden_size: 768,
      num_layers: 12,
      languages: [:en, :es, :ca, :multi]
    },
    distilbert_base: %{
      repo: "distilbert-base-uncased",
      params: 66_000_000,
      hidden_size: 768,
      num_layers: 6,
      languages: [:en]
    }
  }

  @doc """
  Loads a pre-trained transformer model by name.

  ## Options

    * `:cache_dir` - Directory to cache downloaded models (default: priv/models/transformers)
    * `:backend` - Nx backend to use (default: EXLA.Backend)
    * `:device` - Device to use (:cpu or :cuda, default: :cpu)
    * `:offline` - If true, only use cached models (default: false)

  ## Examples

      {:ok, model} = Loader.load_model(:roberta_base)
      {:ok, model} = Loader.load_model(:xlm_roberta_base, cache_dir: "/tmp/models")

  """
  @spec load_model(model_name(), keyword()) :: {:ok, transformer_model()} | {:error, term()}
  def load_model(model_name, opts \\ []) do
    with {:ok, config} <- get_model_config(model_name),
         cache_dir <- get_cache_dir(opts),
         {:ok, cached_path} <- maybe_use_cache(model_name, cache_dir, opts),
         {:ok, model_info, tokenizer} <- load_from_hub(config, cached_path, opts) do
      {:ok,
       %{
         name: model_name,
         model_info: model_info,
         tokenizer: tokenizer,
         config: config,
         serving: nil
       }}
    end
  end

  @doc """
  Gets information about a specific model without loading it.

  ## Examples

      {:ok, info} = Loader.get_model_info(:bert_base_cased)
      # => %{params: 110_000_000, hidden_size: 768, ...}

  """
  @spec get_model_info(model_name()) :: {:ok, model_config()} | {:error, :unknown_model}
  def get_model_info(model_name) do
    case Map.fetch(@available_models, model_name) do
      {:ok, config} -> {:ok, config}
      :error -> {:error, :unknown_model}
    end
  end

  @doc """
  Lists all available pre-trained models.

  ## Examples

      Loader.list_models()
      # => [:bert_base_cased, :bert_base_uncased, :roberta_base, ...]

  """
  @spec list_models() :: [model_name()]
  def list_models do
    Map.keys(@available_models)
  end

  @doc """
  Checks if a model is available for a given language.

  ## Examples

      Loader.supports_language?(:xlm_roberta_base, :es)
      # => true

      Loader.supports_language?(:bert_base_cased, :es)
      # => false

  """
  @spec supports_language?(model_name(), atom()) :: boolean()
  def supports_language?(model_name, language) do
    case get_model_info(model_name) do
      {:ok, config} -> language in config.languages or :multi in config.languages
      {:error, _} -> false
    end
  end

  # Private functions

  defp get_model_config(model_name) do
    case Map.fetch(@available_models, model_name) do
      {:ok, config} -> {:ok, config}
      :error -> {:error, {:unknown_model, model_name}}
    end
  end

  defp get_cache_dir(opts) do
    Keyword.get(opts, :cache_dir, default_cache_dir())
  end

  defp default_cache_dir do
    Path.join([Application.app_dir(:nasty, "priv"), "models", "transformers"])
  end

  defp maybe_use_cache(model_name, cache_dir, opts) do
    offline = Keyword.get(opts, :offline, false)

    case CacheManager.get_cached_model(model_name, cache_dir) do
      {:ok, path} when offline ->
        {:ok, path}

      {:ok, path} ->
        # Use cached model but allow re-download if needed
        {:ok, path}

      :not_found when offline ->
        {:error, {:model_not_cached, model_name}}

      :not_found ->
        # Will download from HuggingFace Hub
        {:ok, cache_dir}
    end
  end

  defp load_from_hub(config, cache_dir, opts) do
    backend = Keyword.get(opts, :backend, default_backend())
    device = Keyword.get(opts, :device, :cpu)

    backend_config =
      case device do
        :cuda -> {backend, client: :cuda}
        :cpu -> {backend, client: :host}
        _ -> {backend, client: :host}
      end

    with {:ok, model_info} <- load_model_from_bumblebee(config.repo, cache_dir, backend_config),
         {:ok, tokenizer} <- load_tokenizer_from_bumblebee(config.repo, cache_dir) do
      {:ok, model_info, tokenizer}
    end
  end

  defp load_model_from_bumblebee(repo, cache_dir, _backend_config) do
    {:ok, model_info} = Bumblebee.load_model({:hf, repo}, cache_dir: cache_dir)
    {:ok, model_info}
  rescue
    error ->
      {:error, {:model_load_failed, error}}
  end

  defp load_tokenizer_from_bumblebee(repo, cache_dir) do
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repo}, cache_dir: cache_dir)
    {:ok, tokenizer}
  rescue
    error ->
      {:error, {:tokenizer_load_failed, error}}
  end

  defp default_backend do
    if Code.ensure_loaded?(EXLA) do
      EXLA.Backend
    else
      Nx.BinaryBackend
    end
  end
end
