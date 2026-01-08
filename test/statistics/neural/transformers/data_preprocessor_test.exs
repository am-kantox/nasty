defmodule Nasty.Statistics.Neural.Transformers.DataPreprocessorTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Statistics.Neural.Transformers.DataPreprocessor

  defp make_token(text, pos_tag_val \\ :noun, opts \\ []) do
    span = Node.make_span({1, 0}, 0, {1, String.length(text)}, String.length(text))

    Map.merge(
      %Token{text: text, pos_tag: pos_tag_val, language: :en, span: span},
      Map.new(opts)
    )
  end

  # Note: prepare_batch/4 and process_sequence/5 require Bumblebee tokenizer integration
  # These are integration tested with actual transformer models

  describe "prepare_batch/4" do
    test "returns error for invalid input" do
      assert {:error, :invalid_input} = DataPreprocessor.prepare_batch(nil, %{}, %{})
      assert {:error, :invalid_input} = DataPreprocessor.prepare_batch("invalid", %{}, %{})
    end
  end

  describe "get_label/3" do
    test "extracts POS label" do
      token = make_token("cat", :noun)
      label_map = %{noun: 5, verb: 6}

      assert DataPreprocessor.get_label(token, label_map, :pos_tag) == 5
    end

    test "extracts entity_type label" do
      token = make_token("John", :propn, entity_type: :person)
      label_map = %{person: 10, location: 11}

      assert DataPreprocessor.get_label(token, label_map, :entity_type) == 10
    end

    test "returns default for unknown label" do
      token = make_token("test", :x)
      label_map = %{noun: 1}

      assert DataPreprocessor.get_label(token, label_map, :pos_tag) == 0
    end

    test "handles missing key in token" do
      token = make_token("test")
      label_map = %{noun: 1}

      assert DataPreprocessor.get_label(token, label_map, :nonexistent) == 0
    end
  end

  describe "align_labels/3" do
    test "aligns labels with first subword strategy" do
      labels = [1, 2, 3]
      word_ids = [nil, 0, 0, 1, 2, 2, nil]
      result = DataPreprocessor.align_labels(labels, word_ids, -100)

      assert result == [-100, 1, -100, 2, 3, -100, -100]
    end

    test "handles empty word_ids" do
      labels = []
      word_ids = []
      result = DataPreprocessor.align_labels(labels, word_ids, -100)

      assert result == []
    end

    test "handles special tokens only" do
      labels = []
      word_ids = [nil, nil, nil]
      result = DataPreprocessor.align_labels(labels, word_ids, -100)

      assert result == [-100, -100, -100]
    end

    test "handles single word with multiple subwords" do
      labels = [5]
      word_ids = [nil, 0, 0, 0, nil]
      result = DataPreprocessor.align_labels(labels, word_ids, -100)

      assert result == [-100, 5, -100, -100, -100]
    end

    test "uses custom pad_id" do
      labels = [1]
      word_ids = [nil, 0, nil]
      result = DataPreprocessor.align_labels(labels, word_ids, -999)

      assert result == [-999, 1, -999]
    end

    test "handles continuous word IDs" do
      labels = [10, 20, 30]
      word_ids = [0, 1, 2]
      result = DataPreprocessor.align_labels(labels, word_ids, -100)

      assert result == [10, 20, 30]
    end
  end

  describe "pad_or_truncate/3" do
    test "pads sequence when shorter than target" do
      sequence = [1, 2, 3]
      result = DataPreprocessor.pad_or_truncate(sequence, 5, 0)

      assert result == [1, 2, 3, 0, 0]
      assert match?([_, _, _, _, _], result)
    end

    test "truncates sequence when longer than target" do
      sequence = [1, 2, 3, 4, 5, 6]
      result = DataPreprocessor.pad_or_truncate(sequence, 3, 0)

      assert result == [1, 2, 3]
      assert match?([_, _, _], result)
    end

    test "returns unchanged when length matches target" do
      sequence = [1, 2, 3]
      result = DataPreprocessor.pad_or_truncate(sequence, 3, 0)

      assert result == [1, 2, 3]
    end

    test "uses custom pad value" do
      sequence = [1, 2]
      result = DataPreprocessor.pad_or_truncate(sequence, 5, -100)

      assert result == [1, 2, -100, -100, -100]
    end

    test "handles empty sequence" do
      sequence = []
      result = DataPreprocessor.pad_or_truncate(sequence, 3, 0)

      assert result == [0, 0, 0]
    end

    test "handles single element" do
      sequence = [42]
      result = DataPreprocessor.pad_or_truncate(sequence, 1, 0)

      assert result == [42]
    end

    test "handles large sequences" do
      sequence = Enum.to_list(1..1000)
      result = DataPreprocessor.pad_or_truncate(sequence, 100, 0)

      assert match?([_, _, _ | _], result)
      assert length(result) == 100
    end
  end

  describe "create_label_map/1" do
    test "creates label map from unique labels" do
      labels = [:noun, :verb, :adj]
      result = DataPreprocessor.create_label_map(labels)

      assert result == %{noun: 0, verb: 1, adj: 2}
    end

    test "handles duplicate labels" do
      labels = [:noun, :verb, :noun, :adj]
      result = DataPreprocessor.create_label_map(labels)

      assert map_size(result) == 3
      assert result.noun in [0, 1, 2]
    end

    test "returns empty map for empty list" do
      result = DataPreprocessor.create_label_map([])

      assert result == %{}
    end

    test "creates sequential indices" do
      labels = [:a, :b, :c, :d, :e]
      result = DataPreprocessor.create_label_map(labels)

      assert map_size(result) == 5
      values = Map.values(result)
      assert Enum.sort(values) == [0, 1, 2, 3, 4]
    end

    test "preserves label order for index assignment" do
      labels = [:z, :a, :m]
      result = DataPreprocessor.create_label_map(labels)

      assert result.z == 0
      assert result.a == 1
      assert result.m == 2
    end
  end

  describe "extract_labels/2" do
    test "extracts unique POS labels from token sequences" do
      tokens = [
        [make_token("The", :det), make_token("cat", :noun)],
        [make_token("runs", :verb), make_token("fast", :adv)]
      ]

      result = DataPreprocessor.extract_labels(tokens, :pos_tag)

      assert :det in result
      assert :noun in result
      assert :verb in result
      assert :adv in result
    end

    test "extracts entity_type labels" do
      tokens = [
        [make_token("John", :propn, entity_type: :person)],
        [make_token("Paris", :propn, entity_type: :location)]
      ]

      result = DataPreprocessor.extract_labels(tokens, :entity_type)

      assert :person in result
      assert :location in result
    end

    test "removes duplicates" do
      tokens = [
        [make_token("cat", :noun), make_token("dog", :noun)],
        [make_token("bird", :noun)]
      ]

      result = DataPreprocessor.extract_labels(tokens, :pos_tag)

      assert result == [:noun]
    end

    test "returns sorted labels" do
      tokens = [
        [make_token("runs", :verb)],
        [make_token("cat", :noun)],
        [make_token("quickly", :adv)]
      ]

      result = DataPreprocessor.extract_labels(tokens, :pos_tag)

      assert result == Enum.sort(result)
    end

    test "handles empty token sequences" do
      result = DataPreprocessor.extract_labels([], :pos_tag)

      assert result == []
    end

    test "handles nested empty lists" do
      result = DataPreprocessor.extract_labels([[], []], :pos_tag)

      assert result == []
    end

    test "handles mixed empty and non-empty sequences" do
      tokens = [
        [],
        [make_token("cat", :noun)],
        [],
        [make_token("run", :verb)]
      ]

      result = DataPreprocessor.extract_labels(tokens, :pos_tag)

      assert match?([_, _], result)
    end
  end
end
