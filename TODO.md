# TODO - Nasty Implementation Status

This document tracks what has NOT YET been implemented from PLAN.md.

## Major Missing Components

### 1. Module Structure Gaps

The following directories mentioned in PLAN.md (lines 806-883) don't exist:

#### `lib/parsing/` - Language-agnostic parsing layer
Currently, parsing logic is in `lib/language/english/`. Need to extract:
- `grammar.ex` - Grammar rules engine
- `phrase_parser.ex` - Phrase structure parsing
- `dependency_parser.ex` - Dependency parsing (exists in `language/english/` instead)
- `clause_parser.ex` - Clause identification
- `sentence_parser.ex` - Sentence parsing (exists in `language/english/` instead)

#### `lib/semantic/` - Language-agnostic semantic layer
Partially implemented:
- `entity_recognition.ex` - Behaviour and `RuleBased` implementation ✅
- `coreference_resolution.ex` - Behaviour (generic extraction pending)
- `word_sense_disambiguation.ex` - Lesk algorithm implementation ✅
- Language-specific implementations remain in `lib/language/english/`:
  - `entity_recognizer.ex` (delegates to generic)
  - `semantic_role_labeler.ex`
  - `coreference_resolver.ex`
  - `word_sense_disambiguator.ex` (delegates to generic)

#### `lib/operations/` - Language-agnostic NLP operations
Currently, operations are in `lib/language/english/`. Need to extract:
- `summarization.ex` (exists in `language/english/summarizer.ex` instead)
- `question_answering.ex` (exists in `language/english/question_analyzer.ex` and `answer_extractor.ex`)
- `classification.ex` (exists in `language/english/text_classifier.ex`)
- `extraction.ex` (exists in multiple `language/english/*_extractor.ex` files)

### 2. Language Infrastructure Not Implemented

- `Nasty.Language.Parser` - Generic parsing interface (PLAN.md line 43-45)
- `Nasty.Language.Renderer` - Generic renderer interface (PLAN.md line 47-49) (partially done in `rendering/text.ex`)

### 3. Multi-Language Support (PARTIALLY IMPLEMENTED)

#### Spanish Implementation ✅ COMPLETED (2026-01-08)
- ✅ `lib/language/spanish/` directory with 13 modules
- ✅ Spanish tokenizer (handles ¿?, «», accents, clitics)
- ✅ Spanish POS tagger (verb conjugations, gender/number agreement)
- ✅ Spanish morphology (lemmatization, feature extraction)
- ✅ Spanish phrase parser and sentence parser
- ✅ Spanish dependency extractor
- ✅ Spanish entity recognizer (40+ names, 40+ places, organization patterns)
- ✅ Spanish summarizer (5 categories of discourse markers, 100+ stop words)
- ✅ Spanish coreference resolver (complete pronoun system: subject, object, reflexive, possessive, demonstrative)
- ✅ Spanish adapters (3 total, 843 lines):
  - `Spanish.Adapters.SummarizerAdapter` (241 lines)
  - `Spanish.Adapters.EntityRecognizerAdapter` (346 lines)
  - `Spanish.Adapters.CoreferenceResolverAdapter` (256 lines)
- ✅ All Spanish modules delegate to generic algorithms (45% code reduction)
- ✅ Registered in application startup
- ✅ Comprehensive example script (`examples/spanish_example.exs`)
- ✅ Complete documentation (`docs/languages/SPANISH_IMPLEMENTATION.md`, 385 lines)
- ✅ All tests passing (641 tests total, 9 Spanish-specific)

#### Catalan Implementation
- No `lib/language/catalan/` directory
- No Catalan tokenizer, POS tagger, morphology, parser
- No `priv/languages/catalan/` resource directory

#### Cross-language Translation
- NL(English) ↔ NL(Spanish) via shared AST representation
- NL(English) ↔ NL(Catalan) via shared AST representation
- Multi-language rendering: `Nasty.render(ast, target_language: :es)` (PLAN.md line 1018-1019)

### Documentation Missing

From PLAN.md lines 932-943, the following documents status:

- ✅ `docs/PARSING_GUIDE.md` - Parsing algorithm details - EXISTS
- ✅ `docs/STATISTICAL_MODELS.md` - Statistical models guide - EXISTS (includes PCFG and CRF)
- ❌ `docs/TRAINING_GUIDE.md` - Model training guide - (covered in STATISTICAL_MODELS.md and TRAINING_NEURAL.md)
- ✅ `docs/languages/ENGLISH_GRAMMAR.md` - English grammar specification - EXISTS
- ❌ `docs/languages/SPANISH_GRAMMAR.md` - Spanish grammar (future)
- ❌ `docs/languages/CATALAN_GRAMMAR.md` - Catalan grammar (future)

### 5. Resource Files Missing

From PLAN.md lines 888-897:

#### English Resources
- `priv/languages/english/grammars/phrase_rules.ex` - CFG phrase rules
- `priv/languages/english/grammars/dependency_rules.ex` - Dependency templates

#### Spanish Resources ✅ COMPLETED (2026-01-08)
- ✅ Spanish adapters provide all language-specific configuration
- ✅ Spanish discourse markers (40+ markers across 5 categories)
- ✅ Spanish stop words (100+ words)
- ✅ Spanish entity lexicons (40+ person names, 40+ places, organization patterns)
- ✅ Spanish pronoun system (subject, object, reflexive, possessive, demonstrative)
- ✅ Spanish titles, date/time patterns, money patterns

#### Catalan Resources (future)
- `priv/languages/catalan/` - All Catalan language resources

### 6. Advanced Features (Future Directions, PLAN.md lines 1048-1061)

#### Abstractive Summarization
- ✅ Template-based abstractive summarization IMPLEMENTED (2026-01-07)
- `lib/operations/summarization/abstractive.ex` and `lib/language/english/abstractive_summarizer.ex`
- Neural attention-based models remain a future enhancement (see `docs/FUTURE_FEATURES.md`)

#### Advanced Statistical Models
- ✅ **Neural models (BiLSTM-CRF)** IMPLEMENTED (2026-01-07)
  - `lib/statistics/pos_tagging/neural_tagger.ex` - BiLSTM-CRF POS tagger
  - `lib/statistics/neural/` - Complete neural infrastructure (8 modules)
  - 97-98% accuracy on UD-EWT test set (vs 95% HMM, 85% rule-based)
  - Axon/EXLA for GPU acceleration
  - `mix nasty.train.neural_pos` - Training task
  - Documented in `docs/NEURAL_MODELS.md`, `docs/TRAINING_NEURAL.md`, `docs/PRETRAINED_MODELS.md`
- ✅ **PCFG parser** IMPLEMENTED (2026-01-07)
  - `lib/statistics/parsing/pcfg.ex` - Main PCFG model
  - `lib/statistics/parsing/grammar.ex` - Rule representation and CNF conversion
  - `lib/statistics/parsing/cyk_parser.ex` - CYK parsing algorithm
  - Integration: `English.parse(tokens, model: :pcfg)` and `SentenceParser.parse_sentences(tokens, model: :pcfg)`
  - Mix tasks: `mix nasty.train.pcfg`, `mix nasty.eval --type pcfg`
  - Comprehensive test suite in `test/statistics/parsing/pcfg_test.exs`
  - Documented in `docs/STATISTICAL_MODELS.md`
- ✅ **CRF for named entity recognition** IMPLEMENTED (2026-01-07)
  - `lib/statistics/sequence_labeling/crf.ex` - Main CRF model
  - `lib/statistics/sequence_labeling/features.ex` - Feature extraction
  - `lib/statistics/sequence_labeling/viterbi.ex` - Viterbi decoding
  - `lib/statistics/sequence_labeling/optimizer.ex` - Gradient descent optimization
  - Integration: `EntityRecognizer.recognize(tokens, model: :crf)`
  - Mix tasks: `mix nasty.train.crf`, `mix nasty.eval --type crf`
  - Comprehensive test suite in `test/statistics/sequence_labeling/crf_test.exs`
  - Documented in `docs/STATISTICAL_MODELS.md`
- **Pre-trained transformers (BERT, RoBERTa)** - planned, documented in `docs/PRETRAINED_MODELS.md`

#### Additional NLP Capabilities
- ✅ **Word sense disambiguation** IMPLEMENTED (2026-01-07)
  - `lib/semantic/word_sense_disambiguation.ex` - Lesk algorithm framework
  - `lib/language/english/word_sense_disambiguator.ex` - English implementation
- **Dialogue systems** (line 1057) - documented in `docs/FUTURE_FEATURES.md`
- **Formal semantics** (line 1059) - documented in `docs/FUTURE_FEATURES.md`
- **Code understanding** (line 1058) - Full program comprehension and explanation

#### Integration
- **Integration with Ragex** (line 1060) - Use as NLP backend for code+text hybrid analysis
  - `Nasty.Interop.RagexBridge` exists but integration is optional

### 7. Code Interoperability Gaps

#### Known TODOs in Code
- `lib/interop/intent_recognizer.ex:51` - "semantic_frames is not yet implemented in Clause struct" (FIXED)
- `lib/interop/intent_recognizer.ex:55` - "might be too simplified" - Intent building could be more sophisticated
- `lib/interop/code_gen/explain.ex:289` - Explanation could be more detailed
- `lib/interop/code_gen/explain.ex:350` - Additional code patterns could be supported

#### Missing Functionality
- More sophisticated intent recognition
- Broader code pattern coverage

### 8. Top-Level API Functions

Note: `Nasty.PrettyPrint` and `Nasty.Visualization` are available via their full module names:
- `Nasty.Rendering.PrettyPrint`
- `Nasty.Rendering.Visualization`

### 9. Additional Missing Features

#### Test Fixtures
- `test/fixtures/english/sentences.txt` - Test sentences
- `test/fixtures/english/expected_asts_test.ex` - Expected parse results
- `test/fixtures/spanish/` - Spanish test data (future)
- `test/fixtures/catalan/` - Catalan test data (future)

#### Example Scripts
Missing from `examples/`:
- Examples specifically for multi-language support
- Advanced statistical model usage examples (beyond basic HMM)
- Dialogue system examples (when implemented)

## Implementation Status Summary

### Successfully Implemented ✅

- Core English NLP pipeline (tokenization, POS, morphology, parsing)
- Statistical models (HMM POS tagger with 95% accuracy)
- Neural models (BiLSTM-CRF POS tagger with 97-98% accuracy using Axon/EXLA) ✅ NEW
- Semantic analysis (NER, SRL, coreference)
- Extractive summarization & question answering
- Text classification (Multinomial Naive Bayes)
- Information extraction (relations, events, templates)
- Code interoperability (NL → Code and Code → NL)
- AST utilities (traversal, query, validation, transform)
- Rendering and visualization (text, DOT, JSON, pretty print)
- Language behaviour and registry system
- Data layer (CoNLL-U parser, corpus management)
- Model infrastructure (registry, loader, downloader)
- Mix tasks for model training and evaluation (HMM + Neural)
- **Language detection** (character set + word frequency analysis for EN/ES/CA) ✅ NEW
- **Neural model infrastructure** (`lib/statistics/neural/` with 8 modules for training/inference) ✅ NEW
- **Neural model documentation** (`docs/NEURAL_MODELS.md`, `TRAINING_NEURAL.md`, `PRETRAINED_MODELS.md`) ✅ NEW
- **Top-level convenience APIs** (`Nasty.summarize/2`, `Nasty.to_code/2`, `Nasty.explain_code/2`) ✅ NEW
- **Multiple constraints in code generation** (filter predicates now support multiple AND-ed constraints) ✅ NEW
- **API documentation** (`docs/API.md` with complete public API reference) ✅ NEW
- **AST reference documentation** (`docs/AST_REFERENCE.md` with all node types) ✅ NEW
- **Architecture documentation** (`docs/ARCHITECTURE.md` with system design) ✅ NEW
- **Language guide** (`docs/LANGUAGE_GUIDE.md` for adding new languages) ✅ NEW
- **Interop guide** (`docs/INTEROP_GUIDE.md` for code interoperability) ✅ NEW
- **English lexicon resources** (irregular verbs, nouns, stop words in `priv/`) ✅ NEW
- **Generic operations layer** (`lib/operations/` with Summarization, Classification behaviours) ✅ NEW
- **Generic semantic layer** (`lib/semantic/` with EntityRecognition, Coreference behaviours) ✅ NEW
- **Refactoring guide** (`docs/REFACTORING.md` for architecture evolution strategy) ✅ NEW
- **English adapter modules** (Phase 2: bridge implementations to generic behaviours) ✅ NEW
  - `lib/language/english/adapters/summarizer_adapter.ex` ✅
  - `lib/language/english/adapters/entity_recognizer_adapter.ex` ✅
  - `lib/language/english/adapters/coreference_resolver_adapter.ex` ✅
  - Comprehensive adapter test suite (`test/language/english/adapters_test.exs`) ✅
- **Nasty module integration** (uses adapters for behaviour-based operations) ✅ NEW
- **Generic extractive summarization** (Phase 3-4: language-agnostic algorithm extraction) ✅ NEW
  - `lib/operations/summarization/extractive.ex` (440 lines) ✅
  - Position, length, TF-IDF, entity, discourse, coreference scoring ✅
  - Greedy and MMR selection algorithms ✅
  - Jaccard similarity for redundancy reduction ✅
  - Refactored `English.Summarizer` to delegate (69% code reduction) ✅
- **Generic rule-based NER** (Phase 3-4: language-agnostic NER framework) ✅ NEW
  - `lib/semantic/entity_recognition/rule_based.ex` (237 lines) ✅
  - Sequence detection and classification framework ✅
  - Configurable lexicons, patterns, and heuristics ✅
  - Refactored `English.EntityRecognizer` to delegate (23% code reduction) ✅
- **Abstractive summarization** (template-based fact extraction and generation) ✅ NEW
  - `lib/operations/summarization/abstractive.ex` (257 lines) ✅
  - `lib/language/english/abstractive_summarizer.ex` (91 lines) ✅
  - Extracts semantic facts, ranks by importance, generates fluent summaries ✅
- **Word sense disambiguation** (Lesk algorithm for context-based sense selection) ✅ NEW
  - `lib/semantic/word_sense_disambiguation.ex` (188 lines) ✅
  - `lib/language/english/word_sense_disambiguator.ex` (168 lines) ✅
  - Context window analysis, weighted scoring, ready for WordNet integration ✅

### Not Yet Implemented ❌

- Catalan language support
- Advanced statistical models:
  - Pre-trained transformers (BERT, RoBERTa) - documented in `docs/PRETRAINED_MODELS.md` (planned)
- Remaining documentation (3 docs not yet needed):
  - `docs/PARSING_GUIDE.md` - ✅ EXISTS
  - `docs/STATISTICAL_MODELS.md` - ✅ EXISTS
  - `docs/languages/ENGLISH_GRAMMAR.md` - ✅ EXISTS
  - `docs/languages/SPANISH_IMPLEMENTATION.md` - ✅ EXISTS (2026-01-08)
  - `docs/languages/SPANISH_GRAMMAR.md` - Future (when formal grammar spec needed)
  - `docs/languages/CATALAN_GRAMMAR.md` - Future (when Catalan implemented)
- Grammar resource files in priv/ (phrase rules, dependency rules)
- Complete generic algorithm extraction (remaining modules: coreference, SRL, QA, classification)
- Dialogue systems - documented in `docs/FUTURE_FEATURES.md`
- Formal semantics / Lambda calculus - documented in `docs/FUTURE_FEATURES.md`
- Full Ragex integration

## Priority Recommendations

### High Priority (Core Functionality) - ✅ COMPLETED (2026-01-07)
1. ~~Add language detection to `Registry.detect_language/1`~~ ✅
2. ~~Implement top-level convenience APIs in `Nasty` module~~ ✅
3. ~~Create `docs/API.md` and `docs/AST_REFERENCE.md`~~ ✅
4. ~~Support multiple constraints in code generation~~ ✅

### Medium Priority (Architecture Improvements) - ✅ PHASE 1-4 COMPLETED (2026-01-07)
1. ~~Refactor to create generic `lib/parsing/`, `lib/semantic/`, `lib/operations/` layers~~ ✅
   - Phase 1: Created behaviour modules (`Operations.Summarization`, `Operations.Classification`, `Semantic.EntityRecognition`, `Semantic.CoreferenceResolution`) ✅
   - Phase 2: Created adapter modules for English implementations ✅
     - `English.Adapters.SummarizerAdapter` ✅
     - `English.Adapters.EntityRecognizerAdapter` ✅
     - `English.Adapters.CoreferenceResolverAdapter` ✅
   - Updated `Nasty.summarize/2` to use adapter architecture ✅
   - All 360 tests passing with adapters ✅
   - Phase 3-4: Extracted generic algorithms for Summarization and Entity Recognition ✅
     - `Operations.Summarization.Extractive` (440 lines, all scoring + selection algorithms) ✅
     - `Semantic.EntityRecognition.RuleBased` (237 lines, sequence detection + classification) ✅
     - Refactored English modules to delegate to generic implementations ✅
     - 69% code reduction in Summarizer, 23% in EntityRecognizer ✅
     - No breaking changes, all 360 tests passing ✅
2. ~~Extract language-agnostic logic from English implementation~~ ✅ (Phase 1-4 complete for 2 modules)
   - ✅ Summarization: fully extracted and refactored
   - ✅ Entity Recognition: fully extracted and refactored
   - Remaining: Coreference Resolution, Question Answering, Classification, SRL (future)
3. ~~Create resource files in `priv/languages/english/`~~ ✅ (lexicons done, grammars remain)
4. ~~Complete documentation suite~~ ✅ (core docs done, 3 advanced docs remain)
   - Updated `docs/REFACTORING.md` with Phase 3-4 completion ✅

### Low Priority (Future Features)
1. ~~Spanish language implementation~~ ✅ COMPLETED (2026-01-08)
   - Production-ready Spanish NLP pipeline with full adapter pattern ✅
   - 13 modules, 3 adapters (843 lines), 45% code reduction ✅
   - Complete documentation and examples ✅
   - All 641 tests passing ✅
2. Catalan language implementation
3. ~~Abstractive summarization~~ ✅ COMPLETED (2026-01-07)
   - `lib/operations/summarization/abstractive.ex` (257 lines) - Generic template-based framework ✅
   - `lib/language/english/abstractive_summarizer.ex` (91 lines) - English implementation ✅
   - Extracts semantic facts (subject-verb-object tuples), ranks by importance, generates fluent summaries ✅
4. ~~Word sense disambiguation~~ ✅ COMPLETED (2026-01-07)
   - `lib/semantic/word_sense_disambiguation.ex` (188 lines) - Lesk algorithm framework ✅
   - `lib/language/english/word_sense_disambiguator.ex` (168 lines) - English with sample dictionary ✅
   - Context-based sense selection, ready for WordNet integration ✅
5. Advanced statistical models (PCFG, CRF, neural) - DOCUMENTED IN `docs/FUTURE_FEATURES.md`
   - Requires external integration (training data, optimization libraries, or NIFs)
   - See FUTURE_FEATURES.md for detailed implementation plans
6. Dialogue systems - DOCUMENTED IN `docs/FUTURE_FEATURES.md`
   - Requires dialogue corpus, state tracking, multi-turn context management
   - See FUTURE_FEATURES.md for architecture plan
7. Formal semantics - DOCUMENTED IN `docs/FUTURE_FEATURES.md`
   - Requires lambda calculus, compositional semantics, inference engine
   - See FUTURE_FEATURES.md for design overview

## Notes

- The architecture is well-designed for multi-language support via behaviours
- Generic algorithms extracted for Summarization and Entity Recognition (Phase 3-4 complete)
- Language-specific config (lexicons, stop words, patterns) provided via adapters
- Adding new languages is now significantly easier with adapter pattern
- Spanish implementation demonstrates pattern: 843 adapter lines reusing 677+ lines of generic algorithms
- 45% code reduction achieved in Spanish modules through delegation
- Adapter pattern successfully validated with production-ready Spanish support
- The statistical model infrastructure is solid and ready for additional models
- Code interoperability is functional but could be more sophisticated
- Refactoring demonstrates clean separation: 677+ lines of generic code shared across languages
