# Nasty Development Roadmap

This document outlines all planned features that are not yet implemented, organized by priority and category.

## Priority Levels

- **P0 (Critical)**: Essential for core functionality or major user requests
- **P1 (High)**: Important features that significantly enhance the library
- **P2 (Medium)**: Valuable additions that improve usability or performance
- **P3 (Low)**: Nice-to-have features, research projects, or long-term goals

## Currently Implemented Features

For reference, the following major features are complete:
- Core English NLP pipeline (tokenization, POS tagging, morphology, parsing)
- Three POS tagging modes: rule-based (85%), HMM (95%), neural BiLSTM-CRF (97-98%)
- Semantic analysis (NER, SRL, coreference resolution, word sense disambiguation)
- Extractive and abstractive summarization
- Question answering (extractive)
- Text classification (Multinomial Naive Bayes)
- Information extraction (relations, events, templates)
- Code interoperability (NL ↔ Elixir code)
- AST utilities (traversal, query, validation, transform)
- Rendering and visualization (text, DOT, JSON, pretty print)
- Statistical and neural model infrastructure
- Complete documentation suite

---

## P0: Critical Priority

### None Currently

All critical features for the initial release have been implemented.

---

## P1: High Priority

### 1. Multi-Language Support

**Status**: Not started  
**Effort**: Large (6-8 weeks per language)  
**Dependencies**: None

#### Spanish Language Implementation

**Description**: Full Spanish NLP pipeline following the established behaviour-based architecture.

**Components Needed**:
- Tokenizer with Spanish punctuation rules (¿?, «», etc.)
- POS tagger (rule-based + statistical/neural)
- Morphology analyzer (gender agreement, subjunctive mood, clitic pronouns)
- Phrase and sentence parser
- Entity recognizer with Spanish patterns
- Spanish lexicons and resources in `priv/languages/spanish/`

**Benefits**:
- Validates language-agnostic architecture
- Opens library to Spanish-speaking users
- Demonstrates multi-language capabilities

**Reference**: See `docs/LANGUAGE_GUIDE.md` for implementation details

#### Catalan Language Implementation

**Description**: Full Catalan NLP pipeline.

**Components Needed**:
- Similar to Spanish implementation
- Catalan-specific morphology and lexicons
- Resources in `priv/languages/catalan/`

**Benefits**:
- Completes trilingual capability (English, Spanish, Catalan)
- Important for regional NLP applications

**Reference**: See `docs/LANGUAGE_GUIDE.md`

---

## P2: Medium Priority

### 2. Pre-trained Transformer Models

**Status**: Stub interfaces defined, implementation planned  
**Effort**: Medium (4-6 weeks)  
**Dependencies**: Bumblebee library integration  
**Reference**: `docs/PRETRAINED_MODELS.md`

**Description**: Integration with Hugging Face transformers via Bumblebee for state-of-the-art NLP performance.

**Components**:
- Model loading and caching infrastructure
- Fine-tuning pipelines for POS tagging, NER, dependency parsing
- Zero-shot and few-shot learning capabilities
- Support for BERT, RoBERTa, DistilBERT, XLM-RoBERTa

**Expected Performance**:
- POS Tagging: 98-99% (vs 97-98% BiLSTM-CRF)
- NER: 93-95% F1 (vs current rule-based)
- Dependency Parsing: 96-97% UAS

**Benefits**:
- State-of-the-art accuracy across tasks
- Multilingual models (mBERT, XLM-R) for Spanish/Catalan
- Reduced training time via transfer learning

**Challenges**:
- Large model files (100MB-1.4GB)
- Higher memory requirements (500MB-2.5GB RAM)
- Slower inference without GPU

**Implementation Notes**:
- Start with BERT-base for POS tagging
- Add model quantization for faster inference
- Provide CPU and GPU optimized versions

### 3. Advanced Statistical Models

**Status**: Documented, not implemented  
**Effort**: Medium-Large (3-5 weeks each)  
**Reference**: `docs/FUTURE_FEATURES.md`

#### PCFG (Probabilistic Context-Free Grammar) Parser

**Description**: Statistical parsing with probability-weighted grammar rules for improved phrase structure parsing.

**Approach**:
- Learn rule probabilities from treebanks (Penn Treebank, UD corpora)
- Implement CYK algorithm for parsing
- Viterbi-like best parse selection

**Benefits**:
- Better ambiguity resolution
- Probabilistic confidence scores
- More accurate phrase structure

**Challenges**:
- Requires annotated treebank for training
- O(n³) computational complexity
- Grammar rule extraction and smoothing

#### CRF (Conditional Random Fields) for NER

**Description**: Sequence labeling model for improved named entity recognition.

**Approach**:
- Feature extraction (word shape, context, gazetteers)
- Viterbi decoding for label sequences
- Training on CoNLL-2003, OntoNotes

**Expected Performance**:
- 92-95% F1 on CoNLL-2003 (vs current rule-based)

**Benefits**:
- Significantly better NER accuracy
- Better handling of entity boundaries
- Context-aware predictions

**Challenges**:
- Feature engineering complexity
- Requires optimization library (L-BFGS)
- May need Rust NIF for performance

### 4. Generic Algorithm Extraction

**Status**: Partially complete (2 of 6 modules)  
**Effort**: Medium (2-3 weeks per module)  
**Reference**: `docs/REFACTORING.md`

**Description**: Extract language-agnostic implementations for remaining NLP operations.

**Completed**:
- ✅ Extractive Summarization (`lib/operations/summarization/extractive.ex`)
- ✅ Rule-based NER (`lib/semantic/entity_recognition/rule_based.ex`)

**Remaining**:
- Coreference Resolution - Extract scoring and clustering algorithms
- Semantic Role Labeling - Extract role mapping framework
- Question Answering - Extract answer extraction strategies
- Text Classification - Extract Naive Bayes training/prediction

**Benefits**:
- Easier to add new languages (reuse 70-80% of code)
- Consistent behavior across languages
- Easier testing and maintenance

**Example Impact**:
- Spanish summarization would reuse 440 lines of generic algorithm
- Only need ~100 lines for Spanish-specific configuration

### 5. Enhanced Documentation

**Status**: Partial (10 of 14 documents complete)  
**Effort**: Small (1-2 weeks)

**Missing Documents**:
- `docs/PARSING_GUIDE.md` - Detailed parsing algorithm documentation
- `docs/languages/ENGLISH_GRAMMAR.md` - English grammar specification
- `docs/languages/SPANISH_GRAMMAR.md` - Spanish grammar spec (when implemented)
- `docs/languages/CATALAN_GRAMMAR.md` - Catalan grammar spec (when implemented)

**Benefits**:
- Better onboarding for contributors
- Clear reference for grammar rules
- Easier to implement new languages

---

## P3: Low Priority

### 6. Advanced Neural Architectures

**Status**: Research phase  
**Effort**: Large (8-12 weeks)  
**Reference**: `docs/NEURAL_MODELS.md`, `docs/PRETRAINED_MODELS.md`

#### Transformer-based Dependency Parsing

**Description**: Biaffine attention parser using transformer encoders.

**Expected Performance**: 96-97% UAS on UD treebanks

**Benefits**:
- State-of-the-art dependency parsing
- Better handling of long-range dependencies

**Challenges**:
- Requires transformer backbone (BERT/RoBERTa)
- Complex architecture implementation
- Large training data requirements

#### Neural Coreference Resolution

**Description**: Replace heuristic-based coreference with neural models.

**Approaches**:
- End-to-end neural coreference (Lee et al. 2017)
- SpanBERT-based mention ranking

**Benefits**:
- Much higher accuracy
- Better handling of complex coreference patterns

**Challenges**:
- Requires large annotated datasets (OntoNotes)
- High computational requirements

### 7. Dialogue Systems

**Status**: Planned, not started  
**Effort**: Large (10-12 weeks)  
**Reference**: `docs/FUTURE_FEATURES.md`

**Description**: Multi-turn conversational AI with context tracking.

**Components Needed**:
- Dialogue state tracking
- Intent recognition (basic version exists)
- Response generation
- Context management across turns
- Anaphora resolution in dialogue

**Features**:
- Turn-taking management
- Entity carryover across turns
- Dialogue act classification
- Clarification questions
- Response template selection

**Use Cases**:
- Chatbots
- Virtual assistants
- Interactive documentation

**Challenges**:
- Need dialogue corpus (MultiWOZ, PersonaChat)
- Context window management
- Response quality evaluation

**Datasets**:
- MultiWOZ for task-oriented dialogue
- PersonaChat for open-domain
- DSTC challenges

### 8. Formal Semantics

**Status**: Research phase  
**Effort**: Large (12-16 weeks)  
**Reference**: `docs/FUTURE_FEATURES.md`

**Description**: Lambda calculus representation for logical inference and reasoning.

**Components**:
- Semantic parser (NL → Lambda expressions)
- Logical forms (first-order logic)
- Inference engine (logical deduction)
- Theorem prover (verify entailments)

**Key Concepts**:
- Lambda expressions: `λx.P(x)`
- Function application
- Quantifiers: `∀x.P(x)`, `∃x.P(x)`
- Logical connectives

**Example**:
```
"Every dog barks" → ∀x.(dog(x) → barks(x))
"Fido is a dog"   → dog(fido)
Inference: barks(fido) ✓
```

**Benefits**:
- Enable logical reasoning
- Question answering with inference
- Knowledge base integration

**Challenges**:
- Compositional semantics is complex
- Quantifier scoping ambiguity
- Requires lexical semantics for all words
- Inference is computationally hard

**Resources**:
- Blackburn & Bos "Representation and Inference for Natural Language"
- Abstract Meaning Representation (AMR)

### 9. Infrastructure Improvements

#### Model Quantization

**Effort**: Small (1-2 weeks)

**Description**: INT8 quantization for neural models to reduce size and improve inference speed.

**Benefits**:
- 4x smaller model files
- 2-3x faster inference
- Lower memory usage

#### Model Distillation

**Effort**: Medium (3-4 weeks)

**Description**: Compress large models (e.g., RoBERTa-large) into smaller student models.

**Benefits**:
- 40-50% smaller models
- 2-3x faster inference
- 95-97% of original accuracy retained

#### Distributed Training

**Effort**: Medium (3-4 weeks)

**Description**: Multi-node training for large models and datasets.

**Benefits**:
- Train on larger datasets
- Faster training time
- Scale to production workloads

### 10. Additional Resources

#### Grammar Resource Files

**Effort**: Small (1 week)

**Missing Files**:
- `priv/languages/english/grammars/phrase_rules.ex` - CFG phrase rules
- `priv/languages/english/grammars/dependency_rules.ex` - Dependency templates

**Benefits**:
- Easier to extend grammar
- Better documentation of parsing rules
- Configurable parsing behavior

#### Test Fixtures

**Effort**: Small (1 week)

**Missing**:
- `test/fixtures/english/sentences.txt` - Standard test sentences
- `test/fixtures/english/expected_asts.exs` - Expected parse results
- Multi-language test data (when languages implemented)

**Benefits**:
- Regression testing
- Easier to verify changes
- Standard benchmarks

### 11. Full Ragex Integration

**Status**: Stub interface exists  
**Effort**: Medium (3-4 weeks)

**Description**: Deep integration with Ragex for code+text hybrid analysis.

**Current State**:
- `Nasty.Interop.RagexBridge` exists but integration is optional
- Basic code generation works

**Enhancements Needed**:
- Context-aware code generation using codebase knowledge
- Function signature and documentation integration
- Semantic search for function suggestions
- Multi-file code understanding

**Benefits**:
- Better code generation accuracy
- Context-aware suggestions
- Integration with existing codebases

---

## Implementation Strategy

### Phase 1: Multi-Language Support (P1)

**Timeline**: 3-4 months  
**Focus**: Spanish implementation first, then Catalan

**Rationale**:
- Validates language-agnostic architecture
- High user demand
- Enables broader adoption

**Deliverables**:
- Complete Spanish pipeline
- Spanish lexicons and resources
- Comprehensive tests
- Documentation

### Phase 2: Advanced Models (P2)

**Timeline**: 2-3 months  
**Focus**: Pre-trained transformers and PCFG/CRF

**Rationale**:
- Significant accuracy improvements
- Competitive with other NLP libraries
- Enables advanced use cases

**Deliverables**:
- Bumblebee integration
- Fine-tuning pipelines
- PCFG parser
- CRF-based NER

### Phase 3: Architecture Refinement (P2)

**Timeline**: 2 months  
**Focus**: Complete generic algorithm extraction

**Rationale**:
- Makes Phase 1 easier
- Cleaner codebase
- Better maintainability

**Deliverables**:
- 6 generic algorithm modules
- Refactored language adapters
- Updated documentation

### Phase 4: Research Features (P3)

**Timeline**: 6-12 months  
**Focus**: Dialogue systems, formal semantics, advanced neural models

**Rationale**:
- Differentiating features
- Academic interest
- Long-term vision

**Deliverables**:
- Experimental implementations
- Research papers
- Community feedback

---

## Community Contributions

We welcome contributions! Here are good starting points:

### Good First Issues
- Add missing documentation (PARSING_GUIDE.md, etc.)
- Create test fixtures
- Add grammar resource files
- Improve error messages

### Intermediate
- Implement Spanish/Catalan language support
- Extract generic algorithms for remaining modules
- Add model quantization

### Advanced
- Pre-trained transformer integration
- PCFG/CRF implementation
- Neural coreference resolution
- Dialogue systems

---

## Dependencies and Blockers

### External Dependencies

**Bumblebee Integration** (for transformers):
- Status: Library available, integration needed
- Blocker: None

**Training Corpora**:
- Universal Dependencies (available)
- CoNLL-2003 (available)
- OntoNotes (license required)
- Dialogue corpora (various licenses)

**Optimization Libraries**:
- For CRF: May need Rust NIF or external library
- For PCFG: Pure Elixir implementation possible

### Internal Dependencies

**Multi-language** → Complete generic algorithm extraction first  
**Dialogue systems** → Depends on better coreference resolution  
**Formal semantics** → Depends on better parsing

---

## Success Metrics

### Performance Targets

**Accuracy**:
- POS Tagging: ≥98% (transformers)
- NER: ≥93% F1 (CRF or transformers)
- Dependency Parsing: ≥95% UAS (PCFG or transformers)
- Coreference: ≥70% F1 (neural models)

**Speed**:
- Tokenization: <10ms per sentence
- POS Tagging: <50ms per sentence (CPU)
- Full pipeline: <200ms per sentence (CPU)

**Memory**:
- Base library: <100MB
- With HMM models: <200MB
- With neural models: <500MB (CPU), <2GB (GPU)

### Adoption Metrics

- 100+ GitHub stars
- 10+ external contributors
- 5+ production deployments
- Multi-language support for 3+ languages

---

## Related Documents

- [PLAN.md](../PLAN.md) - Original implementation plan
- [TODO.md](../TODO.md) - Detailed implementation status
- [FUTURE_FEATURES.md](FUTURE_FEATURES.md) - Detailed feature descriptions
- [REFACTORING.md](REFACTORING.md) - Architecture evolution
- [PRETRAINED_MODELS.md](PRETRAINED_MODELS.md) - Transformer integration
- [NEURAL_MODELS.md](NEURAL_MODELS.md) - Neural architecture details
- [LANGUAGE_GUIDE.md](LANGUAGE_GUIDE.md) - Adding new languages

---

## Revision History

- **2026-01-07**: Initial roadmap created based on existing documentation
- Priorities assigned based on user value and implementation effort
- Implementation phases outlined

---

**Last Updated**: 2026-01-07  
**Next Review**: 2026-04-07 (quarterly)
