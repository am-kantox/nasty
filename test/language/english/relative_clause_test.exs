defmodule Nasty.Language.English.RelativeClauseTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.RelativeClause
  alias Nasty.Language.English.{PhraseParser, POSTagger, Tokenizer}

  describe "relative clauses with 'that'" do
    test "parses 'that' as subject relativizer" do
      {:ok, tokens} = Tokenizer.tokenize("the cat that sits")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      # Parse the whole NP including relative clause
      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert %RelativeClause{} = rc
      assert rc.relativizer.text == "that"
      assert rc.type == :restrictive
      assert rc.clause.type == :relative
      # Relativizer is implicit subject
      assert rc.clause.subject == nil
      assert rc.clause.predicate != nil
    end

    test "parses 'that' as object relativizer" do
      {:ok, tokens} = Tokenizer.tokenize("the cat that I see")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert rc.relativizer.text == "that"
      # "I" is the subject
      assert rc.clause.subject != nil
      # "see" is the predicate
      assert rc.clause.predicate != nil
    end
  end

  describe "relative clauses with 'which'" do
    test "parses 'which' as subject relativizer" do
      {:ok, tokens} = Tokenizer.tokenize("the dog which ran")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert rc.relativizer.text == "which"
      assert rc.clause.type == :relative
    end

    test "parses 'which' as object relativizer" do
      {:ok, tokens} = Tokenizer.tokenize("the book which I read")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert rc.relativizer.text == "which"
      assert rc.clause.subject != nil
    end
  end

  describe "relative clauses with 'who'" do
    test "parses 'who' as subject relativizer" do
      {:ok, tokens} = Tokenizer.tokenize("the person who laughed")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert rc.relativizer.text == "who"
      assert rc.clause.type == :relative
      assert rc.clause.subject == nil
    end

    test "parses 'who' as object relativizer" do
      {:ok, tokens} = Tokenizer.tokenize("the person who I met")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert rc.relativizer.text == "who"
      assert rc.clause.subject != nil
    end
  end

  describe "relative clauses with adverbs" do
    test "parses 'where' relative adverb" do
      {:ok, tokens} = Tokenizer.tokenize("the place where I live")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert rc.relativizer.text == "where"
      assert rc.clause.type == :relative
    end

    test "parses 'when' relative adverb" do
      {:ok, tokens} = Tokenizer.tokenize("the day when I arrived")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert length(np.post_modifiers) == 1
      [rc] = np.post_modifiers

      assert rc.relativizer.text == "when"
    end
  end

  describe "complex noun phrases" do
    test "parses noun phrase with both PP and relative clause" do
      {:ok, tokens} = Tokenizer.tokenize("the cat on the mat that sits")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      # The RC "that sits" attaches to "the mat" (right-attachment),
      # so top-level NP has 1 post-modifier (the PP),
      # and the PP's object NP has 1 post-modifier (the RC)
      assert length(np.post_modifiers) == 1
      [pp] = np.post_modifiers
      assert pp.__struct__ == Nasty.AST.PrepositionalPhrase
      assert length(pp.object.post_modifiers) == 1
    end

    test "parses NP with adjective and relative clause" do
      {:ok, tokens} = Tokenizer.tokenize("the big cat that runs")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, np, _} = PhraseParser.parse_noun_phrase(tagged, 0)

      assert np.determiner.text == "the"
      assert length(np.modifiers) == 1
      assert hd(np.modifiers).text == "big"
      assert np.head.text == "cat"
      assert length(np.post_modifiers) == 1
    end
  end
end
