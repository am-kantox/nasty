defmodule Nasty.Language.English.TextClassifier do
  @moduledoc """
  English text classification using Naive Bayes.

  Thin wrapper around generic Naive Bayes classifier with English-specific
  feature extraction.
  """

  alias Nasty.AST.{Classification, ClassificationModel, Document}
  alias Nasty.Language.English.FeatureExtractor
  alias Nasty.Operations.Classification.NaiveBayes

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

    # Extract features from all documents
    labeled_features =
      Enum.map(training_data, fn {document, class} ->
        features = FeatureExtractor.extract(document, Keyword.put(opts, :features, feature_types))
        vector = FeatureExtractor.to_vector(features, feature_types)
        {vector, class}
      end)

    # Delegate to generic Naive Bayes
    NaiveBayes.train(labeled_features, Keyword.put(opts, :feature_types, feature_types))
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

      # Delegate to generic Naive Bayes
      classifications = NaiveBayes.predict(model, vector, document.language)

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
    feature_types = model.metadata.feature_types || [:bow]

    # Extract features from test documents
    labeled_features =
      Enum.map(test_data, fn {document, class} ->
        features = FeatureExtractor.extract(document, Keyword.put(opts, :features, feature_types))
        vector = FeatureExtractor.to_vector(features, feature_types)
        {vector, class}
      end)

    # Get language from first document
    language =
      case test_data do
        [{doc, _} | _] -> doc.language
        _ -> :en
      end

    # Delegate to generic Naive Bayes
    NaiveBayes.evaluate(model, labeled_features, language)
  end
end
