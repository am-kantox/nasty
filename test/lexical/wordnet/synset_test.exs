defmodule Nasty.Lexical.WordNet.SynsetTest do
  use ExUnit.Case, async: true

  alias Nasty.Lexical.WordNet.Synset

  describe "new/5" do
    test "creates a synset with required fields" do
      assert {:ok, synset} = Synset.new("oewn-12345-n", :noun, "test definition", :en)
      assert synset.id == "oewn-12345-n"
      assert synset.pos == :noun
      assert synset.definition == "test definition"
      assert synset.language == :en
      assert synset.examples == []
      assert synset.lemmas == []
      assert synset.ili == nil
    end

    test "creates a synset with optional fields" do
      opts = [
        examples: ["example 1", "example 2"],
        lemmas: ["word1", "word2"],
        ili: "i12345"
      ]

      assert {:ok, synset} = Synset.new("oewn-12345-n", :noun, "test definition", :en, opts)
      assert synset.examples == ["example 1", "example 2"]
      assert synset.lemmas == ["word1", "word2"]
      assert synset.ili == "i12345"
    end

    test "returns error for invalid POS tag" do
      assert {:error, :invalid_pos} = Synset.new("oewn-12345-x", :invalid, "definition", :en)
    end
  end

  describe "valid_pos?/1" do
    test "returns true for valid POS tags" do
      assert Synset.valid_pos?(:noun)
      assert Synset.valid_pos?(:verb)
      assert Synset.valid_pos?(:adj)
      assert Synset.valid_pos?(:adv)
    end

    test "returns false for invalid POS tags" do
      refute Synset.valid_pos?(:invalid)
      refute Synset.valid_pos?(:det)
      refute Synset.valid_pos?(:propn)
    end
  end

  describe "from_ud_pos/1" do
    test "converts UD noun tags to WordNet noun" do
      assert Synset.from_ud_pos(:noun) == :noun
      assert Synset.from_ud_pos(:propn) == :noun
    end

    test "converts UD verb tags to WordNet verb" do
      assert Synset.from_ud_pos(:verb) == :verb
      assert Synset.from_ud_pos(:aux) == :verb
    end

    test "converts adjective and adverb tags" do
      assert Synset.from_ud_pos(:adj) == :adj
      assert Synset.from_ud_pos(:adv) == :adv
    end

    test "returns nil for unconvertible tags" do
      assert Synset.from_ud_pos(:det) == nil
      assert Synset.from_ud_pos(:punct) == nil
    end
  end

  describe "primary_lemma/1" do
    test "returns first lemma" do
      {:ok, synset} = Synset.new("id", :noun, "def", :en, lemmas: ["dog", "domestic dog"])
      assert Synset.primary_lemma(synset) == "dog"
    end

    test "returns nil for empty lemmas" do
      {:ok, synset} = Synset.new("id", :noun, "def", :en)
      assert Synset.primary_lemma(synset) == nil
    end
  end
end
