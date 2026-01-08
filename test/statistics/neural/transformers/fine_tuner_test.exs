defmodule Nasty.Statistics.Neural.Transformers.FineTunerTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Statistics.Neural.Transformers.FineTuner

  defp make_token(text, pos_tag_val \\ :noun) do
    span = Node.make_span({1, 0}, 0, {1, String.length(text)}, String.length(text))
    %Token{text: text, pos_tag: pos_tag_val, language: :en, span: span}
  end

  # Note: Most FineTuner functions require actual Bumblebee models and training infrastructure
  # These are integration tested. Here we test configuration and validation logic.

  describe "configuration validation" do
    test "validates empty training data" do
      base_model = %{config: %{}, tokenizer: %{}}
      result = FineTuner.fine_tune(base_model, [], :pos_tagging, num_labels: 3, label_map: %{})

      assert {:error, :empty_training_data} = result
    end

    test "validates invalid training data format" do
      base_model = %{config: %{}, tokenizer: %{}}

      result =
        FineTuner.fine_tune(base_model, [{:invalid}], :pos_tagging, num_labels: 1, label_map: %{})

      assert {:error, :invalid_training_data_format} = result
    end

    test "requires num_labels option" do
      base_model = %{config: %{hidden_size: 128}, tokenizer: %{}}
      training_data = [{[make_token("test")], [0]}]

      assert_raise KeyError, fn ->
        FineTuner.fine_tune(base_model, training_data, :pos_tagging, label_map: %{})
      end
    end

    test "requires label_map option" do
      base_model = %{config: %{hidden_size: 128}, tokenizer: %{}}
      training_data = [{[make_token("test")], [0]}]

      assert_raise KeyError, fn ->
        FineTuner.fine_tune(base_model, training_data, :pos_tagging, num_labels: 3)
      end
    end

    test "validates epochs configuration" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128, params: 10_000},
        tokenizer: %{pad_token_id: 0}
      }

      training_data = [{[make_token("test")], [0]}]

      result =
        FineTuner.fine_tune(base_model, training_data, :pos_tagging,
          epochs: 0,
          num_labels: 3,
          label_map: %{0 => "TEST"}
        )

      assert {:error, :invalid_epochs} = result
    end

    test "validates negative epochs" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128, params: 10_000},
        tokenizer: %{pad_token_id: 0}
      }

      training_data = [{[make_token("test")], [0]}]

      result =
        FineTuner.fine_tune(base_model, training_data, :pos_tagging,
          epochs: -1,
          num_labels: 3,
          label_map: %{0 => "TEST"}
        )

      assert {:error, :invalid_epochs} = result
    end

    test "validates batch_size configuration" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128, params: 10_000},
        tokenizer: %{pad_token_id: 0}
      }

      training_data = [{[make_token("test")], [0]}]

      result =
        FineTuner.fine_tune(base_model, training_data, :pos_tagging,
          batch_size: 0,
          num_labels: 3,
          label_map: %{0 => "TEST"}
        )

      assert {:error, :invalid_batch_size} = result
    end

    test "validates negative batch_size" do
      base_model = %{
        name: :test,
        config: %{hidden_size: 128, params: 10_000},
        tokenizer: %{pad_token_id: 0}
      }

      training_data = [{[make_token("test")], [0]}]

      result =
        FineTuner.fine_tune(base_model, training_data, :pos_tagging,
          batch_size: -5,
          num_labels: 3,
          label_map: %{0 => "TEST"}
        )

      assert {:error, :invalid_batch_size} = result
    end
  end

  describe "training data format" do
    # Note: Training requires actual Bumblebee infrastructure
    # Validation logic is tested in the configuration validation tests above
  end

  describe "task types" do
    # Note: Task execution requires actual Bumblebee infrastructure
    # Task types are accepted by the API (no validation errors occur for task names)
  end

  describe "few_shot_fine_tune/4" do
    test "validates empty dataset" do
      base_model = %{name: :test, config: %{hidden_size: 64, params: 1000}, tokenizer: %{}}

      result = FineTuner.few_shot_fine_tune(base_model, [], :ner, num_labels: 2, label_map: %{})

      assert {:error, :empty_training_data} = result
    end

    # Note: Non-empty dataset tests require actual Bumblebee infrastructure
  end

  describe "evaluate/2" do
    # Note: evaluate/2 requires actual tokenizer and model infrastructure
    # We skip detailed testing here as it would fail on tokenization
    # These are integration tested with real models
  end
end
