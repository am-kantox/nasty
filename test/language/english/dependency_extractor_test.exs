defmodule Nasty.Language.English.DependencyExtractorTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.English.{DependencyExtractor, POSTagger, SentenceParser, Tokenizer}

  describe "simple sentences" do
    test "extracts subject dependency" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Should have: det→cat, nsubj→sat
      assert match?([_, _ | _], deps)

      # Find nsubj relation
      nsubj = Enum.find(deps, fn d -> d.relation == :nsubj end)
      assert nsubj != nil
      assert nsubj.head.text == "sat"
      assert nsubj.dependent.text == "cat"

      # Find det relation
      det = Enum.find(deps, fn d -> d.relation == :det end)
      assert det != nil
      assert det.head.text == "cat"
      assert det.dependent.text == "The"
    end

    test "extracts object dependency" do
      {:ok, tokens} = Tokenizer.tokenize("I see the cat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Find obj relation
      obj = Enum.find(deps, fn d -> d.relation == :obj end)
      assert obj != nil
      assert obj.head.text == "see"
      assert obj.dependent.text == "cat"

      # Find nsubj relation
      nsubj = Enum.find(deps, fn d -> d.relation == :nsubj end)
      assert nsubj != nil
      assert nsubj.head.text == "see"
      assert nsubj.dependent.text == "I"
    end
  end

  describe "modifiers" do
    test "extracts adjectival modifier" do
      {:ok, tokens} = Tokenizer.tokenize("The big cat sat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Find amod relation
      amod = Enum.find(deps, fn d -> d.relation == :amod end)
      assert amod != nil
      assert amod.head.text == "cat"
      assert amod.dependent.text == "big"
    end

    test "extracts auxiliary" do
      {:ok, tokens} = Tokenizer.tokenize("The cat will run.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Find aux relation
      aux = Enum.find(deps, fn d -> d.relation == :aux end)
      assert aux != nil
      assert aux.head.text == "run"
      assert aux.dependent.text == "will"
    end
  end

  describe "prepositional phrases" do
    test "extracts oblique and case relations" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat on the mat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Find case relation (on → mat)
      case_dep = Enum.find(deps, fn d -> d.relation == :case end)
      assert case_dep != nil
      assert case_dep.head.text == "mat"
      assert case_dep.dependent.text == "on"

      # Find obl relation (sat → mat)
      obl = Enum.find(deps, fn d -> d.relation == :obl end)
      assert obl != nil
      assert obl.head.text == "sat"
      assert obl.dependent.text == "mat"
    end

    test "extracts nmod for PP modifying noun" do
      {:ok, tokens} = Tokenizer.tokenize("The cat on the mat sat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Find nmod relation (cat → mat)
      nmod = Enum.find(deps, fn d -> d.relation == :nmod end)
      assert nmod != nil
      assert nmod.head.text == "cat"
      assert nmod.dependent.text == "mat"
    end
  end

  describe "relative clauses" do
    test "extracts acl and mark relations" do
      {:ok, tokens} = Tokenizer.tokenize("I see the cat that sits.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Find acl relation (cat → sits)
      acl = Enum.find(deps, fn d -> d.relation == :acl end)
      assert acl != nil
      assert acl.head.text == "cat"
      assert acl.dependent.text == "sits"

      # Find mark relation (sits → that)
      mark = Enum.find(deps, fn d -> d.relation == :mark end)
      assert mark != nil
      assert mark.head.text == "sits"
      assert mark.dependent.text == "that"
    end

    test "extracts dependencies within relative clause" do
      {:ok, tokens} = Tokenizer.tokenize("I met the person who runs.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Should have acl for RC (person → runs)
      acl =
        Enum.find(deps, fn d ->
          d.relation == :acl && d.head.text == "person"
        end)

      assert acl != nil
      assert acl.dependent.text == "runs"
    end
  end

  describe "coordination" do
    test "extracts dependencies from coordinated clauses" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat and the dog ran.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Should have nsubj for both clauses
      nsubj_deps = Enum.filter(deps, fn d -> d.relation == :nsubj end)
      assert match?([_, _], nsubj_deps)

      # One for "cat sat"
      assert Enum.any?(nsubj_deps, fn d ->
               d.head.text == "sat" && d.dependent.text == "cat"
             end)

      # One for "dog ran"
      assert Enum.any?(nsubj_deps, fn d ->
               d.head.text == "ran" && d.dependent.text == "dog"
             end)
    end
  end

  describe "subordinate clauses" do
    test "extracts mark relation for subordinator" do
      {:ok, tokens} = Tokenizer.tokenize("Because I ran home.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Find mark relation (ran → Because)
      mark = Enum.find(deps, fn d -> d.relation == :mark end)
      assert mark != nil
      assert mark.head.text == "ran"
      assert mark.dependent.text == "Because"
    end
  end

  describe "complex sentences" do
    test "extracts all dependencies from complex sentence" do
      {:ok, tokens} = Tokenizer.tokenize("The big cat sat on the mat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Count expected relations:
      # 1. det: The → cat
      # 2. amod: big → cat
      # 3. nsubj: cat → sat
      # 4. case: on → mat
      # 5. det: the → mat
      # 6. obl: sat → mat

      assert match?([_, _, _, _, _, _], deps)

      # Verify each type exists
      assert Enum.any?(deps, fn d -> d.relation == :det end)
      assert Enum.any?(deps, fn d -> d.relation == :amod end)
      assert Enum.any?(deps, fn d -> d.relation == :nsubj end)
      assert Enum.any?(deps, fn d -> d.relation == :case end)
      assert Enum.any?(deps, fn d -> d.relation == :obl end)
    end
  end

  describe "passive voice constructions" do
    test "correctly identifies dependencies in passive voice with 'by' phrase" do
      # "The book was written by the author."
      # In passive voice: subject is "book" (patient), auxiliary "was", verb "written", agent "author"
      {:ok, tokens} = Tokenizer.tokenize("The book was written by the author.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Should extract:
      # - det: The → book
      # - nsubj: book → written (or nsubj:pass in full UD)
      # - aux: was → written (auxiliary for passive)
      # - case: by → author
      # - det: the → author
      # - obl: written → author (or obl:agent for agent phrase)

      # Find subject relation
      nsubj = Enum.find(deps, fn d -> d.relation == :nsubj end)
      assert nsubj != nil
      assert nsubj.dependent.text == "book"
      assert nsubj.head.text == "written"

      # Find auxiliary
      aux = Enum.find(deps, fn d -> d.relation == :aux end)
      assert aux != nil
      assert aux.dependent.text == "was"
      assert aux.head.text == "written"

      # Find agent phrase ("by the author")
      # The preposition "by" should have a case relation to "author"
      case_dep = Enum.find(deps, fn d -> d.relation == :case && d.dependent.text == "by" end)
      assert case_dep != nil
      assert case_dep.head.text == "author"

      # Find oblique relation for agent
      obl = Enum.find(deps, fn d -> d.relation == :obl && d.dependent.text == "author" end)
      assert obl != nil
      assert obl.head.text == "written"
    end

    test "identifies dependencies in simple passive without agent" do
      # "The door was closed."
      {:ok, tokens} = Tokenizer.tokenize("The door was closed.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Should have:
      # - det: The → door
      # - nsubj: door → closed
      # - aux: was → closed

      nsubj = Enum.find(deps, fn d -> d.relation == :nsubj end)
      assert nsubj != nil
      assert nsubj.dependent.text == "door"

      aux = Enum.find(deps, fn d -> d.relation == :aux end)
      assert aux != nil
      assert aux.dependent.text == "was"
    end

    test "handles passive voice with perfect aspect" do
      # "The letter has been sent."
      {:ok, tokens} = Tokenizer.tokenize("The letter has been sent.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, [sentence]} = SentenceParser.parse_sentences(tagged)

      deps = DependencyExtractor.extract(sentence)

      # Should identify subject
      nsubj = Enum.find(deps, fn d -> d.relation == :nsubj end)
      assert nsubj != nil
      assert nsubj.dependent.text == "letter"

      # Should have multiple auxiliaries: "has" and "been"
      aux_deps = Enum.filter(deps, fn d -> d.relation == :aux end)
      assert match?([_ | _], aux_deps)

      aux_words = Enum.map(aux_deps, & &1.dependent.text)
      assert "has" in aux_words or "been" in aux_words
    end
  end
end
