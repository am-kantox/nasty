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
Currently, semantic logic is in `lib/language/english/`. Need to extract:
- `ner.ex` - Named entity recognition (exists in `language/english/entity_recognizer.ex` instead)
- `srl.ex` - Semantic role labeling (exists in `language/english/semantic_role_labeler.ex` instead)
- `coref.ex` - Coreference resolution (exists in `language/english/coreference_resolver.ex` instead)
- `disambiguation.ex` - **Word sense disambiguation (NOT IMPLEMENTED)**

#### `lib/operations/` - Language-agnostic NLP operations
Currently, operations are in `lib/language/english/`. Need to extract:
- `summarization.ex` (exists in `language/english/summarizer.ex` instead)
- `question_answering.ex` (exists in `language/english/question_analyzer.ex` and `answer_extractor.ex`)
- `classification.ex` (exists in `language/english/text_classifier.ex`)
- `extraction.ex` (exists in multiple `language/english/*_extractor.ex` files)

### 2. Language Infrastructure Not Implemented

- `Nasty.Language.Parser` - Generic parsing interface (PLAN.md line 43-45)
- `Nasty.Language.Renderer` - Generic renderer interface (PLAN.md line 47-49) (partially done in `rendering/text.ex`)

### 3. Multi-Language Support (PLANNED, NOT IMPLEMENTED)

#### Spanish Implementation
- No `lib/language/spanish/` directory
- No Spanish tokenizer, POS tagger, morphology, parser
- No `priv/languages/spanish/` resource directory

#### Catalan Implementation
- No `lib/language/catalan/` directory
- No Catalan tokenizer, POS tagger, morphology, parser
- No `priv/languages/catalan/` resource directory

#### Cross-language Translation
- NL(English) ↔ NL(Spanish) via shared AST representation
- NL(English) ↔ NL(Catalan) via shared AST representation
- Multi-language rendering: `Nasty.render(ast, target_language: :es)` (PLAN.md line 1018-1019)

### 4. Documentation Missing

From PLAN.md lines 932-943, the following documents don't exist:

- `docs/PARSING_GUIDE.md` - Parsing algorithm details
- `docs/STATISTICAL_MODELS.md` - Statistical models guide
- `docs/TRAINING_GUIDE.md` - Model training guide
- `docs/languages/ENGLISH_GRAMMAR.md` - English grammar specification
- `docs/languages/SPANISH_GRAMMAR.md` - Spanish grammar (future)
- `docs/languages/CATALAN_GRAMMAR.md` - Catalan grammar (future)

### 5. Resource Files Missing

From PLAN.md lines 888-897:

#### English Resources
- `priv/languages/english/grammars/phrase_rules.ex` - CFG phrase rules
- `priv/languages/english/grammars/dependency_rules.ex` - Dependency templates

#### Spanish Resources (future)
- `priv/languages/spanish/` - All Spanish language resources

#### Catalan Resources (future)
- `priv/languages/catalan/` - All Catalan language resources

### 6. Advanced Features (Future Directions, PLAN.md lines 1048-1061)

#### Abstractive Summarization
- PLAN.md lines 992-993, 1056
- Currently only extractive summarization is implemented
- Need attention-based abstractive models

#### Advanced Statistical Models
- **PCFG parser** for phrase structure (line 1053)
- **CRF for named entity recognition** (line 1054)
- **Neural models** for improved accuracy (line 1055)

#### Additional NLP Capabilities
- **Word sense disambiguation** - Mentioned in semantic layer but not implemented
- **Dialogue systems** (line 1057) - Conversational context tracking
- **Formal semantics** (line 1059) - Lambda calculus representation for logical inference
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
- `test/fixtures/english/expected_asts.exs` - Expected parse results
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
- Mix tasks for model training and evaluation
- **Language detection** (character set + word frequency analysis for EN/ES/CA) ✅ NEW
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

### Not Yet Implemented ❌

- Multi-language support (Spanish, Catalan)
- Word sense disambiguation
- Abstractive summarization
- Advanced statistical models (PCFG, CRF, neural)
- Remaining documentation (3 of 13 docs missing)
- Grammar resource files in priv/ (phrase rules, dependency rules)
- Generic `lib/parsing/`, `lib/semantic/`, `lib/operations/` module structure
- Dialogue systems
- Formal semantics / Lambda calculus
- Full Ragex integration

## Priority Recommendations

### High Priority (Core Functionality) - ✅ COMPLETED (2026-01-07)
1. ~~Add language detection to `Registry.detect_language/1`~~ ✅
2. ~~Implement top-level convenience APIs in `Nasty` module~~ ✅
3. ~~Create `docs/API.md` and `docs/AST_REFERENCE.md`~~ ✅
4. ~~Support multiple constraints in code generation~~ ✅

### Medium Priority (Architecture Improvements) - ⚡ PARTIALLY COMPLETED (2026-01-07)
1. ~~Refactor to create generic `lib/parsing/`, `lib/semantic/`, `lib/operations/` layers~~ ✅ (behaviours defined, adapters next)
2. Extract language-agnostic logic from English implementation (in progress - phase 1 complete)
3. ~~Create resource files in `priv/languages/english/`~~ ✅ (lexicons done, grammars remain)
4. ~~Complete documentation suite~~ ✅ (core docs done, 3 advanced docs remain)

### Low Priority (Future Features)
1. Spanish language implementation
2. Catalan language implementation
3. Abstractive summarization
4. Word sense disambiguation
5. Advanced statistical models (PCFG, CRF, neural)
6. Dialogue systems
7. Formal semantics

## Notes

- The architecture is well-designed for multi-language support via behaviours
- Most language-specific logic is currently in `lib/language/english/`
- Refactoring to extract generic layers would make adding new languages easier
- The statistical model infrastructure is solid and ready for additional models
- Code interoperability is functional but could be more sophisticated
