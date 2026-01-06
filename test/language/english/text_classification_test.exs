defmodule Nasty.Language.English.TextClassificationTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Classification, ClassificationModel}
  alias Nasty.Language.English
  alias Nasty.Language.English.{FeatureExtractor, TextClassifier}

  # Helper to create a simple document from text
  defp create_document(text) do
    {:ok, tokens} = English.tokenize(text)
    {:ok, tagged} = English.tag_pos(tokens)
    {:ok, document} = English.parse(tagged)
    document
  end

  describe "FeatureExtractor.extract/2" do
    test "extracts bag of words features" do
      document = create_document("The cat sat on the mat. The dog ran.")

      features = FeatureExtractor.extract(document, features: [:bow])

      assert is_map(features.bow)
      assert Map.has_key?(features.bow, "cat")
      assert Map.has_key?(features.bow, "dog")
      # Stop words should be filtered
      refute Map.has_key?(features.bow, "the")
    end

    test "extracts n-gram features" do
      document = create_document("The cat sat on the mat.")

      features = FeatureExtractor.extract(document, features: [:ngrams], ngram_size: 2)

      assert is_map(features.ngrams)
      # Should have bigrams
      assert map_size(features.ngrams) > 0
      # Bigrams are tuples of 2 words
      assert Enum.all?(Map.keys(features.ngrams), fn key -> tuple_size(key) == 2 end)
    end

    test "extracts POS pattern features" do
      document = create_document("The cat sat on the mat.")

      features = FeatureExtractor.extract(document, features: [:pos_patterns], ngram_size: 2)

      assert is_map(features.pos_patterns)
      assert map_size(features.pos_patterns) > 0
      # POS patterns are tuples of POS tags
      assert Enum.all?(Map.keys(features.pos_patterns), &is_tuple/1)
    end

    test "extracts syntactic features" do
      document = create_document("The cat sat. The dog ran and the bird flew.")

      features = FeatureExtractor.extract(document, features: [:syntactic])

      assert is_map(features.syntactic)
      assert Map.has_key?(features.syntactic, :sentence_structures)
      assert Map.has_key?(features.syntactic, :total_sentences)
      assert features.syntactic.total_sentences > 0
    end

    test "extracts entity features" do
      document = create_document("John Smith works at Google in California.")

      features = FeatureExtractor.extract(document, features: [:entities])

      assert is_map(features.entities)
      assert Map.has_key?(features.entities, :entity_counts)
      assert Map.has_key?(features.entities, :total_entities)
      assert is_float(features.entities.entity_density)
    end

    test "extracts lexical features" do
      document = create_document("The cat sat on the mat.")

      features = FeatureExtractor.extract(document, features: [:lexical])

      assert is_map(features.lexical)
      assert Map.has_key?(features.lexical, :total_tokens)
      assert Map.has_key?(features.lexical, :unique_tokens)
      assert Map.has_key?(features.lexical, :type_token_ratio)
      assert features.lexical.total_tokens > 0
      assert is_float(features.lexical.type_token_ratio)
    end

    test "extracts multiple feature types at once" do
      document = create_document("The cat sat on the mat.")

      features = FeatureExtractor.extract(document, features: [:bow, :ngrams, :lexical])

      assert Map.has_key?(features, :bow)
      assert Map.has_key?(features, :ngrams)
      assert Map.has_key?(features, :lexical)
    end

    test "respects min_frequency option" do
      document = create_document("cat cat dog")

      features = FeatureExtractor.extract(document, features: [:bow], min_frequency: 2)

      # "cat" appears twice, should be included
      assert Map.has_key?(features.bow, "cat")
      # "dog" appears once, should be filtered
      refute Map.has_key?(features.bow, "dog")
    end

    test "includes stop words when requested" do
      document = create_document("The cat sat on the mat.")

      features =
        FeatureExtractor.extract(document, features: [:bow], include_stop_words: true)

      # Stop words should be included
      assert Map.has_key?(features.bow, "the")
    end
  end

  describe "FeatureExtractor.to_vector/2" do
    test "converts features to vector representation" do
      document = create_document("cat dog cat")
      features = FeatureExtractor.extract(document, features: [:bow])

      vector = FeatureExtractor.to_vector(features, [:bow])

      assert is_map(vector)
      assert Enum.all?(Map.keys(vector), &is_binary/1)
      assert Enum.all?(Map.values(vector), &is_number/1)
    end
  end

  describe "ClassificationModel" do
    test "creates a new model" do
      model = ClassificationModel.new(:naive_bayes, [:spam, :ham])

      assert model.algorithm == :naive_bayes
      assert model.classes == [:spam, :ham]
      refute ClassificationModel.trained?(model)
    end

    test "checks if model is trained" do
      untrained = ClassificationModel.new(:naive_bayes, [:spam, :ham])
      refute ClassificationModel.trained?(untrained)

      trained =
        ClassificationModel.new(:naive_bayes, [:spam, :ham], class_priors: %{spam: 0.5, ham: 0.5})

      assert ClassificationModel.trained?(trained)
    end
  end

  describe "Classification" do
    test "creates a classification result" do
      classification = Classification.new(:spam, 0.85, :en)

      assert classification.class == :spam
      assert classification.confidence == 0.85
      assert classification.language == :en
    end

    test "sorts classifications by confidence" do
      classifications = [
        Classification.new(:low, 0.2, :en),
        Classification.new(:high, 0.9, :en),
        Classification.new(:mid, 0.6, :en)
      ]

      sorted = Classification.sort_by_confidence(classifications)

      assert Enum.map(sorted, & &1.class) == [:high, :mid, :low]
    end
  end

  describe "TextClassifier.train/2" do
    test "trains a binary classifier" do
      # Create training documents
      spam1 = create_document("win free money now click here")
      spam2 = create_document("congratulations you won a prize")
      ham1 = create_document("meeting scheduled for tomorrow at 3pm")
      ham2 = create_document("please review the attached document")

      training_data = [
        {spam1, :spam},
        {spam2, :spam},
        {ham1, :ham},
        {ham2, :ham}
      ]

      model = TextClassifier.train(training_data, features: [:bow])

      assert model.algorithm == :naive_bayes
      assert :spam in model.classes
      assert :ham in model.classes
      assert ClassificationModel.trained?(model)
      assert map_size(model.class_priors) == 2
      assert map_size(model.feature_probs) == 2
    end

    test "trains a multi-class classifier" do
      tech = create_document("artificial intelligence machine learning algorithm")
      sports = create_document("football team scored goal victory")
      politics = create_document("election vote government policy")

      training_data = [
        {tech, :tech},
        {sports, :sports},
        {politics, :politics}
      ]

      model = TextClassifier.train(training_data, features: [:bow])

      assert length(model.classes) == 3
      assert :tech in model.classes
      assert :sports in model.classes
      assert :politics in model.classes
    end
  end

  describe "TextClassifier.predict/3" do
    setup do
      # Train a simple spam classifier
      spam1 = create_document("win free money now")
      spam2 = create_document("congratulations you won")
      ham1 = create_document("meeting tomorrow at 3pm")
      ham2 = create_document("please review document")

      training_data = [
        {spam1, :spam},
        {spam2, :spam},
        {ham1, :ham},
        {ham2, :ham}
      ]

      model = TextClassifier.train(training_data, features: [:bow])
      {:ok, model: model}
    end

    test "predicts spam correctly", %{model: model} do
      test_doc = create_document("free money win now")

      {:ok, predictions} = TextClassifier.predict(model, test_doc)

      assert [top | _rest] = predictions
      assert top.class == :spam
      assert top.confidence > 0.5
    end

    test "predicts ham correctly", %{model: model} do
      test_doc = create_document("meeting scheduled tomorrow")

      {:ok, predictions} = TextClassifier.predict(model, test_doc)

      assert [top | _rest] = predictions
      assert top.class == :ham
      assert top.confidence > 0.5
    end

    test "returns all class probabilities", %{model: model} do
      test_doc = create_document("test document")

      {:ok, predictions} = TextClassifier.predict(model, test_doc)

      assert length(predictions) == 2
      assert Enum.all?(predictions, &match?(%Classification{}, &1))

      # Probabilities should sum to approximately 1.0
      total_prob = Enum.sum(Enum.map(predictions, & &1.confidence))
      assert_in_delta total_prob, 1.0, 0.01
    end

    test "returns error for untrained model" do
      model = ClassificationModel.new(:naive_bayes, [:spam, :ham])
      test_doc = create_document("test")

      assert {:error, :model_not_trained} = TextClassifier.predict(model, test_doc)
    end
  end

  describe "TextClassifier.evaluate/3" do
    test "evaluates model performance" do
      # Training data
      spam1 = create_document("win free money now")
      spam2 = create_document("congratulations you won")
      ham1 = create_document("meeting tomorrow at 3pm")
      ham2 = create_document("please review document")

      training_data = [
        {spam1, :spam},
        {spam2, :spam},
        {ham1, :ham},
        {ham2, :ham}
      ]

      model = TextClassifier.train(training_data, features: [:bow])

      # Test data (same as training for simplicity)
      test_data = training_data

      metrics = TextClassifier.evaluate(model, test_data)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :accuracy)
      assert Map.has_key?(metrics, :per_class)
      assert metrics.accuracy >= 0.0 and metrics.accuracy <= 1.0
      assert Map.has_key?(metrics.per_class, :spam)
      assert Map.has_key?(metrics.per_class, :ham)

      # Each class should have precision, recall, f1
      spam_metrics = metrics.per_class[:spam]
      assert Map.has_key?(spam_metrics, :precision)
      assert Map.has_key?(spam_metrics, :recall)
      assert Map.has_key?(spam_metrics, :f1)
    end
  end

  describe "English.train_classifier/2" do
    test "trains classifier via English API" do
      doc1 = create_document("positive happy good great")
      doc2 = create_document("negative bad terrible awful")

      training_data = [{doc1, :positive}, {doc2, :negative}]

      model = English.train_classifier(training_data)

      assert ClassificationModel.trained?(model)
      assert :positive in model.classes
      assert :negative in model.classes
    end
  end

  describe "English.classify/3" do
    test "classifies document via English API" do
      doc1 = create_document("positive happy good")
      doc2 = create_document("negative bad terrible")

      training_data = [{doc1, :positive}, {doc2, :negative}]
      model = English.train_classifier(training_data)

      test_doc = create_document("good happy")

      {:ok, predictions} = English.classify(test_doc, model)

      assert [top | _rest] = predictions
      assert top.class == :positive
    end
  end

  describe "English.extract_features/2" do
    test "extracts features via English API" do
      document = create_document("The cat sat on the mat.")

      features = English.extract_features(document, features: [:bow, :lexical])

      assert is_map(features)
      assert Map.has_key?(features, :bow)
      assert Map.has_key?(features, :lexical)
    end
  end

  describe "integration tests" do
    test "full classification pipeline" do
      # Create diverse training set
      training_texts = [
        {"This is great and wonderful", :positive},
        {"Excellent work very good", :positive},
        {"Amazing fantastic perfect", :positive},
        {"This is bad and terrible", :negative},
        {"Awful horrible worst", :negative},
        {"Disappointing poor quality", :negative}
      ]

      training_data =
        Enum.map(training_texts, fn {text, label} ->
          {create_document(text), label}
        end)

      # Train model
      model = English.train_classifier(training_data, features: [:bow])

      # Test predictions
      positive_test = create_document("wonderful excellent")
      negative_test = create_document("terrible awful")

      {:ok, pos_predictions} = English.classify(positive_test, model)
      {:ok, neg_predictions} = English.classify(negative_test, model)

      # Top prediction should match expected class
      assert hd(pos_predictions).class == :positive
      assert hd(neg_predictions).class == :negative
    end

    test "classification with multiple feature types" do
      doc1 = create_document("short text")
      doc2 = create_document("this is a much longer text with many more words")

      training_data = [{doc1, :short}, {doc2, :long}]

      model = English.train_classifier(training_data, features: [:bow, :lexical])

      test_doc = create_document("another short one")
      {:ok, predictions} = English.classify(test_doc, model)

      assert [top | _] = predictions
      assert top.class in [:short, :long]
    end
  end
end
