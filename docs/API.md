# Nasty Public API Reference

This document describes the public API of Nasty, the Natural Abstract Syntax Tree library for Elixir.

## Core Functions

### Parsing

#### `Nasty.parse/2`

Parses natural language text into an Abstract Syntax Tree (AST).

**Parameters:**
- `text` (String.t()) - The text to parse
- `opts` (keyword()) - Options:
  - `:language` - Language code (`:en`, `:es`, `:ca`, etc.) **Required**
  - `:tokenize` - Enable tokenization (default: `true`)
  - `:pos_tag` - Enable POS tagging (default: `true`)
  - `:parse_dependencies` - Parse dependency relationships (default: `true`)
  - `:extract_entities` - Extract named entities (default: `false`)
  - `:resolve_coreferences` - Resolve coreferences (default: `false`)

**Returns:**
- `{:ok, %Nasty.AST.Document{}}` - Parsed AST document
- `{:error, reason}` - Parse error

**Examples:**

```elixir
# Basic parsing
{:ok, ast} = Nasty.parse("The cat sat on the mat.", language: :en)

# With entity recognition
{:ok, ast} = Nasty.parse("John lives in Paris.", 
  language: :en, 
  extract_entities: true
)

# With coreference resolution
{:ok, ast} = Nasty.parse("Mary loves her cat. She feeds it daily.", 
  language: :en, 
  resolve_coreferences: true
)
```

#### `Nasty.render/2`

Renders an AST back to natural language text.

**Parameters:**
- `ast` (struct()) - AST node to render (Document, Sentence, etc.)
- `opts` (keyword()) - Options (language determined from AST)

**Returns:**
- `{:ok, text}` - Rendered text string
- `{:error, reason}` - Render error

**Examples:**

```elixir
{:ok, ast} = Nasty.parse("The cat sat.", language: :en)
{:ok, text} = Nasty.render(ast)
# => "The cat sat."
```

### Summarization

#### `Nasty.summarize/2`

Summarizes a document by extracting important sentences.

**Parameters:**
- `text_or_ast` - Text string or AST Document to summarize
- `opts` (keyword()) - Options:
  - `:language` - Language code (required if text)
  - `:ratio` - Compression ratio (0.0 to 1.0), default `0.3`
  - `:max_sentences` - Maximum number of sentences in summary
  - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)
  - `:min_sentence_length` - Minimum sentence length in tokens (default: `3`)
  - `:mmr_lambda` - MMR diversity parameter, 0-1 (default: `0.5`)

**Returns:**
- `{:ok, [%Sentence{}]}` - List of extracted sentences
- `{:error, reason}` - Error

**Examples:**

```elixir
# From text
{:ok, summary} = Nasty.summarize(long_text, 
  language: :en, 
  ratio: 0.3
)

# From AST
{:ok, ast} = Nasty.parse(long_text, language: :en)
{:ok, summary} = Nasty.summarize(ast, max_sentences: 3)

# Using MMR for diversity
{:ok, summary} = Nasty.summarize(text, 
  language: :en, 
  method: :mmr, 
  mmr_lambda: 0.7
)
```

### Code Interoperability

#### `Nasty.to_code/2`

Converts natural language text to code.

**Parameters:**
- `text` (String.t()) - Natural language description
- `opts` (keyword()) - Options:
  - `:source_language` - Source natural language (`:en`, etc.) **Required**
  - `:target_language` - Target programming language (`:elixir`, etc.) **Required**

**Returns:**
- `{:ok, code_string}` - Generated code
- `{:error, reason}` - Error

**Supported Language Pairs:**
- English → Elixir (`:en` → `:elixir`)

**Examples:**

```elixir
# List operations
{:ok, code} = Nasty.to_code("Sort the list", 
  source_language: :en, 
  target_language: :elixir
)
# => "Enum.sort(list)"

# Filter with constraints
{:ok, code} = Nasty.to_code("Filter users where age is greater than 18",
  source_language: :en,
  target_language: :elixir
)
# => "Enum.filter(users, fn item -> item > 18 end)"

# Arithmetic
{:ok, code} = Nasty.to_code("Add x and y",
  source_language: :en,
  target_language: :elixir
)
# => "x + y"
```

#### `Nasty.explain_code/2`

Generates natural language explanation from code.

**Parameters:**
- `code` - Code string or AST to explain
- `opts` (keyword()) - Options:
  - `:source_language` - Programming language (`:elixir`, etc.) **Required**
  - `:target_language` - Target natural language (`:en`, etc.) **Required**
  - `:style` - Explanation style: `:concise` or `:verbose` (default: `:concise`)

**Returns:**
- `{:ok, explanation_string}` - Natural language explanation
- `{:error, reason}` - Error

**Supported Language Pairs:**
- Elixir → English (`:elixir` → `:en`)

**Examples:**

```elixir
{:ok, explanation} = Nasty.explain_code("Enum.sort(list)",
  source_language: :elixir,
  target_language: :en
)
# => "Sort list"

{:ok, explanation} = Nasty.explain_code(
  "list |> Enum.map(&(&1 * 2)) |> Enum.sum()",
  source_language: :elixir,
  target_language: :en
)
# => "Map list to double each element, then sum the results"

# Verbose style
{:ok, explanation} = Nasty.explain_code("x = 5",
  source_language: :elixir,
  target_language: :en,
  style: :verbose
)
```

## Language Registry

### `Nasty.Language.Registry`

Manages language implementations.

#### `Registry.register/1`

Registers a language implementation module.

```elixir
Nasty.Language.Registry.register(Nasty.Language.English)
# => :ok
```

#### `Registry.get/1`

Gets the implementation module for a language code.

```elixir
{:ok, module} = Nasty.Language.Registry.get(:en)
# => {:ok, Nasty.Language.English}
```

#### `Registry.detect_language/1`

Detects the language of the given text.

```elixir
{:ok, language} = Nasty.Language.Registry.detect_language("Hello world")
# => {:ok, :en}

{:ok, language} = Nasty.Language.Registry.detect_language("Hola mundo")
# => {:ok, :es}
```

#### `Registry.registered_languages/0`

Returns all registered language codes.

```elixir
Nasty.Language.Registry.registered_languages()
# => [:en]
```

#### `Registry.registered?/1`

Checks if a language is registered.

```elixir
Nasty.Language.Registry.registered?(:en)
# => true
```

## AST Utilities

### Query

#### `Nasty.AST.Query`

Query and traverse AST structures.

```elixir
# Find subject in a sentence
subject = Nasty.AST.Query.find_subject(sentence)

# Extract all tokens
tokens = Nasty.AST.Query.extract_tokens(document)

# Find entities
entities = Nasty.AST.Query.find_entities(document)
```

### Validation

#### `Nasty.AST.Validation`

Validate AST structure.

```elixir
case Nasty.AST.Validation.validate(document) do
  :ok -> IO.puts("Valid AST")
  {:error, errors} -> IO.inspect(errors)
end
```

### Transformation

#### `Nasty.AST.Transform`

Transform AST nodes.

```elixir
# Apply transformation to all nodes
transformed = Nasty.AST.Transform.map(document, fn node ->
  # Modify node
  node
end)

# Filter nodes
filtered = Nasty.AST.Transform.filter(document, fn node ->
  # Keep or discard
  true
end)
```

### Traversal

#### `Nasty.AST.Traversal`

Traverse AST structure.

```elixir
# Pre-order traversal
Nasty.AST.Traversal.pre_order(document, fn node ->
  IO.inspect(node)
  node
end)

# Post-order traversal
Nasty.AST.Traversal.post_order(document, fn node ->
  IO.inspect(node)
  node
end)

# Breadth-first traversal
Nasty.AST.Traversal.breadth_first(document, fn node ->
  IO.inspect(node)
  node
end)
```

## Rendering

### Pretty Print

#### `Nasty.Rendering.PrettyPrint`

Format AST for human-readable inspection.

```elixir
# Pretty print to stdout
Nasty.Rendering.PrettyPrint.inspect(ast)

# Get formatted string
formatted = Nasty.Rendering.PrettyPrint.format(ast)
```

### Visualization

#### `Nasty.Rendering.Visualization`

Generate visualizations of AST structures.

```elixir
# Generate DOT format for Graphviz
{:ok, dot} = Nasty.Rendering.Visualization.to_dot(ast)
File.write("ast.dot", dot)

# Generate JSON representation
{:ok, json} = Nasty.Rendering.Visualization.to_json(ast)
```

### Text Rendering

#### `Nasty.Rendering.Text`

Render AST to text.

```elixir
{:ok, text} = Nasty.Rendering.Text.render(document)
```

## Statistical Models

### Model Registry

#### `Nasty.Statistics.ModelRegistry`

Manage statistical models.

```elixir
# Register a model
Nasty.Statistics.ModelRegistry.register(:hmm_pos_tagger, model)

# Get a model
{:ok, model} = Nasty.Statistics.ModelRegistry.get(:hmm_pos_tagger)

# List models
models = Nasty.Statistics.ModelRegistry.list_models()
```

### Model Loader

#### `Nasty.Statistics.ModelLoader`

Load and save statistical models.

```elixir
# Load model from file
{:ok, model} = Nasty.Statistics.ModelLoader.load("path/to/model.bin")

# Save model to file
:ok = Nasty.Statistics.ModelLoader.save(model, "path/to/model.bin")

# Load from project
{:ok, model} = Nasty.Statistics.ModelLoader.load_from_priv("models/hmm.bin")
```

## Data Layer

### CoNLL-U Parser

#### `Nasty.Data.CoNLLU`

Parse and generate CoNLL-U format data.

```elixir
# Parse CoNLL-U file
{:ok, sentences} = Nasty.Data.CoNLLU.parse_file("corpus.conllu")

# Parse CoNLL-U string
{:ok, sentences} = Nasty.Data.CoNLLU.parse(conllu_string)

# Convert AST to CoNLL-U
conllu_string = Nasty.Data.CoNLLU.format(sentence)
```

### Corpus Management

#### `Nasty.Data.Corpus`

Manage text corpora.

```elixir
# Load corpus
{:ok, corpus} = Nasty.Data.Corpus.load("path/to/corpus")

# Get sentences
sentences = Nasty.Data.Corpus.sentences(corpus)

# Statistics
stats = Nasty.Data.Corpus.statistics(corpus)
```

## NLP Operations (English)

These are language-specific operations available for English. Access through the English module.

### Question Answering

```elixir
alias Nasty.Language.English

# Analyze question
{:ok, analysis} = English.QuestionAnalyzer.analyze("What is the capital of France?")

# Extract answer
{:ok, answer} = English.AnswerExtractor.extract(document, analysis)
```

### Text Classification

```elixir
# Train classifier
classifier = English.TextClassifier.train(training_data)

# Classify text
{:ok, category} = English.TextClassifier.classify(classifier, text)
```

### Information Extraction

```elixir
# Extract relations
relations = English.RelationExtractor.extract(document)

# Extract events
events = English.EventExtractor.extract(document)

# Extract with templates
extracted = English.TemplateExtractor.extract(document, templates)
```

### Semantic Role Labeling

```elixir
# Label semantic roles
labeled = English.SemanticRoleLabeler.label(sentence)
```

### Coreference Resolution

```elixir
# Resolve coreferences
{:ok, resolved} = English.CoreferenceResolver.resolve(document)
```

## Error Handling

All public API functions return result tuples:

- `{:ok, result}` on success
- `{:error, reason}` on failure

Common error reasons:

- `:language_required` - Language not specified
- `:language_not_found` - Language not registered
- `:language_not_registered` - Language code not in registry
- `:no_languages_registered` - No languages available
- `:no_match` - Language detection failed
- `:invalid_text` - Invalid input text
- `:parse_error` - Failed to parse text
- `:source_language_required` - Source language not specified
- `:target_language_required` - Target language not specified
- `:unsupported_language_pair` - Language pair not supported
- `:summarization_not_supported` - Summarization not available for language
- `:invalid_input` - Invalid input type

## See Also

- [AST Reference](AST_REFERENCE.md) - Complete AST node documentation
- [User Guide](USER_GUIDE.md) - Tutorial and examples
- [Architecture](ARCHITECTURE.md) - System architecture
- [Language Guide](LANGUAGE_GUIDE.md) - Adding new languages
