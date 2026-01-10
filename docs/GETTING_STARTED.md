# Getting Started with Nasty

A beginner-friendly guide to Natural Abstract Syntax Tree processing in Elixir.

## Table of Contents

1. [Installation](#installation)
2. [Your First Steps](#your-first-steps)
3. [Core Concepts](#core-concepts)
4. [Common Patterns](#common-patterns)
5. [Language Support](#language-support)
6. [Troubleshooting](#troubleshooting)
7. [Next Steps](#next-steps)

## Installation

### Prerequisites

- **Elixir**: Version 1.14 or later
- **Erlang/OTP**: Version 25 or later

Check your versions:
```bash
elixir --version
# Erlang/OTP 25 [erts-13.0] [source] [64-bit]
# Elixir 1.14.0 (compiled with Erlang/OTP 25)
```

### Adding Nasty to Your Project

Add `nasty` to your `mix.exs` dependencies:

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
mix compile
```

### Verifying Installation

Test that everything works:

```elixir
# In IEx
iex> alias Nasty.Language.English
iex> {:ok, tokens} = English.tokenize("Hello world!")
iex> IO.inspect(tokens)
```

## Your First Steps

### Example 1: Parse a Simple Sentence

```elixir
alias Nasty.Language.English

# Step 1: Tokenize
text = "The cat runs."
{:ok, tokens} = English.tokenize(text)

# Step 2: POS Tag
{:ok, tagged} = English.tag_pos(tokens)

# Step 3: Parse
{:ok, document} = English.parse(tagged)

# Examine the result
IO.inspect(document)
```

**What just happened?**
1. **Tokenization**: Split text into words and punctuation
2. **POS Tagging**: Assigned grammatical categories (noun, verb, etc.)
3. **Parsing**: Built an Abstract Syntax Tree (AST)

### Example 2: Extract Information

```elixir
alias Nasty.Language.English

text = "John Smith works at Google in New York."
{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)

# Extract named entities
alias Nasty.Language.English.EntityRecognizer
entities = EntityRecognizer.recognize(tagged)

Enum.each(entities, fn entity ->
  IO.puts("#{entity.text} is a #{entity.type}")
end)
# Output:
# John Smith is a person
# Google is a org
# New York is a gpe
```

### Example 3: Translate Between Languages

```elixir
alias Nasty.Language.{English, Spanish}
alias Nasty.Translation.Translator

# Parse English
{:ok, tokens} = English.tokenize("The cat runs.")
{:ok, tagged} = English.tag_pos(tokens)
{:ok, doc} = English.parse(tagged)

# Translate to Spanish
{:ok, doc_es} = Translator.translate(doc, :es)

# Render Spanish text
{:ok, text_es} = Nasty.Rendering.Text.render(doc_es)
IO.puts(text_es)
# Output: El gato corre.
```

## Core Concepts

### The AST Structure

Nasty represents text as a tree:

```
Document
└── Paragraph
    └── Sentence
        └── Clause
            ├── Subject (NounPhrase)
            │   ├── Determiner: "The"
            │   └── Head: "cat"
            └── Predicate (VerbPhrase)
                └── Head: "runs"
```

### Tokens

Every word is a **Token** with:
- `text`: The actual word ("runs")
- `lemma`: Dictionary form ("run")
- `pos_tag`: Part of speech (`:verb`)
- `morphology`: Features (`%{tense: :present}`)
- `language`: Language code (`:en`)
- `span`: Position in text

### Phrases

Phrases group related tokens:
- **NounPhrase**: "the big cat"
- **VerbPhrase**: "is running quickly"
- **PrepositionalPhrase**: "in the house"

### The Processing Pipeline

```
Text → Tokenization → POS Tagging → Morphology → Parsing → AST
```

Each step enriches the data:
1. **Tokenization**: Split into atomic units
2. **POS Tagging**: Add grammatical categories
3. **Morphology**: Add features (tense, number, etc.)
4. **Parsing**: Build hierarchical structure

## Common Patterns

### Pattern 1: Batch Processing

Process multiple texts efficiently:

```elixir
alias Nasty.Language.English

texts = [
  "The first sentence.",
  "The second sentence.",
  "The third sentence."
]

results = 
  texts
  |> Task.async_stream(fn text ->
    with {:ok, tokens} <- English.tokenize(text),
         {:ok, tagged} <- English.tag_pos(tokens),
         {:ok, doc} <- English.parse(tagged) do
      {:ok, doc}
    end
  end, max_concurrency: System.schedulers_online())
  |> Enum.to_list()
```

### Pattern 2: Extract Specific Information

Find all nouns in a document:

```elixir
alias Nasty.Utils.Query

{:ok, doc} = Nasty.parse("The cat and dog play.", language: :en)

# Find all nouns
nouns = Query.find_by_pos(doc, :noun)

Enum.each(nouns, fn token ->
  IO.puts(token.text)
end)
# Output:
# cat
# dog
```

### Pattern 3: Transform Text

Normalize and clean text:

```elixir
alias Nasty.Utils.Transform

{:ok, doc} = Nasty.parse("The CAT runs QUICKLY!", language: :en)

# Lowercase everything
normalized = Transform.normalize_case(doc, :lower)

# Remove punctuation
no_punct = Transform.remove_punctuation(normalized)

# Render back to text
{:ok, clean_text} = Nasty.render(no_punct)
IO.puts(clean_text)
# Output: the cat runs quickly
```

### Pattern 4: Error Handling

Always handle errors gracefully:

```elixir
alias Nasty.Language.English

text = "Some text..."

case English.tokenize(text) do
  {:ok, tokens} ->
    case English.tag_pos(tokens) do
      {:ok, tagged} ->
        case English.parse(tagged) do
          {:ok, doc} -> 
            # Success! Process doc
            process_document(doc)
          {:error, reason} ->
            IO.puts("Parse error: #{inspect(reason)}")
        end
      {:error, reason} ->
        IO.puts("Tagging error: #{inspect(reason)}")
    end
  {:error, reason} ->
    IO.puts("Tokenization error: #{inspect(reason)}")
end
```

Or use `with`:

```elixir
with {:ok, tokens} <- English.tokenize(text),
     {:ok, tagged} <- English.tag_pos(tokens),
     {:ok, doc} <- English.parse(tagged) do
  process_document(doc)
else
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end
```

## Language Support

### Supported Languages

Nasty currently supports:
- **English** (`:en`) - Fully implemented
- **Spanish** (`:es`) - Fully implemented
- **Catalan** (`:ca`) - Fully implemented

### Using Different Languages

Each language has its own module:

```elixir
# English
alias Nasty.Language.English
{:ok, doc_en} = Nasty.parse("The cat runs.", language: :en)

# Spanish
alias Nasty.Language.Spanish
{:ok, doc_es} = Nasty.parse("El gato corre.", language: :es)

# Catalan
alias Nasty.Language.Catalan
{:ok, doc_ca} = Nasty.parse("El gat corre.", language: :ca)
```

### Language Detection

Auto-detect the language:

```elixir
{:ok, lang} = Nasty.Language.Registry.detect_language("Hola mundo")
# => {:ok, :es}

{:ok, lang} = Nasty.Language.Registry.detect_language("Hello world")
# => {:ok, :en}
```

## Troubleshooting

### Common Issues

#### Issue 1: Module Not Found

**Error:**
```
** (UndefinedFunctionError) function Nasty.Language.English.tokenize/1 is undefined
```

**Solution:**
Make sure you've compiled the project:
```bash
mix deps.get
mix compile
```

#### Issue 2: Empty Token List

**Problem:**
```elixir
{:ok, []} = English.tokenize("")
```

**Solution:**
Empty strings return empty token lists. Check your input:
```elixir
text = String.trim(user_input)
if text != "" do
  English.tokenize(text)
else
  {:error, :empty_input}
end
```

#### Issue 3: Parse Errors with Long Sentences

**Problem:**
Very long or complex sentences may fail to parse.

**Solution:**
Split long sentences:
```elixir
sentences = String.split(text, ~r/[.!?]+/)
|> Enum.map(&String.trim/1)
|> Enum.filter(&(&1 != ""))

Enum.each(sentences, fn sent ->
  {:ok, doc} = Nasty.parse(sent, language: :en)
  # Process doc
end)
```

#### Issue 4: Low Entity Recognition

**Problem:**
Named entities not detected.

**Solution:**
Entities depend on lexicons. For specialized domains, you may need to add custom entity patterns or use statistical models:

```elixir
# Use rule-based (default)
{:ok, tagged} = English.tag_pos(tokens)
entities = EntityRecognizer.recognize(tagged)

# Or use CRF model (better accuracy)
entities = EntityRecognizer.recognize(tagged, model: :crf)
```

### Performance Issues

#### Slow Processing

If processing is slow:

1. **Use parallel processing** for multiple documents
2. **Cache parsed documents** to avoid re-parsing
3. **Use simpler models** for POS tagging (`:rule` instead of `:neural`)

```elixir
# Fast rule-based tagging
{:ok, tagged} = English.tag_pos(tokens, model: :rule)

# Better accuracy but slower
{:ok, tagged} = English.tag_pos(tokens, model: :hmm)
```

### Getting Help

- **Documentation**: Check [docs/](docs) for detailed guides
- **Examples**: See [examples/](examples) for working code
- **Issues**: Report bugs on [GitHub](https://github.com/am-kantox/nasty/issues)

## Next Steps

### Learn More

1. **Read the User Guide**: [USER_GUIDE.md](USER_GUIDE.md) for comprehensive examples
2. **Explore Examples**: [EXAMPLES.md](EXAMPLES.md) for runnable scripts
3. **Understand Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md) for system design
4. **Try Translation**: [TRANSLATION.md](TRANSLATION.md) for multilingual features

### Try the Examples

Run the example scripts:

```bash
# Basic tokenization
elixir examples/tokenizer_example.exs

# Question answering
elixir examples/question_answering.exs

# Translation
elixir examples/translation_example.exs

# Multilingual comparison
elixir examples/multilingual_pipeline.exs
```

### Build Something

Now that you understand the basics, try building:

1. **Text Analyzer**: Extract keywords, entities, and sentiment
2. **Translation Tool**: Translate documents between languages
3. **Chatbot**: Parse user input and generate responses
4. **Content Categorizer**: Classify documents by topic
5. **Grammar Checker**: Analyze and correct grammatical errors

### Advanced Topics

Once comfortable with basics, explore:

- **Statistical Models**: Train custom POS taggers
- **Neural Networks**: Use BiLSTM-CRF for better accuracy
- **Information Extraction**: Extract relations and events
- **Question Answering**: Build Q&A systems
- **Custom Grammars**: Define domain-specific grammar rules

## Quick Reference

### Essential Functions

```elixir
# Parsing
Nasty.parse(text, language: :en)

# Rendering
Nasty.render(ast)

# Translation
Nasty.Translation.Translator.translate(ast, target_language)

# Querying
Nasty.Utils.Query.find_by_pos(doc, :noun)
Nasty.Utils.Query.extract_entities(doc)

# Transformation
Nasty.Utils.Transform.normalize_case(doc, :lower)
Nasty.Utils.Transform.remove_punctuation(doc)
```

### Language Modules

```elixir
Nasty.Language.English
Nasty.Language.Spanish
Nasty.Language.Catalan
```

### Common Modules

```elixir
alias Nasty.Language.English
alias Nasty.Translation.Translator
alias Nasty.Utils.{Query, Transform, Traversal}
alias Nasty.Rendering.Text
```

## Summary

You now know how to:
- ✓ Install and set up Nasty
- ✓ Parse text into an AST
- ✓ Extract information from documents
- ✓ Translate between languages
- ✓ Handle common issues
- ✓ Use best practices

**Happy parsing!** 🚀
