#!/usr/bin/env elixir

# Comprehensive Demo of Nasty NLP Library
# This script demonstrates all major features of the library

Mix.install([{:nasty, path: "."}])

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("NASTY NLP LIBRARY - COMPREHENSIVE DEMO")
IO.puts(String.duplicate("=", 80) <> "\n")

# Sample text for demonstrations
sample_text = """
John Smith is a software engineer at Google. He graduated from Stanford University 
in 2010 with a degree in Computer Science. Google is headquartered in Mountain View, 
California. The company was founded by Larry Page and Sergey Brin in 1998.
John loves working on natural language processing and machine learning projects.
"""

alias Nasty.AST.{Sentence, Token}
alias Nasty.Language.English
alias Nasty.Utils.{Query, Traversal, Transform, Validator}
alias Nasty.Rendering.{Text, PrettyPrint, Visualization}

# ============================================================================
# SECTION 1: Basic Text Processing
# ============================================================================

IO.puts("SECTION 1: Basic Text Processing")
IO.puts(String.duplicate("-", 80))

IO.puts("\n1.1 Tokenization")
{:ok, tokens} = English.tokenize(sample_text)
IO.puts("Total tokens: #{length(tokens)}")
IO.puts("First 10 tokens: #{Enum.take(tokens, 10) |> Enum.map(& &1.text) |> Enum.join(", ")}")

IO.puts("\n1.2 POS Tagging (Rule-based)")
{:ok, tagged} = English.tag_pos(tokens)
IO.puts("Sample tagged tokens:")
Enum.take(tagged, 10)
|> Enum.each(fn token ->
  IO.puts("  #{token.text}: #{token.pos_tag}")
end)

IO.puts("\n1.3 Morphological Analysis")
alias Nasty.Language.English.Morphology

Enum.take(tagged, 5)
|> Enum.each(fn token ->
  lemma = Morphology.lemmatize(token.text, token.pos_tag)
  IO.puts("  #{token.text} -> #{lemma} [#{token.pos_tag}]")
end)

# ============================================================================
# SECTION 2: Parsing and AST Construction
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 2: Parsing and AST Construction")
IO.puts(String.duplicate("-", 80))

IO.puts("\nParsing document...")
{:ok, document} = English.parse(tagged)

IO.puts("\nDocument Structure:")
IO.puts("  Paragraphs: #{length(document.paragraphs)}")
IO.puts("  Sentences: #{Query.count(document, :sentence)}")
IO.puts("  Tokens: #{Query.count(document, :token)}")
IO.puts("  Noun Phrases: #{Query.count(document, :noun_phrase)}")
IO.puts("  Verb Phrases: #{Query.count(document, :verb_phrase)}")

# ============================================================================
# SECTION 3: Queries and Information Extraction
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 3: Queries and Information Extraction")
IO.puts(String.duplicate("-", 80))

IO.puts("\n3.1 Find by POS Tag")
nouns = Query.find_by_pos(document, :noun)
IO.puts("Nouns found: #{Enum.map(nouns, & &1.text) |> Enum.join(", ")}")

verbs = Query.find_by_pos(document, :verb)
IO.puts("Verbs found: #{Enum.map(verbs, & &1.text) |> Enum.join(", ")}")

IO.puts("\n3.2 Find Noun Phrases")
noun_phrases = Query.find_all(document, :noun_phrase)
IO.puts("Found #{length(noun_phrases)} noun phrases:")
Enum.take(noun_phrases, 5)
|> Enum.each(fn np ->
  det = if np.determiner, do: np.determiner.text <> " ", else: ""
  mods = Enum.map(np.modifiers, & &1.text) |> Enum.join(" ")
  mods = if mods != "", do: mods <> " ", else: ""
  head = np.head.text
  IO.puts("  - #{det}#{mods}#{head}")
end)

IO.puts("\n3.3 Content vs Function Words")
content = Query.content_words(document)
function_words = Query.function_words(document)
IO.puts("Content words: #{length(content)}, Function words: #{length(function_words)}")

# ============================================================================
# SECTION 4: Named Entity Recognition
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 4: Named Entity Recognition")
IO.puts(String.duplicate("-", 80))

alias Nasty.Language.English.EntityRecognizer
entities = EntityRecognizer.recognize(tagged)

IO.puts("\nEntities found:")
Enum.each(entities, fn entity ->
  IO.puts("  #{entity.text}: #{entity.type} (confidence: #{Float.round(entity.confidence, 2)})")
end)

IO.puts("\nPeople:")
Query.extract_entities(document, type: :PERSON)
|> Enum.each(fn entity ->
  IO.puts("  - #{entity.text}")
end)

# ============================================================================
# SECTION 5: Dependency Extraction
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 5: Dependency Relations")
IO.puts(String.duplicate("-", 80))

alias Nasty.Language.English.DependencyExtractor

sentences = document.paragraphs |> Enum.flat_map(& &1.sentences)
first_sentence = List.first(sentences)

IO.puts("\nDependencies in first sentence:")
deps = DependencyExtractor.extract(first_sentence)
Enum.take(deps, 8)
|> Enum.each(fn dep ->
  IO.puts("  #{dep.head.text} --#{dep.relation}--> #{dep.dependent.text}")
end)

# ============================================================================
# SECTION 6: AST Traversal
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 6: AST Traversal")
IO.puts(String.duplicate("-", 80))

IO.puts("\n6.1 Count nodes using traversal")
token_count = Traversal.reduce(document, 0, fn
  %{__struct__: Token}, acc -> acc + 1
  _, acc -> acc
end)
IO.puts("Tokens counted via traversal: #{token_count}")

IO.puts("\n6.2 Collect specific nodes")
proper_nouns = Traversal.collect(document, fn
  %{__struct__: Token, pos_tag: :propn} -> true
  _ -> false
end)
IO.puts("Proper nouns: #{Enum.map(proper_nouns, & &1.text) |> Enum.join(", ")}")

IO.puts("\n6.3 Find first interrogative sentence")
question = Traversal.find(document, fn
  %{__struct__: Sentence, function: :interrogative} -> true
  _ -> false
end)
IO.puts("Question found: #{if question, do: "Yes", else: "No (no questions in text)"}")

# ============================================================================
# SECTION 7: AST Transformations
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 7: AST Transformations")
IO.puts(String.duplicate("-", 80))

IO.puts("\n7.1 Lowercase transformation")
lowercased = Transform.normalize_case(document, :lower)
{:ok, lower_text} = Text.render(lowercased)
IO.puts("Lowercased: #{String.slice(lower_text, 0..80)}...")

IO.puts("\n7.2 Remove punctuation")
no_punct = Transform.remove_punctuation(document)
{:ok, no_punct_text} = Text.render(no_punct)
IO.puts("No punctuation: #{String.slice(no_punct_text, 0..80)}...")

IO.puts("\n7.3 Remove stop words")
no_stops = Transform.remove_stop_words(document)
{:ok, no_stops_text} = Text.render(no_stops)
IO.puts("No stop words: #{String.slice(no_stops_text, 0..80)}...")

IO.puts("\n7.4 Lemmatization")
lemmatized = Transform.lemmatize(document)
{:ok, lemma_text} = Text.render(lemmatized)
IO.puts("Lemmatized: #{String.slice(lemma_text, 0..80)}...")

IO.puts("\n7.5 Transformation pipeline")
processed = Transform.pipeline(document, [
  &Transform.normalize_case(&1, :lower),
  &Transform.remove_punctuation/1,
  &Transform.remove_stop_words/1
])
{:ok, processed_text} = Text.render(processed)
IO.puts("Pipeline result: #{String.slice(processed_text, 0..80)}...")

# ============================================================================
# SECTION 8: Validation
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 8: AST Validation")
IO.puts(String.duplicate("-", 80))

IO.puts("\n8.1 Validate structure")
case Validator.validate(document) do
  {:ok, _} -> IO.puts("✓ Document structure is valid")
  {:error, reason} -> IO.puts("✗ Validation error: #{reason}")
end

IO.puts("\n8.2 Validate spans")
case Validator.validate_spans(document) do
  :ok -> IO.puts("✓ Position spans are consistent")
  {:error, reason} -> IO.puts("✗ Span error: #{reason}")
end

IO.puts("\n8.3 Validate language consistency")
case Validator.validate_language(document) do
  :ok -> IO.puts("✓ Language markers are consistent")
  {:error, reason} -> IO.puts("✗ Language error: #{reason}")
end

# ============================================================================
# SECTION 9: Rendering Back to Text
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 9: Rendering Back to Text")
IO.puts(String.duplicate("-", 80))

IO.puts("\n9.1 Basic rendering")
{:ok, rendered} = Text.render(document)
IO.puts("Rendered text (first 100 chars):")
IO.puts("  #{String.slice(rendered, 0..100)}...")

IO.puts("\n9.2 Custom rendering options")
{:ok, custom_rendered} = Text.render(document,
  capitalize_sentences: false,
  paragraph_separator: " "
)
IO.puts("Custom rendering (first 100 chars):")
IO.puts("  #{String.slice(custom_rendered, 0..100)}...")

# ============================================================================
# SECTION 10: Pretty Printing
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 10: Pretty Printing")
IO.puts(String.duplicate("-", 80))

IO.puts("\n10.1 Statistics")
IO.puts(PrettyPrint.stats(document))

IO.puts("\n10.2 Tree view (first sentence only)")
first_sent = document.paragraphs |> List.first() |> Map.get(:sentences) |> List.first()
tree = PrettyPrint.tree(first_sent)
IO.puts(String.slice(tree, 0..500) <> "...")

IO.puts("\n10.3 Indented view (limited depth)")
indented = PrettyPrint.print(first_sent, max_depth: 2)
IO.puts(String.slice(indented, 0..300) <> "...")

# ============================================================================
# SECTION 11: Visualization Export
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 11: Visualization Export")
IO.puts(String.duplicate("-", 80))

IO.puts("\n11.1 Export parse tree to DOT format")
dot = Visualization.to_dot(first_sent, type: :parse_tree)
IO.puts("DOT format generated (#{String.length(dot)} bytes)")
IO.puts("Preview:")
IO.puts(String.slice(dot, 0..200) <> "...")

IO.puts("\n11.2 Export to JSON")
json = Visualization.to_json(first_sent)
IO.puts("JSON format generated (#{String.length(json)} bytes)")

# ============================================================================
# SECTION 12: Advanced NLP - Summarization
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 12: Text Summarization")
IO.puts(String.duplicate("-", 80))

summary = English.summarize(document, max_sentences: 2)
IO.puts("\nSummary (2 sentences):")
IO.puts("  #{inspect(summary)}")

# ============================================================================
# SECTION 13: Code Interoperability
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 13: Code Interoperability")
IO.puts(String.duplicate("-", 80))

IO.puts("\n13.1 Natural Language to Code")
commands = [
  "Sort the list",
  "Filter users where age is greater than 18",
  "Map the numbers"
]

Enum.each(commands, fn command ->
  case English.to_code(command) do
    {:ok, code} -> IO.puts("  \"#{command}\" → #{code}")
    {:error, _} -> IO.puts("  \"#{command}\" → [could not generate]")
  end
end)

IO.puts("\n13.2 Code to Natural Language")
code_examples = [
  "Enum.sort(numbers)",
  "Enum.filter(users, fn u -> u.age > 18 end)"
]

Enum.each(code_examples, fn code ->
  case English.explain_code(code) do
    {:ok, explanation} -> IO.puts("  #{code} → \"#{explanation}\"")
    {:error, _} -> IO.puts("  #{code} → [could not explain]")
  end
end)

# ============================================================================
# SECTION 14: Question Answering
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("SECTION 14: Question Answering")
IO.puts(String.duplicate("-", 80))

questions = [
  "Who works at Google?",
  "Where is Google located?",
  "When was Google founded?"
]

Enum.each(questions, fn question ->
  IO.puts("\nQ: #{question}")
  case English.answer_question(document, question) do
    {:ok, answers} ->
      if Enum.empty?(answers) do
        IO.puts("  A: [no answer found]")
      else
        Enum.take(answers, 2)
        |> Enum.each(fn answer ->
          IO.puts("  A: #{answer.text} (confidence: #{Float.round(answer.confidence, 2)})")
        end)
      end
    {:error, reason} ->
      IO.puts("  Error: #{inspect(reason)}")
  end
end)

# ============================================================================
# Summary
# ============================================================================

IO.puts("\n\n" <> String.duplicate("=", 80))
IO.puts("DEMO COMPLETE")
IO.puts(String.duplicate("=", 80))

IO.puts("""

This demo showcased:
  ✓ Tokenization and POS tagging
  ✓ Morphological analysis
  ✓ AST construction and parsing
  ✓ Queries and information extraction
  ✓ Named entity recognition
  ✓ Dependency parsing
  ✓ AST traversal patterns
  ✓ AST transformations
  ✓ Validation
  ✓ Text rendering
  ✓ Pretty printing and debugging
  ✓ Visualization export (DOT, JSON)
  ✓ Text summarization
  ✓ Code interoperability
  ✓ Question answering

For more examples, see the examples/ directory.
For documentation, see docs/USER_GUIDE.md
""")
