defmodule Nasty.Language.English.QuestionAnsweringTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.English
  alias Nasty.Language.English.{AnswerExtractor, QuestionAnalyzer}
  alias Nasty.AST.{Answer, Document}

  # Sample document for testing
  @sample_text """
  John Smith founded Google in 1998 with his partner Larry Page.
  The company is headquartered in Mountain View, California.
  Google has become one of the largest technology companies in the world.
  The search engine processes billions of queries every day.
  """

  setup do
    {:ok, tokens} = English.tokenize(@sample_text)
    {:ok, tagged} = English.tag_pos(tokens)
    {:ok, document} = English.parse(tagged)

    {:ok, document: document}
  end

  describe "QuestionAnalyzer.analyze/1" do
    test "classifies WHO questions" do
      question = "Who founded Google?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :who
      assert analysis.answer_type == :person
      assert length(analysis.keywords) > 0
    end

    test "classifies WHAT questions" do
      question = "What is Google?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :what
      assert analysis.answer_type == :thing
    end

    test "classifies WHEN questions" do
      question = "When was Google founded?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :when
      assert analysis.answer_type == :time
    end

    test "classifies WHERE questions" do
      question = "Where is Google located?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :where
      assert analysis.answer_type == :location
    end

    test "classifies HOW questions" do
      question = "How does Google work?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :how
      assert analysis.answer_type == :manner
    end

    test "classifies HOW MANY questions as quantity" do
      question = "How many employees does Google have?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :how
      assert analysis.answer_type == :quantity
    end

    test "classifies YES/NO questions" do
      question = "Is Google a search engine?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :yes_no
      assert analysis.answer_type == :boolean
    end

    test "extracts keywords from questions" do
      question = "Who founded Google in California?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      keyword_texts = Enum.map(analysis.keywords, & &1.text)
      assert "founded" in keyword_texts or "found" in keyword_texts
      assert "Google" in keyword_texts
    end

    test "handles empty question" do
      assert {:error, :empty_question} = QuestionAnalyzer.analyze([])
    end

    test "refines WHAT TIME to time answer type" do
      question = "What time does the store open?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)

      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      assert analysis.type == :what
      assert analysis.answer_type == :time
    end
  end

  describe "QuestionAnalyzer.expects_entity_type?/2" do
    test "WHO questions expect person entities" do
      analysis = %QuestionAnalyzer{type: :who, answer_type: :person, keywords: [], focus: nil}
      assert QuestionAnalyzer.expects_entity_type?(analysis, :person)
      refute QuestionAnalyzer.expects_entity_type?(analysis, :org)
    end

    test "WHERE questions expect location entities" do
      analysis = %QuestionAnalyzer{
        type: :where,
        answer_type: :location,
        keywords: [],
        focus: nil
      }

      assert QuestionAnalyzer.expects_entity_type?(analysis, :gpe)
      assert QuestionAnalyzer.expects_entity_type?(analysis, :loc)
      refute QuestionAnalyzer.expects_entity_type?(analysis, :person)
    end
  end

  describe "QuestionAnalyzer.describe/1" do
    test "generates readable description" do
      analysis = %QuestionAnalyzer{type: :who, answer_type: :person, keywords: [], focus: nil}
      description = QuestionAnalyzer.describe(analysis)

      assert description == "WHO question expecting PERSON answer"
    end
  end

  describe "AnswerExtractor.extract/3" do
    test "extracts person answers for WHO questions", %{document: document} do
      question = "Who founded Google?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      answers = AnswerExtractor.extract(document, analysis)

      assert length(answers) > 0
      assert Enum.any?(answers, fn answer -> String.contains?(answer.text, "Smith") end)
    end

    test "extracts location answers for WHERE questions", %{document: document} do
      question = "Where is Google located?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      answers = AnswerExtractor.extract(document, analysis)

      assert length(answers) > 0
      # Should find California or Mountain View
      assert Enum.any?(answers, fn answer ->
               String.contains?(answer.text, "California") or
                 String.contains?(answer.text, "Mountain") or
                 String.contains?(answer.text, "View")
             end)
    end

    test "extracts temporal answers for WHEN questions", %{document: document} do
      question = "When was Google founded?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      answers = AnswerExtractor.extract(document, analysis)

      assert length(answers) > 0
      # Should find 1998
      assert Enum.any?(answers, fn answer -> String.contains?(answer.text, "1998") end)
    end

    test "respects max_answers option", %{document: document} do
      question = "What is in the document?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      answers = AnswerExtractor.extract(document, analysis, max_answers: 2)

      assert length(answers) <= 2
    end

    test "respects min_confidence option", %{document: document} do
      question = "What is mentioned?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      answers = AnswerExtractor.extract(document, analysis, min_confidence: 0.8)

      # All answers should have high confidence
      assert Enum.all?(answers, fn answer -> answer.confidence >= 0.8 end)
    end

    test "returns answers sorted by confidence", %{document: document} do
      question = "What companies are mentioned?"
      {:ok, tokens} = English.tokenize(question)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, analysis} = QuestionAnalyzer.analyze(tagged)

      answers = AnswerExtractor.extract(document, analysis)

      if length(answers) > 1 do
        # Check that answers are sorted by confidence descending
        confidences = Enum.map(answers, & &1.confidence)
        assert confidences == Enum.sort(confidences, :desc)
      end
    end

    test "returns empty list when no answer found" do
      text = "The sky is blue. Birds can fly."
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      question = "Who founded Microsoft?"
      {:ok, q_tokens} = English.tokenize(question)
      {:ok, q_tagged} = English.tag_pos(q_tokens)
      {:ok, analysis} = QuestionAnalyzer.analyze(q_tagged)

      answers = AnswerExtractor.extract(document, analysis)

      # Should return empty or very low confidence answers
      assert answers == [] or Enum.all?(answers, fn a -> a.confidence < 0.5 end)
    end
  end

  describe "English.answer_question/3" do
    test "answers WHO questions", %{document: document} do
      {:ok, answers} = English.answer_question(document, "Who founded Google?")

      assert is_list(answers)
      assert length(answers) > 0
      assert Enum.all?(answers, &match?(%Answer{}, &1))
    end

    test "answers WHERE questions", %{document: document} do
      {:ok, answers} = English.answer_question(document, "Where is Google?")

      assert is_list(answers)
      # Should find location entities
      assert Enum.any?(answers, fn answer ->
               String.contains?(answer.text, "California") or
                 String.contains?(answer.text, "Mountain") or
                 String.contains?(answer.text, "View")
             end)
    end

    test "answers WHEN questions", %{document: document} do
      {:ok, answers} = English.answer_question(document, "When was Google founded?")

      assert is_list(answers)
      assert Enum.any?(answers, fn answer -> String.contains?(answer.text, "1998") end)
    end

    test "answers WHAT questions", %{document: document} do
      {:ok, answers} = English.answer_question(document, "What company is mentioned?")

      assert is_list(answers)
      assert length(answers) > 0
    end

    test "respects options", %{document: document} do
      {:ok, answers} = English.answer_question(document, "What is mentioned?", max_answers: 1)

      assert length(answers) <= 1
    end

    test "handles malformed questions gracefully" do
      text = "Sample text about nothing."
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      # Question with no clear answer in document
      result = English.answer_question(document, "When did aliens arrive?")

      assert {:ok, answers} = result
      assert is_list(answers)
    end
  end

  describe "Answer struct" do
    test "creates answer with required fields" do
      answer = Answer.new("test answer", 0.85, :en)

      assert answer.text == "test answer"
      assert answer.confidence == 0.85
      assert answer.language == :en
    end

    test "creates answer with optional fields" do
      answer =
        Answer.new("test", 0.9, :en,
          span: {0, 1, 3},
          reasoning: "keyword match"
        )

      assert answer.span == {0, 1, 3}
      assert answer.reasoning == "keyword match"
    end

    test "checks confidence threshold" do
      high = Answer.new("high", 0.9, :en)
      low = Answer.new("low", 0.3, :en)

      assert Answer.confident?(high, 0.7)
      refute Answer.confident?(low, 0.7)
    end

    test "sorts answers by confidence" do
      answers = [
        Answer.new("low", 0.3, :en),
        Answer.new("high", 0.9, :en),
        Answer.new("mid", 0.6, :en)
      ]

      sorted = Answer.sort_by_confidence(answers)
      confidences = Enum.map(sorted, & &1.confidence)

      assert confidences == [0.9, 0.6, 0.3]
    end
  end

  describe "integration tests" do
    test "full pipeline from text to answers" do
      text = """
      Albert Einstein was born in 1879 in Germany.
      He developed the theory of relativity.
      Einstein received the Nobel Prize in Physics in 1921.
      """

      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      # Test multiple question types
      {:ok, who_answers} = English.answer_question(document, "Who developed relativity?")
      assert Enum.any?(who_answers, fn a -> String.contains?(a.text, "Einstein") end)

      {:ok, when_answers} = English.answer_question(document, "When was Einstein born?")
      assert Enum.any?(when_answers, fn a -> String.contains?(a.text, "1879") end)

      {:ok, where_answers} = English.answer_question(document, "Where was Einstein born?")
      assert Enum.any?(where_answers, fn a -> String.contains?(a.text, "Germany") end)
    end

    test "handles complex documents" do
      text = """
      Natural language processing is a field of artificial intelligence.
      It focuses on enabling computers to understand human language.
      Google and Microsoft have invested heavily in NLP research.
      Machine learning models power modern NLP systems.
      These systems can translate languages and answer questions.
      """

      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      {:ok, what_answers} = English.answer_question(document, "What is NLP?")
      assert length(what_answers) > 0

      {:ok, who_answers} = English.answer_question(document, "Who invests in NLP?")

      assert Enum.any?(who_answers, fn a ->
               String.contains?(a.text, "Google") or String.contains?(a.text, "Microsoft")
             end)
    end
  end
end
