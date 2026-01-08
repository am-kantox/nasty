defmodule Nasty.Statistics.Neural.Transformers.LoaderTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Transformers.Loader

  describe "list_models/0" do
    test "returns list of available models" do
      models = Loader.list_models()

      assert is_list(models)
      refute Enum.empty?(models)
    end

    test "includes expected transformer models" do
      models = Loader.list_models()

      assert :bert_base_cased in models
      assert :bert_base_uncased in models
      assert :roberta_base in models
      assert :xlm_roberta_base in models
      assert :distilbert_base in models
    end
  end

  describe "get_model_info/1" do
    test "returns model configuration for valid model" do
      {:ok, info} = Loader.get_model_info(:roberta_base)

      assert is_map(info)
      assert info.repo == "roberta-base"
      assert info.params == 125_000_000
      assert info.hidden_size == 768
      assert info.num_layers == 12
      assert info.languages == [:en]
    end

    test "returns error for unknown model" do
      assert {:error, :unknown_model} = Loader.get_model_info(:nonexistent_model)
    end

    test "all listed models have valid info" do
      models = Loader.list_models()

      Enum.each(models, fn model ->
        assert {:ok, info} = Loader.get_model_info(model)
        assert is_binary(info.repo)
        assert is_integer(info.params)
        assert info.params > 0
        assert is_integer(info.hidden_size)
        assert info.hidden_size > 0
        assert is_integer(info.num_layers)
        assert info.num_layers > 0
        assert is_list(info.languages)
        refute Enum.empty?(info.languages)
      end)
    end
  end

  describe "model configurations" do
    test "BERT base cased has correct configuration" do
      {:ok, info} = Loader.get_model_info(:bert_base_cased)

      assert info.repo == "bert-base-cased"
      assert info.params == 110_000_000
      assert info.hidden_size == 768
      assert info.num_layers == 12
      assert info.languages == [:en]
    end

    test "BERT base uncased has correct configuration" do
      {:ok, info} = Loader.get_model_info(:bert_base_uncased)

      assert info.repo == "bert-base-uncased"
      assert info.params == 110_000_000
      assert info.hidden_size == 768
      assert info.num_layers == 12
      assert info.languages == [:en]
    end

    test "RoBERTa base has correct configuration" do
      {:ok, info} = Loader.get_model_info(:roberta_base)

      assert info.repo == "roberta-base"
      assert info.params == 125_000_000
      assert info.hidden_size == 768
      assert info.num_layers == 12
      assert info.languages == [:en]
    end

    test "XLM-RoBERTa base supports multiple languages" do
      {:ok, info} = Loader.get_model_info(:xlm_roberta_base)

      assert info.repo == "xlm-roberta-base"
      assert info.params == 270_000_000
      assert info.hidden_size == 768
      assert info.num_layers == 12
      assert :multi in info.languages or length(info.languages) > 1
    end

    test "DistilBERT base is smaller model" do
      {:ok, info} = Loader.get_model_info(:distilbert_base)

      assert info.repo == "distilbert-base-uncased"
      assert info.params == 66_000_000
      assert info.hidden_size == 768
      assert info.num_layers == 6
      assert info.languages == [:en]
    end
  end

  describe "supports_language?/2" do
    test "returns true for supported language" do
      assert Loader.supports_language?(:bert_base_cased, :en) == true
      assert Loader.supports_language?(:roberta_base, :en) == true
    end

    test "returns false for unsupported language on monolingual model" do
      assert Loader.supports_language?(:bert_base_cased, :es) == false
      assert Loader.supports_language?(:roberta_base, :ca) == false
    end

    test "returns true for multilingual model with any language" do
      assert Loader.supports_language?(:xlm_roberta_base, :en) == true
      assert Loader.supports_language?(:xlm_roberta_base, :es) == true
      assert Loader.supports_language?(:xlm_roberta_base, :ca) == true
      assert Loader.supports_language?(:xlm_roberta_base, :zh) == true
    end

    test "returns false for unknown model" do
      assert Loader.supports_language?(:nonexistent_model, :en) == false
    end
  end

  describe "load_model/2" do
    test "accepts valid model name" do
      # This will fail in test environment without actual models
      # but we test the API and options handling
      result = Loader.load_model(:roberta_base, offline: true)

      # Should fail because model is not cached
      assert match?({:error, _}, result)
    end

    test "accepts cache_dir option" do
      result = Loader.load_model(:bert_base_cased, cache_dir: "/tmp/test_cache", offline: true)

      assert match?({:error, _}, result)
    end

    test "accepts backend option" do
      result = Loader.load_model(:roberta_base, backend: Nx.BinaryBackend, offline: true)

      assert match?({:error, _}, result)
    end

    test "accepts device option" do
      result = Loader.load_model(:roberta_base, device: :cpu, offline: true)

      assert match?({:error, _}, result)
    end

    test "returns error for unknown model" do
      result = Loader.load_model(:nonexistent_model, offline: true)

      assert {:error, {:unknown_model, :nonexistent_model}} = result
    end

    test "respects offline mode" do
      result = Loader.load_model(:bert_base_cased, offline: true)

      # Should fail with model not cached error
      assert match?({:error, {:model_not_cached, _}}, result)
    end
  end

  describe "model parameter counts" do
    test "DistilBERT is smallest model" do
      {:ok, distilbert} = Loader.get_model_info(:distilbert_base)
      {:ok, bert} = Loader.get_model_info(:bert_base_cased)
      {:ok, roberta} = Loader.get_model_info(:roberta_base)
      {:ok, xlm_roberta} = Loader.get_model_info(:xlm_roberta_base)

      assert distilbert.params < bert.params
      assert distilbert.params < roberta.params
      assert distilbert.params < xlm_roberta.params
    end

    test "XLM-RoBERTa is largest base model" do
      {:ok, xlm_roberta} = Loader.get_model_info(:xlm_roberta_base)
      {:ok, bert} = Loader.get_model_info(:bert_base_cased)
      {:ok, roberta} = Loader.get_model_info(:roberta_base)

      assert xlm_roberta.params > bert.params
      assert xlm_roberta.params > roberta.params
    end

    test "all base models have same hidden size" do
      models = [
        :bert_base_cased,
        :bert_base_uncased,
        :roberta_base,
        :distilbert_base,
        :xlm_roberta_base
      ]

      hidden_sizes =
        Enum.map(models, fn model ->
          {:ok, info} = Loader.get_model_info(model)
          info.hidden_size
        end)

      # All should be 768
      assert Enum.all?(hidden_sizes, &(&1 == 768))
    end
  end
end
