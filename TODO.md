# TODO - Nasty Unimplemented Features

This document tracks all features, enhancements, and code items that are not yet implemented in Nasty.

## Code-Level TODOs

These are TODOs found in the codebase that need attention:

### Neural Models

#### BiLSTM-CRF Architecture (`lib/statistics/neural/architectures/bilstm_crf.ex`)
- **Full CRF Layer Implementation** (lines 158, 294, 328, 358)
  - Currently using softmax instead of proper CRF
  - Need: Forward-backward algorithm for partition function
  - Need: Full Viterbi decoding for inference
  - Need: Transition matrix learning and application
  - Need: Variable-length sequence handling with masking
  - Status: Basic softmax version works, but proper CRF would improve accuracy

#### INT8 Quantization (`lib/statistics/neural/quantization/int8.ex`)
- **Model Hook System** (lines 194, 212, 304)
  - Need: Axon hooks to capture intermediate activations
  - Need: Full parameter extraction from Axon models
  - Need: Real activation statistics collection
  - Status: Stub implementation, basic quantization works
- **Accuracy Validation** (lines 354, 369)
  - Need: Full model evaluation on test data
  - Need: Proper parameter counting
  - Status: Returns placeholder values

### Code Interoperability

#### Intent Recognition (`lib/interop/intent_recognizer.ex`)
- ~~**Semantic Frames** (line 51)~~
  - ~~semantic_frames not yet implemented in Clause struct~~
  - Status: ~~Works with simplified extraction~~ COMPLETED - Added fallback handling for semantic_frames field
- ~~**Sophistication** (line 55)~~
  - ~~Intent building might be too simplified~~
  - ~~Could extract more nuanced constraints and arguments~~
  - Status: COMPLETED - Enhanced with comparison, property, and range constraint extraction
  
#### Code Explanation (`lib/interop/code_gen/explain.ex`)
- ~~**Enum.reduce Explanation** (line 289)~~
  - ~~Reducer function explanation not implemented~~
  - ~~Currently gives generic explanation~~
  - Status: COMPLETED - Added full reducer explanation with accumulator and element naming
- ~~**Mapper Variable Usage** (line 350)~~
  - ~~Not using variable name in mapper explanation~~
  - ~~Could be more descriptive~~
  - Status: COMPLETED - Now uses variable name in mapper explanation

### Language Support

#### Spanish Implementations
- ~~**Text Classification** (`lib/language/spanish/text_classifier.ex`, lines 157-159)~~
  - ~~POS tags feature not implemented for Spanish~~
  - ~~Entity extraction feature not implemented for Spanish~~
  - Status: ~~Basic BOW classification works~~ COMPLETED - POS tags and entity extraction features now implemented

#### Entity Recognition (`lib/language/english/entity_recognizer.ex`)
- ~~**Error Handling** (line 155)~~
  - ~~CRF prediction error case not handled~~
  - ~~Would fall through to rule-based (needs explicit error handling)~~
  - Status: COMPLETED - Explicit error handling added with fallback to rule-based

### Data Processing

#### Corpus Management (`lib/data/corpus.ex`)
- ~~**Test Ratio Usage** (line 94)~~
  - ~~test_ratio variable calculated but not used directly~~
  - ~~Could be cleaner~~
  - Status: COMPLETED - Cleaned up unused variable comment

### Mix Tasks

#### Training Tasks
- ~~**Fine-tuning** (`lib/mix/tasks/nasty/fine_tune/pos.ex`, lines 113, 145)~~
  - ~~Training loop progress reporting could be enhanced~~
  - ~~Validation logic could be more detailed~~
  - Status: COMPLETED - Added error handling for evaluation failures

#### Evaluation Tasks (`lib/mix/tasks/nasty.eval.ex`, line 154)
- ~~Additional evaluation metrics needed~~
- Status: COMPLETED - Added per-label metrics, confusion matrix statistics, and support counts

#### CRF Training (`lib/mix/tasks/nasty.train.crf.ex`, line 232)
- ~~Enhanced progress reporting~~
- Status: COMPLETED - Added error handling for prediction failures

### Visualization

#### Rendering (`lib/rendering/visualization.ex`, line 162)
- ~~JSON export could include more metadata~~
- Status: COMPLETED - Added language, span, and dependencies to JSON export

### Template Extraction

#### English Templates (`lib/language/english/template_extractor.ex`, line 164)
- ~~More template types could be added~~
- Status: COMPLETED - Added product_launch, education, founding, and subsidiary templates

## Feature-Level TODOs

### 1. Catalan Language Support

**Priority**: Medium  
**Effort**: 6-8 weeks  
**Status**: Not started

**Components Needed**:
- Tokenizer with Catalan punctuation and clitics
- POS tagger (rule-based + statistical)
- Morphology analyzer
- Phrase and sentence parsers
- Complete NLP pipeline
- Adapters for generic algorithms
- Resources in `priv/languages/catalan/`

**Benefits**:
- Completes trilingual support (English, Spanish, Catalan)
- Important for regional NLP applications
- Validates multi-language architecture

### 2. Dialogue Systems

**Priority**: Low  
**Effort**: 8-10 weeks  
**Status**: Not started

**Purpose**: Multi-turn conversational AI

**Components Needed**:

1. **Dialogue State Tracking**
   - Track conversation context across turns
   - Maintain entity carryover
   - Session management

2. **Turn Management**
   - Turn-taking protocols
   - Clarification questions
   - Out-of-domain handling

3. **Response Generation**
   - Template-based responses
   - Context-aware generation
   - Appropriate response selection

4. **Context Management**
   - Conversation history
   - Anaphora resolution across turns
   - Entity tracking

**Implementation Approach**:
```elixir
defmodule Nasty.Dialogue do
  defmodule State do
    defstruct [:turns, :entities, :current_intent, :context]
  end
  
  defmodule Manager do
    def process_turn(state, user_input, opts)
    def generate_response(state, opts)
    def update_context(state, new_info)
  end
end
```

**Challenges**:
- Need dialogue corpus (MultiWOZ, PersonaChat)
- Context window management
- Response quality evaluation
- Handling ambiguous references

**Datasets**:
- MultiWOZ for task-oriented dialogue
- PersonaChat for open-domain
- DSTC challenges

### 3. Formal Semantics / Lambda Calculus

**Priority**: Low (Research/Specialized)  
**Effort**: 12+ weeks  
**Status**: Not started

**Purpose**: Logical representation of meaning for inference and reasoning

**Components Needed**:

1. **Lambda Calculus Representation**
   ```elixir
   defmodule Nasty.Semantics.LambdaCalculus do
     defstruct [:type, :variable, :body, :function, :argument]
     
     def beta_reduce(expression)
     def alpha_convert(expression, new_var)
     def apply_function(function, argument)
   end
   ```

2. **Semantic Parsing**
   - NL → Lambda expressions
   - Compositional semantics
   - Quantifier handling

3. **Logical Forms**
   - First-order logic representation
   - Predicate-argument structure
   - Logical connectives (AND, OR, NOT, IMPLIES)

4. **Inference Engine**
   - Logical deduction
   - Theorem proving
   - Entailment checking

**Key Concepts**:
- Lambda expressions: `λx.P(x)` (property of x)
- Function application: `λx.P(x)(john)` → `P(john)`
- Quantifiers: `∀x.P(x)`, `∃x.P(x)`

**Example**:
```
"Every dog barks" → ∀x.(dog(x) → barks(x))
"Fido is a dog"  → dog(fido)
Inference: barks(fido) ✓
```

**Challenges**:
- Compositional semantics is complex
- Need lexical semantics for all words
- Quantifier scoping is ambiguous
- Handling modals, tense, aspect
- Inference is computationally hard (NP-complete)

**Resources**:
- Blackburn & Bos "Representation and Inference for Natural Language"
- Penn Semantic Treebank
- Abstract Meaning Representation (AMR)

### 4. Cross-Lingual Translation

**Priority**: Medium  
**Effort**: 6-8 weeks  
**Status**: Not started (architecture supports it)

**Purpose**: NL(English) ↔ NL(Spanish/Catalan) via shared AST

**Approach**:
- Parse source language to AST
- AST carries language-agnostic structure
- Render AST in target language

**Components Needed**:
- Cross-lingual word mapping lexicons
- Idiom translation rules
- Cultural adaptation rules
- Agreement enforcement per target language

**Example**:
```elixir
# English to Spanish
{:ok, document} = English.parse("The cat sleeps on the sofa.")
{:ok, spanish_text} = Spanish.render(document)
# => "El gato duerme en el sofá."
```

**Challenges**:
- Non-literal translations (idioms)
- Gender/number agreement in target language
- Word order differences
- Cultural context

### 5. Advanced Neural Model Integration

**Priority**: Medium  
**Effort**: 8-10 weeks  
**Status**: Basic transformer support complete, deeper integration possible

**Approaches**:

1. **ONNX Runtime Integration**
   - Run any ONNX model from Elixir
   - Hugging Face model zoo compatibility
   - Cross-platform support

2. **PyTorch via NIFs**
   - Direct Python library integration
   - Maximum flexibility
   - Best performance

3. **Expanded Axon Models**
   - More architecture types
   - Custom layers
   - Advanced training techniques

**Use Cases**:
- Text generation (GPT-style)
- Sequence-to-sequence (translation, summarization)
- Advanced embeddings (sentence-BERT)
- Multi-modal models (vision + language)

**Challenges**:
- GPU acceleration requirements
- Large model files (GBs)
- Training infrastructure
- Deployment complexity

**Recommendation**: 
- ONNX Runtime for inference-only use cases
- NIFs for custom training pipelines
- Axon for Elixir-native smaller models

### 6. Enhanced Information Extraction

**Priority**: Low  
**Effort**: 4-6 weeks  
**Status**: Basic extraction implemented

**Enhancements Needed**:

1. **More Relation Types**
   - Family relations (parent_of, sibling_of)
   - Ownership (owns, belongs_to)
   - Causality (causes, results_in)
   - Comparison (better_than, similar_to)

2. **More Event Types**
   - Natural events (earthquake, flood)
   - Political events (election, legislation)
   - Social events (protest, celebration)
   - Personal events (birth, death, marriage)

3. **Advanced Templates**
   - Scientific paper extraction
   - Legal document extraction
   - Medical record extraction
   - News article extraction

4. **Coreference Integration**
   - Track entities across sentences
   - Resolve pronouns in relations
   - Build knowledge graphs

### 7. Grammar Resource Files

**Priority**: Low  
**Effort**: 2-3 weeks  
**Status**: Logic is in code, could be externalized

**Purpose**: Externalize grammar rules for easier modification

**Files Needed**:
- `priv/languages/english/grammars/phrase_rules.ex` - CFG phrase rules
- `priv/languages/english/grammars/dependency_rules.ex` - Dependency templates
- Similar files for Spanish and future languages

**Benefits**:
- Easier grammar updates without code changes
- Non-programmers can contribute grammar rules
- Language-specific customization
- A/B testing of grammar variants

### 8. WordNet Integration

**Priority**: Low  
**Effort**: 3-4 weeks  
**Status**: WSD framework ready, needs data

**Purpose**: Rich lexical database for word sense disambiguation

**Integration Points**:
- Word sense disambiguation (already has framework)
- Synonym/antonym lookup
- Hypernym/hyponym relationships
- Semantic similarity calculations

**Implementation**:
```elixir
defmodule Nasty.Lexical.WordNet do
  def get_senses(word, pos_tag)
  def get_definition(sense_id)
  def get_synonyms(sense_id)
  def get_hypernyms(sense_id)
  def similarity(sense1, sense2)
end
```

**Resources**:
- Open Multilingual WordNet
- NLTK WordNet interface (for reference)
- BabelNet (multilingual)

### 9. Advanced Coreference Resolution

**Priority**: Low  
**Effort**: 6-8 weeks  
**Status**: Rule-based implemented, neural not started

**Approach**: Neural coreference models

**Components**:
- Mention detection (already have)
- Mention pair scoring (neural)
- Clustering (neural or hybrid)

**Models**:
- Span-based models (Lee et al.)
- BERT-based coreference
- End-to-end coreference

**Benefits**:
- Much higher accuracy (85%+ F1)
- Better handling of difficult cases
- Cross-sentence context

**Challenges**:
- Requires large annotated corpus (OntoNotes)
- Complex neural architecture
- Training infrastructure

## Implementation Priority Recommendations

### High Value / Near Term
1. Catalan language support (completes trilingual capability)
2. Grammar resource externalization (improves maintainability)
3. WordNet integration (enhances WSD)

### Medium Value / Medium Term
4. Cross-lingual translation (leverages existing architecture)
5. Enhanced information extraction (expands use cases)
6. Advanced neural integration (ONNX/NIFs)

### Research / Long Term
7. Dialogue systems (specialized application)
8. Formal semantics (research/academic)
9. Advanced coreference (neural models)

## External Integration Recommendations

Rather than implementing everything from scratch, consider integrating external tools:

1. **Neural Models**: ONNX Runtime or PyTorch via NIFs
2. **WordNet**: Use existing WordNet databases
3. **Dialogue**: Rasa or similar framework integration
4. **Large Models**: Hugging Face API for inference

This allows focusing on Elixir's strengths (concurrency, fault-tolerance, pipeline composition) while leveraging external tools for heavy computation.

## Contributing

When implementing features from this list:

1. Update this file to mark items as in-progress or complete
2. Add comprehensive tests
3. Document in relevant `docs/` files
4. Update `README.md` with new capabilities
5. Add examples to `examples/` directory
6. Follow existing code style and patterns
7. Use the adapter pattern for language-specific implementations

## Status Legend

- **Not started**: Feature is planned but no code exists
- **Stub**: Basic structure exists, needs full implementation
- **Partial**: Some functionality works, needs completion
- **Complete**: Fully implemented and tested
