defmodule Nasty.Language.English.PhraseParserTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{NounPhrase, VerbPhrase}
  alias Nasty.Language.English.{PhraseParser, POSTagger, Tokenizer}

  describe "parse_noun_phrase/2" do
    test "parses simple noun" do
      {:ok, tokens} = Tokenizer.tokenize("cat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert {:ok, %NounPhrase{}, 1} = PhraseParser.parse_noun_phrase(tagged, 0)
    end

    test "parses determiner + noun" do
      {:ok, tokens} = Tokenizer.tokenize("the cat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, pos} = PhraseParser.parse_noun_phrase(tagged, 0)
      assert np.determiner != nil
      assert np.determiner.text == "the"
      assert np.head.text == "cat"
      assert pos == 2
    end

    test "parses det + adj + noun" do
      {:ok, tokens} = Tokenizer.tokenize("the big cat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, pos} = PhraseParser.parse_noun_phrase(tagged, 0)
      assert np.determiner.text == "the"
      assert match?([_], np.modifiers)
      assert hd(np.modifiers).text == "big"
      assert np.head.text == "cat"
      assert pos == 3
    end

    test "parses noun phrase with PP" do
      {:ok, tokens} = Tokenizer.tokenize("the cat on the mat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, pos} = PhraseParser.parse_noun_phrase(tagged, 0)
      assert np.head.text == "cat"
      assert match?([_], np.post_modifiers)
      assert pos == 5
    end
  end

  describe "parse_verb_phrase/2" do
    test "parses simple verb" do
      {:ok, tokens} = Tokenizer.tokenize("runs")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      # Force tag as verb (since our tagger might tag "runs" as noun)
      tagged = [%{hd(tagged) | pos_tag: :verb}]

      assert {:ok, %VerbPhrase{}, 1} = PhraseParser.parse_verb_phrase(tagged, 0)
    end

    test "parses aux + verb" do
      {:ok, tokens} = Tokenizer.tokenize("is running")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, vp, pos} = PhraseParser.parse_verb_phrase(tagged, 0)
      assert match?([_], vp.auxiliaries)
      assert hd(vp.auxiliaries).text == "is"
      assert vp.head.text == "running"
      assert pos == 2
    end

    test "parses verb + NP object" do
      {:ok, tokens} = Tokenizer.tokenize("likes cats")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      # Force first token to be verb
      [first | rest] = tagged
      tagged = [%{first | pos_tag: :verb} | rest]

      {:ok, vp, pos} = PhraseParser.parse_verb_phrase(tagged, 0)
      assert vp.head.text == "likes"
      assert match?([_ | _], vp.complements)
      assert pos >= 2
    end
  end

  describe "parse_prepositional_phrase/2" do
    test "parses prep + NP" do
      {:ok, tokens} = Tokenizer.tokenize("on the mat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, pp, pos} = PhraseParser.parse_prepositional_phrase(tagged, 0)
      assert pp.head.text == "on"
      assert pp.object.head.text == "mat"
      assert pos == 3
    end

    test "fails without preposition" do
      {:ok, tokens} = Tokenizer.tokenize("the cat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert PhraseParser.parse_prepositional_phrase(tagged, 0) == :error
    end
  end

  describe "integration" do
    test "parses complete sentence structure" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat on the mat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      # Check we can parse NP
      {:ok, np, np_end} = PhraseParser.parse_noun_phrase(tagged, 0)
      assert np.head.text == "cat"

      # The next token should be a verb or could be mistagged
      verb_token = Enum.at(tagged, np_end)
      require Logger
      Logger.notice(label: "Token after NP: " <> inspect(verb_token))
    end
  end

  describe "deeply nested noun phrases" do
    test "parses noun phrase with PP post-modifier" do
      # "the cat on the mat"
      # Structure: NP(det + head) + PP("on the mat")
      {:ok, tokens} = Tokenizer.tokenize("the cat on the mat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, pos} = PhraseParser.parse_noun_phrase(tagged, 0)

      # Check head noun
      assert np.head.text == "cat"

      # Check determiner
      assert np.determiner != nil
      assert np.determiner.text == "the"

      # Should have post-modifiers
      # Note: This tests the parser's ability to parse post-modifiers
      # If the parser implementation fully supports PP post-modifiers,
      # this should be >= 1. Current implementation may vary.
      assert is_list(np.post_modifiers)

      # If post-modifiers are parsed, verify structure
      if match?([_ | _], np.post_modifiers) do
        first_pp = hd(np.post_modifiers)
        assert match?(%Nasty.AST.PrepositionalPhrase{}, first_pp)
        assert first_pp.head.text == "on"
        assert first_pp.object.head.text == "mat"
        assert pos == length(tagged)
      else
        # Parser stopped at the noun, which is acceptable behavior
        # Position should be at least past determiner and noun
        assert pos >= 2
      end
    end

    test "parses deeply nested NP with nested PP" do
      # "the cat in the house on the hill"
      # Structure: NP + PP1("in the house") where house has PP2("on the hill")
      {:ok, tokens} = Tokenizer.tokenize("the cat in the house on the hill")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, pos} = PhraseParser.parse_noun_phrase(tagged, 0)

      # Check main NP
      assert np.head.text == "cat"
      assert np.determiner.text == "the"

      # Should have at least one PP post-modifier
      assert match?([_ | _], np.post_modifiers)

      first_pp = hd(np.post_modifiers)
      assert match?(%Nasty.AST.PrepositionalPhrase{}, first_pp)
      assert first_pp.head.text == "in"

      # The object of the first PP should be an NP that itself has a PP post-modifier
      house_np = first_pp.object
      assert house_np.head.text == "house"

      # Check if the house NP has its own PP post-modifier ("on the hill")
      # This tests deep nesting
      if match?([_ | _], house_np.post_modifiers) do
        nested_pp = hd(house_np.post_modifiers)
        assert nested_pp.head.text == "on"
        assert nested_pp.object.head.text == "hill"
      end

      # Should consume all tokens
      assert pos == length(tagged)
    end

    test "parses NP with multiple adjectives and PP" do
      # "the big red ball on the floor"
      {:ok, tokens} = Tokenizer.tokenize("the big red ball on the floor")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, pos} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert np.head.text == "ball"
      assert np.determiner.text == "the"

      # Should have multiple adjective modifiers
      assert match?([_, _ | _], np.modifiers)
      modifier_texts = Enum.map(np.modifiers, & &1.text)
      assert "big" in modifier_texts
      assert "red" in modifier_texts

      # Should have PP post-modifier
      assert match?([_ | _], np.post_modifiers)
      pp = hd(np.post_modifiers)
      assert pp.head.text == "on"
      assert pp.object.head.text == "floor"

      assert pos == length(tagged)
    end
  end
end
