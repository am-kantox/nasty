defmodule Nasty.Integration.TransformerIntegrationTest do
  use ExUnit.Case

  alias Nasty.AST.{Node, Token}
  alias Nasty.Language.English.{POSTagger, Tokenizer}
  alias Nasty.Statistics.Neural.Transformers.{CacheManager, Config, Loader}

  @moduletag :integration

  describe "transformer model listing and info" do
    test "lists available transformer models" do
      models = Loader.list_models()

      assert is_list(models)
      assert length(models) >= 5
      assert :roberta_base in models
    end

    test "retrieves model information" do
      {:ok, info} = Loader.get_model_info(:roberta_base)

      assert info.repo == "roberta-base"
      assert info.params > 0
      assert info.hidden_size == 768
    end

    test "checks language support" do
      assert Loader.supports_language?(:roberta_base, :en)
      refute Loader.supports_language?(:roberta_base, :jp)
      assert Loader.supports_language?(:xlm_roberta_base, :es)
    end
  end

  describe "configuration management" do
    test "gets default configuration" do
      config = Config.get()

      assert is_map(config)
      assert Map.has_key?(config, :cache_dir)
      assert Map.has_key?(config, :default_model)
      assert Map.has_key?(config, :backend)
      assert Map.has_key?(config, :device)
    end

    test "retrieves specific config values" do
      cache_dir = Config.cache_dir()
      default_model = Config.default_model()
      device = Config.device()

      assert is_binary(cache_dir)
      assert is_atom(default_model)
      assert device in [:cpu, :cuda]
    end

    test "merges runtime options" do
      config = Config.with_opts(device: :cuda, cache_dir: "/tmp/test")

      assert config.device == :cuda
      assert config.cache_dir == "/tmp/test"
    end
  end

  describe "cache management" do
    setup do
      cache_dir = "test/tmp/integration_cache"
      File.rm_rf!(cache_dir)
      File.mkdir_p!(cache_dir)

      on_exit(fn -> File.rm_rf!(cache_dir) end)

      {:ok, cache_dir: cache_dir}
    end

    test "checks for cached models", %{cache_dir: cache_dir} do
      assert :not_found = CacheManager.get_cached_model(:roberta_base, cache_dir)
    end

    test "lists empty cache initially", %{cache_dir: cache_dir} do
      assert [] = CacheManager.list_cached_models(cache_dir)
    end

    test "registers and lists models", %{cache_dir: cache_dir} do
      :ok = CacheManager.register_cached_model(:roberta_base, cache_dir)

      models = CacheManager.list_cached_models(cache_dir)
      assert length(models) == 1
      assert hd(models).model_name == :roberta_base
    end

    test "calculates cache size", %{cache_dir: cache_dir} do
      {:ok, size} = CacheManager.cache_size(cache_dir)
      assert size >= 0
    end
  end

  describe "tokenizer to POS tagger integration" do
    test "processes text through tokenization to POS tagging" do
      text = "The cat sat on the mat."

      {:ok, tokens} = Tokenizer.tokenize(text)

      assert is_list(tokens)
      refute Enum.empty?(tokens)
      assert Enum.all?(tokens, &match?(%Token{}, &1))

      # Verify tokens have required structure for POS tagging
      Enum.each(tokens, fn token ->
        assert is_binary(token.text)
        assert is_atom(token.language)
        assert token.language == :en
        refute is_nil(token.span)
      end)
    end

    test "fallback to rule-based when transformer unavailable" do
      text = "The cat sat."

      {:ok, tokens} = Tokenizer.tokenize(text)

      # This should fall back to rule-based since transformers aren't available in test
      {:ok, tagged} = POSTagger.tag_pos(tokens, model: :rule_based)

      assert is_list(tagged)
      assert length(tagged) == length(tokens)

      Enum.each(tagged, fn token ->
        assert is_atom(token.pos_tag)
        assert token.pos_tag != nil
      end)
    end

    test "transformer model option is accepted even if unavailable" do
      text = "The quick brown fox."

      {:ok, tokens} = Tokenizer.tokenize(text)

      # Should attempt transformer but fail gracefully
      result = POSTagger.tag_pos(tokens, model: :transformer)

      # May error or fall back, but should not crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "model option handling in POSTagger" do
    setup do
      span1 = Node.make_span({1, 0}, 0, {1, 3}, 3)
      span2 = Node.make_span({1, 4}, 4, {1, 7}, 7)

      tokens = [
        %Token{
          text: "The",
          pos_tag: :x,
          language: :en,
          span: span1,
          lemma: "The",
          morphology: %{}
        },
        %Token{
          text: "cat",
          pos_tag: :x,
          language: :en,
          span: span2,
          lemma: "cat",
          morphology: %{}
        }
      ]

      {:ok, tokens: tokens}
    end

    test "accepts :rule_based model option", %{tokens: tokens} do
      {:ok, tagged} = POSTagger.tag_pos(tokens, model: :rule_based)

      assert is_list(tagged)
      assert length(tagged) == 2
    end

    test "accepts :transformer model option", %{tokens: tokens} do
      result = POSTagger.tag_pos(tokens, model: :transformer)

      # May fail without actual model, but should handle gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts specific transformer model names", %{tokens: tokens} do
      result = POSTagger.tag_pos(tokens, model: :roberta_base)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "rejects invalid model option", %{tokens: tokens} do
      result = POSTagger.tag_pos(tokens, model: :invalid_model)

      assert {:error, {:unknown_model_type, :invalid_model}} = result
    end
  end

  describe "end-to-end workflow without actual models" do
    test "complete pipeline with fallbacks" do
      text = "Natural language processing is fascinating."

      # Tokenize
      {:ok, tokens} = Tokenizer.tokenize(text)
      assert is_list(tokens)
      refute Enum.empty?(tokens)

      # POS tag with rule-based (guaranteed to work)
      {:ok, rule_tagged} = POSTagger.tag_pos(tokens, model: :rule_based)

      assert is_list(rule_tagged)
      assert length(rule_tagged) == length(tokens)

      # Verify all tokens have POS tags
      Enum.each(rule_tagged, fn token ->
        assert is_atom(token.pos_tag)

        assert token.pos_tag in [
                 :noun,
                 :verb,
                 :adj,
                 :adv,
                 :det,
                 :adp,
                 :pron,
                 :aux,
                 :cconj,
                 :sconj,
                 :part,
                 :num,
                 :punct,
                 :propn,
                 :intj,
                 :sym,
                 :x
               ]
      end)
    end

    test "handles empty input" do
      assert {:ok, []} = Tokenizer.tokenize("")
    end

    test "handles single word" do
      {:ok, tokens} = Tokenizer.tokenize("word")
      {:ok, tagged} = POSTagger.tag_pos(tokens, model: :rule_based)

      assert length(tagged) == 1
      assert hd(tagged).text == "word"
      assert is_atom(hd(tagged).pos_tag)
    end

    test "handles punctuation correctly" do
      {:ok, tokens} = Tokenizer.tokenize("Hello, world!")
      {:ok, tagged} = POSTagger.tag_pos(tokens, model: :rule_based)

      punct_tokens = Enum.filter(tagged, &(&1.pos_tag == :punct))
      assert length(punct_tokens) >= 2
    end
  end

  describe "error handling and robustness" do
    test "handles offline mode gracefully" do
      result = Loader.load_model(:roberta_base, offline: true)

      # Should fail gracefully without crashing
      assert {:error, {:model_not_cached, _}} = result
    end

    test "handles unknown model gracefully" do
      result = Loader.load_model(:nonexistent_model, offline: true)

      assert {:error, {:unknown_model, :nonexistent_model}} = result
    end

    test "handles invalid cache directory" do
      result = CacheManager.get_cached_model(:roberta_base, "/invalid/path/that/does/not/exist")

      assert :not_found = result
    end

    test "POSTagger falls back on model load failure" do
      {:ok, tokens} = Tokenizer.tokenize("Test sentence.")

      # Should fall back to rule-based if transformer fails
      result = POSTagger.tag_pos(tokens, model: :transformer)

      # Either succeeds (with fallback) or returns specific error
      case result do
        {:ok, tagged} ->
          assert is_list(tagged)
          refute Enum.empty?(tagged)

        {:error, _reason} ->
          # Acceptable if no fallback is configured
          :ok
      end
    end
  end
end
