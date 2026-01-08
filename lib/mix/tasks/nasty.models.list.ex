defmodule Mix.Tasks.Nasty.Models.List do
  @moduledoc """
  Lists all cached transformer models and available models.

  ## Usage

      mix nasty.models.list [OPTIONS]

  ## Options

    * `--cache-dir` - Directory to check for cached models (default: priv/models/transformers)
    * `--available` - Show all available models that can be downloaded

  ## Examples

      # List cached models
      mix nasty.models.list

      # List available models for download
      mix nasty.models.list --available

      # Check custom cache directory
      mix nasty.models.list --cache-dir=/tmp/models

  """

  use Mix.Task
  alias Nasty.Statistics.Neural.Transformers.{CacheManager, Config, Loader}

  @shortdoc "Lists cached and available transformer models"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [cache_dir: :string, available: :boolean],
        aliases: [c: :cache_dir, a: :available]
      )

    cache_dir = Keyword.get(opts, :cache_dir, Config.cache_dir())
    show_available = Keyword.get(opts, :available, false)

    if show_available do
      show_available_models()
    else
      show_cached_models(cache_dir)
    end
  end

  defp show_cached_models(cache_dir) do
    Mix.shell().info("Cached Transformer Models")
    Mix.shell().info(String.duplicate("=", 60))
    Mix.shell().info("Cache directory: #{cache_dir}")
    Mix.shell().info("")

    cached_models = CacheManager.list_cached_models(cache_dir)

    if Enum.empty?(cached_models) do
      Mix.shell().info("No models cached yet.")
      Mix.shell().info("\nTo download a model, run:")
      Mix.shell().info("  mix nasty.models.download MODEL_NAME")
      Mix.shell().info("\nTo see available models, run:")
      Mix.shell().info("  mix nasty.models.list --available")
    else
      Enum.each(cached_models, fn entry ->
        Mix.shell().info("Model: #{entry.model_name}")
        Mix.shell().info("  Path: #{entry.path}")
        Mix.shell().info("  Size: #{format_bytes(entry.size_bytes)}")
        Mix.shell().info("  Downloaded: #{format_datetime(entry.downloaded_at)}")
        Mix.shell().info("  Version: #{entry.version}")
        Mix.shell().info("")
      end)

      # Show total cache size
      case CacheManager.cache_size(cache_dir) do
        {:ok, total_size} ->
          Mix.shell().info("Total cache size: #{format_bytes(total_size)}")

        _ ->
          :ok
      end
    end
  end

  defp show_available_models do
    Mix.shell().info("Available Transformer Models")
    Mix.shell().info(String.duplicate("=", 60))
    Mix.shell().info("")

    Loader.list_models()
    |> Enum.each(fn model_name ->
      case Loader.get_model_info(model_name) do
        {:ok, info} ->
          Mix.shell().info("#{model_name}")
          Mix.shell().info("  Repository: #{info.repo}")
          Mix.shell().info("  Parameters: ~#{div(info.params, 1_000_000)}M")
          Mix.shell().info("  Hidden size: #{info.hidden_size}")
          Mix.shell().info("  Layers: #{info.num_layers}")
          Mix.shell().info("  Languages: #{format_languages(info.languages)}")
          Mix.shell().info("  Download size: ~#{estimate_download_size(info)}MB")
          Mix.shell().info("")

        {:error, _} ->
          :ok
      end
    end)

    Mix.shell().info("To download a model, run:")
    Mix.shell().info("  mix nasty.models.download MODEL_NAME")
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_languages(languages) do
    case languages do
      [:multi] -> "100+ languages"
      [lang] -> "#{lang}"
      langs when length(langs) <= 3 -> Enum.join(langs, ", ")
      langs -> "#{Enum.take(langs, 3) |> Enum.join(", ")} and #{length(langs) - 3} more"
    end
  end

  defp estimate_download_size(info) do
    # Estimate: 4 bytes per parameter + overhead
    div(info.params * 4, 1_000_000)
  end
end
