defmodule Nasty.Language.English.ComplexSentencesTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.English.{POSTagger, SentenceParser, Tokenizer}

  describe "coordinated sentences" do
    test "parses sentence with 'and' coordination" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat and the dog ran.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.structure == :compound
      assert length(sentence.additional_clauses) == 1

      # Check both clauses have subjects and predicates
      assert sentence.main_clause.subject != nil
      assert sentence.main_clause.predicate != nil

      [second_clause] = sentence.additional_clauses
      assert second_clause.subject != nil
      assert second_clause.predicate != nil
    end

    test "parses sentence with 'but' coordination" do
      {:ok, tokens} = Tokenizer.tokenize("I ran but he walked.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.structure == :compound
      assert length(sentence.additional_clauses) == 1
    end

    test "parses sentence with 'or' coordination" do
      {:ok, tokens} = Tokenizer.tokenize("Stay here or come with me.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.structure == :compound
    end
  end

  describe "subordinate clauses" do
    test "parses sentence starting with 'because'" do
      {:ok, tokens} = Tokenizer.tokenize("Because I ran home.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      # Sentence starting with subordinate clause is a fragment
      assert sentence.main_clause.type == :subordinate
      assert sentence.main_clause.subordinator != nil
      assert sentence.main_clause.subordinator.text == "Because"
    end

    test "parses sentence with 'although'" do
      {:ok, tokens} = Tokenizer.tokenize("Although it rained today.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.main_clause.type == :subordinate
    end

    test "parses sentence with 'if'" do
      {:ok, tokens} = Tokenizer.tokenize("If you go there.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.main_clause.type == :subordinate
      assert sentence.main_clause.subordinator.text == "If"
    end
  end

  describe "simple sentence classification" do
    test "identifies simple sentence correctly" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.structure == :simple
      assert sentence.main_clause.type == :independent
      assert sentence.additional_clauses == []
    end
  end

  describe "sentence function" do
    test "identifies declarative sentence" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.function == :declarative
    end

    test "identifies interrogative sentence" do
      {:ok, tokens} = Tokenizer.tokenize("Did the cat sit?")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.function == :interrogative
    end

    test "identifies exclamative sentence" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat!")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      assert sentence.function == :exclamative
    end
  end
end
