# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Nasty (Natural Abstract Syntax Treey) is a comprehensive NLP library for Elixir that treats natural language with the same rigor as programming languages. It provides a complete grammatical Abstract Syntax Tree (AST) for English and Spanish, with a behaviour-based architecture designed to support multiple languages.

## Core Commands

### Building and Dependencies
```bash
# Install/update dependencies
mix deps.get

# Compile the project
mix compile
```

### Testing
```bash
# Run all tests
mix test

# Run tests for a specific module
mix test test/language/english/tokenizer_test.exs
mix test test/language/english/phrase_parser_test.exs
mix test test/language/english/dependency_extractor_test.exs

# Run tests with coverage
mix coveralls

# Generate HTML coverage report
mix coveralls.html
```

### Code Quality
```bash
# Format code (ALWAYS run before committing)
mix format

# Run Credo linter
mix credo

# Run Credo strict analysis (used in CI)
mix credo --strict
```

### Model Training
```bash
# Train HMM POS tagger (fast, 95% accuracy)
mix nasty.train.pos \
  --corpus data/en_ewt-ud-train.conllu \
  --test data/en_ewt-ud-test.conllu \
  --output priv/models/en/pos_hmm.model

# Train neural POS tagger (slower, 97-98% accuracy)
mix nasty.train.neural_pos \
  --corpus data/en_ewt-ud-train.conllu \
  --output priv/models/en/pos_neural.axon \
  --epochs 10 \
  --batch-size 32

# Evaluate models
mix nasty.eval.pos \
  --model priv/models/en/pos_hmm.model \
  --test data/en_ewt-ud-test.conllu

# List available models
mix nasty.models list

# Fine-tune transformer models (98-99% accuracy)
mix nasty.fine_tune.pos \
  --model roberta_base \
  --corpus data/train.conllu \
  --output priv/models/en/pos_roberta.model \
  --epochs 3

# Zero-shot classification (no training needed)
mix nasty.zero_shot \
  --text "I love this product!" \
  --labels positive,negative,neutral

# Quantize models for deployment (4x compression)
mix nasty.quantize \
  --input priv/models/en/pos_neural.axon \
  --output priv/models/en/pos_neural_int8.axon \
  --calibration-data data/calibration.conllu
```

### Demo and Examples
```bash
# Run the complete NLP pipeline demo
./demo.exs

# Run example scripts
elixir examples/tokenizer_example.exs
```

## Architecture

### Behaviour-Based Language System
The project uses Elixir behaviours to define a language-agnostic interface. All language implementations must implement `Nasty.Language.Behaviour`:

- `language_code/0` - Returns ISO 639-1 code (e.g., `:en`)
- `tokenize/2` - Splits text into tokens
- `tag_pos/2` - Assigns part-of-speech tags
- `parse/2` - Builds AST from tokens
- `render/2` - Generates text from AST
- `metadata/0` - Optional language metadata

Languages are registered at runtime with `Nasty.Language.Registry`.

### NLP Pipeline Flow
```
Text → Tokenization → POS Tagging → Morphology → Phrase Parsing → Sentence Parsing → Document AST
                                                                                         ↓
                                                                    Entity Recognition, Dependencies, Summarization
```

The pipeline is modular:
1. **Tokenization** (`English.Tokenizer`) - NimbleParsec-based text segmentation
2. **POS Tagging** (`English.POSTagger`) - Rule-based, HMM, or Neural (BiLSTM-CRF) tagging
3. **Morphology** (`English.Morphology`) - Lemmatization and feature extraction
4. **Phrase Parsing** (`English.PhraseParser`) - Builds NP, VP, PP structures
5. **Sentence Parsing** (`English.SentenceParser`) - Clause detection and coordination
6. **Dependency Extraction** (`English.DependencyExtractor`) - Grammatical relations
7. **Entity Recognition** (`English.EntityRecognizer`) - Named entity detection
8. **Summarization** (`English.Summarizer`) - Extractive and abstractive summarization
9. **Question Answering**, **Text Classification**, **Information Extraction** - Advanced NLP tasks
10. **Code Interoperability** - Bidirectional NL ↔ Code conversion
    - Intent recognition with constraint extraction (comparison, property, range)
    - Natural language to Elixir code generation
    - Code explanation back to natural language

### AST Structure
The AST is hierarchical and linguistically rigorous:

- `Document` - Top level, contains paragraphs
- `Paragraph` - Contains sentences
- `Sentence` - Contains clauses (main + subordinate/relative)
- `Clause` - Contains subject and predicate phrases
- `Phrase` nodes - `NounPhrase`, `VerbPhrase`, `PrepositionalPhrase`, etc.
- `Token` - Atomic unit with text, POS tag, lemma, morphology

All nodes include:
- `span` - Position tracking (line/column + byte offsets)
- `language` - Language code (`:en`, `:es`, `:ca`, etc.)

### Key Design Principles
1. **Universal Dependencies** - Use UD tag set and dependency relations
2. **Position Tracking** - Every node has precise source location via `span`
3. **Language Markers** - All nodes carry language metadata for multilingual support
4. **Pure Elixir** - No external NLP dependencies; uses NimbleParsec for parsing
5. **Composable** - Small, focused modules that compose into full pipeline

### Recent Improvements (2026-01-08)

**Parser Enhancements**:
- Adjectival phrases now parse with prepositional complements ("greater than 21")
- "than" treated as pseudo-preposition in comparative constructions
- Numeric objects supported in comparative phrases
- Sentence-initial capitalized verbs correctly tagged in imperative sentences
- Code-generation verbs (filter, sort, map, reduce) added to POS lexicon
- Comparison and property adjectives expanded in lexicon

**Constraint Extraction**:
- Comparison constraints: `{:comparison, :greater_than, 21}`
- Property constraints: `{:property, :active, true}`
- Range constraints: `{:range, 50, 100}`
- Full token extraction from all phrase types (NP, VP, AdjP, AdvP, PP)

## Coding Style Rules

### Documentation
- Never use emojis in documentation, code comments, commit messages, or any technical writing
- Keep documentation professional and text-based

### Testing
- For short lists in tests, use pattern matching instead of `length/1`:
  - Good: `assert [_, _, _] = list` or `assert match?([_, _, _], list)`
  - Avoid: `assert length(list) == 3`
- This makes tests more explicit about structure and fails faster

## Testing Conventions

- Tests use `ExUnit.Case` with `async: true` for parallel execution
- Test files mirror source structure: `test/language/english/foo_test.exs` tests `lib/language/english/foo.ex`
- Use descriptive `describe` blocks for different test scenarios
- Include position tracking tests for tokenization/parsing
- Test both success and error paths

## Code Structure Notes

### Module Organization
```
lib/
├── nasty.ex                    # Public API and entry point
├── ast/                        # AST node definitions
│   ├── node.ex                 # Base types and utilities
│   ├── document.ex             # Document and Paragraph
│   ├── sentence.ex             # Sentence and Clause
│   ├── token.ex                # Token with POS/morphology
│   ├── dependency.ex           # Dependency relations
│   └── semantic.ex             # Entities and semantic nodes
├── language/
│   ├── behaviour.ex            # Language interface
│   ├── registry.ex             # Language registry (Agent)
│   └── english/                # English implementation
│       ├── tokenizer.ex        # NimbleParsec tokenization
│       ├── pos_tagger.ex       # Rule-based POS tagging
│       ├── morphology.ex       # Lemmatization
│       ├── phrase_parser.ex    # Phrase structure
│       ├── sentence_parser.ex  # Sentence/clause parsing
│       ├── dependency_extractor.ex
│       ├── entity_recognizer.ex
│       └── summarizer.ex
```

### Application Startup
The application is supervised (`Nasty.Application`) and automatically registers the English language module at startup. When adding new languages, register them in `application.ex`.

### NimbleParsec Usage
Tokenization uses NimbleParsec combinators for efficient parsing. Key patterns:
- `defparsec :parse_name, combinator` defines a parser
- Return format: `{:ok, result, rest, context, position, byte_offset}` or `{:error, ...}`
- Position tracking is automatic via context

## CI/CD

GitHub Actions runs three jobs on push/PR:
1. **Format Check** - `mix format --check-formatted`
2. **Credo Analysis** - `mix credo --strict`
3. **Tests & Coverage** - `mix test` with coverage reporting to Codecov

All jobs must pass for CI to succeed.

## Model Modes

POS tagging supports multiple models:
- **Rule-based** (`:rule`) - Fast, ~85% accuracy, no model loading
- **HMM** (`:hmm`) - Statistical, ~95% accuracy, fast inference
- **Neural** (`:neural`) - BiLSTM-CRF with Axon/EXLA, 97-98% accuracy
- **Transformer** (`:roberta_base`, `:bert_base_cased`) - Pre-trained models, 98-99% accuracy
- **Ensemble** (`:ensemble`) - Combines multiple models for best accuracy

## Transformer Models (NEW)

Nasty now supports pre-trained transformer models via Bumblebee:
- **Fine-tuning**: Full pipeline for POS tagging and NER
- **Zero-shot**: Classify without training using NLI models (70-85% accuracy)
- **Quantization**: INT8 compression for 4x smaller models and 2-3x faster inference
- **Multilingual**: XLM-RoBERTa support for 100+ languages including Spanish

See `docs/PRETRAINED_MODELS.md`, `docs/ZERO_SHOT.md`, and `docs/QUANTIZATION.md` for details.

```elixir
# Use in code
{:ok, tokens} = English.tag_pos(tokens, model: :neural)
{:ok, tokens} = English.tag_pos(tokens, model: :ensemble)
```

## Future Enhancements (from PLAN.md)

The project is designed for extensibility:
- Multi-language support (Spanish, Catalan) via behaviour implementations
- Pre-trained transformers (BERT, RoBERTa) - See docs/PRETRAINED_MODELS.md
- Advanced statistical models (PCFG, CRF)
- Enhanced coreference and semantic analysis

When implementing new features, maintain the grammar-first, AST-based approach and ensure all nodes carry position and language metadata.

## Documentation References

Key documentation files for understanding the codebase:

- **[PARSING_GUIDE.md](docs/PARSING_GUIDE.md)** - Complete reference for all parsing algorithms (tokenization, POS tagging, morphology, phrase/sentence parsing, dependencies). Essential reading for understanding how text is processed.

- **[ENGLISH_GRAMMAR.md](docs/languages/ENGLISH_GRAMMAR.md)** - Formal English grammar specification with CFG rules, dependency relations, morphological features, and lexical categories. The authoritative reference for the English parser implementation.

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture overview, design patterns, and module organization.

- **[NEURAL_MODELS.md](docs/NEURAL_MODELS.md)** - Neural network architecture details for BiLSTM-CRF POS tagger.

- **[TRAINING_NEURAL.md](docs/TRAINING_NEURAL.md)** - Guide for training neural models on custom datasets.

- **[ROADMAP.md](docs/ROADMAP.md)** - Feature roadmap with priorities, timelines, and implementation strategies.
