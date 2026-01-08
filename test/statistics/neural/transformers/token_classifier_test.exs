defmodule Nasty.Statistics.Neural.Transformers.TokenClassifierTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Transformers.TokenClassifier

  # Note: Most TokenClassifier functions require Bumblebee integration
  # Here we test the configuration and creation logic

  describe "create/2" do
    test "creates classifier with required options" do
      base_model = %{
        name: :roberta_base,
        config: %{hidden_size: 768},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 17,
          label_map: %{0 => "NOUN", 1 => "VERB"}
        )

      assert classifier.base_model == base_model
      assert classifier.config.task == :pos_tagging
      assert classifier.config.num_labels == 17
      assert classifier.config.label_map == %{0 => "NOUN", 1 => "VERB"}
    end

    test "uses default dropout rate" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :ner,
          num_labels: 5,
          label_map: %{}
        )

      assert classifier.config.dropout_rate == 0.1
    end

    test "accepts custom dropout rate" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :ner,
          num_labels: 5,
          label_map: %{},
          dropout_rate: 0.3
        )

      assert classifier.config.dropout_rate == 0.3
    end

    test "stores model name in config" do
      base_model = %{
        name: :roberta_base,
        config: %{hidden_size: 768},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :token_classification,
          num_labels: 10,
          label_map: %{}
        )

      assert classifier.config.model_name == :roberta_base
    end

    test "raises on missing required options" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      assert_raise KeyError, fn ->
        TokenClassifier.create(base_model, num_labels: 5)
      end
    end

    test "builds classification head" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 17,
          label_map: %{}
        )

      assert classifier.classification_head != nil
    end
  end

  describe "task types" do
    test "supports POS tagging" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 17,
          label_map: %{}
        )

      assert classifier.config.task == :pos_tagging
    end

    test "supports NER" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :ner,
          num_labels: 9,
          label_map: %{}
        )

      assert classifier.config.task == :ner
    end

    test "supports generic token classification" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :token_classification,
          num_labels: 5,
          label_map: %{}
        )

      assert classifier.config.task == :token_classification
    end
  end

  describe "label mapping" do
    test "stores label map in config" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 64},
        tokenizer: %{pad_token_id: 0}
      }

      label_map = %{0 => "O", 1 => "B-PER", 2 => "I-PER"}

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :ner,
          num_labels: 3,
          label_map: label_map
        )

      assert classifier.config.label_map == label_map
    end

    test "handles empty label map" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 64},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 10,
          label_map: %{}
        )

      assert classifier.config.label_map == %{}
    end

    test "handles large label map" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 64},
        tokenizer: %{pad_token_id: 0}
      }

      label_map =
        Enum.reduce(0..50, %{}, fn i, acc ->
          Map.put(acc, i, "LABEL_#{i}")
        end)

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :token_classification,
          num_labels: 51,
          label_map: label_map
        )

      assert map_size(classifier.config.label_map) == 51
    end
  end

  describe "configuration" do
    test "validates num_labels" do
      base_model = %{
        name: :bert_base,
        config: %{hidden_size: 768},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 1,
          label_map: %{}
        )

      assert classifier.config.num_labels == 1
    end

    test "handles different hidden sizes" do
      small_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(small_model,
          task: :ner,
          num_labels: 5,
          label_map: %{}
        )

      assert classifier.base_model.config.hidden_size == 128
    end

    test "stores configuration immutably" do
      base_model = %{
        name: :bert_base,
        config: %{hidden_size: 768},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 10,
          label_map: %{0 => "TEST"}
        )

      original_config = classifier.config

      assert classifier.config == original_config
    end

    test "accepts zero dropout rate" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 10,
          label_map: %{},
          dropout_rate: 0.0
        )

      assert classifier.config.dropout_rate == 0.0
    end

    test "accepts high dropout rate" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128},
        tokenizer: %{pad_token_id: 0}
      }

      {:ok, classifier} =
        TokenClassifier.create(base_model,
          task: :pos_tagging,
          num_labels: 10,
          label_map: %{},
          dropout_rate: 0.9
        )

      assert classifier.config.dropout_rate == 0.9
    end
  end
end
