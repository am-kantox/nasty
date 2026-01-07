defmodule Nasty.Operations.Classification.NaiveBayes do
  @moduledoc """
  Generic Naive Bayes classifier for text classification.

  Implements:
  - Multinomial Naive Bayes algorithm
  - Laplace (add-one) smoothing for unseen features
  - Log probabilities to avoid numerical underflow
  - Softmax for probability normalization
  """

  alias Nasty.AST.{Classification, ClassificationModel}

  @doc """
  Trains a Naive Bayes model from labeled feature vectors.

  ## Arguments
  - `labeled_features` - List of `{feature_vector, class}` tuples
  - `opts` - Training options

  ## Options
  - `:smoothing` - Laplace smoothing parameter alpha (default: 1.0)
  - `:feature_types` - List of feature types used (for metadata)

  ## Returns
  ClassificationModel struct with learned parameters
  """
  @spec train([{map(), atom()}], keyword()) :: ClassificationModel.t()
  def train(labeled_features, opts \\ []) do
    smoothing = Keyword.get(opts, :smoothing, 1.0)
    feature_types = Keyword.get(opts, :feature_types, [:bow])

    # Get unique classes
    classes = labeled_features |> Enum.map(fn {_f, c} -> c end) |> Enum.uniq()

    # Build vocabulary from all features
    vocabulary =
      labeled_features
      |> Enum.flat_map(fn {features, _class} -> Map.keys(features) end)
      |> MapSet.new()

    # Calculate class priors: P(class) = count(class) / total_documents
    total_docs = length(labeled_features)

    class_priors =
      classes
      |> Enum.map(fn class ->
        count = Enum.count(labeled_features, fn {_, c} -> c == class end)
        {class, count / total_docs}
      end)
      |> Enum.into(%{})

    # Calculate feature probabilities for each class
    # P(feature | class) = (count(feature in class) + alpha) / (total features in class + alpha * |V|)
    feature_probs =
      classes
      |> Enum.map(fn class ->
        class_docs = Enum.filter(labeled_features, fn {_, c} -> c == class end)

        # Count features in this class
        feature_counts =
          class_docs
          |> Enum.flat_map(fn {features, _} ->
            Enum.map(features, fn {feature, count} -> {feature, count} end)
          end)
          |> Enum.reduce(%{}, fn {feature, count}, acc ->
            Map.update(acc, feature, count, &(&1 + count))
          end)

        # Total feature count in class
        total_count = feature_counts |> Map.values() |> Enum.sum()

        # Calculate probabilities with Laplace smoothing
        vocab_size = MapSet.size(vocabulary)

        probs =
          vocabulary
          |> Enum.map(fn feature ->
            count = Map.get(feature_counts, feature, 0)
            prob = (count + smoothing) / (total_count + smoothing * vocab_size)
            {feature, prob}
          end)
          |> Enum.into(%{})

        {class, probs}
      end)
      |> Enum.into(%{})

    ClassificationModel.new(:naive_bayes, classes,
      class_priors: class_priors,
      feature_probs: feature_probs,
      vocabulary: vocabulary,
      metadata: %{
        training_examples: total_docs,
        feature_types: feature_types,
        smoothing: smoothing,
        vocab_size: MapSet.size(vocabulary)
      }
    )
  end

  @doc """
  Predicts class probabilities for a feature vector.

  Uses log probabilities and softmax for numerical stability.

  ## Returns
  List of Classification structs sorted by confidence (highest first)
  """
  @spec predict(ClassificationModel.t(), map(), atom()) :: [Classification.t()]
  def predict(%ClassificationModel{} = model, feature_vector, language) do
    # Calculate log probabilities for each class
    # log P(class | features) = log P(class) + sum(log P(feature_i | class))
    class_log_probs =
      model.classes
      |> Enum.map(fn class ->
        prior = Map.get(model.class_priors, class, 1.0e-10)
        log_prior = :math.log(prior)

        # Sum log probabilities of features
        feature_log_sum =
          feature_vector
          |> Enum.map(fn {feature, count} ->
            prob = get_in(model.feature_probs, [class, feature]) || 1.0e-10
            count * :math.log(prob)
          end)
          |> Enum.sum()

        {class, log_prior + feature_log_sum}
      end)
      |> Enum.into(%{})

    # Convert log probabilities to probabilities using softmax
    max_log_prob = class_log_probs |> Map.values() |> Enum.max()

    # Subtract max for numerical stability
    exp_probs =
      class_log_probs
      |> Enum.map(fn {class, log_prob} ->
        {class, :math.exp(log_prob - max_log_prob)}
      end)
      |> Enum.into(%{})

    total = exp_probs |> Map.values() |> Enum.sum()

    # Normalize to probabilities
    probabilities =
      exp_probs
      |> Enum.map(fn {class, exp_prob} ->
        {class, exp_prob / total}
      end)
      |> Enum.into(%{})

    # Create classification results
    probabilities
    |> Enum.map(fn {class, prob} ->
      Classification.new(class, prob, language,
        features: feature_vector,
        probabilities: probabilities
      )
    end)
    |> Classification.sort_by_confidence()
  end

  @doc """
  Evaluates a model on test data.

  Returns accuracy and per-class precision, recall, and F1 metrics.
  """
  @spec evaluate(ClassificationModel.t(), [{map(), atom()}], atom()) :: map()
  def evaluate(%ClassificationModel{} = model, test_data, language) do
    predictions =
      Enum.map(test_data, fn {feature_vector, true_class} ->
        [prediction | _] = predict(model, feature_vector, language)
        {prediction.class, true_class}
      end)

    # Calculate overall accuracy
    correct = Enum.count(predictions, fn {pred, actual} -> pred == actual end)
    accuracy = correct / length(predictions)

    # Calculate per-class metrics
    per_class_metrics =
      model.classes
      |> Enum.map(fn class ->
        # True positives
        tp = Enum.count(predictions, fn {pred, actual} -> pred == class and actual == class end)
        # False positives
        fp = Enum.count(predictions, fn {pred, actual} -> pred == class and actual != class end)
        # False negatives
        fn_count =
          Enum.count(predictions, fn {pred, actual} -> pred != class and actual == class end)

        precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
        recall = if tp + fn_count > 0, do: tp / (tp + fn_count), else: 0.0

        f1 =
          if precision + recall > 0,
            do: 2 * precision * recall / (precision + recall),
            else: 0.0

        {class,
         %{
           precision: precision,
           recall: recall,
           f1: f1,
           support: Enum.count(test_data, fn {_, c} -> c == class end)
         }}
      end)
      |> Enum.into(%{})

    %{
      accuracy: accuracy,
      per_class: per_class_metrics,
      total_examples: length(test_data),
      correct_predictions: correct
    }
  end
end
