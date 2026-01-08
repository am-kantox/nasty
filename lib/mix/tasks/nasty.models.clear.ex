defmodule Mix.Tasks.Nasty.Models.Clear do
  @moduledoc """
  Clears cached transformer models to free disk space.

  ## Usage

      mix nasty.models.clear [MODEL_NAME] [OPTIONS]

  ## Arguments

    * MODEL_NAME - (Optional) Specific model to clear. If omitted, prompts to clear all.

  ## Options

    * `--cache-dir` - Directory with cached models (default: priv/models/transformers)
    * `--all` - Clear all cached models without confirmation
    * `--force` - Skip confirmation prompts

  ## Examples

      # Clear specific model (with confirmation)
      mix nasty.models.clear roberta_base

      # Clear all models (with confirmation)
      mix nasty.models.clear --all

      # Clear all models without confirmation
      mix nasty.models.clear --all --force

      # Clear from custom directory
      mix nasty.models.clear --cache-dir=/tmp/models --all

  """

  use Mix.Task
  alias Nasty.Statistics.Neural.Transformers.{CacheManager, Config}

  @shortdoc "Clears cached transformer models"

  @impl Mix.Task
  def run(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [cache_dir: :string, all: :boolean, force: :boolean],
        aliases: [c: :cache_dir, a: :all, f: :force]
      )

    cache_dir = Keyword.get(opts, :cache_dir, Config.cache_dir())
    clear_all = Keyword.get(opts, :all, false)
    force = Keyword.get(opts, :force, false)

    cond do
      clear_all ->
        clear_all_models(cache_dir, force)

      rest != [] ->
        model_name = hd(rest)
        model_atom = String.to_atom(model_name)
        clear_model(model_atom, cache_dir, force)

      true ->
        # No arguments provided, ask what to do
        show_cache_and_prompt(cache_dir)
    end
  end

  defp clear_all_models(cache_dir, force) do
    # Get cache size before clearing
    case CacheManager.cache_size(cache_dir) do
      {:ok, size} ->
        size_mb = Float.round(size / (1024 * 1024), 2)

        Mix.shell().info("Cache directory: #{cache_dir}")
        Mix.shell().info("Total size: #{size_mb}MB")
        Mix.shell().info("")

        if size == 0 do
          Mix.shell().info("Cache is already empty")
          exit({:shutdown, 0})
        end

      _ ->
        :ok
    end

    # List cached models
    cached_models = CacheManager.list_cached_models(cache_dir)

    if Enum.empty?(cached_models) do
      Mix.shell().info("No models to clear")
      exit({:shutdown, 0})
    end

    Mix.shell().info("Models to be cleared:")

    Enum.each(cached_models, fn entry ->
      size_mb = Float.round(entry.size_bytes / (1024 * 1024), 2)
      Mix.shell().info("  #{entry.model_name} (#{size_mb}MB)")
    end)

    Mix.shell().info("")

    # Confirm unless force flag is set
    proceed =
      if force do
        true
      else
        Mix.shell().yes?("Clear all cached models?")
      end

    if proceed do
      case CacheManager.clear_cache(:all, cache_dir) do
        :ok ->
          Mix.shell().info("All cached models cleared successfully")
          Mix.shell().info("Freed disk space in: #{cache_dir}")

        {:error, reason} ->
          Mix.shell().error("Failed to clear cache: #{inspect(reason)}")
          exit({:shutdown, 1})
      end
    else
      Mix.shell().info("Operation cancelled")
      exit({:shutdown, 0})
    end
  end

  defp clear_model(model_atom, cache_dir, force) do
    # Check if model is cached
    case CacheManager.get_cached_model(model_atom, cache_dir) do
      {:ok, _path} ->
        # Get model info
        cached_models = CacheManager.list_cached_models(cache_dir)

        model_entry =
          Enum.find(cached_models, fn entry -> entry.model_name == model_atom end)

        if model_entry do
          size_mb = Float.round(model_entry.size_bytes / (1024 * 1024), 2)

          Mix.shell().info("Model: #{model_atom}")
          Mix.shell().info("Size: #{size_mb}MB")
          Mix.shell().info("Path: #{model_entry.path}")
          Mix.shell().info("")
        end

        # Confirm unless force flag is set
        proceed =
          if force do
            true
          else
            Mix.shell().yes?("Clear this model?")
          end

        if proceed do
          case CacheManager.clear_cache(model_atom, cache_dir) do
            :ok ->
              Mix.shell().info("Model cleared successfully")

              if model_entry do
                freed_mb = Float.round(model_entry.size_bytes / (1024 * 1024), 2)
                Mix.shell().info("Freed: #{freed_mb}MB")
              end

            {:error, reason} ->
              Mix.shell().error("Failed to clear model: #{inspect(reason)}")
              exit({:shutdown, 1})
          end
        else
          Mix.shell().info("Operation cancelled")
          exit({:shutdown, 0})
        end

      :not_found ->
        Mix.shell().error("Model not found in cache: #{model_atom}")
        Mix.shell().info("\nTo see cached models, run:")
        Mix.shell().info("  mix nasty.models.list")
        exit({:shutdown, 1})
    end
  end

  defp show_cache_and_prompt(cache_dir) do
    Mix.shell().info("Transformer Model Cache Management")
    Mix.shell().info(String.duplicate("=", 60))
    Mix.shell().info("Cache directory: #{cache_dir}")
    Mix.shell().info("")

    cached_models = CacheManager.list_cached_models(cache_dir)

    if Enum.empty?(cached_models) do
      Mix.shell().info("No models cached")
      exit({:shutdown, 0})
    end

    Mix.shell().info("Cached models:")

    Enum.with_index(cached_models, 1)
    |> Enum.each(fn {entry, idx} ->
      size_mb = Float.round(entry.size_bytes / (1024 * 1024), 2)
      Mix.shell().info("  #{idx}. #{entry.model_name} (#{size_mb}MB)")
    end)

    # Show total
    case CacheManager.cache_size(cache_dir) do
      {:ok, total_size} ->
        total_mb = Float.round(total_size / (1024 * 1024), 2)
        Mix.shell().info("\nTotal cache size: #{total_mb}MB")

      _ ->
        :ok
    end

    Mix.shell().info("\nOptions:")
    Mix.shell().info("  Clear specific model: mix nasty.models.clear MODEL_NAME")
    Mix.shell().info("  Clear all models:     mix nasty.models.clear --all")
  end
end
