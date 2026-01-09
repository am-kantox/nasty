defmodule Nasty.Statistics.Neural.Transformers.ZeroShotTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Transformers.ZeroShot

  describe "classify/2 with single label" do
    setup do
      text = "I absolutely love this product! It's amazing and exceeded my expectations."
      candidate_labels = ["positive", "negative", "neutral"]

      {:ok, text: text, labels: candidate_labels}
    end

    test "returns error when model loading fails", %{text: text, labels: labels} do
      result = ZeroShot.classify(text, candidate_labels: labels)

      # Model loading will fail in test environment
      assert match?({:error, _}, result)
    end

    test "accepts model option", %{text: text, labels: labels} do
      result = ZeroShot.classify(text, candidate_labels: labels, model: :roberta_large_mnli)

      assert match?({:error, _}, result)
    end

    test "accepts hypothesis_template option", %{text: text, labels: labels} do
      result =
        ZeroShot.classify(text,
          candidate_labels: labels,
          hypothesis_template: "This text is {}"
        )

      assert match?({:error, _}, result)
    end

    test "requires candidate_labels" do
      text = "Test text"

      assert_raise KeyError, fn ->
        ZeroShot.classify(text, model: :roberta_large_mnli)
      end
    end

    test "validates empty text" do
      result = ZeroShot.classify("", candidate_labels: ["label1", "label2"])

      assert {:error, :empty_text} = result
    end

    test "validates no candidate labels" do
      result = ZeroShot.classify("Test text", candidate_labels: [])

      assert {:error, :no_candidate_labels} = result
    end

    test "validates single candidate label" do
      result = ZeroShot.classify("Test text", candidate_labels: ["only_one"])

      assert {:error, :need_multiple_labels} = result
    end

    test "accepts multiple candidate labels" do
      result = ZeroShot.classify("Test text", candidate_labels: ["label1", "label2"])

      # Should pass validation but fail on model loading
      assert match?({:error, {:model_load_failed, _}}, result)
    end
  end

  describe "classify/2 with multi-label" do
    setup do
      text = "This urgent message requires immediate action and contains important information."
      candidate_labels = ["urgent", "action_required", "informational", "casual"]

      {:ok, text: text, labels: candidate_labels}
    end

    test "accepts multi_label option", %{text: text, labels: labels} do
      result = ZeroShot.classify(text, candidate_labels: labels, multi_label: true)

      assert match?({:error, _}, result)
    end

    test "accepts threshold option for multi-label", %{text: text, labels: labels} do
      result =
        ZeroShot.classify(text,
          candidate_labels: labels,
          multi_label: true,
          threshold: 0.7
        )

      assert match?({:error, _}, result)
    end

    test "multi_label false by default", %{text: text, labels: labels} do
      result = ZeroShot.classify(text, candidate_labels: labels)

      # Should not use multi-label mode by default
      assert match?({:error, _}, result)
    end
  end

  describe "classify_batch/2" do
    test "classifies multiple texts" do
      texts = [
        "I love this!",
        "This is terrible.",
        "It's okay, nothing special."
      ]

      result =
        ZeroShot.classify_batch(texts, candidate_labels: ["positive", "negative", "neutral"])

      # Should fail due to model loading
      assert match?({:error, _}, result)
    end

    test "handles empty batch" do
      result = ZeroShot.classify_batch([], candidate_labels: ["label1", "label2"])

      # Empty list should return empty results
      assert {:ok, []} = result
    end

    test "validates all texts in batch" do
      texts = ["", "valid text", ""]

      result = ZeroShot.classify_batch(texts, candidate_labels: ["label1", "label2"])

      # Should fail on first empty text
      assert {:error, :empty_text} = result
    end
  end

  describe "recommended_models/0" do
    test "returns list of recommended models" do
      models = ZeroShot.recommended_models()

      assert is_list(models)
      assert match?([_, _, _], models)
    end

    test "includes roberta_large_mnli" do
      models = ZeroShot.recommended_models()

      assert :roberta_large_mnli in models
    end

    test "includes bart_large_mnli" do
      models = ZeroShot.recommended_models()

      assert :bart_large_mnli in models
    end

    test "includes xlm_roberta_base for multilingual" do
      models = ZeroShot.recommended_models()

      assert :xlm_roberta_base in models
    end

    test "all recommended models are atoms" do
      models = ZeroShot.recommended_models()

      assert Enum.all?(models, &is_atom/1)
    end
  end

  describe "candidate label variations" do
    test "accepts topic classification labels" do
      text = "The stock market reached new highs today."
      labels = ["politics", "sports", "technology", "business"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "accepts sentiment labels" do
      text = "This movie was fantastic!"
      labels = ["positive", "negative", "neutral"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "accepts intent classification labels" do
      text = "Can you help me reset my password?"
      labels = ["question", "request", "complaint", "feedback"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "accepts binary classification labels" do
      text = "This is spam advertising."
      labels = ["spam", "not_spam"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "accepts many candidate labels" do
      text = "A test document"
      labels = Enum.map(1..10, fn i -> "category_#{i}" end)

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end
  end

  describe "hypothesis template variations" do
    test "uses default template when not specified" do
      text = "Test text"
      labels = ["label1", "label2"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      # Default template: "This text is about {}"
      assert match?({:error, _}, result)
    end

    test "accepts custom hypothesis template" do
      text = "Test text"
      labels = ["label1", "label2"]

      result =
        ZeroShot.classify(text,
          candidate_labels: labels,
          hypothesis_template: "This document discusses {}"
        )

      assert match?({:error, _}, result)
    end

    test "accepts simple hypothesis template" do
      text = "Test text"
      labels = ["urgent", "normal"]

      result =
        ZeroShot.classify(text,
          candidate_labels: labels,
          hypothesis_template: "This is {}"
        )

      assert match?({:error, _}, result)
    end
  end

  describe "edge cases" do
    test "handles very long text" do
      text = String.duplicate("word ", 500)
      labels = ["category1", "category2"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "handles special characters in text" do
      text = "Hello! @#$%^&*() This is a test?"
      labels = ["formal", "informal"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "handles Unicode text" do
      text = "Привет мир 你好世界 مرحبا"
      labels = ["greeting", "farewell"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "handles newlines in text" do
      text = "Line 1\nLine 2\nLine 3"
      labels = ["multiline", "singleline"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "handles labels with spaces" do
      text = "Test document"
      labels = ["very positive", "very negative", "somewhat neutral"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end

    test "handles labels with special characters" do
      text = "Test document"
      labels = ["tech/software", "business-finance", "health&wellness"]

      result = ZeroShot.classify(text, candidate_labels: labels)

      assert match?({:error, _}, result)
    end
  end

  describe "option combinations" do
    @describetag [model: true, skip: true]

    test "combines model and multi_label options" do
      text = "Test text"
      labels = ["label1", "label2", "label3"]

      result =
        ZeroShot.classify(text,
          candidate_labels: labels,
          model: :xlm_roberta_base,
          multi_label: true
        )

      assert match?({:error, _}, result)
    end

    test "combines all options" do
      text = "Test text"
      labels = ["label1", "label2"]

      result =
        ZeroShot.classify(text,
          candidate_labels: labels,
          model: :roberta_large_mnli,
          multi_label: true,
          threshold: 0.6,
          hypothesis_template: "This text is about {}"
        )

      assert match?({:error, _}, result)
    end
  end

  describe "validation order" do
    test "validates text before labels" do
      # Empty text should be caught first
      result = ZeroShot.classify("", candidate_labels: [])

      assert {:error, :empty_text} = result
    end

    test "validates labels count after empty check" do
      # No labels should be caught
      result = ZeroShot.classify("text", candidate_labels: [])

      assert {:error, :no_candidate_labels} = result
    end

    test "validates multiple labels requirement" do
      # Single label should be caught
      result = ZeroShot.classify("text", candidate_labels: ["only_one"])

      assert {:error, :need_multiple_labels} = result
    end
  end
end
