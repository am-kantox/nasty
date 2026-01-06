defmodule Nasty.Statistics.Evaluator do
  @moduledoc """
  Model evaluation and performance metrics.

  Provides standard NLP evaluation metrics for various tasks:
  - Classification: Accuracy, precision, recall, F1
  - Sequence tagging: Token-level and entity-level metrics
  - Parsing: PARSEVAL metrics

  ## Examples

      # POS tagging evaluation
      gold = [:noun, :verb, :det, :noun]
      pred = [:noun, :verb, :adj, :noun]
      metrics = Evaluator.classification_metrics(gold, pred)
      # => %{accuracy: 0.75, ...}

      # Confusion matrix
      matrix = Evaluator.confusion_matrix(gold, pred)
  """

  @doc """
  Calculate classification metrics (accuracy, precision, recall, F1).

  ## Parameters

    - `gold` - List of gold-standard labels
    - `predicted` - List of predicted labels
    - `opts` - Options
      - `:average` - Averaging method: `:micro`, `:macro`, `:weighted` (default: `:macro`)
      - `:labels` - Specific labels to include (default: all)

  ## Returns

    - Map with metrics:
      - `:accuracy` - Overall accuracy
      - `:precision` - Precision score
      - `:recall` - Recall score
      - `:f1` - F1 score
      - `:support` - Number of true instances per class
  """
  @spec classification_metrics([atom()], [atom()], keyword()) :: map()
  def classification_metrics(gold, predicted, opts \\ [])
      when length(gold) == length(predicted) do
    average = Keyword.get(opts, :average, :macro)
    labels = Keyword.get(opts, :labels, unique_labels(gold, predicted))

    accuracy = accuracy(gold, predicted)

    per_class_metrics =
      labels
      |> Enum.map(fn label ->
        {label, per_class_metrics(gold, predicted, label)}
      end)
      |> Enum.into(%{})

    averaged_metrics = average_metrics(per_class_metrics, average)

    %{
      accuracy: accuracy,
      precision: averaged_metrics.precision,
      recall: averaged_metrics.recall,
      f1: averaged_metrics.f1,
      per_class: per_class_metrics,
      confusion_matrix: confusion_matrix(gold, predicted, labels)
    }
  end

  @doc """
  Calculate accuracy: correct predictions / total predictions.

  ## Examples

      iex> gold = [:a, :b, :c, :a]
      iex> pred = [:a, :b, :b, :a]
      iex> Evaluator.accuracy(gold, pred)
      0.75
  """
  @spec accuracy([atom()], [atom()]) :: float()
  def accuracy(gold, predicted) when length(gold) == length(predicted) do
    correct =
      Enum.zip(gold, predicted)
      |> Enum.count(fn {g, p} -> g == p end)

    correct / length(gold)
  end

  @doc """
  Calculate per-class precision, recall, and F1.

  ## Parameters

    - `gold` - Gold-standard labels
    - `predicted` - Predicted labels
    - `label` - The label/class to evaluate

  ## Returns

    - Map with `:precision`, `:recall`, `:f1`, `:support`
  """
  @spec per_class_metrics([atom()], [atom()], atom()) :: map()
  def per_class_metrics(gold, predicted, label) do
    tp = true_positives(gold, predicted, label)
    fp = false_positives(gold, predicted, label)
    fn_count = false_negatives(gold, predicted, label)
    support = Enum.count(gold, &(&1 == label))

    precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
    recall = if tp + fn_count > 0, do: tp / (tp + fn_count), else: 0.0
    f1 = if precision + recall > 0, do: 2 * precision * recall / (precision + recall), else: 0.0

    %{
      precision: precision,
      recall: recall,
      f1: f1,
      support: support
    }
  end

  @doc """
  Build a confusion matrix.

  ## Parameters

    - `gold` - Gold-standard labels
    - `predicted` - Predicted labels
    - `labels` - Optional list of labels to include (default: all unique labels)

  ## Returns

    - Map of maps: `%{true_label => %{pred_label => count}}`

  ## Examples

      iex> gold = [:a, :b, :b, :a]
      iex> pred = [:a, :a, :b, :a]
      iex> confusion_matrix(gold, pred)
      %{a: %{a: 2, b: 0}, b: %{a: 1, b: 1}}
  """
  @spec confusion_matrix([atom()], [atom()], [atom()] | nil) :: map()
  def confusion_matrix(gold, predicted, labels \\ nil) do
    labels = labels || unique_labels(gold, predicted)

    # Initialize matrix with zeros
    initial_matrix =
      labels
      |> Enum.map(fn label ->
        {label, Enum.map(labels, fn l -> {l, 0} end) |> Enum.into(%{})}
      end)
      |> Enum.into(%{})

    # Count predictions
    Enum.zip(gold, predicted)
    |> Enum.reduce(initial_matrix, fn {g, p}, matrix ->
      put_in(matrix, [g, p], matrix[g][p] + 1)
    end)
  end

  @doc """
  Entity-level evaluation for NER.

  Compares predicted and gold entity spans using strict matching.

  ## Parameters

    - `gold_entities` - List of gold entities: `[{type, start, end}, ...]`
    - `pred_entities` - List of predicted entities: `[{type, start, end}, ...]`

  ## Returns

    - Map with `:precision`, `:recall`, `:f1`
  """
  @spec entity_metrics([tuple()], [tuple()]) :: map()
  def entity_metrics(gold_entities, pred_entities) do
    gold_set = MapSet.new(gold_entities)
    pred_set = MapSet.new(pred_entities)

    tp = MapSet.intersection(gold_set, pred_set) |> MapSet.size()
    fp = MapSet.size(pred_set) - tp
    fn_count = MapSet.size(gold_set) - tp

    precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
    recall = if tp + fn_count > 0, do: tp / (tp + fn_count), else: 0.0
    f1 = if precision + recall > 0, do: 2 * precision * recall / (precision + recall), else: 0.0

    %{
      precision: precision,
      recall: recall,
      f1: f1,
      true_positives: tp,
      false_positives: fp,
      false_negatives: fn_count
    }
  end

  @doc """
  Print a formatted confusion matrix.

  ## Examples

      iex> matrix = confusion_matrix(gold, pred)
      iex> print_confusion_matrix(matrix)
      # Prints a nicely formatted table
  """
  @spec print_confusion_matrix(map()) :: :ok
  def print_confusion_matrix(matrix) do
    labels = Map.keys(matrix) |> Enum.sort()

    # Header
    IO.puts("\\nConfusion Matrix:")
    IO.puts("Predicted →")
    IO.puts("True ↓")

    # Column headers
    header = ["" | Enum.map(labels, &to_string/1)] |> Enum.join("\\t")
    IO.puts(header)

    # Rows
    Enum.each(labels, fn true_label ->
      row =
        [
          to_string(true_label)
          | Enum.map(labels, fn pred_label ->
              to_string(matrix[true_label][pred_label])
            end)
        ]
        |> Enum.join("\\t")

      IO.puts(row)
    end)

    :ok
  end

  @doc """
  Print a formatted classification report.

  ## Examples

      iex> metrics = classification_metrics(gold, pred)
      iex> print_report(metrics)
      # Prints precision, recall, F1 for each class
  """
  @spec print_report(map()) :: :ok
  def print_report(metrics) do
    IO.puts("\\nClassification Report:")

    IO.puts(
      String.pad_trailing("Class", 15) <>
        String.pad_trailing("Precision", 12) <>
        String.pad_trailing("Recall", 12) <>
        String.pad_trailing("F1", 12) <>
        "Support"
    )

    IO.puts(String.duplicate("-", 60))

    metrics.per_class
    |> Enum.sort()
    |> Enum.each(fn {label, class_metrics} ->
      IO.puts(
        String.pad_trailing(to_string(label), 15) <>
          String.pad_trailing(Float.round(class_metrics.precision, 3) |> to_string(), 12) <>
          String.pad_trailing(Float.round(class_metrics.recall, 3) |> to_string(), 12) <>
          String.pad_trailing(Float.round(class_metrics.f1, 3) |> to_string(), 12) <>
          to_string(class_metrics.support)
      )
    end)

    IO.puts(String.duplicate("-", 60))
    IO.puts("\\nOverall Accuracy: #{Float.round(metrics.accuracy, 3)}")
    IO.puts("Macro Avg F1: #{Float.round(metrics.f1, 3)}")

    :ok
  end

  ## Private Helpers

  defp unique_labels(gold, predicted) do
    (gold ++ predicted)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp true_positives(gold, predicted, label) do
    Enum.zip(gold, predicted)
    |> Enum.count(fn {g, p} -> g == label and p == label end)
  end

  defp false_positives(gold, predicted, label) do
    Enum.zip(gold, predicted)
    |> Enum.count(fn {g, p} -> g != label and p == label end)
  end

  defp false_negatives(gold, predicted, label) do
    Enum.zip(gold, predicted)
    |> Enum.count(fn {g, p} -> g == label and p != label end)
  end

  defp average_metrics(per_class_metrics, :macro) do
    # Simple average across classes
    values = Map.values(per_class_metrics)
    n = length(values)

    %{
      precision: Enum.sum(Enum.map(values, & &1.precision)) / n,
      recall: Enum.sum(Enum.map(values, & &1.recall)) / n,
      f1: Enum.sum(Enum.map(values, & &1.f1)) / n
    }
  end

  defp average_metrics(per_class_metrics, :micro) do
    # Aggregate counts then compute metrics
    values = Map.values(per_class_metrics)

    total_tp = Enum.sum(Enum.map(values, fn m -> m.support * m.recall end))
    total_support = Enum.sum(Enum.map(values, & &1.support))

    # For micro-averaging, precision = recall = F1
    score = if total_support > 0, do: total_tp / total_support, else: 0.0

    %{
      precision: score,
      recall: score,
      f1: score
    }
  end

  defp average_metrics(per_class_metrics, :weighted) do
    # Weighted by support
    values = Map.values(per_class_metrics)
    total_support = Enum.sum(Enum.map(values, & &1.support))

    if total_support == 0 do
      %{precision: 0.0, recall: 0.0, f1: 0.0}
    else
      %{
        precision:
          Enum.sum(Enum.map(values, fn m -> m.precision * m.support end)) / total_support,
        recall: Enum.sum(Enum.map(values, fn m -> m.recall * m.support end)) / total_support,
        f1: Enum.sum(Enum.map(values, fn m -> m.f1 * m.support end)) / total_support
      }
    end
  end
end
