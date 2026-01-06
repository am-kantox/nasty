# Nasty - Natural Abstract Syntax Treey

[![CI](https://github.com/am-kantox/nasty/workflows/CI/badge.svg)](https://github.com/am-kantox/nasty/actions)
[![codecov](https://codecov.io/gh/am-kantox/nasty/branch/main/graph/badge.svg)](https://codecov.io/gh/am-kantox/nasty)
[![Hex.pm](https://img.shields.io/hexpm/v/nasty.svg)](https://hex.pm/packages/nasty)
[![Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/nasty/)

**A comprehensive NLP library for Elixir that treats natural language with the same rigor as programming languages.**

Nasty provides a complete grammatical Abstract Syntax Tree (AST) for English, with a full NLP pipeline from tokenization to text summarization.

- **Tokenization** - NimbleParsec-based text segmentation
- **POS Tagging** - Universal Dependencies part-of-speech tagging  
- **Morphological Analysis** - Lemmatization and features
- **Phrase Structure Parsing** - NP, VP, PP, and relative clauses
- **Complex Sentences** - Coordination, subordination
- **Dependency Extraction** - Universal Dependencies relations
- **Named Entity Recognition** - Person, place, organization
- **Text Summarization** - Extractive summarization

## Quick Start

```bash
# Run the complete demo
./demo.exs
```

```elixir
alias Nasty.Language.English

# Simple example
text = "John Smith works at Google in New York."

{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

# Extract entities
alias Nasty.Language.English.EntityRecognizer
entities = EntityRecognizer.recognize(tagged)
# => [%Entity{type: :person, text: "John Smith"}, 
#     %Entity{type: :org, text: "Google"}, ...]

# Extract dependencies
alias Nasty.Language.English.DependencyExtractor
sentences = document.paragraphs |> Enum.flat_map(& &1.sentences)
deps = Enum.flat_map(sentences, &DependencyExtractor.extract/1)

# Summarize
alias Nasty.Language.English.Summarizer
summary = Summarizer.summarize(document, ratio: 0.5)
```

## Architecture

```
Text → Tokenization → POS Tagging → Phrase Parsing → Sentence Parsing → Document AST
                                                                            ↓
                                    ┌───────────────┬───────────────┬──────────────┐
                                    │               │               │              │
                              Dependencies    Entities      Summarization   (more...)
```

### Complete Pipeline

1. **Tokenization** (`English.Tokenizer`) - Split text into tokens
2. **POS Tagging** (`English.POSTagger`) - Assign grammatical categories
3. **Morphology** (`English.Morphology`) - Lemmatization and features
4. **Phrase Parsing** (`English.PhraseParser`) - Build NP, VP, PP structures
5. **Sentence Parsing** (`English.SentenceParser`) - Detect clauses and structure
6. **Dependency Extraction** (`English.DependencyExtractor`) - Grammatical relations
7. **Entity Recognition** (`English.EntityRecognizer`) - Named entities
8. **Summarization** (`English.Summarizer`) - Extract key sentences

## Features

### Phrase Structures
- Noun Phrases (NP): `Det? Adj* Noun PP* RelClause*`
- Verb Phrases (VP): `Aux* Verb NP? PP* Adv*`
- Prepositional Phrases (PP): `Prep NP`
- Relative Clauses: `RelPron/RelAdv Clause`

### Sentence Types
- Simple, Compound, Complex sentences
- Coordination (and, or, but)
- Subordination (because, although, if)
- Relative clauses (who, which, that)

### Dependencies (Universal Dependencies)
- Core arguments: `nsubj`, `obj`, `iobj`
- Modifiers: `amod`, `advmod`, `det`, `case`
- Clausal: `acl`, `advcl`, `mark`
- Coordination: `conj`, `cc`

### Entity Types
- Person, Organization, Place (GPE)
- With confidence scores and multi-word support

## Testing

```bash
# Run all tests
mix test

# Run specific module tests
mix test test/language/english/tokenizer_test.exs
mix test test/language/english/phrase_parser_test.exs
mix test test/language/english/dependency_extractor_test.exs
```

## Documentation

For detailed documentation on the original vision and architecture, see [PLAN.md](PLAN.md).

## Future Enhancements

- [ ] Statistical models for improved accuracy
- [ ] Multi-language support (Spanish, Catalan)
- [ ] Coreference resolution
- [ ] Semantic role labeling
- [ ] Code ↔ NL bidirectional conversion

## License

MIT License - see LICENSE file for details.

---

**Built with ❤️ using Elixir and NimbleParsec**
