defmodule Nasty.Language.Resources.LexiconLoaderTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.Resources.LexiconLoader

  describe "load/2" do
    test "loads determiners lexicon for English" do
      determiners = LexiconLoader.load(:en, :determiners)

      assert is_list(determiners)
      assert "the" in determiners
      assert "a" in determiners
      assert "an" in determiners
      assert "this" in determiners
      assert "that" in determiners
    end

    test "loads pronouns lexicon for English" do
      pronouns = LexiconLoader.load(:en, :pronouns)

      assert is_list(pronouns)
      assert "i" in pronouns
      assert "you" in pronouns
      assert "he" in pronouns
      assert "she" in pronouns
      assert "it" in pronouns
      assert "we" in pronouns
      assert "they" in pronouns
    end

    test "loads prepositions lexicon for English" do
      prepositions = LexiconLoader.load(:en, :prepositions)

      assert is_list(prepositions)
      assert "in" in prepositions
      assert "on" in prepositions
      assert "at" in prepositions
      assert "to" in prepositions
      assert "from" in prepositions
    end

    test "loads coordinating conjunctions lexicon for English" do
      conjunctions = LexiconLoader.load(:en, :conjunctions_coord)

      assert is_list(conjunctions)
      assert "and" in conjunctions
      assert "but" in conjunctions
      assert "or" in conjunctions
      assert "nor" in conjunctions
    end

    test "loads subordinating conjunctions lexicon for English" do
      conjunctions = LexiconLoader.load(:en, :conjunctions_sub)

      assert is_list(conjunctions)
      assert "because" in conjunctions
      assert "although" in conjunctions
      assert "while" in conjunctions
      assert "if" in conjunctions
      assert "when" in conjunctions
    end

    test "loads auxiliaries lexicon for English" do
      auxiliaries = LexiconLoader.load(:en, :auxiliaries)

      assert is_list(auxiliaries)
      assert "is" in auxiliaries
      assert "are" in auxiliaries
      assert "was" in auxiliaries
      assert "were" in auxiliaries
      assert "have" in auxiliaries
      assert "has" in auxiliaries
      assert "will" in auxiliaries
      assert "can" in auxiliaries
    end

    test "loads adverbs lexicon for English" do
      adverbs = LexiconLoader.load(:en, :adverbs)

      assert is_list(adverbs)
      assert "not" in adverbs
      assert "very" in adverbs
      assert "always" in adverbs
      assert "never" in adverbs
      assert "however" in adverbs
    end

    test "loads particles lexicon for English" do
      particles = LexiconLoader.load(:en, :particles)

      assert is_list(particles)
      assert "up" in particles
      assert "down" in particles
      assert "out" in particles
      assert "off" in particles
      assert "away" in particles
    end

    test "loads interjections lexicon for English" do
      interjections = LexiconLoader.load(:en, :interjections)

      assert is_list(interjections)
      assert "oh" in interjections
      assert "ah" in interjections
      assert "wow" in interjections
      assert "hey" in interjections
    end

    test "loads common verbs lexicon for English" do
      verbs = LexiconLoader.load(:en, :common_verbs)

      assert is_list(verbs)
      assert "go" in verbs
      assert "come" in verbs
      assert "see" in verbs
      assert "filter" in verbs
      assert "sort" in verbs
      assert "map" in verbs
    end

    test "loads common adjectives lexicon for English" do
      adjectives = LexiconLoader.load(:en, :common_adjectives)

      assert is_list(adjectives)
      assert "good" in adjectives
      assert "bad" in adjectives
      assert "big" in adjectives
      assert "small" in adjectives
      assert "greater" in adjectives
      assert "active" in adjectives
    end

    test "raises when lexicon file not found" do
      assert_raise RuntimeError, ~r/Lexicon file not found/, fn ->
        LexiconLoader.load(:en, :nonexistent)
      end
    end
  end

  describe "in_lexicon?/3" do
    test "returns true when word is in lexicon" do
      assert LexiconLoader.in_lexicon?(:en, :determiners, "the")
      assert LexiconLoader.in_lexicon?(:en, :pronouns, "i")
      assert LexiconLoader.in_lexicon?(:en, :prepositions, "in")
    end

    test "returns false when word is not in lexicon" do
      refute LexiconLoader.in_lexicon?(:en, :determiners, "foobar")
      refute LexiconLoader.in_lexicon?(:en, :pronouns, "xyz")
      refute LexiconLoader.in_lexicon?(:en, :prepositions, "blah")
    end

    test "is case-sensitive" do
      assert LexiconLoader.in_lexicon?(:en, :pronouns, "i")
      refute LexiconLoader.in_lexicon?(:en, :pronouns, "I")
    end
  end

  describe "lexicon_path/2" do
    test "returns correct path for English lexicons" do
      path = LexiconLoader.lexicon_path(:en, :determiners)

      assert String.ends_with?(path, "priv/languages/en/lexicons/determiners.exs")
    end

    test "returns correct path for Spanish lexicons" do
      path = LexiconLoader.lexicon_path(:es, :determiners)

      assert String.ends_with?(path, "priv/languages/es/lexicons/determiners.exs")
    end
  end

  describe "list_lexicons/1" do
    test "lists all available English lexicons" do
      lexicons = LexiconLoader.list_lexicons(:en)

      assert :determiners in lexicons
      assert :pronouns in lexicons
      assert :prepositions in lexicons
      assert :conjunctions_coord in lexicons
      assert :conjunctions_sub in lexicons
      assert :auxiliaries in lexicons
      assert :adverbs in lexicons
      assert :particles in lexicons
      assert :interjections in lexicons
      assert :common_verbs in lexicons
      assert :common_adjectives in lexicons
    end

    test "returns empty list for non-existent language" do
      lexicons = LexiconLoader.list_lexicons(:nonexistent)

      assert lexicons == []
    end
  end
end
