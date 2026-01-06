defmodule Nasty.Language.English.TextClassifier do
  @moduledoc """
  Text classification using Naive Bayes algorithm.

  Implements a probabilistic classifier that learns from labeled training data
  and predicts classes for new documents based on extracted features.

  Uses:
  - Multinomial Naive Bayes for text classification
  - Laplace (add-one) smoothing for unseen features
  - Log probabilities to avoid numerical underflow
  """

  alias Nasty.AST.{Classification, ClassificationModel, Document}
  alias Nasty.Language.English.FeatureExtractor

  @doc """
  Trains a Naive Bayes classifier on labeled documents.

  ## Arguments

  - `training_data` - List of `{document, class}` tuples
  - `opts` - Training options

  ## Options

  - `:features` - Feature types to extract (default: `[:bow]`)
  - `:smoothing` - Smoothing parameter alpha (default: 1.0)
  - `:min_frequency` - Minimum feature frequency (default: 2)

  ## Examples

      iex> training_data = [
      ...>   {spam_doc1, :spam},
      ...>   {spam_doc2, :spam},
      ...>   {ham_doc1, :ham},
      ...>   {ham_doc2, :ham}
      ...> ]
      iex> model = TextClassifier.train(training_data, features: [:bow, :ngrams])
      %ClassificationModel{algorithm: :naive_bayes, classes: [:spam, :ham], ...}
  """
  @spec train([{Document.t(), atom()}], keyword()) :: ClassificationModel.t()
  def train(training_data, opts \\ []) do
    feature_types = Keyword.get(opts, :features, [:bow])
    smoothing = Keyword.get(opts, :smoothing, 1.0)

    # Extract features from all documents
    labeled_features =
      Enum.map(training_data, fn {document, class} ->
        features = FeatureExtractor.extract(document, Keyword.put(opts, :features, feature_types))
        vector = FeatureExtractor.to_vector(features, feature_types)
        {vector, class}
      end)

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
  Predicts the class for a document using a trained model.

  Returns a list of classification results sorted by confidence.

  ## Examples

      iex> {:ok, predictions} = TextClassifier.predict(model, document)
      {:ok, [
        %Classification{class: :spam, confidence: 0.85, ...},
        %Classification{class: :ham, confidence: 0.15, ...}
      ]}
  """
  @spec predict(ClassificationModel.t(), Document.t(), keyword()) ::
          {:ok, [Classification.t()]} | {:error, term()}
  def predict(%ClassificationModel{} = model, %Document{} = document, opts \\ []) do
    if ClassificationModel.trained?(model) do
      feature_types = model.metadata.feature_types || [:bow]

      # Extract features from document
      features = FeatureExtractor.extract(document, Keyword.put(opts, :features, feature_types))
      vector = FeatureExtractor.to_vector(features, feature_types)

      # Calculate log probabilities for each class
      # log P(class | features) = log P(class) + sum(log P(feature_i | class))
      class_log_probs =
        model.classes
        |> Enum.map(fn class ->
          prior = Map.get(model.class_priors, class, 1.0e-10)
          log_prior = :math.log(prior)

          # Sum log probabilities of features
          feature_log_sum =
            vector
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
      classifications =
        probabilities
        |> Enum.map(fn {class, prob} ->
          Classification.new(class, prob, document.language,
            features: vector,
            probabilities: probabilities
          )
        end)
        |> Classification.sort_by_confidence()

      {:ok, classifications}
    else
      {:error, :model_not_trained}
    end
  end

  @doc """
  Evaluates a model on test data.

  Returns accuracy and per-class metrics.

  ## Examples

      iex> test_data = [{doc1, :spam}, {doc2, :ham}, ...]
      iex> metrics = TextClassifier.evaluate(model, test_data)
      %{
        accuracy: 0.85,
        precision: %{spam: 0.9, ham: 0.8},
        recall: %{spam: 0.8, ham: 0.9},
        f1: %{spam: 0.85, ham: 0.85}
      }
  """
  @spec evaluate(ClassificationModel.t(), [{Document.t(), atom()}], keyword()) :: map()
  def evaluate(%ClassificationModel{} = model, test_data, opts \\ []) do
    predictions =
      Enum.map(test_data, fn {document, true_class} ->
        {:ok, [prediction | _]} = predict(model, document, opts)
        {prediction.class, true_class}
      end)

    # Calculate overall accuracy
    correct = Enum.count(predictions, fn {pred, actual} -> pred == actual end)
    accuracy = correct / length(predictions)

    # Calculate per-class metrics
    classes = model.classes

    per_class_metrics =
      classes
      |> Enum.map(fn class ->
        # True positives: predicted class and actual class both match
        tp = Enum.count(predictions, fn {pred, actual} -> pred == class and actual == class end)

        # False positives: predicted class but different actual
        fp = Enum.count(predictions, fn {pred, actual} -> pred == class and actual != class end)

        # False negatives: didn't predict class but was actual
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
