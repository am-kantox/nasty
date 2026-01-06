defmodule Nasty.Statistics.ModelRegistryTest do
  use ExUnit.Case, async: true
  alias Nasty.Statistics.ModelRegistry

  setup do
    # Clear registry before each test
    ModelRegistry.clear()
    :ok
  end

  describe "register/5" do
    test "registers a model with metadata" do
      model = %{test: "model"}
      metadata = %{accuracy: 0.95}

      assert :ok = ModelRegistry.register(:en, :pos_tagging, "v1", model, metadata)
    end

    test "overwrites existing model with same key" do
      model1 = %{version: 1}
      model2 = %{version: 2}

      ModelRegistry.register(:en, :pos_tagging, "v1", model1, %{})
      ModelRegistry.register(:en, :pos_tagging, "v1", model2, %{})

      assert {:ok, ^model2, _} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
    end
  end

  describe "lookup/3" do
    test "returns model and metadata when found" do
      model = %{test: "model"}
      metadata = %{accuracy: 0.95, f1: 0.94}

      ModelRegistry.register(:en, :pos_tagging, "v1", model, metadata)

      assert {:ok, ^model, ^metadata} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
    end

    test "returns error when model not found" do
      assert {:error, :not_found} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
    end

    test "distinguishes between different languages" do
      model_en = %{lang: :en}
      model_es = %{lang: :es}

      ModelRegistry.register(:en, :pos_tagging, "v1", model_en, %{})
      ModelRegistry.register(:es, :pos_tagging, "v1", model_es, %{})

      assert {:ok, ^model_en, _} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
      assert {:ok, ^model_es, _} = ModelRegistry.lookup(:es, :pos_tagging, "v1")
    end

    test "distinguishes between different tasks" do
      model_pos = %{task: :pos}
      model_ner = %{task: :ner}

      ModelRegistry.register(:en, :pos_tagging, "v1", model_pos, %{})
      ModelRegistry.register(:en, :ner, "v1", model_ner, %{})

      assert {:ok, ^model_pos, _} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
      assert {:ok, ^model_ner, _} = ModelRegistry.lookup(:en, :ner, "v1")
    end

    test "distinguishes between different versions" do
      model_v1 = %{version: 1}
      model_v2 = %{version: 2}

      ModelRegistry.register(:en, :pos_tagging, "v1", model_v1, %{})
      ModelRegistry.register(:en, :pos_tagging, "v2", model_v2, %{})

      assert {:ok, ^model_v1, _} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
      assert {:ok, ^model_v2, _} = ModelRegistry.lookup(:en, :pos_tagging, "v2")
    end
  end

  describe "list/0" do
    test "returns empty list when no models registered" do
      assert [] = ModelRegistry.list()
    end

    test "returns all registered models" do
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{accuracy: 0.95})
      ModelRegistry.register(:en, :pos_tagging, "v2", %{}, %{accuracy: 0.96})
      ModelRegistry.register(:es, :ner, "v1", %{}, %{f1: 0.85})

      models = ModelRegistry.list()

      assert match?([_, _, _], models)
      assert {:en, :pos_tagging, "v1", %{accuracy: 0.95}} in models
      assert {:en, :pos_tagging, "v2", %{accuracy: 0.96}} in models
      assert {:es, :ner, "v1", %{f1: 0.85}} in models
    end

    test "returns sorted list" do
      ModelRegistry.register(:es, :ner, "v1", %{}, %{})
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{})
      ModelRegistry.register(:ca, :pos_tagging, "v1", %{}, %{})

      models = ModelRegistry.list()

      # Should be sorted by language, task, version
      assert match?([{:ca, _, _, _}, {:en, _, _, _}, {:es, _, _, _}], models)
    end
  end

  describe "list_versions/2" do
    test "returns empty list when no models for language/task" do
      assert [] = ModelRegistry.list_versions(:en, :pos_tagging)
    end

    test "returns all versions for language and task" do
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{accuracy: 0.95})
      ModelRegistry.register(:en, :pos_tagging, "v2", %{}, %{accuracy: 0.96})
      ModelRegistry.register(:en, :ner, "v1", %{}, %{})

      versions = ModelRegistry.list_versions(:en, :pos_tagging)

      assert match?([_, _], versions)
      assert {"v1", %{accuracy: 0.95}} in versions
      assert {"v2", %{accuracy: 0.96}} in versions
    end

    test "returns sorted list of versions" do
      ModelRegistry.register(:en, :pos_tagging, "v3", %{}, %{})
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{})
      ModelRegistry.register(:en, :pos_tagging, "v2", %{}, %{})

      versions = ModelRegistry.list_versions(:en, :pos_tagging)

      assert match?([{"v1", _}, {"v2", _}, {"v3", _}], versions)
    end
  end

  describe "unregister/3" do
    test "removes a specific model" do
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{})
      ModelRegistry.register(:en, :pos_tagging, "v2", %{}, %{})

      assert :ok = ModelRegistry.unregister(:en, :pos_tagging, "v1")

      assert {:error, :not_found} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
      assert {:ok, _, _} = ModelRegistry.lookup(:en, :pos_tagging, "v2")
    end

    test "returns ok even if model doesn't exist" do
      assert :ok = ModelRegistry.unregister(:en, :pos_tagging, "v1")
    end
  end

  describe "clear/0" do
    test "removes all models" do
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{})
      ModelRegistry.register(:es, :ner, "v1", %{}, %{})
      ModelRegistry.register(:ca, :pos_tagging, "v2", %{}, %{})

      refute Enum.empty?(ModelRegistry.list())

      assert :ok = ModelRegistry.clear()

      assert [] = ModelRegistry.list()
    end

    test "allows registering new models after clear" do
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{})
      ModelRegistry.clear()

      assert :ok = ModelRegistry.register(:en, :pos_tagging, "v2", %{}, %{})
      assert {:ok, _, _} = ModelRegistry.lookup(:en, :pos_tagging, "v2")
    end
  end

  describe "metadata storage" do
    test "stores and retrieves complex metadata" do
      metadata = %{
        version: "1.0",
        accuracy: 0.947,
        trained_on: "UD_English-EWT v2.13",
        training_date: "2026-01-06",
        hyperparameters: %{smoothing_k: 0.001}
      }

      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, metadata)

      assert {:ok, _, ^metadata} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
    end

    test "stores empty metadata" do
      ModelRegistry.register(:en, :pos_tagging, "v1", %{}, %{})

      assert {:ok, _, metadata} = ModelRegistry.lookup(:en, :pos_tagging, "v1")
      assert metadata == %{}
    end
  end
end
