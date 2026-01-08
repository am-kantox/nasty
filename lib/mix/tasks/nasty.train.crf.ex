defmodule Mix.Tasks.Nasty.Train.Crf do
  @moduledoc """
  Trains a CRF (Conditional Random Field) model for sequence labeling tasks.

  ## Usage

      mix nasty.train.crf --corpus data/train.conllu --output priv/models/en/ner_crf.model --task ner

  ## Options

    * `--corpus` - Path to training corpus in CoNLL-U format (required)
    * `--test` - Path to test corpus for evaluation (optional)
    * `--output` - Path to save trained model (required)
    * `--task` - Task type: ner, pos, chunking (default: ner)
    * `--iterations` - Maximum training iterations (default: 100)
    * `--learning-rate` - Learning rate (default: 0.1)
    * `--regularization` - L2 regularization strength (default: 1.0)
    * `--method` - Optimization method: sgd, momentum, adagrad (default: momentum)
    * `--language` - Language code (default: en)

  ## Examples

      # Train NER model
      mix nasty.train.crf \\
        --corpus data/en_ewt-ud-train.conllu \\
        --output priv/models/en/ner_crf.model \\
        --task ner \\
        --iterations 100

      # Train with evaluation
      mix nasty.train.crf \\
        --corpus data/train.conllu \\
        --test data/test.conllu \\
        --output priv/models/en/ner_crf.model \\
        --task ner \\
        --learning-rate 0.05
  """

  use Mix.Task

  alias Nasty.Statistics.SequenceLabeling.CRF

  @shortdoc "Trains a CRF model for sequence labeling"

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          corpus: :string,
          test: :string,
          output: :string,
          task: :string,
          iterations: :integer,
          learning_rate: :float,
          regularization: :float,
          method: :string,
          language: :string
        ],
        aliases: [
          i: :iterations,
          l: :learning_rate,
          r: :regularization
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    corpus_path = Keyword.get(opts, :corpus)
    output_path = Keyword.get(opts, :output)
    test_path = Keyword.get(opts, :test)
    task = Keyword.get(opts, :task, "ner")
    iterations = Keyword.get(opts, :iterations, 100)
    learning_rate = Keyword.get(opts, :learning_rate, 0.1)
    regularization = Keyword.get(opts, :regularization, 1.0)
    method = Keyword.get(opts, :method, "momentum") |> String.to_atom()
    language = Keyword.get(opts, :language, "en") |> String.to_atom()

    unless corpus_path do
      Mix.raise("--corpus option is required")
    end

    unless output_path do
      Mix.raise("--output option is required")
    end

    Mix.shell().info("Training CRF model...")
    Mix.shell().info("Corpus: #{corpus_path}")
    Mix.shell().info("Task: #{task}")
    Mix.shell().info("Language: #{language}")
    Mix.shell().info("Iterations: #{iterations}")
    Mix.shell().info("Learning rate: #{learning_rate}")
    Mix.shell().info("Optimization: #{method}")

    # Load training data
    training_data = load_conllu(corpus_path, task)
    Mix.shell().info("Loaded #{length(training_data)} sequences")

    # Extract labels
    labels = extract_labels(training_data)
    Mix.shell().info("Label set: #{inspect(labels)}")

    # Create and train model
    model = CRF.new(labels: labels, language: language)

    Mix.shell().info("\nTraining model...")

    {:ok, trained} =
      CRF.train(model, training_data,
        iterations: iterations,
        learning_rate: learning_rate,
        regularization: regularization,
        method: method
      )

    # Print statistics
    Mix.shell().info("Training complete!")
    Mix.shell().info("Feature weights: #{map_size(trained.feature_weights)}")
    Mix.shell().info("Transition weights: #{map_size(trained.transition_weights)}")

    # Evaluate on test set if provided
    if test_path do
      Mix.shell().info("\nEvaluating on test set...")
      test_data = load_conllu(test_path, task)
      metrics = evaluate_model(trained, test_data)

      Mix.shell().info("Test accuracy: #{Float.round(metrics.accuracy * 100, 2)}%")
      Mix.shell().info("Precision: #{Float.round(metrics.precision * 100, 2)}%")
      Mix.shell().info("Recall: #{Float.round(metrics.recall * 100, 2)}%")
      Mix.shell().info("F1 score: #{Float.round(metrics.f1 * 100, 2)}%")
    end

    # Save model
    :ok = CRF.save(trained, output_path)
    Mix.shell().info("\nModel saved to: #{output_path}")
  end

  # Load CoNLL-U format data
  defp load_conllu(path, task) do
    path
    |> File.read!()
    |> String.split("\n\n", trim: true)
    |> Enum.map(&parse_sequence(&1, task))
    |> Enum.reject(&is_nil/1)
  end

  # Parse a single sequence
  defp parse_sequence(sequence_text, task) do
    lines =
      sequence_text
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))

    if Enum.empty?(lines) do
      nil
    else
      token_lines =
        lines
        |> Enum.map(&parse_token_line(&1, task))
        |> Enum.reject(&is_nil/1)

      tokens = Enum.map(token_lines, fn {token, _label} -> token end)
      labels = Enum.map(token_lines, fn {_token, label} -> label end)

      {tokens, labels}
    end
  end

  # Parse a single CoNLL-U token line and extract label based on task
  defp parse_token_line(line, task) do
    fields = String.split(line, "\t")

    if length(fields) >= 10 do
      [id, form, lemma, upos, _xpos, feats, _head, _deprel, _deps, misc] = fields

      # Skip multiword tokens
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

        label = extract_label(misc, feats, task)
        {token, label}
      end
    else
      nil
    end
  end

  # Extract label based on task type
  defp extract_label(misc, _feats, "ner") do
    # Extract NER tag from MISC field (e.g., "Entity=PERSON")
    case Regex.run(~r/Entity=([A-Z]+)/, misc) do
      [_, entity_type] -> String.to_atom(String.downcase(entity_type))
      nil -> :none
    end
  end

  defp extract_label(_misc, _feats, "pos") do
    # POS tagging is already in the token
    :tag
  end

  defp extract_label(_misc, _feats, _task) do
    :none
  end

  # Extract all unique labels from training data
  defp extract_labels(training_data) do
    training_data
    |> Enum.flat_map(fn {_tokens, labels} -> labels end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Evaluate model on test data
  defp evaluate_model(model, test_data) do
    results =
      Enum.map(test_data, fn {tokens, expected_labels} ->
        case CRF.predict(model, tokens, []) do
          {:ok, predicted_labels} ->
            {expected_labels, predicted_labels}

          {:error, reason} ->
            Mix.shell().error("Prediction error: #{inspect(reason)}")
            {expected_labels, List.duplicate(:none, length(expected_labels))}
        end
      end)

    calculate_metrics(results)
  end

  # Calculate precision, recall, F1, and accuracy
  defp calculate_metrics(results) do
    {all_expected, all_predicted} =
      Enum.reduce(results, {[], []}, fn {expected, predicted}, {exp_acc, pred_acc} ->
        {exp_acc ++ expected, pred_acc ++ predicted}
      end)

    total = length(all_expected)
    correct = Enum.zip(all_expected, all_predicted) |> Enum.count(fn {e, p} -> e == p end)

    # Calculate per-class metrics (excluding :none)
    non_none_labels = Enum.reject(all_expected ++ all_predicted, &(&1 == :none)) |> Enum.uniq()

    {total_precision, total_recall, count} =
      Enum.reduce(non_none_labels, {0.0, 0.0, 0}, fn label, {prec_acc, rec_acc, cnt} ->
        true_positive = count_matches(all_expected, all_predicted, label, label)
        false_positive = count_matches(all_expected, all_predicted, :not_label, label)
        false_negative = count_matches(all_expected, all_predicted, label, :not_label)

        precision =
          if true_positive + false_positive > 0,
            do: true_positive / (true_positive + false_positive),
            else: 0.0

        recall =
          if true_positive + false_negative > 0,
            do: true_positive / (true_positive + false_negative),
            else: 0.0

        {prec_acc + precision, rec_acc + recall, cnt + 1}
      end)

    avg_precision = if count > 0, do: total_precision / count, else: 0.0
    avg_recall = if count > 0, do: total_recall / count, else: 0.0

    f1 =
      if avg_precision + avg_recall > 0,
        do: 2 * avg_precision * avg_recall / (avg_precision + avg_recall),
        else: 0.0

    %{
      accuracy: correct / total,
      precision: avg_precision,
      recall: avg_recall,
      f1: f1
    }
  end

  # Count matches for metric calculation
  defp count_matches(expected, predicted, exp_pattern, pred_pattern) do
    Enum.zip(expected, predicted)
    |> Enum.count(fn {e, p} ->
      exp_match = if exp_pattern == :not_label, do: e != pred_pattern, else: e == exp_pattern
      pred_match = if pred_pattern == :not_label, do: p != exp_pattern, else: p == pred_pattern
      exp_match and pred_match
    end)
  end
end
