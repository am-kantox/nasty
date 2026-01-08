defmodule Mix.Tasks.Nasty.Models.Download do
  @moduledoc """
  Downloads a pre-trained transformer model from HuggingFace.

  ## Usage

      mix nasty.models.download MODEL_NAME [OPTIONS]

  ## Arguments

    * MODEL_NAME - Name of the model to download (e.g., roberta_base, bert_base_cased)

  ## Options

    * `--cache-dir` - Directory to cache models (default: priv/models/transformers)
    * `--offline` - Use only cached models, don't download (default: false)

  ## Examples

      # Download RoBERTa base model
      mix nasty.models.download roberta_base

      # Download BERT to custom directory
      mix nasty.models.download bert_base_cased --cache-dir=/tmp/models

      # Download XLM-RoBERTa for multilingual support
      mix nasty.models.download xlm_roberta_base

  ## Available Models

    * bert_base_cased - BERT base (110M params, English)
    * bert_base_uncased - BERT base uncased (110M params, English)
    * roberta_base - RoBERTa base (125M params, English, recommended)
    * xlm_roberta_base - XLM-RoBERTa (270M params, 100 languages)
    * distilbert_base - DistilBERT (66M params, English, fast)

  """

  use Mix.Task
  require Logger

  alias Nasty.Statistics.Neural.Transformers.{CacheManager, Config, Loader}

  @shortdoc "Downloads a pre-trained transformer model"

  @impl Mix.Task
  def run(args) do
    # Start the application to ensure all dependencies are loaded
    Mix.Task.run("app.start")

    {opts, [model_name | _rest], _} =
      OptionParser.parse(args,
        strict: [cache_dir: :string, offline: :boolean],
        aliases: [c: :cache_dir, o: :offline]
      )

    # Convert string model name to atom
    model_atom = String.to_atom(model_name)

    # Get cache directory
    cache_dir = Keyword.get(opts, :cache_dir, Config.cache_dir())
    offline = Keyword.get(opts, :offline, false)

    Mix.shell().info("Downloading transformer model: #{model_name}")
    Mix.shell().info("Cache directory: #{cache_dir}")

    # Check if model is already cached
    case CacheManager.get_cached_model(model_atom, cache_dir) do
      {:ok, _path} ->
        Mix.shell().info("Model already cached at: #{cache_dir}")

        if Mix.shell().yes?("Re-download?") do
          download_model(model_atom, cache_dir, offline)
        else
          Mix.shell().info("Using cached model")
        end

      :not_found ->
        download_model(model_atom, cache_dir, offline)
    end
  end

  defp download_model(model_atom, cache_dir, offline) do
    if offline do
      Mix.shell().error("Model not cached and offline mode is enabled")
      exit({:shutdown, 1})
    end

    # Validate model name
    unless model_atom in Loader.list_models() do
      Mix.shell().error("Unknown model: #{model_atom}")
      Mix.shell().info("\nAvailable models:")

      Enum.each(Loader.list_models(), fn model ->
        {:ok, info} = Loader.get_model_info(model)
        Mix.shell().info("  #{model} (~#{div(info.params, 1_000_000)}M params)")
      end)

      exit({:shutdown, 1})
    end

    # Get model info
    {:ok, model_info} = Loader.get_model_info(model_atom)

    Mix.shell().info("\nModel Information:")
    Mix.shell().info("  Parameters: ~#{div(model_info.params, 1_000_000)}M")
    Mix.shell().info("  Hidden size: #{model_info.hidden_size}")
    Mix.shell().info("  Layers: #{model_info.num_layers}")
    Mix.shell().info("  Languages: #{inspect(model_info.languages)}")
    Mix.shell().info("\nDownload size: ~#{div(model_info.params * 4, 1_000_000)}MB")

    # Confirm download
    unless Mix.shell().yes?("Proceed with download?") do
      Mix.shell().info("Download cancelled")
      exit({:shutdown, 0})
    end

    # Download model
    Mix.shell().info("\nDownloading... (this may take several minutes)")

    case Loader.load_model(model_atom, cache_dir: cache_dir) do
      {:ok, _model} ->
        # Register in cache
        CacheManager.register_cached_model(model_atom, cache_dir)

        Mix.shell().info("\nModel downloaded successfully!")
        Mix.shell().info("Cached at: #{cache_dir}")

        # Show cache size
        case CacheManager.cache_size(cache_dir) do
          {:ok, size} ->
            size_mb = Float.round(size / (1024 * 1024), 2)
            Mix.shell().info("Total cache size: #{size_mb}MB")

          _ ->
            :ok
        end

      {:error, reason} ->
        Mix.shell().error("Download failed: #{inspect(reason)}")
        Mix.shell().info("\nTroubleshooting:")
        Mix.shell().info("  - Check internet connection")
        Mix.shell().info("  - Verify disk space (~500MB free)")
        Mix.shell().info("  - Check HuggingFace Hub status")
        exit({:shutdown, 1})
    end
  end
end
