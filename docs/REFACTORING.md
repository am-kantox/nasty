# Architecture Refactoring Guide

This document explains the ongoing refactoring to extract language-agnostic layers from language-specific implementations.

## Overview

The current architecture has all NLP operations embedded within language implementations (e.g., `Nasty.Language.English.Summarizer`). The goal is to create generic, behaviour-based layers that can be reused across languages.

## Current Structure (Before Refactoring)

```
lib/
├── language/
│   ├── behaviour.ex          # Language interface
│   ├── registry.ex
│   └── english/
│       ├── summarizer.ex      # English-specific
│       ├── text_classifier.ex # English-specific
│       ├── entity_recognizer.ex # English-specific
│       ├── coreference_resolver.ex
│       └── ... (17 modules)
```

## Target Structure (After Refactoring)

```
lib/
├── language/
│   ├── behaviour.ex          # Core language interface
│   ├── registry.ex
│   └── english/
│       ├── english.ex         # Main module
│       ├── tokenizer.ex
│       ├── pos_tagger.ex
│       ├── phrase_parser.ex
│       └── adapters/          # Adapters to generic layers
│           ├── summarizer_adapter.ex
│           ├── classifier_adapter.ex
│           └── ner_adapter.ex
├── operations/                # Generic NLP operations
│   ├── summarization.ex      # Behaviour
│   ├── classification.ex     # Behaviour
│   └── question_answering.ex # Behaviour
└── semantic/                  # Generic semantic analysis
    ├── entity_recognition.ex  # Behaviour
    ├── coreference_resolution.ex # Behaviour
    └── semantic_role_labeling.ex # Behaviour
```

## New Behaviour Layers

### 1. Operations Layer (`lib/operations/`)

Language-agnostic NLP operations that produce results:

#### `Nasty.Operations.Summarization`
```elixir
@callback summarize(Document.t(), options()) :: 
  {:ok, [Sentence.t()] | String.t()} | {:error, term()}
@callback methods() :: [method()]
```

**Purpose**: Extract or generate summaries from documents

**Implementation**: `Nasty.Language.English.SummarizerAdapter`

#### `Nasty.Operations.Classification`
```elixir
@callback train(training_data(), options()) :: {:ok, model()} | {:error, term()}
@callback classify(model(), input(), options()) :: {:ok, Classification.t()} | {:error, term()}
```

**Purpose**: Train and use text classifiers

**Implementation**: `Nasty.Language.English.ClassifierAdapter`

### 2. Semantic Layer (`lib/semantic/`)

Language-agnostic semantic analysis:

#### `Nasty.Semantic.EntityRecognition`
```elixir
@callback recognize_document(Document.t(), options()) :: {:ok, [Entity.t()]} | {:error, term()}
@callback recognize(tokens(), options()) :: {:ok, [Entity.t()]} | {:error, term()}
```

**Purpose**: Named entity recognition across languages

**Implementation**: `Nasty.Language.English.NERAdapter`

#### `Nasty.Semantic.CoreferenceResolution`
```elixir
@callback resolve(Document.t(), options()) :: {:ok, Document.t()} | {:error, term()}
```

**Purpose**: Resolve coreferences in text

**Implementation**: `Nasty.Language.English.CoreferenceAdapter`

## Migration Strategy

### Phase 1: Create Behaviour Definitions (CURRENT)

✅ **Status**: Complete

- Created `lib/operations/` with base behaviours
- Created `lib/semantic/` with base behaviours
- Defined clear interfaces for each operation

### Phase 2: Create Adapter Pattern (IN PROGRESS)

**Goal**: Adapt existing English implementations to new behaviours without breaking changes

**Approach**:
1. Keep existing modules functioning as-is
2. Create adapter modules that implement new behaviours
3. Adapters delegate to existing implementations
4. Update top-level APIs to use adapters when available

**Example Adapter**:
```elixir
defmodule Nasty.Language.English.SummarizerAdapter do
  @behaviour Nasty.Operations.Summarization
  
  alias Nasty.Language.English.Summarizer
  
  @impl true
  def summarize(document, opts) do
    # Delegate to existing implementation
    sentences = Summarizer.summarize(document, opts)
    {:ok, sentences}
  end
  
  @impl true
  def methods, do: [:extractive, :mmr]
end
```

### Phase 3: Refactor Implementations (COMPLETED)

✅ **Status**: Complete for Summarization and Entity Recognition

**Goal**: Move language-agnostic logic out of language modules

**Completed Work**:
1. ✅ Created `Nasty.Operations.Summarization.Extractive` - Generic extractive summarization
2. ✅ Created `Nasty.Semantic.EntityRecognition.RuleBased` - Generic rule-based NER
3. ✅ Refactored `English.Summarizer` to delegate to generic module (69% code reduction)
4. ✅ Refactored `English.EntityRecognizer` to delegate to generic module (23% code reduction)
5. ✅ All language-specific logic (lexicons, stop words, patterns) remains in English modules
6. ✅ All 360 tests passing with no breaking changes

### Phase 4: Extract Generic Algorithms (COMPLETED for 2 modules)

✅ **Status**: Complete for Summarization and Entity Recognition

**Extracted Algorithms**:
- ✅ `Nasty.Operations.Summarization.Extractive` (440 lines)
  - Position scoring, length scoring, TF-IDF keyword scoring
  - Entity scoring, discourse marker scoring, coreference scoring
  - Greedy and MMR selection algorithms
  - Jaccard similarity for redundancy reduction
  
- ✅ `Nasty.Semantic.EntityRecognition.RuleBased` (237 lines)
  - Sequence detection (finds capitalized token sequences)
  - Configurable classification framework
  - Lexicon matching, pattern matching, heuristic classification
  - Generic entity creation with proper span calculation

**Remaining modules** for future phases:
- [ ] Coreference Resolution
- [ ] Semantic Role Labeling  
- [ ] Question Answering
- [ ] Text Classification

## Benefits of Refactoring

### 1. Code Reuse
- Generic algorithms work across all languages
- Less duplication when adding new languages
- Easier to maintain and test

### 2. Clear Separation
- Language-specific logic clearly separated
- Generic operations have well-defined interfaces
- Easier to understand system architecture

### 3. Easier Language Addition
```elixir
# Before: Implement 17 modules for new language
defmodule Nasty.Language.Spanish.Summarizer do
  # 200 lines of code
end

# After: Implement adapter + language-specific tweaks
defmodule Nasty.Language.Spanish.SummarizerAdapter do
  @behaviour Nasty.Operations.Summarization
  use Nasty.Operations.Summarization.Extractive  # Generic algorithm
  
  # Only override language-specific parts
  def stop_words, do: @spanish_stop_words  # 10 lines
end
```

### 4. Testing
- Test generic algorithms once
- Test language-specific adaptations separately
- Mock behaviours easily in tests

## Backward Compatibility

### Maintaining Existing APIs

All existing code continues to work:

```elixir
# Still works
Nasty.Language.English.Summarizer.summarize(doc, [])

# Also works with new adapter
Nasty.Operations.Summarization.summarize(doc, language: :en)
```

### Deprecation Strategy

1. Keep old modules functional
2. Add deprecation warnings after adapters are complete
3. Remove old modules in next major version

## Implementation Checklist

### Operations Layer
- [x] Create `lib/operations/summarization.ex` behaviour
- [x] Create `lib/operations/classification.ex` behaviour
- [x] Create English adapters for operations
- [x] Extract generic algorithms
  - [x] `Nasty.Operations.Summarization.Extractive`
- [ ] Create `lib/operations/question_answering.ex` behaviour
- [ ] Extract remaining generic algorithms

### Semantic Layer
- [x] Create `lib/semantic/entity_recognition.ex` behaviour
- [x] Create `lib/semantic/coreference_resolution.ex` behaviour
- [x] Create English adapters for semantic operations
- [x] Extract generic algorithms
  - [x] `Nasty.Semantic.EntityRecognition.RuleBased`
- [ ] Create `lib/semantic/semantic_role_labeling.ex` behaviour
- [ ] Extract remaining generic algorithms

### Documentation
- [x] Create REFACTORING.md guide
- [x] Update REFACTORING.md with Phase 3-4 completion
- [ ] Update ARCHITECTURE.md with new layers
- [ ] Add migration examples
- [ ] Document adapter pattern

## Example: Adapting Summarizer

### Step 1: Current Implementation

```elixir
defmodule Nasty.Language.English.Summarizer do
  def summarize(%Document{} = doc, opts) do
    # 200 lines of extractive summarization logic
  end
end
```

### Step 2: Create Adapter

```elixir
defmodule Nasty.Language.English.SummarizerAdapter do
  @behaviour Nasty.Operations.Summarization
  
  alias Nasty.Language.English.Summarizer
  
  @impl true
  def summarize(document, opts) do
    result = Summarizer.summarize(document, opts)
    {:ok, result}
  end
  
  @impl true
  def methods, do: [:extractive, :mmr]
end
```

### Step 3: Update Top-Level API

```elixir
defmodule Nasty do
  def summarize(text_or_ast, opts) do
    # Use adapter if available
    case get_summarizer_adapter(opts[:language]) do
      {:ok, adapter} -> adapter.summarize(ast, opts)
      {:error, _} -> fallback_to_old_api(ast, opts)
    end
  end
end
```

### Step 4: Extract Generic Algorithm (Future)

```elixir
defmodule Nasty.Operations.Summarization.Extractive do
  def summarize(sentences, scoring_fn, opts) do
    # Generic extractive summarization
    # Works for any language with custom scoring_fn
  end
end

defmodule Nasty.Language.English.SummarizerAdapter do
  use Nasty.Operations.Summarization.Extractive
  
  def score_sentence(sentence, context) do
    # English-specific scoring using stop words, etc.
  end
end
```

## Contributing

When adding new NLP features:

1. **Define behaviour first** in `lib/operations/` or `lib/semantic/`
2. **Implement for English** as an adapter
3. **Extract generic algorithms** where possible
4. **Document** the behaviour and implementation strategy

## See Also

- [Architecture](ARCHITECTURE.md) - Overall system architecture
- [Language Guide](LANGUAGE_GUIDE.md) - Adding new languages
- [API Documentation](API.md) - Public APIs
