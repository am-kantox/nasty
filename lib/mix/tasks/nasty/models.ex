defmodule Mix.Tasks.Nasty.Models do
  @shortdoc "Manage Nasty statistical models"

  @moduledoc """
  Manage statistical models for Nasty.

  ## Commands

      mix nasty.models list           # List all available models
      mix nasty.models info MODEL_ID  # Show detailed model information
      mix nasty.models path MODEL_ID  # Show local path to model file
      mix nasty.models clean          # Remove all cached models from registry

  ## Model IDs

  Model IDs follow the format: `{language}-{task}-{version}`

  Examples:
  - `en-pos-v1` - English POS tagging model, version 1
  - `en-ner-v2` - English NER model, version 2

  ## Examples

      # List all models
      mix nasty.models list

      # Show info about a specific model
      mix nasty.models info en-pos-v1

      # Get path to model file
      mix nasty.models path en-pos-v1

      # Clear model registry
      mix nasty.models clean
  """

  use Mix.Task
  alias Nasty.Statistics.{ModelLoader, ModelRegistry}

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [] ->
        list_models()

      ["list"] ->
        list_models()

      ["info", model_id] ->
        show_info(model_id)

      ["path", model_id] ->
        show_path(model_id)

      ["clean"] ->
        clean_models()

      _ ->
        Mix.shell().error("Unknown command or invalid arguments.")
        Mix.shell().info("")
        Mix.shell().info("Usage:")
        Mix.shell().info("  mix nasty.models list")
        Mix.shell().info("  mix nasty.models info MODEL_ID")
        Mix.shell().info("  mix nasty.models path MODEL_ID")
        Mix.shell().info("  mix nasty.models clean")
        exit({:shutdown, 1})
    end
  end

  defp list_models do
    Mix.shell().info("Discovering models...")
    discovered = ModelLoader.discover_models()

    if Enum.empty?(discovered) do
      Mix.shell().info("")
      Mix.shell().info("No models found in priv/models/")
      Mix.shell().info("")
      Mix.shell().info("To train a model:")
      Mix.shell().info("  mix nasty.train.pos --corpus PATH")
      Mix.shell().info("")
    else
      Mix.shell().info("")
      Mix.shell().info("Available models:")
      Mix.shell().info("")

      discovered
      |> Enum.group_by(fn {language, task, _version, _path, _meta} ->
        {language, task}
      end)
      |> Enum.sort()
      |> Enum.each(fn {{language, task}, models} ->
        Mix.shell().info("  #{format_language(language)} - #{format_task(task)}:")

        models
        |> Enum.sort_by(fn {_lang, _task, version, _path, _meta} -> version end)
        |> Enum.each(fn {_lang, _task, version, path, meta_path} ->
          model_id = format_model_id(language, task, version)
          size = get_file_size(path)
          has_meta = if meta_path, do: "", else: " (no metadata)"
          Mix.shell().info("    #{model_id} - #{size}#{has_meta}")
        end)

        Mix.shell().info("")
      end)

      Mix.shell().info("Total: #{length(discovered)} model(s)")
    end

    # Also show registry contents
    registered = ModelRegistry.list()

    if not Enum.empty?(registered) do
      Mix.shell().info("")
      Mix.shell().info("Loaded in registry: #{length(registered)} model(s)")
    end
  end

  defp show_info(model_id) do
    case parse_model_id(model_id) do
      {:ok, language, task, version} ->
        case ModelLoader.get_model_path(language, task, version) do
          {:ok, path} ->
            Mix.shell().info("Model: #{model_id}")
            Mix.shell().info("Language: #{format_language(language)}")
            Mix.shell().info("Task: #{format_task(task)}")
            Mix.shell().info("Version: #{version}")
            Mix.shell().info("Path: #{path}")
            Mix.shell().info("Size: #{get_file_size(path)}")

            # Try to load metadata
            meta_path = String.replace(path, ".model", ".meta.json")

            if File.exists?(meta_path) do
              case File.read(meta_path) do
                {:ok, content} ->
                  case :json.decode(content) do
                    {:ok, metadata} when is_map(metadata) ->
                      Mix.shell().info("")
                      Mix.shell().info("Metadata:")
                      print_metadata(metadata)

                    _ ->
                      :ok
                  end

                _ ->
                  :ok
              end
            end

            # Check if loaded in registry
            case ModelRegistry.lookup(language, task, version) do
              {:ok, _model, registry_meta} ->
                Mix.shell().info("")
                Mix.shell().info("Status: Loaded in registry")

                if map_size(registry_meta) > 0 do
                  Mix.shell().info("")
                  Mix.shell().info("Registry metadata:")
                  print_metadata(registry_meta)
                end

              {:error, :not_found} ->
                Mix.shell().info("")
                Mix.shell().info("Status: Not loaded in registry")
            end

          {:error, :not_found} ->
            Mix.shell().error("Model not found: #{model_id}")
            exit({:shutdown, 1})
        end

      {:error, :invalid_format} ->
        Mix.shell().error("Invalid model ID format: #{model_id}")
        Mix.shell().info("Expected format: LANG-TASK-VERSION (e.g., en-pos-v1)")
        exit({:shutdown, 1})
    end
  end

  defp show_path(model_id) do
    case parse_model_id(model_id) do
      {:ok, language, task, version} ->
        case ModelLoader.get_model_path(language, task, version) do
          {:ok, path} ->
            Mix.shell().info(path)

          {:error, :not_found} ->
            Mix.shell().error("Model not found: #{model_id}")
            exit({:shutdown, 1})
        end

      {:error, :invalid_format} ->
        Mix.shell().error("Invalid model ID format: #{model_id}")
        Mix.shell().info("Expected format: LANG-TASK-VERSION (e.g., en-pos-v1)")
        exit({:shutdown, 1})
    end
  end

  defp clean_models do
    Mix.shell().info("Clearing model registry...")
    ModelRegistry.clear()
    Mix.shell().info("Model registry cleared.")
  end

  ## Helper Functions

  defp parse_model_id(model_id) do
    # Expected format: en-pos-v1
    case String.split(model_id, "-") do
      [lang, task, version] ->
        language = String.to_atom(lang)
        task_atom = parse_task(task)
        {:ok, language, task_atom, version}

      _ ->
        {:error, :invalid_format}
    end
  end

  defp parse_task("pos"), do: :pos_tagging
  defp parse_task("ner"), do: :ner
  defp parse_task("parsing"), do: :parsing
  defp parse_task(other), do: String.to_atom(other)

  defp format_model_id(language, task, version) do
    task_str =
      case task do
        :pos_tagging -> "pos"
        :ner -> "ner"
        :parsing -> "parsing"
        other -> Atom.to_string(other)
      end

    "#{language}-#{task_str}-#{version}"
  end

  defp format_language(:en), do: "English"
  defp format_language(:es), do: "Spanish"
  defp format_language(:ca), do: "Catalan"
  defp format_language(lang), do: Atom.to_string(lang) |> String.capitalize()

  defp format_task(:pos_tagging), do: "POS Tagging"
  defp format_task(:ner), do: "Named Entity Recognition"
  defp format_task(:parsing), do: "Parsing"
  defp format_task(task), do: Atom.to_string(task) |> String.capitalize()

  defp get_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} ->
        format_bytes(size)

      _ ->
        "unknown"
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"

  defp print_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.sort()
    |> Enum.each(fn {key, value} ->
      formatted_key =
        key
        |> to_string()
        |> String.replace("_", " ")
        |> String.capitalize()

      Mix.shell().info("  #{formatted_key}: #{format_value(value)}")
    end)
  end

  defp format_value(value) when is_float(value), do: Float.round(value, 4)
  defp format_value(value) when is_map(value), do: inspect(value)
  defp format_value(value), do: value
end
