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

### Translation

#### `Nasty.Translation.Translator.translate_document/2`

Translates an AST document from one language to another.

**Parameters:**
- `document` - AST Document to translate
- `target_language` - Target language code (`:en`, `:es`, `:ca`, etc.)

**Returns:**
- `{:ok, %Nasty.AST.Document{}}` - Translated AST document
- `{:error, reason}` - Translation error

**Examples:**

```elixir
alias Nasty.Translation.Translator

# Translate English to Spanish
{:ok, doc_en} = Nasty.parse("The cat runs.", language: :en)
{:ok, doc_es} = Translator.translate_document(doc_en, :es)
{:ok, text_es} = Nasty.render(doc_es)
# => "El gato corre."

# Translate Spanish to English  
{:ok, doc_es} = Nasty.parse("La casa grande.", language: :es)
{:ok, doc_en} = Translator.translate_document(doc_es, :en)
{:ok, text_en} = Nasty.render(doc_en)
# => "The big house."

# Or translate text directly
{:ok, text_es} = Translator.translate("The cat runs.", :en, :es)
# => "El gato corre."
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

#### `Nasty.Language.Registry.register/1`

Registers a language implementation module.

```elixir
Nasty.Language.Registry.register(Nasty.Language.English)
# => :ok
```

#### `Nasty.Language.Registry.get/1`

Gets the implementation module for a language code.

```elixir
{:ok, module} = Nasty.Language.Registry.get(:en)
# => {:ok, Nasty.Language.English}
```

#### `Nasty.Language.Registry.detect_language/1`

Detects the language of the given text.

```elixir
{:ok, language} = Nasty.Language.Registry.detect_language("Hello world")
# => {:ok, :en}

{:ok, language} = Nasty.Language.Registry.detect_language("Hola mundo")
# => {:ok, :es}
```

#### `Nasty.Language.Registry.registered_languages/0`

Returns all registered language codes.

```elixir
Nasty.Language.Registry.registered_languages()
# => [:en, :es, :ca]
```

#### `Nasty.Language.Registry.registered?/1`

Checks if a language is registered.

```elixir
Nasty.Language.Registry.registered?(:en)
# => true
```

## AST Utilities

### Query

#### `Nasty.Utils.Query`

Query and traverse AST structures.

```elixir
alias Nasty.Utils.Query

# Find subject in a sentence
subject = Query.find_subject(sentence)

# Find all noun phrases
noun_phrases = Query.find_all(document, :noun_phrase)

# Find by POS tag
nouns = Query.find_by_pos(document, :noun)
verbs = Query.find_by_pos(document, :verb)

# Count nodes
token_count = Query.count(document, :token)
```

### Validation

#### `Nasty.Utils.Validator`

Validate AST structure.

```elixir
alias Nasty.Utils.Validator

case Validator.validate(document) do
  {:ok, _doc} -> IO.puts("Valid AST")
  {:error, reason} -> IO.puts("Invalid: #{reason}")
end

# Check if valid (boolean)
if Validator.valid?(document) do
  IO.puts("Document is valid")
end
```

### Transformation

#### `Nasty.Utils.Transform`

Transform AST nodes.

```elixir
alias Nasty.Utils.Transform

# Case normalization
lowercased = Transform.normalize_case(document, :lower)

# Remove punctuation
no_punct = Transform.remove_punctuation(document)

# Remove stop words
no_stops = Transform.remove_stop_words(document)

# Lemmatize all tokens
lemmatized = Transform.lemmatize(document)
```

### Traversal

#### `Nasty.Utils.Traversal`

Traverse AST structure.

```elixir
alias Nasty.Utils.Traversal

# Reduce over all nodes
token_count = Traversal.reduce(document, 0, fn
  %Nasty.AST.Token{}, acc -> acc + 1
  _, acc -> acc
end)

# Collect matching nodes
verbs = Traversal.collect(document, fn
  %Nasty.AST.Token{pos_tag: :verb} -> true
  _ -> false
end)

# Map over all nodes
transformed = Traversal.map(document, fn
  %Nasty.AST.Token{} = token ->
    %{token | text: String.downcase(token.text)}
  node -> node
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

## Statistical & Neural Models

### Model Registry

#### `Nasty.Statistics.ModelRegistry`

Manage statistical and neural models.

```elixir
# Register a model
Nasty.Statistics.ModelRegistry.register(:hmm_pos_tagger, model)
Nasty.Statistics.ModelRegistry.register(:neural_pos_tagger, neural_model)

# Get a model
{:ok, model} = Nasty.Statistics.ModelRegistry.get(:hmm_pos_tagger)
{:ok, neural} = Nasty.Statistics.ModelRegistry.get(:neural_pos_tagger)

# List models
models = Nasty.Statistics.ModelRegistry.list_models()
```

### Model Loader

#### `Nasty.Statistics.ModelLoader`

Load and save statistical and neural models.

```elixir
# Load HMM model from file
{:ok, model} = Nasty.Statistics.ModelLoader.load("path/to/model.model")

# Load neural model from file
{:ok, neural} = Nasty.Statistics.POSTagging.NeuralTagger.load("path/to/model.axon")

# Save model to file
:ok = Nasty.Statistics.ModelLoader.save(model, "path/to/model.model")
:ok = NeuralTagger.save(neural, "path/to/model.axon")

# Load from project
{:ok, model} = Nasty.Statistics.ModelLoader.load_from_priv("models/hmm.model")
```

### Neural Models

#### `Nasty.Statistics.POSTagging.NeuralTagger`

Train and use BiLSTM-CRF neural models for POS tagging.

```elixir
# Train a neural model
alias Nasty.Statistics.POSTagging.NeuralTagger

tagger = NeuralTagger.new(
  vocab: vocab,
  tag_vocab: tag_vocab,
  embedding_dim: 300,
  hidden_size: 256,
  num_layers: 2
)

{:ok, trained} = NeuralTagger.train(tagger, training_data,
  epochs: 10,
  batch_size: 32,
  learning_rate: 0.001
)

# Use neural model for prediction
{:ok, tags} = NeuralTagger.predict(trained, ["The", "cat", "sat"], [])

# Save/load neural models
NeuralTagger.save(trained, "model.axon")
{:ok, loaded} = NeuralTagger.load("model.axon")
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

### Translation

#### `Nasty.Translation.Translator`

Translate documents between languages.

```elixir
alias Nasty.Translation.Translator

# Translate document
{:ok, translated_doc} = Translator.translate(source_doc, :es)

# Translate with custom lexicons
{:ok, translated_doc} = Translator.translate(source_doc, :es, lexicon_path: "custom_lexicons/")
```

#### `Nasty.Translation.TokenTranslator`

Translate individual tokens with POS-aware lemma-to-lemma mapping.

```elixir
alias Nasty.Translation.TokenTranslator

# Translate token
translated_token = TokenTranslator.translate_token(token, :en, :es)

# Translate with morphology
translated_token = TokenTranslator.translate_with_morphology(token, :en, :es)
```

#### `Nasty.Translation.Agreement`

Enforce morphological agreement rules.

```elixir
alias Nasty.Translation.Agreement

# Apply gender/number agreement
adjusted_tokens = Agreement.apply_agreement(tokens, :es)

# Check agreement
valid? = Agreement.check_agreement(determiner, noun)
```

#### `Nasty.Translation.WordOrder`

Apply language-specific word order transformations.

```elixir
alias Nasty.Translation.WordOrder

# Transform word order
ordered_phrase = WordOrder.apply_order(phrase, :es)

# Apply adjective position rules  
ordered_np = WordOrder.apply_adjective_order(noun_phrase, :es)
```

#### `Nasty.AST.Renderer`

Render AST back to natural language text.

```elixir
alias Nasty.AST.Renderer

# Render document
{:ok, text} = Renderer.render_document(document)

# Render specific nodes
{:ok, text} = Renderer.render_sentence(sentence)
{:ok, text} = Renderer.render_phrase(phrase)
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
