# Future Features

This document describes planned features for future development.

## Completed Low Priority Features

### 3. Abstractive Summarization ✅
**Status**: Implemented (template-based)
- `lib/operations/summarization/abstractive.ex` - Generic framework
- `lib/language/english/abstractive_summarizer.ex` - English implementation
- Extracts semantic facts and generates new sentences
- Combines related facts fluently

### 4. Word Sense Disambiguation ✅  
**Status**: Implemented (Lesk algorithm)
- `lib/semantic/word_sense_disambiguation.ex` - Generic framework
- `lib/language/english/word_sense_disambiguator.ex` - English with sample dictionary
- Context-based sense selection
- For production: integrate WordNet or similar resource

## Remaining Low Priority Features

### 5. Advanced Statistical Models

These features require significant additional infrastructure:

#### PCFG (Probabilistic Context-Free Grammar) Parser

**Purpose**: Statistical parsing with probability-weighted grammar rules

**Approach**:
- Learn rule probabilities from treebanks (e.g., Penn Treebank)
- Use CYK algorithm for parsing
- Score parse trees by rule probability products

**Implementation Plan**:
```elixir
defmodule Nasty.Parsing.PCFG do
  @moduledoc """
  Probabilistic Context-Free Grammar parser.
  
  Requires:
  - Grammar rule definitions with probabilities
  - CYK parsing algorithm
  - Viterbi-like best parse selection
  """
  
  @callback get_grammar() :: grammar()
  @callback parse(tokens(), grammar()) :: {:ok, parse_tree()} | {:error, term()}
end
```

**Challenges**:
- Need annotated treebank for training
- Grammar rule extraction and smoothing
- Handling unknown words
- Computational complexity O(n³)

**External Dependencies**:
- Would benefit from Penn Treebank or Universal Dependencies
- Consider pre-trained grammar files

#### CRF (Conditional Random Fields) for NER

**Purpose**: Statistical sequence labeling for better entity recognition

**Approach**:
- Feature extraction (word shape, context, gazetteers)
- Viterbi decoding for label sequence
- Training on annotated corpora (CoNLL-2003, OntoNotes)

**Implementation Plan**:
```elixir
defmodule Nasty.Statistical.CRF do
  @moduledoc """
  Conditional Random Fields for sequence labeling.
  
  Requires:
  - Feature extraction functions
  - Viterbi algorithm for decoding
  - Training on labeled data
  """
  
  @callback extract_features(token(), context()) :: feature_vector()
  @callback train(training_data()) :: model()
  @callback predict(model(), sequence()) :: labels()
end
```

**Challenges**:
- Feature engineering (complex for Elixir)
- Training requires optimization (L-BFGS)
- Need labeled training data
- May want Rust NIF for performance

**External Dependencies**:
- Training corpus (CoNLL-2003, OntoNotes)
- Optimization library or NIF

#### Neural Models

**Purpose**: State-of-the-art accuracy for NLP tasks

**Approaches**:
- BERT/RoBERTa for contextualized embeddings
- Transformers for seq2seq tasks
- LSTM/GRU for sequence processing

**Implementation Plan**:
```elixir
defmodule Nasty.Neural do
  @moduledoc """
  Integration with external neural models.
  
  Options:
  1. NIFs to Python/PyTorch models
  2. ONNX Runtime integration
  3. Axon (Elixir neural network library)
  """
end
```

**Challenges**:
- Neural models require large computational resources
- GPU acceleration needed for efficiency  
- Model files are large (100s of MB)
- Training requires specialized hardware

**Recommendation**: 
- Use external model servers (e.g., Hugging Face API)
- Or integrate via NIFs to existing Python libraries
- Axon for simpler models trained on smaller datasets

### 6. Dialogue Systems

**Purpose**: Multi-turn conversational AI

**Components Needed**:
1. **Dialogue State Tracking**: Track conversation context
2. **Intent Recognition**: Classify user intents (already have basic support)
3. **Response Generation**: Generate appropriate responses
4. **Context Management**: Maintain conversation history

**Implementation Plan**:
```elixir
defmodule Nasty.Dialogue do
  @moduledoc """
  Dialogue system for multi-turn conversations.
  """
  
  defmodule State do
    @moduledoc "Tracks dialogue state across turns"
    defstruct [
      :turns,
      :entities,
      :current_intent,
      :context
    ]
  end
  
  defmodule Manager do
    @moduledoc "Manages conversation flow"
    
    def process_turn(state, user_input, opts \\\\ [])
    def generate_response(state, opts \\\\ [])
    def update_context(state, new_info)
  end
end
```

**Features to Implement**:
- Turn-taking management
- Entity carryover across turns
- Anaphora resolution (\"it\", \"that\", etc.)
- Dialogue act classification
- Response template selection
- Clarification questions

**Challenges**:
- Need dialogue corpus for training/testing
- Context window management
- Handling out-of-domain utterances
- Response quality evaluation

**Datasets**:
- MultiWOZ for task-oriented dialogue
- PersonaChat for open-domain
- DSTC challenges

### 7. Formal Semantics / Lambda Calculus

**Purpose**: Logical representation of meaning for inference

**Components**:
1. **Semantic Parsing**: NL → Lambda expressions
2. **Logical Forms**: First-order logic representation
3. **Inference Engine**: Logical deduction
4. **Theorem Proving**: Verify entailments

**Implementation Plan**:
```elixir
defmodule Nasty.Semantics.Formal do
  @moduledoc """
  Formal semantic representations using lambda calculus.
  """
  
  defmodule LambdaCalculus do
    @moduledoc "Lambda expression representation and reduction"
    
    defstruct [:type, :variable, :body, :function, :argument]
    
    def beta_reduce(expression)
    def alpha_convert(expression, new_var)
    def apply_function(function, argument)
  end
  
  defmodule Parser do
    @moduledoc "Parse NL to lambda expressions"
    
    def parse_to_logic(sentence) do
      # Compositional semantics
      # Map syntactic structure to semantic representation
    end
  end
  
  defmodule Inference do
    @moduledoc "Logical inference and entailment checking"
    
    def entails?(premises, conclusion)
    def prove(goal, knowledge_base)
  end
end
```

**Key Concepts**:
- **Lambda expressions**: `λx.P(x)` (property of x)
- **Function application**: `λx.P(x)(john)` → `P(john)`
- **Quantifiers**: `∀x.P(x)`, `∃x.P(x)`
- **Logical connectives**: AND, OR, NOT, IMPLIES

**Example**:
```
"Every dog barks"
∀x.(dog(x) → barks(x))

"Fido is a dog"  
dog(fido)

Inference: barks(fido) ✓
```

**Challenges**:
- Compositional semantics is complex
- Need lexical semantics for all words
- Quantifier scoping is ambiguous
- Handling modals, tense, aspect
- Inference is computationally hard

**Resources**:
- Blackburn & Bos \"Representation and Inference for Natural Language\"
- Penn Semantic Treebank
- Abstract Meaning Representation (AMR)

## Implementation Priority

For practical NLP applications, recommend:

**High Value**:
- ✅ Abstractive summarization (done)
- ✅ Word sense disambiguation (done)
- Dialogue systems (useful for chatbots)

**Medium Value**:
- CRF for NER (significant accuracy improvement)
- Neural model integration (state-of-the-art results)

**Research/Specialized**:
- PCFG parsing (mainly for linguistic analysis)
- Formal semantics (logic/reasoning applications)

## External Integration Recommendations

Rather than implementing everything from scratch, consider:

1. **Neural Models**: ONNX Runtime or PyTorch via NIFs
2. **PCFG/CRF**: Use existing trained models (Stanford CoreNLP, spaCy)
3. **WordNet**: Integrate WordNet database for WSD
4. **Dialogue**: Rasa or similar framework integration

This allows focusing on Elixir's strengths (concurrency, fault-tolerance) 
while leveraging external tools for heavy computation.
