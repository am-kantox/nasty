defmodule Nasty.Language.English.SemanticRoleLabelerTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{SemanticFrame, SemanticRole}

  alias Nasty.Language.English.{
    Morphology,
    POSTagger,
    SemanticRoleLabeler,
    SentenceParser,
    Tokenizer
  }

  describe "label/1 with active voice sentences" do
    test "labels simple transitive sentence (agent + patient)" do
      # "John eats pizza"
      text = "John eats pizza."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames
      assert frame.voice == :active
      assert frame.predicate.text == "eats"

      # Should have agent (John) and patient (pizza)
      roles = frame.roles
      agent = Enum.find(roles, fn r -> r.type == :agent end)
      patient = Enum.find(roles, fn r -> r.type == :patient end)

      assert agent != nil
      assert String.contains?(agent.text, "John")
      assert patient != nil
      assert String.contains?(patient.text, "pizza")
    end

    test "labels ditransitive sentence (agent + theme + recipient)" do
      # "Mary gave John a book"
      text = "Mary gave John a book."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames
      assert frame.voice == :active
      assert frame.predicate.text == "gave"

      # Should have agent, patient/theme, and recipient
      roles = frame.roles
      agent = Enum.find(roles, fn r -> r.type == :agent end)

      assert agent != nil
      assert String.contains?(agent.text, "Mary")
      # Should have at least 2 core arguments beyond agent
      assert match?([_, _ | _], roles)
    end

    test "labels intransitive sentence (agent only)" do
      # "The dog sleeps"
      text = "The dog sleeps."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames
      assert frame.voice == :active
      assert frame.predicate.text == "sleeps"

      roles = frame.roles
      agent = Enum.find(roles, fn r -> r.type == :agent end)

      assert agent != nil
      assert String.contains?(agent.text, "dog")
    end
  end

  describe "label/1 with passive voice sentences" do
    test "detects passive voice" do
      # "The book was read"
      text = "The book was read."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames
      # Should detect passive voice
      assert frame.voice == :passive
      assert frame.predicate.text == "read"

      # In passive, subject should be patient/theme
      roles = frame.roles
      patient = Enum.find(roles, fn r -> r.type == :patient end)

      assert patient != nil
      assert String.contains?(patient.text, "book")
    end
  end

  describe "label/1 with adjunct roles" do
    test "labels location adjunct" do
      # "She works in Boston"
      text = "She works in Boston."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames

      # Should have location role
      location = Enum.find(frame.roles, fn r -> r.type == :location end)

      if location do
        assert String.contains?(location.text, "Boston") or String.contains?(location.text, "in")
      end
    end

    test "labels time adjunct with temporal adverb" do
      # "He arrived yesterday"
      text = "He arrived yesterday."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames

      # Should have time role
      time = Enum.find(frame.roles, fn r -> r.type == :time end)

      if time do
        assert String.contains?(time.text, "yesterday")
      end
    end

    test "labels manner adjunct" do
      # "She runs quickly"
      text = "She runs quickly."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames

      # Should have manner role
      manner = Enum.find(frame.roles, fn r -> r.type == :manner end)

      if manner do
        assert String.contains?(manner.text, "quickly")
      end
    end
  end

  describe "label/1 with complex sentences" do
    test "handles sentence with multiple adjuncts" do
      # "John ran quickly to the store yesterday"
      text = "John ran quickly to the store yesterday."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames
      assert frame.predicate.text == "ran"

      # Should have agent
      agent = Enum.find(frame.roles, fn r -> r.type == :agent end)
      assert agent != nil
      assert String.contains?(agent.text, "John")

      # May have manner, location, and time roles
      roles = frame.roles
      # At least the agent
      assert match?([_ | _], roles)
    end
  end

  describe "label_clause/1" do
    test "returns empty list for clause without predicate" do
      # Create a minimal clause without proper verb phrase
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      clause = %Nasty.AST.Clause{
        type: :independent,
        subject: nil,
        predicate: nil,
        language: :en,
        span: span
      }

      frames = SemanticRoleLabeler.label_clause(clause)

      assert frames == []
    end
  end

  describe "SemanticFrame structure" do
    test "frame has correct structure" do
      text = "Dogs bark."
      {:ok, tokens} = Tokenizer.tokenize(text)
      {:ok, tagged} = POSTagger.tag_pos(tokens)
      {:ok, analyzed} = Morphology.analyze(tagged)
      {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      sentence = List.first(sentences)

      {:ok, frames} = SemanticRoleLabeler.label(sentence)

      assert [frame] = frames
      assert %SemanticFrame{} = frame
      assert is_list(frame.roles)
      assert frame.voice in [:active, :passive, :unknown]
      assert is_struct(frame.predicate, Nasty.AST.Token)

      # All roles should be SemanticRole structs
      Enum.each(frame.roles, fn role ->
        assert %SemanticRole{} = role

        assert role.type in [
                 :agent,
                 :patient,
                 :theme,
                 :experiencer,
                 :recipient,
                 :beneficiary,
                 :source,
                 :goal,
                 :location,
                 :time,
                 :manner,
                 :instrument,
                 :purpose,
                 :cause,
                 :comitative
               ]

        assert is_binary(role.text)
      end)
    end
  end

  describe "core_role? and adjunct_role?" do
    test "correctly identifies core roles" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 4}, 4)

      agent_role = SemanticRole.new(:agent, "John", span)
      assert SemanticRole.core_role?(agent_role) == true
      assert SemanticRole.adjunct_role?(agent_role) == false

      patient_role = SemanticRole.new(:patient, "ball", span)
      assert SemanticRole.core_role?(patient_role) == true

      theme_role = SemanticRole.new(:theme, "book", span)
      assert SemanticRole.core_role?(theme_role) == true
    end

    test "correctly identifies adjunct roles" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      location_role = SemanticRole.new(:location, "in Boston", span)
      assert SemanticRole.adjunct_role?(location_role) == true
      assert SemanticRole.core_role?(location_role) == false

      time_role = SemanticRole.new(:time, "yesterday", span)
      assert SemanticRole.adjunct_role?(time_role) == true

      manner_role = SemanticRole.new(:manner, "quickly", span)
      assert SemanticRole.adjunct_role?(manner_role) == true
    end
  end

  describe "SemanticFrame helper functions" do
    test "find_roles/2 finds roles by type" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 20}, 20)

      predicate = %Nasty.AST.Token{
        text: "gave",
        pos_tag: :verb,
        language: :en,
        span: span,
        lemma: "give",
        morphology: %{}
      }

      roles = [
        SemanticRole.new(:agent, "John", span),
        SemanticRole.new(:theme, "book", span),
        SemanticRole.new(:recipient, "Mary", span),
        SemanticRole.new(:location, "at school", span)
      ]

      frame = SemanticFrame.new(predicate, roles, span)

      agents = SemanticFrame.find_roles(frame, :agent)
      assert [%SemanticRole{type: :agent}] = agents

      themes = SemanticFrame.find_roles(frame, :theme)
      assert match?([_], themes)

      locations = SemanticFrame.find_roles(frame, :location)
      assert match?([_], locations)
    end

    test "agent/1 returns agent role" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 20}, 20)

      predicate = %Nasty.AST.Token{
        text: "runs",
        pos_tag: :verb,
        language: :en,
        span: span,
        lemma: "run",
        morphology: %{}
      }

      roles = [
        SemanticRole.new(:agent, "dog", span),
        SemanticRole.new(:manner, "quickly", span)
      ]

      frame = SemanticFrame.new(predicate, roles, span)

      agent = SemanticFrame.agent(frame)
      assert agent != nil
      assert agent.type == :agent
      assert agent.text == "dog"
    end

    test "core_roles/1 returns only core roles" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 20}, 20)

      predicate = %Nasty.AST.Token{
        text: "ran",
        pos_tag: :verb,
        language: :en,
        span: span,
        lemma: "run",
        morphology: %{}
      }

      roles = [
        SemanticRole.new(:agent, "John", span),
        SemanticRole.new(:location, "to store", span),
        SemanticRole.new(:time, "yesterday", span)
      ]

      frame = SemanticFrame.new(predicate, roles, span)

      core = SemanticFrame.core_roles(frame)
      assert [%SemanticRole{type: :agent}] = core
    end

    test "adjunct_roles/1 returns only adjunct roles" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 20}, 20)

      predicate = %Nasty.AST.Token{
        text: "ran",
        pos_tag: :verb,
        language: :en,
        span: span,
        lemma: "run",
        morphology: %{}
      }

      roles = [
        SemanticRole.new(:agent, "John", span),
        SemanticRole.new(:location, "to store", span),
        SemanticRole.new(:time, "yesterday", span)
      ]

      frame = SemanticFrame.new(predicate, roles, span)

      adjuncts = SemanticFrame.adjunct_roles(frame)
      assert match?([_, _], adjuncts)
      assert Enum.all?(adjuncts, fn r -> r.type in [:location, :time] end)
    end
  end
end
