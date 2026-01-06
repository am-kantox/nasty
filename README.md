# Nasty - Natural Abstract Syntax Treey

[![CI](https://github.com/am-kantox/nasty/workflows/CI/badge.svg)](https://github.com/am-kantox/nasty/actions)
[![codecov](https://codecov.io/gh/am-kantox/nasty/branch/main/graph/badge.svg)](https://codecov.io/gh/am-kantox/nasty)
[![Hex.pm](https://img.shields.io/hexpm/v/nasty.svg)](https://hex.pm/packages/nasty)
[![Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/nasty/)

**A comprehensive NLP library for Elixir that treats natural language with the same rigor as programming languages.**

Nasty provides a complete grammatical Abstract Syntax Tree (AST) for English, with a full NLP pipeline from tokenization to text summarization.

- **Tokenization** - NimbleParsec-based text segmentation
- **POS Tagging** - Rule-based + Statistical (HMM with Viterbi)
- **Morphological Analysis** - Lemmatization and features
- **Phrase Structure Parsing** - NP, VP, PP, and relative clauses
- **Complex Sentences** - Coordination, subordination
- **Dependency Extraction** - Universal Dependencies relations
- **Named Entity Recognition** - Person, place, organization
- **Semantic Role Labeling** - Predicate-argument structure (who did what to whom)
- **Coreference Resolution** - Link mentions across sentences
- **Text Summarization** - Extractive summarization with MMR
- **Question Answering** - Extractive QA for factoid questions
- **Statistical Models** - HMM POS tagger with 95% accuracy

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

# Semantic role labeling
{:ok, document_with_srl} = Nasty.Language.English.parse(tagged, semantic_roles: true)
# Access semantic frames
frames = document_with_srl.semantic_frames
# => [%SemanticFrame{predicate: "works", roles: [%Role{type: :agent, text: "John Smith"}, ...]}]

# Coreference resolution
{:ok, document_with_coref} = Nasty.Language.English.parse(tagged, coreference: true)
# Access coreference chains
chains = document_with_coref.coref_chains
# => [%CorefChain{representative: "John Smith", mentions: ["John Smith", "he"], ...}]

# Summarize
summary = English.summarize(document, ratio: 0.3)  # 30% compression
# or
summary = English.summarize(document, max_sentences: 3)  # Fixed count

# MMR (Maximal Marginal Relevance) for reduced redundancy
summary_mmr = English.summarize(document, max_sentences: 3, method: :mmr, mmr_lambda: 0.5)

# Question answering
{:ok, answers} = English.answer_question(document, "Who works at Google?")
# => [%Answer{text: "John Smith", confidence: 0.85, ...}]

# Statistical POS tagging (auto-loads from priv/models/)
{:ok, tokens_hmm} = English.tag_pos(tokens, model: :hmm)

# Or ensemble mode (combines statistical + rule-based)
{:ok, tokens_ensemble} = English.tag_pos(tokens, model: :ensemble)
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

1. **Tokenization** (`English.Tokenizer`) → Split text into tokens
2. **POS Tagging** (`English.POSTagger`) → Assign grammatical categories
3. **Morphology** (`English.Morphology`) → Lemmatization and features
4. **Phrase Parsing** (`English.PhraseParser`) → Build NP, VP, PP structures
5. **Sentence Parsing** (`English.SentenceParser`) → Detect clauses and structure
6. **Dependency Extraction** (`English.DependencyExtractor`) → Grammatical relations
7. **Entity Recognition** (`English.EntityRecognizer`) → Named entities
8. **Semantic Role Labeling** (`English.SemanticRoleLabeler`) → Predicate-argument structure
9. **Coreference Resolution** (`English.CoreferenceResolver`) → Link mentions
10. **Summarization** (`English.Summarizer`) → Extract key sentences
11. **Question Answering** (`English.QuestionAnalyzer`, `English.AnswerExtractor`) → Answer questions

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

### Text Summarization
- **Extractive summarization** - Select important sentences from document
- **Multiple scoring features**:
  - Position weight (early sentences score higher)
  - Entity density (sentences with named entities)
  - Discourse markers ("in conclusion", "importantly", etc.)
  - Keyword frequency (TF scoring)
  - Sentence length (prefer moderate length)
  - Coreference participation (sentences in coref chains)
- **Selection methods**:
  - `:greedy` - Top-N by score (default)
  - `:mmr` - Maximal Marginal Relevance (reduces redundancy)
- **Flexible options**: compression ratio or fixed sentence count

### Question Answering
- **Extractive QA** - Extract answer spans from documents
- **Question classification**:
  - WHO (person entities)
  - WHAT (things, organizations)
  - WHEN (temporal expressions)
  - WHERE (locations)
  - WHY (reasons, clauses)
  - HOW (manner, quantity)
  - YES/NO (boolean questions)
- **Answer extraction strategies**:
  - Keyword matching with lemmatization
  - Entity type filtering (person, organization, location)
  - Temporal expression recognition
  - Confidence scoring and ranking
- **Multiple answer support** with confidence scores

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

## Statistical Models

Nasty includes statistical machine learning models for improved accuracy:

- **HMM POS Tagger**: Hidden Markov Model with Viterbi decoding (~95% accuracy)
- **Training infrastructure**: Train custom models on your own data
- **Evaluation metrics**: Accuracy, precision, recall, F1, confusion matrices

See [STATISTICAL_MODELS.md](STATISTICAL_MODELS.md) for implementation details and [TRAINING_GUIDE.md](TRAINING_GUIDE.md) for step-by-step training instructions.

### Quick Start: Model Management

```bash
# List available models
mix nasty.models list

# Train a new model
mix nasty.train.pos \
  --corpus data/UD_English-EWT/en_ewt-ud-train.conllu \
  --test data/UD_English-EWT/en_ewt-ud-test.conllu \
  --output priv/models/en/pos_hmm_v1.model

# Evaluate model
mix nasty.eval.pos \
  --model priv/models/en/pos_hmm_v1.model \
  --test data/UD_English-EWT/en_ewt-ud-test.conllu \
  --baseline
```

## Future Enhancements

- [x] Statistical models for improved accuracy (HMM POS tagger - done!)
- [x] Semantic role labeling (rule-based SRL - done!)
- [x] Coreference resolution (heuristic-based - done!)
- [x] Question answering (extractive QA - done!)
- [ ] PCFG parser for phrase structure
- [ ] CRF for named entity recognition  
- [ ] Multi-language support (Spanish, Catalan)
- [ ] Advanced coreference (neural models)
- [ ] Code ↔ NL bidirectional conversion

## License

MIT License - see LICENSE file for details.

---

**Built with ❤️ using Elixir and NimbleParsec**
