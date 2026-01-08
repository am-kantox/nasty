defmodule Nasty.Lexical.WordNet.SimilarityTest do
  use ExUnit.Case

  alias Nasty.Lexical.WordNet.{Relation, Similarity, Storage, Synset}

  setup_all do
    # Create test data
    lang = :test_sim
    Storage.init(lang)
    Storage.clear(lang)

    # Build a simple hierarchy:
    # entity (root)
    #   ├─ organism
    #   │   ├─ animal
    #   │   │   ├─ mammal
    #   │   │   │   ├─ dog
    #   │   │   │   └─ cat
    #   │   │   └─ bird
    #   │   └─ plant
    #   └─ object

    synsets = [
      {"entity", "root concept", []},
      {"organism", "living thing", [{"entity", :hypernym}]},
      {"animal", "living organism", [{"organism", :hypernym}]},
      {"plant", "vegetation", [{"organism", :hypernym}]},
      {"mammal", "warm-blooded animal", [{"animal", :hypernym}]},
      {"bird", "feathered animal", [{"animal", :hypernym}]},
      {"dog", "domestic canine", [{"mammal", :hypernym}]},
      {"cat", "domestic feline", [{"mammal", :hypernym}]},
      {"object", "inanimate thing", [{"entity", :hypernym}]}
    ]

    for {id, definition, relations} <- synsets do
      {:ok, synset} =
        Synset.new(
          "test-#{id}",
          :noun,
          definition,
          lang,
          lemmas: [id]
        )

      Storage.put_synset(synset, lang)

      for {target, rel_type} <- relations do
        {:ok, relation} = Relation.new(rel_type, "test-#{id}", "test-#{target}")
        Storage.put_relation(relation, lang)
      end
    end

    on_exit(fn -> Storage.clear(lang) end)

    {:ok, language: lang}
  end

  describe "path_similarity/3" do
    test "returns 1.0 for identical synsets", %{language: lang} do
      assert Similarity.path_similarity("test-dog", "test-dog", lang) == 1.0
    end

    test "calculates path similarity between close concepts", %{language: lang} do
      # dog -> mammal (1 step)
      similarity = Similarity.path_similarity("test-dog", "test-mammal", lang)
      assert similarity == 0.5
    end

    test "returns lower similarity for distant concepts", %{language: lang} do
      # dog -> mammal -> animal -> organism (3 steps)
      similarity = Similarity.path_similarity("test-dog", "test-organism", lang)
      assert similarity == 0.25
    end

    test "returns 0.0 when no path exists", %{language: lang} do
      Storage.init(:isolated)
      {:ok, synset} = Synset.new("isolated-1", :noun, "isolated concept", :isolated)
      Storage.put_synset(synset, :isolated)

      assert Similarity.path_similarity("test-dog", "isolated-1", :isolated) == 0.0

      Storage.clear(:isolated)
    end
  end

  describe "wup_similarity/3" do
    test "returns 1.0 for identical synsets", %{language: lang} do
      assert Similarity.wup_similarity("test-dog", "test-dog", lang) == 1.0
    end

    test "calculates high similarity for sibling concepts", %{language: lang} do
      # dog and cat share LCS: mammal
      similarity = Similarity.wup_similarity("test-dog", "test-cat", lang)
      # Both are at same depth, LCS is their parent
      assert similarity > 0.7
    end

    test "calculates lower similarity for distant concepts", %{language: lang} do
      # dog and plant share LCS: organism
      similarity = Similarity.wup_similarity("test-dog", "test-plant", lang)
      assert similarity < 0.5
    end

    test "returns 0.0 when no common ancestor", %{language: lang} do
      Storage.init(:isolated2)
      {:ok, synset} = Synset.new("isolated-2", :noun, "isolated", :isolated2)
      Storage.put_synset(synset, :isolated2)

      assert Similarity.wup_similarity("test-dog", "isolated-2", :isolated2) == 0.0

      Storage.clear(:isolated2)
    end
  end

  describe "lesk_similarity/3" do
    test "returns 1.0 for identical synsets", %{language: lang} do
      assert Similarity.lesk_similarity("test-dog", "test-dog", lang) == 1.0
    end

    test "calculates similarity based on definition overlap", %{language: lang} do
      # Both have "animal" in definition
      similarity = Similarity.lesk_similarity("test-mammal", "test-bird", lang)
      assert similarity > 0.0
    end

    test "returns 0.0 for completely different definitions", %{language: lang} do
      # Create synsets with no overlapping words
      Storage.init(:lesk_test)

      {:ok, s1} = Synset.new("lesk-1", :noun, "xyz", :lesk_test)
      {:ok, s2} = Synset.new("lesk-2", :noun, "abc", :lesk_test)

      Storage.put_synset(s1, :lesk_test)
      Storage.put_synset(s2, :lesk_test)

      assert Similarity.lesk_similarity("lesk-1", "lesk-2", :lesk_test) == 0.0

      Storage.clear(:lesk_test)
    end
  end

  describe "depth/2" do
    test "returns 0 for root nodes", %{language: lang} do
      assert Similarity.depth("test-entity", lang) == 0
    end

    test "calculates correct depth for deeper nodes", %{language: lang} do
      # dog: entity -> organism -> animal -> mammal -> dog
      dog_depth = Similarity.depth("test-dog", lang)
      assert dog_depth == 4

      # mammal: entity -> organism -> animal -> mammal
      mammal_depth = Similarity.depth("test-mammal", lang)
      assert mammal_depth == 3
    end

    test "handles cycles gracefully" do
      lang = :cycle_test
      Storage.init(lang)

      {:ok, s1} = Synset.new("cycle-1", :noun, "first", lang)
      {:ok, s2} = Synset.new("cycle-2", :noun, "second", lang)

      Storage.put_synset(s1, lang)
      Storage.put_synset(s2, lang)

      {:ok, r1} = Relation.new(:hypernym, "cycle-1", "cycle-2")
      {:ok, r2} = Relation.new(:hypernym, "cycle-2", "cycle-1")

      Storage.put_relation(r1, lang)
      Storage.put_relation(r2, lang)

      # Should not infinite loop
      depth = Similarity.depth("cycle-1", lang)
      assert is_integer(depth)

      Storage.clear(lang)
    end
  end

  describe "lcs/3" do
    test "finds least common subsumer", %{language: lang} do
      # dog and cat -> LCS is mammal
      lcs_id = Similarity.lcs("test-dog", "test-cat", lang)
      assert lcs_id == "test-mammal"
    end

    test "finds higher LCS for distant concepts", %{language: lang} do
      # dog and bird -> LCS is animal
      lcs_id = Similarity.lcs("test-dog", "test-bird", lang)
      assert lcs_id == "test-animal"
    end

    test "returns nil when no common ancestor", %{language: lang} do
      Storage.init(:lcs_test)
      {:ok, synset} = Synset.new("lcs-isolated", :noun, "isolated", :lcs_test)
      Storage.put_synset(synset, :lcs_test)

      assert Similarity.lcs("test-dog", "lcs-isolated", :lcs_test) == nil

      Storage.clear(:lcs_test)
    end
  end

  describe "combined_similarity/4" do
    test "combines multiple metrics with default weights", %{language: lang} do
      similarity = Similarity.combined_similarity("test-dog", "test-cat", lang)
      assert similarity >= 0.0
      assert similarity <= 1.0
    end

    test "respects custom weights", %{language: lang} do
      # All weight on path similarity
      sim1 =
        Similarity.combined_similarity("test-dog", "test-cat", lang,
          metrics: [:path],
          weights: [1.0]
        )

      path_sim = Similarity.path_similarity("test-dog", "test-cat", lang)
      assert_in_delta sim1, path_sim, 0.01
    end
  end
end
