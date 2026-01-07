# Nasty Architecture

This document describes the architecture of Nasty, a language-agnostic NLP library for Elixir that treats natural language with the same rigor as programming languages.

## Design Philosophy

Nasty is built on three core principles:

1. **Grammar-First**: Treat natural language as a formal grammar with an Abstract Syntax Tree (AST), similar to how compilers handle programming languages
2. **Language-Agnostic**: Use behaviours to define a common interface, allowing multiple natural languages to coexist
3. **Pure Elixir**: No external NLP dependencies; built entirely in Elixir using NimbleParsec and functional programming patterns

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Public API (Nasty)                      │
│  parse/2, render/2, summarize/2, to_code/2, explain_code/2  │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Language Registry                          │
│   Manages language implementations & auto-detection          │
└──────────────────────────┬──────────────────────────────────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
┌───────────▼────────────┐   ┌───────────▼────────────┐
│  Nasty.Language.       │   │  Nasty.Language.       │
│       English          │   │    Spanish/Catalan     │
│  (Full implementation) │   │   (Future)             │
└───────────┬────────────┘   └────────────────────────┘
            │
┌───────────▼────────────────────────────────────────────────┐
│                      NLP Pipeline                           │
│  Tokenization → POS Tagging → Parsing → Semantic Analysis  │
└───────────┬────────────────────────────────────────────────┘
            │
┌───────────▼────────────────────────────────────────────────┐
│                      AST Structures                         │
│  Document → Paragraph → Sentence → Clause → Phrases → Token│
└───────────┬────────────────────────────────────────────────┘
            │
┌───────────▼────────────────────────────────────────────────┐
│                    AST Operations                           │
│   Query, Validation, Transform, Traversal                   │
└────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Language Behaviour System

The `Nasty.Language.Behaviour` defines the interface that all language implementations must follow:

#### Required Callbacks

```elixir
@callback language_code() :: atom()
@callback tokenize(String.t(), options()) :: {:ok, [Token.t()]} | {:error, term()}
@callback tag_pos([Token.t()], options()) :: {:ok, [Token.t()]} | {:error, term()}
@callback parse([Token.t()], options()) :: {:ok, Document.t()} | {:error, term()}
@callback render(struct(), options()) :: {:ok, String.t()} | {:error, term()}
```

#### Optional Callbacks

```elixir
@callback metadata() :: map()
```

#### Benefits

- **Pluggability**: New languages can be added without changing core code
- **Type Safety**: Dialyzer ensures implementations follow the contract
- **Consistency**: All languages provide the same interface
- **Testing**: Easy to mock and test language-specific behavior

### 2. Language Registry

The `Nasty.Language.Registry` is an Agent-based registry that:

- **Registers** language implementations at runtime
- **Validates** implementations comply with the Behaviour
- **Provides lookup** by language code (`:en`, `:es`, `:ca`)
- **Detects language** from text using heuristics

```elixir
# Registration (happens at application startup)
Registry.register(Nasty.Language.English)

# Lookup
{:ok, module} = Registry.get(:en)

# Detection
{:ok, :en} = Registry.detect_language("Hello world")
```

### 3. NLP Pipeline

Each language implementation follows a multi-stage pipeline:

#### Stage 1: Tokenization

**Purpose**: Split raw text into atomic units (tokens)

**Responsibilities**:
- Sentence boundary detection
- Word segmentation
- Contraction handling ("don't" → "do" + "n't")
- Position tracking (line, column, byte offsets)

**Implementation**: NimbleParsec combinators for efficient parsing

**Output**: `[Token.t()]` with text and position information

#### Stage 2: POS Tagging

**Purpose**: Assign part-of-speech tags and morphological features

**Responsibilities**:
- Tag assignment using Universal Dependencies tagset
- Morphological analysis (tense, number, person, case, etc.)
- Lemmatization (reduce to dictionary form)

**Methods**:
- Rule-based tagging
- Statistical models (HMM)
- Hybrid approaches

**Output**: `[Token.t()]` with `pos_tag`, `lemma`, and `morphology` filled

#### Stage 3: Parsing

**Purpose**: Build hierarchical syntactic structure

**Responsibilities**:
- Phrase structure parsing (NP, VP, PP, AP, AdvP)
- Clause identification (independent, subordinate, relative)
- Sentence structure determination (simple, compound, complex)
- Document and paragraph organization

**Approaches**:
- Recursive descent parsing
- Chart parsing (future)
- Statistical parsing (future)

**Output**: `Document.t()` with complete AST hierarchy

#### Stage 4: Semantic Analysis (Optional)

**Purpose**: Extract meaning and relationships

**Components**:
- **Named Entity Recognition (NER)**: Identify persons, organizations, locations, dates
- **Dependency Extraction**: Extract grammatical relationships between words
- **Semantic Role Labeling (SRL)**: Identify who did what to whom
- **Coreference Resolution**: Link pronouns to referents
- **Relation Extraction**: Extract entity relationships
- **Event Extraction**: Identify events and participants

**Output**: Enriched `Document.t()` with semantic annotations

#### Stage 5: Rendering

**Purpose**: Convert AST back to natural language text

**Responsibilities**:
- Surface realization (choose correct word forms)
- Agreement enforcement (subject-verb, etc.)
- Word order application (language-specific)
- Punctuation insertion
- Capitalization and formatting

**Output**: Rendered text string

### 4. AST Structure

The AST is a hierarchical, linguistically-precise representation:

```
Document (root)
  ├─ Paragraph
  │   ├─ Sentence
  │   │   ├─ Clause (main)
  │   │   │   ├─ Subject (NounPhrase)
  │   │   │   └─ Predicate (VerbPhrase)
  │   │   │       ├─ Verb (Token)
  │   │   │       ├─ Complement (NounPhrase)
  │   │   │       └─ Adverbial (PrepositionalPhrase)
  │   │   └─ Clause (subordinate)
  │   └─ Sentence
  └─ Paragraph
```

#### Node Types

**Document Nodes**:
- `Document` - Root container
- `Paragraph` - Topic-related sentences

**Sentence Nodes**:
- `Sentence` - Complete grammatical unit
- `Clause` - Subject + predicate

**Phrase Nodes**:
- `NounPhrase` - Noun-headed (the cat, big house)
- `VerbPhrase` - Verb-headed (is running, gave a book)
- `PrepositionalPhrase` - Preposition-headed (on the mat)
- `AdjectivalPhrase` - Adjective-headed (very happy)
- `AdverbialPhrase` - Adverb-headed (quite quickly)

**Atomic Nodes**:
- `Token` - Single word/punctuation with POS tag

**Semantic Nodes**:
- `Entity` - Named entity
- `Relation` - Entity relationship
- `Event` - Event with participants
- `CorefChain` - Coreference links
- `Frame` - Semantic role frame

#### Universal Properties

All nodes include:

```elixir
%{
  language: atom(),  # :en, :es, :ca
  span: %{          # Position tracking
    start_pos: {line, column},
    start_byte: integer(),
    end_pos: {line, column},
    end_byte: integer()
  }
}
```

### 5. AST Utilities

#### Query Module

Search and extract information from AST:

```elixir
Nasty.AST.Query.find_subject(sentence)
Nasty.AST.Query.extract_tokens(document)
Nasty.AST.Query.find_entities(document)
```

#### Validation Module

Ensure AST structural integrity:

```elixir
case Nasty.AST.Validation.validate(document) do
  :ok -> :ok
  {:error, errors} -> handle_errors(errors)
end
```

#### Transform Module

Modify AST nodes:

```elixir
transformed = Nasty.AST.Transform.map(document, fn node ->
  # Transform logic
  node
end)
```

#### Traversal Module

Navigate AST with different strategies:

```elixir
Nasty.AST.Traversal.pre_order(document, visitor_fn)
Nasty.AST.Traversal.post_order(document, visitor_fn)
Nasty.AST.Traversal.breadth_first(document, visitor_fn)
```

### 6. Statistical Models

#### Model Infrastructure

**Registry**: Agent-based model storage
- `ModelRegistry.register/2` - Store model
- `ModelRegistry.get/1` - Retrieve model
- `ModelRegistry.list_models/0` - List all

**Loader**: Serialize/deserialize models
- `ModelLoader.load/1` - Load from file
- `ModelLoader.save/2` - Save to file
- `ModelLoader.load_from_priv/1` - Load from app resources

#### Model Types

**HMM (Hidden Markov Model)**:
- POS tagging with 95% accuracy
- Viterbi algorithm for decoding

**Naive Bayes**:
- Text classification
- Multinomial variant for document classification

**Future Models**:
- PCFG (Probabilistic Context-Free Grammar) for parsing
- CRF (Conditional Random Fields) for NER
- Neural models for improved accuracy

### 7. Code Interoperability

Bidirectional conversion between natural language and code:

#### NL → Code Pipeline

```
Natural Language
    ↓
Intent Recognition (parse to Intent AST)
    ↓
Code Generation (Intent → Elixir AST)
    ↓
Validation
    ↓
Elixir Code String
```

**Example**:
```elixir
Nasty.to_code("Filter users where age is greater than 18", 
  source_language: :en, 
  target_language: :elixir)
# => "Enum.filter(users, fn item -> item > 18 end)"
```

#### Code → NL Pipeline

```
Elixir Code String
    ↓
Parse to Elixir AST
    ↓
Traverse & Explain (AST → Natural Language)
    ↓
Natural Language Description
```

**Example**:
```elixir
Nasty.explain_code("Enum.sort(list)", 
  source_language: :elixir, 
  target_language: :en)
# => "Sort list"
```

### 8. Rendering & Visualization

#### Text Rendering

Convert AST to formatted text:
```elixir
Nasty.Rendering.Text.render(document)
```

#### Pretty Printing

Human-readable AST inspection:
```elixir
Nasty.Rendering.PrettyPrint.inspect(ast)
```

#### DOT Visualization

Generate Graphviz diagrams:
```elixir
{:ok, dot} = Nasty.Rendering.Visualization.to_dot(ast)
File.write("ast.dot", dot)
```

#### JSON Export

Export to JSON for external tools:
```elixir
{:ok, json} = Nasty.Rendering.Visualization.to_json(ast)
```

### 9. Data Layer

#### CoNLL-U Support

Parse and generate Universal Dependencies format:
```elixir
{:ok, sentences} = Nasty.Data.CoNLLU.parse_file("corpus.conllu")
conllu_string = Nasty.Data.CoNLLU.format(sentence)
```

#### Corpus Management

Manage training corpora:
```elixir
{:ok, corpus} = Nasty.Data.Corpus.load("path/to/corpus")
stats = Nasty.Data.Corpus.statistics(corpus)
```

## Application Supervision

```elixir
defmodule Nasty.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Language Registry Agent
      Nasty.Language.Registry,
      
      # Model Registry Agent
      Nasty.Statistics.ModelRegistry
    ]

    opts = [strategy: :one_for_one, name: Nasty.Supervisor]
    result = Supervisor.start_link(children, opts)
    
    # Register languages at startup
    Nasty.Language.Registry.register(Nasty.Language.English)
    
    result
  end
end
```

## Extension Points

### Adding a New Language

1. Implement `Nasty.Language.Behaviour`
2. Create language module in `lib/language/your_language/`
3. Implement required callbacks
4. Register in `application.ex`
5. Add tests

See [Language Guide](LANGUAGE_GUIDE.md) for details.

### Adding New NLP Features

1. Create module in appropriate layer (`lib/language/`, `lib/semantic/`, etc.)
2. Define behaviour if language-agnostic
3. Implement for each language
4. Add to pipeline if needed
5. Update AST if new node types needed

### Adding Statistical Models

1. Implement model training in `lib/statistics/`
2. Create Mix task for training
3. Add model to registry
4. Integrate into pipeline

## Performance Considerations

### Efficiency

- **NimbleParsec**: Compiled parser combinators for fast tokenization
- **Agent-based registries**: Fast in-memory lookup
- **Streaming**: Process documents incrementally where possible
- **Lazy evaluation**: Use streams for large corpora

### Scalability

- **Stateless processing**: All functions are pure
- **Concurrent processing**: Parse multiple documents in parallel
- **Distributed**: Can run across multiple nodes (future)

## Testing Strategy

### Unit Tests

- Test each module in isolation
- Use `async: true` for parallel execution
- Mock language implementations when testing core

### Integration Tests

- Test full pipeline from text to AST
- Test rendering round-trips
- Test code interoperability

### Property-Based Testing

- Generate random ASTs and validate
- Test parsing/rendering round-trips
- Verify AST invariants

## Future Directions

### Architecture Evolution

1. **Generic Layers**: Extract `lib/parsing/`, `lib/semantic/`, `lib/operations/`
2. **Plugin System**: Dynamic language loading
3. **Streaming Pipeline**: Process infinite text streams
4. **Distributed Processing**: Multi-node coordination

### Advanced Features

1. **Neural Models**: Transformer-based parsing and tagging
2. **Multi-lingual**: True cross-language support
3. **Incremental Parsing**: Update AST on edits
4. **Error Recovery**: Graceful handling of malformed input

## See Also

- [API Documentation](API.md)
- [AST Reference](AST_REFERENCE.md)
- [Language Guide](LANGUAGE_GUIDE.md)
- [User Guide](USER_GUIDE.md)
