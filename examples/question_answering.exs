# Question Answering Examples
# ============================
#
# Demonstrates extractive question answering capabilities:
# - WHO questions (person entities)
# - WHAT questions (organizations, things)
# - WHEN questions (temporal expressions)
# - WHERE questions (locations)
# - HOW questions (manner, quantity)
#
# Run with: mix run examples/question_answering.exs

alias Nasty.Language.English

defmodule QADemo do
  def section(title) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("  #{title}")
    IO.puts(String.duplicate("=", 80) <> "\n")
  end

  def subsection(title) do
    IO.puts("\n#{title}")
    IO.puts(String.duplicate("-", String.length(title)))
  end

  def ask_question(document, question) do
    IO.puts("\nQ: #{question}")

    case English.answer_question(document, question) do
      {:ok, []} ->
        IO.puts("A: No answer found.")

      {:ok, answers} ->
        answers
        |> Enum.take(3)
        |> Enum.with_index(1)
        |> Enum.each(fn {answer, idx} ->
          confidence_pct = Float.round(answer.confidence * 100, 1)
          IO.puts("A#{idx}: #{answer.text} (confidence: #{confidence_pct}%)")

          if answer.reasoning do
            IO.puts("    Reasoning: #{answer.reasoning}")
          end
        end)

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end
end

# =============================================================================
# EXAMPLE 1: TECHNOLOGY COMPANIES
# =============================================================================

QADemo.section("EXAMPLE 1: TECHNOLOGY COMPANIES")

text1 = """
Google was founded by Larry Page and Sergey Brin in 1998 while they were students at Stanford University.
The company is headquartered in Mountain View, California.
Google's search engine processes billions of queries every day.
Microsoft and Apple are major competitors in the technology industry.
"""

IO.puts("Document Text:")
IO.puts(String.duplicate("-", 80))
IO.puts(text1)

{:ok, tokens} = English.tokenize(text1)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

QADemo.subsection("Asking Questions")

QADemo.ask_question(document, "Who founded Google?")
QADemo.ask_question(document, "When was Google founded?")
QADemo.ask_question(document, "Where is Google located?")
QADemo.ask_question(document, "What companies are mentioned?")

# =============================================================================
# EXAMPLE 2: HISTORICAL FIGURES
# =============================================================================

QADemo.section("EXAMPLE 2: HISTORICAL FIGURES")

text2 = """
Albert Einstein was born in Germany in 1879.
He developed the theory of relativity in the early 1900s.
Einstein received the Nobel Prize in Physics in 1921 for his work on the photoelectric effect.
He moved to the United States in 1933 and worked at Princeton University.
Einstein died in 1955 at the age of 76.
"""

IO.puts("Document Text:")
IO.puts(String.duplicate("-", 80))
IO.puts(text2)

{:ok, tokens2} = English.tokenize(text2)
{:ok, tagged2} = English.tag_pos(tokens2)
{:ok, document2} = English.parse(tagged2)

QADemo.subsection("Asking Questions")

QADemo.ask_question(document2, "Who developed the theory of relativity?")
QADemo.ask_question(document2, "When was Einstein born?")
QADemo.ask_question(document2, "Where did Einstein work in America?")
QADemo.ask_question(document2, "What prize did Einstein receive?")
QADemo.ask_question(document2, "When did Einstein die?")

# =============================================================================
# EXAMPLE 3: NATURAL LANGUAGE PROCESSING
# =============================================================================

QADemo.section("EXAMPLE 3: NATURAL LANGUAGE PROCESSING")

text3 = """
Natural language processing is a subfield of artificial intelligence and linguistics.
It focuses on enabling computers to understand, interpret, and generate human language.
Google and Microsoft have invested billions in NLP research and development.
Modern NLP systems use deep learning models trained on massive text corpora.
Applications include machine translation, sentiment analysis, and question answering.
"""

IO.puts("Document Text:")
IO.puts(String.duplicate("-", 80))
IO.puts(text3)

{:ok, tokens3} = English.tokenize(text3)
{:ok, tagged3} = English.tag_pos(tokens3)
{:ok, document3} = English.parse(tagged3)

QADemo.subsection("Asking Questions")

QADemo.ask_question(document3, "What is natural language processing?")
QADemo.ask_question(document3, "Who invests in NLP?")
QADemo.ask_question(document3, "What do NLP systems use?")

# =============================================================================
# EXAMPLE 4: MULTIPLE ANSWERS
# =============================================================================

QADemo.section("EXAMPLE 4: MULTIPLE ANSWERS WITH CONFIDENCE SCORES")

text4 = """
The project was led by John Smith and Mary Johnson.
Sarah Williams contributed to the research phase.
Tom Brown and Lisa Davis worked on implementation.
The team completed the project in 2023.
"""

IO.puts("Document Text:")
IO.puts(String.duplicate("-", 80))
IO.puts(text4)

{:ok, tokens4} = English.tokenize(text4)
{:ok, tagged4} = English.tag_pos(tokens4)
{:ok, document4} = English.parse(tagged4)

QADemo.subsection("Asking Questions")

IO.puts("\nQ: Who worked on the project?")
IO.puts("(showing all answers with confidence scores)")

{:ok, answers} = English.answer_question(document4, "Who worked on the project?", max_answers: 5)

if answers == [] do
  IO.puts("No answers found.")
else
  answers
  |> Enum.with_index(1)
  |> Enum.each(fn {answer, idx} ->
    confidence_pct = Float.round(answer.confidence * 100, 1)
    IO.puts("#{idx}. #{answer.text} (#{confidence_pct}%)")
  end)
end

# =============================================================================
# EXAMPLE 5: UNANSWERABLE QUESTIONS
# =============================================================================

QADemo.section("EXAMPLE 5: UNANSWERABLE QUESTIONS")

text5 = """
The weather today is sunny and warm.
Birds are singing in the trees.
It's a beautiful day outside.
"""

IO.puts("Document Text:")
IO.puts(String.duplicate("-", 80))
IO.puts(text5)

{:ok, tokens5} = English.tokenize(text5)
{:ok, tagged5} = English.tag_pos(tokens5)
{:ok, document5} = English.parse(tagged5)

QADemo.subsection("Asking Questions That Cannot Be Answered")

QADemo.ask_question(document5, "Who is the president?")
QADemo.ask_question(document5, "When was the company founded?")

IO.puts("\nNote: When questions cannot be answered from the document,")
IO.puts("the system returns empty results or very low confidence answers.")

# =============================================================================
# EXAMPLE 6: DIFFERENT QUESTION TYPES
# =============================================================================

QADemo.section("EXAMPLE 6: DIFFERENT QUESTION TYPES")

text6 = """
The International Space Station orbits Earth at an altitude of approximately 400 kilometers.
It travels at a speed of about 28,000 kilometers per hour.
The station has been continuously occupied since November 2000.
Astronauts from many countries have lived and worked on the ISS.
"""

IO.puts("Document Text:")
IO.puts(String.duplicate("-", 80))
IO.puts(text6)

{:ok, tokens6} = English.tokenize(text6)
{:ok, tagged6} = English.tag_pos(tokens6)
{:ok, document6} = English.parse(tagged6)

QADemo.subsection("Various Question Types")

QADemo.ask_question(document6, "What orbits Earth?")
QADemo.ask_question(document6, "How fast does the station travel?")
QADemo.ask_question(document6, "When did continuous occupation begin?")
QADemo.ask_question(document6, "Who has lived on the ISS?")

# =============================================================================
# SUMMARY
# =============================================================================

QADemo.section("SUMMARY")

IO.puts("""
The Nasty question answering system demonstrates:

1. Question Classification
   - Identifies question type (WHO, WHAT, WHEN, WHERE, WHY, HOW)
   - Determines expected answer type (person, location, time, etc.)

2. Answer Extraction
   - Keyword matching with lemmatization
   - Entity type filtering (persons, organizations, locations)
   - Temporal expression recognition
   - Confidence scoring

3. Multiple Answer Support
   - Returns ranked list of candidate answers
   - Confidence scores help identify best answers
   - Configurable result limits

4. Graceful Handling
   - Returns empty results for unanswerable questions
   - Low confidence scores indicate uncertain answers

For more advanced features, the system can be extended with:
- Semantic role labeling for better answer extraction
- Coreference resolution for pronoun handling
- Dependency parsing for relationship extraction
- Machine learning models for improved accuracy
""")

IO.puts(String.duplicate("=", 80))
