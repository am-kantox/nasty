defmodule Nasty.Statistics.Neural.Transformers.CacheManagerTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Transformers.CacheManager

  @test_cache_dir "test/tmp/transformer_cache"

  setup do
    # Clean up test cache directory before and after tests
    File.rm_rf!(@test_cache_dir)
    File.mkdir_p!(@test_cache_dir)

    on_exit(fn ->
      File.rm_rf!(@test_cache_dir)
    end)

    {:ok, cache_dir: @test_cache_dir}
  end

  describe "get_cached_model/2" do
    test "returns :not_found for non-existent model", %{cache_dir: cache_dir} do
      assert :not_found = CacheManager.get_cached_model(:roberta_base, cache_dir)
    end

    test "returns :not_found when model directory exists but missing required files", %{
      cache_dir: cache_dir
    } do
      model_dir = Path.join(cache_dir, "roberta-base")
      File.mkdir_p!(model_dir)

      # Create partial model (missing required files)
      File.write!(Path.join(model_dir, "model.safetensors"), "dummy")

      assert :not_found = CacheManager.get_cached_model(:roberta_base, cache_dir)
    end

    test "returns {:ok, path} when model is properly cached", %{cache_dir: cache_dir} do
      model_dir = Path.join(cache_dir, "roberta-base")
      File.mkdir_p!(model_dir)

      # Create required files
      File.write!(Path.join(model_dir, "config.json"), "{}")
      File.write!(Path.join(model_dir, "tokenizer.json"), "{}")

      assert {:ok, ^cache_dir} = CacheManager.get_cached_model(:roberta_base, cache_dir)
    end
  end

  describe "register_cached_model/3" do
    test "registers a model successfully", %{cache_dir: cache_dir} do
      assert :ok = CacheManager.register_cached_model(:roberta_base, cache_dir)
    end

    test "registers model with version", %{cache_dir: cache_dir} do
      assert :ok = CacheManager.register_cached_model(:roberta_base, cache_dir, version: "v1.0")
    end

    test "creates cache index file", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir)

      cache_index = Path.join(cache_dir, ".cache_index.json")
      assert File.exists?(cache_index)
    end

    test "updates existing model entry", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir, version: "v1.0")
      CacheManager.register_cached_model(:roberta_base, cache_dir, version: "v2.0")

      models = CacheManager.list_cached_models(cache_dir)
      assert length(models) == 1
      assert hd(models).version == "v2.0"
    end
  end

  describe "list_cached_models/1" do
    test "returns empty list when no models cached", %{cache_dir: cache_dir} do
      assert [] = CacheManager.list_cached_models(cache_dir)
    end

    test "returns list of cached models", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir)
      CacheManager.register_cached_model(:bert_base_cased, cache_dir)

      models = CacheManager.list_cached_models(cache_dir)
      assert length(models) == 2

      model_names = Enum.map(models, & &1.model_name)
      assert :roberta_base in model_names
      assert :bert_base_cased in model_names
    end

    test "returns models with complete metadata", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir, version: "v1.0")

      [model] = CacheManager.list_cached_models(cache_dir)

      assert model.model_name == :roberta_base
      assert is_binary(model.path)
      assert is_integer(model.size_bytes)
      assert model.size_bytes >= 0
      assert %DateTime{} = model.downloaded_at
      assert model.version == "v1.0"
    end

    test "handles non-existent cache directory", %{cache_dir: _cache_dir} do
      non_existent_dir = "test/tmp/non_existent"
      assert [] = CacheManager.list_cached_models(non_existent_dir)
    end
  end

  describe "clear_cache/2" do
    test "clears specific model", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir)
      CacheManager.register_cached_model(:bert_base_cased, cache_dir)

      assert :ok = CacheManager.clear_cache(:roberta_base, cache_dir)

      models = CacheManager.list_cached_models(cache_dir)
      assert length(models) == 1
      assert hd(models).model_name == :bert_base_cased
    end

    test "clears all models with :all", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir)
      CacheManager.register_cached_model(:bert_base_cased, cache_dir)

      assert :ok = CacheManager.clear_cache(:all, cache_dir)
      refute File.exists?(cache_dir)
    end

    test "handles clearing non-existent model", %{cache_dir: cache_dir} do
      # Should not error even if model doesn't exist
      result = CacheManager.clear_cache(:nonexistent_model, cache_dir)
      assert :ok = result
    end
  end

  describe "cache_size/1" do
    test "returns 0 for empty cache", %{cache_dir: cache_dir} do
      assert {:ok, 0} = CacheManager.cache_size(cache_dir)
    end

    test "returns 0 for non-existent directory", %{cache_dir: _cache_dir} do
      assert {:ok, 0} = CacheManager.cache_size("test/tmp/non_existent")
    end

    test "calculates size correctly", %{cache_dir: cache_dir} do
      # Create some test files
      test_file = Path.join(cache_dir, "test.txt")
      File.write!(test_file, String.duplicate("a", 1000))

      {:ok, size} = CacheManager.cache_size(cache_dir)
      assert size >= 1000
    end

    test "includes nested files in calculation", %{cache_dir: cache_dir} do
      nested_dir = Path.join(cache_dir, "models/roberta-base")
      File.mkdir_p!(nested_dir)
      File.write!(Path.join(nested_dir, "model.bin"), String.duplicate("x", 5000))

      {:ok, size} = CacheManager.cache_size(cache_dir)
      assert size >= 5000
    end
  end

  describe "JSON serialization" do
    test "serializes and deserializes model entries correctly", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir, version: "v1.0")

      [model] = CacheManager.list_cached_models(cache_dir)

      # Check that atom model_name is preserved
      assert is_atom(model.model_name)
      assert model.model_name == :roberta_base

      # Check that datetime is properly converted
      assert %DateTime{} = model.downloaded_at
    end

    test "handles multiple models with different metadata", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:roberta_base, cache_dir, version: "v1.0")
      CacheManager.register_cached_model(:bert_base_cased, cache_dir, version: "v2.0")
      CacheManager.register_cached_model(:distilbert_base, cache_dir, version: "latest")

      models = CacheManager.list_cached_models(cache_dir)
      assert length(models) == 3

      versions = Enum.map(models, & &1.version)
      assert "v1.0" in versions
      assert "v2.0" in versions
      assert "latest" in versions
    end

    test "handles invalid JSON gracefully", %{cache_dir: cache_dir} do
      cache_index = Path.join(cache_dir, ".cache_index.json")
      File.write!(cache_index, "invalid json{}")

      # Should return empty list rather than crashing
      assert [] = CacheManager.list_cached_models(cache_dir)
    end
  end

  describe "edge cases" do
    test "handles model names with underscores", %{cache_dir: cache_dir} do
      CacheManager.register_cached_model(:xlm_roberta_base, cache_dir)

      models = CacheManager.list_cached_models(cache_dir)
      assert length(models) == 1
      assert hd(models).model_name == :xlm_roberta_base
    end

    test "handles very large cache directories", %{cache_dir: cache_dir} do
      # Create many small files to simulate large cache
      for i <- 1..10 do
        file = Path.join(cache_dir, "file_#{i}.txt")
        File.write!(file, "content")
      end

      {:ok, size} = CacheManager.cache_size(cache_dir)
      assert size > 0
    end

    test "concurrent model registration", %{cache_dir: cache_dir} do
      # Register models concurrently
      tasks =
        for model <- [:bert_base_cased, :roberta_base, :distilbert_base] do
          Task.async(fn ->
            CacheManager.register_cached_model(model, cache_dir)
          end)
        end

      Enum.each(tasks, &Task.await/1)

      models = CacheManager.list_cached_models(cache_dir)
      assert length(models) == 3
    end
  end
end
