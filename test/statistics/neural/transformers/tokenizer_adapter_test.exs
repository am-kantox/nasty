defmodule Nasty.Statistics.Neural.Transformers.TokenizerAdapterTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Transformers.TokenizerAdapter

  # Note: tokenize_for_transformer requires Bumblebee integration
  # Here we test the alignment and utility functions that don't require Bumblebee

  describe "align_predictions/3" do
    test "aligns with first strategy" do
      subword_preds = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.8},
        %{label_id: 1, score: 0.7},
        %{label_id: 2, score: 0.85}
      ]

      alignment_map = %{
        0 => {0, 1},
        1 => {2, 3}
      }

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :first)

      assert match?([_, _], result)
      assert length(result) == 2
      assert List.first(result).label_id == 0
      assert List.first(result).score == 0.9
    end

    test "aligns with average strategy" do
      subword_preds = [
        %{label_id: 0, score: 0.9},
        %{label_id: 0, score: 0.7}
      ]

      alignment_map = %{0 => {0, 1}}

      result =
        TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :average)

      assert match?([_], result)
      first_pred = List.first(result)
      assert first_pred.score > 0.7 and first_pred.score < 0.9
      assert first_pred.label_id == 0
    end

    test "aligns with max strategy" do
      subword_preds = [
        %{label_id: 0, score: 0.5},
        %{label_id: 1, score: 0.95},
        %{label_id: 2, score: 0.7}
      ]

      alignment_map = %{0 => {0, 2}}

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :max)

      assert match?([_], result)
      first_pred = List.first(result)
      assert first_pred.score == 0.95
      assert first_pred.label_id == 1
    end

    test "handles single subword per token" do
      subword_preds = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.8}
      ]

      alignment_map = %{
        0 => {0, 0},
        1 => {1, 1}
      }

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :first)

      assert match?([_, _], result)
    end

    test "handles multiple subwords per token" do
      subword_preds = [
        %{label_id: 0, score: 0.9},
        %{label_id: 0, score: 0.8},
        %{label_id: 0, score: 0.7}
      ]

      alignment_map = %{0 => {0, 2}}

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :first)

      assert match?([_], result)
      assert List.first(result).label_id == 0
    end

    test "defaults to first strategy" do
      subword_preds = [%{label_id: 0, score: 0.9}]
      alignment_map = %{0 => {0, 0}}

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map)

      assert match?([_], result)
    end

    test "average strategy computes correct mean" do
      subword_preds = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.6},
        %{label_id: 2, score: 0.8}
      ]

      alignment_map = %{0 => {0, 2}}

      result =
        TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :average)

      assert match?([_], result)
      pred = List.first(result)
      expected_avg = (0.9 + 0.6 + 0.8) / 3
      assert_in_delta pred.score, expected_avg, 0.01
    end
  end

  describe "remove_special_tokens/2" do
    test "removes tokens marked as special" do
      predictions = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.8},
        %{label_id: 2, score: 0.7},
        %{label_id: 3, score: 0.6}
      ]

      special_token_mask = [true, false, false, true]

      result = TokenizerAdapter.remove_special_tokens(predictions, special_token_mask)

      assert match?([_, _], result)
      assert length(result) == 2
      assert Enum.at(result, 0).label_id == 1
      assert Enum.at(result, 1).label_id == 2
    end

    test "keeps all tokens when none are special" do
      predictions = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.8}
      ]

      special_token_mask = [false, false]

      result = TokenizerAdapter.remove_special_tokens(predictions, special_token_mask)

      assert length(result) == 2
    end

    test "removes all tokens when all are special" do
      predictions = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.8}
      ]

      special_token_mask = [true, true]

      result = TokenizerAdapter.remove_special_tokens(predictions, special_token_mask)

      assert result == []
    end

    test "handles empty lists" do
      result = TokenizerAdapter.remove_special_tokens([], [])

      assert result == []
    end

    test "preserves prediction order" do
      predictions = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.8},
        %{label_id: 2, score: 0.7}
      ]

      special_token_mask = [true, false, false]

      result = TokenizerAdapter.remove_special_tokens(predictions, special_token_mask)

      assert match?([%{label_id: 1}, %{label_id: 2}], result)
    end

    test "handles alternating special and real tokens" do
      predictions = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.8},
        %{label_id: 2, score: 0.7},
        %{label_id: 3, score: 0.6},
        %{label_id: 4, score: 0.5}
      ]

      special_token_mask = [true, false, true, false, true]

      result = TokenizerAdapter.remove_special_tokens(predictions, special_token_mask)

      assert match?([_, _], result)
      assert Enum.at(result, 0).label_id == 1
      assert Enum.at(result, 1).label_id == 3
    end
  end

  describe "alignment strategies" do
    setup do
      subword_preds = [
        %{label_id: 0, score: 0.9},
        %{label_id: 1, score: 0.6},
        %{label_id: 2, score: 0.8}
      ]

      alignment_map = %{0 => {0, 2}}

      {:ok, subword_preds: subword_preds, alignment_map: alignment_map}
    end

    test "first strategy uses first subword", %{subword_preds: preds, alignment_map: map} do
      result = TokenizerAdapter.align_predictions(preds, map, strategy: :first)

      assert match?([%{label_id: 0, score: 0.9}], result)
    end

    test "average strategy computes mean score", %{subword_preds: preds, alignment_map: map} do
      result = TokenizerAdapter.align_predictions(preds, map, strategy: :average)

      assert match?([_], result)
      pred = List.first(result)
      expected_avg = (0.9 + 0.6 + 0.8) / 3
      assert_in_delta pred.score, expected_avg, 0.01
      assert pred.label_id == 0
    end

    test "max strategy selects highest score", %{subword_preds: preds, alignment_map: map} do
      result = TokenizerAdapter.align_predictions(preds, map, strategy: :max)

      assert match?([%{score: 0.9}], result)
      assert List.first(result).label_id == 0
    end
  end

  describe "edge cases" do
    test "handles predictions with zero scores" do
      subword_preds = [
        %{label_id: 0, score: 0.0},
        %{label_id: 1, score: 0.0}
      ]

      alignment_map = %{0 => {0, 1}}

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :first)

      assert match?([_], result)
      assert List.first(result).score == 0.0
    end

    test "handles predictions with identical scores" do
      subword_preds = [
        %{label_id: 0, score: 0.5},
        %{label_id: 1, score: 0.5},
        %{label_id: 2, score: 0.5}
      ]

      alignment_map = %{0 => {0, 2}}

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :max)

      assert match?([_], result)
      assert List.first(result).score == 0.5
    end

    test "handles single prediction" do
      subword_preds = [%{label_id: 5, score: 0.99}]
      alignment_map = %{0 => {0, 0}}

      result = TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :first)

      assert match?([%{label_id: 5, score: 0.99}], result)
    end

    test "handles many tokens" do
      subword_preds =
        Enum.map(0..99, fn i ->
          %{label_id: rem(i, 10), score: 0.8 + rem(i, 20) / 100}
        end)

      alignment_map =
        Enum.reduce(0..9, %{}, fn i, acc ->
          Map.put(acc, i, {i * 10, i * 10 + 9})
        end)

      result =
        TokenizerAdapter.align_predictions(subword_preds, alignment_map, strategy: :average)

      assert match?([_, _, _, _, _, _, _, _, _, _], result)
      assert length(result) == 10
    end
  end
end
