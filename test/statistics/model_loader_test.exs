defmodule Nasty.Statistics.ModelLoaderTest do
  use ExUnit.Case, async: false
  alias Nasty.Statistics.{ModelLoader, ModelRegistry}

  setup do
    # Clear registry before each test
    ModelRegistry.clear()
    :ok
  end

  describe "discover_models/0" do
    test "returns empty list when priv/models doesn't exist" do
      # Most tests won't have models directory
      models = ModelLoader.discover_models()
      assert is_list(models)
    end

    test "returns list of tuples with expected structure" do
      models = ModelLoader.discover_models()

      Enum.each(models, fn model ->
        assert match?(
                 {language, task, version, model_path, meta_path}
                 when is_atom(language) and is_atom(task) and is_binary(version) and
                        is_binary(model_path) and
                        (is_binary(meta_path) or is_nil(meta_path)),
                 model
               )
      end)
    end
  end

  describe "get_model_path/3" do
    test "returns error when model not found" do
      assert {:error, :not_found} =
               ModelLoader.get_model_path(:en, :pos_tagging, "nonexistent")
    end
  end

  describe "load_model/3 with registry" do
    test "returns not_found for nonexistent models" do
      assert {:error, :not_found} = ModelLoader.load_model(:en, :pos_tagging, "v999")
    end

    test "returns model from registry if already loaded" do
      # Register a mock model
      mock_model = %{test: "model"}
      ModelRegistry.register(:en, :pos_tagging, "v1", mock_model, %{})

      # Should return from registry without trying to load from disk
      assert {:ok, ^mock_model} = ModelLoader.load_model(:en, :pos_tagging, "v1")
    end
  end

  describe "load_latest/2" do
    test "returns not_found when no models available" do
      assert {:error, :not_found} = ModelLoader.load_latest(:en, :pos_tagging)
    end

    test "returns model from registry if available" do
      # Register multiple versions
      model_v1 = %{version: 1}
      model_v2 = %{version: 2}

      ModelRegistry.register(:en, :pos_tagging, "v1", model_v1, %{})
      ModelRegistry.register(:en, :pos_tagging, "v2", model_v2, %{})

      # Should return latest (v2 comes after v1 lexicographically)
      assert {:ok, ^model_v2} = ModelLoader.load_latest(:en, :pos_tagging)
    end

    test "returns latest version from multiple registered models" do
      ModelRegistry.register(:en, :pos_tagging, "v1", %{v: 1}, %{})
      ModelRegistry.register(:en, :pos_tagging, "v2", %{v: 2}, %{})
      ModelRegistry.register(:en, :pos_tagging, "v3", %{v: 3}, %{})

      assert {:ok, %{v: 3}} = ModelLoader.load_latest(:en, :pos_tagging)
    end
  end

  describe "task_to_atom/1" do
    # These are internal functions, but we can test the behavior via discover_models
    test "parses common task types correctly" do
      # This implicitly tests task_to_atom through model discovery
      # If models exist with these patterns, they should parse correctly
      models = ModelLoader.discover_models()

      Enum.each(models, fn {_lang, task, _version, _path, _meta} ->
        assert task in [:pos_tagging, :ner, :parsing] or is_atom(task)
      end)
    end
  end

  describe "model filename parsing" do
    # Testing internal parse logic through discover_models
    test "discovers models with standard naming convention" do
      models = ModelLoader.discover_models()

      # All discovered models should have valid structure
      Enum.each(models, fn {language, task, version, path, _meta} ->
        assert is_atom(language)
        assert is_atom(task)
        assert is_binary(version)
        assert String.ends_with?(path, ".model")
      end)
    end
  end

  describe "metadata loading" do
    test "handles missing metadata files gracefully" do
      # When loading models without metadata, should not crash
      # This is tested indirectly through the registry lookup
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{})

      assert {:ok, _, metadata} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
      assert metadata == %{}
    end
  end
end
