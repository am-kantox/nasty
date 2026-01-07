defmodule Nasty.Language.English.POSTaggerTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.English.{POSTagger, Tokenizer}

  doctest Nasty.Language.English.POSTagger

  describe "determiners" do
    test "tags 'the' as determiner" do
      {:ok, tokens} = Tokenizer.tokenize("the")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert hd(tagged).pos_tag == :det
    end

    test "tags articles" do
      {:ok, tokens} = Tokenizer.tokenize("a an the")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.map(tagged, & &1.pos_tag) == [:det, :det, :det]
    end

    test "tags possessive determiners" do
      {:ok, tokens} = Tokenizer.tokenize("my your his her")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :det))
    end
  end

  describe "pronouns" do
    test "tags personal pronouns" do
      {:ok, tokens} = Tokenizer.tokenize("I you he she it")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :pron))
    end

    test "tags object pronouns" do
      {:ok, tokens} = Tokenizer.tokenize("me him us them")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :pron))
    end

    test "tags 'her' as determiner by default (ambiguous word)" do
      {:ok, tokens} = Tokenizer.tokenize("her")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      # Without context, 'her' defaults to determiner (more common usage)
      assert hd(tagged).pos_tag == :det
    end
  end

  describe "prepositions" do
    test "tags common prepositions" do
      {:ok, tokens} = Tokenizer.tokenize("in on at by for")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :adp))
    end

    test "tags complex prepositions" do
      {:ok, tokens} = Tokenizer.tokenize("throughout underneath")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :adp))
    end
  end

  describe "conjunctions" do
    test "tags coordinating conjunctions" do
      {:ok, tokens} = Tokenizer.tokenize("and or but")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :cconj))
    end

    test "tags subordinating conjunctions" do
      {:ok, tokens} = Tokenizer.tokenize("because although while")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :sconj))
    end
  end

  describe "auxiliaries" do
    test "tags 'be' forms" do
      {:ok, tokens} = Tokenizer.tokenize("am is are was were")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :aux))
    end

    test "tags 'have' forms" do
      {:ok, tokens} = Tokenizer.tokenize("have has had")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :aux))
    end

    test "tags modal auxiliaries" do
      {:ok, tokens} = Tokenizer.tokenize("will would can could")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :aux))
    end
  end

  describe "morphological patterns" do
    test "tags -ing words as verbs" do
      {:ok, tokens} = Tokenizer.tokenize("running walking talking")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "tags -ed words as verbs" do
      {:ok, tokens} = Tokenizer.tokenize("walked talked jumped")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "tags -tion words as nouns" do
      {:ok, tokens} = Tokenizer.tokenize("action creation education")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :noun))
    end

    test "tags -ness words as nouns" do
      {:ok, tokens} = Tokenizer.tokenize("happiness sadness kindness")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :noun))
    end

    test "tags -ly words as adverbs" do
      {:ok, tokens} = Tokenizer.tokenize("quickly slowly happily")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :adv))
    end

    test "tags -ful words as adjectives" do
      {:ok, tokens} = Tokenizer.tokenize("beautiful helpful careful")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :adj))
    end

    test "tags -able words as adjectives" do
      {:ok, tokens} = Tokenizer.tokenize("readable movable breakable")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :adj))
    end
  end

  describe "proper nouns" do
    test "tags capitalized words as proper nouns" do
      {:ok, tokens} = Tokenizer.tokenize("London Paris Tokyo")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :propn))
    end
  end

  describe "numbers and punctuation" do
    test "preserves number tags from tokenizer" do
      {:ok, tokens} = Tokenizer.tokenize("42 19.99")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :num))
    end

    test "preserves punctuation tags from tokenizer" do
      {:ok, tokens} = Tokenizer.tokenize(". , ! ?")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert Enum.all?(tagged, &(&1.pos_tag == :punct))
    end
  end

  describe "contextual tagging" do
    test "tags word after determiner as noun" do
      {:ok, tokens} = Tokenizer.tokenize("the cat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.at(tagged, 0).pos_tag == :det
      assert Enum.at(tagged, 1).pos_tag == :noun
    end

    test "tags word after preposition as noun" do
      {:ok, tokens} = Tokenizer.tokenize("in house")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.at(tagged, 0).pos_tag == :adp
      assert Enum.at(tagged, 1).pos_tag == :noun
    end
  end

  describe "complete sentences" do
    test "tags simple sentence correctly" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      tags = Enum.map(tagged, & &1.pos_tag)
      assert tags == [:det, :noun, :verb, :punct]
    end

    test "tags sentence with verb" do
      {:ok, tokens} = Tokenizer.tokenize("I am running quickly.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      tags = Enum.map(tagged, & &1.pos_tag)
      assert tags == [:pron, :aux, :verb, :adv, :punct]
    end

    test "tags sentence with adjectives" do
      {:ok, tokens} = Tokenizer.tokenize("The beautiful flowers.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      tags = Enum.map(tagged, & &1.pos_tag)
      assert tags == [:det, :adj, :noun, :punct]
    end

    test "tags complex sentence" do
      {:ok, tokens} = Tokenizer.tokenize("I don't know.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      tags = Enum.map(tagged, & &1.pos_tag)
      # I: pron, don't: verb (starts with "do"), know: noun (default)
      assert Enum.at(tags, 0) == :pron
      assert Enum.at(tags, -1) == :punct
    end
  end

  describe "edge cases" do
    test "handles empty token list" do
      {:ok, tagged} = POSTagger.tag_pos([])
      assert tagged == []
    end

    test "handles single token" do
      {:ok, tokens} = Tokenizer.tokenize("the")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      assert length(tagged) == 1
      assert hd(tagged).pos_tag == :det
    end
  end

  describe "neural mode integration" do
    @moduletag :neural

    test "accepts :neural mode option" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat.")

      # Should use HMM fallback if neural model not available
      {:ok, tagged} = POSTagger.tag_pos(tokens, mode: :neural)

      assert is_list(tagged)
      assert length(tagged) == 4
      assert Enum.all?(tagged, &Map.has_key?(&1, :pos_tag))
    end

    test "accepts :neural_ensemble mode option" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat.")

      # Should combine neural + HMM + rules
      {:ok, tagged} = POSTagger.tag_pos(tokens, mode: :neural_ensemble)

      assert is_list(tagged)
      assert length(tagged) == 4
    end

    test "neural mode falls back gracefully when model unavailable" do
      {:ok, tokens} = Tokenizer.tokenize("The dog runs.")

      # Neural model not loaded, should fallback to HMM
      {:ok, tagged} = POSTagger.tag_pos(tokens, mode: :neural)

      tags = Enum.map(tagged, & &1.pos_tag)
      assert :det in tags
      assert :noun in tags
      assert :verb in tags
    end

    test "accepts neural_model option" do
      {:ok, tokens} = Tokenizer.tokenize("Hello world.")

      # Pass nil model (should fall back)
      {:ok, tagged} = POSTagger.tag_pos(tokens, mode: :neural, neural_model: nil)

      assert is_list(tagged)
      assert length(tagged) == 3
    end

    test "neural_ensemble combines multiple approaches" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat.")

      {:ok, ensemble_tags} = POSTagger.tag_pos(tokens, mode: :neural_ensemble)
      {:ok, hmm_tags} = POSTagger.tag_pos(tokens, mode: :hmm)
      {:ok, rule_tags} = POSTagger.tag_pos(tokens, mode: :rule_based)

      # All should produce valid results
      assert length(ensemble_tags) == length(hmm_tags)
      assert length(ensemble_tags) == length(rule_tags)
    end
  end

  describe "mode parameter" do
    test "accepts :rule_based mode" do
      {:ok, tokens} = Tokenizer.tokenize("The cat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens, mode: :rule_based)

      assert length(tagged) == 3
    end

    test "accepts :hmm mode" do
      {:ok, tokens} = Tokenizer.tokenize("The cat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens, mode: :hmm)

      assert length(tagged) == 3
    end

    test "defaults to :hmm mode when no mode specified" do
      {:ok, tokens} = Tokenizer.tokenize("The cat.")
      {:ok, tagged_default} = POSTagger.tag_pos(tokens)
      {:ok, tagged_hmm} = POSTagger.tag_pos(tokens, mode: :hmm)

      # Should produce same results
      assert Enum.map(tagged_default, & &1.pos_tag) ==
               Enum.map(tagged_hmm, & &1.pos_tag)
    end
  end
end
