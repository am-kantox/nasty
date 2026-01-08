defmodule Nasty.Language.GrammarLoaderTest do
  use ExUnit.Case, async: false

  alias Nasty.Language.GrammarLoader

  setup do
    # Clear cache before each test
    GrammarLoader.clear_cache()
    :ok
  end

  describe "start_link/0" do
    test "initializes ETS cache" do
      {:ok, _pid} = GrammarLoader.start_link()
      assert :ets.info(:grammar_rules_cache) != :undefined
    end
  end

  describe "validate_rules/1" do
    test "validates map rules" do
      assert :ok = GrammarLoader.validate_rules(%{})
      assert :ok = GrammarLoader.validate_rules(%{noun_phrases: []})
    end

    test "raises on non-map rules" do
      assert_raise ArgumentError, "Grammar rules must be a map", fn ->
        GrammarLoader.validate_rules("invalid")
      end
    end
  end

  describe "load_file/2" do
    setup do
      # Create temporary grammar file
      tmp_dir = System.tmp_dir!()
      test_file = Path.join(tmp_dir, "test_grammar.exs")

      File.write!(test_file, """
      %{
        noun_phrases: [
          %{pattern: [:det, :noun], description: "Simple NP"}
        ],
        verb_phrases: [
          %{pattern: [:verb], description: "Simple VP"}
        ]
      }
      """)

      on_exit(fn ->
        File.rm(test_file)
      end)

      {:ok, test_file: test_file}
    end

    test "loads grammar from file", %{test_file: file} do
      {:ok, rules} = GrammarLoader.load_file(file)

      assert is_map(rules)
      assert Map.has_key?(rules, :noun_phrases)
      assert Map.has_key?(rules, :verb_phrases)
      assert [%{pattern: [:det, :noun]}] = rules.noun_phrases
    end

    test "caches loaded grammar", %{test_file: file} do
      # First load
      {:ok, rules1} = GrammarLoader.load_file(file)

      # Second load should hit cache
      {:ok, rules2} = GrammarLoader.load_file(file)

      assert rules1 == rules2
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = GrammarLoader.load_file("/nonexistent/file.exs")
    end

    test "returns error for invalid Elixir code" do
      tmp_file = Path.join(System.tmp_dir!(), "invalid.exs")
      File.write!(tmp_file, "invalid elixir code {")

      assert {:error, {:eval_error, _}} = GrammarLoader.load_file(tmp_file)

      File.rm(tmp_file)
    end
  end

  describe "load/3" do
    test "returns empty map when grammar file doesn't exist" do
      # Try to load non-existent grammar
      {:ok, rules} = GrammarLoader.load(:nonexistent_lang, :nonexistent_rules)

      assert rules == %{}
    end

    test "caches loaded rules" do
      # First call
      {:ok, rules1} = GrammarLoader.load(:en, :test_rules)

      # Second call should use cache
      {:ok, rules2} = GrammarLoader.load(:en, :test_rules)

      assert rules1 == rules2
    end

    test "supports force_reload option" do
      # Load once
      {:ok, _rules} = GrammarLoader.load(:en, :test_rules)

      # Force reload
      {:ok, rules} = GrammarLoader.load(:en, :test_rules, force_reload: true)

      assert is_map(rules)
    end

    test "supports variant option" do
      {:ok, rules} = GrammarLoader.load(:en, :test_rules, variant: :formal)

      assert is_map(rules)
    end
  end

  describe "clear_cache/0" do
    test "clears all cached rules" do
      # Load some rules to populate cache
      GrammarLoader.load(:en, :test_rules1)
      GrammarLoader.load(:en, :test_rules2)

      # Clear cache
      assert :ok = GrammarLoader.clear_cache()

      # ETS table should be empty
      assert :ets.tab2list(:grammar_rules_cache) == []
    end
  end

  describe "clear_cache/3" do
    test "clears specific cached rules" do
      # Create temporary files to ensure caching actually happens
      tmp_dir = System.tmp_dir!()
      file1 = Path.join(tmp_dir, "rules1.exs")
      file2 = Path.join(tmp_dir, "rules2.exs")

      File.write!(file1, "%{test: 1}")
      File.write!(file2, "%{test: 2}")

      # Load multiple rules
      GrammarLoader.load_file(file1, cache_key: {:en, :rules1, :default})
      GrammarLoader.load_file(file2, cache_key: {:en, :rules2, :default})

      # Clear only one
      assert :ok = GrammarLoader.clear_cache(:en, :rules1)

      # rules1 should be cleared, but rules2 should still be cached
      cache_list = :ets.tab2list(:grammar_rules_cache)
      refute Enum.any?(cache_list, fn {{lang, type, _}, _} -> lang == :en and type == :rules1 end)
      assert Enum.any?(cache_list, fn {{lang, type, _}, _} -> lang == :en and type == :rules2 end)

      File.rm(file1)
      File.rm(file2)
    end
  end
end
