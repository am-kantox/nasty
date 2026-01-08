defmodule Mix.Tasks.Nasty.ZeroShot do
  @moduledoc """
  Zero-shot text classification using NLI models.

  Classify text into arbitrary categories without training data.

  ## Usage

      # Classify single text
      mix nasty.zero_shot \\
        --text "I love this product!" \\
        --labels positive,negative,neutral

      # Classify from file
      mix nasty.zero_shot \\
        --input data/texts.txt \\
        --labels technology,sports,politics,business \\
        --output results.json

      # Multi-label classification
      mix nasty.zero_shot \\
        --text "Urgent: Please review the attached document" \\
        --labels urgent,action_required,informational \\
        --multi-label \\
        --threshold 0.5

  ## Options

    * `--text` - Text to classify (use this or --input)
    * `--input` - Path to file with texts to classify (one per line)
    * `--labels` - Comma-separated list of candidate labels (required)
    * `--output` - Output file for results (default: stdout)
    * `--model` - NLI model to use (default: roberta_large_mnli)
      Options: roberta_large_mnli, bart_large_mnli, xlm_roberta_base
    * `--multi-label` - Enable multi-label classification (default: false)
    * `--threshold` - Minimum score for multi-label (default: 0.5)
    * `--hypothesis-template` - Custom hypothesis template (default: "This text is about {}")

  ## Examples

      # Sentiment analysis
      mix nasty.zero_shot \\
        --text "The movie was boring and predictable" \\
        --labels positive,negative,neutral

      # Topic classification
      mix nasty.zero_shot \\
        --text "Bitcoin reaches new all-time high" \\
        --labels technology,finance,sports,politics

      # Multi-label with custom threshold
      mix nasty.zero_shot \\
        --text "Scientists discover new AI breakthrough" \\
        --labels science,technology,healthcare,education \\
        --multi-label \\
        --threshold 0.3

  """

  use Mix.Task

  alias Nasty.Statistics.Neural.Transformers.ZeroShot

  require Logger

  @shortdoc "Zero-shot text classification"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          text: :string,
          input: :string,
          labels: :string,
          output: :string,
          model: :string,
          multi_label: :boolean,
          threshold: :float,
          hypothesis_template: :string
        ]
      )

    # Validate options
    labels = validate_labels!(opts)
    texts = get_texts!(opts)

    config = %{
      model: parse_model(Keyword.get(opts, :model, "roberta_large_mnli")),
      multi_label: Keyword.get(opts, :multi_label, false),
      threshold: Keyword.get(opts, :threshold, 0.5),
      hypothesis_template: Keyword.get(opts, :hypothesis_template, "This text is about {}"),
      output: Keyword.get(opts, :output)
    }

    Mix.shell().info("Zero-shot classification")
    Mix.shell().info("  Model: #{config.model}")
    Mix.shell().info("  Labels: #{Enum.join(labels, ", ")}")
    Mix.shell().info("  Texts: #{length(texts)}")
    Mix.shell().info("  Multi-label: #{config.multi_label}")

    # Classify texts
    Mix.shell().info("\nClassifying...")

    results =
      texts
      |> Enum.with_index(1)
      |> Enum.map(fn {text, idx} ->
        Mix.shell().info("  [#{idx}/#{length(texts)}] Processing...")

        classify_opts = [
          candidate_labels: labels,
          model: config.model,
          multi_label: config.multi_label,
          threshold: config.threshold,
          hypothesis_template: config.hypothesis_template
        ]

        case ZeroShot.classify(text, classify_opts) do
          {:ok, result} ->
            %{text: text, result: result, success: true}

          {:error, reason} ->
            Mix.shell().error("    Failed: #{inspect(reason)}")
            %{text: text, error: reason, success: false}
        end
      end)

    # Display or save results
    successful = Enum.filter(results, & &1.success)
    Mix.shell().info("\nCompleted: #{length(successful)}/#{length(texts)} successful")

    if config.output do
      save_results(results, config.output)
      Mix.shell().info("Results saved to: #{config.output}")
    else
      display_results(results, config.multi_label)
    end
  end

  defp validate_labels!(opts) do
    case Keyword.fetch(opts, :labels) do
      {:ok, labels_str} ->
        labels =
          labels_str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        if length(labels) < 2 do
          Mix.shell().error("Error: Need at least 2 labels for classification")
          exit({:shutdown, 1})
        end

        labels

      :error ->
        Mix.shell().error("Error: --labels option is required")
        exit({:shutdown, 1})
    end
  end

  defp get_texts!(opts) do
    cond do
      Keyword.has_key?(opts, :text) ->
        [Keyword.get(opts, :text)]

      Keyword.has_key?(opts, :input) ->
        input_path = Keyword.get(opts, :input)

        case File.read(input_path) do
          {:ok, content} ->
            content
            |> String.split("\n")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))

          {:error, reason} ->
            Mix.shell().error("Error reading input file: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      true ->
        Mix.shell().error("Error: Either --text or --input is required")
        exit({:shutdown, 1})
    end
  end

  defp parse_model(model_str) do
    String.to_atom(model_str)
  rescue
    ArgumentError -> :roberta_large_mnli
  end

  defp display_results(results, multi_label) do
    Mix.shell().info("\n" <> String.duplicate("=", 70))

    Enum.each(results, fn entry ->
      Mix.shell().info("\nText: #{String.slice(entry.text, 0, 100)}")

      if entry.success do
        if multi_label do
          display_multi_label_result(entry.result)
        else
          display_single_label_result(entry.result)
        end
      else
        Mix.shell().error("Error: #{inspect(entry.error)}")
      end

      Mix.shell().info(String.duplicate("-", 70))
    end)
  end

  defp display_single_label_result(result) do
    Mix.shell().info("  Predicted: #{result.label}")
    Mix.shell().info("  Confidence: #{Float.round(result.scores[result.label] * 100, 2)}%")
    Mix.shell().info("\n  All scores:")

    result.scores
    |> Enum.sort_by(fn {_label, score} -> -score end)
    |> Enum.each(fn {label, score} ->
      bar = String.duplicate("█", round(score * 20))
      Mix.shell().info("    #{label}: #{Float.round(score * 100, 1)}% #{bar}")
    end)
  end

  defp display_multi_label_result(result) do
    if Enum.empty?(result.labels) do
      Mix.shell().info("  No labels above threshold")
    else
      Mix.shell().info("  Predicted labels: #{Enum.join(result.labels, ", ")}")
    end

    Mix.shell().info("\n  All scores:")

    result.scores
    |> Enum.sort_by(fn {_label, score} -> -score end)
    |> Enum.each(fn {label, score} ->
      marker = if label in result.labels, do: "✓", else: " "
      bar = String.duplicate("█", round(score * 20))
      Mix.shell().info("    [#{marker}] #{label}: #{Float.round(score * 100, 1)}% #{bar}")
    end)
  end

  defp save_results(results, output_path) do
    # Convert to JSON-friendly format
    json_results =
      Enum.map(results, fn entry ->
        if entry.success do
          %{
            text: entry.text,
            result: entry.result,
            success: true
          }
        else
          %{
            text: entry.text,
            error: inspect(entry.error),
            success: false
          }
        end
      end)

    json = Jason.encode!(json_results, pretty: true)
    File.write!(output_path, json)
  rescue
    _error ->
      # Fallback if Jason not available
      formatted =
        Enum.map_join(results, "\n\n", &inspect/1)

      File.write!(output_path, formatted)
  end
end
