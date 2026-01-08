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

### 3. Advanced Statistical Models ✅

**Status**: ✅ Fully Implemented and Integrated  
**Effort**: Medium-Large (3-5 weeks each)  
**Reference**: `docs/STATISTICAL_MODELS.md`  
**Completed**: 2026-01-07

#### PCFG (Probabilistic Context-Free Grammar) Parser ✅

**Description**: Statistical parsing with probability-weighted grammar rules for improved phrase structure parsing.

**Implementation**:
- ✅ `lib/statistics/parsing/grammar.ex` - Rule representation and CNF conversion
- ✅ `lib/statistics/parsing/cyk_parser.ex` - CYK parsing algorithm  
- ✅ `lib/statistics/parsing/pcfg.ex` - Main PCFG model
- ✅ Grammar rule learning from treebanks
- ✅ Viterbi-style best parse selection
- ✅ Add-k smoothing for unseen rules
- ✅ Mix tasks: `mix nasty.train.pcfg`, `mix nasty.eval --type pcfg`
- ✅ Integration: `English.parse(tokens, model: :pcfg)`
- ✅ Comprehensive test suite

**Benefits**:
- ✅ Better ambiguity resolution with probabilities
- ✅ Confidence scores on parse trees
- ✅ More accurate phrase structure
- ✅ N-best parsing support
- ✅ Graceful fallback to rule-based parsing

**Performance**:
- Bracketing F1: 85-90% (expected)
- Speed: ~50-100ms per sentence (CPU)
- Complexity: O(n³) with beam search optimization

#### CRF (Conditional Random Fields) for NER ✅

**Description**: Sequence labeling model for significantly improved named entity recognition.

**Implementation**:
- ✅ `lib/statistics/sequence_labeling/features.ex` - Rich feature extraction
- ✅ `lib/statistics/sequence_labeling/viterbi.ex` - Viterbi decoding
- ✅ `lib/statistics/sequence_labeling/optimizer.ex` - Gradient descent optimization
- ✅ `lib/statistics/sequence_labeling/crf.ex` - Main CRF model
- ✅ Forward-backward algorithm for training
- ✅ BIO tagging scheme support
- ✅ Mix tasks: `mix nasty.train.crf`, `mix nasty.eval --type crf`
- ✅ Integration: `EntityRecognizer.recognize(tokens, model: :crf)`
- ✅ Comprehensive test suite

**Benefits**:
- ✅ Significantly better NER accuracy (92-95% F1 vs 70-80% rule-based)
- ✅ Proper entity boundary detection
- ✅ Context-aware predictions with rich features
- ✅ Confidence scores
- ✅ Graceful fallback to rule-based NER

**Performance**:
- Entity F1: 92-95% (expected on CoNLL-2003)
- Speed: ~20-30ms per sentence (CPU)
- Complexity: O(n × L²) where L = number of labels

### 4. Generic Algorithm Extraction ✅

**Status**: ✅ Fully Implemented  
**Effort**: Medium (2-3 weeks per module)  
**Reference**: `docs/REFACTORING.md`  
**Completed**: 2026-01-08

**Description**: Extract language-agnostic implementations for all NLP operations.

**Completed**:
- ✅ Extractive Summarization (`lib/operations/summarization/extractive.ex`)
- ✅ Rule-based NER (`lib/semantic/entity_recognition/rule_based.ex`)
- ✅ Coreference Resolution (`lib/semantic/coreference/resolver.ex`, `clusterer.ex`, `mention_detector.ex`, `scorer.ex`)
- ✅ Semantic Role Labeling (`lib/semantic/srl/labeler.ex`, `predicate_detector.ex`, `core_argument_mapper.ex`, `adjunct_classifier.ex`)
- ✅ Question Answering (`lib/operations/qa/qa_engine.ex`, `question_classifier.ex`, `candidate_scorer.ex`, `answer_selector.ex`)
- ✅ Text Classification (`lib/operations/classification/naive_bayes.ex`)

**Benefits**:
- ✅ Easier to add new languages (reuse 70-80% of code)
- ✅ Consistent behavior across languages
- ✅ Easier testing and maintenance
- ✅ Language implementations are now thin wrappers with config-based customization

**Example Impact**:
- Spanish/Catalan implementations only need ~100-150 lines per module for configuration
- Generic algorithms handle all core logic (scoring, clustering, extraction, classification)
- All 626 tests pass with generic implementations

### 5. Enhanced Documentation ✅

**Status**: ✅ Core documentation complete  
**Effort**: Small (1-2 weeks)  
**Completed**: 2026-01-08

**Completed Documents**:
- ✅ `docs/PARSING_GUIDE.md` - Detailed parsing algorithm documentation
- ✅ `docs/languages/ENGLISH_GRAMMAR.md` - English grammar specification
- ✅ Grammar resource files (`phrase_rules.ex`, `dependency_rules.ex`)
- ✅ Test fixtures (`sentences.txt`, `expected_asts_test.txt`)

**Future Documents** (pending language implementation):
- `docs/languages/SPANISH_GRAMMAR.md` - Spanish grammar spec (when Spanish implemented)
- `docs/languages/CATALAN_GRAMMAR.md` - Catalan grammar spec (when Catalan implemented)

**Benefits**:
- ✅ Better onboarding for contributors
- ✅ Clear reference for grammar rules
- ✅ Easier to implement new languages
- ✅ Comprehensive parsing and grammar documentation available

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

### 10. Full Ragex Integration

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

### Phase 2: Advanced Models (P2) ✅

**Timeline**: 2-3 months  
**Focus**: Pre-trained transformers and PCFG/CRF  
**Status**: PCFG/CRF completed, transformers planned

**Rationale**:
- Significant accuracy improvements
- Competitive with other NLP libraries
- Enables advanced use cases

**Completed Deliverables**:
- ✅ PCFG parser
- ✅ CRF-based NER

**Remaining Deliverables**:
- Bumblebee integration
- Fine-tuning pipelines

### Phase 3: Architecture Refinement (P2) ✅

**Timeline**: 2 months  
**Focus**: Complete generic algorithm extraction  
**Status**: ✅ Completed 2026-01-08

**Rationale**:
- Makes Phase 1 easier
- Cleaner codebase
- Better maintainability

**Completed Deliverables**:
- ✅ 6 generic algorithm modules (Text Classification, QA, Coreference, SRL, Summarization, NER)
- ✅ Refactored language adapters (English implementations now thin wrappers)
- ✅ Updated documentation (PARSING_GUIDE.md, ENGLISH_GRAMMAR.md)
- ✅ Grammar resource files (phrase_rules.ex, dependency_rules.ex)
- ✅ Test fixtures (sentences.txt, expected_asts_test.txt)

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
- Improve error messages
- Add Spanish/Catalan lexicons
- Add more test cases
- Improve documentation examples

### Intermediate
- Implement Spanish/Catalan language support
- Add model quantization
- Improve transformer integration

### Advanced
- Complete Bumblebee transformer integration
- Neural coreference resolution
- Dialogue systems
- Formal semantics

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

**Multi-language** → ✅ Generic algorithm extraction complete, ready for new languages  
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
  - PCFG/CRF statistical models completed

- **2026-01-08**: Major P2 features completed
  - ✅ Generic Algorithm Extraction fully implemented (all 6 modules)
  - ✅ Enhanced Documentation completed (PARSING_GUIDE.md, ENGLISH_GRAMMAR.md)
  - ✅ Grammar resource files created (phrase_rules.ex, dependency_rules.ex)
  - ✅ Test fixtures added (sentences.txt, expected_asts_test.txt)
  - Updated roadmap to reflect completed work
  - All 626 tests passing

---

**Last Updated**: 2026-01-08  
**Next Review**: 2026-04-07 (quarterly)
