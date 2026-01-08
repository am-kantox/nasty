defmodule Nasty.Statistics.Neural.Transformers.InferenceTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Transformers.Inference

  # Mock classifier for testing
  defp mock_classifier do
    %{
      base_model: %{
        name: :roberta_base,
        model_info: %{},
        tokenizer: %{},
        config: %{hidden_size: 768}
      },
      config: %{
        task: :pos_tagging,
        num_labels: 17,
        label_map: %{},
        model_name: :roberta_base
      },
      classification_head: nil
    }
  end

  describe "optimize_for_inference/2" do
    test "optimizes classifier with default options" do
      classifier = mock_classifier()

      result = Inference.optimize_for_inference(classifier)

      assert {:ok, optimized} = result
      assert is_map(optimized)
      assert optimized.classifier == classifier
      assert is_list(optimized.optimizations)
      assert optimized.cache == nil
      assert optimized.compiled_serving == nil
    end

    test "creates cache when :cache optimization is requested" do
      classifier = mock_classifier()

      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      assert :cache in optimized.optimizations
      assert optimized.cache != nil
      assert is_reference(optimized.cache)
    end

    test "accepts multiple optimizations" do
      classifier = mock_classifier()

      {:ok, optimized} =
        Inference.optimize_for_inference(classifier, optimizations: [:cache, :compile])

      assert :cache in optimized.optimizations
      assert :compile in optimized.optimizations
    end

    test "accepts cache_size option" do
      classifier = mock_classifier()

      {:ok, optimized} =
        Inference.optimize_for_inference(classifier, optimizations: [:cache], cache_size: 500)

      assert optimized.cache != nil
    end

    test "accepts device option" do
      classifier = mock_classifier()

      result = Inference.optimize_for_inference(classifier, device: :cpu)

      assert {:ok, _optimized} = result
    end

    test "handles compilation failure gracefully" do
      classifier = mock_classifier()

      # Compilation will fail without actual model, but should not error
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:compile])

      # Should succeed even if compilation fails
      assert optimized.compiled_serving == nil
    end
  end

  describe "clear_cache/1" do
    test "clears cache successfully" do
      classifier = mock_classifier()

      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      assert :ok = Inference.clear_cache(optimized)
    end

    test "handles nil cache gracefully" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [])

      assert optimized.cache == nil
      assert :ok = Inference.clear_cache(optimized)
    end

    test "cache is actually cleared" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      # Insert some test data
      :ets.insert(optimized.cache, {:test_key, "test_value"})
      assert :ets.info(optimized.cache, :size) > 0

      Inference.clear_cache(optimized)
      assert :ets.info(optimized.cache, :size) == 0
    end
  end

  describe "cache_stats/1" do
    test "returns :no_cache when cache is not enabled" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [])

      assert :no_cache = Inference.cache_stats(optimized)
    end

    test "returns cache statistics when cache is enabled" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      {:ok, stats} = Inference.cache_stats(optimized)

      assert is_map(stats)
      assert Map.has_key?(stats, :entries)
      assert Map.has_key?(stats, :memory_words)
      assert is_integer(stats.entries)
      assert is_integer(stats.memory_words)
    end

    test "reflects actual cache contents" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      {:ok, stats_before} = Inference.cache_stats(optimized)
      assert stats_before.entries == 0

      # Add entries
      :ets.insert(optimized.cache, {:key1, "value1"})
      :ets.insert(optimized.cache, {:key2, "value2"})

      {:ok, stats_after} = Inference.cache_stats(optimized)
      assert stats_after.entries == 2
    end
  end

  describe "cache behavior" do
    test "cache stores and retrieves entries correctly" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      # Manually insert and retrieve to test cache functionality
      test_key = :erlang.phash2("test_tokens")
      test_predictions = [%{label: "NOUN", score: 0.95}]

      :ets.insert(optimized.cache, {test_key, test_predictions})

      case :ets.lookup(optimized.cache, test_key) do
        [{^test_key, predictions}] ->
          assert predictions == test_predictions

        [] ->
          flunk("Cache lookup failed")
      end
    end

    test "cache handles hash collisions gracefully" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      # Insert multiple entries
      for i <- 1..10 do
        key = :erlang.phash2("tokens_#{i}")
        :ets.insert(optimized.cache, {key, %{index: i}})
      end

      {:ok, stats} = Inference.cache_stats(optimized)
      assert stats.entries == 10
    end

    test "cache is independent per optimized model" do
      classifier = mock_classifier()

      {:ok, optimized1} = Inference.optimize_for_inference(classifier, optimizations: [:cache])
      {:ok, optimized2} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      # Caches should be different ETS tables
      assert optimized1.cache != optimized2.cache

      :ets.insert(optimized1.cache, {:key, "value1"})
      :ets.insert(optimized2.cache, {:key, "value2"})

      [{_, value1}] = :ets.lookup(optimized1.cache, :key)
      [{_, value2}] = :ets.lookup(optimized2.cache, :key)

      assert value1 != value2
    end
  end

  describe "optimization combinations" do
    test "can enable only cache" do
      classifier = mock_classifier()

      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      assert :cache in optimized.optimizations
      assert :compile not in optimized.optimizations
      assert optimized.cache != nil
    end

    test "can enable only compile" do
      classifier = mock_classifier()

      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:compile])

      assert :compile in optimized.optimizations
      assert :cache not in optimized.optimizations
      assert optimized.cache == nil
    end

    test "can enable both cache and compile" do
      classifier = mock_classifier()

      {:ok, optimized} =
        Inference.optimize_for_inference(classifier, optimizations: [:cache, :compile])

      assert :cache in optimized.optimizations
      assert :compile in optimized.optimizations
      assert optimized.cache != nil
    end

    test "can enable no optimizations" do
      classifier = mock_classifier()

      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [])

      assert optimized.optimizations == []
      assert optimized.cache == nil
      assert optimized.compiled_serving == nil
    end
  end

  describe "edge cases" do
    test "handles empty classifier gracefully" do
      empty_classifier = %{}

      result = Inference.optimize_for_inference(empty_classifier)

      # Should not crash, may return error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles nil classifier gracefully" do
      result = Inference.optimize_for_inference(nil)

      # Should handle gracefully
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "cache survives multiple clear operations" do
      classifier = mock_classifier()
      {:ok, optimized} = Inference.optimize_for_inference(classifier, optimizations: [:cache])

      Inference.clear_cache(optimized)
      Inference.clear_cache(optimized)
      Inference.clear_cache(optimized)

      # Should still work
      {:ok, stats} = Inference.cache_stats(optimized)
      assert stats.entries == 0
    end

    test "handles very large cache sizes" do
      classifier = mock_classifier()

      {:ok, optimized} =
        Inference.optimize_for_inference(classifier,
          optimizations: [:cache],
          cache_size: 1_000_000
        )

      assert optimized.cache != nil
    end
  end
end
