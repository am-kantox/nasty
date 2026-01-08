defmodule Mix.Tasks.Nasty.Eval do
  @moduledoc """
  Evaluates trained statistical models on test data.

  ## Usage

      mix nasty.eval --model priv/models/en/pcfg.model --test data/test.conllu --type pcfg
      mix nasty.eval --model priv/models/en/ner_crf.model --test data/test.conllu --type crf --task ner

  ## Options

    * `--model` - Path to trained model file (required)
    * `--test` - Path to test data in CoNLL-U format (required)
    * `--type` - Model type: pcfg, crf (required)
    * `--task` - Task type for CRF: ner, pos, chunking (default: ner)
    * `--verbose` - Show detailed per-example results (default: false)

  ## Examples

      # Evaluate PCFG
      mix nasty.eval \\
        --model priv/models/en/pcfg.model \\
        --test data/en_ewt-ud-test.conllu \\
        --type pcfg

      # Evaluate CRF with verbose output
      mix nasty.eval \\
        --model priv/models/en/ner_crf.model \\
        --test data/test.conllu \\
        --type crf \\
        --task ner \\
        --verbose
  """

  use Mix.Task

  alias Nasty.Statistics.Parsing.PCFG
  alias Nasty.Statistics.SequenceLabeling.CRF

  @shortdoc "Evaluates trained statistical models"

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          model: :string,
          test: :string,
          type: :string,
          task: :string,
          verbose: :boolean
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    model_path = Keyword.get(opts, :model)
    test_path = Keyword.get(opts, :test)
    model_type = Keyword.get(opts, :type)
    task = Keyword.get(opts, :task, "ner")
    verbose = Keyword.get(opts, :verbose, false)

    unless model_path do
      Mix.raise("--model option is required")
    end

    unless test_path do
      Mix.raise("--test option is required")
    end

    unless model_type do
      Mix.raise("--type option is required (pcfg or crf)")
    end

    Mix.shell().info("Evaluating #{model_type} model...")
    Mix.shell().info("Model: #{model_path}")
    Mix.shell().info("Test data: #{test_path}")

    case model_type do
      "pcfg" -> evaluate_pcfg(model_path, test_path, verbose)
      "crf" -> evaluate_crf(model_path, test_path, task, verbose)
      _ -> Mix.raise("Unknown model type: #{model_type}. Use 'pcfg' or 'crf'")
    end
  end

  # Evaluate PCFG model
  defp evaluate_pcfg(model_path, test_path, verbose) do
    # Load model
    {:ok, model} = PCFG.load(model_path)
    Mix.shell().info("Loaded PCFG model")
    Mix.shell().info("Rules: #{length(model.rules)}")

    # Load test data
    test_data = load_conllu_for_pcfg(test_path)
    Mix.shell().info("Test sentences: #{length(test_data)}")

    # Evaluate
    Mix.shell().info("\nEvaluating...")

    results =
      Enum.map(test_data, fn {tokens, _expected_tree} ->
        case PCFG.predict(model, tokens, []) do
          {:ok, _tree} -> {true, tokens}
          {:error, reason} -> {false, tokens, reason}
        end
      end)

    successful = Enum.count(results, fn result -> elem(result, 0) end)
    total = length(results)
    accuracy = successful / total

    Mix.shell().info("\nResults:")
    Mix.shell().info("Total sentences: #{total}")
    Mix.shell().info("Successful parses: #{successful}")
    Mix.shell().info("Failed parses: #{total - successful}")
    Mix.shell().info("Parsing accuracy: #{Float.round(accuracy * 100, 2)}%")

    if verbose do
      Mix.shell().info("\nFailed examples:")

      results
      |> Enum.reject(fn result -> elem(result, 0) end)
      |> Enum.take(10)
      |> Enum.each(fn {_success, tokens, reason} ->
        sentence = Enum.map_join(tokens, " ", & &1.text)
        Mix.shell().info("  #{sentence}")
        Mix.shell().info("  Error: #{inspect(reason)}")
      end)
    end
  end

  # Evaluate CRF model
  defp evaluate_crf(model_path, test_path, task, verbose) do
    # Load model
    {:ok, model} = CRF.load(model_path)
    Mix.shell().info("Loaded CRF model")
    Mix.shell().info("Labels: #{inspect(model.labels)}")

    # Load test data
    test_data = load_conllu_for_crf(test_path, task)
    Mix.shell().info("Test sequences: #{length(test_data)}")

    # Evaluate
    Mix.shell().info("\nEvaluating...")

    results =
      Enum.map(test_data, fn {tokens, expected_labels} ->
        case CRF.predict(model, tokens, []) do
          {:ok, predicted_labels} ->
            {expected_labels, predicted_labels, tokens}

          {:error, reason} ->
            Mix.shell().error("Prediction error: #{inspect(reason)}")
            {expected_labels, List.duplicate(:none, length(expected_labels)), tokens}
        end
      end)

    metrics = calculate_crf_metrics(results)

    Mix.shell().info("\nResults:")
    Mix.shell().info("Accuracy: #{Float.round(metrics.accuracy * 100, 2)}%")
    Mix.shell().info("Precision: #{Float.round(metrics.precision * 100, 2)}%")
    Mix.shell().info("Recall: #{Float.round(metrics.recall * 100, 2)}%")
    Mix.shell().info("F1 score: #{Float.round(metrics.f1 * 100, 2)}%")

    with true <- verbose,
         %{per_label: per_label} <- metrics do
      Mix.shell().info("\nPer-label metrics:")

      Enum.each(per_label, fn {label, label_metrics} ->
        Mix.shell().info("  #{label}:")
        Mix.shell().info("    Precision: #{Float.round(label_metrics.precision * 100, 2)}%")
        Mix.shell().info("    Recall: #{Float.round(label_metrics.recall * 100, 2)}%")
        Mix.shell().info("    F1: #{Float.round(label_metrics.f1 * 100, 2)}%")
      end)
    end
  end

  # Load CoNLL-U for PCFG
  defp load_conllu_for_pcfg(path) do
    path
    |> File.read!()
    |> String.split("\n\n", trim: true)
    |> Enum.map(&parse_sentence_for_pcfg/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_sentence_for_pcfg(sentence_text) do
    lines =
      sentence_text
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))

    if Enum.empty?(lines) do
      nil
    else
      tokens =
        lines
        |> Enum.map(&parse_token_line_pcfg/1)
        |> Enum.reject(&is_nil/1)

      parse_tree = {:s, []}
      {tokens, parse_tree}
    end
  end

  defp parse_token_line_pcfg(line) do
    fields = String.split(line, "\t")

    if length(fields) >= 10 do
      [id, form, lemma, upos | _] = fields

      if String.contains?(id, "-") do
        nil
      else
        %Nasty.AST.Token{
          text: form,
          lemma: lemma,
          pos_tag: String.to_atom(String.downcase(upos)),
          span: nil,
          language: :en
        }
      end
    else
      nil
    end
  end

  # Load CoNLL-U for CRF
  defp load_conllu_for_crf(path, task) do
    path
    |> File.read!()
    |> String.split("\n\n", trim: true)
    |> Enum.map(&parse_sequence_for_crf(&1, task))
    |> Enum.reject(&is_nil/1)
  end

  defp parse_sequence_for_crf(sequence_text, task) do
    lines =
      sequence_text
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))

    if Enum.empty?(lines) do
      nil
    else
      token_lines =
        lines
        |> Enum.map(&parse_token_line_crf(&1, task))
        |> Enum.reject(&is_nil/1)

      tokens = Enum.map(token_lines, fn {token, _label} -> token end)
      labels = Enum.map(token_lines, fn {_token, label} -> label end)

      {tokens, labels}
    end
  end

  defp parse_token_line_crf(line, task) do
    fields = String.split(line, "\t")

    if length(fields) >= 10 do
      [id, form, lemma, upos, _xpos, feats, _head, _deprel, _deps, misc] = fields

      if String.contains?(id, "-") do
        nil
      else
        token = %Nasty.AST.Token{
          text: form,
          lemma: lemma,
          pos_tag: String.to_atom(String.downcase(upos)),
          span: nil,
          language: :en
        }

        label = extract_label_for_crf(misc, feats, task)
        {token, label}
      end
    else
      nil
    end
  end

  defp extract_label_for_crf(misc, _feats, "ner") do
    case Regex.run(~r/Entity=([A-Z]+)/, misc) do
      [_, entity_type] -> String.to_atom(String.downcase(entity_type))
      nil -> :none
    end
  end

  defp extract_label_for_crf(_misc, _feats, _task), do: :none

  # Calculate metrics for CRF
  defp calculate_crf_metrics(results) do
    {all_expected, all_predicted} =
      Enum.reduce(results, {[], []}, fn {expected, predicted, _tokens}, {exp_acc, pred_acc} ->
        {exp_acc ++ expected, pred_acc ++ predicted}
      end)

    total = length(all_expected)
    correct = Enum.zip(all_expected, all_predicted) |> Enum.count(fn {e, p} -> e == p end)

    non_none_labels = Enum.reject(all_expected ++ all_predicted, &(&1 == :none)) |> Enum.uniq()

    {total_precision, total_recall, count} =
      Enum.reduce(non_none_labels, {0.0, 0.0, 0}, fn label, {prec_acc, rec_acc, cnt} ->
        tp = count_label_matches(all_expected, all_predicted, label, label)
        fp = count_label_matches(all_expected, all_predicted, :other, label)
        fn_count = count_label_matches(all_expected, all_predicted, label, :other)

        precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
        recall = if tp + fn_count > 0, do: tp / (tp + fn_count), else: 0.0

        {prec_acc + precision, rec_acc + recall, cnt + 1}
      end)

    avg_precision = if count > 0, do: total_precision / count, else: 0.0
    avg_recall = if count > 0, do: total_recall / count, else: 0.0

    f1 =
      if avg_precision + avg_recall > 0,
        do: 2 * avg_precision * avg_recall / (avg_precision + avg_recall),
        else: 0.0

    # Calculate per-label metrics for detailed analysis
    per_label_metrics =
      Enum.map(non_none_labels, fn label ->
        tp = count_label_matches(all_expected, all_predicted, label, label)
        fp = count_label_matches(all_expected, all_predicted, :other, label)
        fn_count = count_label_matches(all_expected, all_predicted, label, :other)

        precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
        recall = if tp + fn_count > 0, do: tp / (tp + fn_count), else: 0.0

        f1_label =
          if precision + recall > 0, do: 2 * precision * recall / (precision + recall), else: 0.0

        {label,
         %{
           precision: precision,
           recall: recall,
           f1: f1_label,
           true_positives: tp,
           false_positives: fp,
           false_negatives: fn_count
         }}
      end)
      |> Map.new()

    # Calculate confusion matrix statistics
    confusion_pairs =
      Enum.zip(all_expected, all_predicted)
      |> Enum.reject(fn {e, p} -> e == p end)
      |> Enum.frequencies()

    %{
      accuracy: correct / total,
      precision: avg_precision,
      recall: avg_recall,
      f1: f1,
      total_predictions: total,
      correct_predictions: correct,
      per_label: per_label_metrics,
      confusion_pairs: confusion_pairs,
      support: Map.new(Enum.frequencies(all_expected))
    }
  end

  defp count_label_matches(expected, predicted, exp_pattern, pred_pattern) do
    Enum.zip(expected, predicted)
    |> Enum.count(fn {e, p} ->
      exp_match = if exp_pattern == :other, do: e != pred_pattern, else: e == exp_pattern
      pred_match = if pred_pattern == :other, do: p != exp_pattern, else: p == pred_pattern
      exp_match and pred_match
    end)
  end
end
