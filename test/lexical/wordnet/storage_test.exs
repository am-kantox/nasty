defmodule Nasty.Lexical.WordNet.StorageTest do
  use ExUnit.Case

  alias Nasty.Lexical.WordNet.{Lemma, Relation, Storage, Synset}

  setup do
    # Use unique test language to avoid conflicts
    language = :test_lang
    Storage.init(language)
    Storage.clear(language)

    on_exit(fn ->
      Storage.clear(language)
    end)

    {:ok, language: language}
  end

  describe "init/1" do
    test "initializes storage for a language", %{language: lang} do
      assert :ok = Storage.init(lang)
      # Should be idempotent
      assert :ok = Storage.init(lang)
    end
  end

  describe "synset operations" do
    test "stores and retrieves synset", %{language: lang} do
      {:ok, synset} = Synset.new("test-001-n", :noun, "a test synset", lang)

      assert :ok = Storage.put_synset(synset, lang)
      assert retrieved = Storage.get_synset("test-001-n", lang)
      assert retrieved.id == "test-001-n"
      assert retrieved.definition == "a test synset"
    end

    test "returns nil for non-existent synset", %{language: lang} do
      assert Storage.get_synset("non-existent", lang) == nil
    end

    test "stores synset with ILI and updates ILI index", %{language: lang} do
      {:ok, synset} = Synset.new("test-001-n", :noun, "definition", lang, ili: "i12345")

      Storage.put_synset(synset, lang)

      # Should be findable via ILI
      results = Storage.get_by_ili("i12345", lang)
      assert length(results) == 1
      assert hd(results).id == "test-001-n"
    end
  end

  describe "lemma operations" do
    test "stores and retrieves lemmas", %{language: lang} do
      {:ok, lemma} = Lemma.new("dog", :noun, "test-001-n", "dog%1:05:00::", lang)

      assert :ok = Storage.put_lemma(lemma, lang)

      lemmas = Storage.get_lemmas("dog", :noun, lang)
      assert [retrieved] = lemmas
      assert retrieved.word == "dog"
      assert retrieved.synset_id == "test-001-n"
    end

    test "retrieves lemmas across all POS tags", %{language: lang} do
      {:ok, lemma1} = Lemma.new("run", :noun, "test-001-n", "run%1:05:00::", lang)
      {:ok, lemma2} = Lemma.new("run", :verb, "test-002-v", "run%2:38:00::", lang)

      Storage.put_lemma(lemma1, lang)
      Storage.put_lemma(lemma2, lang)

      lemmas = Storage.get_lemmas("run", nil, lang)
      assert length(lemmas) == 2
    end

    test "normalizes word lookup", %{language: lang} do
      {:ok, lemma} = Lemma.new("dog", :noun, "test-001-n", "dog%1:05:00::", lang)
      Storage.put_lemma(lemma, lang)

      # Should find with different case
      assert [_] = Storage.get_lemmas("DOG", :noun, lang)
      assert [_] = Storage.get_lemmas("Dog", :noun, lang)
    end
  end

  describe "synsets for word" do
    test "retrieves synsets for a word", %{language: lang} do
      {:ok, synset} = Synset.new("test-001-n", :noun, "definition", lang)
      {:ok, lemma} = Lemma.new("dog", :noun, "test-001-n", "dog%1:05:00::", lang)

      Storage.put_synset(synset, lang)
      Storage.put_lemma(lemma, lang)

      synsets = Storage.get_synsets_for_word("dog", :noun, lang)
      assert [retrieved] = synsets
      assert retrieved.id == "test-001-n"
    end

    test "returns empty list for unknown word", %{language: lang} do
      assert [] = Storage.get_synsets_for_word("unknown", :noun, lang)
    end
  end

  describe "relation operations" do
    test "stores and retrieves relations", %{language: lang} do
      {:ok, relation} = Relation.new(:hypernym, "test-001-n", "test-002-n")

      assert :ok = Storage.put_relation(relation, lang)

      targets = Storage.get_relations("test-001-n", :hypernym, lang)
      assert targets == ["test-002-n"]
    end

    test "retrieves all relation types", %{language: lang} do
      {:ok, rel1} = Relation.new(:hypernym, "test-001-n", "test-002-n")
      {:ok, rel2} = Relation.new(:meronym, "test-001-n", "test-003-n")

      Storage.put_relation(rel1, lang)
      Storage.put_relation(rel2, lang)

      all_relations = Storage.get_all_relations("test-001-n", lang)
      assert {:hypernym, "test-002-n"} in all_relations
      assert {:meronym, "test-003-n"} in all_relations
    end
  end

  describe "ILI operations" do
    test "finds synsets across languages by ILI" do
      {:ok, en_synset} = Synset.new("oewn-001-n", :noun, "definition", :en, ili: "i12345")
      {:ok, es_synset} = Synset.new("omw-es-001-n", :noun, "definición", :es, ili: "i12345")

      Storage.init(:en)
      Storage.init(:es)
      Storage.put_synset(en_synset, :en)
      Storage.put_synset(es_synset, :es)

      # Find English synset via ILI
      en_results = Storage.get_by_ili("i12345", :en)
      assert length(en_results) == 1
      assert hd(en_results).language == :en

      # Find all synsets via ILI
      all_results = Storage.get_by_ili("i12345", :all)
      assert length(all_results) == 2

      Storage.clear(:en)
      Storage.clear(:es)
    end
  end

  describe "stats/1" do
    test "returns statistics", %{language: lang} do
      {:ok, synset} = Synset.new("test-001-n", :noun, "definition", lang)
      {:ok, lemma} = Lemma.new("word", :noun, "test-001-n", "key", lang)
      {:ok, relation} = Relation.new(:hypernym, "test-001-n", "test-002-n")

      Storage.put_synset(synset, lang)
      Storage.put_lemma(lemma, lang)
      Storage.put_relation(relation, lang)

      stats = Storage.stats(lang)
      assert stats.synsets == 1
      assert stats.lemmas == 1
      assert stats.relations == 1
    end
  end

  describe "loaded?/1" do
    test "returns true when data is loaded", %{language: lang} do
      {:ok, synset} = Synset.new("test-001-n", :noun, "definition", lang)
      Storage.put_synset(synset, lang)

      assert Storage.loaded?(lang)
    end

    test "returns false for unloaded language" do
      refute Storage.loaded?(:unloaded_lang)
    end
  end

  describe "clear/1" do
    test "clears all data for language", %{language: lang} do
      {:ok, synset} = Synset.new("test-001-n", :noun, "definition", lang)
      Storage.put_synset(synset, lang)

      assert Storage.loaded?(lang)

      Storage.clear(lang)

      refute Storage.loaded?(lang)
      assert Storage.get_synset("test-001-n", lang) == nil
    end
  end
end
