#!/usr/bin/env elixir
#
# Nasty NLP Library - End-to-End Demo
# =====================================
#
# This demo showcases the complete NLP pipeline:
# 1. Tokenization
# 2. POS Tagging
# 3. Morphological Analysis
# 4. Phrase Structure Parsing
# 5. Dependency Extraction
# 6. Named Entity Recognition
# 7. Text Summarization

Mix.install([{:nasty, path: "."}])

alias Nasty.Language.English
alias Nasty.Language.English.{
  Tokenizer,
  POSTagger,
  DependencyExtractor,
  EntityRecognizer,
  Summarizer
}

# Helper functions for pretty printing
defmodule Demo do
  def section(title) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("  #{title}")
    IO.puts(String.duplicate("=", 80) <> "\n")
  end

  def subsection(title) do
    IO.puts("\n#{title}")
    IO.puts(String.duplicate("-", String.length(title)))
  end

  def print_tokens(tokens) do
    tokens
    |> Enum.with_index(1)
    |> Enum.each(fn {token, idx} ->
      IO.puts("  #{idx}. #{token.text} [#{token.pos_tag}]")
    end)
  end

  def print_dependencies(deps) do
    deps
    |> Enum.each(fn dep ->
      IO.puts("  #{dep.relation}: #{dep.head.text} ← #{dep.dependent.text}")
    end)
  end

  def print_entities(entities) do
    entities
    |> Enum.each(fn entity ->
      confidence = if entity.confidence, do: " (#{Float.round(entity.confidence, 2)})", else: ""
      IO.puts("  [#{entity.type}] #{entity.text}#{confidence}")
    end)
  end

  def print_sentence_tree(sentence) do
    IO.puts("  Sentence: #{sentence.function}, #{sentence.structure}")
    IO.puts("    Main Clause: #{sentence.main_clause.type}")
    
    if sentence.main_clause.subject do
      IO.puts("      Subject: #{get_phrase_head(sentence.main_clause.subject)}")
    end
    
    IO.puts("      Predicate: #{get_phrase_head(sentence.main_clause.predicate)}")
    
    if sentence.additional_clauses != [] do
      IO.puts("    Additional Clauses: #{length(sentence.additional_clauses)}")
    end
  end

  defp get_phrase_head(%{head: head}), do: head.text
  defp get_phrase_head(_), do: "?"
end

# =============================================================================
# DEMO START
# =============================================================================

Demo.section("NASTY NLP LIBRARY - COMPLETE DEMO")

IO.puts("""
This demo processes a sample text through the complete NLP pipeline,
demonstrating tokenization, POS tagging, parsing, dependency extraction,
entity recognition, and text summarization.
""")

# Sample text for processing
text = """
Natural language processing is a subfield of artificial intelligence.
It focuses on the interaction between computers and human language.
John Smith, a researcher at Stanford University, developed new techniques for machine translation.
These methods improved translation quality significantly.
Google and Microsoft have implemented similar approaches in their products.
"""

IO.puts("Input Text:")
IO.puts(String.duplicate("-", 80))
IO.puts(text)

# =============================================================================
# STEP 1: TOKENIZATION
# =============================================================================

Demo.section("STEP 1: TOKENIZATION")

IO.puts("Breaking text into tokens (words, punctuation)...\n")

{:ok, tokens} = Tokenizer.tokenize(text)

IO.puts("Total tokens: #{length(tokens)}")
Demo.subsection("First 20 tokens")
tokens |> Enum.take(20) |> Demo.print_tokens()

# =============================================================================
# STEP 2: POS TAGGING
# =============================================================================

Demo.section("STEP 2: PART-OF-SPEECH TAGGING")

IO.puts("Assigning grammatical categories to each token...\n")

{:ok, tagged} = POSTagger.tag_pos(tokens)

Demo.subsection("Sample POS tags (first 15 tokens)")
tagged
|> Enum.take(15)
|> Enum.each(fn token ->
  IO.puts("  #{String.pad_trailing(token.text, 15)} → #{token.pos_tag}")
end)

# POS tag statistics
pos_counts = Enum.frequencies_by(tagged, & &1.pos_tag)
Demo.subsection("POS Tag Distribution")
pos_counts
|> Enum.sort_by(fn {_tag, count} -> -count end)
|> Enum.take(10)
|> Enum.each(fn {tag, count} ->
  IO.puts("  #{String.pad_trailing("#{tag}", 10)} : #{count}")
end)

# =============================================================================
# STEP 3: PARSING
# =============================================================================

Demo.section("STEP 3: SYNTACTIC PARSING")

IO.puts("Building phrase structure and sentence trees...\n")

{:ok, document} = English.parse(tagged)

IO.puts("Document Structure:")
IO.puts("  Paragraphs: #{length(document.paragraphs)}")
IO.puts("  Total Sentences: #{document.metadata.sentence_count}")

Demo.subsection("Sentence Structures")
document.paragraphs
|> Enum.flat_map(& &1.sentences)
|> Enum.with_index(1)
|> Enum.each(fn {sentence, idx} ->
  IO.puts("\nSentence #{idx}:")
  Demo.print_sentence_tree(sentence)
end)

# =============================================================================
# STEP 4: DEPENDENCY EXTRACTION
# =============================================================================

Demo.section("STEP 4: DEPENDENCY EXTRACTION")

IO.puts("Extracting grammatical relationships between words...\n")

sentences = document.paragraphs |> Enum.flat_map(& &1.sentences)

Enum.with_index(sentences, 1)
|> Enum.take(2)  # Show dependencies for first 2 sentences
|> Enum.each(fn {sentence, idx} ->
  deps = DependencyExtractor.extract(sentence)
  
  Demo.subsection("Sentence #{idx} Dependencies (#{length(deps)} relations)")
  Demo.print_dependencies(deps)
end)

# Dependency statistics
all_deps = sentences |> Enum.flat_map(&DependencyExtractor.extract/1)
dep_counts = Enum.frequencies_by(all_deps, & &1.relation)

Demo.subsection("Dependency Relation Types")
dep_counts
|> Enum.sort_by(fn {_rel, count} -> -count end)
|> Enum.each(fn {rel, count} ->
  IO.puts("  #{String.pad_trailing("#{rel}", 10)} : #{count}")
end)

# =============================================================================
# STEP 5: NAMED ENTITY RECOGNITION
# =============================================================================

Demo.section("STEP 5: NAMED ENTITY RECOGNITION")

IO.puts("Identifying people, places, and organizations...\n")

entities = EntityRecognizer.recognize(tagged)

IO.puts("Total entities found: #{length(entities)}\n")
Demo.print_entities(entities)

# Entity type breakdown
entity_counts = Enum.frequencies_by(entities, & &1.type)
Demo.subsection("Entity Type Distribution")
entity_counts
|> Enum.each(fn {type, count} ->
  IO.puts("  #{String.pad_trailing("#{type}", 10)} : #{count}")
end)

# =============================================================================
# STEP 6: TEXT SUMMARIZATION
# =============================================================================

Demo.section("STEP 6: TEXT SUMMARIZATION")

IO.puts("Extracting the most important sentences...\n")

# Summarize at 40% compression
summary_sentences = Summarizer.summarize(document, ratio: 0.4)

IO.puts("Original: #{document.metadata.sentence_count} sentences")
IO.puts("Summary:  #{length(summary_sentences)} sentences (40% compression)")
IO.puts("")

Demo.subsection("Summary")
summary_sentences
|> Enum.with_index(1)
|> Enum.each(fn {sentence, idx} ->
  # Extract text from sentence structure
  subject_text = if sentence.main_clause.subject do
    "#{sentence.main_clause.subject.head.text}"
  else
    ""
  end
  
  predicate_text = "#{sentence.main_clause.predicate.head.text}"
  
  IO.puts("#{idx}. #{subject_text} #{predicate_text}...")
end)

# =============================================================================
# COMPREHENSIVE ANALYSIS
# =============================================================================

Demo.section("COMPREHENSIVE ANALYSIS")

Demo.subsection("Overall Statistics")
IO.puts("  Total Tokens:       #{length(tokens)}")
IO.puts("  Unique Words:       #{tokens |> Enum.map(&String.downcase(&1.text)) |> Enum.uniq() |> length()}")
IO.puts("  Sentences:          #{document.metadata.sentence_count}")
IO.puts("  Named Entities:     #{length(entities)}")
IO.puts("  Dependencies:       #{length(all_deps)}")

Demo.subsection("Linguistic Complexity")
avg_sentence_length = length(tokens) / document.metadata.sentence_count
IO.puts("  Avg Sentence Length: #{Float.round(avg_sentence_length, 1)} tokens")

complex_sentences = sentences
|> Enum.filter(fn s -> s.structure in [:compound, :complex] end)
|> length()

IO.puts("  Simple Sentences:    #{document.metadata.sentence_count - complex_sentences}")
IO.puts("  Complex Sentences:   #{complex_sentences}")

Demo.subsection("Entity Mentions")
entities
|> Enum.group_by(& &1.type)
|> Enum.each(fn {type, ents} ->
  names = ents |> Enum.map(& &1.text) |> Enum.join(", ")
  IO.puts("  #{type}: #{names}")
end)

# =============================================================================
# DEMO END
# =============================================================================

Demo.section("DEMO COMPLETE")

IO.puts("""
The Nasty NLP library has successfully processed the text through all stages:

✓ Tokenization       - Split text into words and punctuation
✓ POS Tagging        - Identified grammatical categories
✓ Parsing            - Built syntactic structure (NP, VP, PP, clauses)
✓ Dependencies       - Extracted grammatical relationships
✓ Entity Recognition - Found people, places, and organizations
✓ Summarization      - Selected most important sentences

For more information, see:
  - Documentation: mix docs
  - Tests: mix test
  - Source: lib/
""")

IO.puts(String.duplicate("=", 80))
