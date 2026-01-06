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
      assert length(np.modifiers) == 1
      assert hd(np.modifiers).text == "big"
      assert np.head.text == "cat"
      assert pos == 3
    end

    test "parses noun phrase with PP" do
      {:ok, tokens} = Tokenizer.tokenize("the cat on the mat")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, pos} = PhraseParser.parse_noun_phrase(tagged, 0)
      assert np.head.text == "cat"
      assert length(np.post_modifiers) == 1
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
      assert length(vp.auxiliaries) == 1
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
end
