# Nasty User Guide

A comprehensive guide to using the Nasty NLP library for natural language processing in Elixir.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Core Concepts](#core-concepts)
5. [Basic Text Processing](#basic-text-processing)
6. [Phrase and Sentence Parsing](#phrase-and-sentence-parsing)
7. [Semantic Analysis](#semantic-analysis)
8. [Advanced NLP Operations](#advanced-nlp-operations)
9. [Code Interoperability](#code-interoperability)
10. [AST Manipulation](#ast-manipulation)
11. [Visualization and Debugging](#visualization-and-debugging)
12. [Statistical Models](#statistical-models)
13. [Performance Tips](#performance-tips)
14. [Troubleshooting](#troubleshooting)

## Introduction

Nasty (Natural Abstract Syntax Treey) is a comprehensive NLP library that treats natural language with the same rigor as programming languages. It provides a complete grammatical Abstract Syntax Tree (AST) for English, enabling sophisticated text analysis and manipulation.

### Key Features

- **Complete NLP Pipeline**: From tokenization to summarization
- **Grammar-First Design**: Linguistically rigorous AST structure
- **Statistical Models**: HMM POS tagger with 95% accuracy
- **Bidirectional Code Conversion**: Natural language ↔ Elixir code
- **AST Utilities**: Traversal, querying, validation, and transformation
- **Visualization**: Export to DOT/Graphviz and JSON formats

## Installation

Add `nasty` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nasty, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

Here's a simple example to get started:

```elixir
alias Nasty.Language.English

# Parse a sentence
text = "The quick brown fox jumps over the lazy dog."
{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

# Extract information
alias Nasty.Utils.Query

# Count tokens
token_count = Query.count(document, :token)
# => 9

# Find all nouns
nouns = Query.find_by_pos(document, :noun)
# => [%Token{text: "fox", ...}, %Token{text: "dog", ...}]

# Render back to text
alias Nasty.Rendering.Text
{:ok, text} = Text.render(document)
# => "The quick brown fox jumps over the lazy dog."
```

## Core Concepts

### AST Structure

Nasty represents text as a hierarchical tree structure:

```
Document
└── Paragraph
    └── Sentence
        └── Clause
            ├── Subject (NounPhrase)
            │   ├── Determiner (Token)
            │   ├── Modifiers (Tokens)
            │   └── Head (Token)
            └── Predicate (VerbPhrase)
                ├── Auxiliaries (Tokens)
                ├── Head (Token)
                └── Complements (NounPhrases, etc.)
```

### Universal Dependencies

All POS tags and dependency relations follow the Universal Dependencies standard:

**POS Tags**: `noun`, `verb`, `adj`, `adv`, `det`, `adp`, `aux`, `cconj`, `sconj`, `pron`, `propn`, `num`, `punct`

**Dependencies**: `nsubj`, `obj`, `iobj`, `amod`, `advmod`, `det`, `case`, `acl`, `advcl`, `conj`, `cc`

### Language Markers

Every AST node carries a language identifier (`:en` for English), enabling future multilingual support.

## Basic Text Processing

### Tokenization

Split text into tokens (words and punctuation):

```elixir
alias Nasty.Language.English

text = "Hello, world! How are you?"
{:ok, tokens} = English.tokenize(text)

# Tokens include position information
Enum.each(tokens, fn token ->
  IO.puts("#{token.text} at #{inspect(token.span)}")
end)
```

### POS Tagging

Assign grammatical categories to tokens:

```elixir
# Rule-based tagging (fast)
{:ok, tagged} = English.tag_pos(tokens)

# Statistical tagging (higher accuracy)
{:ok, tagged} = English.tag_pos(tokens, model: :hmm)

# Ensemble (best of both)
{:ok, tagged} = English.tag_pos(tokens, model: :ensemble)

# Inspect tags
Enum.each(tagged, fn token ->
  IO.puts("#{token.text}: #{token.pos_tag}")
end)
```

### Morphological Analysis

Extract lemmas and morphological features:

```elixir
alias Nasty.Language.English.Morphology

tagged
|> Enum.map(fn token ->
  lemma = Morphology.lemmatize(token.text, token.pos_tag)
  features = Morphology.extract_features(token.text, token.pos_tag)
  {token.text, lemma, features}
end)
|> Enum.each(fn {text, lemma, features} ->
  IO.puts("#{text} -> #{lemma} (#{inspect(features)})")
end)
```

## Phrase and Sentence Parsing

### Building the AST

Parse tokens into a complete AST:

```elixir
text = "The cat sat on the mat."
{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

# Access structure
paragraph = List.first(document.paragraphs)
sentence = List.first(paragraph.sentences)
IO.puts("Sentence type: #{sentence.function}, #{sentence.structure}")
```

### Phrase Structure

Extract and analyze phrases:

```elixir
alias Nasty.Utils.Query

# Find all noun phrases
noun_phrases = Query.find_all(document, :noun_phrase)

Enum.each(noun_phrases, fn np ->
  det = if np.determiner, do: np.determiner.text, else: ""
  mods = Enum.map(np.modifiers, & &1.text) |> Enum.join(" ")
  head = np.head.text
  IO.puts("NP: #{det} #{mods} #{head}")
end)

# Find verb phrases
verb_phrases = Query.find_all(document, :verb_phrase)

Enum.each(verb_phrases, fn vp ->
  aux = Enum.map(vp.auxiliaries, & &1.text) |> Enum.join(" ")
  verb = vp.head.text
  IO.puts("VP: #{aux} #{verb}")
end)
```

### Sentence Structure Analysis

Analyze sentence complexity:

```elixir
document.paragraphs
|> Enum.flat_map(& &1.sentences)
|> Enum.each(fn sentence ->
  IO.puts("Function: #{sentence.function}")
  IO.puts("Structure: #{sentence.structure}")
  IO.puts("Clauses: #{1 + length(sentence.additional_clauses)}")
  IO.puts("")
end)
```

### Dependency Relations

Extract grammatical dependencies:

```elixir
alias Nasty.Language.English.DependencyExtractor

sentences = document.paragraphs |> Enum.flat_map(& &1.sentences)

Enum.each(sentences, fn sentence ->
  deps = DependencyExtractor.extract(sentence)
  
  Enum.each(deps, fn dep ->
    IO.puts("#{dep.head.text} --#{dep.relation}--> #{dep.dependent.text}")
  end)
end)
```

## Semantic Analysis

### Named Entity Recognition

Extract and classify named entities:

```elixir
alias Nasty.Language.English.EntityRecognizer

text = "John Smith works at Google in New York."
{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)

entities = EntityRecognizer.recognize(tagged)

Enum.each(entities, fn entity ->
  IO.puts("#{entity.text}: #{entity.type} (confidence: #{entity.confidence})")
end)
# => John Smith: PERSON (confidence: 0.8)
#    Google: ORG (confidence: 0.8)
#    New York: GPE (confidence: 0.7)
```

### Semantic Role Labeling

Identify who did what to whom:

```elixir
{:ok, document} = English.parse(tagged, semantic_roles: true)

document.semantic_frames
|> Enum.each(fn frame ->
  IO.puts("Predicate: #{frame.predicate}")
  
  Enum.each(frame.roles, fn role ->
    IO.puts("  #{role.type}: #{role.text}")
  end)
end)
# => Predicate: works
#      agent: John Smith
#      location: at Google
```

### Coreference Resolution

Link mentions across sentences:

```elixir
text = """
John Smith is a software engineer. He works at Google.
The company is based in Mountain View.
"""

{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged, coreference: true)

document.coref_chains
|> Enum.each(fn chain ->
  IO.puts("Representative: #{chain.representative.text}")
  IO.puts("Mentions: #{Enum.map(chain.mentions, & &1.text) |> Enum.join(", ")}")
end)
# => Representative: John Smith
#    Mentions: John Smith, He
```

## Advanced NLP Operations

### Text Summarization

Extract key sentences from documents:

```elixir
alias Nasty.Language.English

long_text = """
[Your long document here...]
"""

{:ok, tokens} = English.tokenize(long_text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

# Extractive summarization - compression ratio
summary = English.summarize(document, ratio: 0.3)
IO.puts("30% summary:")
IO.puts(summary)

# Fixed sentence count
summary = English.summarize(document, max_sentences: 3)

# MMR for reduced redundancy
summary = English.summarize(document, 
  max_sentences: 3, 
  method: :mmr, 
  mmr_lambda: 0.5
)
```

### Question Answering

Answer questions from documents:

```elixir
text = """
John Smith is a software engineer at Google.
He graduated from Stanford University in 2010.
Google is headquartered in Mountain View, California.
"""

{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

# Ask questions
questions = [
  "Who works at Google?",
  "Where is Google located?",
  "When did John Smith graduate?",
  "What is John Smith's profession?"
]

Enum.each(questions, fn question ->
  {:ok, answers} = English.answer_question(document, question)
  
  IO.puts("Q: #{question}")
  Enum.each(answers, fn answer ->
    IO.puts("A: #{answer.text} (confidence: #{answer.confidence})")
  end)
  IO.puts("")
end)
```

### Text Classification

Train and apply classifiers:

```elixir
alias Nasty.Language.English

# Prepare training data
positive_reviews = [
  "This product is amazing! Highly recommended.",
  "Excellent quality and fast shipping.",
  "Love it! Best purchase ever."
]

negative_reviews = [
  "Terrible product. Waste of money.",
  "Poor quality and slow delivery.",
  "Very disappointed with this purchase."
]

# Parse documents
training_data =
  Enum.map(positive_reviews, fn text ->
    {:ok, tokens} = English.tokenize(text)
    {:ok, tagged} = English.tag_pos(tokens)
    {:ok, doc} = English.parse(tagged)
    {doc, :positive}
  end) ++
  Enum.map(negative_reviews, fn text ->
    {:ok, tokens} = English.tokenize(text)
    {:ok, tagged} = English.tag_pos(tokens)
    {:ok, doc} = English.parse(tagged)
    {doc, :negative}
  end)

# Train classifier
model = English.train_classifier(training_data, 
  features: [:bow, :lexical]
)

# Classify new text
test_text = "Great product, very satisfied!"
{:ok, tokens} = English.tokenize(test_text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, doc} = English.parse(tagged)

{:ok, predictions} = English.classify(doc, model)
IO.inspect(predictions)
```

### Information Extraction

Extract structured information:

```elixir
text = """
Apple Inc. acquired Beats Electronics for $3 billion in 2014.
The company is headquartered in Cupertino, California.
Tim Cook serves as CEO of Apple.
"""

{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

# Extract relations
{:ok, relations} = English.extract_relations(document)
Enum.each(relations, fn rel ->
  IO.puts("#{rel.subject.text} --#{rel.type}--> #{rel.object.text}")
end)

# Extract events
{:ok, events} = English.extract_events(document)
Enum.each(events, fn event ->
  IO.puts("Event: #{event.type}")
  IO.puts("Trigger: #{event.trigger}")
  IO.puts("Participants: #{inspect(event.participants)}")
end)

# Template-based extraction
alias Nasty.Language.English.TemplateExtractor

templates = [
  TemplateExtractor.employment_template(),
  TemplateExtractor.acquisition_template()
]

{:ok, results} = English.extract_templates(document, templates)
Enum.each(results, fn result ->
  IO.puts("Template: #{result.template}")
  IO.puts("Slots: #{inspect(result.slots)}")
end)
```

## Code Interoperability

### Natural Language to Code

Convert natural language commands to Elixir code:

```elixir
alias Nasty.Language.English

# Simple operations
{:ok, code} = English.to_code("Sort the list")
IO.puts(code)
# => "Enum.sort(list)"

{:ok, code} = English.to_code("Filter users where age is greater than 18")
IO.puts(code)
# => "Enum.filter(users, fn item -> item > 18 end)"

{:ok, code} = English.to_code("Map the numbers to double each one")
IO.puts(code)
# => "Enum.map(numbers, fn item -> item * 2 end)"

# Get the AST
{:ok, ast} = English.to_code_ast("Sort the numbers")
IO.inspect(ast)

# Recognize intent without generating code
{:ok, intent} = English.recognize_intent("Filter the list")
IO.inspect(intent)
```

### Code to Natural Language

Explain code in natural language:

```elixir
alias Nasty.Language.English

# Explain code strings
{:ok, explanation} = English.explain_code("Enum.sort(numbers)")
IO.puts(explanation)
# => "sort numbers"

{:ok, explanation} = English.explain_code("""
list
|> Enum.map(&(&1 * 2))
|> Enum.filter(&(&1 > 10))
|> Enum.sum()
""")
IO.puts(explanation)
# => "map list to each element times 2, then filter list where item is greater than 10, then sum list"

# Explain from AST
code_ast = quote do: x = a + b
{:ok, doc} = English.explain_code_to_document(code_ast)
{:ok, text} = Nasty.Rendering.Text.render(doc)
IO.puts(text)
```

## AST Manipulation

### Traversal

Walk the AST tree:

```elixir
alias Nasty.Utils.Traversal

# Count all tokens
token_count = Traversal.reduce(document, 0, fn
  %Nasty.AST.Token{}, acc -> acc + 1
  _, acc -> acc
end)

# Collect all verbs
verbs = Traversal.collect(document, fn
  %Nasty.AST.Token{pos_tag: :verb} -> true
  _ -> false
end)

# Find first question
question = Traversal.find(document, fn
  %Nasty.AST.Sentence{function: :interrogative} -> true
  _ -> false
end)

# Transform tree (lowercase all text)
lowercased = Traversal.map(document, fn
  %Nasty.AST.Token{} = token ->
    %{token | text: String.downcase(token.text)}
  node ->
    node
end)

# Breadth-first traversal
nodes = Traversal.walk_breadth(document, [], fn node, acc ->
  {:cont, [node | acc]}
end)
```

### Queries

High-level querying API:

```elixir
alias Nasty.Utils.Query

# Find by type
noun_phrases = Query.find_all(document, :noun_phrase)
sentences = Query.find_all(document, :sentence)

# Find by POS tag
nouns = Query.find_by_pos(document, :noun)
verbs = Query.find_by_pos(document, :verb)

# Find by text pattern
cats = Query.find_by_text(document, "cat")
words_starting_with_s = Query.find_by_text(document, ~r/^s/i)

# Find by lemma
runs = Query.find_by_lemma(document, "run")  # Matches "run", "runs", "running"

# Extract entities
all_entities = Query.extract_entities(document)
people = Query.extract_entities(document, type: :PERSON)
organizations = Query.extract_entities(document, type: :ORG)

# Structural queries
subject = Query.find_subject(sentence)
verb = Query.find_main_verb(sentence)
objects = Query.find_objects(sentence)

# Count nodes
token_count = Query.count(document, :token)
sentence_count = Query.count(document, :sentence)

# Content vs function words
content_words = Query.content_words(document)
function_words = Query.function_words(document)

# Custom predicates
long_words = Query.filter(document, fn
  %Nasty.AST.Token{text: text} -> String.length(text) > 7
  _ -> false
end)
```

### Transformations

Modify AST structures:

```elixir
alias Nasty.Utils.Transform

# Case normalization
lowercased = Transform.normalize_case(document, :lower)
uppercased = Transform.normalize_case(document, :upper)
titled = Transform.normalize_case(document, :title)

# Remove punctuation
no_punct = Transform.remove_punctuation(document)

# Remove stop words
no_stops = Transform.remove_stop_words(document)

# Custom stop words
custom_stops = ["the", "a", "an"]
filtered = Transform.remove_stop_words(document, custom_stops)

# Lemmatize all tokens
lemmatized = Transform.lemmatize(document)

# Replace tokens
masked = Transform.replace_tokens(
  document,
  fn token -> token.pos_tag == :propn end,
  fn token -> %{token | text: "[MASK]"} end
)

# Transformation pipelines
processed = Transform.pipeline(document, [
  &Transform.normalize_case(&1, :lower),
  &Transform.remove_punctuation/1,
  &Transform.remove_stop_words/1,
  &Transform.lemmatize/1
])

# Round-trip testing
{:ok, transformed} = Transform.round_trip_test(document, fn doc ->
  Transform.normalize_case(doc, :lower)
end)
```

### Validation

Ensure AST integrity:

```elixir
alias Nasty.Utils.Validator

# Validate structure
case Validator.validate(document) do
  {:ok, doc} -> IO.puts("Valid!")
  {:error, reason} -> IO.puts("Invalid: #{reason}")
end

# Check validity (boolean)
if Validator.valid?(document) do
  IO.puts("Document is valid")
end

# Validate spans
case Validator.validate_spans(document) do
  :ok -> IO.puts("Spans are consistent")
  {:error, reason} -> IO.puts("Span error: #{reason}")
end

# Validate language consistency
case Validator.validate_language(document) do
  :ok -> IO.puts("Language is consistent")
  {:error, reason} -> IO.puts("Language error: #{reason}")
end

# Validate and raise
Validator.validate!(document)  # Raises on error
```

## Visualization and Debugging

### Pretty Printing

Debug AST structures:

```elixir
alias Nasty.Rendering.PrettyPrint

# Indented output
IO.puts(PrettyPrint.print(document))

# With colors
IO.puts(PrettyPrint.print(document, color: true))

# Limit depth
IO.puts(PrettyPrint.print(document, max_depth: 3))

# Show spans
IO.puts(PrettyPrint.print(document, show_spans: true))

# Tree-style output
IO.puts(PrettyPrint.tree(document))

# Statistics
IO.puts(PrettyPrint.stats(document))
```

### Graphviz Visualization

Export to DOT format for visual rendering:

```elixir
alias Nasty.Rendering.Visualization

# Parse tree
dot = Visualization.to_dot(document, type: :parse_tree)
File.write("parse_tree.dot", dot)
# Then: dot -Tpng parse_tree.dot -o parse_tree.png

# Dependency graph
deps_dot = Visualization.to_dot(sentence, 
  type: :dependencies,
  rankdir: "LR"
)
File.write("dependencies.dot", deps_dot)

# Entity graph
entity_dot = Visualization.to_dot(document, type: :entities)
File.write("entities.dot", entity_dot)

# Custom options
dot = Visualization.to_dot(document,
  type: :parse_tree,
  rankdir: "TB",
  show_pos_tags: true,
  show_spans: false
)
```

### JSON Export

Export for web visualization:

```elixir
alias Nasty.Rendering.Visualization

# Export to JSON (for d3.js, etc.)
json = Visualization.to_json(document)
File.write("document.json", json)

# Can be loaded in JavaScript:
# fetch('document.json')
#   .then(r => r.json())
#   .then(data => visualize(data))
```

### Text Rendering

Convert AST back to text:

```elixir
alias Nasty.Rendering.Text

# Basic rendering
{:ok, text} = Text.render(document)

# Custom options
{:ok, text} = Text.render(document,
  capitalize_sentences: false,
  add_punctuation: false,
  paragraph_separator: "\n\n"
)

# Render with agreement helper
{subject, verb} = Text.apply_agreement("cat", "run", :en)
# => {"cat", "runs"}
```

## Statistical Models

### Using Pretrained Models

Load and use statistical models:

```elixir
alias Nasty.Language.English

# Automatic loading (looks in priv/models/)
{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens, model: :hmm)

# Ensemble mode (combines rule-based + statistical)
{:ok, tagged} = English.tag_pos(tokens, model: :ensemble)
```

### Training Custom Models

Train on your own data:

```bash
# Download Universal Dependencies data
wget https://lindat.mff.cuni.cz/repository/xmlui/bitstream/handle/11234/1-4611/ud-treebanks-v2.10.tgz

# Extract
tar -xzf ud-treebanks-v2.10.tgz

# Train model
mix nasty.train.pos \
  --corpus ud-treebanks-v2.10/UD_English-EWT/en_ewt-ud-train.conllu \
  --test ud-treebanks-v2.10/UD_English-EWT/en_ewt-ud-test.conllu \
  --output priv/models/en/my_model.model

# Evaluate
mix nasty.eval.pos \
  --model priv/models/en/my_model.model \
  --test ud-treebanks-v2.10/UD_English-EWT/en_ewt-ud-test.conllu
```

### Model Management

```bash
# List models
mix nasty.models list

# Inspect model
mix nasty.models inspect priv/models/en/pos_hmm_v1.model

# Compare models
mix nasty.models compare model1.model model2.model
```

## Performance Tips

### Batch Processing

Process multiple texts efficiently:

```elixir
alias Nasty.Language.English

texts = [
  "First sentence.",
  "Second sentence.",
  "Third sentence."
]

# Process in parallel
results = 
  texts
  |> Task.async_stream(fn text ->
    with {:ok, tokens} <- English.tokenize(text),
         {:ok, tagged} <- English.tag_pos(tokens),
         {:ok, doc} <- English.parse(tagged) do
      {:ok, doc}
    end
  end, max_concurrency: System.schedulers_online())
  |> Enum.map(fn {:ok, result} -> result end)
```

### Selective Parsing

Skip expensive operations when not needed:

```elixir
# Basic parsing (no semantic analysis)
{:ok, doc} = English.parse(tokens)

# With semantic roles
{:ok, doc} = English.parse(tokens, semantic_roles: true)

# With coreference
{:ok, doc} = English.parse(tokens, coreference: true)

# Full pipeline
{:ok, doc} = English.parse(tokens,
  semantic_roles: true,
  coreference: true
)
```

### Caching

Cache parsed documents:

```elixir
defmodule MyApp.DocumentCache do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get_or_parse(text) do
    Agent.get_and_update(__MODULE__, fn cache ->
      case Map.fetch(cache, text) do
        {:ok, doc} ->
          {doc, cache}
        :error ->
          {:ok, tokens} = English.tokenize(text)
          {:ok, tagged} = English.tag_pos(tokens)
          {:ok, doc} = English.parse(tagged)
          {doc, Map.put(cache, text, doc)}
      end
    end)
  end
end
```

## Troubleshooting

### Common Issues

**Issue**: Parsing fails with long sentences

**Solution**: Break into smaller sentences or increase timeout

```elixir
# Split long text
sentences = String.split(text, ~r/[.!?]+/)
Enum.map(sentences, &English.parse/1)
```

**Issue**: Entity recognition misses entities

**Solution**: Train custom NER or add to dictionary

```elixir
# Add custom entity patterns
alias Nasty.Language.English.EntityRecognizer

# This is conceptual - check actual API
EntityRecognizer.add_pattern(:ORG, ~r/\b[A-Z][a-z]+ Inc\.\b/)
```

**Issue**: POS tagging accuracy is low

**Solution**: Use statistical model or ensemble

```elixir
# Use HMM model
{:ok, tagged} = English.tag_pos(tokens, model: :hmm)

# Or ensemble
{:ok, tagged} = English.tag_pos(tokens, model: :ensemble)
```

### Debugging Tips

1. **Visualize the AST**: Use pretty printing to understand structure
2. **Check spans**: Ensure position tracking is correct
3. **Validate**: Run validation to catch structural issues
4. **Incremental parsing**: Test each pipeline stage separately

```elixir
# Debug pipeline stage by stage
{:ok, tokens} = English.tokenize(text)
IO.inspect(tokens, label: "Tokens")

{:ok, tagged} = English.tag_pos(tokens)
IO.inspect(tagged, label: "Tagged")

{:ok, doc} = English.parse(tagged)
IO.puts(PrettyPrint.tree(doc))
```

### Getting Help

- Check the [API documentation](https://hexdocs.pm/nasty/)
- Review [PLAN.md](../PLAN.md) for architecture details
- See [examples/](../examples/) for working code
- Report issues on [GitHub](https://github.com/am-kantox/nasty/issues)

## Next Steps

- Explore the [examples/](../examples/) directory for more demos
- Read [STATISTICAL_MODELS.md](STATISTICAL_MODELS.md) for ML details
- Check [TRAINING_GUIDE.md](TRAINING_GUIDE.md) to train custom models
- See [INTEROP_GUIDE.md](INTEROP_GUIDE.md) for code conversion details

Happy parsing!
